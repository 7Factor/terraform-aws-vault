# load blanacer
resource "aws_lb" "vault_lb" {
  name               = "vault-lb-${data.aws_region.current.name}"
  load_balancer_type = "application"
  internal           = "${var.internal}"

  subnets = [
    "${var.public_subnets}",
  ]

  security_groups = [
    "${aws_security_group.vault_httplb_sg.id}",
  ]

  tags {
    Name    = "Vault LB"
    Cluster = "${var.cluster_name}"
  }
}

resource "aws_lb_target_group" "vault_lb_target" {
  name     = "vault-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    path                = "/v1/sys/health?uninitcode=200"
    port                = 8200
    interval            = 5
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
  ssl_policy        = "${var.lb_security_policy}"
  certificate_arn   = "${var.vault_cert_arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.vault_lb_target.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "vault_lb_redirect" {
  load_balancer_arn = "${aws_lb.vault_lb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
