resource "aws_sns_topic" "metric_alarm" {
  name = "${local.project}-${local.env}-metric-alarm"
}
