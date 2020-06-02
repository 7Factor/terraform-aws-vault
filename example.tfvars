# The bare minimum required to run this module is provided in this
# example file. Be sure to not store sensitive information in the
# fields pertaining to passwords, authentication configuration, and
# cred store configuration.

###########################
#   VAULT MODULE CONFIG   #
###########################
vpc_id = "VPC-ID"

# Misc stuff
vault_key_name      = "VAULT-PEM"
vault_version       = "1.0.1"
vault_instance_type = "t3.micro"
vault_cert_arn      = "CERT-ARN"
vault_fqdn          = "MY-FQDN"

# Networking
public_subnets        = ["PUBLIC-SUBNET1", "PUBLIC-SUBNET2"]
private_subnets       = ["PRIVATE-SUBNET1", "PRIVATE-SUBNET2"]
utility_accessible_sg = "BASTION-SG"
lb_security_policy    = "ELBSecurityPolicy-FS-2018-06"

# Vault specific
vault_count       = 2
vault_bucket_name = "BUKKIT"