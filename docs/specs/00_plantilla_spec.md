# Spec 00: [Título de la Funcionalidad o Proyecto]

## 1. Contexto y Objetivo
Descripción concisa del problema que resuelve y el objetivo principal de este desarrollo.

## 2. Stack Tecnológico y Dependencias Autorizadas
> [!IMPORTANT]
> El stack es dinámico y debe definirse aquí para cada proyecto. Si esta sección está vacía o ambigua, el agente se detendrá y solicitará aclaración antes de continuar.

- **Lenguaje / Runtime:** (ej. JavaScript ES Modules, TypeScript, Python 3.12, Dart, etc.)
- **Framework / Plataforma:** (ej. Vanilla HTML5/CSS3, Next.js, Astro, Flutter, Fastify, etc.)
- **Base de Datos / Persistencia:** (ej. Supabase, PostgreSQL local, LocalStorage, etc.)
- **Dependencias y Paquetes a Instalar:**
  - *Ninguna por defecto.* Enumerar cada paquete y justificar su inclusión.
- **Estructura de Directorios Adoptada:**
  - Código Fuente: `src/` (o `lib/`, `app/`)
  - Pruebas Automatizadas: `tests/` (o `__tests__/`)

## 3. Requerimientos Funcionales
- [ ] Requerimiento 1 (ej: Flujo principal del usuario)
- [ ] Requerimiento 2 (ej: Validación y manejo de datos)
- [ ] Requerimiento 3 (ej: Estados de carga, error y confirmación)

## 4. Lógica de Negocio (Módulos Puros y Aislados)
- **Módulo / Servicio:** `src/logic/[module_name].[ext]` (o ruta equivalente según stack)
- **Responsabilidad:** (Detallar cálculos, transformaciones y reglas de negocio desacopladas de la UI).
- **Casos límite (Edge Cases):** (Entradas vacías, desbordamientos, caídas de red, formatos inesperados).

## 5. Requerimientos de Interfaz y UX (si aplica)
- **Componentes o Vistas:** (Layout, navegación, modales, alertas).
- **Diseño Responsive:** (Comportamiento en escritorio vs. móvil / tableta).
- **Tokens de Diseño:** (Variables de color, tipografía, espaciado).

## 6. Criterios de Aceptación y Validación (Innegociables)
- [ ] 100% de tests unitarios pasando en la suite de pruebas.
- [ ] Verificación visual obligatoria (Chrome DevTools MCP para web o inspección equivalente).
- [ ] Cero errores de consola / advertencias no resueltas.
- [ ] Actualización obligatoria de [MEMORY.md](file:///MEMORY.md).
