output "repository_url" {
  description = "URL del repositorio ECR para hacer push/pull de imagenes"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio ECR"
  value       = aws_ecr_repository.this.arn
}
