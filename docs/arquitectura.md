# Arquitectura — RetailStore

## Red y zonas de disponibilidad

```mermaid
graph TD
    Internet --> IGW[Internet Gateway]
    IGW --> PubA["Subnet pública\nus-east-1a · 10.x.1.0/24"]
    IGW --> PubB["Subnet pública\nus-east-1b · 10.x.2.0/24"]
    PubA --> NAT_A[NAT Gateway A]
    PubB --> NAT_B[NAT Gateway B]
    PubA --> ALB_UI[ALB — ui]
    PubB --> ALB_Admin[ALB — admin]
    NAT_A --> PrivA["Subnet privada\nus-east-1a · 10.x.11.0/24"]
    NAT_B --> PrivB["Subnet privada\nus-east-1b · 10.x.12.0/24"]
    ALB_UI --> ECS["ECS Fargate Cluster\nui · catalog · cart · checkout\norders · admin · db · redis"]
    ALB_Admin --> ECS
    PrivA --> ECS
    PrivB --> ECS
```

Cada ambiente (dev/test/prod) usa su propio bloque CIDR:

| Ambiente | VPC           | Subred pública A  | Subred pública B  | Subred privada A  | Subred privada B  |
|----------|---------------|-------------------|-------------------|-------------------|-------------------|
| dev      | 10.0.0.0/16   | 10.0.1.0/24       | 10.0.2.0/24       | 10.0.11.0/24      | 10.0.12.0/24      |
| test     | 10.1.0.0/16   | 10.1.1.0/24       | 10.1.2.0/24       | 10.1.11.0/24      | 10.1.12.0/24      |
| prod     | 10.2.0.0/16   | 10.2.1.0/24       | 10.2.2.0/24       | 10.2.11.0/24      | 10.2.12.0/24      |

---

## Exposición de servicios

```mermaid
flowchart LR
    Internet --> ALB_UI["ALB ui\npúblico :80"]
    Internet --> ALB_Admin["ALB admin\npúblico :80"]
    ALB_UI --> UI[ui task]
    ALB_Admin --> Admin[admin task]
    UI --> CatNLB[catalog-nlb]
    UI --> CartNLB[cart-nlb]
    UI --> ChkNLB[checkout-nlb]
    UI --> OrdNLB[orders-nlb]
    CatNLB --> Catalog[catalog task]
    CartNLB --> Cart[cart task]
    ChkNLB --> Checkout[checkout task]
    OrdNLB --> Orders[orders task]
    Checkout --> OrdNLB
    Checkout --> Redis[(redis :6379)]
    Catalog --> DB[(db :5432)]
    Cart --> DB
    Orders --> DB
    Admin --> DB
```

`ui` y `admin` se exponen con **ALB** (HTTP/HTTPS). Los servicios internos usan **NLB** (TCP) porque solo necesitan balanceo de capa 4 sin inspección HTTP.

---

## Pipeline CI/CD — flujo completo

```mermaid
flowchart LR
    Push(["Push / PR"]) --> CodeScan["code-scan\nSemgrep SAST\nbloqueante"]
    Push --> SCA["sca-secrets\nTrivy SCA + Gitleaks\nGitleaks bloqueante"]
    Push --> Tests["test\nmatrix 6 servicios\nbloqueante"]
    Dispatch(["workflow_dispatch\nambiente elegido"]) --> CodeScan
    Dispatch --> SCA
    Dispatch --> Tests
    CodeScan --> Build["build-scan-push\nDocker build · Trivy image · ECR push\nsolo workflow_dispatch"]
    SCA --> Build
    Tests --> Build
    Build --> Deploy["deploy\nECS update-service\nwait services-stable"]
    Deploy --> ECS_F["AWS ECS Fargate\nambiente elegido"]
```

---

## Infraestructura como código — flujo

```mermaid
flowchart TD
    WD(["workflow_dispatch\nambiente: dev / test / prod"]) --> Infra[infra.yml]
    Infra --> Init[terraform init]
    Init --> Fmt[terraform fmt -check]
    Fmt --> Validate[terraform validate]
    Validate --> Plan[terraform plan]
    Plan --> Apply[terraform apply]
    Apply --> S3[(S3 — estado remoto)]
    Apply --> AWS["AWS\nVPC · ECR · ECS · ALB/NLB\nCloudWatch · SNS · Lambda"]
```

---

## Observabilidad

```mermaid
flowchart TD
    ECS[ECS Tasks] -->|métricas| CWM[CloudWatch Metrics]
    ECS -->|logs stdout| CWL[CloudWatch Logs]
    CWM -->|5 alarmas| SNS[SNS Topic]
    SNS -->|suscripción Lambda| Lambda[Lambda Python 3.12]
    SNS -->|suscripción email| Email["email directo\nsecuredev.lm@gmail.com\ndev y prod"]
    Lambda -->|JSON estructurado| CWL
    CWL --> Dashboard["Dashboard CloudWatch\nCPU · memoria · 5XX · latencia · hosts"]
```

---

## Estrategia de ramas

```mermaid
gitGraph
   commit id: "init"
   branch develop
   checkout develop
   branch "feature/terraform-iac-base"
   checkout "feature/terraform-iac-base"
   commit id: "terraform"
   checkout develop
   merge "feature/terraform-iac-base"
   branch "feature/observabilidad"
   checkout "feature/observabilidad"
   commit id: "observabilidad"
   checkout develop
   merge "feature/observabilidad"
   branch "feature/infra-pipeline"
   checkout "feature/infra-pipeline"
   commit id: "pipeline"
   checkout develop
   merge "feature/infra-pipeline"
   branch "feature/documentacion"
   checkout "feature/documentacion"
   commit id: "docs"
   checkout develop
   merge "feature/documentacion"
   checkout main
   merge develop tag: "v1.0"
```

Reglas de protección de rama en `main` y `develop`:

- Push directo bloqueado
- Se requiere al menos 1 aprobación de PR
- Los checks de CI deben pasar antes del merge

---

## Módulos Terraform

```mermaid
graph TD
    DEV["environments/dev\nvariables.tf · terraform.tfvars"]
    NET["networking\nVPC · subnets · IGW · NAT GW"]
    ECR["ecr\n7 repos · lifecycle policy"]
    ECS_C["ecs\nCluster Fargate · Container Insights"]
    ECSSVC["ecs_service\ntask def · ALB/NLB · service ×8"]
    CW["cloudwatch\nlog groups · dashboard · 5 alarmas · SNS"]
    LAMBDA["lambda_alert\nPython 3.12 · log JSON estructurado"]

    DEV --> NET
    DEV --> ECR
    DEV --> ECS_C
    DEV --> ECSSVC
    DEV --> CW
    DEV --> LAMBDA
```
