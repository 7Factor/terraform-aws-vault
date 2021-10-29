#!/bin/bash
sudo yum install -y unzip

# install vault
sudo mkdir -p /etc/vault/
sudo curl -o /etc/vault.zip -L https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip
sudo unzip -q /etc/vault.zip -d /etc/bin

# create config dest
sudo mkdir -p /etc/vault/config
sudo chown -R ubuntu:ubuntu /etc/vault

# build and place config
cat << EOF > "/etc/vault/config/vault.hcl"
ui = true
api_addr = "https://${vault_fqdn}"
disable_mlock = true

listener "tcp" {
  address = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8200"
  tls_disable = "true"
}

ha_storage "dynamodb" {
  ha_enabled = "true"
  region     = "${region}"
  table      = "vault-lock"
}

storage "s3" {
  region     = "${region}"
  bucket     = "${vault_bucket_name}"
}

seal "awskms" {
  region     = "${region}"
  kms_key_id = "${vault_autounseal_key_id}"
}

default_lease_ttl = "168h"
max_lease_ttl = "720h"

EOF

sudo chown -R root:root /etc/vault

# start vault
sudo echo "
[Unit]
Description=Vault Service
After=network.target
[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=/etc/bin/vault server \
            -config=/etc/vault/config/vault.hcl

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/vault.service

systemctl enable vault
systemctl start vault