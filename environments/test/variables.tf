variable "environment" {
  description = "Nombre del ambiente"
  type        = string
  default     = "test"
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr_block" {
  description = "CIDR de la VPC de este ambiente"
  type        = string
}

variable "public_subnets" {
  description = "CIDRs de las subnets públicas"
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDRs de las subnets privadas"
  type        = list(string)
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar"
  type        = list(string)
}

variable "lab_role_name" {
  description = "Nombre del rol IAM pre-creado en la cuenta de laboratorio (LabRole)"
  type        = string
  default     = "LabRole"
}

variable "task_cpu" {
  description = "CPU de las tareas Fargate (unidades) para este ambiente"
  type        = number
}

variable "task_memory" {
  description = "Memoria de las tareas Fargate (MB) para este ambiente"
  type        = number
}

variable "desired_count" {
  description = "Cantidad de réplicas deseadas por servicio en este ambiente"
  type        = number
}

# Secretos: nunca van en terraform.tfvars (committeado). Se cargan en
# secrets.auto.tfvars (ignorado por git) o por TF_VAR_xxx al momento del apply.
variable "db_password" {
  description = "Password de PostgreSQL"
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Usuario del panel admin"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Password del panel admin"
  type        = string
  sensitive   = true
}

variable "admin_jwt_secret" {
  description = "Secreto para firmar tokens JWT del panel admin"
  type        = string
  sensitive   = true
}

variable "alarm_email" {
  description = "Email para notificaciones de alarmas CloudWatch (vacío = sin suscripción)"
  type        = string
  default     = ""
}
