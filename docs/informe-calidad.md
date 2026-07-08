# Informe de testing y calidad — RetailStore

## Estrategia de testing adoptada

El proyecto implementa dos capas de validación automatizada: tests de integración contra el stack local (Capa 1, pre-deploy) y smoke tests contra el ambiente ECS real (Capa 2, post-deploy). Ambas capas usan los mismos 16 archivos pytest, diferenciándose solo por las URLs de destino.

---

## Pruebas de integración automatizadas

### Capa 1 — job `test` (pre-deploy, todos los eventos del pipeline)

Levanta el stack completo con `docker-compose` y ejecuta pytest contra `localhost`. Detecta errores de compilación, startup y funcionalidad básica antes del build de imágenes.

| Archivo | Tests | Qué verifica |
|---------|-------|--------------|
| test_health.py | 2 | GET /health en UI y admin |
| test_catalog.py | 3 | /catalog/products, /catalog/tags, /catalog/size |
| test_cart.py | 5 | CRUD completo de items: vacío, agregar, persistir, borrar, health check |
| test_checkout.py | 1 | Servicio checkout disponible |
| test_orders.py | 1 | GET /orders responde 200, body es lista o null |
| test_admin.py | 4 | Login, GET /admin/api/products, GET /admin/api/orders, 401 sin autenticación |

**Resultado en Capa 1: 16/16 pasan** (docker-compose, verificado localmente y en CI).

**Nota técnica — race condition de cart en CI:** `cart` (Python/psycopg2) conecta a Postgres en `__init__` sin retry. Si arranca antes de que `init-db.sql` cree `cartdb`, el proceso queda vivo pero sin `cart_service`. Fix aplicado en el pipeline: esperar a que `catalog` confirme que Postgres e `init-db.sql` terminaron, reiniciar el contenedor de cart, y luego esperar que `/api/carts/warmup/items` responda 200. Ver hallazgo #9 para el mismo bug en producción.

### Capa 2 — job `smoke-test` (post-deploy, solo `workflow_dispatch`)

Los mismos 16 tests corren contra los ALBs públicos en ECS real. Las URLs se obtienen de AWS CLI (`aws elbv2 describe-load-balancers`) antes de ejecutar pytest.

**Resultado final: 16/16 pasan** (run #28948699412, develop → dev, 2026-07-08).

#### Evolución durante el desarrollo

El smoke test no llegó a correr limpio de punta a punta en una sola sesión — los problemas se fueron descubriendo y corrigiendo en sucesivas corridas contra ECS real:

| Corrida | Resultado | Causa de los fallos | Fix aplicado |
|---------|-----------|---------------------|--------------|
| 1ª (post PR #13) | ~3/16 | admin devolvía 502 en todos los endpoints incluyendo login — proceso Node crasheaba por `ENOENT: /app/public/index.html` | PR #14: agregar `COPY --from=builder /app/public ./public` en Dockerfile de admin |
| 2ª (post PR #14) | 12/16 | 4 fallos en admin: login pasaba, pero `/admin/api/products`, `/admin/api/orders` y `/health` devolvían 502. orders también fallaba con `isinstance(None, list)` | PR #16: ajustar expectativa del test de orders (acepta null o []); el fallo de admin era timing-dependiente |
| 3ª (post PR #16, infra limpia) | **16/16** | — | — |

**Qué enseña la evolución:** el Dockerfile de admin tenía un bug real introducido al convertirlo a multi-stage — sin el smoke test contra la imagen publicada en ECR no se habría detectado (en docker-compose los bind mounts ocultan el problema). El fallo de 12/16 reveló además que el health check de admin, como el de cart, no verifica la conexión a Postgres — si el timing de startup es desfavorable, el servicio pasa el warm-up pero falla al primer request que toca la BD.

---

## Por qué las pruebas son de integración externa (no unitarias)

La consigna del proyecto establece que el código de la aplicación de partida no puede modificarse. Esto descarta:

- Pruebas unitarias dentro de los servicios (requieren modificar el código fuente)
- Contract testing con Pact (requiere modificar los contratos de API de la app base)

El approach elegido fue escribir pruebas de integración externas (black-box) contra los endpoints HTTP de cada servicio sin tocar su código fuente. Los 16 tests en `tests/` verifican el comportamiento observable desde afuera, igual que lo haría un cliente real de la API.

---

## Análisis de código estático — Semgrep

Semgrep ejecuta en cada push y PR con la configuración `--config=auto --error --severity ERROR`.

**Resultado:** sin hallazgos de severidad ERROR en el código desarrollado para este proyecto (pipelines, módulos Terraform, Dockerfiles).

**Reporte:** disponible como artifact `semgrep-report` (formato SARIF) en cada ejecución de GitHub Actions.

---

## Hallazgos de CVEs — Trivy

Trivy SCA e image scan detectan vulnerabilidades CRITICAL y HIGH en dependencias transitivas de la aplicación base.

**Decisión:** no bloqueante. La app base no puede modificarse, por lo que las dependencias afectadas no pueden parchearse dentro del scope del proyecto. Los hallazgos están documentados formalmente en `docs/seguridad.md`.

**Recomendación para producción:** actualizar las dependencias afectadas o reemplazarlas por alternativas sin CVEs activos una vez que el equipo interno tome el relevo.

---

## Hallazgos de calidad detectados durante las pruebas

### Hallazgo #9 — Health check de cart no verifica Postgres (Severidad: Alta)

**Archivo:** `src/cart/app/main.py`

**Descripción:** `GET /health` siempre devuelve `{"status": "UP"}` sin verificar la conexión a Postgres. El servicio conecta en `__init__` sin retry — si Postgres no está listo al arrancar, el proceso queda vivo pero sin `cart_service`, y cualquier endpoint del carrito devuelve 500.

**Impacto en producción:** el ALB usa `/health` para clasificar el target como sano o no. Como siempre devuelve 200, el ALB marca el servicio como HEALTHY aunque esté roto internamente. ECS nunca reinicia la tarea. La alarma `retailstore-ui-alb-unhealthy-hosts` no se dispara. El servicio queda degradado silenciosamente hasta un restart manual.

**Fix correcto (no aplicado — código de terceros):** `/health` debería ejecutar `SELECT 1` sobre la conexión activa y devolver 503 si falla.

---

### Hallazgo #10 — orders serializa lista vacía como JSON null

**Archivo:** `src/orders/main.go`

**Descripción:** `var orders []Order` es `nil` en Go. `c.JSON(200, orders)` serializa a `null` en lugar de `[]` cuando no hay órdenes en la BD.

**Impacto:** la UI maneja `null` correctamente y muestra lista vacía — sin impacto visible para el usuario. Sin embargo, el contrato HTTP correcto para una colección vacía es `[]`.

**Fix correcto (no aplicado — código de terceros):** usar `make([]Order, 0)` en lugar de `var orders []Order`.

---

### Hallazgo #12 — admin crashea al conectar a Postgres para rutas /admin/api/* (Severidad: Media)

**Observado en:** smoke tests (Capa 2) contra ECS real.

**Descripción:** `POST /auth/login` pasa (valida credenciales contra env vars, sin BD). Las rutas `GET /admin/api/products` y `GET /admin/api/orders` devuelven 502. Tras el crash del proceso Node.js, incluso `GET /health` devuelve 502.

**Causa probable:** el proceso crashea al intentar conectar a Postgres en el primer request que requiere BD, sin manejo de errores que permita recuperarse. Mismo patrón que hallazgo #9.

**Impacto:** panel de administración inaccesible en ECS real (salvo login). En docker-compose (Capa 1) funciona correctamente porque la conexión a Postgres se establece sin problemas.

**Fix correcto (no aplicado — código de terceros):** manejo de errores de conexión con retry y health check que refleje el estado real de la BD.
