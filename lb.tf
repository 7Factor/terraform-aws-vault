# internal lb config, intended to be primary
resource "aws_lb" "vault_internal_lb" {
  name               = "vault-int-lb"
  load_balancer_type = "application"
  internal           = true

  subnets = flatten([var.public_subnets])

  security_groups = [aws_security_group.vault_httplb_sg.id]

  tags = {
    Name = "Vault Internal LB"
  }
}

# no need for ssl on internal lb
resource "aws_lb_listener" "vault_int_lb_listener" {
  load_balancer_arn = aws_lb.vault_internal_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.vault_int_lb_target.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "vault_int_lb_target" {
  name     = "vault-int-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    path                = "/v1/sys/health?uninitcode=200"
    port                = 8200
    interval            = 5
  }
}

resource "aws_lb_target_group_attachment" "vault_int_lb_target_attachments" {
  count            = var.vault_count
  target_group_arn = aws_lb_target_group.vault_int_lb_target.arn
  target_id        = element(aws_instance.vault.*.id, count.index)
  port             = 8200
}

# public lb config, optional
resource "aws_lb" "vault_external_lb" {
  count = var.external_lb_enabled ? 1 : 0

  name               = "vault-pub-lb"
  load_balancer_type = "application"
  internal           = false

  subnets = flatten([var.public_subnets])

  security_groups = [aws_security_group.vault_httplb_sg.id]

  tags = {
    Name = "Vault External LB"
  }
}

resource "aws_lb_listener" "vault_pub_lb_listener" {
  count = var.external_lb_enabled ? 1 : 0

  load_balancer_arn = aws_lb.vault_external_lb[count.index].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.lb_security_policy
  certificate_arn   = var.vault_cert_arn

  default_action {
    target_group_arn = aws_lb_target_group.vault_pub_lb_target.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "vault_pub_lb_redirect" {
  count = var.external_lb_enabled ? 1 : 0

  load_balancer_arn = aws_lb.vault_external_lb[count.index].arn
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

resource "aws_lb_target_group" "vault_pub_lb_target" {
  name     = "vault-pub-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    path                = "/v1/sys/health?uninitcode=200"
    port                = 8200
    interval            = 5
  }
}

resource "aws_lb_target_group_attachment" "vault_pub_lb_target_attachments" {
  count            = var.vault_count
  target_group_arn = aws_lb_target_group.vault_pub_lb_target.arn
  target_id        = element(aws_instance.vault.*.id, count.index)
  port             = 8200
}
