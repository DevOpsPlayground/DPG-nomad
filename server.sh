
## Install Terraform
curl "https://releases.hashicorp.com/terraform/1.6.3/terraform_1.6.3_linux_amd64.zip" -o /tmp/terraform1.6.3.zip

unzip -u /tmp/terraform1.6.3.zip -d /usr/local/bin

## Install nomad
curl "https://releases.hashicorp.com/nomad/1.6.3/nomad_1.6.3_linux_amd64.zip" -o /tmp/nomad1.6.3.zip

unzip -u /tmp/nomad1.6.3.zip -d /usr/local/bin

mkdir /var/lib/nomad; true
mkdir /etc/nomad.d; true

## set up nomad
cat > /etc/nomad.d/config.hcl << EOF
data_dir  = "/var/lib/nomad"
 
bind_addr = "0.0.0.0" # the default

datacenter = "playground"


server {
  enabled          = true
  bootstrap_expect = 1
}

advertise {
    http = "$( curl http://169.254.169.254/latest/meta-data/local-ipv4 )"
    rpc = "$( curl http://169.254.169.254/latest/meta-data/local-ipv4 )"
    serf = "$( curl http://169.254.169.254/latest/meta-data/local-ipv4 )"
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