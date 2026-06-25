output "alb_dns_name" {
  description = "DNS publico del ALB (null si el servicio no es publico)"
  value       = var.public ? aws_lb.this[0].dns_name : null
}

output "alb_arn" {
  description = "ARN del ALB (null si el servicio no es publico)"
  value       = var.public ? aws_lb.this[0].arn : null
}

output "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB para metricas CloudWatch (null si el servicio no es publico)"
  value       = var.public ? aws_lb.this[0].arn_suffix : null
}

output "target_group_arn_suffix" {
  description = "Sufijo del ARN del Target Group para metricas CloudWatch (null si el servicio no es publico)"
  value       = var.public ? aws_lb_target_group.this[0].arn_suffix : null
}

output "service_name" {
  description = "Nombre del servicio ECS"
  value       = aws_ecs_service.this.name
}

output "internal_dns_name" {
  description = "Nombre DNS interno via Cloud Map (null si el servicio es publico)"
  value       = var.public ? null : "${var.app_name}.retailstore.local"
}
