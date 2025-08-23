#!/bin/bash
# Script to install Prometheus + Grafana with Node Exporter monitoring

set -e

# ==============================
# Update system
# ==============================
echo "[INFO] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# ==============================
# Install dependencies
# ==============================
echo "[INFO] Installing dependencies..."
sudo apt-get install -y wget tar curl apt-transport-https software-properties-common

# ==============================
# Install Prometheus
# ==============================
PROM_VERSION="2.55.1"   # Change if newer version available
echo "[INFO] Downloading Prometheus v$PROM_VERSION..."
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz

echo "[INFO] Extracting Prometheus..."
tar xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
sudo mv prometheus-${PROM_VERSION}.linux-amd64 /usr/local/prometheus

# Create Prometheus user
sudo useradd --no-create-home --shell /bin/false prometheus || true

# Set permissions
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo cp /usr/local/prometheus/prometheus /usr/local/prometheus/promtool /usr/local/bin/
sudo cp -r /usr/local/prometheus/consoles /usr/local/prometheus/console_libraries /etc/prometheus/

# ==============================
# Configure Prometheus
# ==============================
echo "[INFO] Configuring Prometheus..."
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF

sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# ==============================
# Systemd service for Prometheus
# ==============================
echo "[INFO] Creating Prometheus systemd service..."
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

echo "[INFO] Prometheus installed and running on http://localhost:9090"

# ==============================
# Install Node Exporter
# ==============================
NODE_VERSION="1.8.2"
echo "[INFO] Installing Node Exporter v$NODE_VERSION..."
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /usr/local/bin/

# Systemd for Node Exporter
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo "[INFO] Node Exporter running on http://localhost:9100/metrics"

# ==============================
# Install Grafana
# ==============================
echo "[INFO] Installing Grafana..."
sudo apt-get install -y gnupg2
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update -y
sudo apt-get install -y grafana

sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "[INFO] Grafana installed and running on http://localhost:3000"
echo "[INFO] Default login: admin / admin (you’ll be prompted to change it)"
