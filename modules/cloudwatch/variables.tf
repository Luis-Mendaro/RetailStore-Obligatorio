variable "app_name" {
  description = "Nombre de la aplicación"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster ECS"
  type        = string
}

variable "service_name" {
  description = "Nombre del servicio ECS"
  type        = string
}

variable "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Sufijo del ARN del Target Group"
  type        = string
}

variable "alarm_email" {
  description = "Email para notificaciones"
  type        = string
  default     = ""
}

variable "cpu_threshold" {
  description = "% CPU para alarma"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "% memoria para alarma"
  type        = number
  default     = 80
}

variable "error_5xx_threshold" {
  description = "Errores 5XX para alarma"
  type        = number
  default     = 10
}

variable "response_time_threshold" {
  description = "Tiempo respuesta en segundos"
  type        = number
  default     = 2
}

variable "unhealthy_hosts_threshold" {
  description = "Hosts no saludables para alarma"
  type        = number
  default     = 1
}

variable "aws_region" {
  description = "Región AWS"
  type        = string
}
