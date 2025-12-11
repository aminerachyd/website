---
tags:
  - nut
  - ups
  - linux
---

# NUT - Network UPS Tools

## Overview

NUT is a tool that allows exposing a UPS (Uninterrupted Power Supply) in the network. It supports multiple vendors. You can check supported devices [here](https://networkupstools.org/stable-hcl.html).

My current setup features a [EATON Ellipse ECO 1200](https://www.eaton.com/tr/en-gb/skuPage.EL1200USBDIN.html) UPS.

The installation has been tested on my Thinkpad laptop running Fedora 42, then installed on RHEL9 virtual machine.

---

## Setup Considerations

### USB Passthrough

The UPS can only be controlled via a USB connection. For the virtual machine case it has to be passed through from the VM host.

---

## Installation on Fedora

### Initial Setup

- At the end, the guide proceeds to setup httpd to expose the monitor script. However the suggested setup (using `nut-cgi-bin` endpoint) didn't work. I instead proceeded the modify the pre-configured `cgi-bin` endpoint to point to the dir where the NUT .cgi scripts lived (`/var/www/nut-cgi-bin/`).
  This was done in the default httpd conf:

---

## Installation on RHEL9

### Challenges and Solutions

- `upsd` was complaining about missing libusb, turns out the `libusb` library was containing extra information about version of the lib. Resolution was to create a symlink pointing to the available lib file.
- Some permission issues, resolved by adding `user = root` directive on top of the `ups.conf` file.
- SELinux refraining the `nut` user from accessing certain files. This can be either resolved by disabling SELinux or adding a policy for the concerned files (check kernel messages for more info).
- The `nut-server` service wasn't able to start up automatically even when enabled. Perhaps it is waiting for some other target to start before. Resolved it by having a `@reboot` directive on cron that starts it up upon reboot.
