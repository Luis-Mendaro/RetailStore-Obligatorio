locals {
  # Servicios internos que hablan un protocolo binario (Postgres, Redis) van
  # detras de un NLB (Network Load Balancer); el resto (HTTP) detras de un ALB,
  # publico si var.public = true, interno si no.
  use_nlb = !var.public && var.internal_protocol == "TCP"
}

resource "aws_security_group" "alb" {
  count       = local.use_nlb ? 0 : 1
  name        = "${var.app_name}-alb-sg"
  description = "Trafico permitido hacia el load balancer de ${var.app_name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.public ? ["0.0.0.0/0"] : [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    environment = var.environment
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.app_name}-tasks-sg"
  description = "Trafico permitido hacia las tareas ECS"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.use_nlb ? [] : [1]
    content {
      from_port       = var.container_port
      to_port         = var.container_port
      protocol        = "tcp"
      security_groups = [aws_security_group.alb[0].id]
    }
  }

  # Los NLB no tienen security group propio: el trafico llega con la IP
  # original del cliente, por eso se filtra directo por el CIDR de la VPC.
  dynamic "ingress" {
    for_each = local.use_nlb ? [1] : []
    content {
      from_port   = var.container_port
      to_port     = var.container_port
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr_block]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    environment = var.environment
  }
}

resource "aws_lb" "this" {
  count              = local.use_nlb ? 0 : 1
  name               = "${var.app_name}-alb"
  internal           = !var.public
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public ? var.public_subnet_ids : var.private_subnet_ids

  tags = {
    environment = var.environment
  }
}

resource "aws_lb_target_group" "this" {
  count       = local.use_nlb ? 0 : 1
  name        = "${var.app_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  count             = local.use_nlb ? 0 : 1
  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }
}

resource "aws_lb" "nlb" {
  count              = local.use_nlb ? 1 : 0
  name               = "${var.app_name}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  tags = {
    environment = var.environment
  }
}

resource "aws_lb_target_group" "nlb" {
  count       = local.use_nlb ? 1 : 0
  name        = "${var.app_name}-tg"
  port        = var.container_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    environment = var.environment
  }
}

resource "aws_lb_listener" "nlb" {
  count             = local.use_nlb ? 1 : 0
  load_balancer_arn = aws_lb.nlb[0].arn
  port              = var.container_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb[0].arn
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7

  tags = {
    environment = var.environment
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name        = var.app_name
      image       = var.image_url
      essential   = true
      environment = var.environment_variables
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.app_name}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    environment = var.environment
  }
}

resource "aws_ecs_service" "this" {
  name            = var.app_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = local.use_nlb ? aws_lb_target_group.nlb[0].arn : aws_lb_target_group.this[0].arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener.nlb]

  tags = {
    environment = var.environment
  }
}
