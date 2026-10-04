# Local Kafka on Docker Desktop

Both versions run in the **default** namespace. Every resource manifest explicitly
sets `metadata.namespace: default`, and both Kustomize overlays also set `default`. Choose **single-node** for a
lighter setup, or **three-node** to test replication. Run only one at a time.
Kafka and Schema Registry use Confluent **8.2.2**; Kafka UI uses **v0.7.2**.
Each broker has a **2Gi PVC** and `-Xms256m -Xmx512m` heap.

Run each command block separately. The run/view/check sections are enough for
normal use; deletion and switching are only needed when you want to stop or reset.

## To run

Enable Kubernetes in Docker Desktop, then open a terminal:

```sh
cd ~/codes/my_projects/clean_architecture/kubernetes-dev-infra-tester
```

Choose **Option 1 or Option 2**, then run the shared readiness checks below.
Use the same variant as your existing Kafka data. Switching between single-node
and three-node requires the wipe procedure under **To switch**.

### Option 1: Run with the helper

Use this option for the default topics or your own topic names. Choose one version:

Single-node (1 broker, replication factor 1), with the five default topics:

```sh
./kubernetes/kafka/run.sh single-node
```

Three-node (3 brokers, replication factor 3), with the five default topics:

```sh
./kubernetes/kafka/run.sh three-node
```

For another application's topics, add their names to the command:

```sh
./kubernetes/kafka/run.sh single-node orders inventory-events notifications
```

Replace those names with yours; use `three-node` if that is your chosen version.
Each supplied topic gets **3 partitions** and replication factor **1** or **3**.
The helper starts the infrastructure or reuses the same running version, and
recreates the initialization Job. Existing topics and messages remain.
Custom names replace the default list **for that initialization run**; they do
not rename or delete existing topics.

The helper does not edit saved manifests. To preview without touching the cluster:

```sh
./kubernetes/kafka/run.sh --render single-node orders inventory-events notifications
```

Topic names must be 1–249 letters, digits, dots, underscores or hyphens;
`.` and `..` are invalid. Applications keep the same Kafka and Registry endpoints.

### Option 2: Run directly with the manifests

Use the original commands to start with the five default food-ordering topics.
Choose one version:

Single-node:

```sh
kubectl --context docker-desktop -n default apply -k kubernetes/kafka/single-node
```

Three-node:

```sh
kubectl --context docker-desktop -n default apply -k kubernetes/kafka/three-node
```

If you previously ran the helper with custom topics, use Option 1 without topic
names to initialize the default list again. That recreates the Job with the default
configuration; a direct apply alone cannot update an existing Job's pod template.

### Wait for readiness after either option

Run this block after **Option 1 or Option 2**, for either version:

```sh
kubectl --context docker-desktop -n default rollout status statefulset/kafka --timeout=600s
kubectl --context docker-desktop -n default wait --for=condition=complete job/kafka-topics --timeout=900s
kubectl --context docker-desktop -n default rollout status deployment/schema-registry --timeout=600s
kubectl --context docker-desktop -n default rollout status deployment/kafka-ui --timeout=600s
```

These commands return as soon as readiness checks succeed. The timeouts are
maximum waiting times, not guarantees that startup will succeed.

The default topics are `payment-request`, `payment-response`,
`restaurant-approval-request`, `restaurant-approval-response`, and `customer`,
each with **3 partitions**. If you supplied custom names in Option 1, the Job
initializes those instead. It preserves existing topics and fails if their
partition or replication counts are wrong. Broker probes check listener sockets;
the Job checks the Kafka API on every broker and verifies the selected topics.

## To view Kafka UI

Run this in a terminal and **leave it running**:

```sh
kubectl --context docker-desktop -n default port-forward svc/kafka-ui 9000:8080
```

Open **[http://localhost:9000](http://localhost:9000)** in your browser.
Select **local → Topics** to inspect your topics and messages.
Press **Ctrl+C** in that terminal when you want to close access to the UI.

## To check status

Open another terminal if the UI forwarding command is still running:

```sh
kubectl --context docker-desktop -n default get pods -l app=kafka
kubectl --context docker-desktop -n default get pods -l app=schema-registry
kubectl --context docker-desktop -n default get pods -l app=kafka-ui
kubectl --context docker-desktop -n default get job kafka-topics
```

Pods should show **1/1 Running**. The Job should show **Complete** / **1/1 completions**.

To check the initialized topics and their partition/replication counts:

```sh
kubectl --context docker-desktop -n default logs job/kafka-topics
```

## To check storage

```sh
kubectl --context docker-desktop -n default get pvc -l app=kafka
```

Claims should show **Bound** and **2Gi**. Single-node uses `data-kafka-0`;
three-node also uses `data-kafka-1` and `data-kafka-2`.
Docker Desktop's default StorageClass must support dynamic volume provisioning.
If a claim stays Pending:

```sh
kubectl --context docker-desktop -n default describe pvc data-kafka-0
kubectl --context docker-desktop get storageclass
```

## To connect Spring Boot

Run your Spring Boot applications in **default** too. Use:

```yaml
spring:
  kafka:
    bootstrap-servers: kafka:9092
schema:
  registry:
    url: http://schema-registry:8081
```

Keep your application's existing Schema Registry property name if it differs;
use the URL above. These endpoints stay the same in both versions.
Kafka advertises individual broker addresses under
`kafka-N.kafka-headless.default.svc.cluster.local:9092`. These are for applications
inside Kubernetes; forwarding one Kafka port does not enable host Kafka clients.

## To view Schema Registry

Optional: run this in another terminal and leave it running:

```sh
kubectl --context docker-desktop -n default port-forward svc/schema-registry 8081:8081
```

Open **[http://localhost:8081/subjects](http://localhost:8081/subjects)**.
An empty list is normal before your applications register schemas.

## To delete the infrastructure and keep Kafka data

Stop your Spring Boot applications first. Choose the command matching the version
you deployed.

For single-node:

```sh
kubectl --context docker-desktop -n default delete -k kubernetes/kafka/single-node --ignore-not-found
```

For three-node:

```sh
kubectl --context docker-desktop -n default delete -k kubernetes/kafka/three-node --ignore-not-found
```

Wait for Kafka pods to disappear:

```sh
kubectl --context docker-desktop -n default wait --for=delete pod -l app=kafka --timeout=180s
```

If it reports no matching resources, the pods are already gone.
The **PVCs and Kafka data remain**. Run the **same version** again to reuse them.
These overlays do not create or delete the default namespace. **Never delete the
default namespace** as part of Kafka cleanup.

## To wipe Kafka data

This erases Kafka events, offsets, metadata, and Schema Registry schemas.
First follow **To delete the infrastructure and keep Kafka data** above, and
wait for the Kafka pods to disappear. Then:

```sh
kubectl --context docker-desktop -n default get pvc -l app=kafka
kubectl --context docker-desktop -n default delete pvc -l app=kafka
kubectl --context docker-desktop -n default wait --for=delete pvc -l app=kafka --timeout=180s
```

If it reports no matching resources, the claims are already gone.
With a `Delete` PV reclaim policy, the backing volumes are deleted too.
With `Retain`, backing volumes require separate intentional cleanup.
Run either version again to start with empty data.

## To switch between single-node and three-node

Both versions now share the default namespace, resource names, and PVC names,
but have different cluster IDs and static controller quorums. **Switching requires
a data reset**; applying the other version over retained data is not supported.

1. Stop the Spring Boot applications using Kafka.
2. Follow **To delete the infrastructure and keep Kafka data** for the current version.
3. Follow **To wipe Kafka data** to delete its PVCs.
4. Follow **To run**, choosing the other version, and wait for readiness.
5. Restart your applications. Their endpoints stay the same.

Do not change `CLUSTER_ID` while retaining PVCs, and do not edit replica count or
controller voters to switch versions. This procedure does not migrate data.

If you already deployed the previous manifests into `kafka-single-node` or
`kafka-three-node`, they remain there until you explicitly remove them. Changing
these files does not move existing cluster resources. This update did not apply
or delete anything in your cluster.

## To troubleshoot

If readiness fails, inspect the topic Job, broker logs, and recent events:

```sh
kubectl --context docker-desktop -n default describe job kafka-topics
kubectl --context docker-desktop -n default logs -l app=kafka-topics --all-containers=true --prefix=true
kubectl --context docker-desktop -n default logs kafka-0
kubectl --context docker-desktop -n default get events --sort-by=.metadata.creationTimestamp
```

After fixing the issue, recreate the Job and reapply **the same version**:

```sh
kubectl --context docker-desktop -n default delete job kafka-topics --ignore-not-found
# Choose your currently deployed version:
kubectl --context docker-desktop -n default apply -k kubernetes/kafka/single-node
```

For three-node, replace `single-node` with `three-node` in the last command.
The Job has a 15-minute deadline and up to two retries. Existing topics with
incorrect layouts need an intentional reset or reassignment; the Job never deletes them.

## Configuration and validation

Shared files live in `kubernetes/kafka/base`; version-specific settings live in
`single-node` and `three-node`. Combined broker/controller roles and plaintext
networking are for local development only. No ZooKeeper, Connect, Control Center,
or ksqlDB is deployed.

| Component | CPU request / limit | RAM request / limit |
|---|---|---|
| Kafka, per broker | 250m / 750m | 512Mi / 1Gi |
| Schema Registry | 100m / 500m | 256Mi / 512Mi |
| Kafka UI | 50m / 250m | 128Mi / 384Mi |
| Topic Job, temporary | 50m / 250m | 128Mi / 256Mi |

Steady requests: single-node **400m CPU / 896Mi RAM**; three-node **900m CPU /
1920Mi RAM**. Leave extra Docker Desktop capacity for Kubernetes and applications.
Three brokers on one Docker Desktop machine do not protect against machine failure.
Retention is 24 hours and 128Mi per partition with 16Mi segments; monitor the 2Gi
volumes during heavy testing. Three-node uses `min.insync.replicas=2`; use
`acks=all` in applications when testing durability. Single-node uses 1.

Both versions were deployed and tested on Docker Desktop Kubernetes **1.36.1**.
Tests passed for readiness, all five topic layouts, message production/consumption,
Schema Registry registration/retrieval, UI access through port-forwarding, and
PVC retention. Single-node messages survived a broker restart. Three-node
message delivery continued after stopping the active controller; restoring it
returned every topic replica to sync. All temporary test resources were removed
and preexisting resources were preserved. See `VALIDATION.md` for results.

Both overlays also passed server-side dry runs, configuration/shell checks, and
strict Kubernetes 1.32.0 schema validation: **20/20 resources valid**. Pod templates
set `enableServiceLinks: false` to prevent Kubernetes-generated Service variables
from conflicting with Confluent startup settings.
