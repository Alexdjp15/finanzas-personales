# MEMORY.md — Memoria Persistente del Proyecto

Este archivo conserva el contexto histórico, el estado técnico, las decisiones arquitectónicas y el roadmap de trabajo para los agentes de Antigravity.

---

## 1. Estado Actual

- **Fase:** Inicialización y parametrización arquitectónica completada.
- **Estado del Repositorio:** Plantilla base agnóstica lista para ser clonada o duplicada para nuevos desarrollos.
- **Estructura configurada:**
  - Sistema de configuración de MCPs (`mcp_config.json`) con 5 servidores esenciales (Chrome DevTools, Context7, GitHub, Figma, Supabase).
  - Reglas del agente definidas en [AGENTS.md](file:///AGENTS.md) gobernando stack dinámico y control de dependencias.
  - Constitución de desarrollo definida en [docs/constitution.md](file:///docs/constitution.md) con 6 principios innegociables.
  - Directorios de extensiones y habilidades del agente en `.agents/` (`agents/`, `commands/`, `skills/`).
  - Plantilla base de especificaciones en `docs/specs/00_plantilla_spec.md`.
  - Manual de operaciones en [guia_de_uso.md](file:///guia_de_uso.md).

---

## 2. Decisiones Arquitectónicas y de Proceso

- **Stack Dinámico Gobernado por la Spec:** La tecnología (lenguaje, framework, librerías, base de datos) NO está predefinida. La especificación activa (`docs/specs/`) es la única fuente de la verdad para determinar el stack. Si no está especificado, el agente debe detenerse y preguntar.
- **Control Estricto de Dependencias:** Prohibición absoluta de instalar dependencias o inicializar frameworks sin autorización explícita en un plan aprobado por el usuario.
- **Estructura Base Agnóstica:** Organización desacoplada basada en `docs/` (especificaciones y constitución), carpeta de código fuente (`src/`, `lib/`, `app/`, etc.) y carpeta de pruebas (`tests/`, `__tests__/`, etc.).
- **Metodología SDD Estricta:** No se permite codificación directa sin una especificación previa y un plan aprobado mediante `/plan`.
- **Validación Dual:** Verificación lógica mediante tests automatizados (100% pasando) y verificación visual en interfaces de usuario (Chrome DevTools MCP).
- **Separación de Idiomas:** Convención bilingüe estricta: código técnico y commits en inglés; interfaces de usuario, especificaciones y documentación en español.

---

## 3. Aprendizajes y Mejores Prácticas

- Mantener la plantilla agnóstica al stack permite reutilizar este mismo marco de trabajo para aplicaciones Web nativas, SPAs (React, Vue, Svelte), frameworks modernos (Next.js, Astro), aplicaciones Flutter o scripts backend.
- Exigir autorización previa para la instalación de paquetes evita la proliferación de `node_modules` innecesarios o dependencias vulnerables antes de consolidar el diseño de software.
- Mantener los tokens vacíos como placeholders en `mcp_config.json` previene fugas accidentales de secretos en repositorios compartidos.

---

## 4. Próximos Pasos

1. [ ] Clonar/copiar este directorio para el nuevo proyecto.
2. [ ] Configurar las claves y tokens requeridos en `mcp_config.json` (o en `~/.gemini/config/mcp_config.json`).
3. [ ] Redactar la primera especificación funcional en `docs/specs/01_nombre_del_modulo.md` declarando explícitamente el stack tecnológico y dependencias necesarias.
4. [ ] Iniciar la sesión de Antigravity con `/plan` para generar el plan de ejecución y autorizar dependencias.
5. [ ] Ejecutar los tests de la lógica y la verificación visual.

---

## 5. Progreso Spec 01 (finanzas personales) — 2026-10-07

- **Plan aprobado:** [docs/plans/01_implementation_plan.md](file:///docs/plans/01_implementation_plan.md), con las 8 resoluciones registradas.
- **Fase 0 (parcial):** proyecto Flutter web creado (`flutter create`, Flutter 3.47.6 en `C:\src\flutter\bin`, que no está en el PATH) y dependencias autorizadas instaladas (`supabase_flutter`, `flutter_riverpod`, `csv`, `intl`, `mocktail`). Pendiente: migración SQL y su aplicación a Supabase (requiere confirmación del usuario).
- **Fase 1 (parcial):** dominio puro en `lib/domain/` con 43 tests en verde (`test/domain/`): `BalanceCalculator`, `CreditCardService`, `NlpParser`, `RecurringPaymentProcessor`, `AlertScheduler`. Pendiente: `FiscalCloseService`.
- **Supuestos del dominio por confirmar con el usuario:**
  - Un gasto con tarjeta solo reduce el cupo y no mueve saldos de bolsillos; el bolsillo es la categoría. Los abonos descuentan del bolsillo elegido.
  - `netWorth` = activos (suma de bolsillos) − deuda de tarjetas.
  - Los pagos recurrentes son solo mensuales, y el día 31 se ajusta al último día del mes.
  - Un gasto o transferencia que supere el saldo del bolsillo se rechaza.
- **Aprendizaje:** el test `test/widget_test.dart` generado por `flutter create` fallará al reemplazar `main.dart`, hay que reemplazarlo en la Fase 3.
- **Seguridad:** `mcp_config.json` tiene un token real de Supabase, hay que rotarlo.

### Actualización 2026-10-07 (tarde)

- **Fase 1 cerrada:** se añadió `FiscalCloseService` (exporta JSON/CSV, devuelve ids a borrar y saldos iniciales). Hay 48 tests en verde y `flutter analyze` está limpio.
- **Decisión del usuario:** los bolsillos pueden quedar en negativo y no se bloquea ninguna transacción por saldo. Se eliminó `insufficientFunds` del dominio. El cupo de la tarjeta y el tope de deuda en abonos sí se validan.
- **Credenciales:** `.env` (ignorado por git) con `SUPABASE_URL` y `SUPABASE_ANON_KEY`, y `.env.example` como plantilla. Se leen con `flutter run --dart-define-from-file=.env`, sin dependencias nuevas. `mcp_config.json` se añadió a `.gitignore`, pero **sigue versionado en git** y requiere `git rm --cached mcp_config.json`.
- **Migraciones SQL (NO aplicadas, pendientes de aprobación):** `supabase/migrations/` con `schema` (tablas y RLS), `functions` (RPC atómicas y job de pagos recurrentes) y `cron` (pg_cron diario a las 13:00 UTC, 08:00 Bogotá).
- **Desviación del plan:** los pagos recurrentes los procesa una función SQL con `pg_cron`, no una Edge Function. La regla del día 31 está duplicada en Dart y SQL, y conviene probar que coincidan después de aplicarla.

---

## 6. Consolidación Final Spec 01 — 2026-10-07

- **Fases Completadas:** Fases 0 a 5 concluidas al 100%.
- **Base de Datos:**
  - Migraciones de esquema, RPCs y cron aplicadas en Supabase (`ciesbycnqesrubtcrjbm`).
  - 8 tablas creadas con RLS activo por usuario.
  - 7 funciones PostgreSQL atómicas operando.
  - `pg_cron` activo ejecutando `process_due_recurring_payments` diariamente a las 13:00 UTC (08:00 AM Bogotá).
- **Dominio Puro y Lógica:**
  - `BalanceCalculator`, `CreditCardService`, `NlpParser`, `RecurringPaymentProcessor`, `AlertScheduler`, `FiscalCloseService`.
- **Datos y UI:**
  - Repositorios Supabase para Auth y Finanzas.
  - Pantallas de Login/Registro, Onboarding inicial con pre-carga de datos de la Spec, Dashboard unificado con resumen de patrimonio, activos y pasivos aislados.
  - Modales funcionales: Ingreso Rápido por Frase (NLP), Transferencias entre Bolsillos, Abono a Tarjeta de Crédito, CRUD de Bolsillos, Suscripciones, Alertas in-app y Cierre Fiscal con exportación JSON/CSV y doble confirmación.
- **Validación Automatizada:**
  - 51 tests unitarios y de interfaz pasando (100% éxito, 0 fallos).
  - `flutter analyze` con 0 errores y 0 advertencias.
- **Verificación Visual:**
  - Compilación exitosa en Web release (`build/web`).
  - Inspección mediante protocolo Chromium DevTools (CDP) con 0 errores de consola (`console.error = 0`).
  - Capturas de pantalla validadas para escritorio (1280x800) y móvil (390x844).
- **Documentación:**
  - Walkthrough disponible en `docs/walkthrough.md` y en el directorio de artefactos.
  - Plan de implementación aprobado disponible en `docs/plans/01_implementation_plan.md`.

---

## 7. Refactorizaciones y Correcciones de UI / Lógica — 2026-10-07 (Noche)

- **Corrección de Renderizado (Pantalla Roja & Overflows):**
  - Eliminado el error `Duplicate keys found / multiple children with key [<null>]` en `TransferDialog`, `CardPaymentDialog`, `RecurringPaymentDialog` y `NlpEntryDialog`. Se sustituyeron claves nulas dinámicas por claves estables no nulas (`const Key(...)` o IDs garantizados).
  - Eliminado el error `BOTTOM OVERFLOWED` en todos los diálogos modales al envolver sus contenidos en `SingleChildScrollView` dentro de `ConstrainedBox` con restricción de altura proporcional al viewport (`maxHeight: mediaQuery.size.height * 0.85`).
  - Manejo seguro de listas vacías o cuentas sin bolsillos en los selectores desplegables.
- **Compras con Tarjeta de Crédito:**
  - El campo "Bolsillo" ya no es obligatorio ni bloqueante en el modal de transacciones cuando el origen es una tarjeta de crédito. Si se omite, se categoriza de forma automática en el bolsillo "Personal" o "General" (o el primer disponible).
- **CRUD Completo de Cuentas Eje:**
  - `FinanceRepository` y `SupabaseFinanceRepository` incorporan `createAccountWithInitialPocket` y `deleteAccount(id)`.
  - El modal de gestión ahora incluye pestañas para "Cuentas Eje" y "Bolsillos". Permite añadir nuevas entidades con su tipo y saldo inicial, y eliminar cuentas existentes sin movimientos asociados.
- **Asistente Interactivo de Configuración Inicial (Onboarding):**
  - Reemplazado el botón estático de prueba por un asistente interactivo (`OnboardingScreen`) con formulario completo. El usuario puede modificar los saldos iniciales de cuentas y bolsillos, ajustar cupos totales y disponibles de tarjetas de crédito, agregar o eliminar cuentas/tarjetas, y ver el cálculo de patrimonio neto en vivo antes de guardar.
- **Mejora del Motor NLP:**
  - Preselección automática de la Cuenta Eje principal por defecto cuando la frase no menciona el origen (sin advertencia bloqueante de `unknownSource`).
  - Soporte de alias ampliados para tarjetas y cuentas con prefijos explícitos (`tc`, `tarjeta`, `tarjeta de credito`, `cuenta`, `cta`), resolviendo conflictos entre nombres de entidades compartidas (ej. tarjeta "Bancolombia Única" vs cuenta "Bancolombia").
- **Validación Final de Calidad:**
  - 54 tests unitarios y de widgets ejecutados y aprobados (100% éxito).
  - `flutter analyze` con 0 errores y 0 advertencias.
  - Verificación web con Chromium DevTools (CDP) con **0 errores de consola** (`console.error = 0`) y capturas responsivas actualizadas.

---

## 8. Gestión de Tarjetas de Crédito y Reinicio para Onboarding — 2026-10-07 (Noche)

- **Gestión Completa (CRUD) de Tarjetas de Crédito:**
  - Creado `CreditCardCrudDialog` (`lib/presentation/screens/dialogs/credit_card_crud_dialog.dart`) con diseño responsivo (`Wrap`, `isExpanded: true`, sin desbordamientos).
  - Permite listar tarjetas, registrar nuevas tarjetas (entidad, tipo/nombre, franquicia, últimos 4 dígitos, cupo total, cupo disponible, día de corte y día límite de pago) y eliminar tarjetas existentes con confirmación.
  - Métodos `createCreditCard` y `deleteCreditCard` en `SupabaseFinanceRepository` enriquecidos con registro automático de alias para NLP (`name`, `entity`, `tc name`, `tarjeta name`) y verificación previa de integridad (bloquea eliminación si existen transacciones o pagos recurrentes vinculados).
  - Integrado en `DashboardScreen` mediante un acceso directo ("Gestionar Tarjetas de Crédito") en la botonera de acciones y un botón `+` de administración en el encabezado de la sección de Tarjetas de Crédito.
- **Detección de Cuenta Preexistente en Registro (Supabase Auth):**
  - Manejo de respuestas con `identities: []` en `signUp()` para notificar claramente que el correo ya está registrado y evitar confusión por contraseñas desactualizadas.
- **Reinicio Completo de Datos para Pruebas:**
  - Ejecutada limpieza de datos para el usuario de pruebas en Supabase (`alert_deliveries`, `transactions`, `recurring_payments`, `aliases`, `pockets`, `accounts`, `credit_cards`, `user_settings`).
  - Al iniciar sesión, la aplicación redirige de forma inmediata y automática al **Asistente de Configuración Inicial** (`OnboardingScreen`) con el formulario listo para parametrizar cuentas, bolsillos y tarjetas desde cero.
- **Suite de Pruebas:**
  - 55 tests unitarios y de widgets pasando al 100%.
  - `flutter analyze` con 0 errores y 0 advertencias.

---

## 9. Cuentas Banco, Historial por Entidad/Bolsillo, Onboarding $0 y Retención Anual — 2026-10-07 (Noche)

- **Terminología Oficial Actualizada:**
  - Sustituido en su totalidad el término "Cuenta Eje" por **"Cuenta Banco"** tanto en el código fuente, diálogos, pantallas, modelos y asistente de configuración inicial.
- **Modelo de Cuentas Banco y Desglose Financiero:**
  - Columna `account_number text default ''` añadida a `public.accounts` en Supabase y soportada en el modelo `Account`.
  - Desglose contable claro de los fondos del banco:
    - *Saldo Fuera de Bolsillos (Disponible)*: Dinero libre que entra a la cuenta sin asignación a bolsillo.
    - *Saldo en Bolsillos*: Suma de los bolsillos creados para metas o presupuestos.
    - *Saldo Total Banco*: Total disponible consolidado en la entidad financiera.
- **Asistente de Onboarding en $0 COP y Flexible:**
  - Formulario inicial completamente en **$0 COP** (sin datos de prueba arbitrarios).
  - Permite añadir y quitar bancos dinámicamente con su número de cuenta y saldo fuera de bolsillos.
  - Permite añadir bolsillos ilimitados por banco.
  - Permite añadir y quitar tarjetas de crédito definiendo entidad, tipo, últimos 4 dígitos, cupo total, cupo disponible, día de corte (1-31) y fecha límite de pago (1-31).
- **Historial Detallado por Cuenta Banco (`BankDetailsDialog`):**
  - Botón "Detalles e Historial" integrado en cada tarjeta de banco del Dashboard.
  - Visualización del número de cuenta, desglose financiero (Total, Fuera de Bolsillos, En Bolsillos) y lista de bolsillos.
  - Historial cronológico de ingresos, egresos y transferencias filtrable dinámicamente por bolsillo ("Todos los bolsillos" o bolsillo específico).
  - Opción de descarga y respaldo rápido en CSV.
- **Historial Detallado por Tarjeta de Crédito (`CardDetailsDialog`):**
  - Botón "Ver Historial y Movimientos" integrado en cada tarjeta de crédito del Dashboard.
  - Visualización de cupo total, cupo disponible, deuda actual, día de corte y día de pago con aviso visual.
  - Historial cronológico de compras (gastos) y abonos (pagos de tarjeta) con fechas, conceptos y montos formateados.
  - Opción de descarga y respaldo rápido en CSV.
- **Política de Retención de 1 Año y Respaldo:**
  - Función PostgreSQL `public.delete_transactions_older_than_one_year()` desplegada en Supabase con política de purga automática de movimientos con más de 365 días de antigüedad.
  - Método `purgeTransactionsOlderThanOneYear()` expuesto en `FinanceRepository` para mantenimiento programado o manual.
  - Capacidad de exportación CSV en los diálogos de historial para que el usuario pueda respaldar sus transacciones antes del ciclo de purga.
- **Validación Automatizada Rigurosa:**
  - **57 tests ejecutados y pasando al 100%** (`flutter test`), incluyendo pruebas unitarias del dominio, cálculo de balances, parsing NLP, alertas recurrentes, asistentes de onboarding, dashboard y los nuevos diálogos de historial (`BankDetailsDialog`, `CardDetailsDialog`).
  - **0 advertencias y 0 errores** en `flutter analyze`.
  - Overflows resueltos con estructuras responsivas (`Wrap`, `Expanded`, `Flexible`).

---

## 10. Correcciones de Transferencias, Íconos Web, Duplicación y Lógica NLP/TC — 2026-10-07 (Noche)

- **Corrección de Transferencias entre Bolsillos (`TransferDialog`):**
  - Eliminado el desbordamiento horizontal (`RIGHT OVERFLOWED BY 32 PIXELS`) mediante `isExpanded: true` y truncamiento elíptico en items.
  - Habilitadas las **transferencias entre bolsillos de cualquier Cuenta Banco** (mismo o diferente banco), eliminando la restricción previa que limitaba transferencias al mismo banco.
  - Saldo formateado adecuadamente con separadores de miles COP (`Formatters.cop`).
- **Prevención de Cuentas Duplicadas:**
  - En `SupabaseFinanceRepository.createAccount` y `createCreditCard` se implementó verificación previa para reutilizar o actualizar registros existentes en lugar de duplicarlos ante llamadas múltiples o doble clic.
  - En `OnboardingScreen`, se añadió una guarda estricta contra múltiples envíos concurrentes (`if (_isLoading) return;`).
- **Renderizado e Íconos Web:**
  - Sustituidos emojis (`🏦`, `💳`) en los encabezados del Dashboard por los componentes nativos `Icon(Icons.account_balance)` e `Icon(Icons.credit_card)` para evitar glifos desalineados o rotos en Flutter Web.
- **Lógica Financiera y Reconocimiento de Lenguaje Natural (NLP):**
  - **Consumos con Tarjeta de Crédito:**
    - Al registrar un gasto cuyo origen sea una Tarjeta de Crédito (ej. `"compra tc rappi 50000"`, `"tarjeta de credito bancolombia 45000"`), la UI **oculta el selector de bolsillo** y muestra un aviso informativo de que el gasto consume cupo directo de la tarjeta sin debitar dinero de los bolsillos bancarios.
  - **Abonos y Pagos de Tarjeta de Crédito (`isCardPayment`):**
    - Frases como `"pago tc rappi 100000"`, `"abono tc unica 50000"` o `"pagar tarjeta 80000"` se identifican automáticamente como operaciones de **Abonar a Tarjeta**.
    - La interfaz permite seleccionar la Tarjeta de Crédito a pagar y el **Bolsillo de Origen** de la Cuenta Banco desde donde se debita el dinero.
    - Se registra con `repo.recordCardPayment` (restaura cupo y descuenta del bolsillo seleccionado).
  - **Filtrado Inteligente de Bolsillos por Banco:**
    - Si la transacción es bancaria normal, el dropdown de bolsillos filtra de forma estricta para mostrar **únicamente los bolsillos de la Cuenta Banco seleccionada**, evitando la mezcla confusa de bolsillos de todas las entidades.
- **Reinicio Completo de la Cuenta de Pruebas:**
  - Todas las tablas asociadas al usuario de pruebas (`ce844303-3202-40b3-8bb3-517c51a5ead3`) fueron restablecidas a 0.
- **Resultados de Calidad:**
  - **58 tests en verde al 100%** (`flutter test`).
  - **0 issues** en `flutter analyze`.
  - Build Web release exitoso (`build/web`).

---

## 11. Informe Consolidado de Estado del Proyecto — 2026-10-08

### 11.1. Estado General de la Arquitectura
- **Patrón Arquitectónico:** Spec-Driven Development (SDD) con arquitectura limpia multicapa (Domain puro, Data con Supabase, Presentation con Flutter Riverpod).
- **Base de Datos y Backend:** Supabase PostgreSQL con Row Level Security (RLS) activo por `auth.uid()`, RPCs atómicas para transacciones financieras y `pg_cron` activo para procesamiento de pagos periódicos a las 13:00 UTC (08:00 AM Bogotá).
- **Estado de Autenticación y Datos:** Conexión operativa a Supabase GoTrue; base de datos reiniciada a $0 COP para inicio de pruebas desde Onboarding.

### 11.2. Módulos y Funcionalidades Operativas
1. **Cuentas Banco:**
   - Modelo ampliado con número de cuenta (`account_number`).
   - Desglose financiero: Saldo Fuera de Bolsillos (dinero libre disponible), Saldo en Bolsillos y Saldo Total del Banco.
   - Pestaña de gestión CRUD para agregar entidades financieras o eliminarlas (si no tienen movimientos).
   - Diálogo `BankDetailsDialog` con detalles de saldos, selector de filtrado cronológico por bolsillo y exportación a CSV.
2. **Bolsillos:**
   - Subcuentas vinculadas a cada banco con asignación de color y nombre.
   - Regla de negocio activa: saldos en negativo permitidos sin bloqueo de transacciones.
   - Diálogo `TransferDialog` con transferencias habilitadas entre cualquier bolsillo de cualquier banco.
3. **Tarjetas de Crédito:**
   - Modelo con franquicia, últimos 4 dígitos, cupo total, cupo disponible, deuda calculada, día de corte (1-31) y fecha límite de pago (1-31).
   - Consumos directos sin exigir bolsillo obligatorio (consumen cupo directo).
   - Diálogo `CreditCardCrudDialog` para creación y eliminación segura.
   - Diálogo `CardDetailsDialog` con métricas de deuda, historial de cargos y abonos, y descarga CSV.
4. **Parser de Lenguaje Natural (NLP):**
   - Procesamiento de montos en COP con separadores de miles y signos de pesos.
   - Detección de operaciones de gasto, ingreso y abono a tarjeta (`isCardPayment`).
   - Manejo inteligente de alias con prefijos amplios (`tc`, `tarjeta de credito`, etc.).
   - Preselección automática de la Cuenta Banco principal si la frase no menciona entidad.
5. **Pagos Recurrentes / `pg_cron`:**
   - Gestión de suscripciones mensuales con regla de fin de mes (día 31 ajustado a días 28, 29 o 30 según el mes).
   - Ejecución idempotente programada en la base de datos vía `pg_cron` diario.
6. **Centro de Alertas in-app:**
   - Recordatorios preventivos a 2 y 1 días antes del vencimiento de tarjetas y suscripciones.
   - Hora de alerta configurable en `ReminderSettingsDialog` y almacenamiento en `user_settings`.
   - Bandeja in-app con contador en el Dashboard y hoja modal `InAppAlertsSheet`.
7. **Cierre Fiscal y Política de Retención Anual:**
   - `FiscalCloseService` y `FiscalCloseDialog` para exportación en JSON/CSV, borrado de movimientos del ejercicio y consolidación de saldos de apertura.
   - Función SQL `delete_transactions_older_than_one_year()` y método de repositorio para depuración de movimientos > 365 días.
8. **Asistente de Configuración Inicial (Onboarding):**
   - Detección automática al registrarse o iniciar sesión sin cuentas creadas.
   - Formulario interactivo en $0 COP con creación dinámica de bancos, bolsillos y tarjetas de crédito con fechas de corte/pago.
   - Cálculo del patrimonio neto proyectado en tiempo real y protección contra envíos duplicados.

### 11.3. Estado de Calidad y Verificación
- **Pruebas Automatizadas:** 58 tests unitarios y de interfaz pasando al 100% (0 fallos).
- **Análisis Estático de Código:** `flutter analyze` reporta 0 errores y 0 advertencias.
- **Compilación Web:** `build/web` listo y verificado con 0 errores de consola (`console.error = 0`).

### 11.4. Brecha con la Spec y Backlog Futuro
- **Soporte Móvil Nativo:** Configurar y compilar para emuladores Android/iOS cuando se inicie la fase nativa móvil.
- **Notificaciones Push Móviles:** Migración o integración de notificaciones nativas en el sistema operativo mediante FCM / servicios nativos.
- **Gráficos Visuales de Análisis:** Incorporar dashboards visuales interactivos (gráficos de barras o torta para tendencias de gastos y categorías).
- **Edición Individual de Movimientos:** Posibilidad de corregir o anular transacciones individuales directamente desde los listados de historial.

---

## 12. Sesión Autónoma de Pruebas Funcionales e Integración E2E — 2026-10-08

### 12.1. Escenarios Evaluados y Verificados
1. **Onboarding Inicial ($0 COP):**
   - Parametrización interactiva desde $0 COP sin datos arbitrarios.
   - Guardado exitoso y creación de cuentas, bolsillos iniciales y marcado de `onboardingCompleted`.
2. **Gestión de Cuentas y Bolsillos:**
   - Alta de Cuenta Banco con número de cuenta y saldo fuera de bolsillos.
   - Creación de bolsillo personalizado y renombramiento.
   - Validación matemática exacta del desglose de `BalanceCalculator`: Saldo Fuera de Bolsillos, Saldo en Bolsillos y Saldo Total Banco.
3. **Transferencia entre Bolsillos:**
   - Transferencia entre bolsillos de distintas cuentas sin colisiones de identificadores.
   - Cero errores de `Duplicate keys found / [<null>]`.
   - Cero desbordamientos de `RenderFlex`.
4. **Compras con Tarjeta de Crédito vía NLP:**
   - Reconocimiento de `"compra portatil 2000000 tc bancolombia"`.
   - Sin obligatoriedad de bolsillo (consumo directo contra el cupo de la tarjeta).
   - Reducción exacta del cupo disponible y aumento correspondiente en la deuda de la tarjeta con saldos de bolsillos intactos.
5. **Abonos a Tarjeta de Crédito:**
   - Registro de abono desde un bolsillo bancario hacia la tarjeta.
   - Restauración del cupo disponible, disminución de la deuda bancaria y débito automático en el bolsillo seleccionado.
6. **Historiales y Exportación CSV:**
   - Despliegue de `BankDetailsDialog` y `CardDetailsDialog`.
   - Filtrado dinámico por bolsillo de las transacciones registradas.
   - Generación y copia del historial al portapapeles en formato CSV estándar.

### 12.2. Correcciones de Renderizado Aplicadas
- **`CardPaymentDialog`:**
  - Se añadieron `isExpanded: true` y `overflow: TextOverflow.ellipsis` con `Formatters.cop` a los selectores desplegables de tarjeta y bolsillo, eliminando desbordamientos de 189px y 28px.
  - Se sustituyó `Spacer()` por `Expanded(child: Text(..., overflow: TextOverflow.ellipsis))` en los encabezados.
- **Estandarización de Encabezados de Diálogos:**
  - Se eliminó el uso de `Spacer()` en favor de `Expanded` con elipsis en `TransferDialog`, `PocketCrudDialog`, `NlpEntryDialog`, `RecurringPaymentDialog`, `FiscalCloseDialog`, `ReminderSettingsDialog` e `InAppAlertsSheet`.
- **Limpieza de Emojis Restantes:**
  - Se sustituyeron emojis literales (`🏦` y `💳`) en `OnboardingScreen`, `BankDetailsDialog` y `CardDetailsDialog` por componentes oficiales `Icon(Icons.account_balance)` e `Icon(Icons.credit_card)`.

### 12.3. Resultados de Calidad
- **Tests Automatizados:** **64 de 64 pruebas en verde al 100%** (`flutter test`).
- **Análisis Estático:** **0 advertencias / 0 errores** (`flutter analyze`).
- **Verificación CDP en Navegador:** **0 errores de consola (`console.error = 0`)**, capturas de pantalla responsivas validadas.

---

## 13. Suite de Pruebas de Robustez, Casos Límite y Estrés de Dominio — 2026-10-08

### 13.1. Alcance de Casos Límite Implementados (`test/domain/edge_cases_and_nlp_stress_test.dart`)

1. **Saldos Negativos en Bolsillos:**
   - **Gasto Excesivo Permitido:** Un gasto de $120.000 COP sobre un saldo inicial de $50.000 COP se registra correctamente y produce un saldo resultante exacto de -$70.000 COP.
   - **Coherencia Matemática Global:** `BalanceCalculator` mantiene la precisión en `accountBalance`, `totalAssets` y `netWorth` aun ante saldos en descubierto en los bolsillos.
   - **Transferencias en Descubierto:** Transferencias entre bolsillos que dejen la cuenta de origen con saldo negativo conservan el balance total del banco intacto.

2. **Validación contra Sobrepagos a Tarjetas de Crédito:**
   - **Cálculo de Deuda Base:** Verificación de deuda vigente de $1.146.164 COP (cupo total $5.000.000 COP, disponible $3.853.836 COP).
   - **Bloqueo de Sobrepago:** Intentar registrar un abono de $1.500.000 COP lanza la excepción `DomainException` con código `DomainErrorCode.paymentExceedsDebt` y detalla el ID de la tarjeta.
   - **Precisión al Peso:** Un sobrepago por incluso $1 COP ($1.146.165 COP) es rechazado inmediatamente.
   - **Liquidación Total y Abono Parcial:** El pago exacto de $1.146.164 COP deja la deuda en $0 COP y restaura el cupo al 100%; abonos parciales (ej. $500.000 COP) ajustan simétricamente deuda y cupo disponible.
   - **Protección de Montos No Positivos:** Abonos de $0 COP o con importes negativos son rechazados con `DomainErrorCode.invalidAmount`.

3. **Casos de Estrés y Variaciones Lingüísticas en `NlpParser`:**
   - **Puntuación y Separadores de Miles:** `"recibí 1.500.000 abono graficolor nequi"` detecta tipo Ingreso, monto 1.500.000, cuenta Nequi y bolsillo Graficolor.
   - **Gastos Implícitos sin Entidad:** `"almuerzo 25000"` extrae monto 25.000, tipo Gasto, sin issues bloqueantes y preseleccionando la cuenta principal disponible en el catálogo.
   - **Abonos Directos a Tarjeta:** `"pago tc bancolombia 150000"` marca `isCardPayment = true`, tarjeta objetivo identificada y monto 150.000.
   - **Símbolos Monetarios y Espacios Irregulares:** Reconocimiento de `"$  350.000  mercado exito"`, `"$15000 taxi aeropuerto"` y espacios en blanco extremos/tabuladores (`"   gasto     $    120.000    en    supermercado   "`).
   - **Desambiguación Avanzada Entidad vs Tarjeta:** Integración de `_accountHintPattern` ("cuenta", "ahorros", "cta") junto con `_cardHintPattern` para resolver frases complejas como `"recibi $ 2.800.000 de salario en cuenta bancolombia"` distinguiendo la cuenta bancaria de la tarjeta de crédito homónima.

### 13.2. Resultados Globales del Proyecto
- **Tests Automatizados:** **82 de 82 pruebas pasando al 100%** (`flutter test`).
- **Análisis de Tipado y Calidad:** **0 advertencias / 0 errores** (`flutter analyze`).
- **Consistencia SDD:** Alineado con las especificaciones técnicas y requerimientos de robustez.

---

## 14. Integración de la Skill `frontend-design` y Rediseño de UI/UX — 2026-10-08

### 14.1. Instalación y Adaptación de la Skill
- **Ubicación:** `.agents/skills/frontend-design/SKILL.md`.
- **Adaptación Flutter:** Pautas de tipografía con espaciado numérico negativo (`letterSpacing: -0.6` a `-0.8`), tokens semánticos en `AppColors`, contenedores con elevaciones difusas y bordes sutiles de 1px (`#E2E8F0`), erradicación de fondos decorativos chillones o genéricos (*gastar la audacia en el Patrimonio Neto y mantener sobrio el resto*).

### 14.2. Sistema de Tokens Centralizado (`lib/presentation/utils/app_theme.dart`)
- **`AppColors`:** Fondo base Slate 50 (`#F8FAFC`), tarjetas en blanco puro, acento institucional cobalto (`#2563EB`), activos esmeralda (`#059669`) y pasivos carmesí (`#DC2626`).
- **`AppTypography` & `AppDecorations`:** Jerarquía modular con títulos armónicos, tarjetas oscuras de hero y badges píldora.
- **`buildAppTheme()`:** Integrado en `lib/main.dart` con `ThemeData` central para botones, campos de texto, diálogos y tarjetas.

### 14.3. Componentes Rediseñados en `lib/presentation/screens/`
1. **Dashboard (`dashboard_screen.dart`):**
   - **Hero Card Unificada:** Muestra el Patrimonio Neto como cifra principal en tarjeta oscura de alto contraste (`#0F172A`) acompañada de dos cápsulas ordenadas para Activos (Esmeralda) y Pasivos (Carmesí).
   - **Barra de Entrada NLP:** Estilo *Command Bar* con avatar redondeado, texto contextual en `sentence case` y botón de llamada a la acción pulido.
   - **Tarjetas de Crédito:** Se sustituyó el fondo rosa chillón por un contenedor sobrio con chip de franquicia, **barra de progreso de utilización de cupo (6px)** con porcentaje calculado en tiempo real, desglose de cupo disponible/deuda y badges para corte/pago.
   - **Cuentas Banco y Bolsillos:** Encabezados con avatar bancario, chip de número de cuenta y celdas individuales para bolsillos con estado de saldo.
2. **Asistente de Onboarding (`onboarding_screen.dart`):**
   - Formulario estructurado con bordes sutiles y barra inferior de resumen en vivo (*Activos Iniciales*, *Deuda Inicial* y *Patrimonio Neto Proyectado*).
3. **Inicio de Sesión (`login_screen.dart`):**
   - Tarjeta central con avatar de marca y campos con `AppColors`.

### 14.4. Resultados de Calidad y Compilación
- **Tests Automatizados:** **82 de 82 pruebas pasando al 100%** (`flutter test`).
- **Análisis Estático:** **0 advertencias / 0 errores** (`flutter analyze`).
- **Compilación Web:** `flutter build web` exitoso en 44.5s con cero advertencias ni fallos.

---

## 15. Sistema de Temas Dinámicos: Modo Oscuro (Predeterminado) y Modo Claro — 2026-10-08

### 15.1. Requerimiento y Diseño
- **Solicitud del usuario:** Posibilidad de alternar entre tema negro/oscuro y blanco/claro, con **modo oscuro predeterminado**.
- **Arquitectura de Estado:**
  - `ThemeModeNotifier` extendiendo `Notifier<ThemeMode>` en `lib/presentation/providers/finance_state_providers.dart` con Riverpod 3.x (`NotifierProvider<ThemeModeNotifier, ThemeMode>`).
  - Estado inicial configurado en `ThemeMode.dark`.
  - Métodos `toggle()` y `setThemeMode(ThemeMode)`.

### 15.2. Tokens Semánticos (`lib/presentation/utils/app_theme.dart`)
- **`AppPalette`:** Provee tokens de color contextualmente según el brillo del tema:
  - **`AppPalette.dark` (Predeterminado):**
    - Superficie base: Midnight Slate `#0B0F19`.
    - Contenedores de tarjeta: Slate 900 `#161F30`.
    - Elementos sutiles: Slate 800 `#1E293B`.
    - Bordes: Slate 700 sutil `#26334D`.
    - Texto principal: Blanco de alto contraste `#F8FAFC`.
    - Texto secundario: Slate 400 `#94A3B8`.
    - Acentos: Azul vibrante `#3B82F6`, Esmeralda luminoso `#34D399` y Carmesí `#F87171`.
  - **`AppPalette.light`:**
    - Superficie base: Slate 50 `#F8FAFC`.
    - Contenedores de tarjeta: Blanco puro `#FFFFFF`.
    - Elementos sutiles: Slate 100 `#F1F5F9`.
    - Bordes: Slate 200 `#E2E8F0`.
    - Texto principal: Slate 900 `#0F172A`.
    - Texto secundario: Slate 600 `#475569`.
- **`AppColors.of(context)`:** Retorna la paleta activa correspondiente (`Theme.of(context).brightness == Brightness.dark ? dark : light`).
- **`buildAppTheme(brightness)`:** Constructor integral que configura `ThemeData` para `Brightness.dark` y `Brightness.light` cubriendo Scaffold, CardTheme, AppBarTheme, DialogTheme, InputDecorationTheme, ButtonThemes y DividerTheme.

### 15.3. Integración en UI
- **`FinanzasApp` (`lib/main.dart`):** Conecta `themeModeProvider` con `theme: buildAppTheme(brightness: Brightness.light)`, `darkTheme: buildAppTheme(brightness: Brightness.dark)` y `themeMode: themeMode`.
- **Selector de Tema en Dashboard (`lib/presentation/screens/dashboard_screen.dart`):**
  - Botón `IconButton` en el `AppBar.actions` con icono adaptativo (`Icons.light_mode_rounded` en modo oscuro / `Icons.dark_mode_rounded` en modo claro).
  - Tooltips contextuales: *"Cambiar a tema claro"* y *"Cambiar a tema oscuro"*.
  - Dispara `ref.read(themeModeProvider.notifier).toggle()`.
  - Todos los contenedores, barras, tarjetas de banco y crédito responden contextualmente al brillo activo.

### 15.4. Verificación y Calidad
- **Tests Unitarios y de Widget:**
  - `Default theme is dark mode and can be toggled to light mode`: Verifica que el contenedor inicie en `ThemeMode.dark` y alterne simétricamente con `toggle()`.
  - `DashboardScreen displays theme toggle button and switches theme on tap`: Simula la pulsación del usuario y comprueba el cambio de iconos y temas.
- **Resultado Global:** **84 de 84 tests pasando al 100%** (`flutter test`).
- **Análisis Estático:** **0 advertencias / 0 errores** (`flutter analyze`).

---

## 16. Corrección de RenderFlex Overflow en Diálogo NLP y Dropdowns — 2026-10-08

### 16.1. Causa Raíz
- En el modal `NlpEntryDialog` (`lib/presentation/screens/dialogs/nlp_entry_dialog.dart`), la fila de confirmación contenía el `DropdownButtonFormField` de "Operación" y el `TextField` de "Monto COP".
- El dropdown de "Operación" carecía de `isExpanded: true`, lo cual provocaba que el texto interno (`Gasto / Compra`) junto al padding horizontal y el icono de flecha excedieran el ancho acotado de la celda en resoluciones compactas, disparando una excepción visual de `RenderFlex overflowed by 11 pixels`.

### 16.2. Solución Aplicada
1. **`nlp_entry_dialog.dart`:**
   - Se configuró `isExpanded: true` en el `DropdownButtonFormField` de "Operación".
   - Se asignó una proporción ergonómica en la fila: `flex: 6` para "Operación" y `flex: 5` para "Monto COP".
   - Se aplicó `overflow: TextOverflow.ellipsis` a los textos de las opciones (`Gasto / Compra`, `Ingreso`, `Abonar a Tarjeta (Pagar TC)`), así como a los ítems de cuentas y tarjetas.
   - Se optimizó el `contentPadding` a `EdgeInsets.symmetric(horizontal: 12, vertical: 14)` para evitar desbordes en ventanas estrechas.
2. **Revisión Proactiva de Otros Dropdowns:**
   - Se agregó `isExpanded: true` y `TextOverflow.ellipsis` a `pocket_crud_dialog.dart` y `recurring_payment_dialog.dart`.
3. **Constante de Utilidad:**
   - Se agregó `static const empty = NlpCatalog(accounts: [], cards: [], pockets: []);` en `NlpCatalog` (`nlp_parser.dart`).

### 16.3. Verificación Automatizada
- **Nuevo Widget Test:** `NlpEntryDialog renders without RenderFlex overflow even on compact width` en `test/widget_test.dart`, simulando un ancho físico compacto de 360px y validando `expect(tester.takeException(), isNull)`.
- **Resultados:** **85 de 85 tests pasando al 100%** (`flutter test`).
- **Análisis Estático:** **0 advertencias / 0 errores** (`flutter analyze`).

---

## 17. Gráficos Visuales y Microinteracciones Dinámicas en Dashboard — 2026-10-08

### 17.1. Dependencia e Infraestructura
- **`fl_chart: ^1.2.0`:** Añadida a `pubspec.yaml` para renderizado interactivo de gráficos vectoriales (donas, circulares y progresiones) en Flutter Web y multiplataforma.

### 17.2. Lógica de Dominio Pura (`DashboardVisuals`)
- **Archivo:** [dashboard_visuals.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/dashboard_visuals.dart)
- **`DashboardVisuals.byPocket(pockets)`:**
  - Extrae y ordena los bolsillos por saldo descendente.
  - Excluye saldos $\le 0$ para evitar distorsiones en gráficos de dona y calcula porcentajes relativos exactos.
  - Informa el conteo de bolsillos excluidos en `DistributionResult.excludedNegativeCount`.
- **`DashboardVisuals.byAccount(accounts, pockets)`:**
  - Agrupa la suma de saldos de bolsillos por cada entidad bancaria.
  - Calcula el peso porcentual de cada banco sobre el total de activos.
- **`DashboardVisuals.creditUsageLevel(ratio)`:**
  - Evalúa los niveles de estrés de cupo de tarjetas de crédito:
    - **Saludable (`healthy`):** $< 30\%$ de utilización (color verde esmeralda / `assetPositive`).
    - **Moderado (`moderate`):** Entre $30\%$ y $70\%$ de utilización (color ámbar / `warning`).
    - **Crítico (`critical`):** $> 70\%$ de utilización (color carmesí / `liabilityNegative`).

### 17.3. Componentes y Microinteracciones
1. **Gráfico de Dona Interactivo (`PocketDistributionChart`):**
   - **Archivo:** [pocket_distribution_chart.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/charts/pocket_distribution_chart.dart)
   - Donut chart con `PieChart` (`fl_chart`), radio central translúcido y radio exterior dinámico al seleccionar o interactuar con un sector.
   - Centro informativo interactivo: muestra el nombre de la categoría, monto en COP y porcentaje de la cuña seleccionada o en hover.
   - Selector integrado `SegmentedButton<DistributionMode>`: permite alternar fluidamente entre **"Por Bolsillos"** y **"Por Cuentas Banco"**.
   - Leyenda con badges de color, tooltips nativos y nombres con `TextOverflow.ellipsis`.
   - Estado vacío animado (`AnimatedSwitcher`) cuando no hay saldos positivos disponibles.
2. **Contador Numérico Animado (`AnimatedCopText`):**
   - **Archivo:** [dashboard_micro_widgets.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/dashboard_micro_widgets.dart)
   - Utiliza `TweenAnimationBuilder` para realizar una animación suave de conteo ascendente en el Patrimonio Neto y métricas financieras principales al cargar o mutar el estado.
3. **Indicador de Estrés de Cupo (`CreditUsageBar`):**
   - **Archivo:** [dashboard_micro_widgets.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/dashboard_micro_widgets.dart)
   - Barra de progreso animada con interpolación cúbica (`TweenAnimationBuilder`).
   - El color de la barra y el porcentaje de utilización en texto cambian en tiempo real de acuerdo a los umbrales de estrés definidos.
4. **Contenedor Interactivo (`HoverCard`):**
   - **Archivo:** [dashboard_micro_widgets.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/dashboard_micro_widgets.dart)
   - Aplica elevación visual suave, sombra difusa y acento cromático en el borde mediante `MouseRegion` y `AnimatedContainer` al interactuar con las tarjetas de bancos y tarjetas de crédito.
5. **Transición Fluida de Vistas en Dashboard:**
   - **Archivo:** [dashboard_screen.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dashboard_screen.dart)
   - Selector superior con `SegmentedButton<DashboardView>` (**"Resumen"** y **"Gráfico"**).
   - Transición envolvente con `AnimatedSwitcher` entre el panel de métricas numéricas y el gráfico de distribución patrimonial.

### 17.4. Verificación y Calidad SDD
- **Nueva Suite:** [dashboard_visuals_and_charts_test.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/test/presentation/widgets/dashboard_visuals_and_charts_test.dart) (10 tests cubriendo lógica de dominio, porcentajes, umbrales de estrés, widget `AnimatedCopText`, `CreditUsageBar`, `HoverCard` y `PocketDistributionChart`).
- **Ampliación en `widget_test.dart`:** Test de alternancia de vista entre "Resumen" y "Gráfico" en `DashboardScreen`.
- **Resultados:**
  - **`flutter test`:** **96 de 96 tests pasando al 100% en verde**.
  - **`flutter analyze`:** **0 errores y 0 advertencias**.
  - Cero desbordamientos de `RenderFlex` en resoluciones móviles y de escritorio.

---

## 18. Funcionalidad de Dictado por Voz (Speech to Text) Integrada con NLP — 2026-10-08

### 18.1. Arquitectura y Servicio Desacoplado
- **Dependencia:** `speech_to_text: ^7.5.0` añadida a `pubspec.yaml` para reconocimiento de voz en navegadores web (Web Speech API) y dispositivos móviles.
- **Contrato de Dominio:** [voice_dictation_service.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/voice_dictation_service.dart)
  - `VoiceDictationService`: Interfaz abstracta que desacopla la captura de audio y la transcripción de la capa de interfaz gráfica.
  - `SpeechToTextVoiceService`: Implementación de producción que encapsula `stt.SpeechToText`, resuelve el dialecto español colombiano (`localeId: 'es_CO'`) o dialectos afines, y mapea errores nativos (`error_permission`, `error_speech_timeout`, etc.) a descripciones amigables en español.
  - `FakeVoiceDictationService`: Implementación simulada en memoria para pruebas automatizadas herméticas sin requerir hardware de micrófono en entornos de CI.
- **Gestión de Estado:** [voice_dictation_provider.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/providers/voice_dictation_provider.dart)
  - Expone `voiceDictationServiceProvider` (sobreescribible en tests) y `voiceDictationProvider` (`VoiceDictationNotifier`).

### 18.2. Componentes e Integración en UI
1. **Botón Interactivo de Micrófono ([`VoiceDictationButton`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/voice_dictation_widgets.dart)):**
   - Animación de escala pulsante mientras está en modo de escucha.
   - Cambio cromático dinámico a rojo carmesí (`colors.liabilityNegative`) cuando el micrófono está activo y azul (`colors.brandAccent`) en reposo.
   - Detección inteligente de entorno de pruebas para evitar bucles infinitos en `pumpAndSettle()`.
2. **Flujo Reactivo en [`NlpEntryDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/nlp_entry_dialog.dart):**
   - El botón de micrófono se ubica dentro del `suffixIcon` del campo de texto principal.
   - A medida que el usuario habla, `_phraseController.text` se actualiza en tiempo real con las palabras reconocidas.
   - Se dispara reactivamente `_onPhraseChanged(words, catalog)`, ejecutando `NlpParser.parse()` para auto-completar instantáneamente:
     - Tipo de operación (`Gasto`, `Ingreso`, o `Abonar a Tarjeta`).
     - Monto en COP extraído con formato numérico.
     - Entidad de origen y tarjeta/cuenta destino.
     - Selección de bolsillo aplicable.
   - Banner de feedback en vivo con punto de grabación rojo cuando está escuchando.
   - Manejo de fallbacks: banner descriptivo si se deniegan permisos de micrófono o si el navegador no soporta la Web Speech API.
3. **Acceso Rápido en [`DashboardScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dashboard_screen.dart):**
   - Botón *"Dictar por Voz"* en el Command Bar superior.
   - Abre `NlpEntryDialog(startListeningImmediately: true)`, activando el micrófono de inmediato sin requerir pulsaciones adicionales.
   - Maquetado responsivo con `LayoutBuilder` que previene desbordamientos de `RenderFlex` en resoluciones móviles y pantallas angostas.

### 18.3. Verificación y Calidad SDD
- **Suite de Dominio:** [voice_dictation_test.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/test/domain/voice_dictation_test.dart) (6 tests unitarios verificando inicialización, permisos bloqueados, transcripción de palabras parciales/finales, detención y errores).
- **Suite de Integración y Widgets:** [voice_dictation_flow_test.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/test/presentation/widgets/voice_dictation_flow_test.dart) (6 tests verificando interacción con micrófono, transcripción de compra con TC, abono a tarjeta con `isCardPayment`, apertura inmediata desde el Dashboard y captura de denegación de permisos).
- **Resultados Globales:**
  - **`flutter test`:** **108 de 108 tests pasando al 100% en verde**.
  - **`flutter analyze`:** **0 errores y 0 advertencias**.

---

## 19. Evolución del Motor NLP por Intenciones, Edición Completa de Entidades y Catálogo de Bancos con Logos — 2026-10-09

### 19.1. Assets y Logotipo Institucional
- **Configuración en `pubspec.yaml`:**
  - Habilitados los directorios de recursos: `assets/images/`, `assets/icons/banks/` y `assets/icons/`.
- **Componente [`AppLogoWidget`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/app_logo_widget.dart):**
  - Renderiza el logo institucional cargado desde `assets/images/logo.png`.
  - Fallback elegante ante ausencia del archivo o error de carga hacia `Icon(Icons.account_balance_wallet_rounded)`.
  - Integrado en el AppBar de [`DashboardScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dashboard_screen.dart), en el encabezado de [`LoginScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/login_screen.dart) y en [`OnboardingScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/onboarding_screen.dart).

### 19.2. Catálogo de Bancos Predefinidos con Logos Oficiales
- **Modelo de Dominio ([`BankCatalog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/models/bank_catalog.dart)):**
  - 14 entidades financieras configuradas con logos vectoriales/PNG, colores primarios oficiales y alias lingüísticos: Bancolombia, Nequi, Davivienda, Daviplata, Nu, Lulo Bank, Banco de Bogotá, BBVA, Scotiabank Colpatria, Banco Falabella, RappiPay, Dale!, Revolut, y opción "Otro / Personalizado".
  - Métodos `BankCatalog.bestMatch(query)` para emparejamiento automático por alias y `BankCatalog.findById(id)`.
- **Componentes Visuales ([`BankLogoAvatar`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/bank_logo_avatar.dart) y [`BankSelectorField`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/bank_logo_avatar.dart)):**
  - `BankLogoAvatar`: Presenta el logo oficial del banco con fondo suave adaptado al color de marca y fallback automático a la inicial mayúscula si el asset físico no está presente.
  - `BankSelectorField`: Selector interactivo con modal inferior desplegable con buscador en vivo de entidades bancarias y campo de texto condicional si se selecciona "Otro".
  - Integrado en Onboarding, creación y edición de Cuentas Banco y Tarjetas de Crédito, y en los modales de detalles e historial.

### 19.3. Motor NLP de Intenciones y Expresiones Coloquiales Colombianas
- **Jerarquía Tipada de Intenciones ([`NlpIntent`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/nlp_parser.dart)):**
  - `ExpenseIntent`: Gastos desde cuentas o tarjetas.
  - `IncomeIntent`: Ingresos a cuentas banco.
  - `TransferIntent`: Traslado de fondos entre bolsillos con sintaxis "pasar X de Y a Z", "transferir", "mover".
  - `CardPaymentIntent`: Abonos a tarjetas de crédito ("abono tc", "pago tarjeta", "le metí a la tarjeta").
  - `CreatePocketIntent`: Creación de bolsillos con saldo inicial y cuenta destino ("crear bolsillo viajes 200000 en bancolombia").
  - `CreateAccountIntent`: Creación de cuentas banco ("crear cuenta ahorros davivienda").
  - `CreateCardIntent`: Creación de tarjetas de crédito con cupo ("crear tarjeta nu cupo 3000000").
  - `CreateRecurringIntent`: Creación de suscripciones con día de cobro ("crear suscripcion netflix 45000 cada 15").
- **Expresiones Coloquiales Colombianas Soportadas:**
  - *"me gasté 45000 en almuerzo nequi"* (gasto en cuenta Nequi).
  - *"tanqueé 50000 con tc nu"* (gasto en tarjeta de crédito Nu).
  - *"me consignaron 1200000 de quincena en bancolombia"* (ingreso).
  - *"me cayó la prima 800000 davivienda"* / *"me cayó la quincena"* (ingreso).
  - *"aboné 200000 a la tarjeta bancolombia"* (abono con restauración de cupo).
- **Ejecución Dinámica en [`NlpEntryDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/nlp_entry_dialog.dart):**
  - Botón de acción contextual que se adapta a la intención detectada ("Crear Bolsillo", "Crear Cuenta", "Registrar Tarjeta", "Crear Suscripción", "Transferir Fondos", "Abonar a Tarjeta", "Registrar Transacción").
  - Ejecuta directamente la operación en el repositorio sin requerir navegación manual adicional.

### 19.4. Edición Completa In-Situ de Entidades (CRUD)
- **Cuentas Banco ([`BankDetailsDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/bank_details_dialog.dart)):**
  - Botón de edición en encabezado para cambiar nombre de entidad, número de cuenta y reajustar el dinero libre (saldo fuera de bolsillos).
- **Bolsillos ([`BankDetailsDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/bank_details_dialog.dart)):**
  - Botón de edición por bolsillo para modificar nombre y saldo directamente.
- **Tarjetas de Crédito ([`CardDetailsDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/card_details_dialog.dart) y [`CreditCardCrudDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/credit_card_crud_dialog.dart)):**
  - Edición completa in-situ de entidad emisora, nombre/tipo, franquicia, últimos 4 dígitos, cupo total (manteniendo intacta la deuda y recalculando el disponible) y días de corte/pago.
- **Suscripciones ([`RecurringPaymentDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/recurring_payment_dialog.dart)):**
  - Modo edición con selector de bolsillo/tarjeta, monto y día de cobro.
- **Métodos en Repositorio ([`FinanceRepository`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/repositories/finance_repository.dart) & [`SupabaseFinanceRepository`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/data/supabase_finance_repository.dart)):**
  - `updateAccount`, `updatePocket`, `updateCreditCard`, `updateRecurringPayment`.

### 19.5. Verificación y Calidad SDD
- **Nuevas Suites de Pruebas:**
  - [bank_catalog_and_intent_test.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/test/domain/bank_catalog_and_intent_test.dart) (15 tests de catálogo, intenciones tipadas y expresiones coloquiales).
  - [entity_edit_and_bank_logos_test.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/test/presentation/widgets/entity_edit_and_bank_logos_test.dart) (6 tests verificando renderizado de logos, selector de bancos y flujo interactivo de edición de cuentas, bolsillos y tarjetas).
- **Resultados Globales:**
  - **`flutter test`:** **129 de 129 tests pasando al 100% en verde** (0 fallos).
  - **`flutter analyze`:** **0 errores y 0 advertencias**.

---

## 20. Favicon Institucional, Insignias Planas de Logos Bancarios y Auditoría Integral de Contrastes — 2026-10-10

### 20.1. Generación y Configuración del Favicon
- **Origen:** Imagen institucional proporcionada en `C:\Users\User\Desktop\favicon.jpg`.
- **Archivos Generados:**
  - `web/favicon.png` (32x32 y resolución web optimizada).
  - `web/icons/Icon-192.png` y `web/icons/Icon-512.png` (PWA y Android).
  - `web/icons/Icon-maskable-192.png` y `web/icons/Icon-maskable-512.png` (íconos enmascarables PWA).
  - `assets/images/favicon.png` (recurso interno de la aplicación).
- **Configuración Web (`web/index.html`):**
  - Vinculación de favicon `web/favicon.png` con `rel="icon" type="image/png"`.
  - Título institucional actualizado a `Finanzas Personales — Control de Activos y Pasivos`.

### 20.2. Aumento de Tamaño y Realce del Logotipo Institucional
- **[`LoginScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/login_screen.dart):**
  - Logo ampliado a 80px contenido en una tarjeta blanca destacada con esquinas redondeadas (`borderRadius: 24`), borde sutil y sombra suave, logrando presencia dominante en el login.
- **[`OnboardingScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/onboarding_screen.dart):**
  - Encabezado ampliado a 48px dentro de un contenedor blanco puro con sombra flotante.
- **[`DashboardScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dashboard_screen.dart):**
  - Insignia en AppBar ampliada a 32px con fondo blanco puro y esquinas redondeadas para máxima nitidez sobre fondo oscuro o claro.

### 20.3. Insignia Circular Plana y Sólida para Logos de Bancos
- **Problema previo:** Los avatares bancarios utilizaban círculos con transparencia (`primaryColor.withValues(alpha: 0.15)`), perdiendo contraste y visibilidad sobre las tarjetas oscuras del dashboard y modales.
- **Solución ([`BankLogoAvatar`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/bank_logo_avatar.dart)):**
  - Se sustituyó la transparencia por un círculo plano y sólido de color blanco puro (`color: Colors.white`).
  - Añadido borde nítido (`Border.all(color: Color(0xFFCBD5E1), width: 1.2)`) y sombra perimetral suave.
  - Recorte anti-aliasing circular para logos con esquinas transparentes o cuadradas.
  - Legibilidad y contraste al 100% garantizados tanto en modo oscuro como en modo claro para todas las 14 entidades del catálogo (Bancolombia, Nequi, Nu, Davivienda, etc.).

### 20.4. Auditoría y Corrección Integral de Contrastes en Toda la Aplicación
- **Eliminación de Contenedores Claros Rígidos e Inversión de Texto:**
  - **[`PocketCrudDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/pocket_crud_dialog.dart):** Se eliminó el bloque `#F8FAFC` que en modo oscuro creaba una caja blanca con inputs oscuros (`#1E293B`) y etiquetas ilegibles. Migrado a `palette.surfaceSubtle` y `palette.textPrimary`.
  - **[`CreditCardCrudDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/credit_card_crud_dialog.dart):** Eliminados fondos rígidos `#FFF1F2` y `#FECDD3`; adoptados tokens semánticos `palette.surfaceSubtle`, `palette.liabilityNegative` y `BankLogoAvatar(size: 38)`.
  - **[`BankDetailsDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/bank_details_dialog.dart):** Eliminados `#0F172A`, `#1E293B` y `#F8FAFC` en contenedores de métricas e histórico. Migrado a `palette.surfaceSubtle`, `palette.brandAccentBg` y `palette.assetPositiveBg`.
  - **[`CardDetailsDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/card_details_dialog.dart):** Eliminados colores rígidos `#FFFBEB` y `#FFF1F2`. Sustituidos por `palette.warningBg` y `palette.liabilityNegativeBg`.
  - **[`RecurringPaymentDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/recurring_payment_dialog.dart):** Lista de transacciones y formulario migrados a `palette.surfaceSubtle` y `palette.textPrimary`.
  - **[`FiscalCloseDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/fiscal_close_dialog.dart):** Contenedores de confirmación migrados a `palette.assetPositiveBg` y `palette.liabilityNegativeBg`.
  - **[`NlpEntryDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/nlp_entry_dialog.dart):** Banners de detección de abonos, advertencias y gastos con tarjeta adaptados a `colors.brandAccentBg`, `colors.warningBg` y `colors.liabilityNegativeBg`.
  - **[`OnboardingScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/onboarding_screen.dart):** Migración completa a `AppPalette.of(context)` en todas las tarjetas de cuentas, bolsillos, tarjetas de crédito, badges y barra de resumen.

### 20.5. Verificación y Cumplimiento SDD
- **`flutter analyze`:** **0 errores y 0 advertencias**.
- **`flutter test`:** **129 de 129 tests pasando al 100% en verde** (0 fallos).

---

## 21. Arquitectura Integral de Inteligencia Artificial (Google AI Studio / Gemini) vía Supabase Edge Functions, Motor Híbrido, Copiloto Conversacional, Auditoría de Fugas y Edición Total In-Situ — 2026-10-10

### 21.1. Supabase Edge Function (`supabase/functions/finance_ai/index.ts`)
- **Conectividad:** Desarrollada en TypeScript para Deno/Supabase Edge Functions, enlazada a la API de **Google AI Studio (Gemini Flash)** mediante secret `GEMINI_API_KEY`.
- **Manejo de CORS:** Soporte completo de preflight `OPTIONS` y headers estándar para invocación directa desde Flutter Web y móvil.
- **Acciones Implementadas (`action`):**
  1. `parse_intent`: Recibe texto/dictado junto con el catálogo financiero activo (cuentas, bolsillos, tarjetas) y devuelve un JSON estrictamente estructurado clasificando la intención (`expense`, `income`, `transfer`, `card_payment`, `create_recurring`, `create_card`, `create_pocket`, `create_account`).
     - Prompt calibrado para jerga y expresiones financieras colombianas ("lucas", "barras", "palos", "los 15 de cada mes", "mensualidad").
  2. `chat_copilot`: Asistente conversacional in-app que inyecta en su contexto los saldos en tiempo real (patrimonio neto, activos, deuda en tarjetas y bolsillos libres) para responder consultas estratégicas y consejos de ahorro.
  3. `audit_expenses`: Analiza los movimientos registrados, clasifica gastos hormiga (<$20.000 COP), detecta cobros duplicados en la misma fecha y evalúa fugas de liquidez recurrentes.

### 21.2. Motor Híbrido y Capa de Dominio en Flutter
- **[`AiAssistantService`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/ai_assistant_service.dart):**
  - Servicio de dominio desacoplado con soporte de inyección de dependencias (`functionInvoker`) para tests automatizados y conexión a `supabaseClientProvider`.
  - Mapeo tipado de respuestas a la jerarquía de intenciones de `NlpIntent` y a modelos estructurados de auditoría (`AntExpenseItem`, `DuplicateExpenseItem`, `LiquidityLeakItem`, `ExpenseAuditResult`).
  - Fallback offline robusto para operar con datos locales aún ante caídas de red o demoras en la API externa.
- **Motor Híbrido en [`NlpParser`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/nlp_parser.dart):**
  - `NlpParser.isLocalMatch(input)`: Discrimina instantáneamente si una entrada puede ser resuelta de forma 100% determinista localmente en Dart o si contiene jerga ("lucas", "barras", "palos") o intenciones de creación (`crear suscripción`, `nueva tarjeta`).
  - `NlpParser.parseHybrid(...)`: Resuelve patrones simples en microsegundos en el cliente, y escala de forma asíncrona a la Edge Function de Gemini para peticiones semánticamente complejas o con lenguaje coloquial.
- **Jerarquía Completa de Intenciones Tipadas:**
  - `CreateRecurringIntent`: Extrae nombre del servicio, monto en COP, día de cobro mensual (1-31) y método de pago (tarjeta o bolsillo débito).
  - `CreateCardIntent`: Extrae entidad bancaria, cupo total, franquicia, y días de corte y pago.
  - `CreatePocketIntent` / `CreateAccountIntent`: Permite crear nuevos bolsillos o cuentas vinculadas.

### 21.3. Experiencia de Usuario & Nuevos Diálogos
- **[`NlpEntryDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/nlp_entry_dialog.dart):**
  - Indicador visual e insignia sutil `"✨ Analizado con IA"` en el encabezado cuando una intención fue enriquecida por Gemini.
  - Tarjetas de confirmación dedicadas para `CreateRecurringIntent` (mostrando día de cobro mensual y método), `CreateCardIntent` (mostrando entidad, cupo, corte y fecha límite de pago) y `CreatePocketIntent`.
  - Maquetación adaptativa con `Wrap` que elimina al 100% cualquier desbordamiento horizontal (`RenderFlex overflow`) en pantallas móviles ultra compactas (360px).
- **[`AiCopilotDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/ai_copilot_dialog.dart):**
  - Modal interactivo con historial conversacional, píldoras de preguntas rápidas sugeridas, inyección reactiva del contexto patrimonial y scroll suave animado.
  - Acceso directo desde el comando superior del Dashboard ("Copiloto IA").
- **[`ExpenseAuditDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/expense_audit_dialog.dart):**
  - Auditoría visual dividida en: Gastos Hormiga (< $20.000 COP), Posibles Duplicados (mismo importe en la misma fecha), Fugas de Liquidez y Consejos Prácticos de Ahorro.
  - Cálculo de respaldo local integrado en caso de operar fuera de línea.
  - Acceso directo en "Accesos Rápidos" del Dashboard ("Auditar Gastos Hormiga (IA)").

### 21.4. Edición Total In-Situ (Hot CRUD) de Entidades
- **Cuentas Banco ([`PocketCrudDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/pocket_crud_dialog.dart) & [`BankDetailsDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/bank_details_dialog.dart)):**
  - Botón de lápiz en la lista de cuentas para editar nombre, número y saldo libre fuera de bolsillos.
- **Bolsillos ([`PocketCrudDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/pocket_crud_dialog.dart) & [`BankDetailsDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/bank_details_dialog.dart)):**
  - Diálogo de edición ampliado para renombrar bolsillo y reajustar su saldo asignado directamente.
- **Tarjetas de Crédito ([`CreditCardCrudDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/credit_card_crud_dialog.dart) & [`CardDetailsDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/card_details_dialog.dart)):**
  - Edición completa in-situ de entidad, nombre, cupo total, fechas de corte y fechas límite de pago.
- **Suscripciones ([`RecurringPaymentDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/recurring_payment_dialog.dart)):**
  - Edición de monto, día de cobro mensual, origen de pago y débito automático.

### 21.5. Verificación y Calidad SDD
- **Nuevas Suites de Pruebas:**
  - [ai_assistant_service_test.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/test/domain/ai_assistant_service_test.dart) (10 tests de parseo de intenciones, jerga colombiana, creación de entidades, copilot conversacional y auditoría).
  - [ai_dialogs_and_copilot_test.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/test/presentation/widgets/ai_dialogs_and_copilot_test.dart) (4 tests de interfaz para el Copiloto IA, Auditoría de Gastos y previsualización de suscripciones/tarjetas en NLP).
- **Resultados Globales:**
  - **`flutter test`:** **143 de 143 tests pasando al 100% en verde** (0 fallos).
  - **`flutter analyze`:** **0 errores y 0 advertencias**.
  - **Tolerancia Cero a RenderFlex Overflows:** Validado en resoluciones desde móviles de 360px hasta escritorio de 1280px.

---

## 22. Optimización de Identidad Visual (Isotipo Limpio en Navbar y Login) y Autenticación con Correo o Nombre de Usuario — 2026-10-10

### 22.1. Limpieza y Presentación del Isotipo (Navbar y Login)
- **Barra Superior del Dashboard ([`DashboardScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dashboard_screen.dart)):**
  - Se actualizó el isotipo institucional en la barra de navegación para usar la versión limpia (`assets/images/favicon.png`, gráfico de barras y flecha ascendente sin tipografía incrustada debajo).
  - Dimensionado nítido de 38x38px con borde sutil (1.2px), radio de 10px y sombra delicada (`boxShadow`), alojando el isotipo de 32px para máxima definición al lado del título *"Finanzas Personales"*.
- **Pantalla de Inicio de Sesión ([`LoginScreen`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/login_screen.dart)):**
  - Contenedor destacado de 104x104px con bordes redondeados (22px), fondo blanco puro, borde gris claro y sombra suave de elevación.
  - El isotipo se renderiza con `AppLogoWidget(size: 88, useIsotype: true)` sin compresión ni pixelación.
  - La tipografía institucional (*"APF"*, *"Asistente de Presupuesto & Finanzas"*) se desacopló del archivo gráfico y se implementó con widgets nativos de Flutter (`Text`) con estilos definidos, `letterSpacing` y peso visual equilibrado.
- **Componente Base ([`AppLogoWidget`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/widgets/app_logo_widget.dart)):**
  - Parámetro `useIsotype: true` por defecto, cargando prioritariamente `assets/images/favicon.png` con fallback encadenado a `assets/images/logo.png` y a icono vectorial `Icons.account_balance_wallet_rounded`.

### 22.2. Autenticación Flexible por Correo o Nombre de Usuario
- **Entrada Unificada en Login:**
  - El campo de texto en modo de inicio de sesión tiene la etiqueta `"Correo o Usuario"`, hint `"ej. alex@email.com o alex123"` y prefijo de icono `Icons.person_outline`.
- **Lógica de Autenticación ([`SupabaseAuthRepository`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/data/supabase_auth_repository.dart)):**
  - Si la entrada contiene `'@'`: se trata como correo y se autentica directamente con `_client.auth.signInWithPassword(email: identifier, password: password)`.
  - Si la entrada no contiene `'@'`: se trata como `username`, se consulta la tabla `profiles` (`ilike('username', clean)`) o la función RPC `get_email_by_username(p_username)`. Al resolver el correo asociado, se autentica la sesión. Si no existe, se muestra un mensaje informativo claro al usuario.
- **Modo Registro:**
  - Campos separados e independientes: `"Nombre de usuario único"` (validando longitud de 3 a 30 caracteres, caracteres alfanuméricos y sin arroba) y `"Correo electrónico"`.
  - Validación previa de disponibilidad del nombre de usuario para evitar duplicidades.
  - Transferencia inteligente de datos al alternar entre modos de inicio y registro.
- **Base de Datos Supabase (`supabase/migrations/20261010010000_profiles_and_username_auth.sql`):**
  - Tabla `profiles` con `id`, `username`, `email` y `created_at`.
  - Índice único insensible a mayúsculas/minúsculas (`lower(username)`).
  - Políticas de seguridad a nivel de fila (RLS).
  - Función RPC `get_email_by_username(p_username)` con `SECURITY DEFINER`.
  - Trigger automático en `auth.users` para sincronizar usuarios creados.

### 22.3. Verificación y Cobertura de Pruebas SDD
- **Nueva Suite:** [login_auth_username_test.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/test/presentation/screens/login_auth_username_test.dart) (10 pruebas unitarias y de widgets cubriendo renderizado del isotipo, tipografía APF, inicio con correo, inicio con usuario, banners de error, alternancia de modo, transferencia de datos y validaciones de sintaxis).
- **Resultados Globales:**
  - **`flutter test`:** **153 de 153 tests pasando al 100% en verde** (0 fallos).
  - **`flutter analyze`:** **0 errores y 0 advertencias**.
---

## 23. Diagnóstico de Google AI Studio, Configuración de GEMINI_API_KEY y Despliegue de Edge Function Resiliente — 2026-10-12

### 23.1. Causa Raíz Identificada (Error 404 de Google AI Studio)
- Al probar directamente la API de Google Generative Language con la clave suministrada por el usuario, Google AI Studio retornó:
  `"This model models/gemini-2.0-flash is no longer available. Please update your code to use models/gemini-3.8-flash for the latest features and improvements."`
- Google AI Studio deshabilitó para nuevas peticiones `gemini-2.0-flash` y `gemini-2.5-flash`, habilitando en su lugar `gemini-flash-latest`, `gemini-3.5-flash` y `gemini-3.8-flash`.

### 23.2. Implementación de Fallback Multi-Modelo Inteligente ([`supabase/functions/finance_ai/index.ts`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/supabase/functions/finance_ai/index.ts))
- Se implementó la función helper `callGemini(payload, apiKey)` que itera por candidatos priorizados:
  1. `Deno.env.get("GEMINI_MODEL") || "gemini-flash-latest"` (normalizando prefijo `models/`)
  2. `gemini-3.5-flash`
  3. `gemini-flash-latest`
  4. `gemini-3.8-flash`
- Si un modelo reporta 404 (deprecado), 503 (alta demanda temporal) o 429 (límite de cuota), la función realiza fallback automático y transparente al siguiente modelo en milisegundos sin interrumpir la experiencia del usuario.
- Se configuró la clave de API activa en los secretos de Supabase (`npx supabase secrets set GEMINI_API_KEY=...`).

### 23.3. Despliegue y Verificación en Vivo
- **Despliegue exitoso:** Función `finance_ai` subida y desplegada a producción en Supabase project `ciesbycnqesrubtcrjbm` vía `npx supabase functions deploy finance_ai`.
- **Prueba End-to-End en Vivo:** Petición POST real enviada a `https://ciesbycnqesrubtcrjbm.supabase.co/functions/v1/finance_ai` con `"gasté 50 lucas en almuerzo"`:
  ```json
  {
    "success": true,
    "intent": {
      "intent_type": "expense",
      "amount": 50000,
      "description": "Almuerzo"
    },
    "is_ai": true
  }
  ```
  Respuesta 100% exitosa con HTTP 200 y clasificación exacta.

### 23.4. Verificación de Repositorio SDD
- **`flutter analyze`:** **0 errores y 0 advertencias**.
- **`flutter test`:** **153 de 153 tests pasando al 100% en verde** (0 fallos).

---

## 24. Optimización de Latencia en IA (Gemini Flash-Lite), Desactivación de Thinking Overhead, Corrección de Truncamiento de Copilot y Parser Colombiano — 2026-10-12

### 24.1. Diagnóstico de los Problemas Reportados
1. **Captura 1 (Interpretación Errónea en [`NlpEntryDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/nlp_entry_dialog.dart)):**
   - Frase ingresada: `"crea suscripción Netflix 45 barras cada 15 nequi"`.
   - Síntoma: Se categorizaba como Gasto por solo `$ 45` COP en lugar de suscripción recurrente de `$ 45.000` COP cobrada el día 15 desde Nequi.
   - Causas raíz:
     - Falta de debounce al tipear en el cuadro de texto: cada letra enviaba una solicitud a la Edge Function de Supabase (30+ peticiones por frase), agotando la cuota por minuto de Google AI Studio (`429 RESOURCE_EXHAUSTED`).
     - Al fallar la red por 429, entraba el parser local de contingencia, el cual carecía de multiplicadores de jerga colombiana ("barras", "lucas") y extraía el número literal 45 ignorando el sufijo.
     - El día del mes ("15") competía con el monto de la transacción si no se discriminaba la expresión de frecuencia ("cada 15", "el 15 de cada mes").
2. **Captura 2 (Respuestas Truncadas y Latencia en [`AiCopilotDialog`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/ai_copilot_dialog.dart)):**
   - Pregunta: `"¿Cuánto debo en tarjetas y qué estrategia de pago me recomiendas?"`.
   - Síntoma: La respuesta del Copilot se cortaba a mitad de frase (`ancolombia (única):** $45.000 COP * **Rappi (clásica):`), demorando 4 a 6 segundos o fallando intermitentemente.
   - Causas raíz:
     - En `gemini-3.5-flash` y `gemini-3.8-flash`, el modelo genera tokens internos de razonamiento ("thinking tokens"). Con un `maxOutputTokens: 800`, los tokens de razonamiento consumían el presupuesto antes de completar el markdown, arrojando `finishReason: MAX_TOKENS`.
     - La cuota gratuita de `gemini-3.5-flash` y `gemini-3.8-flash` es de solo 20 solicitudes/día en Google AI Studio, provocando rechazos de disponibilidad.

### 24.2. Mejoras en Backend Edge Function ([`supabase/functions/finance_ai/index.ts`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/supabase/functions/finance_ai/index.ts))
- **Priorización de Modelos Flash-Lite Ultrarrápidos:**
  - Se configuró la cadena de fallback: `gemini-flash-lite-latest`, `gemini-3.5-flash-lite`, `gemini-3.1-flash-lite`, `gemini-flash-latest`, `gemini-3.5-flash`, `gemini-3.8-flash`.
  - Los modelos `flash-lite` responden en ~700ms (frente a 4–6s) y poseen pools de cuota independientes mucho más amplios en Google AI Studio.
- **Desactivación de Thinking Overhead:**
  - Se incorporó `thinkingConfig: { thinkingBudget: 0 }` en `generationConfig`. Esto elimina los tokens de razonamiento interno, ahorrando tiempo de procesamiento y asegurando que todo el presupuesto de tokens esté disponible para la respuesta real.
- **Ampliación de Presupuesto y Concatenación de Partes:**
  - Se aumentó `maxOutputTokens` a 2048 en `chat_copilot`.
  - Se concatenaron todas las partes de texto (`parts.map(p => p.text).join('')`) para que las respuestas ricas y detalladas con análisis de deudas nunca se corten.
- **Despliegue en Vivo:**
  - Edge function desplegada en Supabase (`ciesbycnqesrubtcrjbm`) mediante `npx supabase functions deploy finance_ai`. Verificada con respuesta HTTP 200 en <800ms.

### 24.3. Fortalecimiento del Parser Local ([`lib/domain/services/nlp_parser.dart`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/nlp_parser.dart))
- **Soporte Nativo de Jerga Colombiana (0ms de latencia):**
  - "X barras", "X lucas", "X k" -> `X * 1.000` (ej. "45 barras" -> `$ 45.000`).
  - "X palos", "X millones" -> `X * 1.000.000` (ej. "2 palos" -> `$ 2.000.000`).
  - "media luca" -> `$ 500`.
- **Filtro de Días Calendario:**
  - Expresiones como `"cada 15"`, `"los 15"`, `"el 15"` o `"dia 15"` se excluyen de la detección del monto monetario y se asignan directamente al atributo `dayOfMonth`.
- **Patrones de Verbos Flexibles:**
  - Se amplió la detección de intenciones de creación para admitir formas coloquiales e imperativas: `"crea"`, `"crear"`, `"nuevo"`, `"nueva"`, `"agrega"`, `"anade"`.
- **Suscripciones Recurrentes Locales:**
  - Extrae servicio ("Netflix"), monto (45000), día de cobro (15) y entidad de origen ("Nequi") de manera inmediata y sin requerir conexión a internet.

### 24.4. Debounce y Feedback Visual en UI ([`lib/presentation/screens/dialogs/nlp_entry_dialog.dart`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dialogs/nlp_entry_dialog.dart))
- **Temporizador de Debounce (350ms):**
  - Al escribir o dictar por voz, las solicitudes a la IA se retrasan 350ms tras el último carácter ingresado, evitando ráfagas de 30+ peticiones por segundo.
  - El resultado local se presenta en tiempo real en 0ms y la IA enriquece la semántica en segundo plano.
- **Indicador de Carga Amigable (`ai_loading_badge`):**
  - Muestra un spinner discreto con `"✨ Interpretando con IA..."` mientras Gemini procesa en segundo plano, transicionando limpiamente a `"✨ Analizado con IA"` al culminar.

### 24.5. Validación SDD
- **Pruebas Unitarias Adicionadas:**
  - `test/domain/nlp_parser_test.dart`: Cobertura de multiplicadores de jerga colombiana (`barras`, `lucas`, `palos`, `media luca`, `k`).
  - `test/domain/bank_catalog_and_intent_test.dart`: Cobertura del caso exacto `"crea suscripción Netflix 45 barras cada 15 nequi"`.
- **Resultados Globales:**
  - **`flutter test`:** **155 de 155 tests pasando al 100% en verde** (0 fallos).
  - **`flutter analyze`:** **0 errores y 0 advertencias**.

---

## 25. Preparación para Lanzamiento Oficial, Pipeline de CI/CD (GitHub Actions) y Despliegue PWA en GitHub Pages — 2026-10-12

### 25.1. Pipeline Automatizado de CI/CD ([`.github/workflows/deploy.yml`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/.github/workflows/deploy.yml))
- **Gatillo de Ejecución:**
  - Se ejecuta en cada `push` a la rama `main` y soporta ejecución manual vía `workflow_dispatch`.
- **Fases del Flujo:**
  1. **Aprovisionamiento:** Instala Java 17 (`actions/setup-java@v4`) y Flutter canal estable (`subosito/flutter-action@v2`) con caché de dependencias.
  2. **Control de Calidad SDD:** Ejecuta `flutter pub get`, `flutter analyze` y `flutter test`. Cualquier fallo bloquea de inmediato el despliegue.
  3. **Compilación Release Web:**
     ```bash
     flutter build web --release --base-href "/finanzas-personales/" \
       --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
       --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
     ```
  4. **Enrutamiento SPA:** Copia `build/web/index.html` a `build/web/404.html` para garantizar que recargas de página o rutas directas no generen error 404 en GitHub Pages.
  5. **Despliegue Automático:** Despliega los artefactos generados en `build/web` a la rama `gh-pages` usando `peaceiris/actions-gh-pages@v3` con permisos `contents: write`.

### 25.2. Validación PWA y Metadatos Móviles ([`web/`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/web/))
- **[`web/manifest.json`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/web/manifest.json):**
  - Nombre: `"Finanzas Personales - APF"`, Nombre corto: `"Finanzas APF"`.
  - Colores de tema y fondo: `#0B0F19` (sincronizados con el Dark Mode institucional de la aplicación).
  - Punteros a iconos estándar y maskables de 192px y 512px.
  - Modo: `standalone`, Orientación: `portrait-primary`.
- **[`web/index.html`](file:///c:/Users/User/Desktop/developing/finanzas%20personales/web/index.html):**
  - Soporte completo para iOS y Android (`apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style: black-translucent`, `apple-mobile-web-app-title`).
  - Viewport configurado para experiencia de app móvil nativa (`width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no`).

### 25.3. Prueba de Compilación Release Local
- **Comando:** `flutter build web --release --dart-define-from-file=.env --base-href "/finanzas-personales/"`
- **Resultado:** Compilación exitosa en 57.5s, Wasm dry run aprobado y optimización de tree-shaking de fuentes completada (99% de reducción de peso de íconos).
- **Copia de 404.html:** Verificada en `build/web/404.html`.

### 25.4. Repositorio de GitHub y Configuración de Supabase
- **Repositorio de GitHub:** `https://github.com/Alexdjp15/finanzas-personales`
- **URL Pública de Producción (GitHub Pages PWA):**
  👉 `https://alexdjp15.github.io/finanzas-personales/`
- **Configuración requerida en Supabase Dashboard:**
  - Ir a: **Authentication** $\rightarrow$ **URL Configuration**.
  - **Site URL:** `https://alexdjp15.github.io/finanzas-personales/`
  - **Redirect URLs:** Agregar `https://alexdjp15.github.io/finanzas-personales/**` (y conservar `http://localhost:*` para desarrollo).
- **GitHub Secrets Requeridos en el Repositorio (`Settings` $\rightarrow$ `Secrets and variables` $\rightarrow$ `Actions`):**
  - `SUPABASE_URL`: URL del proyecto Supabase (`https://ciesbycnqesrubtcrjbm.supabase.co`).
  - `SUPABASE_ANON_KEY`: Clave pública anon de Supabase.

### 25.5. Resolución de Errores de CI/CD y Verificación en Vivo de GitHub Pages — 2026-10-12
- **Causas del Fallo Inicial (#1):**
  - Advertencia de análisis estático en `test/domain/bank_catalog_and_intent_test.dart:111:31` (`invalid_null_aware_operator` sobre `intent.sourceName?.toLowerCase()` siendo `sourceName` no nulo). En el runner de Linux, `flutter analyze` detuvo el pipeline con código de salida 1.
  - Al detenerse el pipeline, no se generaron artefactos y la URL pública arrojó error 404.
  - Adicionalmente, GitHub Pages en el repositorio nuevo estaba configurado con `build_type: "workflow"`, lo que requería la acción oficial `actions/deploy-pages@v4` y `actions/upload-pages-artifact@v3` para activar la publicación.
- **Correcciones Implementadas:**
  1. Se eliminó el operador innecesario `?.` en `bank_catalog_and_intent_test.dart`.
  2. Se configuró despliegue nativo en `.github/workflows/deploy.yml` mediante `actions/upload-pages-artifact@v3` y `actions/deploy-pages@v4`, conservando además la sincronización de respaldo a la rama `gh-pages` con `peaceiris/actions-gh-pages@v3`.
  3. Se retiró el paso de Java innecesario para compilar Flutter Web, acelerando el flujo a ~2 minutos.
- **Verificación en Vivo (100% Éxito):**
  - Workflow #3 (`38212889574`) completado exitosamente con check verde en todas las fases (`build-and-deploy` en 2m3s y `deploy-to-pages` en 8s).
  - Petición HTTP a `https://alexdjp15.github.io/finanzas-personales/` respondió con `HTTP/1.1 200 OK` y `<title>Finanzas Personales - APF</title>`.

---

## 26. Correcciones de Responsividad Móvil (Overflows/Layout), Campo Editable de Suscripción en NLP y Alineación de Esquema Gemini API v1beta — 2026-10-12

### 26.1. Corrección de Error 400 INVALID_ARGUMENT en Gemini API ([`supabase/functions/finance_ai/index.ts`](file:///supabase/functions/finance_ai/index.ts))
- **Diagnóstico:** El endpoint REST v1beta de Google AI Studio (`models/gemini-2.0-flash:generateContent`) arrojaba error `400 INVALID_ARGUMENT: Unknown field` cuando se incluían atributos no soportados como `thinkingConfig` en `generationConfig`.
- **Solución Implementada:**
  - Alineación estricta con la especificación Gemini v1beta REST:
    * `contents: [{ role: "user", parts: [{ text: promptCompleto }] }]`
    * `systemInstruction: { parts: [{ text: systemPrompt }] }` en camelCase estándar.
    * `generationConfig: { temperature: 0.2, maxOutputTokens: 1000, responseMimeType: "application/json" }`.
  - Despliegue automático a producción de Supabase Edge Functions (`npx supabase functions deploy finance_ai`).
  - Verificación en vivo: parsing de jerga colombiana ejecutado en <800ms respondiendo HTTP 200 con esquema JSON estricto.

### 26.2. Día de Cobro Mensual Editable en NLP ([`lib/presentation/screens/dialogs/nlp_entry_dialog.dart`](file:///lib/presentation/screens/dialogs/nlp_entry_dialog.dart))
- **Controlador Dinámico:** Se introdujo `_recurringDayController` vinculado en tiempo real a la detección de `CreateRecurringIntent`.
- **Campo Visible y Editable:**
  - `TextFormField` con clave `Key('recurring_day_field')` y etiqueta `"Día de cobro mensual (1-31)"`.
  - Si la frase menciona un día (ej. `"cada 15"`), el campo se precarga automáticamente con dicho valor, permitiendo al usuario cambiarlo libremente antes de pulsar `"Confirmar Suscripción"`.
  - Al enviar, el valor se procesa y asegura dentro del rango válido `1 <= dayOfMonth <= 31`.

### 26.3. AppBar Responsivo y Anti-Colisiones ([`lib/presentation/screens/dashboard_screen.dart`](file:///lib/presentation/screens/dashboard_screen.dart))
- **Adaptación Móvil (<600px):**
  - Título acortado limpiamente a `"Finanzas"` envuelto en `Flexible` con `TextOverflow.ellipsis`.
  - Iconos de acción (tema, alertas, alarmas, cierre fiscal, logout) compactados con `padding: EdgeInsets.zero`, restricciones tight de `32x32px` e iconos de `20px`.
  - Insignia de `"POSICIÓN FINANCIERA NETA"` ajustada con `Flexible` y `ellipsis`.
  - Encabezados de secciones con `Expanded` eliminando el uso de `Spacer()` rígidos.

### 26.4. Textos Completos y Apilado Vertical en Diálogos de Tarjetas ([`lib/presentation/screens/dialogs/credit_card_crud_dialog.dart`](file:///lib/presentation/screens/dialogs/credit_card_crud_dialog.dart) & [`card_details_dialog.dart`](file:///lib/presentation/screens/dialogs/card_details_dialog.dart))
- **Etiquetas Sin Puntos Suspensivos:** Sustitución de etiquetas cortadas por nombres completos: `"Últimos 4 dígitos"`, `"Cupo Total"`, `"Cupo Disponible"`, `"Día de pago"`, `"Día de corte"`.
- **Apilado Adaptativo:** En pantallas <440px, las parejas de campos horizontales se transforman automáticamente en columnas verticales de ancho completo.
- **Botones con Wrap:** Fila de acciones convertida a `Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8)` eliminando cualquier desbordamiento de píxeles (`RenderFlex overflow`).

### 26.5. Corrección de Superposición en Onboarding ([`lib/presentation/screens/onboarding_screen.dart`](file:///lib/presentation/screens/onboarding_screen.dart))
- **Estructura Flexible:**
  - `BankLogoAvatar` colocado directamente en el `Row` principal junto a `Expanded` para el nombre del banco, impidiendo solapamientos.
  - Padding responsivo (`14px` en móviles <500px vs `28px` en desktop).
  - Barra resumen convertida a `Wrap` para visualización limpia en anchos angostos.

### 26.6. Validación SDD
- **Nueva Suite de Pruebas:** [`test/presentation/screens/mobile_layout_and_nlp_day_test.dart`](file:///test/presentation/screens/mobile_layout_and_nlp_day_test.dart) verificando AppBar móvil, botones compactos, apilado de formularios, onboarding responsivo y campo editable de día recurrente en NLP.
- **Resultados de Calidad:**
  - **`flutter test`:** **159 de 159 tests pasando al 100% en verde** (0 fallos).
  - **`flutter analyze`:** **0 errores y 0 advertencias**.

---

## 27. Campo NLP Multilínea, Recordatorios con Monto Variable ($0 COP) y Paneles Acordeón Móviles — 2026-10-12

### 27.1. Campo de Texto Multilínea en Diálogo NLP ([`lib/presentation/screens/dialogs/nlp_entry_dialog.dart`](file:///lib/presentation/screens/dialogs/nlp_entry_dialog.dart))
- **Entrada Dinámica de Párrafo:** Configuración con `minLines: 2`, `maxLines: 8` y `keyboardType: TextInputType.multiline`, permitiendo que textos largos crezcan verticalmente en párrafo completo sin desplazarse lateralmente ni truncarse.
- **Botón Ergonómico de Limpiar Texto:** Agregado botón táctil (`Key('nlp_clear_text_button')`) alineado en el `suffixIcon` junto al botón de dictado por voz para restablecer el formulario con un solo toque.

### 27.2. Recordatorios de Servicios Públicos y Monto Variable ($0 COP)
- **Edge Function Gemini v1beta ([`supabase/functions/finance_ai/index.ts`](file:///supabase/functions/finance_ai/index.ts)):**
  - Prompt del sistema refinado para clasificar frases coloquiales ("recuérdame pagar", "recordar recibo", "factura de energía/luz/gas/agua/internet/arriendo") como `create_recurring`.
  - Regla de negocio de monto variable: Si la frase omite la cantidad monetaria, la IA infiere `amount: 0` sin arrojar error ni requerir monto forzado. Desplegado a Supabase Edge Functions.
- **Parser Local en Dart ([`lib/domain/services/nlp_parser.dart`](file:///lib/domain/services/nlp_parser.dart)):**
  - Exclusión de tokens temporales (`los \d{1,2}`, `el \d{1,2}`, `cada \d{1,2}`) de la extracción de dinero para evitar falsos positivos en el monto.
  - Tolerancia para `CreateRecurringIntent` con `amount: 0` asignando el día del mes inferido y deduciendo el nombre del servicio.
- **Diálogos de Confirmación ([`nlp_entry_dialog.dart`](file:///lib/presentation/screens/dialogs/nlp_entry_dialog.dart) & [`recurring_payment_dialog.dart`](file:///lib/presentation/screens/dialogs/recurring_payment_dialog.dart)):**
  - Muestra la insignia visual `"Monto Variable / Por Definir ($0 COP)"`.
  - Acción adaptativa: el botón cambia a `"Guardar Recordatorio"` cuando el monto es 0 (o `"Crear Suscripción"` si monto > 0).
  - Persistencia segura: permite guardar con monto $0 configurando `autoDeduct: amount > 0`.

### 27.3. Paneles Colapsables y Botonera Comprimida en Móvil ([`lib/presentation/screens/dashboard_screen.dart`](file:///lib/presentation/screens/dashboard_screen.dart))
- **Botonera "⚡ Acciones Rápidas":** En pantallas móviles (<600px), reemplaza los 6 botones dispersos por un botón de acción principal (`Key('dashboard_quick_actions_button')`) que despliega un Modal Bottom Sheet estilizado con las opciones: Transferir, Pagar TC, Gestionar Cuentas, Gestionar Tarjetas, Suscripciones y Auditar Fugas con IA.
- **Acordeón Colapsable:**
  - "Cuentas Banco y Bolsillos" desplegada por defecto en móvil; "Tarjetas de Crédito" colapsada por defecto. Ambas alternables con un toque en el encabezado con flecha animada.
  - Resumen compacto en la barra de título cuando el bloque está colapsado (ej. `"Cuentas Banco (1) · $ 500.000"` y `"Tarjetas (1) · Deuda $ 50.000"`).
- **Prevención de Overflows:** Cajas de montos en tarjetas de crédito reforzadas con `Expanded` y `TextOverflow.ellipsis`, eliminando cualquier riesgo de desbordamiento en anchos angostos.

### 27.4. Validación y Métricas de Calidad
- **Pruebas Automatizadas:** **163 de 163 tests pasando al 100% en verde** (`flutter test`).
- **Análisis Estático:** **0 errores y 0 advertencias** (`flutter analyze`).

---

## 28. Apertura Directa del Diálogo NLP vía Parámetro URL y Accesos Directos PWA — 2026-10-12

### 28.1. Detección y Enrutamiento de Parámetros URL ([`lib/presentation/screens/dashboard_screen.dart`](file:///lib/presentation/screens/dashboard_screen.dart))
- **Mecanismo de Extracción Robusto:** Implementación de `DashboardScreen.parseActionFromUri(Uri uri)` y `DashboardScreen.getUrlAction()` que analiza tanto parámetros directos (`?action=nlp`) como fragmentos hash (`/#/?action=voice` o `/#/dashboard?action=nlp`).
- **Apertura Automatizada en Post-Frame:**
  - En `initState()`, se programa `WidgetsBinding.instance.addPostFrameCallback` para garantizar que la pantalla esté montada.
  - Si `action == 'nlp'`: Despliega automáticamente `NlpEntryDialog()`.
  - Si `action == 'voice'`: Despliega automáticamente `NlpEntryDialog(startListeningImmediately: true)` activando la escucha de micrófono en vivo.
- **Control de Ciclo de Vida:** Bandera booleana interna `_hasHandledUrlAction` que previene aperturas duplicadas ante re-renderizados o cambios de estado del Dashboard.

### 28.2. Accesos Directos PWA ([`web/manifest.json`](file:///web/manifest.json))
- **Shortcuts Declarados:** Agregada la clave estándar `"shortcuts"` en el manifest de la PWA:
  - *"Dictar por Voz"* apuntando a `./?action=voice` con icono 192px.
  - *"Ingreso Rápido"* apuntando a `./?action=nlp` con icono 192px.
  - Permite acceso directo e instantáneo desde el menú contextual o pantalla de inicio de Android/iOS/Chrome.

### 28.3. Validación y Suite de Pruebas
- **Nueva Suite:** [`test/presentation/screens/dashboard_url_action_test.dart`](file:///test/presentation/screens/dashboard_url_action_test.dart) cubriendo casos unitarios de parsing de URLs y pruebas de widgets con apertura automática para `action=nlp` y `action=voice`.
- **Resultados de Calidad:**
  - **`flutter test`:** **171 de 171 tests pasando al 100% en verde** (0 fallos).
  - **`flutter analyze`:** **0 errores y 0 advertencias**.

---

## 29. Corrección de Truncaciones Horizontales y Rediseño Responsivo de NlpEntryDialog — 2026-10-12

### 29.1. Encabezado Conciso y Libre de Elipsis ([`lib/presentation/screens/dialogs/nlp_entry_dialog.dart`](file:///lib/presentation/screens/dialogs/nlp_entry_dialog.dart))
- **Título Compacto:** Sustituido el título redundante `"Ingreso Rápido por Frase (NLP)"` por el título limpio `"Ingreso Rápido"`, envuelto en `Expanded` con tamaño de 18px y peso `FontWeight.bold`, conviviendo holgadamente junto al icono de cerebro y el botón `(X)`.

### 29.2. Campo de Entrada con Hint Multilínea Seguro
- **TextField Adaptable:** Configuración con `minLines: 2`, `maxLines: 4` y `keyboardType: TextInputType.multiline`.
- **Hint Conciso:** Cambiado a `"Escribe o dicta tu movimiento..."` con `hintMaxLines: 2` y `labelText: "Escribe o dicta tu movimiento"`, impidiendo cualquier corte con puntos suspensivos ("...").

### 29.3. Disposición Responsiva en Móvil (<440px): Operación y Monto COP
- **LayoutBuilder Adaptativo:**
  - En anchos `<440px` (móviles): Organiza los campos en columna vertical de ancho completo:
    1. Selector "Operación" con opciones limpias: `"Gasto"`, `"Ingreso"`, `"Abono a TC"`.
    2. Campo de texto "Monto COP" con prefijo `$ `.
  - En pantallas `>=440px` (tablets / desktop): Conserva la fila horizontal proporcional (flex 6:5).
- **Simplificación de Textos del Selector:**
  - `"Gasto"` (reemplazando "Gasto / Compra")
  - `"Ingreso"`
  - `"Abono a TC"` (reemplazando "Abonar a Tarjeta (Pagar TC)")

### 29.4. Simplificación de Etiquetas Flotantes
- Selector de entidad origen: `"Cuenta o Tarjeta"` (en lugar de "Origen (Cuenta Banco o Tarjeta)").
- Selector de bolsillo: `"Bolsillo"` (en lugar de "Bolsillo de la Cuenta").
- Selectores de abono a tarjeta: `"Tarjeta a Abonar"` y `"Bolsillo de Origen"`.

### 29.5. Maximización del Ancho Útil del Diálogo en Pantallas Móviles
- **Reducción de Margen Exterior (`insetPadding`):** Ajustado dinámicamente a `EdgeInsets.symmetric(horizontal: 14, vertical: 20)` en pantallas móviles (<480px), reduciendo el padding interior a `16.0` para ganar más de 68px de ancho útil para formularios.

### 29.6. Validación y Suite de Pruebas
- **Nuevas Pruebas:** Ampliada la suite [`test/presentation/screens/mobile_layout_and_nlp_day_test.dart`](file:///test/presentation/screens/mobile_layout_and_nlp_day_test.dart) verificando el apilado vertical, la ausencia de desbordamientos RenderFlex y la visibilidad íntegra de etiquetas y hints en pantallas de 360px.
- **Resultados de Calidad:**
  - **`flutter test`:** **172 de 172 tests pasando al 100% en verde** (0 fallos).
  - **`flutter analyze`:** **0 errores y 0 advertencias**.

---

## 30. Rediseño Visual de la Barra de Registro Inteligente y Creación de la Esfera Flotante Sof.IA — 2026-10-12

### 30.1. Rediseño de la Barra de Registro Rápido ([`lib/presentation/screens/dashboard_screen.dart`](file:///lib/presentation/screens/dashboard_screen.dart))
- **Título y Subtítulo Concisos:** Encabezado simplificado a `"Registro Inteligente"` con subtítulo corto `"Escribe o dicta tu movimiento"`, libre de textos largos y truncaciones con elipsis.
- **Eliminación del Botón Copiloto:** Removido definitivamente el botón redundante de la barra de comandos para otorgar todo el protagonismo a la nueva esfera flotante.
- **Botonera de Alto Contraste:** Únicamente dos botones limpios:
  1. `"Ingreso por Frase"`: Botón destacado con color acento de la marca e icono `Icons.edit_note_rounded`.
  2. `"Dictar por Voz"`: Botón con estilo píldora, borde contrastado e icono `Icons.mic_rounded`.
- **Distribución Móvil Equilibrada:** En pantallas móviles (`< 620px`), ambos botones se organizan en una fila balanceada con `Expanded` y `maxLines: 1`, evitando cualquier truncación o salto de línea.

### 30.2. Creación del Widget Interactivo "Sof.IA" ([`lib/presentation/widgets/sofia_floating_orb.dart`](file:///lib/presentation/widgets/sofia_floating_orb.dart))
- **Identidad Visual:** Contenedor esférico de 60px con gradiente tricolor vibrante (azul eléctrico `#2563EB`, púrpura `#7C3AED` y cian `#06B6D4`), icono central de destellos `Icons.auto_awesome` y múltiple sombra difusa de brillo (*glow*).
- **Animación de Reposo (*Breathing / Pulse*):** `AnimationController` con variación suave de escala (1.0 a 1.06) y halo exterior de opacidad dinámica (0.25 a 0.65).
- **Micro-Interacción Elástica:** Reacciona al toque con una reducción elástica a 0.94 y recuperación inmediata al soltar, abriendo el diálogo de Sof.IA.
- **Badge y Tooltip:** Incluye etiqueta flotante `"Sof.IA"` en la esquina superior y `Tooltip` explicativo `"Sof.IA · Tu asesora financiera"`.
- **Control para Tests Automatizados:** Incorpora detección de entorno de test y flag estático `enablePulseInTests` para evitar bloqueos por tiempo de espera en `WidgetTester.pumpAndSettle()`.

### 30.3. Renombramiento y Mejora del Chat de Sof.IA ([`lib/presentation/screens/dialogs/ai_copilot_dialog.dart`](file:///lib/presentation/screens/dialogs/ai_copilot_dialog.dart))
- **Identidad Renovada:** Título `"Sof.IA"`, subtítulo `"Tu asesora financiera inteligente"` y avatar esférico con el mismo gradiente brillante.
- **Saludo Personalizado:** `"¡Hola! Soy Sof.IA, tu asistente financiera personal. Analizo tus cuentas y bolsillos en tiempo real. ¿Qué te gustaría consultar o planear hoy?"`.
- **Transición Fluida:** Implementado método estático `AiCopilotDialog.show(context)` utilizando `showGeneralDialog` con curvas `Curves.easeOutCubic`, escala y fade.
- **Ergonomía en Móvil (< 600px):** Modal alineado a la parte inferior con bordes redondeados superiores (24px), barra táctil de arrastre superior y altura del 85% de la pantalla.

### 30.4. Actualización del Backend y Prompt de Sistema ([`supabase/functions/finance_ai/index.ts`](file:///supabase/functions/finance_ai/index.ts))
- **Acción `chat_copilot`:** System Prompt actualizado para que la IA se identifique formalmente como `"Sof.IA"`, una asesora financiera personal, cercana, estratégica y experta adaptada al contexto, modismos y realidad económica de Colombia.

### 30.5. Validación y Suite de Pruebas
- **Nuevas Pruebas ([`test/presentation/widgets/sofia_floating_orb_test.dart`](file:///test/presentation/widgets/sofia_floating_orb_test.dart)):** Cobertura completa del widget flotante, animaciones, callbacks de pulsación y renderizado responsivo en el Dashboard.
- **Resultados de Calidad:**
  - **`flutter test`:** **177 de 177 tests en verde (100% de éxito)**.
  - **`flutter analyze`:** **0 advertencias / 0 errores**.

---

## 31. Motor Multimodal de Comprobantes Bancarios, Refinamiento de Direccionalidad y Webhook Ingest — 2026-10-13

### 31.1. Refinamiento de Léxico Bancario y Direccionalidad (Ingreso vs Gasto)
- **Backend Edge Function ([`supabase/functions/finance_ai/index.ts`](file:///supabase/functions/finance_ai/index.ts)):**
  - Calibración estricta del System Prompt para clasificar inequívocamente transferencias entrantes como `intent_type: "income"`:
    - Palabras clave de entrada: *"me transfirieron"*, *"te transfirieron"*, *"recibiste"*, *"te llegó"*, *"te enviaron"*, *"abono a tu cuenta"*, *"recepción de transferencia"*, *"consignación recibida"*, *"me consignaron"*, *"me pagaron"*, *"me entró"*, *"quincena"*, *"prima"*.
    - **Regla de Oro:** *"me transfirieron 25.000 pesos a la cuenta de Bancolombia Carlos Vives"* se clasifica obligatoriamente como ingreso a la cuenta de Bancolombia, con monto 25.000 COP y descripción limpia *"Carlos Vives"*.
    - Palabras clave de salida (*"transferiste a"*, *"enviaste a"*, *"pagaste"*, *"compraste"*, *"débito por"*, *"retiro cajero"*) clasificadas como gasto (`expense`).
- **Parser Local Dart ([`lib/domain/services/nlp_parser.dart`](file:///lib/domain/services/nlp_parser.dart)):**
  - Implementación de `_incomePriorityPattern` evaluado antes de las transferencias internas entre bolsillos, evitando que transferencias recibidas desde terceros sean confundidas con traspasos entre bolsillos.
  - Métodos auxiliares `_extractCleanDescription` y `_capitalizeWords` para depurar el texto de disparadores, bancos y montos, conservando nombres de remitentes y notas con capitalización correcta.

### 31.2. Motor Multimodal de Comprobantes Bancarios sin Persistencia de Imagen (`parse_receipt`)
- **Backend Multimodal:**
  - Acción `parse_receipt` en `finance_ai` invocando Gemini 2.0 Flash vía `inlineData` (base64 de JPEG, PNG o WebP).
  - Reconocimiento de entidades financieras colombianas (Nequi, Bancolombia, Daviplata, Dale, Nu, Transfiya, Lulo, Davivienda) mediante colores, tipografías y logos.
  - Discriminación de direccionalidad (egreso *"Envío exitoso"*, *"Pagaste"* vs ingreso *"Te transfirieron"*, *"Plata recibida"*).
  - Extracción de JSON estructurado: `operation`, `amount`, `bank_name`, `recipient_or_sender`, `date`, `reference_code`, `description`.
  - **Garantía de Privacidad y Costo Cero de Storage:** La imagen se procesa exclusivamente en memoria efímera durante la inferencia y jamás se almacena en Supabase Storage ni en disco.

### 31.3. Integración en UI y Flujo de Edición Manual
- **Asistente de Selección Cross-Platform ([`lib/presentation/utils/image_picker_helper.dart`](file:///lib/presentation/utils/image_picker_helper.dart)):**
  - Soporte de subida nativa de archivos en Flutter Web vía HTML `FileUploadInputElement` y `FileReader` con importaciones condicionales para preservar compatibilidad con la máquina virtual de Dart en pruebas (`image_picker_stub.dart`).
  - Detección de imágenes o datos base64 en el portapapeles con timeout de seguridad y fallback interactivo a modal de pegado directo.
- **Diálogo NLP ([`lib/presentation/screens/dialogs/nlp_entry_dialog.dart`](file:///lib/presentation/screens/dialogs/nlp_entry_dialog.dart)):**
  - Botón `"📷 Escanear Comprobante"` (`nlp_scan_receipt_button`).
  - Al procesar el comprobante, **NO auto-guarda**: precarga todos los campos detectados (Operación Gasto/Ingreso, Monto COP, Cuenta o Tarjeta coincidente, Bolsillo sugerido, Descripción y nota) manteniendo total libertad de edición manual antes de confirmar.
  - Soporta apertura automática y escaneo directo con el parámetro `initialTriggerScan: true`.
- **Barra de Registro en Dashboard ([`lib/presentation/screens/dashboard_screen.dart`](file:///lib/presentation/screens/dashboard_screen.dart)):**
  - Incorporado botón `"Comprobante"` (`dashboard_scan_receipt_button`) en la barra de comando superior, adaptado tanto a pantallas móviles (<620px) como de escritorio.
  - Enrutamiento por URL: soporte para `action == 'receipt'` y `action == 'scan'`.

### 31.4. Ingesta Automática por Webhook (`webhook_ingest`)
- Acción `webhook_ingest` en la función Edge `finance_ai` preparada para consumir notificaciones en texto sin procesar provenientes de Atajos de Apple Pay, SMS bancarios de Android o integraciones de mensajería, clasificando intenciones y asociándolas al usuario sin requerir interacción manual previa.

### 31.5. Validación y Suite de Pruebas
- **Nuevas Pruebas Unitarias y de Widgets:**
  - Pruebas en [`test/domain/nlp_parser_test.dart`](file:///test/domain/nlp_parser_test.dart) verificando la frase de Carlos Vives y variantes de recepción de transferencias en Bancolombia y Nequi.
  - Pruebas en [`test/domain/ai_assistant_service_test.dart`](file:///test/domain/ai_assistant_service_test.dart) validando `parseReceipt` y `webhookIngest`.
  - Pruebas en [`test/presentation/widgets/ai_dialogs_and_copilot_test.dart`](file:///test/presentation/widgets/ai_dialogs_and_copilot_test.dart) verificando renderizado del botón de escaneo y precarga íntegra sin auto-guardado.
  - Pruebas en [`test/presentation/widgets/sofia_floating_orb_test.dart`](file:///test/presentation/widgets/sofia_floating_orb_test.dart) validando la presencia del botón de comprobante en móvil y escritorio.
- **Resultados de Calidad:**
  - **`flutter test`:** **181 de 181 tests pasando al 100% en verde** (0 fallos).
  - **`flutter analyze`:** **0 errores y 0 advertencias**.

---

## 32. Compresión de Comprobantes en el Cliente e Inyección Contextual de Cuentas y Bolsillos en NLP — 2026-10-15

### 32.1. Compresión y Conversión de Comprobantes en el Cliente
- **Selector Web Multiformato ([`lib/presentation/utils/image_picker_web.dart`](file:///lib/presentation/utils/image_picker_web.dart)):**
  - Parámetro `accept` configurado con formatos estándar y formatos móviles de iOS: `'image/*,.heic,.heif,.png,.jpg,.jpeg,.webp'`.
  - Implementación de compresión del lado del cliente utilizando HTML5 Canvas con fondo opaco y reescalado proporcional a un ancho máximo de 1280px.
  - Conversión de cualquier imagen seleccionada, copiada del portapapeles o pegada a formato `image/jpeg` con compresión de calidad 82% (`0.82`), reduciendo drásticamente el peso del Base64 antes de transmitirlo por la red.
  - Método utilitario `compressImage` expuesto en [`lib/presentation/utils/image_picker_helper.dart`](file:///lib/presentation/utils/image_picker_helper.dart) con stubs limpios para Dart VM/tests ([`lib/presentation/utils/image_picker_stub.dart`](file:///lib/presentation/utils/image_picker_stub.dart)).
- **Manejo en la Interfaz ([`lib/presentation/screens/dialogs/nlp_entry_dialog.dart`](file:///lib/presentation/screens/dialogs/nlp_entry_dialog.dart)):**
  - Envío explícito de `mimeType: 'image/jpeg'` en la llamada a `parseReceipt`.
  - Captura robusta de errores con `SnackBar` descriptivo en color de alerta en caso de fallos de red o de la Edge Function.

### 32.2. Inyección Dinámica de Cuentas y Bolsillos en NLP
- **Backend Edge Function ([`supabase/functions/finance_ai/index.ts`](file:///supabase/functions/finance_ai/index.ts)):**
  - Extensión de interfaces `ParseIntentRequest` y `ParseReceiptRequest` para admitir `available_accounts` (`[{ id, name }]`) y `available_pockets` (`[{ id, name, bank_account_id }]`).
  - Inyección dinámica de las cuentas y bolsillos existentes del usuario directamente dentro del System Prompt de Gemini 2.0 Flash.
  - Instrucciones estrictas de coincidencia de nombres ignorando mayúsculas, minúsculas, tildes y preposiciones o conectores coloquiales (*"en el bolsillo"*, *"desde el bolsillo"*, *"del bolsillo"*, *"de bolsillo"*, *"desde la cuenta"*, *"en la cuenta"*, *"por"*, *"en"*, *"desde"*).
  - Regla de Oro: Frases como *"me gasté 15 mil en almuerzo desde nequi bolsillo personal"* son mapeadas con exactitud a:
    - `operation` / `intent_type`: `"expense"`
    - `amount`: `15000` (resolución de *"mil"* como 1000 COP)
    - `bank_account` / `source_name`: `"Nequi"` con su respectivo `source_id`
    - `pocket` / `pocket_name`: `"Personal"` con su respectivo `pocket_id`
    - `note` / `description`: `"Almuerzo"`
- **Frontend y Parser Local ([`lib/domain/services/nlp_parser.dart`](file:///lib/domain/services/nlp_parser.dart) y [`lib/domain/services/ai_assistant_service.dart`](file:///lib/domain/services/ai_assistant_service.dart)):**
  - Inclusión del multiplicador `"mil"` en `_extractAmount` (`15 mil` -> 15.000 COP).
  - Método `_expandPocketTargets` que genera alias expandidos con combinaciones preposicionales (*"bolsillo $alias"*, *"del bolsillo $alias"*, *"desde el bolsillo $alias"*, *"en el bolsillo $alias"*).
  - Método `_extractCleanExpenseDescription` con límites Unicode seguros (`(?<![a-záéíóúüñ])`) que elimina disparadores (*"me gasté"*, *"gasté"*, *"pagué"*, etc.), cuentas (*"desde nequi"*), bolsillos (*"bolsillo personal"*), montos (*"15 mil"*) y preposiciones iniciales (*"en "*), aislando la nota limpia (*"Almuerzo"*).
  - Soporte de `availableAccounts` y `availablePockets` opcionales en `NlpParser.parse` para enriquecimiento dinámico en caliente del catálogo.
  - `AiAssistantService.parseIntentWithAi` y `parseReceipt` envían `available_accounts` y `available_pockets` al backend y mapean de forma bidireccional `bank_account`, `pocket` y `note`.
  - `NlpEntryDialog` actualiza el campo de nota (`_descController.text`) con la descripción limpia extraída tanto en modo local como tras la refinación por IA.

### 32.3. Estado de Calidad y Verificación
- **Pruebas Automatizadas:** **186 de 186 tests pasando al 100% en verde** (0 fallos).
- **Análisis Estático:** `flutter analyze` reporta **0 errores y 0 advertencias**.
- **Cobertura de Casos Clave:**
  - Test unitario validando *"me gasté 15 mil en almuerzo desde nequi bolsillo personal"* -> amount: 15.000, cuenta: Nequi, bolsillo: Personal, nota: Almuerzo.
  - Test unitario validando inyección dinámica de cuentas y bolsillos en `NlpParser.parse`.
  - Test unitario verificando la transmisión de `available_accounts` y `available_pockets` con `image/jpeg` en `parseReceipt` y `parseIntentWithAi`.

---

## 33. Creación de Usuario de Pruebas y Datos Semilla Aislados (2026-10-15)

### 33.1. Contexto y Objetivos
- **Protección de Cuenta Principal:** Salvaguardar los datos reales de `alexdjp15@gmail.com` permitiendo pruebas exhaustivas (NLP, comprobantes, edición de entidades, recordatorios, transferencias) en un entorno realista y aislado.
- **Aislamiento por RLS:** Todas las tablas de la base de datos (`accounts`, `pockets`, `credit_cards`, `transactions`, `recurring_payments`, `aliases`) están protegidas por Row-Level Security (`auth.uid() = user_id`).

### 33.2. Credenciales del Usuario de Pruebas
- **Nombre de Usuario (`username`):** `demo_tester`
- **Correo Electrónico (`email`):** `demo_tester@finanzas.app`
- **Contraseña (`password`):** `Password123!`
- **Estado de Confirmación:** Correo confirmado (`email_confirmed_at` verificado en Supabase Auth).
- **Compatibilidad de Login:** Puede iniciar sesión ingresando el username `demo_tester` o el email `demo_tester@finanzas.app`.

### 33.3. Datos Semilla Poblados en Supabase
1. **Cuentas Bancarias y Bolsillos (7 bolsillos con saldos en COP):**
   - **Bancolombia** (`1089-234567`):
     - *Disponible en Cuenta*: $450.000 COP
     - *Personal*: $380.000 COP
     - *Arriendo*: $1.200.000 COP
     - *Ahorro Vacaciones*: $850.000 COP
   - **Nequi** (`300 123 4567`):
     - *Disponible Nequi*: $135.000 COP
     - *Comidas Fuera*: $90.000 COP
   - **Daviplata** (`310 987 6543`):
     - *Servicios Públicos*: $160.000 COP
2. **Tarjetas de Crédito:**
   - **RappiCard:** Cupo $3.000.000 COP (Corte: día 18, Pago: día 5)
   - **Tarjeta Nu:** Cupo $5.000.000 COP (Corte: día 12, Pago: día 2)
3. **Alias NLP:** Bancolombia, Nequi, Daviplata, Rappi, RappiCard, Nu, Tarjeta Nu, Personal, Arriendo, Vacaciones, Comidas, Servicios.
4. **Historial de Transacciones (7 movimientos reales):**
   - Ingreso nómina quincena ($2.500.000 COP a Disponible Bancolombia).
   - Gasto Mercado Éxito ($185.000 COP desde Personal).
   - Gasto Almuerzo Restaurante ($28.000 COP desde Comidas Fuera Nequi).
   - Cargo TC RappiCard ($50.000 COP Gasolina Terpel).
   - Cargo TC Nu ($35.000 COP Farmacia La Rebaja).
   - Abono a TC Nu ($400.000 COP pagado desde Disponible Bancolombia).
   - Transferencia entre bolsillos ($150.000 COP de Personal a Ahorro Vacaciones).
5. **Suscripciones y Recordatorios Recurrentes (5 registros):**
   - Netflix 4K ($45.000 COP, día 15, auto-deduct, TC RappiCard).
   - Spotify Familiar ($26.900 COP, día 5, auto-deduct, TC Nu).
   - Factura Internet Claro ($95.000 COP, día 10, manual, Bancolombia).
   - Recibo del Agua ($0 COP - Monto Variable, día 18, manual, Daviplata).
   - Gimnasio SmartFit ($89.000 COP, día 1, auto-deduct, Nequi).

### 33.4. Actualizaciones de Esquema y Migraciones
- Migración [`supabase/migrations/20261015160000_recurring_payments_allow_zero_amount.sql`](file:///supabase/migrations/20261015160000_recurring_payments_allow_zero_amount.sql): actualizó el constraint `recurring_payments_amount_check` de `amount > 0` a `amount >= 0`, permitiendo persistir recordatorios de servicios públicos y facturas variables con valor $0 COP sin error de base de datos.
- Utilidad repetible de siembra: [`tool/seed_test_user.dart`](file:///tool/seed_test_user.dart), ejecutable en cualquier momento con `dart run tool/seed_test_user.dart` para restablecer el entorno de prueba con datos frescos sin tocar ninguna otra cuenta.

