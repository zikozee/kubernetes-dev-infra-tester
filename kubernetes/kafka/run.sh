#!/usr/bin/env bash
set -euo pipefail

# Usage: run.sh [--render] single-node|three-node [topic ...]
# --render prints manifests without reading or changing the cluster.
render=false
if [[ "${1:-}" == --render ]]; then render=true; shift; fi
variant="${1:-}"
case "$variant" in
  single-node) broker_count=1 ;;
  three-node) broker_count=3 ;;
  *) echo "Usage: $0 [--render] single-node|three-node [topic ...]" >&2; exit 2 ;;
esac
shift
base="$(cd "$(dirname "$0")" && pwd)"
topics=""
for topic in "$@"; do
  if [[ ! "$topic" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ ${#topic} -gt 249 ]] || [[ "$topic" == . || "$topic" == .. ]]; then
    echo "Invalid topic name: $topic (use 1–249 letters, digits, dots, underscores or hyphens; excluding . and ..)." >&2
    exit 2
  fi
  case " $topics " in
    *" $topic "*) echo "Duplicate topic name: $topic" >&2; exit 2 ;;
  esac
  topics="${topics:+$topics }$topic"
done

tempdir="$(mktemp -d "$base/.topics-XXXXXX")"
trap 'rm -rf "$tempdir"' EXIT
cat > "$tempdir/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../$variant
YAML
if [[ -n "$topics" ]]; then
  cat >> "$tempdir/kustomization.yaml" <<YAML
patches:
  - target:
      kind: Job
      name: kafka-topics
    patch: |-
      apiVersion: batch/v1
      kind: Job
      metadata:
        name: kafka-topics
      spec:
        template:
          spec:
            containers:
              - name: topics
                env:
                  - name: TOPIC_NAMES
                    value: "$topics"
YAML
fi
kubectl kustomize "$tempdir" > "$tempdir/rendered.yaml"
if [[ "$render" == true ]]; then
  cat "$tempdir/rendered.yaml"
  exit 0
fi

# Applying another static quorum over existing data is not a supported switch.
existing_count="$(kubectl --context docker-desktop -n default get configmap kafka-variant --ignore-not-found -o jsonpath='{.data.BROKER_COUNT}')"
if [[ -n "$existing_count" && "$existing_count" != "$broker_count" ]]; then
  echo "A different variant is running. Follow the README's switch/wipe instructions first." >&2
  exit 2
fi
# Validate before removing the old Job. Its pod template is immutable, so a
# local dry run checks the new render without comparing the existing Job.
kubectl --context docker-desktop -n default apply --dry-run=client --validate=false -f "$tempdir/rendered.yaml" >/dev/null
kubectl --context docker-desktop -n default delete job kafka-topics --ignore-not-found
kubectl --context docker-desktop -n default apply -f "$tempdir/rendered.yaml"
echo "Applied $variant in default. Topic names: ${topics:-the five default food-ordering topics}."
echo "Check completion: kubectl --context docker-desktop -n default wait --for=condition=complete job/kafka-topics --timeout=900s"
