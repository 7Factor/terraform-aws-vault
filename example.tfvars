vpc_id = "VPC-ID"

vault_key_name = "VAULT-PEM"
vault_key_path = "keys"
vault_image = "vault:1.0.1"
vault_instance_type = "t3.micro"
vault_cert_arn = "CERT-ARN"
vault_fqdn = "MY-FQDN"

public_subnets = ["PUBLIC-SUBNET1","PUBLIC-SUBNET2"]
private_subnets = ["PRIVATE-SUBNET1","PRIVATE-SUBNET2"]

utility_accessible_sg = "BASTION-SG"
lb_security_policy = "ELBSecurityPolicy-FS-2018-06"

vault_count = 2
vault_data_bucket = "BUKKIT"
vault_data_bucket_region = "us-east-1"