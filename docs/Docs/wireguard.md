# Wireguard

This documents the installation of a wireguard VPN on client and server.  
The server is running RHEL9.  

## Server configuration

- Create pvt/pub keys in server:  
  ```bash
  # tee writes the stdin in a file and also outputs it
  wg genkey | tee privatekey | wg pubkey > publickey
  ```

- Create interface configuration:  
  ```bash file=/etc/wireguard/wg0.conf
  [Interface]
  PrivateKey=<REDACTED>
  Address=10.0.0.1/8
  SaveConfig=true
  PostUp=iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;
  PostDown=iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE;
  ListenPort=51820
  ```

  A couple notes: the private key is obviously the one you generated before.  

  The address should be an address range which is not used, otherwise it may cause routing issues.  

  PostUp and PostDown explanations: These are commands executed when the Wireguard interface is brought up. In this case they are adding/deleting routing rules via iptables (flags -A and -D)  

  PostUp rule explanation:  
    - `iptables -A FORWARD -i wg0 -j ACCEPT`: This adds a new rule to the `FORWARD` chain of the `iptables` firewall. Any packet that enters the system via the `wg0` interface should be accepted and forwarded.  
    - `iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE`:  This adds a new rule to the `POSTROUTING` chain of the `iptables` NAT table. It specifies that any packet leaving the system via the `eth0` interface should be NATed. This is used to mask the IP address of the devices behind the Wireguard interface, allowing them to access the internet.  

- Start the network interface: `wg-quick up wg0`  
  You can verify that everything is good via `ip link` or `sudo wg`  

## Client configuration

- Create pvt/pub keys in client, same as before on the server.  

- Create wireguard interface configuration on client.  
  ```bash file=/etc/wireguard/wg0.conf
  [Interface]
  Address = 10.0.0.2/8
  SaveConfig = true
  PrivateKey = <REDACTED>
  DNS = <DNS_IP_ADDRESS>
  
  [Peer]
  PublicKey = <SERVER_PUB_KEY>
  AllowedIPs = 0.0.0.0/0
  Endpoint = <SERVER_ADDR>:<SERVER_PORT>`
  PersistentKeepalive = 30
  ```

  Note: the address has to be on the same subnet configured for the server.  

  Once again, the private key is the one generated on the client.  

  AllowedIPs 0.0.0.0/0 tells the client to route all of its traffic through the VPN.  

  The PersistentKeepalive alerts other devices in between not to reset the connection as Wireguard uses UDP (stateless).  

  The DNS parameter states which DNS server to use when the connection is established. For a homelab scenario this would mean setting the DNS server address.  

## Server configuration

- Run the following command: `sudo wg set wg0 peer <CLIENT_PUB_KEY> allowed-ips 10.0.0.2/32`  

Don't forget to enable port redirection in your router.  

- Enable ip forwarding to be able to reach internal. Done via kernel parameter: `sudo sysctl -w net.ipv4.ip_forward=1`  
