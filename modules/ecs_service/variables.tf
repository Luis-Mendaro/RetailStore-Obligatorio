variable "app_name" {
  description = "Nombre de la aplicación"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "cluster_id" {
  description = "ID del cluster ECS"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de subnets públicas (solo se usan si public = true, para el ALB)"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "IDs de subnets privadas (para las tareas)"
  type        = list(string)
}

variable "image_url" {
  description = "URL completa de la imagen de contenedor"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN del IAM role para la ejecución de tareas ECS (LabRole en el entorno de estudiante)"
  type        = string
}

variable "container_port" {
  description = "Puerto que expone el contenedor"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU para la tarea Fargate (en unidades)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memoria para la tarea Fargate (en MB)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Número de tareas deseadas"
  type        = number
  default     = 1
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "public" {
  description = "Si es true, el servicio queda detrás de un ALB público. Si es false, queda detrás de un load balancer interno (ALB o NLB segun internal_protocol), igual de alcance que la red interna que tenían en docker-compose."
  type        = bool
  default     = false
}

variable "internal_protocol" {
  description = "Protocolo del servicio cuando public = false: HTTP (ALB interno) o TCP (NLB interno, para Postgres/Redis)"
  type        = string
  default     = "HTTP"
}

variable "vpc_cidr_block" {
  description = "CIDR de la VPC, para permitir trafico interno entre microservicios cuando public = false"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Variables de entorno del contenedor, como lista de { name, value }"
  type = list(object({
    name  = string
    value = string
  }))
  default   = []
  sensitive = true
}
