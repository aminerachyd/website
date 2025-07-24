# Linux

## systemd explained

Notes from (this video)[https://www.youtube.com/watch?v=Kzpm-rGAXos].

The init system manages all services that run in the background.  

### Units
Unit: anything systemd can manage, for example: service, timers, mounts, automounts...

Some commands to manage services:
```bash
# To inspect running services:
systemctl status

# To restart a service (requires sudo)
systemctl restart httpd

# To start/stop a service (requires sudo)
systemctl start/stop httpd

# To enable/disable a service to start automatically (requires sudo)
systemctl enable/disable httpd
```

### systemd file structure

Service files can be found on:
- /etc/systemd/system => For manually installed units
- /run/systemd/system => For runtime system units
- /lib/systemd/system => For installed service files; if a package comes with a service file. Not advised to be modified manually as they could be overwritten by the package manager

The previous ordering determines priority of unit files to be started by systemd.

### systemd unit file structure

The file is case sensitive.  
3 primary sections:
- Unit: General info about the unit
  - Description: What the unit is for
  - Wants: Pre-req unit that is required before this unit can start up
  - After: Determines the order of pre-req units
  - Documentation: Doc source of the unit
- Service: Configuration specific to service files
  - Type: simple/notify: default service type. How systemd should assume if a system is running (simple: no assumption, notify: the program talks to systemd)
  - ExecStart: What happens when process is started up
  - ExecStop: What happens when process is stopped
  - ExecReload: What happens when process is reloaded (sudo systemctl reload), not a full restart of the service. Reload configuration changes. Not always available in services
- Install: Not required, what happens when a unit file is enabled/disabled
  - WantedBy: Dependency relationship. 

### Customizing unit files

- Overriding an existing system file
```bash
systemctl edit httpd.service
```
Creates an override file in /etc/systemd/sytem/httpd.service.d/ (remember the priority).
Make sure to edit before the discarding line.
To undo the change, simply rm the override file.

To start with the entire service file, instead of an empty override:
```bash
systemctl edit --full httpd.service
```
This time, the new file is stored directly as /etc/systemd/system/http.service.

### Reloading services

This will reload systemd to take into account all changes that we made in unit files.
Any time we make changes to a unit file:
```bash
systemctl daemon-reload
```

## Route DNS requests of a subdomain to a specific DNS server

Using systemd-resolved, you can create a file under `/etc/systemd/resolved/resolved.conf.d/`, call it `custom.conf`.
In this file, add the following:
```toml title="/etc/systemd/resolved/resolved.conf.d/custom.conf"
[Resolve]
Domains=~<SUBDOMAIN>
DNS=<YOUR_DNS_SERVER_IP>
```
This will route all DNS requests to domain matching the pattern `*.<SUBDOMAIN>` to your server.  
Restart systemd-resolved service to reload the configuration:
```bash
sudo systemctl restart systemd-resolved
```
---
## Allow Discord to start without checking updates

Useful when the version in the package manager isn't yet up to date with the latest release. Add the following line in `~/.config/discord/settings.json`:
```json title="~/.config.discord/settings.json"
SKIP_HOST_UPDATE: true
```
---
## Too many open files - Failed to initialize inotify

You can do an ad-hoc raise of the `max_user_instances` parameter:
```bash
echo 256 | sudo tee /proc/sys/fs/inotify/max_user_instances # (1)! 
```

1. You can put a higher value than 256 if needed

You can also persist this configuration by adding a configuration file under `/etc/sysctl.d/`, call it `custom.conf` with the following line:
```bash title="/etc/sysctl.d/custom.conf"
fs.inotify.max_user_instances = 256 
```
---
## Force dark mode on GTK-3 applications in Gnome DE

Add the following line in your `~/.config/gtk-3.0/settings.ini` file (or create it if it doesn't exist):
```bash title="~/.config/gtk-3/settings.ini"
[Settings]
gtk-application-prefer-dark-theme=1
```

---
## Select power usage profiles using TuneD

You can verify if TuneD is running via the command
```bash
systemctl status tuned
```

You can check the available profiles (and the current one) in TuneD by running the command
```bash
tuned-adm profile
```

To set a profile, use the following command (will require admin privilege)
```bash
tuned-adm profile <PROFILE_NAME>
```

---
## Syscalls tracing 
Note: `strace` prints its output to stderr to avoid mixing it with the output of the *traced command*, we need to forward that output to stdout

- Trace filesystem syscalls, replacing all file descriptors by file paths and grepping:
```bash
strace -fyrt touch myfile 2>&1 | grep myfile
```

---
## Extract text from a variable

```bash
$ TOTO=ref/tag/1.2.3
$ echo ${TOTO#ref/*/} # This pattern-matches the variable and extracts the remaining text
1.2.3
```

---
## Resize (extend) disk

```bash
lsblk # find which disk you want to extend
growpart /dev/<DISK_NAME> <PARTIITON_NO>
resize2fs /dev/<DISK_NAME_PARTITION_NO>
```

---
## Memory diagnosys tools

Miscellanous stuff noted from [this video](https://www.youtube.com/watch?v=HdM04UBNcgE).
`free`:
```bash
# This is printed in mebibytes
~ free -h
               total        used        free      shared  buff/cache   available
Mem:            15Gi       2.9Gi        12Gi        15Mi       470Mi        12Gi
Swap:          4.0Gi          0B       4.0Gi
```

`vmstat`:
```bash
# Gives slightly more info compared to free
# Info about swap space, io and cpu load
~ vmstat
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 0  0      0 12775648  16132 465752    0    0   150    71  186    0  0  0 100  0  0  0

# Run vmstat 3 times every 2 seconds
~ vmstat 2 3
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 0  0      0 12767436  16812 465808    0    0   148    71  197    0  0  0 100  0  0  0
 0  0      0 12768672  16820 465800    0    0     0   212  656 1491  0  0 99  0  0  0
 0  0      0 12765212  16820 465808    0    0     0    60  709 1608  0  0 100  0  0  0
```

`ps`:
```bash
# Shows all the processes, users running them and extended informations
# Some fields:
# - VSZ: virtual memory size, virtual memory allocated but not necessary all of it is used
# - RSS: resident set size, an estimate of the amount of the physical memory used by a process. This is an estimate as shared libraries are counted for each process, even though they may be loaded only once.
~ ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0  22404 13492 ?        Ss   18:53   0:00 /sbin/init
root           2  0.0  0.0   2616  1444 ?        Sl   18:53   0:00 /init
[...]
```

`top`:
Press 1 to print info about all cores load.  
Interesting fields for memory are VIRT (vm), RES (RSS), SHR (shared memory).  

`swapon`:
```bash
# Show all swap disks and their usage
~ swapon
NAME      TYPE SIZE USED PRIO
/var/swap file 512M   0B   -2

~ swapon -s
Filename                                Type            Size            Used            Priority
/var/swap                               file            524272          0               -2
```

