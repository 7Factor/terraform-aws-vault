data "template_file" "vault_initialization" {
  template = file("${path.module}/templates/vault_user_data.sh")

  vars = {
    region                  = data.aws_region.current.name
    vault_version           = var.vault_version
    vault_fqdn              = var.vault_fqdn
    vault_bucket_name       = var.vault_bucket_name
    vault_autounseal_key_id = aws_kms_key.vault_autounseal.key_id
  }
}

resource "aws_instance" "vault" {
  count = var.vault_count

  ami           = data.aws_ami.base_ami.id
  instance_type = var.vault_instance_type

  # We're doing some magic here to allow for any number of count that's evenly distributed
  # across the configured subnets.
  subnet_id = var.private_subnets[count.index % length(var.private_subnets)]

  key_name                = var.vault_key_name
  iam_instance_profile    = aws_iam_instance_profile.vault_instance_profile.name
  disable_api_termination = false

  vpc_security_group_ids = [
    aws_security_group.vault_sg.id,
    var.utility_accessible_sg,
  ]

  tags = {
    Name = "Vault Server ${count.index + 1}"
  }

  user_data = base64encode(data.template_file.vault_initialization.rendered)
}

resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "vault-ec2-role"
  role = aws_iam_role.vault_role.name
}

resource "aws_iam_role_policy_attachment" "vault_permissions" {
  role       = aws_iam_role.vault_role.name
  policy_arn = aws_iam_policy.vault_policy.arn
}

resource "aws_iam_role" "vault_role" {
  name        = "VaultEC2"
  description = "Houses required permissions for Vault EC2 boxes."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "vault_policy" {
  name = "VaultDynamoDB"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeLimits",
        "dynamodb:DescribeTimeToLive",
        "dynamodb:Listtags =OfResource",
        "dynamodb:DescribeReservedCapacityOfferings",
        "dynamodb:DescribeReservedCapacity",
        "dynamodb:ListTables",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:CreateTable",
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:GetRecords",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
        "dynamodb:Scan",
        "dynamodb:DescribeTable",
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
