# Informe de testing y calidad — RetailStore

## Estrategia de testing adoptada

El proyecto combina dos capas de validación: pruebas unitarias automatizadas integradas en el pipeline CI/CD, y pruebas de integración end-to-end ejecutadas manualmente sobre el ambiente dev desplegado.

---

## Pruebas unitarias automatizadas

El pipeline ejecuta tests unitarios en cada push y pull request mediante un job matricial que cubre 6 servicios en paralelo.

| Servicio  | Herramienta   | Comando              | Resultado                  |
|-----------|---------------|----------------------|----------------------------|
| catalog   | Go test       | `go test ./...`      | Pasa — lógica de catálogo  |
| orders    | Go test       | `go test ./...`      | Pasa — lógica de órdenes   |
| ui        | npm test      | `npm test`           | Pasa — componentes Express |
| admin     | npm test      | `npm test`           | Pasa — rutas de admin      |
| checkout  | yarn test     | `yarn test`          | Pasa — flujo NestJS        |
| cart      | —             | sin tests unitarios  | Cubierto por validación E2E|

Los tests unitarios se ejecutan en todos los eventos del pipeline (push, PR, workflow_dispatch) y actúan como quality gate: si alguno falla, el pipeline se detiene antes de llegar al build.

---

## Validación de integración — pruebas end-to-end manuales

Se realizaron pruebas funcionales end-to-end sobre el ambiente dev desplegado en AWS, cubriendo el flujo completo de la aplicación:

1. **Navegación**: acceso a la tienda vía URL pública del ALB, carga del catálogo de productos
2. **Carrito**: adición de productos al carrito, verificación de persistencia en PostgreSQL. Se detectó que el servicio `cart` no reconecta automáticamente a PostgreSQL si la conexión se cierra por timeout — el task aparece como `HEALTHY` pero falla al agregar productos. Workaround aplicado: forzar un nuevo deployment (`aws ecs update-service --force-new-deployment`) y ejecutar el flujo del carrito inmediatamente después del deploy para calentar la conexión
3. **Checkout**: inicio del proceso de pago, integración con Redis para sesión y con el servicio orders
4. **Orden**: confirmación de la orden, verificación en la base de datos y en el panel admin

El flujo fue ejecutado en cada despliegue de dev antes de promover al siguiente ambiente. La evidencia de estos despliegues está en `docs/capturas/Deploy DEV.pptx`.

---

## Por qué no se automatizaron las pruebas de integración

La consigna del proyecto establece que **el código de la aplicación de partida no puede modificarse**. Agregar pruebas de integración automatizadas entre microservicios (Postman/Newman, Pact, REST-assured) requeriría modificar los contratos de API, agregar endpoints de health internos o incluir archivos de test en los repositorios de cada servicio — lo que implicaría modificar la app base.

Dado este constraint, el approach elegido fue:

- **Pipeline**: unit tests automatizados para validar la lógica de cada servicio de forma aislada
- **Pre-producción**: validación E2E manual sobre dev antes de cada promoción de ambiente
- **Observabilidad como red de seguridad**: las 5 alarmas de CloudWatch detectan errores 5XX, hosts no saludables y latencia alta en tiempo real durante y después del despliegue

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
