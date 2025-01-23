resource "aws_ecs_cluster" "main" {
  name = "${local.project}-${local.env}"

  tags = {
    Name = "${local.project}-${local.env}-ecs-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT",
  ]

  default_capacity_provider_strategy {
    base              = 1
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
}

# ===============================================================================
# app
# ===============================================================================
resource "aws_ecs_service" "app" {
  name                               = "app"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 50 # 50%以上のタスクが正常に動作している場合に次のタスクを起動する
  platform_version                   = "1.4.0"
  enable_execute_command             = true

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE"
    weight            = 0
  }

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "nginx"
    container_port   = 80
  }

  network_configuration {
    assign_public_ip = true
    subnets = [
      for subnet in aws_subnet.public :
      subnet.id
    ]
    security_groups = [aws_security_group.app.id]
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }

  depends_on = [
    aws_lb_target_group.app
  ]

  tags = {
    Name = "${local.project}-${local.env}-ecs-service-app"
  }
}

resource "aws_appautoscaling_target" "app" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 3 # 最小3タスク
  max_capacity       = 6 # 最大6タスク
}

# スケールアウトポリシー
resource "aws_appautoscaling_policy" "app_scale_out" {
  name               = "scale-out"
  policy_type        = "StepScaling"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 3 # 1回のスケールアウトで3タスク増やす
    }
  }

  depends_on = [aws_appautoscaling_target.app]

  lifecycle {
    ignore_changes = [
      step_scaling_policy_configuration,
    ]
  }
}

resource "aws_appautoscaling_policy" "app_scale_in" {
  name               = "scale-in"
  policy_type        = "StepScaling"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 600
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1 # 1回のスケールインで1タスク減らす
    }
  }

  depends_on = [aws_appautoscaling_target.app]

  lifecycle {
    ignore_changes = [
      step_scaling_policy_configuration,
    ]
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.project}-${local.env}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_service.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions = templatefile(
    "files/task-definitions/app.json",
    {
      project          = local.project
      env              = local.env
      region           = local.region
      log_group_prefix = "${local.project}-${local.env}"
  })
}

# ===============================================================================
# queue
# ===============================================================================
resource "aws_ecs_service" "queue" {
  name = "queue"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.queue.arn
  desired_count = 1
  deployment_minimum_healthy_percent = 50
  platform_version = "1.4.0"

  capacity_provider_strategy {
    base = 1
    capacity_provider = "FARGATE"
    weight = 0
  }

  capacity_provider_strategy {
    base = 0
    capacity_provider = "FARGATE_SPOT"
    weight = 1
  }

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets = [
      for subnet in aws_subnet.public :
      subnet.id
    ]
    security_groups = [aws_security_group.queue.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_ecs_task_definition" "queue" {
  family = "${local.project}-${local.env}-queue"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = 256
  memory = 512
  execution_role_arn = aws_iam_role.ecs_service.arn
  task_role_arn = aws_iam_role.ecs_task.arn
  container_definitions = templatefile(
    "files/task-definitions/queue.json",
    {
      project = local.project
      env = local.env
      region = local.region
      log_group_prefix = "${local.project}-${local.env}"
    }
  )
}

# ===============================================================================
# cron
# ===============================================================================
resource "aws_ecs_task_definition" "cron" {
  family = "${local.project}-${local.env}-cron"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = 256
  memory = 512
  execution_role_arn = aws_iam_role.ecs_service.arn
  task_role_arn = aws_iam_role.ecs_task.arn
  container_definitions = templatefile(
    "files/task-definitions/cron.json",
    {
      project = local.project
      env = local.env
      region = local.region
      log_group_prefix = "${local.project}-${local.env}"
    }
  )
}

# ===============================================================================
# migrate
# ===============================================================================
resource "aws_ecs_task_definition" "migrate" {
  family = "${local.project}-${local.env}-migrate"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = 256
  memory = 512
  execution_role_arn = aws_iam_role.ecs_service.arn
  task_role_arn = aws_iam_role.ecs_task.arn
  container_definitions = templatefile(
    "files/task-definitions/migrate.json",
    {
      project = local.project
      env = local.env
      region = local.region
      log_group_prefix = "${local.project}-${local.env}"
    }
  )
}
