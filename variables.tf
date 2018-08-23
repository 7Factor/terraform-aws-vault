variable cluster_name {
  description = "Name your cluster! This will show up in tags."
}

variable vpc_id {
  description = "The ID of the VPC you'll be installing vault into. We make no assumptions about your networking stack, so you should provide this."
}

variable ui_public_subnets {
  type = "list"
  description = "The public subnet ID corresponding to the private subnet you'll be installing vault ui into. Again, we make no assumptions. This should be large enough to support your cluster."
}

variable ui_private_subnets {
  type = "list"
  description = "The private subnet ID you'll be installing vault ui into. Again, we make no assumptions. This should be large enough to support your cluster."
}

variable vault_private_subnets {
  type = "list"
  description = "The private subnet ID you'll be installing vault into. Again, we make no assumptions. This should be large enough to support your cluster."
}

variable vault_ssh_key_name {
  description = "The PEM key name for accessing and provisioning stuff."
}

variable vault_image {
  default     = "vault"
  description = "The image name for vault. Defaults to latest, but you should lock this down."
}

# security group variables
variable vault_ui_ingress_cidr {
  default     = "0.0.0.0/0"
  description = "The CIDR block from whence web traffic may come. Defaults to anywhere, but override it as necessary. This is applied to the ELB."
}

variable vault_ssh_ingress_cidr {
  description = "The CIDR block from whence SSH traffic may come. Set this to your bastion host or your VPN IP range."
}

variable vault_ui_instance_type {
  description = "The ui instance type. Usually around an m3.large gets it done, but do what you want."
}

variable vault_ui_count {
  default     = 2
  description = "The number of ui boxes to run. Defaults to a pair."
}

variable vault_ui_cert_arn {
  description = "The ARN to the SSL cert we'll apply to the ELB."
}

variable vault_ui_ssl_policy {
  description = "Vault UI SSL policy to apply to the ELB."
}

variable vault_ui_conf_dir {
  description = "The path to the config file for the vault ui server."
}

# Worker variables
variable vault_conf_dir {
  description = "The path to the config for the vault servers."
}

variable vault_count {
  default     = 2
  description = "The number of worker boxes to spin up. Defaults to 2."
}

variable vault_instance_type {
  description = "The worker instance types. Pick something kinda big but not huge."
}
