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
---
### Validation webhooks in Kubernetes

Kubernetes exposes two resources to validate resources before their creation: `validatingwebhookconfigurations` and `mutatingwebhookconfigurations`.   
CRDs and operators can define their own webhooks that the API server will call to check whether the resource to be created is valid or not.  
The order for calling webhook is: mutating webhooks > validating webhook. [Link to doc.](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
