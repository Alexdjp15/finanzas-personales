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
