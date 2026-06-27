variable "function_name" {
  description = "Nombre de la función Lambda"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN del rol IAM que ejecuta la Lambda (LabRole)"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN del topic SNS al que se suscribe la Lambda"
  type        = string
}
