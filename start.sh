#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

trap 'echo "Startup encountered an issue. See docs/TROUBLESHOOTING.md" >&2' ERR

echo "=================================================="
echo "          SOC SIEM LAB STARTUP LAUNCHER           "
echo "=================================================="

# 1. Ensure Host Elasticsearch and Kibana are running
if ! curl -fsS http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    echo "[INFO] Native Elasticsearch not detected on host."
    echo "[INFO] Running automated host ELK installer..."
    sudo "$SCRIPT_DIR/scripts/install-host-elk.sh"
else
    echo "[OK] Host Elasticsearch is active (http://localhost:9200)."
fi

if ! curl -fsS http://localhost:5601/api/status >/dev/null 2>&1; then
    echo "[INFO] Waiting for Host Kibana (http://localhost:5601)..."
    until curl -fsS http://localhost:5601/api/status >/dev/null 2>&1; do
        sleep 5
    done
fi
echo "[OK] Host Kibana is active (http://localhost:5601)."

# Ensure Logstash pipeline config is up to date
if [ -d /etc/logstash/conf.d ]; then
    sudo cp "$SCRIPT_DIR/elk/logstash/pipeline.conf" /etc/logstash/conf.d/main.conf
    sudo systemctl restart logstash || true
fi

# 2. Configure credentials
python3 "$SCRIPT_DIR/scripts/configure.py"

# 3. Import Kibana SOC Dashboards & index template
python3 "$SCRIPT_DIR/scripts/bootstrap.py" bootstrap http://localhost:9200 http://localhost:5601

# 4. Build and start the 3 Docker target machines
echo "Starting the 3 Docker target containers (Linux DVWA, Windows target, Kali attacker)..."
dc up -d --build

# 5. Wait for target services readiness
echo "Waiting for target services to report ready..."
until dc exec -T kali curl -fsS --max-time 8 http://windows-target:18080/ >/dev/null 2>&1; do
    sleep 2
done
until dc exec -T kali curl -fsSL --max-time 8 http://linux-victim/dvwa/login.php >/dev/null 2>&1; do
    sleep 2
done
echo "[OK] All target services ready."

# 6. Run initial acceptance scenarios
"$SCRIPT_DIR/scripts/acceptance.sh"

echo "=================================================="
echo "              SOC SIEM LAB READY                  "
echo "=================================================="
echo " Kibana Dashboard: http://localhost:5601/app/dashboards#/view/soc-overview"
echo " DVWA Target:      http://localhost:8080"
echo " Windows Console:  http://localhost:8006"
echo " Credentials:      .env | Demo: ./attack.sh demo"
echo "=================================================="
