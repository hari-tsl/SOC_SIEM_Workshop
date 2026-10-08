#!/bin/bash
set -euo pipefail

echo "=================================================="
echo "      ENDPOINT & PACKAGE PREREQUISITES CHECK      "
echo "=================================================="

# 1. OS & Architecture Check
OS_NAME="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS_NAME" != "Linux" ]]; then
    echo "[ERROR] This lab must be deployed on a Linux host (detected: $OS_NAME)." >&2
    exit 1
fi

if [[ "$ARCH" != "x86_64" ]]; then
    echo "[ERROR] Unsupported architecture: $ARCH" >&2
    echo "        The SOC lab requires an x86_64 (amd64) host." >&2
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        echo "        Note: AWS Graviton instances (t4g series) are ARM64 and cannot" >&2
        echo "        run the required amd64 packages. Please launch an x86_64 instance" >&2
        echo "        such as t3.large or t3a.large." >&2
    fi
    exit 1
fi
echo "[OK] OS and Architecture: Linux $ARCH"

# 2. Package Requirement & Auto-Installation Check
REQUIRED_CMDS=("curl" "wget" "python3" "git" "sysctl" "systemctl")
MISSING_CMDS=()

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_CMDS+=("$cmd")
    fi
done

if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
    echo "[WARN] Missing required system utilities: ${MISSING_CMDS[*]}"
    if command -v apt-get >/dev/null 2>&1; then
        if [ "${EUID:-$(id -u)}" -eq 0 ]; then
            echo "[INFO] Automatically installing missing packages via apt-get..."
            apt-get update -qq
            apt-get install -y "${MISSING_CMDS[@]}" ca-certificates gnupg apt-transport-https
            echo "[OK] Installed missing packages."
        else
            echo "[ERROR] Please install missing utilities: sudo apt-get update && sudo apt-get install -y ${MISSING_CMDS[*]}" >&2
            exit 1
        fi
    else
        echo "[ERROR] Please install the following commands: ${MISSING_CMDS[*]}" >&2
        exit 1
    fi
fi
echo "[OK] Core system utilities verified."

# 3. Docker & Docker Compose Check
if ! command -v docker >/dev/null 2>&1; then
    echo "[WARN] Docker is not installed on this host."
    if command -v apt-get >/dev/null 2>&1 && [ "${EUID:-$(id -u)}" -eq 0 ]; then
        echo "[INFO] Installing Docker Engine and Docker Compose plugin..."
        apt-get update -qq
        apt-get install -y docker.io docker-compose-v2
        systemctl enable --now docker || true
        echo "[OK] Docker installed."
    else
        echo "[ERROR] Docker is required. Please install Docker Engine: sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2" >&2
        exit 1
    fi
fi

# Check Docker daemon state
if ! docker info >/dev/null 2>&1; then
    echo "[INFO] Docker daemon is not running. Attempting to start service..."
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        systemctl start docker || service docker start || true
    fi
    if ! docker info >/dev/null 2>&1; then
        echo "[ERROR] Docker daemon is unreachable. Verify Docker is running: sudo systemctl start docker" >&2
        exit 1
    fi
fi

# Verify Docker Compose v2 support
if docker compose version >/dev/null 2>&1; then
    echo "[OK] Docker Engine and Compose v2 are active."
elif command -v docker-compose >/dev/null 2>&1; then
    echo "[OK] Legacy docker-compose detected."
else
    if command -v apt-get >/dev/null 2>&1 && [ "${EUID:-$(id -u)}" -eq 0 ]; then
        echo "[INFO] Installing docker-compose-v2 plugin..."
        apt-get update -qq && apt-get install -y docker-compose-v2
    else
        echo "[ERROR] Docker Compose (v2 or standalone) is required." >&2
        exit 1
    fi
fi

# 4. RAM and Swap Check (EC2 Sizing Protection)
RAM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
SWAP_KB="$(awk '/SwapTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
RAM_MB=$((RAM_KB / 1024))
RAM_GB=$((RAM_MB / 1024))

if [ "$RAM_KB" -gt 0 ] && [ "$RAM_KB" -lt 3500000 ]; then
    echo "[ERROR] Host has only ${RAM_MB} MB RAM." >&2
    echo "        The ELK stack and 5 containers require at least 4 GB RAM (8 GB recommended)." >&2
    echo "        Please upgrade to an instance with at least 4 GB - 8 GB RAM (e.g. t3.large)." >&2
    exit 1
fi

if [ "$RAM_KB" -gt 0 ] && [ "$RAM_KB" -lt 7500000 ]; then
    echo "[WARN] Host has ${RAM_GB} GB RAM (8 GB+ recommended)."
    if [ "$SWAP_KB" -lt 2000000 ]; then
        echo "[WARN] Less than 2 GB swap detected (${SWAP_KB} kB)."
        echo "       Elasticsearch and MariaDB can trigger Linux OOM-killer on 4 GB hosts."
        if [ "${EUID:-$(id -u)}" -eq 0 ]; then
            echo "[INFO] Creating 4 GB swapfile (/swapfile) to ensure stability..."
            if [ ! -f /swapfile ]; then
                fallocate -l 4G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=4096 status=none
                chmod 600 /swapfile
                mkswap /swapfile >/dev/null
            fi
            swapon /swapfile 2>/dev/null || true
            if ! grep -q '/swapfile' /etc/fstab 2>/dev/null; then
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
            fi
            echo "[OK] 4 GB swap successfully activated."
        else
            echo "[WARN] Run with sudo or enable swap manually: sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
        fi
    else
        echo "[OK] Swap is configured ($((SWAP_KB / 1024)) MB)."
    fi
else
    echo "[OK] Memory: ${RAM_GB} GB RAM available."
fi

# 5. Disk Space Check
DATA_ROOT="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo '/var/lib/docker')"
FREE_KB="$(df -Pk "$DATA_ROOT" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)"
FREE_GB=$((FREE_KB / 1024 / 1024))

if [ "$FREE_KB" -gt 0 ] && [ "$FREE_KB" -lt 15000000 ]; then
    echo "[WARN] Only ${FREE_GB} GB free disk space in Docker storage ($DATA_ROOT)."
    echo "       At least 20 GB free disk space is recommended for images and Elasticsearch indices."
else
    echo "[OK] Free disk space: ${FREE_GB} GB in $DATA_ROOT."
fi

# 6. Kernel vm.max_map_count for Elasticsearch
CURRENT_MAP="$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)"
if [ "$CURRENT_MAP" -lt 262144 ]; then
    echo "[INFO] Configuring vm.max_map_count=262144 for Elasticsearch..."
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        sysctl -w vm.max_map_count=262144 >/dev/null
        echo 'vm.max_map_count=262144' > /etc/sysctl.d/90-soc-siem-lab.conf
        echo "[OK] Applied vm.max_map_count=262144."
    else
        echo "[ERROR] vm.max_map_count is $CURRENT_MAP (minimum 262144 required). Please run with sudo: sudo ./start.sh" >&2
        exit 1
    fi
else
    echo "[OK] vm.max_map_count is $CURRENT_MAP."
fi

echo "=================================================="
echo "    [OK] ALL ENDPOINT PREREQUISITES SATISFIED     "
echo "=================================================="
