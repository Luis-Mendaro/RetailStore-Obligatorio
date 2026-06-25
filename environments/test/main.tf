locals {
  # Mismos 6 microservicios de docker-compose.yml + db/redis como servicios
  # internos. "public" replica que solo ui/admin tienen puerto expuesto hoy.
  services = {
    catalog  = { public = false, container_port = 8080, needs_ecr = true, image = null }
    cart     = { public = false, container_port = 8080, needs_ecr = true, image = null }
    checkout = { public = false, container_port = 8080, needs_ecr = true, image = null }
    orders   = { public = false, container_port = 8080, needs_ecr = true, image = null }
    ui       = { public = true, container_port = 8080, needs_ecr = true, image = null }
    admin    = { public = true, container_port = 8080, needs_ecr = true, image = null }
    db       = { public = false, container_port = 5432, needs_ecr = true, image = null }
    redis    = { public = false, container_port = 6379, needs_ecr = false, image = "redis:7-alpine" }
  }

  ecr_services = { for k, v in local.services : k => v if v.needs_ecr }
  ecr_urls     = { for k, m in module.ecr : k => m.repository_url }

  image_urls = {
    for k, v in local.services :
    k => v.needs_ecr ? "${local.ecr_urls[k]}:latest" : v.image
  }

  # Variables de entorno por servicio, equivalentes a las de docker-compose.yml
  # pero apuntando a nombres DNS de Cloud Map en vez de nombres de red Docker.
  service_env_vars = {
    catalog = [
      { name = "GIN_MODE", value = "release" },
      { name = "RETAIL_CATALOG_PERSISTENCE_PROVIDER", value = "postgres" },
      { name = "RETAIL_CATALOG_PERSISTENCE_ENDPOINT", value = "db.retailstore.local:5432" },
      { name = "RETAIL_CATALOG_PERSISTENCE_DB_NAME", value = "catalogdb" },
      { name = "RETAIL_CATALOG_PERSISTENCE_USER", value = "retail_user" },
      { name = "RETAIL_CATALOG_PERSISTENCE_PASSWORD", value = var.db_password },
    ]
    cart = [
      { name = "CART_PERSISTENCE_PROVIDER", value = "postgres" },
      { name = "CART_POSTGRES_HOST", value = "db.retailstore.local" },
      { name = "CART_POSTGRES_PORT", value = "5432" },
      { name = "CART_POSTGRES_DB", value = "cartdb" },
      { name = "CART_POSTGRES_USER", value = "retail_user" },
      { name = "CART_POSTGRES_PASSWORD", value = var.db_password },
      { name = "PORT", value = "8080" },
    ]
    orders = [
      { name = "GIN_MODE", value = "release" },
      { name = "RETAIL_ORDERS_PERSISTENCE_ENDPOINT", value = "db.retailstore.local:5432" },
      { name = "RETAIL_ORDERS_PERSISTENCE_NAME", value = "orders" },
      { name = "RETAIL_ORDERS_PERSISTENCE_USERNAME", value = "retail_user" },
      { name = "RETAIL_ORDERS_PERSISTENCE_PASSWORD", value = var.db_password },
    ]
    checkout = [
      { name = "RETAIL_CHECKOUT_PERSISTENCE_PROVIDER", value = "redis" },
      { name = "RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL", value = "redis://redis.retailstore.local:6379" },
      { name = "RETAIL_CHECKOUT_ENDPOINTS_ORDERS", value = "http://orders.retailstore.local:8080" },
    ]
    ui = [
      { name = "RETAIL_UI_ENDPOINTS_CATALOG", value = "http://catalog.retailstore.local:8080" },
      { name = "RETAIL_UI_ENDPOINTS_CARTS", value = "http://cart.retailstore.local:8080" },
      { name = "RETAIL_UI_ENDPOINTS_CHECKOUT", value = "http://checkout.retailstore.local:8080" },
      { name = "RETAIL_UI_ENDPOINTS_ORDERS", value = "http://orders.retailstore.local:8080" },
    ]
    admin = [
      { name = "DB_HOST", value = "db.retailstore.local" },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_USER", value = "retail_user" },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "ADMIN_USERNAME", value = var.admin_username },
      { name = "ADMIN_PASSWORD", value = var.admin_password },
      { name = "ADMIN_JWT_SECRET", value = var.admin_jwt_secret },
    ]
    db = [
      { name = "POSTGRES_USER", value = "retail_user" },
      { name = "POSTGRES_PASSWORD", value = var.db_password },
      { name = "POSTGRES_DB", value = "orders" },
    ]
    redis = []
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

module "ecs_service" {
  source   = "../../modules/ecs_service"
  for_each = local.services

  app_name                       = each.key
  environment                    = var.environment
  cluster_id                     = module.ecs_cluster.cluster_id
  vpc_id                         = module.networking.vpc_id
  public_subnet_ids              = module.networking.public_subnet_ids
  private_subnet_ids             = module.networking.private_subnet_ids
  vpc_cidr_block                 = var.vpc_cidr_block
  service_discovery_namespace_id = module.networking.service_discovery_namespace_id
  image_url                      = local.image_urls[each.key]
  execution_role_arn             = data.aws_iam_role.lab_role.arn
  container_port                 = each.value.container_port
  public                         = each.value.public
  cpu                            = var.task_cpu
  memory                         = var.task_memory
  desired_count                  = var.desired_count
  aws_region                     = var.aws_region
  environment_variables          = local.service_env_vars[each.key]
}
