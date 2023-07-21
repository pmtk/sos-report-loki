#!/bin/bash
set -euo pipefail
set -x

TMP_ROOT_DIR=/tmp/loki-sos-report

get_mountpoint() {
  local input="${1}"

  # Already existing, extracted sos report directory
  if [ -d "${input}" ]; then
    echo "${sos}"
    return
  fi

  mkdir -p "${TMP_ROOT_DIR}"

  # Remote url to sos-report archive: download & extract
  if [[ $1 = http* ]]; then
    (
      filename="$(basename "${input}")"
      without_ext="${filename%%.*}"
      out="${TMP_ROOT_DIR}/${without_ext}"
      if [[ -d "${out}" ]]; then
        echo "${out}"
        return
      fi

      cd "${TMP_ROOT_DIR}"
      curl --silent --remote-name "${input}"

      tar xf "${filename}"
      echo "${out}"
    )
    return
  fi

  # Local path to sos-report archive: copy & extract
  (
    filename="$(basename "${input}")"
    without_ext="${filename%%.*}"
    out="${TMP_ROOT_DIR}/${without_ext}"
    if [[ -d "${out}" ]]; then
      echo "${out}"
      return
    fi

    cd "${TMP_ROOT_DIR}"
    cp "${input}" .

    tar xf "${filename}"
    echo "${out}"
  )
}

if [ -z "$1" ]; then
  echo "./local-loki.sh <path to sos-report>"
  exit 1
fi

sos="$(get_mountpoint "${1}")"

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
  -v "$(pwd)/grafana/datasources:/etc/grafana/provisioning/datasources:Z" \
  -ti docker.io/grafana/grafana:10.0.2

# Start promtail
podman run -d \
  --pod sos-report \
  --name promtail \
  -v "$(pwd)/promtail:/etc/promtail:Z" \
  -v "${sos}:/logs:Z" \
  -ti docker.io/grafana/promtail:2.8.2

echo "Grafana started at http://localhost:3000/explore"
