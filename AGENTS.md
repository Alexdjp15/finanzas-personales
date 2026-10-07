# AGENTS.md — Reglas y Directrices del Proyecto (Antigravity SDD)

Este repositorio es una plantilla base para desarrollo web profesional gobernado bajo la metodología **Spec-Driven Development (SDD)** con **Google Antigravity**.

---

## 1. Filosofía y Metodología: Spec-Driven Development (SDD)

1. **La Spec es la Fuente de la Verdad:** Jamás se genera ni se altera código de producción sin una especificación técnica aprobada en `docs/specs/` y un plan de implementación validado mediante `/plan`.
2. **Prohibido Adivinar o Inventar Requisitos:** Si una funcionalidad, estado de UI o caso límite no está descrito en la spec, el agente debe detenerse y solicitar aclaración.
3. **Flujo de Trabajo Estricto:**
   - **Fase 1: Especificación:** Redacción y refinamiento de la spec funcional y técnica (incluyendo la definición del stack).
   - **Fase 2: Planificación (`/plan`):** Diseño detallado paso a paso con plan de tests, dependencias justificadas y verificación.
   - **Fase 3: Ejecución TDD:** Pruebas unitarias de la lógica antes de la implementación.
   - **Fase 4: Verificación Visual:** Inspección obligatoria con Chrome DevTools MCP (o herramientas acordes al stack).
   - **Fase 5: Consolidación:** Actualización de `MEMORY.md`.

---

## 2. Stack Tecnológico y Arquitectura Dinámica

- **El Stack es Dinámico:** La tecnología a utilizar (lenguajes, frameworks, librerías, bases de datos) **NO** está predefinida en esta plantilla. Se adapta a las necesidades de cada proyecto.
- **Origen de la Verdad:** Antes de planificar o escribir código, el agente debe leer obligatoriamente la especificación activa (`docs/specs/`) para identificar el stack tecnológico de este proyecto específico. Si el stack no está claro en la spec, **el agente debe detenerse y preguntarle al usuario**.
- **Regla de Dependencias:** Está terminantemente prohibido instalar paquetes, SDKs o inicializar frameworks (ej. `npm install`, `flutter create`, `pip install`, `cargo`, etc.) sin que estén explícitamente autorizados en el plan aprobado.
- **Estructura Base Agnóstica:**
  - `docs/` — Constitución, especificaciones de requerimientos (`docs/specs/`) y arquitectura.
  - **Directorio de código fuente:** (`src/`, `lib/`, `app/`, etc., según las convenciones del framework o lenguaje elegido en la spec).
  - **Directorio de pruebas:** (`tests/`, `__tests__/`, `spec/`, etc., estructurado para pruebas unitarias e integrales).

---

## 3. Convenciones de Código Limpio

1. **Separación Estricta de Responsabilidades (SoC):**
   - La lógica de negocio, cálculos y transformaciones de datos **nunca** deben acoplarse directamente a eventos de interfaz de usuario, DOM o controladores de vista.
   - Crear módulos puros en la capa de lógica/dominio que puedan probarse de forma aislada sin dependencias externas pesadas.
   - La capa de presentación solo consume la lógica e interactúa con la interfaz.
2. **Nomenclatura y Claridad:**
   - Todo el código (variables, funciones, clases, archivos, ramas y commits) se escribe en **inglés**.
   - Los nombres deben revelar intención clara (`calculateInvoiceTotal`, `isUserEligible`, etc.). Evitar abreviaciones crípticas.
3. **Funciones Pequeñas y Puras:**
   - Preferir funciones con un único propósito y efectos secundarios controlados.
4. **Comentarios de Intención:**
   - Los comentarios deben explicar el *porqué* de una decisión no obvia, no el *qué* hace el código evidente.

---

## 4. Reglas Innegociables de Validación

> [!CAUTION]
> **TOLERANCIA CERO A FALLOS:** Está terminantemente prohibido dar por finalizada una tarea o avanzar al siguiente paso si cualquiera de estas condiciones se incumple:

1. **Tests Lógicos en Verde (100% éxito):**
   - Todos los tests unitarios e integraciones lógicas deben ejecutarse y reportar cero errores.
   - Si un test falla, la prioridad absoluta es corregir el código o ajustar la prueba según la spec.
2. **Verificación Visual Obligatoria con Chrome DevTools MCP:**
   - Para cualquier cambio en interfaces web, el agente debe utilizar el servidor MCP `chrome-devtools` para:
     - Renderizar la interfaz y tomar capturas visuales.
     - Inspeccionar la consola del navegador verificando que haya **cero errores de consola** (`console.error` o advertencias graves).
     - Comprobar la respuesta visual ante resoluciones móviles y de escritorio.
3. **Integridad del Estado y Memoria:**
   - Cada ciclo concluido requiere actualizar [MEMORY.md](file:///MEMORY.md) reflejando el nuevo estado, decisiones adoptadas y aprendizajes.
