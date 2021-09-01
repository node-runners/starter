#!/bin/bash  

source ~/.profile  


set -e  

if [[ -z $NR_VM_PASSWORD  ]]; then
    echo "Run install globals script"
    exit 0  
fi    

echo "Disabling Prometheus"  
systemctl stop prometheus && systemctl disable prometheus  

rm -rf /opt/prometheus && sudo mkdir /opt/prometheus  

echo "Installing VM Agent"  
wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v1.64.1/vmutils-amd64-v1.64.1.tar.gz
tar xvf vmutils-amd64-v1.64.1.tar.gz
rm  vmutils-amd64-v1.64.1.tar.gz  
rm -f /usr/local/bin/vm*-prod && mv vm*-prod /usr/local/bin/   

sudo tee /opt/prometheus/prometheus.yml <<EOF >/dev/null 
global:
  scrape_interval: 30s
  evaluation_interval: 30s
  external_labels:
    customer: $NR_CUSTOMER
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
        replacement: '$NR_NODE_NAME'
EOF



sudo tee /etc/systemd/system/vmagent.service <<EOF >/dev/null  
[Unit]
  Description=vmagent Monitoring
  Wants=network-online.target
  After=network-online.target
[Service]
  User=$USER
  Type=simple
  ExecStart=/usr/local/bin/vmagent-prod \
  -promscrape.config=/opt/prometheus/prometheus.yml \
  -remoteWrite.url=http://noderunner:$NR_VM_PASSWORD@vm.noderunners.team:8428/api/v1/write
  ExecReload=/bin/kill -HUP $MAINPID
[Install]
  WantedBy=multi-user.target
EOF


echo "Installing Node Exporter"    
wget https://github.com/prometheus/node_exporter/releases/download/v1.2.2/node_exporter-1.2.2.linux-amd64.tar.gz
tar xvf node_exporter-1.2.2.linux-amd64.tar.gz
rm -f /usr/local/bin/node_exporter && cp node_exporter-*.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-*.linux-amd64*  

sudo tee /etc/systemd/system/node_exporter.service <<EOF >/dev/null  
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
User=$USER
Type=simple
ExecStart=/usr/local/bin/node_exporter --collector.systemd --collector.processes --web.listen-address=":9810"
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && systemctl enable node_exporter && systemctl restart node_exporter && systemctl enable vmagent && systemctl restart vmagent  