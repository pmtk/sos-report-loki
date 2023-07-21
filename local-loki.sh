#!/bin/bash
set -euo pipefail

if [ -z "$1" ]; then
  echo "./local-loki.sh <path to unpacked sos-report>"
  exit 1
fi

# Create a pod
podman pod stop sos-report && podman pod rm sos-report || true
podman pod create --name sos-report -p 3000:3000

# Start Loki container
# podman rm -f loki || true
podman run -d \
  --pod sos-report \
  --name loki \
  -u 0 \
  -ti docker.io/grafana/loki:2.8.2

# Start Grafana
podman run -d \
  --pod sos-report \
  --name grafana \
  -e GF_AUTH_ANONYMOUS_ENABLED=true \
  -e GF_AUTH_ANONYMOUS_ORG_ROLE=Editor \
  -v $(pwd)/grafana/datasources:/etc/grafana/provisioning/datasources \
  -ti docker.io/grafana/grafana:10.0.2

# Start promtail
podman run -d \
  --pod sos-report \
  --name promtail \
  -v $(pwd)/promtail:/etc/promtail \
  -v "$1":"/logs" \
  -ti docker.io/grafana/promtail:2.8.2

echo "Grafana started at http://localhost:3000/explore"
