# Static and dynamic linking

Some context on how Linux works: functions that are external from our programs usually come from libraries.
The most known and common library which is present on most Linux systems is the standard C library: the GNU C library, often referred to as `libc` or `glibc`. (check `man glibc`)

When a function is invoked from the libc into a main program, it is often loaded into memory by a special program called **the linker**. (`man ld`)
The linker is only invoked when a program has been compiled with `dynamic linking`, ie my program refers to another program in the library X), as opposed to `static linking`: my program is self sufficient and has pulled all of it's dependencies of libraries and they are baked into the executable.

To demonstrate the difference between static and dynamic linking, let's have a simple C file:

```c
#include <stdio.h>

int main() {
    printf("Hello World");

    return 0;
}
```

We compile it both statically and dynamically and check the sizes of the executables, we see that the statically compiled program is much bigger in size:

```bash
➜  gcc main.c -o hello_dynamic
➜  gcc -static main.c -o hello_static
➜  ls -lh hello_*
-rwxr-xr-x 1 amine amine  16K Aug 21 21:08 hello_dynamic
-rwxr-xr-x 1 amine amine 767K Aug 21 21:08 hello_static
```

## Tracing the compiled programs

Using `strace`, we can trace the [syscalls](https://en.wikipedia.org/wiki/System_call) invoked upon executing the files, we'll focus on only on a subset of calls.  

For the statically compiled program, we get the following output when tracing it:

```bash
➜ strace -y ./hello_static
execve("./hello_static", ["./hello_static"], 0x7fff4d3eafa8 /* 32 vars */) = 0
brk(NULL)                               = 0x22b76000
brk(0x22b76d00)                         = 0x22b76d00
arch_prctl(ARCH_SET_FS, 0x22b76380)     = 0
set_tid_address(0x22b76650)             = 6410
set_robust_list(0x22b76660, 24)         = 0
rseq(0x22b76ca0, 0x20, 0, 0x53053053)   = 0
prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, rlim_max=RLIM64_INFINITY}) = 0
readlinkat(AT_FDCWD</home/amine/Projects/misc>, "/proc/self/exe", "/home/amine/Projects/misc/hello_"..., 4096) = 38
getrandom("\xcc\x96\x51\x97\x15\x69\x02\x3b", 8, GRND_NONBLOCK) = 8
brk(NULL)                               = 0x22b76d00
brk(0x22b97d00)                         = 0x22b97d00
brk(0x22b98000)                         = 0x22b98000
mprotect(0x4a5000, 20480, PROT_READ)    = 0
fstat(1</dev/pts/7>, {st_mode=S_IFCHR|0620, st_rdev=makedev(0x88, 0x7), ...}) = 0
write(1</dev/pts/7>, "Hello World", 11Hello World) = 11
exit_group(0)                           = ?
+++ exited with 0 +++
```

Note how the first syscall is `execve`, which directly executes the program: `execve("./hello_static", ["./hello_static"], 0x7fff4d3eafa8 /* 32 vars */) = 0`

A bunch of setup is done by the C library. By the end (before the exit_group call), the program performs a `stat` and a `write` to the file descriptor 1: `write(1</dev/pts/7>, "Hello World", 11Hello World) = 11` which effectively writes to standard output (stdout), ie the terminal.

Let's observe what happens when doing the same thing on the dynamically linked program this time:

```bash
execve("./hello_dynamic", ["./hello_dynamic"], 0x7ffc3aac5318 /* 32 vars */) = 0
brk(NULL)                               = 0x63aec7935000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7a6f23e3b000
access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (No such file or directory)
openat(AT_FDCWD</home/amine/Projects/misc>, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3</etc/ld.so.cache>
fstat(3</etc/ld.so.cache>, {st_mode=S_IFREG|0644, st_size=40395, ...}) = 0
mmap(NULL, 40395, PROT_READ, MAP_PRIVATE, 3</etc/ld.so.cache>, 0) = 0x7a6f23e31000
close(3</etc/ld.so.cache>)              = 0
openat(AT_FDCWD</home/amine/Projects/misc>, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3</usr/lib/x86_64-linux-gnu/libc.so.6>
read(3</usr/lib/x86_64-linux-gnu/libc.so.6>, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\220\243\2\0\0\0\0\0"..., 832) = 832
pread64(3</usr/lib/x86_64-linux-gnu/libc.so.6>, "\6\0\0\0\4\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0"..., 784, 64) = 784
fstat(3</usr/lib/x86_64-linux-gnu/libc.so.6>, {st_mode=S_IFREG|0755, st_size=2125328, ...}) = 0
pread64(3</usr/lib/x86_64-linux-gnu/libc.so.6>, "\6\0\0\0\4\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0"..., 784, 64) = 784
mmap(NULL, 2170256, PROT_READ, MAP_PRIVATE|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0) = 0x7a6f23c00000
mmap(0x7a6f23c28000, 1605632, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x28000) = 0x7a6f23c28000
mmap(0x7a6f23db0000, 323584, PROT_READ, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x1b0000) = 0x7a6f23db0000
mmap(0x7a6f23dff000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x1fe000) = 0x7a6f23dff000
mmap(0x7a6f23e05000, 52624, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7a6f23e05000
close(3</usr/lib/x86_64-linux-gnu/libc.so.6>) = 0
mmap(NULL, 12288, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7a6f23e2e000
arch_prctl(ARCH_SET_FS, 0x7a6f23e2e740) = 0
set_tid_address(0x7a6f23e2ea10)         = 6611
set_robust_list(0x7a6f23e2ea20, 24)     = 0
rseq(0x7a6f23e2f060, 0x20, 0, 0x53053053) = 0
mprotect(0x7a6f23dff000, 16384, PROT_READ) = 0
mprotect(0x63aeb2039000, 4096, PROT_READ) = 0
mprotect(0x7a6f23e73000, 8192, PROT_READ) = 0
prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, rlim_max=RLIM64_INFINITY}) = 0
munmap(0x7a6f23e31000, 40395)           = 0
fstat(1</dev/pts/7>, {st_mode=S_IFCHR|0620, st_rdev=makedev(0x88, 0x7), ...}) = 0
getrandom("\x53\x23\xbe\x04\x3e\x8d\x83\xcc", 8, GRND_NONBLOCK) = 8
brk(NULL)                               = 0x63aec7935000
brk(0x63aec7956000)                     = 0x63aec7956000
write(1</dev/pts/7>, "Hello World", 11Hello World) = 11
exit_group(0)                           = ?
+++ exited with 0 +++
```

The output is bigger here. We start from the same `execve` call. But this time there is much more setup done by the C library.
In particular, we notice some calls at the beginning:

```bash
# [1]
access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (No such file or directory)

# [2]
openat(AT_FDCWD</home/amine/Projects/misc>, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3</etc/ld.so.cache>
fstat(3</etc/ld.so.cache>, {st_mode=S_IFREG|0644, st_size=40395, ...}) = 0
mmap(NULL, 40395, PROT_READ, MAP_PRIVATE, 3</etc/ld.so.cache>, 0) = 0x7a6f23e31000
close(3</etc/ld.so.cache>)              = 0

# [3]
openat(AT_FDCWD</home/amine/Projects/misc>, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3</usr/lib/x86_64-linux-gnu/libc.so.6>
read(3</usr/lib/x86_64-linux-gnu/libc.so.6>, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\220\243\2\0\0\0\0\0"..., 832) = 832
pread64(3</usr/lib/x86_64-linux-gnu/libc.so.6>, "\6\0\0\0\4\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0"..., 784, 64) = 784
fstat(3</usr/lib/x86_64-linux-gnu/libc.so.6>, {st_mode=S_IFREG|0755, st_size=2125328, ...}) = 0
pread64(3</usr/lib/x86_64-linux-gnu/libc.so.6>, "\6\0\0\0\4\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0"..., 784, 64) = 784
mmap(NULL, 2170256, PROT_READ, MAP_PRIVATE|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0) = 0x7a6f23c00000
mmap(0x7a6f23c28000, 1605632, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x28000) = 0x7a6f23c28000
mmap(0x7a6f23db0000, 323584, PROT_READ, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x1b0000) = 0x7a6f23db0000
mmap(0x7a6f23dff000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x1fe000) = 0x7a6f23dff000
mmap(0x7a6f23e05000, 52624, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7a6f23e05000
close(3</usr/lib/x86_64-linux-gnu/libc.so.6>) = 0
```

Let's explain what happens here:

- Block [1]:
This block checks for any libraries that should be "pre-loaded", even before the glibc. The return code of the `access` is -1, signaling that there are not shared libraries to be pre-loaded.  
We talk about this pre-loading a bit more in-depth later on.

- Block [2]:
The gist here is the presence of `ld.so.cache` file. This file is a cache file that contains entries in the form of: `library --> path/of/the/lib/in/filesystem`.  
This file is constructed at boot and can be inspected via command `ldconfig -p` (requires root permissions):

```bash
# ldconfig -p | head
627 libs found in cache `/etc/ld.so.cache'
        libz3.so.4 (libc6,x86-64) => /lib/x86_64-linux-gnu/libz3.so.4
        libz3.so (libc6,x86-64) => /lib/x86_64-linux-gnu/libz3.so
        libzstd.so.1 (libc6,x86-64) => /lib/x86_64-linux-gnu/libzstd.so.1
        libz.so.1 (libc6,x86-64) => /lib/x86_64-linux-gnu/libz.so.1
        libz.so (libc6,x86-64) => /lib/x86_64-linux-gnu/libz.so
        libyuv.so.0 (libc6,x86-64) => /lib/x86_64-linux-gnu/libyuv.so.0
        libyaml-0.so.2 (libc6,x86-64) => /lib/x86_64-linux-gnu/libyaml-0.so.2
        libyajl.so.2 (libc6,x86-64) => /lib/x86_64-linux-gnu/libyajl.so.2
        libxxhash.so.0 (libc6,x86-64) => /lib/x86_64-linux-gnu/libxxhash.so.0
```

We see in the block that the ld.cs.cache file is [`mmaped`](https://en.wikipedia.org/wiki/Memory-mapped_file) which is mostly for convenience and effeciency to not have to go through the filesystem and instead directly access the cache from memory.

- Block [3]:
You may have spotted here the presence of `libc.so.6`. This is actually the C library on my system.
After it has been found in cache at the previous step, the C library file is opened, it is given file descriptor 3 which is being used for the rest of the loading sequence before closing it.

After reading headers and metadata of the library file, it is then mmaped in memory on different segments:

```bash
mmap(NULL, 2170256, PROT_READ, MAP_PRIVATE|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0) = 0x7a6f23c00000
mmap(0x7a6f23c28000, 1605632, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x28000) = 0x7a6f23c28000
mmap(0x7a6f23db0000, 323584, PROT_READ, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x1b0000) = 0x7a6f23db0000
mmap(0x7a6f23dff000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3</usr/lib/x86_64-linux-gnu/libc.so.6>, 0x1fe000) = 0x7a6f23dff000
mmap(0x7a6f23e05000, 52624, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7a6f23e05000
```

The 1st mmap: loads the entire library in memory in read-only so the loader can read headers, symbols and ata.  
The 2nd mmap: loads the .text segment (executable code) starting from the virtual address (first argument) at a given offset.  
The 3rd mmap: loads constants, string literals and read-only globals
The 4th mmap: loads global variables and writable memory inside libc: env variables, memory for mallocs (arenas)...
The 5th mmap: anonymous mapping which is writable, mainly for runtime structures needed by glibc.

The linker part is done now, the runtime setup proceeds as is done for the statically linked program, and executes the print instruction, with some slight modification in the dynamically linked program due to how the libraries are being referenced (embeded in the program binary in static, referenced in dynamic).

## Hacking with LD_PRELOAD

Now comes the fun part ! We discussed previously the first block where we attempt to "pre-load" some libraries.
Turns out, we can provide additional libraries to our program via the LD_PRELOAD env variable.
These libraries are added on runtime by the linker and their definitions are taken into account before any other library down the chain. Let's illustrate this with an example:

Let's keep our same C program as before:

```c
#include <stdio.h>

int main() {
    printf("Hello World");

    return 0;
}
```

On this program, we will call a simple function that does addition:

```c
#include <stdio.h>

int main() {
    int result = add(2, 3);
    printf("Result: %d\n", result);

    return 0;
}
```

This however returns a compile error, as the program doesn't know where this `add` comes from:

```bash
➜ gcc -o main main.c
main.c: In function ‘main’:
main.c:4:18: warning: implicit declaration of function ‘add’ [-Wimplicit-function-declaration]
    4 |     int result = add(2, 3);
      |                  ^~~
/usr/bin/ld: /tmp/ccjzQvUL.o: in function `main':
main.c:(.text+0x1c): undefined reference to `add'
collect2: error: ld returned 1 exit status
```

We will define it (without implementing it) and mark it as external to hint to the compiler that this function exists somewhere and that it will be resolved at link time:

```c
#include <stdio.h>

extern int add(int a, int b);

int main() {
    int result = add(2, 3);
    printf("Result: %d\n", result);

    return 0;
}
```

We will also define a dummy function `add` on another library that we will compile and link to the main. This is needed as the add symbol is defined in main but needs to point to something (instead of pointing to nothing which will result in a segfault when calling it).

```bash
# The dummy library
➜ cat libdummy.c 
int add(int a, int b) { return 0; }

➜ gcc -shared -fPIC -o libdummy.so libdummy.c

➜ gcc -o main main.c ./libdummy.so
```

Now we run our main, as the add call comes from a dummy library, it should return 0 (while the actual result should be 5):

```bash
➜ ./main
Result: 0
```

Let's now use LD_PRELOAD: We will pre-load a library that will supersede any other function definition in other libraries invoked by the program.
We will define our preloaded library as such:

```c
#include <stdio.h>

// This is our dummy function
int add(int a, int b) {
    printf("[LD_PRELOAD] add called with %d + %d\n", a, b);
    return a + b;
}

// Optional constructor to run when the library is loaded
__attribute__((constructor))
void init() {
    printf("[LD_PRELOAD] Library loaded!\n");
}
```

What we should observe, is this add call by our library being called once it is preloaded (the print statement should be ran):
We compile, pre-load and run again the main:

```bash
➜ gcc -shared -fPIC -o libadd.so libadd.c
➜ LD_PRELOAD=./libadd.so ./main
[LD_PRELOAD] Library loaded!
[LD_PRELOAD] add called with 2 + 3
Result: 5
```

Bingo ! Our pre-loaded library code has superseded the calls and ran crafted `add` function.

### Usefulness of LD_PRELOAD

If LD_PRELOAD can specify libraries that we wish to load first, how is this useful ?

Turns out, this is plenty useful to override behavior of some calls in libraries, especially system calls.
Valgrind is known for making heavy use of a similar mechanism to LD_PRELOAD to instrument certain calls (such as mallocs) to keep track of memory allocations.

One could even think of hijacking some special system calls and modify their behavior, for instance the `getaddrinfo` call which is used to resolve hostnames to addresses could be hijacked to explictely resolve certain hosts to wanted ip addresses.
