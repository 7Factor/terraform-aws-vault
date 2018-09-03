resource "aws_instance" "vault" {
  count = "${var.vault_count}"

  ami           = "${data.aws_ami.aws_linux.id}"
  instance_type = "${var.vault_instance_type}"

  # We're doing some magic here to allow for any number of count that's evenly distributed
  # across the configured subnets.
  subnet_id = "${var.private_subnets[count.index % length(var.private_subnets)]}"

  key_name             = "${var.vault_ssh_key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.vault_instance_profile.name}"

  vpc_security_group_ids = [
    "${aws_security_group.vault_sg.id}",
    "${var.utility_accessible_sg}",
  ]

  tags {
    Name        = "Vault ${count.index}"
    Cluster     = "${var.cluster_name}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/vault/conf",
      "mkdir -p ~/conf",
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = "${self.private_ip}"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/conf/vault.hcl"
    destination = "~/conf/vault.hcl"

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
      "sudo yum -y install docker",
      "sudo service docker start",
      "sudo usermod -aG docker ec2-user",
      "sudo docker pull ${var.vault_image}",
      "sudo mv ~/conf/* /etc/vault/conf/",
      "sudo docker run --cap-add=IPC_LOCK -d --name vault --network host -v /etc/vault/conf/:/vault/config -e 'AWS_DEFAULT_REGION=${data.aws_region.current.name}' vault server",
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

resource "aws_iam_role_policy_attachment" "terraformer_permissions" {
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
