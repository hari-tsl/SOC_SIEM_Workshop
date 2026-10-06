#!/bin/bash
set -euo pipefail

echo "=================================================="
echo "    Installing Native ELK Stack on Ubuntu Host   "
echo "=================================================="

# 1. Prerequisites & GPG Key
sudo apt-get update
sudo apt-get install -y wget curl gnupg apt-transport-https default-jre

if [ ! -f /usr/share/keyrings/elasticsearch-keyring.gpg ]; then
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
fi

# 2. Add Elastic 8.x Apt Repository
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# 3. Install Elasticsearch, Logstash, and Kibana
sudo apt-get update
sudo apt-get install -y elasticsearch kibana logstash

# 4. Configure Elasticsearch (Single node, no security for isolated lab)
sudo mkdir -p /etc/elasticsearch/jvm.options.d
sudo tee /etc/elasticsearch/elasticsearch.yml > /dev/null << 'EOF'
cluster.name: soc-siem-lab
node.name: ubuntu-soc-host
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
EOF

# Set JVM Heap for Elasticsearch (1 GB for cloud lab)
sudo tee /etc/elasticsearch/jvm.options.d/heap.options > /dev/null << 'EOF'
-Xms1g
-Xmx1g
EOF

# Apply kernel virtual memory map
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/90-soc-siem-lab.conf

# 5. Configure Kibana
sudo mkdir -p /etc/kibana
sudo tee /etc/kibana/kibana.yml > /dev/null << 'EOF'
server.port: 5601
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://localhost:9200"]
telemetry.enabled: false
newsfeed.enabled: false
EOF

# 6. Configure Logstash Pipeline
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
sudo mkdir -p /etc/logstash/conf.d /etc/logstash/jvm.options.d
sudo cp "$ROOT_DIR/elk/logstash/pipeline.conf" /etc/logstash/conf.d/main.conf

sudo tee /etc/logstash/jvm.options.d/heap.options > /dev/null << 'EOF'
-Xms512m
-Xmx512m
EOF

# Set proper ownership and permissions
sudo chown -R root:elasticsearch /etc/elasticsearch
sudo chmod -R 755 /etc/elasticsearch
sudo chown -R root:kibana /etc/kibana
sudo chmod -R 755 /etc/kibana
sudo chown -R root:logstash /etc/logstash
sudo chmod -R 755 /etc/logstash

# 7. Enable and Start Services
echo "Starting Elasticsearch, Logstash, and Kibana services..."
sudo systemctl daemon-reload
sudo systemctl enable --now elasticsearch
sudo systemctl enable --now logstash
sudo systemctl enable --now kibana

# 8. Wait for Elasticsearch and Kibana
echo "Waiting for Elasticsearch to respond..."
until curl -fsS http://localhost:9200/_cluster/health >/dev/null 2>&1; do
    sleep 3
done
echo "[OK] Elasticsearch is running on port 9200."

echo "Waiting for Kibana to respond..."
until curl -fsS http://localhost:5601/api/status >/dev/null 2>&1; do
    sleep 5
done
echo "[OK] Kibana is running on port 5601."

# 9. Import Saved Dashboard into Kibana
echo "Importing SOC SIEM Dashboard into Kibana..."
python3 "$ROOT_DIR/scripts/bootstrap.py" bootstrap http://localhost:9200 http://localhost:5601

echo "=================================================="
echo " Native ELK Stack Successfully Installed & Ready "
echo " Elasticsearch: http://localhost:9200             "
echo " Kibana:        http://localhost:5601             "
echo " Logstash:      Port 5044 (Beats input)           "
echo "=================================================="
