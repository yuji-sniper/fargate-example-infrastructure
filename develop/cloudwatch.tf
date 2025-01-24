locals {
  retention_in_days = 180
  ecs_log_groups = toset([
    "app",
    "queue",
    "cron",
    "migrate",
  ])
  nginx_log_groups = toset([
    "nginx",
  ])
  lambda_functions = toset([
    aws_lambda_function.log_error_alert.function_name,
  ])
}

# ===============================================================================
# ECS_log_group
# ===============================================================================
resource "aws_cloudwatch_log_group" "ecs_log_groups" {
  for_each          = local.ecs_log_groups
  name              = "${local.project}-${local.env}-${each.key}"
  retention_in_days = local.retention_in_days
}

resource "aws_cloudwatch_log_group" "nginx" {
  for_each          = local.nginx_log_groups
  name              = "${local.project}-${local.env}-${each.key}"
  retention_in_days = local.retention_in_days
}

# ===============================================================================
# ECS_Metric
# ===============================================================================
# CPU使用率が50%以上が2回続いたらスケールアウト
resource "aws_cloudwatch_metric_alarm" "app_cpu_high" {
  alarm_name          = "${local.project}-${local.env}-app-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 50
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.app_scale_out.arn,
    aws_sns_topic.metric_alarm.arn,
  ]
}

# CPU使用率が15%以下が10回続いたらスケールイン
resource "aws_cloudwatch_metric_alarm" "app_cpu_low" {
  alarm_name          = "${local.project}-${local.env}-app-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 10
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 15
  treat_missing_data  = "notBreaching"
  datapoints_to_alarm = 10

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.app_scale_in.arn,
    aws_sns_topic.metric_alarm.arn,
  ]
}

# メモリ使用率が80%以上が2回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "app_memory_high" {
  alarm_name          = "${local.project}-${local.env}-app-memory-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [
    aws_sns_topic.metric_alarm.arn,
  ]
}

# ===============================================================================
# CloudWatch for ALB Metrics
# ===============================================================================
# ヘルシーホストが0以下が1回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "alb_healthy_host" {
  alarm_name = "${local.project}-${local.env}-alb-healthy_host"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name = "HealthyHostCount"
  namespace = "AWS/ApplicationELB"
  period = 60
  statistic = "Minimum"
  threshold = 0
  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.web.arn
    TargetGroup = aws_lb_target_group.web.arn
  }
}

# アンヘルシーホストが1以上が1回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "alb_un_healthy_host" {
  alarm_name = "${local.project}-${local.env}-alb-un-healthy-host"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name = "UnHealthyHostCount"
  namespace = "AWS/ApplicationELB"
  period = 60
  statistic = "Average"
  threshold = 1
  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.web.arn
    TargetGroup = aws_lb_target_group.web.arn
  }
}

# 接続拒否が0以下が1回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "alb_rejected_connection" {
  alarm_name = "${local.project}-${local.env}-alb-rejected-connection"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name = "RejectedConnectionCount"
  namespace = "AWS/ApplicationELB"
  period = 60
  statistic = "Sum"
  threshold = 0
  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.web.arn
    TargetGroup = aws_lb_target_group.web.arn
  }
}

# 5xxエラーが1回以上が5回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "alb_server_error" {
  alarm_name = "${local.project}-${local.env}-alb-server-error"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 5
  metric_name = "HTTPCode_ELB_5XX_Count"
  namespace = "AWS/ApplicationELB"
  period = 60
  statistic = "Sum"
  threshold = 0
  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.web.arn
    TargetGroup = aws_lb_target_group.web.arn
  }
}

# ===============================================================================
# RDS
# ===============================================================================
resource "aws_cloudwatch_log_group" "rds" {
  count = length(local.enabled_cloudwatch_logs_exports)
  name = "/aws/rds/cluster/${aws_rds_cluster.aurora.cluster_identifier}/${local.enabled_cloudwatch_logs_exports[count.index]}"
  retention_in_days = local.retention_in_days
}

# CPU使用率が50%以上が2回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name = "${local.project}-${local.env}-rds-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/RDS"
  period = 60
  statistic = "Average"
  threshold = 50
  treat_missing_data = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster.aurora.id
  }
}

# CPU使用率が15%以下が5分おきに10回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "rds_cpu_low" {
  alarm_name = "${local.project}-${local.env}-rds-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 10
  metric_name = "CPUUtilization"
  namespace = "AWS/RDS"
  period = 300
  statistic = "Average"
  threshold = 15
  treat_missing_data = "notBreaching"
  datapoints_to_alarm = 10

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster.aurora.id
  }
}

# メモリの空き容量が256MB以下が2回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "rds_memory_high" {
  alarm_name = "${local.project}-${local.env}-rds-memory-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "FreeableMemory"
  namespace = "AWS/RDS"
  period = 60
  statistic = "Minimum"
  threshold = 256000000
  treat_missing_data = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }
}

# データベース接続数が最大接続数の80%以上が1回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "rds_db_connections_high" {
  alarm_name = "${local.project}-${local.env}-rds-connections-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name = "DatabaseConnections"
  namespace = "AWS/RDS"
  period = 60
  statistic = "Average"
  threshold = floor(local.rds_max_connections * 0.8)
  treat_missing_data = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }
}

# ===============================================================================
# ElastiCache Metrics
# ===============================================================================
# CPU使用率が80%以上が2回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "ec_cpu_high" {
  alarm_name = "${local.project}-${local.env}-ec-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/ElasticCache"
  period = 60
  statistic = "Average"
  threshold = 80
  treat_missing_data = "notBreaching"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.cluster_id
  }
}

# メモリ使用率が80%以上が2回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "ec_memory_high" {
  alarm_name = "${local.project}-${local.env}-ec-memory-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "DatabaseMemoryUsagePercentage"
  namespace = "AWS/ElasticCache"
  period = 60
  statistic = "Average"
  threshold = 80
  treat_missing_data = "notBreaching"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.cluster_id
  }
}

# スワップメモリが50MB以上が2回続いたらアラーム
resource "aws_cloudwatch_metric_alarm" "ec_swap_high" {
  alarm_name = "${local.project}-${local.env}-ec-swap-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "DatabaseMemoryUsagePercentage"
  namespace = "AWS/ElastiCache"
  period = 60
  statistic = "Average"
  threshold = 50000000
  treat_missing_data = "notBreaching"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.cluster_id
  }
}

# ===============================================================================
# Lambda Logs
# ===============================================================================
resource "aws_cloudwatch_log_group" "lambda_functions" {
  for_each          = local.lambda_functions
  name              = "/aws/lambda/${each.key}"
  retention_in_days = local.retention_in_days
}
