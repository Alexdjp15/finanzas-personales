# Spec 01: Core App de Finanzas Personales (Flutter + Supabase)

## 1. Contexto y Objetivo
Desarrollar la versión MVP de una aplicación de finanzas personales proactiva y altamente personalizable. El objetivo es gestionar un flujo complejo de dinero que entra a cuentas bancarias centrales (Bancolombia, Nu, Nequi, Davivienda, etc.), permitiendo mantener dinero disponible en la cuenta (fuera de bolsillos) y distribuirlo en "bolsillos" lógicos (*Personal*, *Graficolor*, *Apartamentos*, *Favores*). Además, gestiona pasivos en tarjetas de crédito de forma independiente, procesa pagos recurrentes con alertas tempranas, registra movimientos por procesamiento de lenguaje natural (NLP) y ofrece un historial detallado de movimientos por banco, bolsillo y tarjeta con política de retención anual y respaldo descargable.

## 2. Stack Tecnológico y Dependencias Autorizadas
- **Lenguaje / Framework:** Dart 3.x / Flutter (Web y multiplataforma).
- **Backend / Base de Datos:** Supabase (PostgreSQL para almacenamiento y RLS, GoTrue para Auth, `pg_cron` para jobs automáticos).
- **Gestión de Estado:** `flutter_riverpod`.
- **Dependencias:** `supabase_flutter`, `flutter_riverpod`, `intl`, `csv`.

## 3. Arquitectura Lógica de Cuentas Banco, Bolsillos y Tarjetas
1. **Cuentas Banco (Entidades Financieras):**
   - Representan cuentas en entidades bancarias (ej. Bancolombia, Nequi, Davivienda, Nu).
   - Atributos: Nombre del banco, Número de cuenta (opcional).
   - **Estructura de Saldos del Banco:**
     - **Saldo en Cuenta (Fuera de bolsillos):** Dinero libre en el banco que no ha sido asignado a ningún bolsillo específico (adonde llegan ingresos generales o saldo operativo base).
     - **Saldo en Bolsillos:** Suma de los saldos contenidos en los bolsillos específicos creados por el usuario.
     - **Saldo Total del Banco:** Suma matemática de (Saldo fuera de bolsillos + Saldo en bolsillos).
2. **Bolsillos (Sub-Cuentas Lógicas):**
   - Sub-divisiones con propósito específico dentro de la Cuenta Banco (*Personal*, *Empresa/Graficolor*, *Apartamentos*, *Favores*).
   - Los bolsillos pueden recibir ingresos directos, gastos o transferencias entre bolsillos del mismo banco.
   - Los saldos pueden quedar en negativo por decisión del usuario sin bloquear transacciones.
3. **Tarjetas de Crédito (Pasivos Independientes):**
   - Entidades aisladas. Atributos: Entidad emisora, Nombre/Tipo, Franquicia, Últimos 4 dígitos, Cupo Total, Cupo Disponible, Día de corte (1-31), Día límite de pago (1-31).
   - Se gestionan de forma dinámica (crear, editar, eliminar si no tienen movimientos bloqueantes).
   - Los consumos reducen el cupo disponible sin afectar saldos de cuentas; los abonos descuentan del saldo bancario elegido y restauran el cupo.

## 4. Funcionalidades Core
- **Asistente de Configuración Inicial (Onboarding Limpio):**
   - Al iniciar la cuenta por primera vez, todos los valores inician en **$0 COP** (sin datos de prueba arbitrarios).
   - El usuario puede añadir o quitar Cuentas Banco (con su saldo en cuenta libre y sus bolsillos) y Tarjetas de Crédito (con cupo total, cupo disponible, día de corte y fecha límite de pago).
- **Historial de Movimientos por Banco y por Bolsillo:**
   - Botón directo en la tarjeta de cada banco para ver **Detalles e Historial**:
     - Visualización de número de cuenta, saldo total, saldo fuera de bolsillos y saldo en cada bolsillo.
     - Historial cronológico de transacciones asociadas a la cuenta banco, con selector/filtro para ver todos los movimientos o los de un bolsillo en específico.
- **Historial de Movimientos por Tarjeta de Crédito:**
   - Botón directo en cada tarjeta para ver **Detalles e Historial de TC**:
     - Visualización de cupo total, cupo disponible, deuda actual, día de corte y fecha límite de pago.
     - Historial cronológico de consumos (cargos) y abonos (pagos de TC).
- **Política de Retención y Respaldo de Base de Datos:**
   - El historial de transacciones se mantiene durante un periodo de hasta **1 año (365 días)**.
   - La aplicación permite en cualquier momento **descargar el respaldo completo** de transacciones y saldos en formatos universales (JSON / CSV).
   - Se habilita la depuración de transacciones anteriores a 1 año mediante el Cierre Fiscal / depuración programada, consolidando saldos iniciales del nuevo periodo.
- **Ingreso Rápido por NLP (Frase):**
   - Detección inteligente de monto, operación (+/-), Cuenta Banco / Tarjeta y Bolsillo.
   - Si no se especifica origen, asume la cuenta principal por defecto; si no se especifica bolsillo para una compra con tarjeta, se categoriza en el general.
- **Suscripciones y Pagos Recurrentes:**
   - Programación de cobros periódicos procesados automáticamente mediante `pg_cron` en la base de datos.
- **Centro de Alertas in-app:**
   - Notificaciones a 2 y 1 días de anticipación de fechas límites de pago de tarjetas y suscripciones.

## 5. Criterios de Aceptación (TDD)
- En el onboarding, el estado inicial arranca en $0 COP y permite añadir/quitar bancos y tarjetas con sus días de corte y pago.
- Cada Cuenta Banco expone con precisión su saldo fuera de bolsillos, el saldo acumulado en bolsillos y el saldo total bancario.
- Al pulsar el botón de historial en una Cuenta Banco, se listan sus movimientos con desglose por bolsillo.
- Al pulsar el botón de historial en una Tarjeta de Crédito, se listan sus compras y abonos.
- El usuario puede descargar su base de datos/historial en formato CSV o JSON antes de la depuración anual.