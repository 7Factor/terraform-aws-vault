ui = true

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = "true"
}

storage "dynamodb" {
  ha_enabled = "true"
  table      = "vault-data"
}

default_lease_ttl = "168h"

max_lease_ttl = "720h"