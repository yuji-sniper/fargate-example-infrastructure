# ===============================================================================
# log_error_alert
# ===============================================================================
resource "aws_lambda_function" "log_error_alert" {
  function_name    = "${local.project}-${local.env}-cloudwatch-error-alert"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_functions.id
  s3_key           = aws_s3_object.log_error_alert.key
  source_code_hash = data.archive_file.log_error_alert.output_base64sha256
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      hook_url = var.hook_url_app
    }
  }
}

data "archive_file" "log_error_alert" {
  type        = "zip"
  source_dir  = "${path.cwd}/files/lambda/log_error_alert"
  output_path = "${path.module}/artifacts/log_error_alert.zip"
}

resource "aws_s3_object" "log_error_alert" {
  bucket = aws_s3_bucket.lambda_functions.id
  key    = "log_error_alert.zip"
  source = data.archive_file.log_error_alert.output_path
  etag   = data.archive_file.log_error_alert.output_md5
}

resource "aws_lambda_permission" "lambda_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_error_alert.function_name
  principal     = "logs.${local.region}.amazonaws.com"
  source_arn    = "arn:aws:logs:${local.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
}
