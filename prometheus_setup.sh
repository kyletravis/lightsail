#!/bin/bash

# logging setup
LOGFILE=/var/log/prometheus_setup.log

function logsetup {
    touch $LOGFILE
    exec > >(tee -a $LOGFILE)
    exec 2>&1
}

function log {
    echo "[$(date --rfc-3339=seconds)]: $*"
}

logsetup

log installing and configuring prometheus node exporter

useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-amd64.tar.gz
tar xvf node_exporter-0.18.1.linux-amd64.tar.gz
cp node_exporter-0.18.1.linux-amd64/node_exporter /usr/local/bin
chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-0.18.1.linux-amd64

cat >/etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

log enabling node exporter

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter
systemctl status node_exporter

log enabling firewall

ufw allow from 172.26.0.0/16 to any port 9100
ufw status