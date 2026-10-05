#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
mkdir -p artifacts
ids=$(dc images -q | sort -u)
[[ -n "$ids" ]] || { echo 'No running lab images found'; exit 1; }
# Docker-generated hexadecimal IDs only.
printf '%s\n' "$ids" | xargs docker image inspect --format '{{json .}}' > artifacts/images.ndjson
echo 'Saved artifacts/images.ndjson'
