resource "aws_cloudwatch_log_group" "bastion" {
  name              = "${local.project}-${local.env}-bastion"
  retention_in_days = 365
}

# ===============================================================================
# CloudWatch for EC2 Metrics (bastion)
# ===============================================================================
resource "aws_cloudwatch_metric_alarm" "bastion_cpu_high" {
  alarm_name          = "${local.project}-${local.env}-bastion-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.bastion.id
  }

  alarm_actions = [
    aws_sns_topic.metric_alarm.arn,
  ]
}

resource "aws_cloudwatch_metric_alarm" "bastion_health_low" {
  alarm_name          = "${local.project}-${local.env}-bastion-health-low"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.bastion.id
  }

  alarm_actions = [
    aws_sns_topic.metric_alarm.arn,
  ]
}
