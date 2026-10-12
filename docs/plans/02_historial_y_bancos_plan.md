# Plan de Implementación: Historial por Banco y Tarjeta, Saldos Fuera de Bolsillos, Onboarding en 0 y Retención Anual

## 1. Objetivos del Cambio
1. **Onboarding Limpio:** Iniciar todas las cuentas y tarjetas en $0 COP; permitir añadir y quitar tarjetas y bancos dinámicamente con definición de día de corte y fecha límite de pago.
2. **Nomenclatura:** Sustituir "Cuenta Eje" por "Cuenta Banco" en toda la interfaz.
3. **Estructura de Banco:** Añadir número de cuenta (`account_number`) y desglosar el saldo en:
   - Saldo Fuera de Bolsillos (disponible libre en la cuenta donde llegan los ingresos).
   - Saldo en Bolsillos (asignado a metas o categorías).
   - Saldo Total del Banco.
4. **Historial de Movimientos:**
   - En cada Banco: Diálogo con detalles, número de cuenta, desglose de saldos e historial de transacciones con filtro por bolsillo.
   - En cada Tarjeta de Crédito: Diálogo con detalles (corte, fecha límite de pago, cupos) e historial de compras y abonos.
5. **Retención de 1 Año y Respaldo:**
   - Función para respaldar/descargar base de datos (JSON/CSV) y depurar transacciones con más de 1 año de antigüedad.

---

## 2. Cambios Técnicos Paso a Paso

### Paso 1: Base de Datos en Supabase (Migración SQL)
- Agregar columna `account_number text default ''` a `public.accounts`.
- Crear función PostgreSQL `delete_transactions_older_than_one_year()` para la política de retención anual.

### Paso 2: Capa de Dominio y Repositorios
- Actualizar `Account`:
  ```dart
  class Account {
    const Account({required this.id, required this.name, this.accountNumber = ''});
    final String id;
    final String name;
    final String accountNumber;
  }
  ```
- Actualizar `FinanceRepository` y `SupabaseFinanceRepository`:
  - Modificar creación de cuentas para aceptar `accountNumber`.
  - Crear `getTransactionsForAccount(String accountId)` (filtra por los bolsillos del banco).
  - Crear `getTransactionsForCard(String cardId)` (filtra por tarjeta).
  - Añadir soporte para depuración de movimientos mayores a 1 año.

### Paso 3: Asistente de Configuración Inicial (`OnboardingScreen`)
- Inicializar todas las plantillas y saldos en **$0 COP**.
- Permitir **eliminar tarjetas de crédito** en el borrador con botón de papelera.
- Permitir **añadir y eliminar bancos** con número de cuenta y saldo base fuera de bolsillos.
- Inputs claros para día de corte y fecha límite de pago.

### Paso 4: Vistas de Detalles e Historial
- Crear `BankDetailsDialog`:
  - Botón en cada tarjeta de banco del Dashboard ("Detalles e Historial").
  - Muestra número de cuenta, Saldo total, Saldo fuera de bolsillos y Saldo en bolsillos.
  - Filtro por bolsillo para ver sus movimientos específicos.
  - Botón para exportar historial del banco a CSV.
- Crear `CardDetailsDialog`:
  - Botón en cada tarjeta de crédito del Dashboard ("Detalles e Historial").
  - Muestra día de corte, fecha límite de pago, cupo total, cupo disponible y deuda.
  - Historial de cargos y abonos.
  - Botón para exportar historial de la tarjeta a CSV.

### Paso 5: Renombrado de Nomenclatura
- Cambiar "Cuenta Eje" -> "Cuenta Banco" en:
  - `DashboardScreen`
  - `PocketCrudDialog`
  - `OnboardingScreen`
  - `TransferDialog`, `NlpEntryDialog`, etc.

### Paso 6: Pruebas y Validación (TDD)
- Actualizar y añadir pruebas unitarias en `test/domain/` y de widgets en `test/widget_test.dart`.
- Ejecutar `flutter test` y verificar 100% de éxito.
- Ejecutar `flutter analyze` asegurando cero advertencias.

---

## 3. Verificación
- Abrir onboarding y verificar que todos los campos arrancan en $0 y se pueden añadir/quitar tarjetas y bancos con números de cuenta y fechas de corte/pago.
- Registrar movimientos y verificar que al presionar el botón de historial en un banco se ve el número de cuenta, saldo fuera de bolsillos, saldos en bolsillos y las transacciones correspondientes.
- Verificar que en tarjetas se ve el historial de cargos y abonos.
