#!/bin/bash
set -euo pipefail
set -x

TMP_ROOT_DIR=/tmp/loki-sos-report

get_mountpoint() {
	local input="${1}"

	# Already existing, extracted sos report directory
	if [ -d "${input}" ]; then
		echo "${input}"
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
podman kube down ./pod.yaml
SOS_REPORT_INPUT="${sos}" envsubst <./pod.yaml | podman kube play -

echo "Grafana started at http://localhost:3000/explore"
