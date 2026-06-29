# Decisiones de diseño — RetailStore

Registro de las decisiones técnicas más relevantes tomadas durante el proyecto, con su contexto y justificación.

---

## 1. AWS ECS Fargate como plataforma de orquestación

**Decisión:** desplegar los contenedores en AWS ECS Fargate en lugar de EKS (Kubernetes) u otras alternativas.

**Contexto:** el cliente no tiene equipo de infraestructura propio ni cultura DevOps. La solución debe ser operable sin conocimiento profundo de la plataforma subyacente.

**Justificación:**
- ECS Fargate es serverless — no requiere gestionar nodos EC2 ni grupos de auto-scaling
- La curva de aprendizaje es significativamente menor que Kubernetes
- Integración nativa con los demás servicios AWS usados (ALB, CloudWatch, ECR, IAM)
- Costo proporcional al uso real (sin instancias corriendo cuando no hay workload)

---

## 2. ALB para servicios públicos, NLB para servicios internos

**Decisión:** usar Application Load Balancer (ALB) para `ui` y `admin`, y Network Load Balancer (NLB) para los servicios internos (`catalog`, `cart`, `orders`, `checkout`).

**Justificación:**
- Los servicios internos solo necesitan balanceo TCP (capa 4) — no requieren inspección HTTP, reglas de ruteo por path ni terminación SSL
- NLB tiene menor latencia y menor costo que ALB para tráfico interno
- ALB se justifica para los servicios públicos porque permite reglas de seguridad HTTP y futura integración con WAF

---

## 3. Git Flow como estrategia de ramificación

**Decisión:** implementar Git Flow con ramas `main`, `develop` y `feature/*`.

**Contexto:** proyecto de consultoría con un único desarrollador y entregas por ambiente (dev/test/prod).

**Justificación:**
- `develop` actúa como rama de integración — permite acumular features antes de promover a producción
- `main` siempre refleja el estado de producción
- `feature/*` aísla el trabajo por tema, facilitando la revisión en PR
- Es la estrategia más adoptada en equipos pequeños con ciclos de release definidos

**Alternativa descartada:** Trunk-Based Development — requiere feature flags y una cultura de CI más madura que la que tiene el equipo del cliente.

---

## 4. Despliegue secuencial de ambientes (no simultáneo)

**Decisión:** los tres ambientes (dev/test/prod) no pueden correr en paralelo en la misma cuenta AWS.

**Causa:** los recursos de infraestructura no incluyen el nombre del ambiente en su identificador. Por ejemplo, el ALB de UI se llama `ui-alb` en todos los ambientes — si dos ambientes corren simultáneamente en la misma cuenta, Terraform falla al intentar crear un recurso con un nombre ya existente.

**Workaround aplicado:** destruir el ambiente anterior antes de desplegar el siguiente.

**Fix identificado:** agregar `-${var.environment}` al nombre de todos los recursos en `modules/ecs_service/main.tf` y `modules/cloudwatch/main.tf`. No se aplicó durante el proyecto por riesgo de romper despliegues activos a dos días de la entrega.

**Orden de despliegue usado:** dev → destroy dev → test → destroy test → prod → destroy prod.

---

## 5. Trivy no bloqueante para CVEs de la app de partida

**Decisión:** configurar Trivy SCA e image scan con `exit-code: "0"` (no bloqueante).

**Contexto:** la consigna prohíbe modificar el código de la aplicación de partida. Trivy detecta CVEs CRITICAL y HIGH en dependencias transitivas de varios servicios.

**Justificación:** bloquear el pipeline por vulnerabilidades que no pueden corregirse sin modificar código fuera del scope del proyecto impediría cualquier despliegue. Se opta por reportar los hallazgos como artifacts descargables y documentar el riesgo formalmente.

**Compensación:** Semgrep SAST sí es bloqueante para el código desarrollado por el equipo. Gitleaks es bloqueante para secretos en cualquier parte del repo.

---

## 6. Observabilidad centrada en el servicio UI

**Decisión:** configurar el dashboard de CloudWatch y las alarmas sobre el servicio UI en lugar de los 8 servicios.

**Justificación:**
- UI es el único punto de entrada público — sus métricas reflejan la experiencia real del usuario
- Los errores de los servicios internos (catalog, cart, orders) se propagan como errores 5XX o latencia alta en el ALB de UI
- Container Insights está habilitado en el cluster — CloudWatch recopila CPU y memoria de todos los servicios automáticamente, aunque no haya alarmas configuradas para ellos
- Monitorear los 8 servicios por separado generaría 40 alarmas y complejidad operativa no justificada para el tamaño del sistema

---

## 7. Lambda serverless para log estructurado de alertas

**Decisión:** usar una función Lambda Python 3.12 suscripta al topic SNS de alarmas.

**Propósito:** cuando una alarma se dispara, la Lambda recibe el evento SNS y lo registra como JSON estructurado en CloudWatch Logs. Esto permite búsquedas, filtros y auditoría de alertas con Logs Insights.

**Por qué no solo email:** el email no es searchable ni auditable. El log estructurado en CloudWatch Logs permite consultas como "cuántas veces se disparó la alarma de CPU en la última semana" o "qué servicio tuvo más alertas en producción".

---

## 8. Estado remoto de Terraform en S3

**Decisión:** usar un bucket S3 con versionado como backend para el estado de Terraform.

**Justificación:**
- Permite que el pipeline de GitHub Actions y el equipo local compartan el mismo estado
- El versionado de S3 permite recuperar estados anteriores ante un error
- Es el backend estándar para AWS sin costo adicional relevante

**Bucket:** `retailstore-obligatorio-lm-terraform-state` (us-east-1)

---

## 9. Protección de ramas en repositorio público

**Decisión:** el repositorio se configuró como público temporalmente para habilitar las Branch Protection Rules en GitHub Free.

**Contexto:** GitHub Free no permite Branch Protection Rules en repositorios privados. Para demostrar que `main` y `develop` requieren PR con aprobación, el repositorio se hizo público durante la captura de evidencia.

**Riesgo:** el código y la configuración de infraestructura quedaron visibles públicamente durante ese período. No hay secretos en el repositorio (todos están en GitHub Secrets), por lo que el riesgo es bajo.

**Estado actual:** repositorio privado.

---

## Lecciones aprendidas

| Lección | Aplicación futura |
|---------|-------------------|
| Incluir sufijo de ambiente en todos los nombres de recursos desde el inicio | Permite despliegues paralelos sin colisiones |
| Los mails de confirmación SNS van a spam en Gmail — confirmar antes de la demo | Crear filtro de spam para `@sns.amazonaws.com` al inicio del proyecto |
| Las credenciales de AWS Academy expiran cada 4h — planificar deploys en ventanas cortas | Tener credenciales frescas antes de cada pipeline |
| El cart de Python/psycopg2 no reconecta — hacer una compra inmediatamente al desplegar | Documentar el workaround en el runbook operativo |
| Terraform destroy puede dejar recursos huérfanos si un apply previo falló a mitad | Verificar con `aws elbv2 describe-target-groups` y `aws ec2 describe-addresses` después de cada destroy |
