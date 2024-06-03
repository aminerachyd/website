### Give pod capability to access host network

To give pod access to host network, you can enable it via the `hostNetwork` field in the Pod spec:
```yaml
spec:
  # [...]
  hostNetwork: true
  # [...]
```
---
### Make pods resolve DNS queries using custom DNS server 

Under CoreDNS, you can modify the configmap `coredns` in `kube-system` namespace and add the following: 
```yaml
data:
  Corefile: |
    .:53 {
        [...]
        forward . <YOUR_DNS_SERVER_IP>
        [...]
    }
```
-
