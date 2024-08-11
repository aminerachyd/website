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

---
## Cloudnative Postgres operator

Cloudnative Postgres is an operator that manages the lifecycle of Postgres databases (and cluster) in a Kubernetes cluster.

Database backups are performed via special resources, `backup` and `scheduledbackup` which create `volumesnapshots` that can be used later on to recover data in a newly initiated cluster.

Create a scheduled backup object:
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: mypg-scheduled-backup
  namespace: mynamespace
spec:
  backupOwnerReference: none
  cluster:
    name: mypg                # Name of the cluster to backup, the cluster must already exist and be configured for backups
  method: volumeSnapshot      # Other methods are available, see kubectl explain scheduledbackup.spec.method
  online: true
  schedule: '@every 12h'      # This can take a "cron-like" format, details here: https://pkg.go.dev/github.com/robfig/cron#hdr-CRON_Expression_Format
  suspend: false
  target: prefer-standby
```

Create a cluster that is configured for backups, and can be recovered using a backup:
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql
  namespace: postgres
spec:
  # Other configs redacted
  # More configurations about creating pg clusters: https://cloudnative-pg.io/documentation/1.16/quickstart/#part-3-deploy-a-postgresql-cluster

  # Backup configuration for this database cluster
  backup:
    target: prefer-standby
    volumeSnapshot:
      className: <VOLUME_SNAPSHOT_CLASS>
      online: true
      walClassName: <VOLUME_SNAPSHOT_CLASS>

  bootstrap:
    recovery:
      backup:
        name: mypg-scheduled-backup-XXXX # This is the name of the backup object created by the scheduled backup which will be used to restore data to the cluster
```

Cluster restores are not performed "in-place" on an existing cluster. You can use the data uploaded to the object storage to bootstrap a new cluster from a previously taken backup. The operator will orchestrate the recovery process using the barman-cloud-restore tool (for the base backup) and the barman-cloud-wal-restore tool (for WAL files, including parallel support, if requested).
