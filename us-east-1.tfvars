vpc_id = "vpc-0e6ce80c5861c0584"

vault_key_name      = "vault-us-east-1"
vault_version       = "1.3.1"
vault_instance_type = "t2.micro"
vault_cert_arn      = "arn:aws:acm:us-east-1:964357038409:certificate/3318654b-0652-485f-9a4f-3bb9bbbad075"
vault_fqdn          = "vault.7fdev.io"

public_subnets  = ["subnet-0620394bc9b89c2fe", "subnet-035d2af47fb873744"]
private_subnets = ["subnet-082ac19a5e55f8736", "subnet-0830c1406c1904fa4"]

utility_accessible_sg = "sg-0e7348f1fe06d0d6b"
lb_security_policy    = "ELBSecurityPolicy-FS-2018-06"

vault_count              = 2
vault_data_bucket        = "7f-vault"
vault_data_bucket_region = "us-east-1"
