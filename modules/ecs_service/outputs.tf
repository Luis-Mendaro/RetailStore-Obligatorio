output "alb_dns_name" {
  description = "DNS del ALB (publico o interno; null si el servicio usa NLB)"
  value       = local.use_nlb ? null : aws_lb.this[0].dns_name
}

output "alb_arn" {
  description = "ARN del ALB (null si el servicio usa NLB)"
  value       = local.use_nlb ? null : aws_lb.this[0].arn
}

output "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB para metricas CloudWatch (null si el servicio usa NLB)"
  value       = local.use_nlb ? null : aws_lb.this[0].arn_suffix
}

output "target_group_arn_suffix" {
  description = "Sufijo del ARN del Target Group para metricas CloudWatch (null si el servicio usa NLB)"
  value       = local.use_nlb ? null : aws_lb_target_group.this[0].arn_suffix
}

output "service_name" {
  description = "Nombre del servicio ECS"
  value       = aws_ecs_service.this.name
}

output "endpoint_dns_name" {
  description = "DNS del load balancer (ALB o NLB) que expone este servicio, para que otros servicios lo consuman"
  value       = local.use_nlb ? aws_lb.nlb[0].dns_name : aws_lb.this[0].dns_name
}
