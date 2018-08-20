ui = true

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = "true"
}

storage "dynamodb" {
  ha_enabled = "true"
  region     = "${data.aws_region.current.name}"
  table      = "vault-data"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

default_lease_ttl = "168h"

max_lease_ttl = "720h"