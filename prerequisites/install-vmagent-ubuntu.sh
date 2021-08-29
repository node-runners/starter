#!/bin/bash  

set -e  

if [[ -z $NR_VM_PASSWORD  ]]; then
    echo "Run install globals script"
    exit 0  
fi    

echo "Disabling Prometheus"  
systemctl stop prometheus && systemctl disable prometheus  

sudo mkdir /opt/prometheus

echo "Installing VM Agent"  
wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v1.64.1/vmutils-amd64-v1.64.1.tar.gz
tar xvf vmutils-amd64-v1.64.1.tar.gz
rm -rf vmutils-amd64-v1.64.1.tar.gz  
rm /usr/local/bin/vm*-prod && mv vm*-prod /usr/local/bin/   

sudo tee <<EOF >/dev/null /opt/prometheus/prometheus.yml
global:
  scrape_interval: 30s
  evaluation_interval: 30s
  external_labels:
    owner: $NR_CUSTOMER
    hostname: $NR_NODE_NAME  
scrape_configs:
  - job_name: "node_exporter"
    scrape_interval: 30s
    static_configs:
      - targets: ["localhost:9810"]
    relabel_configs:
      - source_labels: [__address__]
        regex: '.*'
        target_label: instance
        replacement: '$HOSTNAME'
EOF  

sudo tee <<EOF >/dev/null /etc/systemd/system/vmagent.service
[Unit]
  Description=vmagent Monitoring
  Wants=network-online.target
  After=network-online.target
[Service]
  User=$USER
  Type=simple
  ExecStart=/usr/local/bin/vmagent-prod \
  -promscrape.config=/opt/prometheus/prometheus.yml \
  -remoteWrite.url=http://noderunner:$(NR_VM_PASSWORD)@vm.noderunners.team:8428/api/v1/write
  ExecReload=/bin/kill -HUP $MAINPID
[Install]
  WantedBy=multi-user.target
EOF  


echo "Installing Node Exporter"    
wget https://github.com/prometheus/node_exporter/releases/download/v1.2.2/node_exporter-1.2.2.linux-amd64.tar.gz
tar xvf node_exporter-1.2.2.linux-amd64.tar.gz
cp node_exporter-*.linux-amd64/node_exporter /usr/local/bin
rm /usr/local/bin/node_exporter && rm -rf node_exporter-*.linux-amd64*  

sudo tee <<EOF >/dev/null /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
User=$USER
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=":9810"
[Install]
WantedBy=multi-user.target
EOF  

sudo systemctl daemon-reload && systemctl enable node_exporter && systemctl restart node_exporter && systemctl enable vmagent && systemctl restart vmagent  