---
tags:
  - networking
  - kubernetes
  - dns
---

# Manage External Name services with ExternalDNS and Ingress

## Problem statement

Previously I had a setup where I hosted all my services in my homelab in Kubernetes.
Figuring how to expose those services at home was fairly simple: make them accessible via `LoadBalancer` type and attach a external DNS annotations to have ExternalDNS create the corresponding DNS records in my DNS provider (Pi-Hole).

However, I recently migrated some of my services to another server and ran them using Docker. These services are no longer in Kubernetes, so I had no way to expose them via `LoadBalancer` type services.

## ExternalName services

Kubernetes provides a way to reference external services via `ExternalName` type services.

These services essentially create a CNAME DNS record that points to the external service. They can be defined as such:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  type: ExternalName
  externalName: myexternalservice.homelab
  ports:
    - port: 80
      targetPort: 80
```

This should in theory work for workloads inside the cluster, but if I add the external DNS annotation like such:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: external.global.homelab
spec:
  type: ExternalName
  externalName: myexternalservice.homelab
  ports:
    - port: 80
      targetPort: 80
```

The created DNS entry is `external.global.homelab` -> `myexternalservice.homelab`.

So far so good, until I'm supposed to host multiple applications via Docker on the same server, each exposed on different ports.

## Port problems on a single server

Let's say I have two services running on `server.homelab`:
- `app1` exposed on port 8080 -> should be accessible via `server.homelab:8080`, I want to reach it via `app1.global.homelab`
- `app2` exposed on port 9090 -> should be accessible via `server.homelab:9090`, I want to reach it via `app2.global.homelab`

The two corresponding `ExternalName` services would be:

```yaml
apiVersion: v1
kind: Service
metadata: 
  name: app1-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: app1.global.homelab
spec:
  type: ExternalName
  externalName: server.homelab
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata: 
  name: app2-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: app2.global.homelab
spec:
  type: ExternalName
  externalName: server.homelab
  ports:
    - port: 9090
      targetPort: 9090
```

Except that now both DNS entries written by ExternalDNS will point to `server.homelab`, without any port information:
- `app1.global.homelab` -> `server.homelab`
- `app2.global.homelab` -> `server.homelab`

And as I want to access from outside the cluster, I don't go through the cluster DNS resolution, so the port information is essentially lost.

## Ingress to the rescue

To solve this problem, I can use an Ingress resource to route traffic based on the hostname to the correct service and port.

Instead of defining external DNS entries on the `ExternalName` services, I can instead create ingress rules that route traffic to the correct service based on the hostname.

The aim is that instead of relying only on DNS resolution (which resolves only to IP addresses but ignores the port). I have to go through the ingress controller which can route traffic based on the hostname to the correct service and port.

If we consider that my ingress controller is exposed via `ingress.incluster.homelab`, I can define the following service and ingress resource for `app1`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app1
spec:
  type: ExternalName
  externalName: server.homelab
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app1-ingress
  annotations:
    external-dns.alpha.kubernetes.io/target: ingress.incluster.homelab
spec:
  ingressClassName: nginx
  rules:
  - host: app1.global.homelab
    http:
      paths:
      - backend:
          service:
            name: app1
            port:
              number: 8080
        path: /
        pathType: Prefix
```

The magic annotations is `external-dns.alpha.kubernetes.io/target: ingress.incluster.homelab` which tells ExternalDNS to create a DNS entry that points to the ingress controller instead of the service itself.

So here I have a CNAME record:
- `app1.global.homelab` -> `ingress.incluster.homelab`

So when I access `app1.global.homelab`:
- The request host is at `app1.global.homelab`
- DNS resolution points to `ingress.incluster.homelab`
- The ingress controller receives the request, sees that the host is `app1.global.homelab` and routes the traffic to the `app1` service on port 8080
- The `app1` service is an `ExternalName` service that points to `server.homelab:8080`, so the request is forwarded to the correct external service