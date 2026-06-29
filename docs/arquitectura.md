# Arquitectura — RetailStore

## Red y zonas de disponibilidad

```
                         Internet
                             │
                    ┌────────▼────────┐
                    │  Internet GW    │
                    └────────┬────────┘
                             │
         ┌───────────────────┼────────────────────┐
         │                   │                    │
  us-east-1a          us-east-1b             (ambas AZs)
  10.x.1.0/24         10.x.2.0/24
  (subnet pública)    (subnet pública)
         │                   │
  ┌──────▼─────┐    ┌────────▼──────┐
  │  NAT GW    │    │   NAT GW      │
  │  ui-alb    │    │   admin-alb   │
  └──────┬─────┘    └────────┬──────┘
         │                   │
  us-east-1a          us-east-1b
  10.x.11.0/24        10.x.12.0/24
  (subnet privada)    (subnet privada)
         │                   │
  ┌──────▼───────────────────▼──────┐
  │          ECS Fargate tasks      │
  │  ui / catalog / cart / checkout │
  │  orders / admin / db / redis    │
  └─────────────────────────────────┘
```

Cada ambiente (dev/test/prod) usa su propio bloque CIDR:

| Ambiente | VPC           | Subred pública A  | Subred pública B  | Subred privada A  | Subred privada B  |
|----------|---------------|-------------------|-------------------|-------------------|-------------------|
| dev      | 10.0.0.0/16   | 10.0.1.0/24       | 10.0.2.0/24       | 10.0.11.0/24      | 10.0.12.0/24      |
| test     | 10.1.0.0/16   | 10.1.1.0/24       | 10.1.2.0/24       | 10.1.11.0/24      | 10.1.12.0/24      |
| prod     | 10.2.0.0/16   | 10.2.1.0/24       | 10.2.2.0/24       | 10.2.11.0/24      | 10.2.12.0/24      |

---

## Exposición de servicios

```
Internet
   │
   ├──► ui-alb (público, puerto 80)  ──► ECS task ui
   │
   └──► admin-alb (público, puerto 80) ──► ECS task admin

  (tráfico interno — dentro de la VPC)

   ui-task ──► catalog-nlb ──► catalog-task
   ui-task ──► cart-nlb    ──► cart-task
   ui-task ──► checkout-nlb ──► checkout-task
   ui-task ──► orders-nlb  ──► orders-task

   checkout-task ──► orders-nlb ──► orders-task
   checkout-task ──► redis (ECS task, puerto 6379)

   catalog-task  ──► db (ECS task, puerto 5432)
   cart-task     ──► db (ECS task, puerto 5432)
   orders-task   ──► db (ECS task, puerto 5432)
   admin-task    ──► db (ECS task, puerto 5432)
```

`ui` y `admin` se exponen con **ALB** (HTTP/HTTPS). Los servicios internos usan **NLB** (TCP) porque solo necesitan balanceo de capa 4 sin inspección HTTP.

---

## Pipeline CI/CD — flujo completo

```
 Developer
     │
     │ git push feature/*
     ▼
┌─────────────────────────────────────────────────────┐
│                  GitHub Actions                     │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ En todo push y PR                            │   │
│  │                                              │   │
│  │  ┌───────────┐  ┌──────────────┐  ┌───────┐ │   │
│  │  │ Semgrep   │  │    Trivy     │  │ Tests │ │   │
│  │  │  SAST     │  │SCA+Gitleaks  │  │ unit  │ │   │
│  │  │(bloqueante│  │(Gitleaks blq)│  │(matrix│ │   │
│  │  └───────────┘  └──────────────┘  └───────┘ │   │
│  └──────────────────────────────────────────────┘   │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ Solo workflow_dispatch (ambiente elegido)    │   │
│  │                                              │   │
│  │  ┌──────────────────────────────────────┐   │   │
│  │  │ build-scan-push                      │   │   │
│  │  │  docker build (multi-stage)          │   │   │
│  │  │  trivy image scan (informativo)      │   │   │
│  │  │  docker push → ECR                   │   │   │
│  │  └─────────────────┬────────────────────┘   │   │
│  │                    │                         │   │
│  │  ┌─────────────────▼────────────────────┐   │   │
│  │  │ deploy                               │   │   │
│  │  │  aws ecs update-service              │   │   │
│  │  │  aws ecs wait services-stable        │   │   │
│  │  └──────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │     AWS ECS Fargate   │
              │   (ambiente elegido)  │
              └───────────────────────┘
```

---

## Infraestructura como código — flujo

```
  workflow_dispatch (ambiente: dev/test/prod)
              │
              ▼
  ┌───────────────────────────┐
  │      infra.yml            │
  │                           │
  │  terraform init           │
  │  terraform fmt -check     │
  │  terraform validate       │
  │  terraform plan           │
  │  terraform apply          │
  └───────────┬───────────────┘
              │
              ▼
  ┌───────────────────────────┐
  │  S3 — estado remoto       │
  │  (compartido por ambiente)│
  └───────────────────────────┘
              │
              ▼
  ┌───────────────────────────┐
  │  AWS: VPC, ECR, ECS,      │
  │  ALB/NLB, CloudWatch,     │
  │  SNS, Lambda              │
  └───────────────────────────┘
```

---

## Observabilidad

```
  ECS Tasks
      │ métricas
      ▼
  CloudWatch Metrics
      │ alarmas (5)
      ▼
  SNS Topic
      │ notificación
      ▼
  Lambda Python 3.12
      │ formato mensaje
      ▼
  Email (SNS subscription)
  securedev.lm@gmail.com
      │
      ▼
  Dashboard CloudWatch
  (CPU, memoria, 5XX, latencia, hosts)
```

---

## Estrategia de ramas

```
  main        ──────────●────────────────────────────●──
                        │ merge (PR aprobado)        │
  develop     ──────────●──────●──────●──────────────●──
                               │      │
  feature/*   ──────────────●──●  ──●─●
              (feature/terraform-iac-base)
                                  (feature/observabilidad)
                                      (feature/infra-pipeline)
```

Reglas de protección de rama en `main` y `develop`:

- Push directo bloqueado
- Se requiere al menos 1 aprobación de PR
- Los checks de CI deben pasar antes del merge

---

## Módulos Terraform

```
environments/
  dev/
    main.tf  ──────────────────────────────────────────────────────┐
    variables.tf                                                   │
    terraform.tfvars                                               │
                                                                   │ llama
modules/                                                           │
  networking/  ◄─────────────────────────────────────────────────┤
    main.tf    → VPC, subnets, IGW, NAT GW, route tables         │
                                                                   │
  ecr/         ◄─────────────────────────────────────────────────┤
    main.tf    → 8 repositorios ECR con lifecycle policy          │
                                                                   │
  ecs/         ◄─────────────────────────────────────────────────┤
    main.tf    → Cluster ECS Fargate + Container Insights         │
                                                                   │
  ecs_service/ ◄─────────────────────────────────────────────────┤
    main.tf    → task definition, ALB/NLB, target group,         │
                 security groups, ECS service (×8 servicios)      │
                                                                   │
  cloudwatch/  ◄─────────────────────────────────────────────────┤
    main.tf    → log groups, dashboard, 5 alarmas, SNS topic     │
                                                                   │
  lambda_alert/◄─────────────────────────────────────────────────┘
    main.tf    → función Python 3.12 para alertas de email
```
