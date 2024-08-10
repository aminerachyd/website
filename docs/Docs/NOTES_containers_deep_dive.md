# Notes: Linux container primitives

These are notes taken from [this video](https://www.youtube.com/watch?v=x1npPrzyKfs).
The demos are done via Docker, the notes here are using Podman instead.

Containers are a combination of some Linux primitives:
 - Namespaces 
 - Control groups
 - Union filesystem

## Control groups (cgroups)

Organize and track processes in a system. Used to track resource usage of a group of processes.  
We can limit or prioritize resource utilization with cgroups.  
Control groups is an framework, implemented by concrete subsystems:
 - Memory
 - CPU time
 - Block I/O
 - Devices
 - Network priority
 - pids

These are resource controllers: they can track or limit resources for the processes.

The controllers are independent and can organize processes separately: ie. 1 CPU cgroup for 2 processes, but 2 memory cgroups for the 2 processes

The cgroups subsystems arrage processes in a hierarchy, each subsystem has an independent hierarchy, each process is represented with one cgroup within a subsystem hierarchy.

When a new process is started, it begins in the new cgroup as its parent.

Cgroup interaction can be done via virtual filesystem mounted on **/sys/fs/cgroup**. **tasks** virtual file holds all pids in the cgroup. Other files have settings and utilization data.
  - The dir structure is /sys/fs/cgroup/<SUBSYSTEM>
  - The structure is a hierarchy, we can have the root cgroup (located at the top of the <SUBSYSTEM> directory) and child cgroups (directories under <SUBSYSTEM>)
  - Each **task** file for a given cgroup (subsystem) contains all pids of processes in it. Moving a process to another cgroup is equivalent to writing its pid in the target cgroup.

### Demo
```bash
ls /sys/fs/cgroup/devices

cgroup.clone_children  dev-hugepages.mount  devices.deny  notify_on_release              sys-kernel-debug.mount    tasks
cgroup.procs           dev-mqueue.mount     devices.list  release_agent                  sys-kernel-tracing.mount  user.slice
cgroup.sane_behavior   devices.allow        init.scope    sys-fs-fuse-connections.mount  system.slice
```

Files that control how cgroup subsystem is configured, prefixed with cgroup.  
Files related with devices, related to devices.  
Tasks has the pids that are associated to this cgroup.  

```bash
# Special variable that returns the pid of the current shell
$ echo $$ 
5625

# Info about what cgroups the 5625 process is associated to
$ cat /proc/5625/cgroup  
15:name=systemd:/
14:misc:/
13:rdma:/
12:pids:/
11:hugetlb:/
10:net_prio:/
9:perf_event:/
8:net_cls:/
7:freezer:/
6:devices:/
5:memory:/
4:blkio:/
3:cpuacct:/
2:cpu:/
1:cpuset:/
0::/
```

We can create a new cgroup subsystem:
```bash
$ sudo mkdir /sys/fs/cgroup/pids/lfnw
$ ls /sys/fs/cgroup/pids/lfnw # Files created automatically
cgroup.clone_children  cgroup.procs  notify_on_release  pids.current  pids.events  pids.max  tasks

# Move the current process in that cgroup
$ echo $$ | sudo tee /sys/fs/cgroup/pids/lfnw/tasks
15:name=systemd:/
14:misc:/
13:rdma:/
12:pids:/lfnw # <<<< Here
11:hugetlb:/
10:net_prio:/
9:perf_event:/
8:net_cls:/
7:freezer:/
6:devices:/
5:memory:/
4:blkio:/
3:cpuacct:/
2:cpu:/
1:cpuset:/
0::/

# Echoing the content of the tasks file for this cgroup
$ cat /sys/fs/cgroup/pids/lfnw/tasks
5625  # This is our shell
7606  # This is the pid the of the cat command, as its created by the shell it inherits its cgroups. This pid changes everytime

# The pid cgroup controls the number of processes that are running in a cgroup
# The max can be checked at the pid.max file in the cgroup
# Changing the max value to 3
$ echo 3 | sudo tee /sys/fs/cgroup/pids/lfnw/pids.max

# Running more than 3 processes, the resource is no longer available:
$ $(cat /sys/fs/cgroup/pids/lfnw/tasks) # Runs another shell with a cat command
bash: fork: retry: Resource temporarily unavailable
```

Checking cgroups in a container:
```bash
$ sudo podman run --rm -it --cpu-shares 256 ubuntu # Going with sudo as resource limits isn't supported with non-privileged users in podman
root@24fce7291bc6:/# cat /sys/fs/cgroup/cpu/cpu.shares
256

# In the host, checking the cgroups of the running container:
$ cat /proc/9314/cgroup
15:name=systemd:/machine.slice/libpod-conmon-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope
14:misc:/
13:rdma:/
12:pids:/machine.slice/libpod-conmon-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope
11:hugetlb:/
10:net_prio:/
9:perf_event:/
8:net_cls:/
7:freezer:/
6:devices:/machine.slice
5:memory:/machine.slice/libpod-conmon-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope
4:blkio:/
3:cpuacct:/
2:cpu:/machine.slice/libpod-conmon-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope
1:cpuset:/
0::/machine.slice/libpod-conmon-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope

# In podman, the cgroups in the pods arent the same as the one viewed from the host:
root@24fce7291bc6:/# cat /proc/1/cgroup
15:name=systemd:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope
14:misc:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
13:rdma:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
12:pids:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
11:hugetlb:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
10:net_prio:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
9:perf_event:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
8:net_cls:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
7:freezer:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
6:devices:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
5:memory:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
4:blkio:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
3:cpuacct:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
2:cpu:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
1:cpuset:/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
0::/machine.slice/libpod-24fce7291bc6d7f8a5965a5920740b0df25dda9bb4e84ffb889d8ea2927acec5.scope/container
```

References: linux kernel source Documentation/cgroup-v1

## Namespaces

Isolation of a resource, they control visibility of a resource.  
Changes to a resources within a namespace are invisible outside the namespace.  
Resources can be mapped with permission changes.  

Resources are (include?):
- Network
- Filesystem (mounts)
- Processes (pid)
- Inter process communication (ipc)
- Hostname and domain name (uts)
- User and group IDs
- cgroup
- time

Like cgroups, namespaces are independent and can be shared.

### The network namespace

Frequently used in containers.  
The network ns gives a process a separate view of the network, with different network interfaces and routing rules.  
Network namespaces can be connected together using a virtual ethernet device pair (veth).  
For instance, Docker uses a separate network namespace **per** container (same network namespace on containers running on the same Docker network ?)

Kubernetes pods: containers share the same network namespace

### The mount namespace

Used for giving containers their own filesystem.  
Container image is mounted as the root filesystem.  
"Volumes" are mounts in the container filesystem to share data. 

- The procfs virtual filesystem gives information about the namespace of a process
  The files are symlinks to the namespace. The link containers the namespace type and the inode number to identify the namespace:
```bash
$ readlink /proc/$$/ns/*
cgroup:[4026531835]
ipc:[4026532381]
mnt:[4026532379]
net:[4026532264]
pid:[4026532382]
pid:[4026532382]
time:[4026531834]
time:[4026531834]
user:[4026531837]
uts:[4026532380]
```
- Creating namespaces, two available syscalls: clone(2) and unshare(2).
  clone: is for new processes to create new namespaces, behavior controlled with CLONE_NEW* flags
  unshare: is for existing processes to create new namespaces.

- Namespaces can't be empty, they automatically close when nothing is occupying them.
  Either there is a running process, or a bindmount

- Entering a namespace through setns(2) syscall:
    - Open a file from /proc/$$/ns (or a bindmount) and get the FD.
    - The FD is given to setns as an identifier of the namespace.
    - Once the process moves to a ns, it holds the namespace open even if the bindmount goes away
    - nsenter(1) is a command that does this
    - ip-netns(8) for network Namespaces

### Demo

- Network namesapce
```bash
$ ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:15:5d:08:49:b6 brd ff:ff:ff:ff:ff:ff

# Create a new network namespace, we see different interfaces
# This lo is different from the one above in the host
# This namespace is not persisted as the ip command runs and exits, so nothing holds the namespace alive
$ sudo unshare --net ip link
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00

$ sudo unshare --net bash
# To check then namespaces of this process
 readlink /proc/$$/ns/*
cgroup:[4026531835]
ipc:[4026532242]
mnt:[4026532253]
net:[4026532262]
pid:[4026532255]
pid:[4026532255]
time:[4026531834]
time:[4026531834]
user:[4026531837]
uts:[4026532254]

# To keep this namespace alive, create a bindmount
$ touch /var/run/netns/lfnw # Create a file, whenever you want
$ mount --bind /proc/$$/ns/net /var/run/netns/lfnw # bind mount the namespace 

# List the persistent namespace
$ ip netns list
lfnw
$ ip netns identify $$
lfnw

# Back to host, the ip netns list command still lists the namesapce, but the identify doesn't return it as the process isnt running on that ns 
# To exec a command on that ns
$ sudo ip netns exec lfnw ip link
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00

```
- Network ns investigation when podman:
```bash
# Run a podman container
$ podman run --rm -it ubuntu

# Get PID of running container
$ podman ps --ns

# Inside container, check network interfaces
$ ifconfig

tap0: flags=67<UP,BROADCAST,RUNNING>  mtu 65520
        inet 10.0.2.100  netmask 255.255.255.0  broadcast 10.0.2.255

# Inside host, network interfaces are different
# But we can enther the network namespace of that process and we see a similar output
$ sudo nsenter --target 6377 --net ip addr
2: tap0: <BROADCAST,UP,LOWER_UP> mtu 65520 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether 8a:7d:86:2f:e9:73 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.100/24 brd 10.0.2.255 scope global tap0

# Running Nginx in the container network namespace. The binary is located on the host
$ sudo nsenter --target 6377 --net nginx
$ curl localhost 
curl: (7) Failed to connect to localhost port 80 after 0 ms: Couldn't connect to server

# But inside the container, Nginx is running
root@675244b2d08d:/# ifconfig
tap0: flags=67<UP,BROADCAST,RUNNING>  mtu 65520
        inet 10.0.2.100  netmask 255.255.255.0  broadcast 10.0.2.255

root@675244b2d08d:/# curl -ki localhost
HTTP/1.1 200 OK
```

- Mount namespace, running a binary that doesn't exist on the host:

```bash
# Running a redis container
$ podman run --name redis -d docker.io/redis:latest

# Using the mount namespace, we can run the binary from the container on the host
$ sudo nsenter --target 14350 --mount /usr/local/bin/redis-server

# Redis is working, we can ping it from the host
$ telnet localhost 6379
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
PING
+PONG
QUIT
```

References: man 7 {namespaces, pid_namespaces, user_namespaces}

## Images, layers, union filesystems

- Images are representations of a filesystem
- Images are COW layers
  - Each layer represents a "state" of the filesystem
  - The most upper layer is RW, the rest are RO
  - When a file is modified, it is moved to the upper layer 
    - The modified file "hides" the original file
  - Deleted files are hidden on the upper layer, but still exist underneath 

- Layers are implemented as union of two (or more) filesystems
  - Union filesystem provides a mechanism for having a merged view of files and dirs
  - Efficient use of storage: Add a new layer with the minor changes instead of copying the whole image
  - The image isn't duplicated per container. We add a separate empty RW layer for each container, it serves as its own writable space

### Overlay filesystem

Idea: Joins two directories (upper and lower) to form a union

- Uses file name to describe the files
- When writing to overlay:
  - `lowerdir` is not modified, all changes go the `upperdir`
  - Exisitng files are copied-up to `upperdir` for modification
  - The whole file is copied, not just blocks
- Deleting a file in `upperdir` creates a whiteout
  - Files: character devices with 0/0 device number
  - Directories: xattr "trusted.overlay.opaque" set to "y"
- Overlay filesystems can be created with mount, need to specify a lowerdir, and upperdir and a workdir (for making diffs)
  - An upperdir can have multiple lowerdirs (arguments of the overlay fs when viewing it with mount command)

Both podman and docker use overlay.  
Podman writes overlay filesystmes: `~/.local/share/containers/storage/overlay`  
The upperdir is the final filesystem as seen by the container. Writing to the upperdir is equal to writing to the filesystem.  
Writing to a lowerdir can make the files appear on the upperdir (and on the container filesystem, but it can break image immutability)


### Demo

```bash
# Pulling an image via podman, the image is stored under either:
# - /var/lib/containers/storage/overlay-images
# - ~/.local/share/containers/storage/overlay-images
# The manifest is located under overlay-images/<IMAGE_SHA>/manifest
```

Creating an image with multiple layers:
```bash
# Dockerfile content:
FROM docker.io/amazonlinux:latest 
RUN echo "hello world" > hello
RUN rm hello

# Building with podman
$ podman build . -t testigm
STEP 1/3: FROM docker.io/amazonlinux:latest
STEP 2/3: RUN echo "hello world" > hello
--> 103f5229ccd1
STEP 3/3: RUN rm hello
COMMIT testigm
--> 96e54cbfdcff
Successfully tagged localhost/testigm:latest
96e54cbfdcffd79cd6ff5101e803e4de591bba470bc0b84a8e510dd756b34fa9

# A new dir appears in .local/share/containers/storage/overlay-images as the sha256
# We can inspect the manifest of the image once in the dir, it specifies the 3 layers that we used to build the image:
$ cat manifest | jq
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:96e54cbfdcffd79cd6ff5101e803e4de591bba470bc0b84a8e510dd756b34fa9",
    "size": 1045
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar",
      "digest": "sha256:1e77abe38bf5b2878033a52eb815add929f7482fc4294e037046763869456f20",
      "size": 149324800
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar",
      "digest": "sha256:ae57448bec90750d1356e8465243a21edfba275ddbd1f3a96558920bd7e40f6a",
      "size": 6144
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar",
      "digest": "sha256:137f616da8feed3714cc44dc1dc2e36c61c85adcbb347f62a293daed85433ebe",
      "size": 3072
    }
  ],
  "annotations": {
    "org.opencontainers.image.base.digest": "sha256:130e2b842304783d910b17355968b433b99ad6a8eb2ecd0fcc31c6b995c9f110",
    "org.opencontainers.image.base.name": "docker.io/library/amazonlinux:latest"
  }
}
```

## Container runtimes

- Tools that configure linux primitives to run containers
- runc is the ref impl of OCI spec
- The containre spec consists of a Filesystem (overlay or anything else) and a bundle (JSON file that contains info about the filesystem, cgroups, namespaces, capabilities...)

```bash
# Checking the container bundle

$ podman run -it --rm ubuntu
$ cat ~/.local/share/containers/storage/overlay-containers/d68bb5eb632fbce02efb011a792f33b919ff99f7203ede78a7b7359b443da12a/userdata/config.json| jq | less
```

The result:
```json
{
  "ociVersion": "1.1.0",
  "process": {
    "terminal": true,
    "user": {
      "uid": 0,
      "gid": 0,
      "umask": 18
    },
    "args": [
      "/bin/bash"
    ],
    "env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
      "container=podman",
      "TERM=xterm",
      "HOME=/root",
      "HOSTNAME=d68bb5eb632f"
    ],
    "cwd": "/",
    "capabilities": {
      "bounding": [
        "CAP_CHOWN",
        "CAP_DAC_OVERRIDE",
        "CAP_FOWNER",
        "CAP_FSETID",
        "CAP_KILL",
        "CAP_NET_BIND_SERVICE",
        "CAP_SETFCAP",
        "CAP_SETGID",
        "CAP_SETPCAP",
        "CAP_SETUID",
        "CAP_SYS_CHROOT"
      ],
      "effective": [
        "CAP_CHOWN",
        "CAP_DAC_OVERRIDE",
        "CAP_FOWNER",
        "CAP_FSETID",
        "CAP_KILL",
        "CAP_NET_BIND_SERVICE",
        "CAP_SETFCAP",
        "CAP_SETGID",
        "CAP_SETPCAP",
        "CAP_SETUID",
        "CAP_SYS_CHROOT"
      ],
      "permitted": [
        "CAP_CHOWN",
        "CAP_DAC_OVERRIDE",
        "CAP_FOWNER",
        "CAP_FSETID",
        "CAP_KILL",
        "CAP_NET_BIND_SERVICE",
        "CAP_SETFCAP",
        "CAP_SETGID",
        "CAP_SETPCAP",
        "CAP_SETUID",
        "CAP_SYS_CHROOT"
      ]
    },
    "rlimits": [
      {
        "type": "RLIMIT_NOFILE",
        "hard": 1048576,
        "soft": 1048576
      },
      {
        "type": "RLIMIT_NPROC",
        "hard": 63327,
        "soft": 63327
      }
    ]
  },
  "root": {
    "path": "/home/amine/.local/share/containers/storage/overlay/be729ba6e49a874d1885e37535661f2e89461c7c0c4f51942ef964218a5123ad/merged"
  },
  "hostname": "d68bb5eb632f",
  "mounts": [
    {
      "destination": "/proc",
      "type": "proc",
      "source": "proc",
      "options": [
        "nosuid",
        "noexec",
        "nodev"
      ]
    },
    {
      "destination": "/dev",
      "type": "tmpfs",
      "source": "tmpfs",
      "options": [
        "nosuid",
        "strictatime",
        "mode=755",
        "size=65536k"
      ]
    },
    {
      "destination": "/sys",
      "type": "sysfs",
      "source": "sysfs",
      "options": [
        "nosuid",
        "noexec",
        "nodev",
        "ro"
      ]
    },
    {
      "destination": "/dev/pts",
      "type": "devpts",
      "source": "devpts",
      "options": [
        "nosuid",
        "noexec",
        "newinstance",
        "ptmxmode=0666",
        "mode=0620",
        "gid=5"
      ]
    },
    {
      "destination": "/dev/mqueue",
      "type": "mqueue",
      "source": "mqueue",
      "options": [
        "nosuid",
        "noexec",
        "nodev"
      ]
    },
    {
      "destination": "/etc/hostname",
      "type": "bind",
      "source": "/run/user/1002/containers/overlay-containers/d68bb5eb632fbce02efb011a792f33b919ff99f7203ede78a7b7359b443da12a/userdata/hostname",
      "options": [
        "bind",
        "rprivate"
      ]
    },
    {
      "destination": "/etc/resolv.conf",
      "type": "bind",
      "source": "/run/user/1002/containers/overlay-containers/d68bb5eb632fbce02efb011a792f33b919ff99f7203ede78a7b7359b443da12a/userdata/resolv.conf",
      "options": [
        "bind",
        "rprivate"
      ]
    },
    {
      "destination": "/etc/hosts",
      "type": "bind",
      "source": "/run/user/1002/containers/overlay-containers/d68bb5eb632fbce02efb011a792f33b919ff99f7203ede78a7b7359b443da12a/userdata/hosts",
      "options": [
        "bind",
        "rprivate"
      ]
    },
    {
      "destination": "/dev/shm",
      "type": "bind",
      "source": "/home/amine/.local/share/containers/storage/overlay-containers/d68bb5eb632fbce02efb011a792f33b919ff99f7203ede78a7b7359b443da12a/userdata/shm",
      "options": [
        "bind",
        "rprivate",
        "nosuid",
        "noexec",
        "nodev"
      ]
    },
    {
      "destination": "/run/.containerenv",
      "type": "bind",
      "source": "/run/user/1002/containers/overlay-containers/d68bb5eb632fbce02efb011a792f33b919ff99f7203ede78a7b7359b443da12a/userdata/.containerenv",
      "options": [
        "bind",
        "rprivate"
      ]
    },
    {
      "destination": "/sys/fs/cgroup",
      "type": "cgroup",
      "source": "cgroup",
      "options": [
        "rprivate",
        "nosuid",
        "noexec",
        "nodev",
        "relatime",
        "ro"
      ]
    }
  ],
  "annotations": {
    "io.container.manager": "libpod",
    "io.podman.annotations.autoremove": "TRUE",
    "org.opencontainers.image.stopSignal": "15"
  },
  "linux": {
    "sysctl": {
      "net.ipv4.ping_group_range": "0 0"
    },
    "resources": {},
    "namespaces": [
      {
        "type": "pid"
      },
      {
        "type": "network",
        "path": "/run/user/1002/netns/netns-49f4f7ac-3b34-bcb1-be08-0fc868bacb55"
      },
      {
        "type": "ipc"
      },
      {
        "type": "uts"
      },
      {
        "type": "mount"
      }
    ],
    "seccomp": {
      "defaultAction": "SCMP_ACT_ERRNO",
      "defaultErrnoRet": 38,
      "architectures": [
        "SCMP_ARCH_X86_64",
        "SCMP_ARCH_X86",
        "SCMP_ARCH_X32"
      ],
      "syscalls": [
        {
          "names": [
            "bdflush",
            "io_pgetevents",
            "kexec_file_load",
            "kexec_load",
            "migrate_pages",
            "move_pages",
            "nfsservctl",
            "nice",
            "oldfstat",
            "oldlstat",
            "oldolduname",
            "oldstat",
            "olduname",
            "pciconfig_iobase",
            "pciconfig_read",
            "pciconfig_write",
            "sgetmask",
            "ssetmask",
            "swapcontext",
            "swapoff",
            "swapon",
            "sysfs",
            "uselib",
            "userfaultfd",
            "ustat",
            "vm86",
            "vm86old",
            "vmsplice"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "_llseek",
            "_newselect",
            "accept",
            "accept4",
            "access",
            "adjtimex",
            "alarm",
            "bind",
            "brk",
            "capget",
            "capset",
            "chdir",
            "chmod",
            "chown",
            "chown32",
            "clock_adjtime",
            "clock_adjtime64",
            "clock_getres",
            "clock_getres_time64",
            "clock_gettime",
            "clock_gettime64",
            "clock_nanosleep",
            "clock_nanosleep_time64",
            "clone",
            "clone3",
            "close",
            "close_range",
            "connect",
            "copy_file_range",
            "creat",
            "dup",
            "dup2",
            "dup3",
            "epoll_create",
            "epoll_create1",
            "epoll_ctl",
            "epoll_ctl_old",
            "epoll_pwait",
            "epoll_pwait2",
            "epoll_wait",
            "epoll_wait_old",
            "eventfd",
            "eventfd2",
            "execve",
            "execveat",
            "exit",
            "exit_group",
            "faccessat",
            "faccessat2",
            "fadvise64",
            "fadvise64_64",
            "fallocate",
            "fanotify_mark",
            "fchdir",
            "fchmod",
            "fchmodat",
            "fchown",
            "fchown32",
            "fchownat",
            "fcntl",
            "fcntl64",
            "fdatasync",
            "fgetxattr",
            "flistxattr",
            "flock",
            "fork",
            "fremovexattr",
            "fsconfig",
            "fsetxattr",
            "fsmount",
            "fsopen",
            "fspick",
            "fstat",
            "fstat64",
            "fstatat64",
            "fstatfs",
            "fstatfs64",
            "fsync",
            "ftruncate",
            "ftruncate64",
            "futex",
            "futex_time64",
            "futimesat",
            "get_mempolicy",
            "get_robust_list",
            "get_thread_area",
            "getcpu",
            "getcwd",
            "getdents",
            "getdents64",
            "getegid",
            "getegid32",
            "geteuid",
            "geteuid32",
            "getgid",
            "getgid32",
            "getgroups",
            "getgroups32",
            "getitimer",
            "getpeername",
            "getpgid",
            "getpgrp",
            "getpid",
            "getppid",
            "getpriority",
            "getrandom",
            "getresgid",
            "getresgid32",
            "getresuid",
            "getresuid32",
            "getrlimit",
            "getrusage",
            "getsid",
            "getsockname",
            "getsockopt",
            "gettid",
            "gettimeofday",
            "getuid",
            "getuid32",
            "getxattr",
            "inotify_add_watch",
            "inotify_init",
            "inotify_init1",
            "inotify_rm_watch",
            "io_cancel",
            "io_destroy",
            "io_getevents",
            "io_setup",
            "io_submit",
            "ioctl",
            "ioprio_get",
            "ioprio_set",
            "ipc",
            "keyctl",
            "kill",
            "landlock_add_rule",
            "landlock_create_ruleset",
            "landlock_restrict_self",
            "lchown",
            "lchown32",
            "lgetxattr",
            "link",
            "linkat",
            "listen",
            "listxattr",
            "llistxattr",
            "lremovexattr",
            "lseek",
            "lsetxattr",
            "lstat",
            "lstat64",
            "madvise",
            "mbind",
            "membarrier",
            "memfd_create",
            "memfd_secret",
            "mincore",
            "mkdir",
            "mkdirat",
            "mknod",
            "mknodat",
            "mlock",
            "mlock2",
            "mlockall",
            "mmap",
            "mmap2",
            "mount",
            "mount_setattr",
            "move_mount",
            "mprotect",
            "mq_getsetattr",
            "mq_notify",
            "mq_open",
            "mq_timedreceive",
            "mq_timedreceive_time64",
            "mq_timedsend",
            "mq_timedsend_time64",
            "mq_unlink",
            "mremap",
            "msgctl",
            "msgget",
            "msgrcv",
            "msgsnd",
            "msync",
            "munlock",
            "munlockall",
            "munmap",
            "name_to_handle_at",
            "nanosleep",
            "newfstatat",
            "open",
            "open_tree",
            "openat",
            "openat2",
            "pause",
            "pidfd_getfd",
            "pidfd_open",
            "pidfd_send_signal",
            "pipe",
            "pipe2",
            "pivot_root",
            "pkey_alloc",
            "pkey_free",
            "pkey_mprotect",
            "poll",
            "ppoll",
            "ppoll_time64",
            "prctl",
            "pread64",
            "preadv",
            "preadv2",
            "prlimit64",
            "process_mrelease",
            "process_vm_readv",
            "process_vm_writev",
            "pselect6",
            "pselect6_time64",
            "ptrace",
            "pwrite64",
            "pwritev",
            "pwritev2",
            "read",
            "readahead",
            "readdir",
            "readlink",
            "readlinkat",
            "readv",
            "reboot",
            "recv",
            "recvfrom",
            "recvmmsg",
            "recvmmsg_time64",
            "recvmsg",
            "remap_file_pages",
            "removexattr",
            "rename",
            "renameat",
            "renameat2",
            "restart_syscall",
            "rmdir",
            "rseq",
            "rt_sigaction",
            "rt_sigpending",
            "rt_sigprocmask",
            "rt_sigqueueinfo",
            "rt_sigreturn",
            "rt_sigsuspend",
            "rt_sigtimedwait",
            "rt_sigtimedwait_time64",
            "rt_tgsigqueueinfo",
            "sched_get_priority_max",
            "sched_get_priority_min",
            "sched_getaffinity",
            "sched_getattr",
            "sched_getparam",
            "sched_getscheduler",
            "sched_rr_get_interval",
            "sched_rr_get_interval_time64",
            "sched_setaffinity",
            "sched_setattr",
            "sched_setparam",
            "sched_setscheduler",
            "sched_yield",
            "seccomp",
            "select",
            "semctl",
            "semget",
            "semop",
            "semtimedop",
            "semtimedop_time64",
            "send",
            "sendfile",
            "sendfile64",
            "sendmmsg",
            "sendmsg",
            "sendto",
            "set_mempolicy",
            "set_robust_list",
            "set_thread_area",
            "set_tid_address",
            "setfsgid",
            "setfsgid32",
            "setfsuid",
            "setfsuid32",
            "setgid",
            "setgid32",
            "setgroups",
            "setgroups32",
            "setitimer",
            "setns",
            "setpgid",
            "setpriority",
            "setregid",
            "setregid32",
            "setresgid",
            "setresgid32",
            "setresuid",
            "setresuid32",
            "setreuid",
            "setreuid32",
            "setrlimit",
            "setsid",
            "setsockopt",
            "setuid",
            "setuid32",
            "setxattr",
            "shmat",
            "shmctl",
            "shmdt",
            "shmget",
            "shutdown",
            "sigaction",
            "sigaltstack",
            "signal",
            "signalfd",
            "signalfd4",
            "sigpending",
            "sigprocmask",
            "sigreturn",
            "sigsuspend",
            "socketcall",
            "socketpair",
            "splice",
            "stat",
            "stat64",
            "statfs",
            "statfs64",
            "statx",
            "symlink",
            "symlinkat",
            "sync",
            "sync_file_range",
            "syncfs",
            "syscall",
            "sysinfo",
            "syslog",
            "tee",
            "tgkill",
            "time",
            "timer_create",
            "timer_delete",
            "timer_getoverrun",
            "timer_gettime",
            "timer_gettime64",
            "timer_settime",
            "timer_settime64",
            "timerfd",
            "timerfd_create",
            "timerfd_gettime",
            "timerfd_gettime64",
            "timerfd_settime",
            "timerfd_settime64",
            "times",
            "tkill",
            "truncate",
            "truncate64",
            "ugetrlimit",
            "umask",
            "umount",
            "umount2",
            "uname",
            "unlink",
            "unlinkat",
            "unshare",
            "utime",
            "utimensat",
            "utimensat_time64",
            "utimes",
            "vfork",
            "wait4",
            "waitid",
            "waitpid",
            "write",
            "writev"
          ],
          "action": "SCMP_ACT_ALLOW"
        },
        {
          "names": [
            "personality"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [
            {
              "index": 0,
              "value": 0,
              "op": "SCMP_CMP_EQ"
            }
          ]
        },
        {
          "names": [
            "personality"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [
            {
              "index": 0,
              "value": 8,
              "op": "SCMP_CMP_EQ"
            }
          ]
        },
        {
          "names": [
            "personality"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [
            {
              "index": 0,
              "value": 131072,
              "op": "SCMP_CMP_EQ"
            }
          ]
        },
        {
          "names": [
            "personality"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [
            {
              "index": 0,
              "value": 131080,
              "op": "SCMP_CMP_EQ"
            }
          ]
        },
        {
          "names": [
            "personality"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [
            {
              "index": 0,
              "value": 4294967295,
              "op": "SCMP_CMP_EQ"
            }
          ]
        },
        {
          "names": [
            "arch_prctl"
          ],
          "action": "SCMP_ACT_ALLOW"
        },
        {
          "names": [
            "modify_ldt"
          ],
          "action": "SCMP_ACT_ALLOW"
        },
        {
          "names": [
            "open_by_handle_at"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "bpf",
            "fanotify_init",
            "lookup_dcookie",
            "perf_event_open",
            "quotactl",
            "setdomainname",
            "sethostname",
            "setns"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "chroot"
          ],
          "action": "SCMP_ACT_ALLOW"
        },
        {
          "names": [
            "delete_module",
            "finit_module",
            "init_module",
            "query_module"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "acct"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "kcmp",
            "process_madvise"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "ioperm",
            "iopl"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "clock_settime",
            "clock_settime64",
            "settimeofday",
            "stime"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "vhangup"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 1
        },
        {
          "names": [
            "socket"
          ],
          "action": "SCMP_ACT_ERRNO",
          "errnoRet": 22,
          "args": [
            {
              "index": 0,
              "value": 16,
              "op": "SCMP_CMP_EQ"
            },
            {
              "index": 2,
              "value": 9,
              "op": "SCMP_CMP_EQ"
            }
          ]
        },
        {
          "names": [
            "socket"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [
            {
              "index": 2,
              "value": 9,
              "op": "SCMP_CMP_NE"
            }
          ]
        },
        {
          "names": [
            "socket"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [
            {
              "index": 0,
              "value": 16,
              "op": "SCMP_CMP_NE"
            }
          ]
        },
        {
          "names": [
            "socket"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [
            {
              "index": 2,
              "value": 9,
              "op": "SCMP_CMP_NE"
            }
          ]
        }
      ]
    },
    "maskedPaths": [
      "/proc/acpi",
      "/proc/kcore",
      "/proc/keys",
      "/proc/latency_stats",
      "/proc/timer_list",
      "/proc/timer_stats",
      "/proc/sched_debug",
      "/proc/scsi",
      "/sys/firmware",
      "/sys/fs/selinux",
      "/sys/dev/block",
      "/sys/devices/virtual/powercap"
    ],
    "readonlyPaths": [
      "/proc/asound",
      "/proc/bus",
      "/proc/fs",
      "/proc/irq",
      "/proc/sys",
      "/proc/sysrq-trigger"
    ]
  }
}
```

