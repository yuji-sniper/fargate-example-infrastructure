# ===============================================================================
# Github Actions
# ===============================================================================
resource "aws_iam_role" "github_actions" {
  name               = "${local.project}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_role.json
}

data "aws_iam_policy_document" "github_actions_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    principals {
      type = "Federated"
      identifiers = [
        data.aws_iam_openid_connect_provider.github_actions.arn
      ]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        # "repo:yuji-sniper/fargate-example-server:*",
      ]
    }
  }
}

resource "aws_iam_policy" "github_actions" {
  name   = "${local.project}-${local.env}-github-actions"
  policy = data.aws_iam_policy_document.github_actions.json
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:ListDistributions",
    ]
    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${local.project}-*",
      "arn:aws:s3:::${local.project}-*/*",
      "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      aws_ecr_repository.app_base.arn,
      aws_ecr_repository.nginx_base.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "events:PutTargets",
      "ecs:RunTask",
      "ecs:RegisterTaskDefinition",
      "ecr:GetAuthorizationToken",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ecs:DescribeTaskDefinition",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:UploadLayerPart",
      "ecs:DescribeClusters",
      "ecr:PutImage",
      "ecs:UpdateService",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:ecs:${local.region}:${data.aws_caller_identity.current.account_id}:cluster/*",
      "arn:aws:ecs:${local.region}:${data.aws_caller_identity.current.account_id}:task/*",
      "arn:aws:ecs:${local.region}:${data.aws_caller_identity.current.account_id}:service/*",
      "arn:aws:s3:::${local.project}-*",
      "arn:aws:s3:::${local.project}-*/*",
      "arn:aws:ecr:${local.region}:${data.aws_caller_identity.current.account_id}:repository/*",
      "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project}-*-ecs-service",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project}-*-ecs-task",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  client_id_list  = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# ===============================================================================
# iam_ssh_login
# ===============================================================================
resource "aws_iam_policy" "iam_ssh_login" {
  name   = "${local.project}-iam-ssh-login"
  policy = data.aws_iam_policy_document.iam_ssh_login.json
}

data "aws_iam_policy_document" "iam_ssh_login" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::????????????:role/${local.project}_iam_login_role"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeTags"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "iam_ssh_login" {
  role       = aws_iam_role.bastion_instance.id
  policy_arn = aws_iam_policy.iam_ssh_login.arn
}

# ===============================================================================
# bastion_instance
# ===============================================================================
resource "aws_iam_instance_profile" "bastion_instance" {
  name = "${local.project}-bastion-instance"
  role = aws_iam_role.bastion_instance.name
}

resource "aws_iam_role" "bastion_instance" {
  name               = "${local.project}-bastion-instance"
  assume_role_policy = data.aws_iam_policy_document.bastion_instance_assume.json
}

data "aws_iam_policy_document" "bastion_instance_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_policy" "bastion_instance" {
  name   = "${local.project}-bastion-instance"
  policy = data.aws_iam_policy_document.bastion_instance.json
}

data "aws_iam_policy_document" "bastion_instance" {
  statement {
    effect = "Allow"
    actions = [
      "s3:Get*",
    ]
    resources = [
      "${aws_s3_bucket.bastion.arn}/*",
      "${aws_s3_bucket.iam_ssh.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      aws_cloudwatch_log_group.bastion.arn,
      "${aws_cloudwatch_log_group.bastion.arn}:log-stream:*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "bastion_instance" {
  role       = aws_iam_role.bastion_instance.id
  policy_arn = aws_iam_policy.bastion_instance.arn
}

resource "aws_iam_role_policy_attachment" "bastion_instance_to_AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.bastion_instance.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ===============================================================================
# lambda
# ===============================================================================
resource "aws_iam_role" "lambda" {
  name               = "${local.project}-${local.env}-lambda"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_cloudwatch" {
  statement {
    sid    = ""
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }
}

resource "aws_iam_policy" "lambda_cloudwatch" {
  name   = "${local.project}-${local.env}-lambda-cloudwatch"
  policy = data.aws_iam_policy_document.lambda_cloudwatch.json
}

resource "aws_iam_policy_attachment" "lambda_cloudwatch" {
  name       = "${local.project}-${local.env}-lambda-cloudwatch"
  roles      = [aws_iam_role.lambda.name]
  policy_arn = aws_iam_policy.lambda_cloudwatch.arn
}


# ===============================================================================
# chatbot
# ===============================================================================
resource "aws_iam_role" "chatbot" {
  name = "${local.project}-${local.env}-chatbot"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.chatbot_assume.json
}

data "aws_iam_policy_document" "chatbot_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "chatbot.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_policy" "chatbot" {
  name   = "${local.project}-${local.env}-chatbot"
  policy = data.aws_iam_policy_document.chatbot.json
}

data "aws_iam_policy_document" "chatbot" {
  statement {
    effect = "Allow"
    actions = [
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:AddPermission",
      "sns:RemovePermission",
      "sns:DeleteTopic",
      "sns:Subscribe",
      "sns:ListSubscriptionsByTopic",
      "sns:Publish",
      "sns:Receive",
    ]
    resources = [
      "*",
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values = [
        data.aws_caller_identity.current.account_id,
      ]
    }
  }

  statement {
    sid    = "SNSPublish"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [
      aws_sns_topic.metric_alarm.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/chatbot/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "chatbot:CreateSlackChannelConfiguration",
      "chatbot:DeleteSlackWorkspaceAuthorization",
      "chatbot:DescribeSlackChannelConfigurations",
      "chatbot:DeleteSlackChannelConfiguration",
      "chatbot:CreateChimeWebhookConfiguration",
      "chatbot:DescribeChimeWebhookConfigurations",
      "chatbot:DeleteChimeWebhookConfiguration",
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "chatbot" {
  role       = aws_iam_role.chatbot.name
  policy_arn = aws_iam_policy.chatbot.arn
}

# ===============================================================================
# chatbot_guardrail
# ===============================================================================
resource "aws_iam_policy" "chatbot_guardrail" {
  name   = "${local.project}-${local.env}-chatbot-guardrail"
  policy = data.aws_iam_policy_document.chatbot_guardrail.json
}

data "aws_iam_policy_document" "chatbot_guardrail" {
  statement {
    effect = "Allow"
    actions = [
      "chatbot:DescribeSlackChannelConfigurations",
      "chatbot:DescribeChimeWebhookConfigurations",
    ]
    resources = [
      "*"
    ]
  }
}
