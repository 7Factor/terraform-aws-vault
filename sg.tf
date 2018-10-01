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
    Cluster = "${var.cluster_name}"
    Name    = "Vault Boxes"
  }
}

resource "aws_security_group_rule" "vault_peer_communication" {
  type                     = "ingress"
  from_port                = 8201
  to_port                  = 8201
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.vault_sg.id}"
  security_group_id        = "${aws_security_group.vault_sg.id}"
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
    Cluster = "${var.cluster_name}"
    Name    = "Vault Load Balancer"
  }
}