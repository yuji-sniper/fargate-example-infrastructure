resource "aws_lb" "app" {
  name            = "${local.project}-${local.env}-app"
  internal        = false
  security_groups = [aws_security_group.alb.id]
  subnets = [
    for subnet in aws_subnet.public :
    subnet.id
  ]

  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.alb_log.bucket
    prefix  = "app"
    enabled = true
  }

  lifecycle {
    ignore_changes = [ idle_timeout ]
  }
}

# ===============================================================================
# リスナー
# ===============================================================================
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.api.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ===============================================================================
# app向けターゲットグループ
# ===============================================================================
resource "aws_lb_target_group" "app" {
  name        = "${local.project}-${local.env}-app"
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    healthy_threshold   = 5
    unhealthy_threshold = 2
    path                = "/healthcheck"
  }

  depends_on = [
    aws_lb.app
  ]
}
