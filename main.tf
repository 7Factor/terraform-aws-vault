# Required terraform version
terraform {
  required_version = ">=0.10.7"
}

# Grab the current region to be used everywhere
data "aws_region" "current" {
}

#---------------------------------------------------------
# SGs for access to vault servers. One for the ui
# and another for SSH access and another for DB access.
#---------------------------------------------------------
resource "aws_security_group" "vault_sg" {
  name        = "vault-sg-${data.aws_region.current.name}"
  description = "Security group for all vault servers in ${data.aws_region.current.name}."
  vpc_id      = "${var.vpc_id}"

  # access 8200 for api / ui
  ingress {
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = ["${aws_security_group.vault_httplb_sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Application = "vault"
    Cluster     = "${var.cluster_name}"
    Name        = "Vault"
  }
}

resource "aws_security_group" "vault_cluster_sg" {
  name        = "vault-sg-${data.aws_region.current.name}"
  description = "Security group for all vault servers in ${data.aws_region.current.name}."
  vpc_id      = "${var.vpc_id}"

  # access 8201 for cluster communication
  ingress {
    from_port       = 8201
    to_port         = 8201
    protocol        = "tcp"
    security_groups = ["${aws_security_group.vault_sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Application = "vault"
    Cluster     = "${var.cluster_name}"
    Name        = "Vault"
  }
}

resource "aws_security_group" "vault_ssh_access" {
  name        = "vault-ssh-sg-${data.aws_region.current.name}"
  description = "Opens SSH to vault servers in ${data.aws_region.current.name}"
  vpc_id      = "${var.vpc_id}"

  // Assumes default ports
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vault_ssh_ingress_cidr}"]
  }

  // Per docs, this means allow all leaving.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Application = "vault"
    Cluster     = "${var.cluster_name}"
    Name        = "Vault SSH Acess"
  }
}

resource "aws_security_group" "vault_httplb_sg" {
  name        = "vault-lb-sg-${data.aws_region.current.name}"
  description = "Security group for the LB in ${data.aws_region.current.name}."
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.vault_ingress_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Application = "vault"
    Cluster     = "${var.cluster_name}"
    Name        = "Vault LB Access"
  }
}

#---------------------------------------------------------
# Vault iam role for vault boxes so they can talk
# to dynamo db
#---------------------------------------------------------
resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "vault-ec2-role"
  role = "${aws_iam_role.vault_role.name}"
}

resource "aws_iam_role_policy_attachment" "terraformer_permissions" {
  role       = "${aws_iam_role.vault_role.name}"
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

# todo: tighten up this policy
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

#---------------------------------------------------------
# Vault ui server farm. We'll go with a passed in
# number of boxes and a load balancer.
#---------------------------------------------------------
data "aws_ami" "aws_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

resource "aws_instance" "vault" {
  count = "${var.vault_count}"

  ami           = "${data.aws_ami.aws_linux.id}"
  instance_type = "${var.vault_instance_type}"

  # We're doing some magic here to allow for any number of count that's evenly distributed
  # across the configured subnets.
  subnet_id     = "${var.private_subnets[count.index % length(var.private_subnets)]}"
  key_name      = "${var.vault_ssh_key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.vault_instance_profile.name}"

  vpc_security_group_ids = [
    "${aws_security_group.vault_sg.id}",
    "${aws_security_group.vault_cluster_sg.id}",
    "${aws_security_group.vault_ssh_access.id}",
  ]

  tags {
    Name        = "vault"
    Application = "vault"
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
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }

//  provisioner "file" {
//    source      = "${var.vault_ui_conf_dir}"
//    destination = "~/conf/"
//
//    connection {
//      type        = "ssh"
//      user        = "ec2-user"
//      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
//    }
//  }

  provisioner "file" {
    source = "${path.module}/conf/vault.hcl"
    destination = "~/conf/vault.hcl"

    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sleep 10",
      "sudo docker pull ${var.vault_image}",
      "sudo mv ~/conf/* /etc/vault/conf/",
      "docker run --cap-add=IPC_LOCK -d --name vault -p 8200:8200 -p 8201:8201 -v /etc/vault/conf/:/vault/config -e 'AWS_DEFAULT_REGION=${data.aws_region.current.name}' vault server"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }
}

resource "aws_s3_bucket" "vault-data" {
  bucket = "vault-data"
}

# load blanacer
resource "aws_lb" "vault_lb" {
  name = "vault-lb-${data.aws_region.current.name}"
  load_balancer_type = "application"

  subnets = [
    "${var.public_subnets}"
  ]

  security_groups = [
    "${aws_security_group.vault_httplb_sg.id}",
  ]

  tags {
    Name        = "vault-lb"
    Application = "vault"
    Cluster     = "${var.cluster_name}"
  }
}

resource "aws_lb_target_group" "vault_lb_target" {
  name = "vault-lb-${data.aws_region.current.name}-target"
  port = 80
  protocol = "HTTP"
  vpc_id = "${var.vpc_id}"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    path                = "/ui"
    port                = 8200
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "vault_lb_target_attachments" {
  count            = "${var.vault_count}"
  target_group_arn = "${aws_lb_target_group.vault_lb_target.arn}"
  target_id        = "${element(aws_instance.vault.*.id, count.index)}"
  port             = 8200
}

resource "aws_lb_listener" "vault_lb_listener" {
  load_balancer_arn = "${aws_lb.vault_lb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "${var.vault_ssl_policy}"
  certificate_arn   = "${var.vault_cert_arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.vault_lb_target.arn}"
    type             = "forward"
  }
}

