output "ui_url" {
  description = "URL pública de la tienda (ui)"
  value       = "http://${module.ecs_service["ui"].alb_dns_name}"
}

output "admin_url" {
  description = "URL pública del panel de administración"
  value       = "http://${module.ecs_service["admin"].alb_dns_name}"
}

output "ecr_repository_urls" {
  description = "URLs de los repositorios ECR por servicio"
  value       = local.ecr_urls
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS de este ambiente"
  value       = module.ecs_cluster.cluster_name
}

output "vpc_id" {
  description = "ID de la VPC de este ambiente"
  value       = module.networking.vpc_id
}
