#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/scripts/common.sh"
trap 'echo "Startup did not complete. Inspect: docker compose logs --tail=100; see docs/TROUBLESHOOTING.md" >&2' ERR
./scripts/prerequisites.sh
python3 scripts/configure.py
dc config --quiet
# Pull helper explicitly: internal networks cannot download Python packages at runtime.
dc --profile tools pull setup
printf 'Starting ELK and building training images...\n'
dc up -d --build elasticsearch logstash kibana
dc run --rm setup bootstrap
dc up -d --build linux-victim filebeat kali kali-filebeat windows-target
printf 'Starting Windows target services...\n'
dc up -d --build windows
limit=$(python3 -c 'from scripts.configure import read_env; from pathlib import Path; print(int(read_env(Path(".env")).get("WINDOWS_TIMEOUT",7200)))')
deadline=$((SECONDS+limit))
until dc exec -T kali curl -fsS --max-time 8 http://windows-target:18080/ >/dev/null 2>&1; do
  if ((SECONDS >= deadline)); then echo 'Windows provisioning timed out. See Windows console and C:\SOC\bootstrap.log.'; exit 1; fi
  echo 'Windows is still provisioning; console: http://127.0.0.1:8006'
  sleep 20
done
./scripts/acceptance.sh
printf '\nSOC SIEM LAB READY\nKibana: http://127.0.0.1:5601/app/dashboards#/view/soc-overview\nWeb target: http://127.0.0.1:8080\nWindows console: http://127.0.0.1:8006\nCredentials: .env | Demo: ./attack.sh demo | Stop: ./stop.sh\n'
