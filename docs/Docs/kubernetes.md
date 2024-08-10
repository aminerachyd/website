## Give pod capability to access host network

To give pod access to host network, you can enable it via the `hostNetwork` field in the Pod spec:
```yaml
spec:
  # [...]
  hostNetwork: true
  # [...]
```
---
## Make pods resolve DNS queries using custom DNS server 

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
## Validation webhooks in Kubernetes

Kubernetes exposes two resources to validate resources before their creation: `validatingwebhookconfigurations` and `mutatingwebhookconfigurations`.   
CRDs and operators can define their own webhooks that the API server will call to check whether the resource to be created is valid or not.  
The order for calling webhook is: mutating webhooks > validating webhook. [Link to doc.](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)

---
## Volume snapshots

Reference to doc: [Volume snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)

### Definition

`VolumeSnapshots` and `VolumeSnapshotContent` are resources that are analogous to `PersistentVolumeClaim` and `PersistentVolume`.
- A `VolumeSnapshot` is a request to create a `VolumeSnapshotContent`
- A `VolumeSnapshotContent` is a snapshot taken from a volume in the cluster

Similarly to a `StorageClass`, a `VolumeSnapshotClass` is a resource that is responsible for the mechanism of taking snapshots, it is defined similarly with a CSI drivers and some of its parameters, ex:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: nfs-csi-snapshotclass
deletionPolicy: Retain
driver: nfs.csi.k8s.io
parameters:
  server: <NFS_SERVEr>
  share: <NFS_EXPORT_PATH>
```

Volume snapshots provide a standardized way of copying a volume's data without creating a new volume, this is handy for example to backup databases before performing edits.

The deployment process of `VolumeSnapshot` includes two additional resources:
  - A snapshot controller, watches `VolumeSnapshot` and `VolumeSnapshotContent` resources and is responsible for the creation and deletion of the latter.
  - A CSI snapshotter, watches `VolumeSnapshotContent` and is responsible for triggering `CreateSnapshot` and `DeleteSnapshot` operations against a CSI endpoint.

Data from a snapshot can be restored into a volume via the `dataSource` field in a `PersistentVolumeClaim` object.

### Lifecycle

- Provisioning: either manually (an cluster admin creates a `VolumeSnapshotContent`) or dynamically (via a `VolumeSnapshotClass`)

- Binding: the `VolumeSnapshot` is bound to the `VolumeSnapshotContent` in a 1-to-1 mapping.

- Protection of the PVC: when a snapshot is being taken, the PVC is in-use. When deletion of the PVC is requested, it won't be deleted until the snapshot is completed.

- Delete: triggered by deleting the `VolumeSnapshot` resource. The underlying snapshot and `VolumeSnapshotContent` are kept depending on the `DeletionPolicy` (can be set to `Delete` or `Retain`)
