---
tags:
  - fuse
  - linux
  - filesystem
---

# From FUSE Read to Page Cache

## Overview

This reading has been done to understand how a filesystem, in particular FUSE ones, interact with the page cache and find potential ways to trace this behavior. This reading references Kernel [5.14](https://elixir.bootlin.com/linux/v5.14/source).

---

## FUSE Basics

### File Operations
```c
static const struct file_operations fuse_file_operations = {
	.llseek		= fuse_file_llseek,
	.read_iter	= fuse_file_read_iter,
	.write_iter	= fuse_file_write_iter,
	.mmap		= fuse_file_mmap,
	.open		= fuse_open,
	.flush		= fuse_flush,
	.release	= fuse_release,
	.fsync		= fuse_fsync,
	.lock		= fuse_file_lock,
	.get_unmapped_area = thp_get_unmapped_area,
	.flock		= fuse_file_flock,
	.splice_read	= generic_file_splice_read,
	.splice_write	= iter_file_splice_write,
	.unlocked_ioctl	= fuse_file_ioctl,
	.compat_ioctl	= fuse_file_compat_ioctl,
	.poll		= fuse_file_poll,
	.fallocate	= fuse_file_fallocate,
	.copy_file_range = fuse_copy_file_range,
};
```
The `.read_iter` interface is the one used to read files once they are opened.

The FUSE driver doesn't implement the `.read` operation, so the `.read_iter` is used by the Kernel ([check vfs_read operation](https://elixir.bootlin.com/linux/v5.14/source/fs/read_write.c#L493-L496)) as it's a slightly more modern alternative than the legacy `.read`.

---

## FUSE Read Implementation

### fuse_file_read_iter
```c
static ssize_t fuse_file_read_iter(struct kiocb *iocb, struct iov_iter *to)
{
	struct file *file = iocb->ki_filp;
	struct fuse_file *ff = file->private_data;
	struct inode *inode = file_inode(file);

	if (fuse_is_bad(inode))
		return -EIO;

	if (FUSE_IS_DAX(inode))
		return fuse_dax_read_iter(iocb, to);

	if (!(ff->open_flags & FOPEN_DIRECT_IO))
		return fuse_cache_read_iter(iocb, to);
	else
		return fuse_direct_read_iter(iocb, to);
}
```

To read while trying to use the page cache, we have to use a "no DIRECT_IO" flag. The first condition is thus checked and we enter the routine `fuse_cache_read_iter` defined as follows:

---

### fuse_cache_read_iter
```c
static ssize_t fuse_cache_read_iter(struct kiocb *iocb, struct iov_iter *to)
{
	struct inode *inode = iocb->ki_filp->f_mapping->host;
	struct fuse_conn *fc = get_fuse_conn(inode);

	/*
	 * In auto invalidate mode, always update attributes on read.
	 * Otherwise, only update if we attempt to read past EOF (to ensure
	 * i_size is up to date).
	 */
	if (fc->auto_inval_data ||
	    (iocb->ki_pos + iov_iter_count(to) > i_size_read(inode))) {
		int err;
		err = fuse_update_attributes(inode, iocb->ki_filp);
		if (err)
			return err;
	}

	return generic_file_read_iter(iocb, to);
}
```

This in turn does some checks and ultimately calls the `generic_file_read_iter` routine which is a high level and generic routine used by all filesystems to read data from the page cache. This puts data into `iter` which is the destination for the read data.

---

## Page Cache Interaction

### generic_file_read_iter
ssize_t generic_file_read_iter(struct kiocb *iocb, struct iov_iter *iter)
{
	size_t count = iov_iter_count(iter);
	ssize_t retval = 0;

	if (!count)
		return 0; /* skip atime */

	if (iocb->ki_flags & IOCB_DIRECT) {
		struct file *file = iocb->ki_filp;
		struct address_space *mapping = file->f_mapping;
		struct inode *inode = mapping->host;
		loff_t size;

		size = i_size_read(inode);
		if (iocb->ki_flags & IOCB_NOWAIT) {
			if (filemap_range_needs_writeback(mapping, iocb->ki_pos,
						iocb->ki_pos + count - 1))
				return -EAGAIN;
		} else {
			retval = filemap_write_and_wait_range(mapping,
						iocb->ki_pos,
					        iocb->ki_pos + count - 1);
			if (retval < 0)
				return retval;
		}

		file_accessed(file);

		retval = mapping->a_ops->direct_IO(iocb, iter);
		if (retval >= 0) {
			iocb->ki_pos += retval;
			count -= retval;
		}
		if (retval != -EIOCBQUEUED)
			iov_iter_revert(iter, count - iov_iter_count(iter));

		/*
		 * Btrfs can have a short DIO read if we encounter
		 * compressed extents, so if there was an error, or if
		 * we've already read everything we wanted to, or if
		 * there was a short read because we hit EOF, go ahead
		 * and return.  Otherwise fallthrough to buffered io for
		 * the rest of the read.  Buffered reads will not work for
		 * DAX files, so don't bother trying.
		 */
		if (retval < 0 || !count || iocb->ki_pos >= size ||
		    IS_DAX(inode))
			return retval;
	}

	return filemap_read(iocb, iter, retval);
}
```

By the end this routine calls the `filemap_read` routine which initiates the chain to [read from the pagecache](https://elixir.bootlin.com/linux/v5.14/source/mm/filemap.c#L2519):
```c
ssize_t filemap_read(struct kiocb *iocb, struct iov_iter *iter,
		ssize_t already_read)
{
	struct file *filp = iocb->ki_filp;
	struct file_ra_state *ra = &filp->f_ra;
	struct address_space *mapping = filp->f_mapping;
	struct inode *inode = mapping->host;
	struct pagevec pvec;
	int i, error = 0;
	bool writably_mapped;
	loff_t isize, end_offset;

	if (unlikely(iocb->ki_pos >= inode->i_sb->s_maxbytes))
		return 0;
	if (unlikely(!iov_iter_count(iter)))
		return 0;

	iov_iter_truncate(iter, inode->i_sb->s_maxbytes);
	pagevec_init(&pvec);

	do {
		cond_resched();

		/*
		 * If we've already successfully copied some data, then we
		 * can no longer safely return -EIOCBQUEUED. Hence mark
		 * an async read NOWAIT at that point.
		 */
		if ((iocb->ki_flags & IOCB_WAITQ) && already_read)
			iocb->ki_flags |= IOCB_NOWAIT;

		error = filemap_get_pages(iocb, iter, &pvec);
		if (error < 0)
			break;

		/*
		 * i_size must be checked after we know the pages are Uptodate.
		 *
		 * Checking i_size after the check allows us to calculate
		 * the correct value for "nr", which means the zero-filled
		 * part of the page is not copied back to userspace (unless
		 * another truncate extends the file - this is desired though).
		 */
		isize = i_size_read(inode);
		if (unlikely(iocb->ki_pos >= isize))
			goto put_pages;
		end_offset = min_t(loff_t, isize, iocb->ki_pos + iter->count);

		/*
		 * Once we start copying data, we don't want to be touching any
		 * cachelines that might be contended:
		 */
		writably_mapped = mapping_writably_mapped(mapping);

		/*
		 * When a sequential read accesses a page several times, only
		 * mark it as accessed the first time.
		 */
		if (iocb->ki_pos >> PAGE_SHIFT !=
		    ra->prev_pos >> PAGE_SHIFT)
			mark_page_accessed(pvec.pages[0]);

		for (i = 0; i < pagevec_count(&pvec); i++) {
			struct page *page = pvec.pages[i];
			size_t page_size = thp_size(page);
			size_t offset = iocb->ki_pos & (page_size - 1);
			size_t bytes = min_t(loff_t, end_offset - iocb->ki_pos,
					     page_size - offset);
			size_t copied;

			if (end_offset < page_offset(page))
				break;
			if (i > 0)
				mark_page_accessed(page);
			/*
			 * If users can be writing to this page using arbitrary
			 * virtual addresses, take care about potential aliasing
			 * before reading the page on the kernel side.
			 */
			if (writably_mapped) {
				int j;

				for (j = 0; j < thp_nr_pages(page); j++)
					flush_dcache_page(page + j);
			}

			copied = copy_page_to_iter(page, offset, bytes, iter);

			already_read += copied;
			iocb->ki_pos += copied;
			ra->prev_pos = iocb->ki_pos;

			if (copied < bytes) {
				error = -EFAULT;
				break;
			}
		}
put_pages:
		for (i = 0; i < pagevec_count(&pvec); i++)
			put_page(pvec.pages[i]);
		pagevec_reinit(&pvec);
	} while (iov_iter_count(iter) && iocb->ki_pos < isize && !error);

	file_accessed(filp);

	return already_read ? already_read : error;
}
```

And calls the `filemap_get_pages` routine which does the [actual reading from the pagecache](https://elixir.bootlin.com/linux/v5.14/source/mm/filemap.c#L2519):

```c
static int filemap_get_pages(struct kiocb *iocb, struct iov_iter *iter,
		struct pagevec *pvec)
{
	struct file *filp = iocb->ki_filp;
	struct address_space *mapping = filp->f_mapping;
	struct file_ra_state *ra = &filp->f_ra;
	pgoff_t index = iocb->ki_pos >> PAGE_SHIFT;
	pgoff_t last_index;
	struct page *page;
	int err = 0;

	last_index = DIV_ROUND_UP(iocb->ki_pos + iter->count, PAGE_SIZE);
retry:
	if (fatal_signal_pending(current))
		return -EINTR;

	filemap_get_read_batch(mapping, index, last_index, pvec);
	if (!pagevec_count(pvec)) {
		if (iocb->ki_flags & IOCB_NOIO)
			return -EAGAIN;
		page_cache_sync_readahead(mapping, ra, filp, index,
				last_index - index);
		filemap_get_read_batch(mapping, index, last_index, pvec);
	}
	if (!pagevec_count(pvec)) {
		if (iocb->ki_flags & (IOCB_NOWAIT | IOCB_WAITQ))
			return -EAGAIN;
		err = filemap_create_page(filp, mapping,
				iocb->ki_pos >> PAGE_SHIFT, pvec);
		if (err == AOP_TRUNCATED_PAGE)
			goto retry;
		return err;
	}

	page = pvec->pages[pagevec_count(pvec) - 1];
	if (PageReadahead(page)) {
		err = filemap_readahead(iocb, filp, mapping, page, last_index);
		if (err)
			goto err;
	}
	if (!PageUptodate(page)) {
		if ((iocb->ki_flags & IOCB_WAITQ) && pagevec_count(pvec) > 1)
			iocb->ki_flags |= IOCB_NOWAIT;
		err = filemap_update_page(iocb, mapping, iter, page);
		if (err)
			goto err;
	}

	return 0;
err:
	if (err < 0)
		put_page(page);
	if (likely(--pvec->nr))
		return 0;
	if (err == AOP_TRUNCATED_PAGE)
		goto retry;
	return err;
}
```

Digging deeper, we see the two routines are invoked in the `retry` block: `filemap_get_read_batch` & `page_cache_sync_readahead`.
The first one reads a batch of pages from the page cache and stores them in the `pvec` pages vector.
If no page has been read (`!pagevec_count(pvec)` being equal to 1), the second routine is invoked to fetch pages and retry the read.

Ultimately, the `filemap_get_pages` routine should always return >=0 unless there is an error, so for tracing purposes we can't really know from it alone if we did a cache hit or miss on a read.

```
filemap_get_pages(..., pvec)
\_ pvec is not empty
   \_ return 0, pvec has references to pages read
\_ pvec is empty
   \_ page readahead
   \_ re-read again pages, go back to when pvec is not empty
```

Another routine to probably probe which could be interesting is: [pagecache_get_page](https://elixir.bootlin.com/linux/v5.14/source/mm/filemap.c#L1833)
However there is no straightforward entrypoing to the `pagecache_get_page` routine as it is invoked manually by some file system operations in the Kernel 5.14.

In Kernel 5.14 there is also the [page_cache_sync_readahead](https://elixir.bootlin.com/linux/v5.14/source/include/linux/pagemap.h#L879) routine:
```
 * page_cache_sync_readahead() should be called when a cache miss happened: * it will submit the read.  The readahead logic may decide to piggyback more * pages onto the read request if access patterns suggest it will improve * performance.
```
But since it's inlined, it is not traceable.
