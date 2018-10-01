variable cluster_name {
  description = "Name your cluster! This will show up in tags."
}

variable vpc_id {
  description = "The ID of the VPC you'll be installing vault into. We make no assumptions about your networking stack, so you should provide this."
}

variable vault_ssh_key_name {
  description = "The PEM key name for accessing and provisioning stuff."
}

variable vault_image {
  default     = "vault"
  description = "The image name for vault. Defaults to latest, but you should lock this down."
}

variable vault_instance_type {
  description = "The ui instance type. Usually around an m3.large gets it done, but do what you want."
}

variable vault_count {
  default     = 2
  description = "The number of vault boxes to run. Defaults to a pair."
}

variable public_subnets {
  type        = "list"
  description = "The public subnet ID corresponding to the private subnet you'll be installing vault ui into. Again, we make no assumptions. This should be large enough to support your cluster."
}

variable private_subnets {
  type        = "list"
  description = "The private subnet ID you'll be installing vault ui into. Again, we make no assumptions. This should be large enough to support your cluster."
}

variable vault_cert_arn {
  description = "The ARN to the SSL cert we'll apply to the ELB."
}

# security group variables
variable vault_ingress_cidr {
  default     = "0.0.0.0/0"
  description = "The CIDR block from whence web traffic may come. Defaults to anywhere, but override it as necessary. This is applied to the ELB."
}

variable utility_accessible_sg {
  description = "Pass in the ID of your access security group here."
}

variable lb_security_policy {
  description = "Vault UI SSL policy to apply to the ELB."
}

variable vault_data_bucket {
  description = "The bucket name to store encrypted vault information."
}