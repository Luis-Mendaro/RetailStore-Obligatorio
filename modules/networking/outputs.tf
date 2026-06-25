output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs de las subnets publicas (para el ALB)"
  value       = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (para las tareas Fargate)"
  value       = aws_subnet.private_subnet[*].id
}

output "service_discovery_namespace_id" {
  description = "ID del namespace de Cloud Map para descubrimiento entre microservicios"
  value       = aws_service_discovery_private_dns_namespace.internal.id
}
