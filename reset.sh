#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/scripts/common.sh"
if [[ ${1:-} != --destroy-all ]]; then echo 'Deletes Windows installation AND all telemetry. Run ./reset.sh --destroy-all and confirm.'; exit 2; fi
read -r -p 'Type DELETE to remove all lab volumes: ' answer
[[ $answer == DELETE ]] || exit 1
dc down -v --remove-orphans
echo 'Lab data removed. Run ./start.sh to reinstall. Existing .env credentials are retained.'
