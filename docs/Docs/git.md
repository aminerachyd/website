# Git

## Viewing History & Search

### Look for a line in commit history

This command will list the commits where a specific string was added and removed from a file.
It will display the commit log along with the diff, showing where the line was added or removed.

```bash
git log -p -S'example line' -- example.txt
```

---

## Working with Branches & Files

### Copy file from a commit/branch to another branch

Place yourself on the branch you would like to copy **to**, and run

```bash
git checkout <SOURCE_BRANCH> myfile
```

Or to modify only the working directory (the previous command also copies to the staging area)

```bash
git restore --source <SOURCE_BRANCH> myfile
```

---

## Authentication & SSH

### Setup a separate SSH key to use for different identities on Github

1. Create an SSH key:
```bash
ssh-keygen -t rsa -b 4096 -C "aminerachyd99@example.com"
```

2. Add the SSH key to Github
3. Edit your SSH config (`~/.ssh/config` or a file under `~/.ssh/config.d/`)
```
# Default GitHub
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes

# Second GitHub account (for aminerachyd) with the key we generated above
Host github-second
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_aminerachyd
  IdentitiesOnly yes
```

4. Set the remote URL using the SSH host we added
```bash
git remote set-url origin git@github-second:aminerachyd/argo-cd.git
```

5. Test:
```bash
$ ssh -T git@github-second
Hi aminerachyd! You've successfully authenticated, but GitHub does not provide shell access
```

---

## Staging & Changes

### Restore only some lines in changed file

Using:
```bash
git restore -p path/to/file
```

This opens an interactie prompt to select the lines to keep or to discard in the changed file.
