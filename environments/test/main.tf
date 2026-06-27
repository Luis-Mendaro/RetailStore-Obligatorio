locals {
  # Mismos 6 microservicios de docker-compose.yml + db/redis como servicios
  # internos. "public" replica que solo ui/admin tienen puerto expuesto hoy.
  # "layer" ordena la creacion para que cada servicio solo pueda referenciar
  # por DNS a servicios de una capa anterior (evita dependencia circular en
  # Terraform): 0 = sin dependencias, 1 = depende de la capa 0, etc.
  services = {
    db       = { public = false, container_port = 5432, needs_ecr = true, image = null, protocol = "TCP", layer = 0 }
    redis    = { public = false, container_port = 6379, needs_ecr = false, image = "redis:7-alpine", protocol = "TCP", layer = 0 }
    catalog  = { public = false, container_port = 8080, needs_ecr = true, image = null, protocol = "HTTP", layer = 1 }
    cart     = { public = false, container_port = 8080, needs_ecr = true, image = null, protocol = "HTTP", layer = 1 }
    orders   = { public = false, container_port = 8080, needs_ecr = true, image = null, protocol = "HTTP", layer = 1 }
    admin    = { public = true, container_port = 8080, needs_ecr = true, image = null, protocol = "HTTP", layer = 1 }
    checkout = { public = false, container_port = 8080, needs_ecr = true, image = null, protocol = "HTTP", layer = 2 }
    ui       = { public = true, container_port = 8080, needs_ecr = true, image = null, protocol = "HTTP", layer = 3 }
  }

  layer0 = { for k, v in local.services : k => v if v.layer == 0 }
  layer1 = { for k, v in local.services : k => v if v.layer == 1 }

  ecr_services = { for k, v in local.services : k => v if v.needs_ecr }
  ecr_urls     = { for k, m in module.ecr : k => m.repository_url }

  image_urls = {
    for k, v in local.services :
    k => v.needs_ecr ? "${local.ecr_urls[k]}:latest" : v.image
  }

  # Variables de entorno por servicio, equivalentes a las de docker-compose.yml
  # pero apuntando a los load balancers internos en vez de nombres de red Docker.
  layer0_env_vars = {
    db = [
      { name = "POSTGRES_USER", value = "retail_user" },
      { name = "POSTGRES_PASSWORD", value = var.db_password },
      { name = "POSTGRES_DB", value = "orders" },
    ]
    redis = []
  }

  layer1_env_vars = {
    catalog = [
      { name = "GIN_MODE", value = "release" },
      { name = "RETAIL_CATALOG_PERSISTENCE_PROVIDER", value = "postgres" },
      { name = "RETAIL_CATALOG_PERSISTENCE_ENDPOINT", value = "${module.ecs_service_l0["db"].endpoint_dns_name}:5432" },
      { name = "RETAIL_CATALOG_PERSISTENCE_DB_NAME", value = "catalogdb" },
      { name = "RETAIL_CATALOG_PERSISTENCE_USER", value = "retail_user" },
      { name = "RETAIL_CATALOG_PERSISTENCE_PASSWORD", value = var.db_password },
    ]
    cart = [
      { name = "CART_PERSISTENCE_PROVIDER", value = "postgres" },
      { name = "CART_POSTGRES_HOST", value = module.ecs_service_l0["db"].endpoint_dns_name },
      { name = "CART_POSTGRES_PORT", value = "5432" },
      { name = "CART_POSTGRES_DB", value = "cartdb" },
      { name = "CART_POSTGRES_USER", value = "retail_user" },
      { name = "CART_POSTGRES_PASSWORD", value = var.db_password },
      { name = "PORT", value = "8080" },
    ]
    orders = [
      { name = "GIN_MODE", value = "release" },
      { name = "RETAIL_ORDERS_PERSISTENCE_ENDPOINT", value = "${module.ecs_service_l0["db"].endpoint_dns_name}:5432" },
      { name = "RETAIL_ORDERS_PERSISTENCE_NAME", value = "orders" },
      { name = "RETAIL_ORDERS_PERSISTENCE_USERNAME", value = "retail_user" },
      { name = "RETAIL_ORDERS_PERSISTENCE_PASSWORD", value = var.db_password },
    ]
    admin = [
      { name = "DB_HOST", value = module.ecs_service_l0["db"].endpoint_dns_name },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_USER", value = "retail_user" },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "ADMIN_USERNAME", value = var.admin_username },
      { name = "ADMIN_PASSWORD", value = var.admin_password },
      { name = "ADMIN_JWT_SECRET", value = var.admin_jwt_secret },
    ]
  }
}

data "aws_iam_role" "lab_role" {
  name = var.lab_role_name
}

module "networking" {
  source = "../../modules/networking"

  environment        = var.environment
  vpc_name           = "retailstore-${var.environment}"
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones
}

module "ecs_cluster" {
  source = "../../modules/ecs"

  cluster_name = "retailstore-${var.environment}"
  environment  = var.environment
}

module "ecr" {
  source   = "../../modules/ecr"
  for_each = local.ecr_services

  name        = "retailstore-${each.key}-${var.environment}"
  environment = var.environment
}

module "ecs_service_l0" {
  source   = "../../modules/ecs_service"
  for_each = local.layer0

  app_name            = each.key
  environment         = var.environment
  cluster_id          = module.ecs_cluster.cluster_id
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  vpc_cidr_block       = var.vpc_cidr_block
  image_url            = local.image_urls[each.key]
  execution_role_arn   = data.aws_iam_role.lab_role.arn
  container_port       = each.value.container_port
  public               = each.value.public
  internal_protocol    = each.value.protocol
  cpu                  = var.task_cpu
  memory               = var.task_memory
  desired_count        = var.desired_count
  aws_region           = var.aws_region
  environment_variables = local.layer0_env_vars[each.key]
}

module "ecs_service_l1" {
  source   = "../../modules/ecs_service"
  for_each = local.layer1

  app_name            = each.key
  environment         = var.environment
  cluster_id          = module.ecs_cluster.cluster_id
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  vpc_cidr_block       = var.vpc_cidr_block
  image_url            = local.image_urls[each.key]
  execution_role_arn   = data.aws_iam_role.lab_role.arn
  container_port       = each.value.container_port
  public               = each.value.public
  internal_protocol    = each.value.protocol
  cpu                  = var.task_cpu
  memory               = var.task_memory
  desired_count        = var.desired_count
  aws_region           = var.aws_region
  environment_variables = local.layer1_env_vars[each.key]
}

module "ecs_service_checkout" {
  source = "../../modules/ecs_service"

  app_name           = "checkout"
  environment        = var.environment
  cluster_id         = module.ecs_cluster.cluster_id
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  vpc_cidr_block      = var.vpc_cidr_block
  image_url           = local.image_urls["checkout"]
  execution_role_arn  = data.aws_iam_role.lab_role.arn
  container_port      = local.services.checkout.container_port
  public              = local.services.checkout.public
  internal_protocol   = local.services.checkout.protocol
  cpu                 = var.task_cpu
  memory              = var.task_memory
  desired_count       = var.desired_count
  aws_region          = var.aws_region
  environment_variables = [
    { name = "RETAIL_CHECKOUT_PERSISTENCE_PROVIDER", value = "redis" },
    { name = "RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL", value = "redis://${module.ecs_service_l0["redis"].endpoint_dns_name}:6379" },
    { name = "RETAIL_CHECKOUT_ENDPOINTS_ORDERS", value = "http://${module.ecs_service_l1["orders"].endpoint_dns_name}" },
  ]
}

module "ecs_service_ui" {
  source = "../../modules/ecs_service"

  app_name           = "ui"
  environment        = var.environment
  cluster_id         = module.ecs_cluster.cluster_id
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  vpc_cidr_block      = var.vpc_cidr_block
  image_url           = local.image_urls["ui"]
  execution_role_arn  = data.aws_iam_role.lab_role.arn
  container_port      = local.services.ui.container_port
  public              = local.services.ui.public
  internal_protocol   = local.services.ui.protocol
  cpu                 = var.task_cpu
  memory              = var.task_memory
  desired_count       = var.desired_count
  aws_region          = var.aws_region
  environment_variables = [
    { name = "RETAIL_UI_ENDPOINTS_CATALOG", value = "http://${module.ecs_service_l1["catalog"].endpoint_dns_name}" },
    { name = "RETAIL_UI_ENDPOINTS_CARTS", value = "http://${module.ecs_service_l1["cart"].endpoint_dns_name}" },
    { name = "RETAIL_UI_ENDPOINTS_CHECKOUT", value = "http://${module.ecs_service_checkout.endpoint_dns_name}" },
    { name = "RETAIL_UI_ENDPOINTS_ORDERS", value = "http://${module.ecs_service_l1["orders"].endpoint_dns_name}" },
  ]
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  app_name                = "retailstore-ui"
  environment             = var.environment
  cluster_name            = module.ecs_cluster.cluster_name
  service_name            = module.ecs_service_ui.service_name
  alb_arn_suffix          = module.ecs_service_ui.alb_arn_suffix
  target_group_arn_suffix = module.ecs_service_ui.target_group_arn_suffix
  aws_region              = var.aws_region
  alarm_email             = var.alarm_email
}

module "lambda_alert" {
  source             = "../../modules/lambda_alert"
  function_name      = "retailstore-alert-handler-${var.environment}"
  environment        = var.environment
  execution_role_arn = data.aws_iam_role.lab_role.arn
  sns_topic_arn      = module.cloudwatch.sns_topic_arn
}
