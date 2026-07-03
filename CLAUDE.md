# CLAUDE.md — Memoria persistente del proyecto RetailStore-Obligatorio

Este archivo es la fuente de contexto para cualquier sesión nueva de Claude Code.
Leerlo completo antes de hacer cualquier cambio al repo.

---

## Estado actual del trabajo

**Fase:** Pulido para portfolio — proyecto ya entregado y defendido.
**Objetivo:** que cualquier persona (reclutador, tech lead) pueda leer el repo
sin que el autor esté al lado explicando. Funcional, consistente, sin mentiras.

**Reglas base (inamovibles):**
1. EL CÓDIGO Y TERRAFORM SON LA FUENTE DE VERDAD. Docs, diagramas y tests
   se ajustan al código, nunca al revés.
2. CERO HARDCODEO. URLs, IDs, credenciales, valores numéricos: siempre salen
   de variables de entorno, terraform output, o configuración real. Si no hay
   forma de evitarlo, se para y se consulta antes de seguir.
3. Cada inconsistencia nueva se registra en este CLAUDE.md ANTES de corregirla.

### Qué está hecho (sesión 2026-07-02)
- Infra Terraform 100% funcional y verificada en AWS real (sesiones anteriores)
- Pipelines CI/CD corriendo en GitHub Actions (sesiones anteriores)
- ARQUITECTURA_COMPLETA.md (repo privado) corregido y consistente (sesiones anteriores)
- **docs/arquitectura.md**: NAT 2→1, NLBs→ALBs para catalog/cart/orders/checkout,
  texto explicativo corregido, widget dashboard corregido
- **docs/decisiones.md** ADR #2: reescrito (ALB para HTTP, NLB solo db/redis)
- **README.md**: NAT ×2→×1, descripción dashboard UI-only
- **docs/seguridad.md**: diagram quality gates (TrivyImg solo en workflow_dispatch)

### Qué queda pendiente

**Frente B — docs y diagramas:**
- [ ] docs/informe-calidad.md — tabla de tests: describe no-ops como tests reales
      (debe actualizarse cuando tests reales estén implementados)
- [ ] README.md — auditoría completa (solo se corrigieron 2 líneas, puede haber más)
- [ ] Buscar menciones de "8 servicios" en contexto ECR/Dockerfiles (correcto: 7)
- [ ] Storytelling del README — ADRs visibles, contar el "por qué"
- [ ] Agregar referencia de versión/snapshot en encabezado de diagramas

**Frente A — tests de integración:**
- [ ] Completar auditoría de rutas (checkout y admin pendientes de leer)
- [ ] Verificar terraform outputs disponibles para ALB URLs
- [ ] Crear tests/conftest.py + tests/test_integration.py (pytest + requests)
- [ ] Agregar job smoke-test en app.yml (post-deploy, workflow_dispatch only)
- [ ] Actualizar docs/informe-calidad.md con descripción de tests reales

---

## Fuente de verdad — datos verificados contra el código

### Servicios

| Servicio | Tecnología | Puerto | ECR propio | Dockerfile |
|---|---|---|---|---|
| ui | Node.js | 8080 | sí | src/ui/Dockerfile |
| admin | Node.js | 8080 | sí | src/admin/Dockerfile |
| catalog | Go/Gin | 8080 | sí | src/catalog/Dockerfile |
| cart | Python/uvicorn | 8080 | sí | src/cart/Dockerfile |
| orders | Go/Gin | 8080 | sí | src/orders/Dockerfile |
| checkout | NestJS | 8080 | sí | src/checkout/Dockerfile |
| db | PostgreSQL 16 | 5432 | sí | db/Dockerfile |
| redis | Redis 7 Alpine | 6379 | **no** | **no tiene** — usa imagen pública |

- **ECS services: 8**
- **ECR repos: 7** (redis usa `redis:7-alpine` pública, `needs_ecr = false`)
- **Dockerfiles: 7** (redis no tiene)

### Load balancers (verificado en AWS real)

| Nombre | Tipo | Esquema |
|---|---|---|
| ui-alb | ALB application | internet-facing |
| admin-alb | ALB application | internet-facing |
| catalog-alb | ALB application | internal |
| cart-alb | ALB application | internal |
| orders-alb | ALB application | internal |
| checkout-alb | ALB application | internal |
| db-nlb | NLB network | internal |
| redis-nlb | NLB network | internal |

**Total: 6 ALBs + 2 NLBs.**
Regla en código: `use_nlb = !var.public && var.internal_protocol == "TCP"` (ecs_service/main.tf línea 5)

### Red (networking/main.tf + terraform.tfvars)

- VPC: `10.0.0.0/16` (dev) / `10.1.0.0/16` (test) / `10.2.0.0/16` (prod)
- Subnets públicas: `10.0.1.0/24` (us-east-1a), `10.0.2.0/24` (us-east-1b)
- Subnets privadas: `10.0.11.0/24` (us-east-1a), `10.0.12.0/24` (us-east-1b)
- **NAT Gateways: 1 solo**, en us-east-1a — decisión de costo de lab
- Todos los tasks en subnets privadas, `assign_public_ip = false`

### Pipeline app.yml

- **Triggers:** push a cualquier rama, PR a develop/main, workflow_dispatch
- **Jobs:** code-scan (Semgrep) → sca-secrets (Trivy + Gitleaks) → test → build-scan-push → deploy
- **build-scan-push:** solo si `workflow_dispatch`, matrix de **7 servicios** (sin redis)
- **deploy:** matrix de 7 servicios

### Tests — estado real

Todos los tests del job `test` son no-op. Ninguno ejecuta asserts reales:

| Servicio | Comando | Por qué es no-op |
|---|---|---|
| cart | `echo "sin tests..."` | no ejecuta nada |
| admin | `npm test --if-present` | no hay script `test` en package.json |
| ui | `npm test --if-present` | no hay script `test` en package.json |
| catalog | `go test ./...` | no hay archivos `*_test.go` |
| orders | `go test ./...` | no hay archivos `*_test.go` |
| checkout | `yarn test` | script `test` en package.json es `exit 0` |

**Solución decidida: DOS CAPAS de testing, mismos archivos, dos entornos.**

Arquitectura:
```
Push/PR:    code-scan → sca-secrets → test (Capa 1, docker-compose) → build-scan-push → deploy
                                                                                              ↓
workflow_dispatch:                                                             smoke-test (Capa 2, ECS real)
```

CAPA 1 — job `test` (pre-deploy, se rellena, no se elimina):
- docker-compose up con el docker-compose.yml existente
- pytest contra localhost (UI_URL=http://localhost:8080, ADMIN_URL=http://localhost:8081)
- Objetivo: detectar antes del build si imagen no compila o servicio no arranca
- Necesita secrets: DB_PASSWORD, ADMIN_USERNAME, ADMIN_PASSWORD, ADMIN_JWT_SECRET (ya en GitHub Secrets)
- NO necesita credenciales AWS

CAPA 2 — job `smoke-test` (post-deploy, workflow_dispatch only):
- pytest contra ECS real (UI_URL y ADMIN_URL de terraform output o AWS CLI)
- Objetivo: verificar ALBs, networking, DNS interno entre servicios
- Necesita credenciales AWS + mismos secrets de app

REUTILIZACIÓN: mismos archivos test_*.py, conftest.py diferencia el entorno solo por env vars.

Decisiones de diseño:
- Wait en Capa 1: loop `until curl http://localhost:8080/api/catalog/products` (no sleep fijo)
  Razón: depends_on solo espera que postgres ARRANQUE, no que acepte conexiones
- customer_id en tests: `f"ci-{os.getenv('GITHUB_RUN_ID', 'local')}"` 
  Razón: Capa 2 usa ECS persistente — datos acumulan entre runs, hay que aislar
- Admin tests: fixture `admin_session` con requests.Session() que hace POST /auth/login primero
  Razón: rutas /admin/api/* requieren JWT cookie HttpOnly — no se puede pasar manualmente

Naming resuelto: docker-compose llama al servicio `carts` (plural), ECS/Terraform/src lo llaman `cart` (singular). Los tests usan siempre /api/carts/* vía UI proxy — el nombre interno no importa para los tests.

**Auditoría de rutas reales (del código):**

| Servicio | Puerto | Rutas verificadas | Health check — ¿verifica dependencias? |
|----------|--------|-------------------|----------------------------------------|
| ui | 8080 | GET /health → "OK"; proxy /api/catalog/*, /api/carts/*, /api/checkout/*, /api/orders/* | No — siempre OK |
| catalog | 8080 | GET /catalog/products, /catalog/products/:id, /catalog/size, /catalog/tags, /health, /topology | Solo verifica chaosController (no DB) |
| cart | 8080 | GET /carts/{id}, GET/POST/PATCH/DELETE /carts/{id}/items, GET /carts/{id}/items/{item_id} | **BUG CONOCIDO**: devuelve 200 sin verificar Postgres |
| orders | 8080 | GET /orders, POST /orders, GET /health | No — `c.String(200, "OK")` sin DB check |
| checkout | 8080 | GET /checkout/{id}, POST /checkout/{id}/update, POST /checkout/{id}/submit, GET /health, GET /topology | Pendiente de verificar |
| admin | 8081* | POST /auth/login, GET /auth/me (auth), GET /admin/api/products (auth), GET /admin/api/orders (auth), GET /health | res.send('OK') — pendiente verificar |

*8081 es el puerto externo en docker-compose; en ECS el container escucha en 8080

**Shapes verificados:**
- Cart Item (POST body + response): `{ "itemId": str, "quantity": int, "unitPrice": int }`
- Cart Cart (GET response): `{ "customerId": str, "items": [Item] }`
- Orders Order (response): `{ "id": uuid, "createdDate": datetime, "firstName": str, "lastName": str, "email": str, "address1": str, "address2": str, "city": str, "state": str, "zipCode": str, "items": [OrderItem] }`
- Orders OrderItem: `{ "productId": str, "name": str, "quantity": int, "price": int, "totalCost": int }`
- Orders CreateOrderRequest (POST body): `{ "shippingAddress": ShippingAddress, "items": [OrderItem] }`
- Catalog GET /catalog/products: array de productos (shape pendiente de verificar — DB arranca vacía)

**Acceso a servicios internos desde tests externos:**
- catalog/cart/orders/checkout: ALBs internos (no accesibles desde internet)
- Vía proxy UI: `<ui-alb-url>/api/catalog/*`, `/api/carts/*`, `/api/orders/*`, `/api/checkout/*`
- admin: ALB público, accesible directo
- ui: ALB público

### Observabilidad (cloudwatch/main.tf)

5 alarmas sobre el servicio `ui`:

| Alarma | Umbral | Períodos |
|---|---|---|
| retailstore-ui-ecs-cpu-high | CPU ≥ 80% | 2 × 5 min |
| retailstore-ui-ecs-memory-high | Mem ≥ 80% | 2 × 5 min |
| retailstore-ui-alb-5xx-errors | 5XX ≥ 10 | 1 × 5 min |
| retailstore-ui-alb-unhealthy-hosts | unhealthy ≥ 1 | 1 × 1 min |
| retailstore-ui-alb-response-time | latencia ≥ 2s | 2 × 5 min |

Lambda `retailstore-alert-handler-dev` (Python 3.12, runtime inline en Terraform).
JSON logueado: `alarm`, `estado`, `razon` (sin tilde), `servicio`, `ambiente`.

---

## Inconsistencias ya detectadas (documentación vs código)

### 1. NAT Gateways — **CORREGIDO** (sesión 2026-07-02)
- Decía: 2 NAT Gateways (uno por AZ) — en docs/arquitectura.md y README.md
- Realidad: 1 solo NAT Gateway en us-east-1a (`networking/main.tf`)
- Archivos corregidos: docs/arquitectura.md, README.md

### 2. Tipo de load balancer — **CORREGIDO** (sesión 2026-07-02)
- Decía: catalog/cart/orders/checkout usan NLBs
- Realidad: catalog/cart/orders/checkout usan ALBs (HTTP); solo db/redis usan NLB (TCP)
- Archivos corregidos: docs/arquitectura.md (diagrama + texto), docs/decisiones.md (ADR #2 reescrito)

### 3. Dashboard CloudWatch — **CORREGIDO** (sesión 2026-07-02)
- Decía: dashboard con widgets "5XX · latencia · hosts"
- Realidad: dashboard tiene CPU + Memoria + Estado alarmas (ver cloudwatch/main.tf)
- Archivo corregido: docs/arquitectura.md

### 4. build-scan-push matrix — **CORREGIDO** en ARQUITECTURA_COMPLETA.md (sesión anterior)
- Decía: "8 servicios en paralelo"
- Realidad: 7 servicios (redis no tiene Dockerfile)
- Pendiente verificar: si aparece en otros docs

### 5. Campos JSON Lambda — **CORREGIDO** en ARQUITECTURA_COMPLETA.md (sesión anterior)
- Decía: campo `razón` (con tilde)
- Realidad: campo `razon` (sin tilde)

### 6. Quality gates diagram — **CORREGIDO** (sesión 2026-07-02)
- Decía: Push/PR → TrivyImg (Trivy image scan)
- Realidad: Trivy image scan solo corre en workflow_dispatch (job build-scan-push)
- Archivo corregido: docs/seguridad.md

### 7. Tests descritos como reales en informe-calidad.md — **PENDIENTE**
- Dice: "Pasa — lógica de catálogo", "Pasa — componentes Express", etc.
- Realidad: todos son no-op (ver tabla en sección Tests)
- Pendiente: actualizar cuando tests reales estén implementados

### 8. docker-compose nombra servicio `carts`, ECS/Terraform/src lo llaman `cart` — **REGISTRADO**
- Inconsistencia menor, no funcional
- docker-compose.yml línea 33: `carts:`, pero src/cart/, ECS service "cart", Terraform key "cart"
- Para tests no importa (siempre van por UI proxy /api/carts/*)
- Pendiente: mencionar en docs como nota de inconsistencia histórica

---

## Metodología de la auditoría

1. Antes de corregir cualquier doc, verificar el código real
2. Si se detecta una nueva inconsistencia, agregarla a la sección anterior ANTES de corregirla
3. Actualizar "Estado actual" al cerrar cada sesión
4. No asumir — si hay duda, `grep` o leer el `.tf` correspondiente

---

## Datos AWS del lab

- Cuenta: `058264384259` — región: `us-east-1`
- Rol: `LabRole` (pre-creado, sin permisos IAM para crear roles nuevos)
- Credenciales expiran cada ~4h — el usuario las renueva desde AWS Academy
- S3 backend: `retailstore-obligatorio-lm-terraform-state`, key `dev/terraform.tfstate`
- Secretos de deploy: en `.env` (gitignoreado) y como secrets de GitHub Actions
