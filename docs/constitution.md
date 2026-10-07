# Constitución del Proyecto

La presente Constitución establece los principios fundamentales e innegociables que gobiernan todo el ciclo de vida del software en este repositorio. Cualquier sugerencia, propuesta o generación de código que entre en conflicto con estos 6 principios queda automáticamente invalidada.

---

## Principio 1: Stack Dinámico y Autorización Estricta de Dependencias

La tecnología a utilizar (lenguajes de programación, frameworks, librerías, bases de datos) **NO está predefinida en esta plantilla**.
- **Origen de la Verdad:** Antes de planificar o escribir código, el agente debe leer obligatoriamente la especificación activa en `docs/specs/` para identificar el stack tecnológico de este proyecto específico.
- **Detención por Ambigüedad:** Si el stack técnico no está claramente determinado en la especificación, **el agente debe detenerse y preguntarle al usuario** antes de tomar cualquier decisión o generar planes.
- **Regla Estricta de Dependencias:** Queda terminantemente prohibido instalar paquetes, agregar dependencias externas, configurar SDKs o inicializar herramientas de construcción (ej. `npm`, `flutter`, `pip`, `cargo`, `composer`) sin que estén explícitamente autorizados y justificados en el plan aprobado.

---

## Principio 2: La Spec Manda (No Inventar Funciones)

Todo comportamiento, botón, campo, regla o flujo debe originarse en una especificación aprobada dentro de `docs/specs/`.
- **Prohibido asumir requerimientos:** Si la spec no especifica qué ocurre ante un evento o cómo se maneja un caso borde, pregunta al usuario o somete la propuesta en el plan antes de codificar.
- **Cero funciones "por si acaso" (YAGNI):** No añadas utilidades, helpers ni configuraciones futuristas que no formen parte inmediata de la spec en curso.

---

## Principio 3: Lógica Separada de Interfaz y Estructura Agnóstica

La arquitectura debe mantener un desacoplamiento absoluto entre la **lógica de negocio** y la **capa de presentación**:
- La lógica de negocio, validaciones, cálculos, formateo y modelos de datos residen en módulos puros, libres de dependencias directas de la capa visual, DOM o controladores de interfaz.
- La capa de interfaz es responsable únicamente de renderizar datos, capturar eventos de usuario y delegar el procesamiento a la lógica pura.
- **Estructura Base Agnóstica:**
  - `docs/` — Constitución, especificaciones de requerimientos (`docs/specs/`) y arquitectura.
  - **Directorio de código fuente:** (`src/`, `lib/`, `app/`, etc., según el framework o lenguaje acordado en la spec).
  - **Directorio de pruebas:** (`tests/`, `__tests__/`, etc., organizando tests unitarios e integrales).

---

## Principio 4: Tests Obligatorios para Lógica

Ninguna lógica de negocio se considera terminada sin una suite de pruebas unitarias automatizadas:
- Se sigue un enfoque TDD (Test-Driven Development) o test-first siempre que sea posible.
- Todas las pruebas deben pasar con un 100% de éxito (`0 failed tests`) antes de proceder a la integración o entrega.
- Los casos de prueba deben cubrir el camino feliz (happy path), casos límite (edge cases) y escenarios de fallo conocidos.

---

## Principio 5: Integridad de Datos

Los datos son el activo más valioso de la aplicación y deben protegerse rigurosamente:
- **Validación en los límites:** Toda entrada de datos (formularios, respuestas de APIs externas, almacenamiento local o base de datos) debe ser validada exhaustivamente antes de ingresar al sistema.
- **Manejo defensivo y resiliente de errores:** Las excepciones deben ser capturadas, registradas adecuadamente y traducidas en mensajes claros y seguros para el usuario final.
- **Coherencia de estado:** El estado de la aplicación no debe quedar en un estado inconsistente o intermedio ante fallos de red o errores de ejecución.

---

## Principio 6: Idioma (Código en Inglés, Textos en Español)

Para mantener la interoperabilidad global y la coherencia cultural:
- **Código Técnico (Inglés):** Nombres de variables, funciones, clases, tipos, nombres de archivos de código, mensajes de commit, comentarios internos y ramas Git deben redactarse obligatoriamente en **inglés**.
- **Capa Humana y de Usuario (Español):** La interfaz de usuario (etiquetas, botones, mensajes de error, alertas visibles), las especificaciones de requerimientos (`docs/specs/`) y la documentación funcional deben redactarse en **español**.
