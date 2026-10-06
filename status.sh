#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/scripts/common.sh"
echo "=== Docker Target Containers ==="
dc ps
echo "=== Host ELK Health & Recent Telemetry Counts ==="
python3 "$ROOT/scripts/bootstrap.py" status
