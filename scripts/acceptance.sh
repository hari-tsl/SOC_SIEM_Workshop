#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
since=$(date -u -d "30 seconds ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
"$ROOT/attack.sh" demo
python3 "$ROOT/scripts/bootstrap.py" verify "$since"
