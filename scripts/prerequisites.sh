#!/bin/bash
set -euo pipefail
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'Full lab requires an x86_64 Linux host.'; exit 1; }
for cmd in docker python3 sysctl; do command -v "$cmd" >/dev/null || { echo "Missing prerequisite: $cmd"; exit 1; }; done
docker info >/dev/null
docker compose version >/dev/null

# Optional KVM notification (native container does not require KVM)
if [[ -c /dev/kvm ]]; then
  echo "[OK] Hardware KVM detected."
else
  echo "[INFO] Running in native container mode (KVM not required)."
fi

ram=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if ((ram < 7500000)); then
  echo 'WARNING: Host has under 8 GB RAM; Elasticsearch and services may encounter pressure.'
fi

data_root=$(docker info --format '{{.DockerRootDir}}')
free=$(df -Pk "$data_root" | awk 'NR==2 {print $4}')
((free >= 20000000)) || echo 'WARNING: under 20 GB free in Docker storage; logs may exhaust disk.'

if (( $(sysctl -n vm.max_map_count) < 262144 )); then
  [[ $EUID == 0 ]] || { echo 'Run sudo ./start.sh to apply vm.max_map_count.'; exit 1; }
  sysctl -w vm.max_map_count=262144
  echo 'vm.max_map_count=262144' > /etc/sysctl.d/90-soc-siem-lab.conf
fi
