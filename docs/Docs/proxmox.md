# Docs: Proxmox

Hardware used for reference: Lenovo thinkcentre tiny m720q with i5-8500T and 32gb of RAM

## Disabling checksum offloading

- **TCP checksum**: A 16-bit field in the TCP header used for error-checking of the latter, the payload and an IP pseudo-header.
The IP pseudo-header consists of source IP addr, destination IP addr, the protocol number of the TCP protocol (6) and the length of TCP headers and payload (in bytes). [Source](https://en.wikipedia.org/wiki/Transmission_Control_Protocol#Error_detection)
- **TCP checksum offloading**: Offloading consists of hardware assistance to automatically compute the checksum in the network adapter prior to transmission/reception to/from the network. The intention is to relieve the OS from using CPU cycles for this and thus increasing performance
This can be problematic if packets are intercepted before being transmitted by the network adapter; Some packet analyzers which intercept packets might report invalid checksums in outbound packets which have not yet reached the network adapter.
This issue also occurs in virtualized environments where a virtual device driver may omit the checksum calculation (as an optim), knowing that the calculation will be later done by the VM host kernel or its physical hardware. [source](https://en.wikipedia.org/wiki/Transmission_Control_Protocol#Checksum_offload)

To disable it, get the network interface which you're using, and run the following command:
```bash
ethtool -K <INTERFACE_NAME> gso off gro off tso off tx off rx off rxvlan off txvlan off sg off
```

You can persist it by writing in `/etc/network/interfaces`:
```bash
auto <INTERFACE_NAME>
iface <INTERFACE_NAME> inet static
  offload-gso off
  offload-gro off
  offload-tso off
  offload-rx off
  offload-tx off
  offload-rxvlan off
  offload-txvlan off
  offload-sg off
  offload-ufo off
  offload-lro off
  address x.x.x.x
  netmask a.a.a.a
  gateway z.z.z.z
```

## Troubleshooting rrdcached issue causing Proxmox node in a cluster to randomly become unreachable:

When running a Proxmox cluster, nodes would sometimes streaming this error:
```
2024-10-19T11:34:38.064395+02:00 pve1 rrdcached[875]: handle_request_update: Could not read RRD file.
2024-10-19T11:34:38.064470+02:00 pve1 pmxcfs[895]: [status] notice: RRDC update error /var/lib/rrdcached/db/pve2-storage/pve1/local: -1
2024-10-19T11:34:38.064507+02:00 pve1 pmxcfs[895]: [status] notice: RRD update error /var/lib/rrdcached/db/pve2-storage/pve1/local: mmaping file '/var/lib/rrdcached/db/pve2-storage/pve1/local': Invalid argument
```

This usually means that the time of a node is out of sync or/and in the future.

A simple solution would be to [delete the RRD cache directory restart the service](https://forum.proxmox.com/threads/strange-rrd-error.102139/):
However, perfomance graphs are lost with this manipulation.
```bash
rm -r /var/lib/rrdcached/db
systemctl restart rrdcached.service 
```
