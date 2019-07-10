resource "aws_instance" "vault" {
  count = "${var.vault_count}"

  ami           = "${data.aws_ami.base_ami.id}"
  instance_type = "${var.vault_instance_type}"

  # We're doing some magic here to allow for any number of count that's evenly distributed
  # across the configured subnets.
  subnet_id = "${var.private_subnets[count.index % length(var.private_subnets)]}"

  key_name                = "${var.vault_key_name}"
  iam_instance_profile    = "${aws_iam_instance_profile.vault_instance_profile.name}"
  disable_api_termination = false

  vpc_security_group_ids = [
    "${aws_security_group.vault_sg.id}",
    "${var.utility_accessible_sg}",
  ]

  tags = {
    Name = "Vault Server ${count.index + 1}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/vault/config",
      "sudo chown -R ubuntu:ubuntu /etc/vault",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = "${self.private_ip}"
      private_key = "${file("${path.root}/${var.vault_key_path}/${var.vault_key_name}.pem")}"
    }
  }

  provisioner "file" {
    content = <<EOF
ui = true
api_addr = "https://${var.vault_fqdn}"

listener "tcp" {
  address = "${self.private_ip}:8200"
  tls_disable = "true"
}

ha_storage "dynamodb" {
  ha_enabled = "true"
  region     = "${data.aws_region.current.name}"
  table      = "vault-lock"
}

storage "s3" {
  region     = "${data.aws_region.current.name}"
  bucket     = "${var.vault_data_bucket}"
}

seal "awskms" {
  region     = "${data.aws_region.current.name}"
  kms_key_id = "${aws_kms_key.vault_autounseal.key_id}"
}

default_lease_ttl = "168h"
max_lease_ttl = "720h"

EOF

    destination = "/etc/vault/config/vault.hcl"

    connection {
      type = "ssh"
      user = "ubuntu"
      host = "${self.private_ip}"
      private_key = "${file("${path.root}/${var.vault_key_path}/${var.vault_key_name}.pem")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo unattended-upgrade -d",
      "sudo apt-get remove docker docker-engine docker.io",
      "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce",
      "sudo docker pull ${var.vault_image}",
      "sudo docker run -d --name vault --network host --cap-add=IPC_LOCK -p 8200:8200 -p 8201:8201 -v /etc/vault/config/:/vault/config vault server",
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = "${self.private_ip}"
      private_key = "${file("${path.root}/${var.vault_key_path}/${var.vault_key_name}.pem")}"
    }
  }
}

resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "vault-ec2-role"
  role = "${aws_iam_role.vault_role.name}"
}

resource "aws_iam_role_policy_attachment" "vault_permissions" {
  role = "${aws_iam_role.vault_role.name}"
  policy_arn = "${aws_iam_policy.vault_policy.arn}"
}

resource "aws_iam_role" "vault_role" {
  name = "VaultEC2"
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
