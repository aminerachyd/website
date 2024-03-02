### Give pod capability to access host network

To give pod access to host network, you can enable it via the `hostNetwork` field in the Pod spec:
```yaml
spec:
  # [...]
  hostNetwork: true
  # [...]
```
---
