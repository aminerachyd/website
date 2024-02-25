### Route DNS requests of a subdomain to a specific DNS server

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
### Allow Discord to start without checking updates

Useful when the version in the package manager isn't yet up to date with the latest release. Add the following line in `~/.config/discord/settings.json`:
```json title="~/.config.discord/settings.json"
SKIP_HOST_UPDATE: true
```
---
### Too many open files - Failed to initialize inotify

You can do an ad-hoc raise of the `max_user_instances` parameter:
```bash
echo 256 | sudo tee /proc/sys/fs/inotify/max_user_instances # (1)! 
```

1. You can put a higher value than 256 if needed

You can also persist this configuration by adding a configuration file under `/etc/sysctl.d/`, call it `custom.conf` with the following line:
```bash title="/etc/sysctl.d/custom.conf"
fs.inotify.max_user_instances = 256 
```
