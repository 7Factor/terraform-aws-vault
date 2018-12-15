resource "aws_instance" "vault" {
  count = "${var.vault_count}"

  ami           = "${data.aws_ami.aws_linux.id}"
  instance_type = "${var.vault_instance_type}"

  # We're doing some magic here to allow for any number of count that's evenly distributed
  # across the configured subnets.
  subnet_id = "${var.private_subnets[count.index % length(var.private_subnets)]}"

  key_name                = "${var.vault_ssh_key_name}"
  iam_instance_profile    = "${aws_iam_instance_profile.vault_instance_profile.name}"
  disable_api_termination = false

  vpc_security_group_ids = [
    "${aws_security_group.vault_sg.id}",
    "${var.utility_accessible_sg}",
  ]

  tags {
    Name    = "Vault Server ${count.index + 1}"
    Cluster = "${var.cluster_name}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/vault/config",
      "sudo chown -R ec2-user:ec2-user /etc/vault",
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = "${self.private_ip}"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }

  provisioner "file" {
    content = <<EOF
ui = true
api_addr = "https://${var.vault_fqdn}"
cluster_addr = "https://${self.private_ip}:8201"

listener "tcp" {
  address = "${self.private_ip}:8200"
}

ha_storage "dynamodb" {
  ha_enabled = "true"
  table      = "Vault"
}

storage "s3" {
  region     = "${data.aws_region.current.name}"
  bucket     = "${var.vault_data_bucket}"
}

default_lease_ttl = "168h"
max_lease_ttl = "720h"

EOF

    destination = "/etc/vault/config/vault.hcl"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = "${self.private_ip}"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo amazon-linux-extras install -y docker",
      "sudo service docker start",
      "sudo usermod -aG docker ec2-user",
      "sudo docker pull ${var.vault_image}",
      "sudo docker run -d --name vault --cap-add=IPC_LOCK -p ${self.private_ip}:8200:8200 -p ${self.private_ip}:8201:8201 -v /etc/vault/config/:/vault/config vault server",
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = "${self.private_ip}"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }
}

resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "vault-ec2-role"
  role = "${aws_iam_role.vault_role.name}"
}

resource "aws_iam_role_policy_attachment" "vault_permissions" {
  role       = "${aws_iam_role.vault_role.name}"
  policy_arn = "${aws_iam_policy.vault_policy.arn}"
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
      "Action": "dynamodb:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
}
