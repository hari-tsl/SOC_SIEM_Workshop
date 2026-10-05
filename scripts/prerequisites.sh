#!/bin/bash
set -euo pipefail
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'Full lab requires an x86_64 Linux host.'; exit 1; }
for cmd in docker python3 sysctl; do command -v "$cmd" >/dev/null || { echo "Missing prerequisite: $cmd"; exit 1; }; done
docker info >/dev/null
docker compose version >/dev/null
[[ -c /dev/kvm && -c /dev/net/tun ]] || { echo 'KVM and /dev/net/tun required; Docker Desktop on macOS cannot run this lab.'; exit 1; }
python3 - <<'PYCHECK'
import fcntl, os
fd=os.open('/dev/kvm',os.O_RDWR)
assert fcntl.ioctl(fd,0xAE00,0)==12, 'KVM API unavailable'
os.close(fd)
PYCHECK
ram=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
((ram >= 15000000)) || { echo 'At least 16 GB host RAM required.'; exit 1; }
data_root=$(docker info --format '{{.DockerRootDir}}')
free=$(df -Pk "$data_root" | awk 'NR==2 {print $4}')
((free >= 100000000)) || echo 'WARNING: under 100 GB free in Docker storage; Windows and logs may exhaust disk.'
if (( $(sysctl -n vm.max_map_count) < 262144 )); then
  [[ $EUID == 0 ]] || { echo 'Run sudo ./start.sh to apply vm.max_map_count.'; exit 1; }
  sysctl -w vm.max_map_count=262144
  echo 'vm.max_map_count=262144' > /etc/sysctl.d/90-soc-siem-lab.conf
fi
