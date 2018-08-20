# Required terraform version
terraform {
  required_version = ">=0.10.7"
}

# Grab the current region to be used everywhere
data "aws_region" "current" {
  current = true
}

#---------------------------------------------------------
# SGs for access to vault servers. One for the web ui
# and another for SSH access and another for DB access.
#---------------------------------------------------------
resource "aws_security_group" "vault_ui_sg" {
  name        = "vault-ui-web-sg-${data.aws_region.current.name}"
  description = "Security group for all vault ui web servers in ${data.aws_region.current.name}."
  vpc_id      = "${var.vpc_id}"

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
  }
}

resource "aws_security_group" "vault_sg" {
  name        = "vault-sg-${data.aws_region.current.name}"
  description = "Opens all the appropriate vault ports in ${data.aws_region.current.name}"

  ingress {
    from_port       = 8201
    to_port         = 8201
    protocol        = "tcp"
    security_groups = ["${aws_security_group.vault_ui_sg.id}"]
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
    cidr_blocks = ["${var.vault_web_ingress_cidr}"]
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
  }
}

#---------------------------------------------------------
# Concourse web server farm. We'll go with a passed in
# number of boxes and a load balancer.
#---------------------------------------------------------
data "aws_ami" "ecs_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
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

resource "aws_instance" "vault_ui" {
  count = "${var.vault_web_count}"

  ami           = "${data.aws_ami.ecs_linux.id}"
  instance_type = "${var.vault_web_instance_type}"
  subnet_id     = "${var.subnet_id}"
  key_name      = "${var.vault_ssh_key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.vault_ui_sg.id}",
    "${aws_security_group.vault_ssh_access.id}",
  ]

  tags {
    Name        = "vault-ui"
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

  provisioner "file" {
    source      = "${var.vault_web_conf_dir}"
    destination = "~/conf/"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo docker pull ${var.vault_image}",
      "sudo mv ~/conf /etc/vault/",
      "docker run --cap-add=IPC_LOCK -d --name vault_web -p 8200:8200 -p 8201:8201 -v /etc/vault/conf/:/vault/config vault server"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }
}

resource "aws_lb" "vault_lb" {
  name = "vault-lb-${data.aws_region.current.name}"
  load_balancer_type = "application"

  subnets = [
    "${var.subnet_id}"
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

  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8200/ui"
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "vault_lb_target_attachments" {
  count            = "${var.vault_web_count}"
  target_group_arn = "${aws_lb_target_group.vault_lb_target.arn}"
  target_id        = "${element(aws_instance.vault_ui.*.id, count.index)}"
  port             = 8200
}

resource "aws_lb_listener" "vault_lb_listener" {
  load_balancer_arn = "${aws_lb.vault_lb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.vault_ui_cert_arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.vault_lb_target.arn}"
    type             = "forward"
  }
}

#---------------------------------------------------------
# Vault farm.
#---------------------------------------------------------
resource "aws_instance" "vault" {
  count      = "${var.vault_count}"
  depends_on = ["aws_elb.vault_lb"]

  ami           = "${data.aws_ami.ecs_linux.id}"
  instance_type = "${var.vault_instance_type}"
  subnet_id     = "${var.subnet_id}"
  key_name      = "${var.vault_ssh_key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.vault_ssh_access.id}",
    "${aws_security_group.vault_sg.id}",
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

  provisioner "file" {
    source      = "${var.vault_conf_dir}"
    destination = "~/conf/"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo docker pull ${var.vault_image}",
      "sudo mv ~/conf /etc/vault/",
      "docker run --cap-add=IPC_LOCK -d --name vault -p 8201:8201 -v /etc/vault/conf/:/vault/config vault server"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("${path.root}/keys/${var.vault_ssh_key_name}.pem")}"
    }
  }
}
