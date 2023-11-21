apt install unzip
## Install nomad
curl "https://releases.hashicorp.com/nomad/1.6.3/nomad_1.6.3_linux_amd64.zip" -o /tmp/nomad1.6.3.zip

unzip -u /tmp/nomad1.6.3.zip -d /usr/local/bin

mkdir /var/lib/nomad; true
mkdir /etc/nomad.d; true

## set up nomad
cat > /etc/nomad.d/config.hcl << EOF
data_dir  = "/var/lib/nomad"
datacenter = "playground"
client {
    enabled = true
    server_join {
        retry_join = [ "13.40.126.201" ]
        retry_max = 3
        retry_interval = "15s"
    }
}
advertise {
    http = "35.177.191.23"
    rpc = "35.177.191.23"
    serf = "35.177.191.23"
}
plugin "raw_exec" {
  config {
    enabled = true
  }
}

EOF

cat > /etc/systemd/system/nomad.service << EOF
[Unit]
Description="HashiCorp nomad" Documentation=https://www.nomadproject.io/docs/
Requires=network-online.target
After=network-online.target ConditionFileNotEmpty=/etc/nomad.d/config.hcl
StartLimitBurst=3

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/config.hcl 
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target

EOF
systemctl daemon-reload
systemctl restart nomad