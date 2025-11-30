# Kubernetes

## Cluster Management

### Force Delete Namespace

Top answer from [this thread](https://stackoverflow.com/a/53661717)
This forces the delete of a namespace stuck in "Terminating" state

```bash
(
NAMESPACE=NAMESPACE_TO_DELETE
kubectl proxy &
kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
)
```

---

## Pod Configuration & Networking

### Give Pod Capability to Access Host Network

To give pod access to host network, you can enable it via the `hostNetwork` field in the Pod spec:

```yaml
spec:
  # [...]
  hostNetwork: true
  # [...]
```

---

### Configure Custom DNS

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

### Run Containers with VPN

## Running containers with a VPN

Kubernetes pods regroup containers which share the same network namespace.
This essentially means that if a container is connected to a VPN, the containers in the same pod will also be connected to the same VPN (you can check by running `curl ip.me` from one of the containers of the pod).

1. Run your "VPN" container. [Gluetun](https://github.com/qdm12/gluetun) is a cool project which lets you run a container that connects to a particular VPN provider (multiple ones supported).
   You can configure it as follows with env variables, for example with [Mullvad VPN](https://mullvad.net):

   ```yaml
   env:
   - name: VPN_SERVICE_PROVIDER
     value: "mullvad"
   - name: VPN_TYPE
     value: "openvpn"
   - name: OPENVPN_USER
     value: <YOUR_MULLVAD_VPN_ID>
   ```

   The Gluetun container has also to be privileged and be explicitly given the NET_ADMIN capability. This can be done through the securityContext field in the pod spec:

   ```yaml
   securityContext:
     privileged: true
     capabilities:
       add: ["NET_ADMIN"]
   ```

2. Run your desired container alongside it.

---

## Advanced Features

### Validation Webhooks

Kubernetes exposes two resources to validate resources before their creation: `validatingwebhookconfigurations` and `mutatingwebhookconfigurations`.
CRDs and operators can define their own webhooks that the API server will call to check whether the resource to be created is valid or not.
The order for calling webhook is: mutating webhooks > validating webhook. [Link to doc.](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)

---

### Volume Snapshots

Reference to doc: [Volume snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)

#### Definition

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

### Lifecycle

- **Provisioning**: either manually (an cluster admin creates a `VolumeSnapshotContent`) or dynamically (via a `VolumeSnapshotClass`)
- **Binding**: the `VolumeSnapshot` is bound to the `VolumeSnapshotContent` in a 1-to-1 mapping
- **Protection of the PVC**: when a snapshot is being taken, the PVC is in-use. When deletion of the PVC is requested, it won't be deleted until the snapshot is completed
- **Delete**: triggered by deleting the `VolumeSnapshot` resource. The underlying snapshot and `VolumeSnapshotContent` are kept depending on the `DeletionPolicy` (can be set to `Delete` or `Retain`)

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
    # Name of the cluster to backup, the cluster must already exist and be configured for backups
    name: mypg
  # Other methods are available, see kubectl explain scheduledbackup.spec.method
  method: volumeSnapshot
  online: true
  # This can take a "cron-like" format
  # more details here: https://pkg.go.dev/github.com/robfig/cron#hdr-CRON_Expression_Format
  schedule: '@every 12h'
  suspend: false
  target: prefer-standby
```

Create a cluster that is configured for backups, and can be recovered using a backup:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  # Cluster name, has to match the one used in the backup
  name: mypg
  namespace: mynamespace
spec:
  # Other configs redacted
  # More configurations about creating pg clusters:
  # https://cloudnative-pg.io/documentation/1.16/quickstart/#part-3-deploy-a-postgresql-cluster

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
        # This is the name of the backup object
        # created by the scheduled backup which will be used to restore data to the cluster
        name: mypg-scheduled-backup-XXXX
```

Cluster restores are not performed "in-place" on an existing cluster. You can use the data uploaded to the object storage to bootstrap a new cluster from a previously taken backup. The operator will orchestrate the recovery process using the barman-cloud-restore tool (for the base backup) and the barman-cloud-wal-restore tool (for WAL files, including parallel support, if requested).

---

## Maintain connection (affinity) to a specific pod using services

Services definition can be configured to maintain affinity to a pod using the `spec.sessionAffinity` field:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysvc
spec:
  type: LoadBalancer            # Works with ClusterIP and LoadBalancer types
                                # Doesn't work with Ingress and NodePort configuration

  sessionAffinity: ClientIP     # Defaults to None
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800     # Duration for which the affinity is kept
                                # Defaults to 10800 seconds
```

---

## Limit maximum allocatable capacity on a Kubernetes node

In the Kubelet configuration (under `/var/lib/kubelet/config.yaml`), add the following with your desired values:

```yaml
systemReserved:
  cpu: "1"
  memory: "2Gi"
  # Supports also ephermeral-storage and pid fields
```

Then restart the Kubelet, the result should be reflected with a `kubectl describe node` in Allocatable field:

```
Capacity:
  cpu:                6
  ephemeral-storage:  62027756Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             7869036Ki
  pods:               110
Allocatable:
  cpu:                5
  ephemeral-storage:  57164779835
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             5669484Ki
  pods:               110
```
