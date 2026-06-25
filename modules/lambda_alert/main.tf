data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_alert.zip"
  source {
    content  = <<-PYTHON
      import json, logging
      logger = logging.getLogger()
      logger.setLevel(logging.INFO)

      def handler(event, context):
          for record in event.get("Records", []):
              msg = json.loads(record["Sns"]["Message"])
              logger.info(json.dumps({
                  "alarm":    record["Sns"]["Subject"],
                  "estado":   msg.get("NewStateValue"),
                  "razon":    msg.get("NewStateReason"),
                  "servicio": msg.get("Trigger", {}).get("Dimensions", [{}])[0].get("value", ""),
                  "ambiente": "${var.environment}",
              }))
    PYTHON
    filename = "lambda_alert.py"
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7
  tags              = { environment = var.environment }
}

resource "aws_lambda_function" "alert" {
  function_name    = var.function_name
  role             = var.execution_role_arn
  runtime          = "python3.12"
  handler          = "lambda_alert.handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  tags             = { environment = var.environment }
  depends_on       = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert.arn
}
