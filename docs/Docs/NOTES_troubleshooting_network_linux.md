# Notes: Troubleshooting linux networking

Notes from [this livestream](https://www.youtube.com/live/dHa2Bja85U0)

DHCP lease: a temporary allocation of an IP address to a device by a DHCP server. The DHCP lease contains several infos: the ip address, the lease time (duration, renewal time, rebinding time), default gateway, DNS servers, domain name associated by the network, etc.

## Useful tools

### **ping**
Uses ICMP ECHO packets
Receiver responds with ECHO reply packet
Prints time, roundtrip time between the moment the ICMP packet is sent and the receive of ECHO packet

### **tracepath**
Uses UDP datagram packets
Sets the TTL to be incrementally larger
If the recepient receives the packet with an elapsed TTL, it sends back and error, that's how we know who that machine is

`tracepath -n`: don't do DNS lookups and only show numbers

no reply: some network devices can be configured to not reply on expired TTL. tracepath will try 3 times before reporting there was no reply

`traceroute` is the predecessor tool, it sends **ICMP** packets instead, the idea stays the same. Traceroute can be configured to send **TCP** packets, and can check whether we can deliver packets to specific addr/port

### **ip**
`ip a`: configured addr
`ip r`: routing configuration, for a tabular output: `route -n` (-n for only numbers, otherwise it does DNS lookup)
 
### **nmcli**
Network manager CLI, specific to RHEL-like systems.  
Network manager can also be configured through a TUI via `nmtui`.  

Bond interfaces: Group two network interfaces to work as one. Either both could service the same requests, or one could serve as a failover for the other.  

Some commands: 

```bash
# Check on current devices
nmcli device

# Check current interfaces/connections
nmcli con

# Disable/Enable interface
nmcli con down/up <INTERFACE>

# Show params of connections
# Gives many infos, for ex IP was assigned via DHCP: ipv4.method auto or manual
nmcli con show <INTERFACE>
```

Changes done via nmcli are persisted on the systems  

## Anatomy of a ping command

`ping www.google.com`
- DNS lookups: checks if there is a DNS entry in /etc/hosts, if not it sends a a DNS server inquery (info can be found on /etc/resov.conf)
- IP addr found, ping sends the ICMP pakcets
- Resubstitutes the hostname in the ouput of the command instead of printing just the numbers

## Troubleshooting DNS

**Symptoms:**
  - Tools don't work with hostnames
**Troubleshooting:**
  - Use tools with IP addresses (ping, tracepath -n)
  - Check /etc/resolv.conf, try using a different one
  - If another one is working, troubleshoot the original one
    - Check if it responds
    - Check connection details via nmcli; check at the bottom the DHCP provided data. DHCP provides a lease with the DNS server to use.
    - If we have multiple interfaces, a wrong nameserver could be placed on top of the /etc/resolv.conf, making DNS resolves very slow

## Troubleshooting routes

**Symptoms:**
  - Ping of addr: Destination host unreachable, this info is sent on with the DHCP lease
  - Can happen when there are multiple network interfaces
**Troubleshooting:**
  - Check if IP addresses are configured
  - Ping a machine on the local network, traffic able to pass to local machines, but not able to be sent to local area segment
  - If the traffic goes to a machine outside the local area segment, it goes to the gateway
  - Check "from" field of the output of ping
  - Check default getways form `route -n`, the default gateway has a destination of `0.0.0.0`. If there are many default gateways, the first on the list is used
  - Delete the incorrect default gateway route with `route del`

## Troubleshooting ping

**Symptoms:**
 - Pinging a machine not working (or locally ping 127.0.0.1 not working)
**Troubleshooting:**
 - Check if conneting to other services is working fine
 - Check kernel setting: /proc/sys/net/ipv4/icmp_echo_ignore_all
 - If set to 1, will ignore all ICMP echo requests on ipv4 addr. `ping localhost` could work if the flag is disabled for ipv6 (local addr ::1)
 - Check if tracepath (UDP) or traceroute (ICMP ECHO) or traceroute in TCP mode are working
