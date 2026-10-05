#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/scripts/common.sh"
[[ $# == 1 ]] || { echo 'Usage: ./attack.sh demo|port-scan|web|linux-auth|linux-ftp|windows-auth|windows-ssh|windows-ftp'; exit 2; }
dc exec -T kali python3 /opt/scenarios.py "$1"
