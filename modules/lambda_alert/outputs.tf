output "function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.alert.arn
}

output "function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.alert.function_name
}
