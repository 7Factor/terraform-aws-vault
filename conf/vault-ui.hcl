ui = true

api_addr = "https://0.0.0.0:8200"
cluster_addr = "https://0.0.0.0:8201"

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = "true"
}

listener "tcp" {
  address = "0.0.0.0:8201"
  tls_disable = "true"
}

storage "dynamodb" {
  ha_enabled = "true"
  table      = "VaultData"
}

default_lease_ttl = "168h"

max_lease_ttl = "720h"