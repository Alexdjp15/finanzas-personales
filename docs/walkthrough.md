# Walkthrough — Core App de Finanzas Personales (Flutter + Supabase)

Implementación completada del MVP especificado en [docs/specs/01_app_finanzas.md.md](file:///c:/Users/User/Desktop/developing/finanzas%20personales/docs/specs/01_app_finanzas.md.md) y planificado en [docs/plans/01_implementation_plan.md](file:///c:/Users/User/Desktop/developing/finanzas%20personales/docs/plans/01_implementation_plan.md), siguiendo rigurosamente las directrices de [AGENTS.md](file:///c:/Users/User/Desktop/developing/finanzas%20personales/AGENTS.md) y [docs/constitution.md](file:///c:/Users/User/Desktop/developing/finanzas%20personales/docs/constitution.md).

---

## 1. Resumen de Cambios Realizados

### A. Seguridad y Entorno
- **Protección de Tokens:** Se eliminó `mcp_config.json` del rastreo de Git (`git rm --cached`) y se ignoró en `.gitignore`.
- **Configuración Supabase:** Se crearon los archivos [.env](file:///c:/Users/User/Desktop/developing/finanzas%20personales/.env) y [.env.example](file:///c:/Users/User/Desktop/developing/finanzas%20personales/.env.example) con las credenciales del proyecto real (`ciesbycnqesrubtcrjbm`).

### B. Base de Datos PostgreSQL y Supabase (Migraciones Aplicadas)
1. **Esquema Relacional y RLS ([20261007171500_schema.sql](file:///c:/Users/User/Desktop/developing/finanzas%20personales/supabase/migrations/20261007171500_schema.sql)):**
   - 8 tablas creadas: `accounts`, `pockets`, `credit_cards`, `recurring_payments`, `transactions`, `aliases`, `alert_deliveries`, `user_settings`.
   - Montos monetarios almacenados como enteros en COP (`bigint`) para evitar errores de coma flotante.
   - Políticas RLS por usuario (`auth.uid()`) activadas en todas las tablas.
2. **Operaciones Atómicas RPC ([20261007171600_functions.sql](file:///c:/Users/User/Desktop/developing/finanzas%20personales/supabase/migrations/20261007171600_functions.sql)):**
   - `record_pocket_movement`: Ingreso o gasto con actualización de saldo del bolsillo (soporta saldos negativos según decisión de usuario).
   - `record_card_charge`: Cargo a tarjeta de crédito reduciendo cupo disponible y categorizando en el bolsillo sin mover saldo bancario.
   - `record_card_payment`: Abono a tarjeta debitando del bolsillo seleccionado y restaurando el cupo disponible.
   - `transfer_between_pockets`: Mueve fondos entre bolsillos de una misma cuenta manteniendo inalterado el saldo bancario global.
   - `delete_transactions_of_year`: Limpieza de histórico para el cierre fiscal anual.
3. **Automatización Cron ([20261007171700_cron.sql](file:///c:/Users/User/Desktop/developing/finanzas%20personales/supabase/migrations/20261007171700_cron.sql)):**
   - `pg_cron` programado a las `0 13 * * *` UTC (08:00 AM hora de Bogotá) para debitar automáticamente suscripciones vencidas con lógica idempotente para meses cortos (día 31 ajustado a final de mes).

### C. Capa de Dominio Puro (Lógica desacoplada de la UI)
- [models.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/models/models.dart): Modelos inmutables (`Account`, `Pocket`, `CreditCard`, `RecurringPayment`, `AppAlert`, etc.).
- [balance_calculator.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/balance_calculator.dart): Cálculo estricto de balances, patrimonio neto y transferencias internas.
- [credit_card_service.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/credit_card_service.dart): Reglas de cupo y abonos a deuda.
- [nlp_parser.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/nlp_parser.dart): Parser determinista mediante expresiones regulares con catálogo de alias (`NlpCatalog`). Extrae monto, signo (+/-), cuenta/tarjeta y bolsillo.
- [recurring_payment_processor.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/recurring_payment_processor.dart): Cálculo de cobros pendientes y reglas de fecha límite.
- [alert_scheduler.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/alert_scheduler.dart): Generación de recordatorios configurables a 48h y 24h previas al corte/cobro.
- [fiscal_close_service.dart](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/domain/services/fiscal_close_service.dart): Exportación anual a JSON y CSV con generación de saldos iniciales del nuevo año.

### D. Capa de Datos (Repositorios)
- [SupabaseAuthRepository](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/data/supabase_auth_repository.dart): Autenticación con correo y contraseña.
- [SupabaseFinanceRepository](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/data/supabase_finance_repository.dart): Conexión con Supabase y ejecución de RPCs atómicas.

### E. Capa de Presentación Web
- [LoginScreen](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/login_screen.dart): Formulario de login y registro.
- [OnboardingScreen](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/onboarding_screen.dart): Inicialización con un clic de la estructura predeterminada (Bancolombia, Nequi, bolsillos Personal, Graficolor, Apartamentos, Favores, y tarjetas Bancolombia Única y RappiCard).
- [DashboardScreen](file:///c:/Users/User/Desktop/developing/finanzas%20personales/lib/presentation/screens/dashboard_screen.dart):
  - Barra de resumen superior: Patrimonio Neto, Activos Totales (Bancos), Pasivos Totales (Tarjetas).
  - Cuentas Eje con suma matemática de sus bolsillos.
  - Tarjetas de Crédito aisladas con Cupo Total, Disponible, Deuda y fechas de corte/límite de pago.
  - Centro de alertas in-app con contador en campana.
  - Modales de acción: Ingreso Rápido por Frase (NLP) con confirmación editable previa a guardar, Transferencia entre bolsillos, Abono a Tarjeta de Crédito, CRUD de Bolsillos, Gestión de Suscripciones, Configuración de Hora de Alertas y Cierre Fiscal con exportación JSON/CSV y doble confirmación ("CONFIRMAR").

---

## 2. Refactorizaciones y Corrección de Errores de UI y Lógica (Ciclo 2)

1. **Fix de Renderizado (Pantalla Roja y Overflows):**
   - Corregido el error `Duplicate keys found / multiple children with key [<null>]` en `TransferDialog`, `CardPaymentDialog`, `RecurringPaymentDialog` y `NlpEntryDialog`. Se sustituyeron claves dinámicas que generaban `ValueKey(null)` por claves únicas estables no nulas (`const Key(...)` o IDs garantizados).
   - Corregido el error `BOTTOM OVERFLOWED` en todos los modales al envolver su estructura en `SingleChildScrollView` dentro de un `ConstrainedBox` con restricción dinámica de altura (`maxHeight: mediaQuery.size.height * 0.85`).
   - Gestión segura de listas vacías y cuentas sin bolsillos en los selectores desplegables.

2. **Compras con Tarjeta de Crédito:**
   - El campo "Bolsillo" en el modal de transacciones NLP es opcional cuando el origen es una Tarjeta de Crédito. Si el usuario no lo especifica, se categoriza de manera automática como `Personal` o `General` sin bloquear la operación.

3. **Gestión Personalizada de Cuentas (CRUD):**
   - Implementados métodos en `FinanceRepository` y `SupabaseFinanceRepository` para crear cuentas con bolsillo inicial (`createAccountWithInitialPocket`) y eliminarlas (`deleteAccount`).
   - El modal de administración ahora cuenta con pestañas de **Cuentas Eje** y **Bolsillos**, permitiendo agregar nuevas entidades (nombre, tipo y saldo inicial) y eliminar cuentas que no tengan movimientos registrados (ej. borrar Nu o Davivienda si no se usan).

4. **Asistente de Configuración Inicial (Onboarding Interactivo):**
   - Reemplazado el botón de carga fija por un asistente interactivo completo con formulario en tiempo real (`OnboardingScreen`).
   - Permite ingresar saldos iniciales reales de Cuentas Eje y Bolsillos, así como configurar los Cupos Totales y Cupos Disponibles de las Tarjetas de Crédito, visualizando el cálculo de Activos, Deuda y Patrimonio Neto en vivo antes de guardar.

5. **Mejoras del Motor NLP Parser:**
   - Si una frase no especifica cuenta ni tarjeta de origen (ej. `15000 gasolina`), se preselecciona automáticamente la Cuenta Eje principal por defecto sin generar advertencias bloqueantes de `unknownSource`.
   - Detección ampliada de alias con prefijos `tc`, `tarjeta`, `tarjeta de credito`, `cuenta` y `cta`. Manejo de colisiones de nombre entre tarjeta y cuenta de la misma entidad (ej. `bancolombia` -> Cuenta; `tc bancolombia` -> Tarjeta).

---

## 3. Resultados de Pruebas Automatizadas

Se ejecutó la suite completa de tests de lógica de negocio y componentes de interfaz:

```bash
flutter test --reporter compact
```
- **Resultado:** **54 tests ejecutados con éxito (100% passed, 0 failures)**.
  - 13 tests de Balances, Patrimonio Neto y Tarjetas de Crédito.
  - 14 tests de Suscripciones, Fechas Clamped (Día 31) y Alertas Proactivas.
  - 17 tests de NLP Parser (saldos, prefijos `tc`/`tarjeta`, selección de cuenta por defecto, resolución de alias compartidos).
  - 7 tests de Cierre Fiscal y Exportación JSON/CSV.
  - 3 widget tests actualizados (Login, Onboarding interactivo y Dashboard responsivo con cuentas y tarjetas).

```bash
flutter analyze
```
- **Resultado:** **No issues found!** (0 errores, 0 advertencias, 0 lints).

---

## 4. Verificación Visual en Navegador (Chromium Headless / Edge)

La aplicación fue compilada para producción web (`flutter build web --release`) y verificada mediante el protocolo CDP (Chrome DevTools Protocol) en resolución de escritorio y móvil:

- **Inspección de Consola:** **0 errores de consola (`console.error = 0`)**.
- **Capturas visuales obtenidas:**

### Pantalla de Inicio de Sesión (Desktop 1280x800)
![Desktop Login](screenshot_desktop.png)

### Pantalla de Inicio de Sesión (Mobile 390x844)
![Mobile Login](screenshot_mobile.png)

---

## 5. Instrucciones para Ejecución Local

Para correr la aplicación en tu navegador:

```powershell
$env:Path = "C:\src\flutter\bin;" + $env:Path
flutter run -d chrome --dart-define-from-file=.env
```

O si prefieres utilizar el servidor web integrado de Flutter:
```powershell
flutter run -d web-server --web-port 8080 --dart-define-from-file=.env
```
Y abrir `http://localhost:8080` en tu navegador.
