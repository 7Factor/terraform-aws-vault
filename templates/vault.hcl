ui = true
api_addr = "https://${vault_fqdn}:8200"
cluster_addr = "https://${private_ip}:8201"

listener "tcp" {
  address = "${private_ip}:8200"
}

ha_storage "dynamodb" {
  ha_enabled = "true"
  table      = "Vault"
}

storage "s3" {
  region     = "${region}"
  bucket     = "${vault_data_bucket}"
}

default_lease_ttl = "168h"
max_lease_ttl = "720h"