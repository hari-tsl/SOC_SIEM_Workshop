#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/scripts/common.sh"
dc ps
dc run --rm setup status
dc exec -T kali curl -fsS --max-time 10 http://windows-target:18080/
