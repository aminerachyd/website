# Proxmox

## VM Management

### Shrink VM Disk Size

Reference [from here](https://forum.proxmox.com/threads/decrease-a-vm-disk-size.122430/post-540307).

This has been used mainly to shrink of a VM template which boots off cloud-init, connect to the PVE hosting the template/VM and run the commands:

```bash
# The wanted should have the unit, for instance 40g
lvm lvreduce -L <WANTED_SIZE> pve/<DISK_NAME>
qm rescan
```

---

## Network Configuration

### Disabling Checksum Offloading

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
  ethtool -K $IFACE gso off gro off tso off tx off rx off rxvlan off txvlan off sg off
```

---

## Troubleshooting & Maintenance

### RRD Cache Issue

When running a Proxmox cluster, nodes would sometimes start streaming this error and become unreachable:

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

---

## GPU Passthrough

### Intel iGPU Passthrough to Virtual Machine

The PCI passthrough setup might highly depend on the hardware you have. My hardware is a Lenovo m720q with an Intel i5-8500T CPU.
This has been tested on Proxmox VE 8.3.2.

### Pre-requisites

Make sure your virtual machine runs on the same firmware as your host. If your host uses UEFI and the VM uses BIOS, this won't work.
To check whether your host is on UEFI mode, just run:

```bash
ls /sys/firmware/efi/
```

If it shows that the directory has content, then your host runs on UEFI.
If your virtual machine happens to run on BIOS, simply update it to use UEFI using the Hardware tab on Proxmox GUI.

### Setup

1. Edit GRUB configuration

Edit the file `/etc/default/grub`, update the line:

```conf
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
```

To:

```conf
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on i915.enable_gvt=1 iommu=pt pcie_acs_override=downstream,multifunction video=efifb:off video=vesa:off vfio_iommu_type1.allow_unsafe_interrupts=1 kvm.ignore_msrs=1 modprobe.blacklist=radeon,nouveau,nvidia,nvidiafb,nvidia-gpu"
```

The main info is that this enables IOMMU which allows devices to be directly assigned to virtual machines. Devices are grouped in IOMMU groups, and whole groups need to be passed to VMs for the device to be able to function, yet we don't necessarily want to passthrough all devices in a group. `pcie_acs_override` is an option that splits devices onto their own separate IOMMU group. This command also blacklists some drivers from being loaded on boot.

2. Update GRUB, run:

   ```bash
   update-grub
   ```

3. Add these modules to `/etc/modules`:

   ```conf
   vfio
   vfio_iommu_type1
   vfio_pci
   vfio_virqfd
   kvmgt
   ```

In short these kernel modules provide support for passing through devices to virtual machins. The last one, `kvmgt` is specific for Intel, it enables GPU virtualization so a GPU can be shared across multiples virtual machines.

4. Add a file: `/etc/modprobe.d/iommu_unsafe_interrupts.conf` with content:

   ```conf
   options vfio_iommu_type1 allow_unsafe_interrupts=1
   ```

5. Add a file: `/etc/modprobe.d/kvm.conf` with content:

   ```conf
   options kvm ignore_msrs=1
   ```

6. Blacklist the GPU drivers, edit the file `/etc/modprobe.d/blacklist.conf` and add:

   ```conf
   blacklist radeon
   blacklist nouveau
   blacklist nvidia
   blacklist nvidiafb
   ```

7. Add GPU to vfio

   List PCI devices and note the GPU PCI number:

   ```bash
   root@pve1:~# lspci
   [...]
   00:02.0 VGA compatible controller: Intel Corporation CoffeeLake-S GT2 [UHD Graphics 630]
   [...]
   ```

   Then get the GPU vendors number:

   ```bash
   root@pve1:~# lspci -n -s 00:02.0
   00:02.0 0300: 8086:3e92
   ```

   Add then this in the file `/etc/modprobe.d/vfio.conf`:

   ```conf
   options vfio-pci ids=8086:3e92 disable_vga=1
   ```

8. Run `update-initramfs -u` and restart
