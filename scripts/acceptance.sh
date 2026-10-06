#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
"$ROOT/attack.sh" demo
python3 "$ROOT/scripts/bootstrap.py" verify "$since"
