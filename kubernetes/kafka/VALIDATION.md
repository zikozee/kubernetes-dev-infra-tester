# Kafka Kubernetes runtime validation

Tested on 4 October 2026, using Docker Desktop Kubernetes **v1.36.1** in the
**default** namespace. Both variants were deployed, tested, and removed.

## Changes made during testing

- Every resource manifest now explicitly includes `metadata.namespace: default`.
  Both overlays also set default. No Namespace resource is included.
- Fixed a real startup failure: Kubernetes injected `KAFKA_PORT` and
  `SCHEMA_REGISTRY_PORT` variables that Confluent rejected as deprecated settings.
  All pod templates now use `enableServiceLinks: false`; DNS endpoints still work.

## Results

| Check | Single-node | Three-node |
|---|---|---|
| Kafka, Registry and UI readiness | Passed | Passed |
| Topic initialization Job completed | Passed | Passed |
| Five topics, 3 partitions each, required RF | RF 1 passed | RF 3 passed |
| Produce and consume on every topic with acks=all | Passed | Passed |
| UI HTML, health, topic list and broker API via port-forward | Passed; 1 broker | Passed; 3 brokers |
| Register and retrieve an Avro schema | Passed | Passed |
| 2Gi Bound PVCs | 1 verified | 3 verified |
| PVC retention after uninstall | Passed | Passed |
| Strict schemas and server-side dry runs | Passed | Passed |

Additional checks:

- Single-node broker restart preserved messages on all five topics and the
  registered schema. Rerunning initialization preserved all five topic IDs.
- In three-node mode, broker/controller 3 was the active controller. Stopping it
  moved controller leadership from node 3 to node 1. With two brokers remaining,
  every topic still accepted and returned another message using acks=all.
- Restoring node 3 returned all 15 application-topic partitions and `_schemas`
  to three in-sync replicas. Quorum follower lag returned to zero.
- Final corrected three-node containers had zero restarts.
- Both rendered overlays passed kubeconform 0.7.0 strict Kubernetes 1.32.0 schemas:
  **20 valid, 0 invalid, 0 errors, 0 skipped**. Configuration invariants and embedded
  Bash syntax passed. All raw resource manifests explicitly use default.

## Cleanup

Removed the test StatefulSet, deployments, Jobs, Services, ConfigMaps, pods,
replica sets, three test PVCs (`data-kafka-0`, `data-kafka-1`, `data-kafka-2`),
and their backing PVs. Temporary port-forwarding processes were stopped.

The before/after comparison confirmed the original resource names and UIDs were
unchanged. The nine preexisting PVCs from the older Confluent deployment were
preserved, along with the default namespace and its original Service/ConfigMap.
No Kafka test infrastructure remains running.

These were local functional and recovery tests with small messages; they were
not sustained load tests or production certification. Spring Boot services were
not deployed as part of these infrastructure tests.

## Custom-topic helper follow-up

Added `run.sh` to initialize supplied topic names without editing saved manifests.
The default five-topic list remains available when no names are supplied.
Both custom overlays passed strict schema validation (20 resources total).
Offline checks covered default/custom lists, topic creation, replication mismatch
failures, invalid and duplicate names, variant mismatch prevention, mocked startup
ordering, and temporary-file cleanup. No cluster changes were made for this
follow-up; the runtime tests above preceded this helper addition.
