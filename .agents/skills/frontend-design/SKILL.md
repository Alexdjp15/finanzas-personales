---
name: frontend-design
description: Guidance for distinctive, intentional visual design when building new UI or reshaping an existing one in Flutter and modern web apps. Helps with aesthetic direction, typography, rhythmic spacing, contrast, micro-interactions, and avoiding templated AI defaults.
license: Complete terms in LICENSE.txt
---

# Frontend Design Skill — Adaptación para Flutter & Interfaces Financieras

Esta skill proporciona una guía de diseño visual intencional, distintiva y ergonómica, adaptada de `anthropics/skills/frontend-design` específicamente para el ecosistema **Flutter** y aplicaciones financieras de alta fidelidad.

---

## 1. Filosofía y Punto de Vista de Diseño

Aborda el diseño como un Lead Designer de estudio creando una identidad visual única para un producto financiero personal:
- **Rechazo a lo Genérico (AI Tells):** Evitar fondos neutros sin intención, tarjetas idénticas apiladas sin ritmo visual, gradientes decorativos sin propósito, sombras pesadas o bordes redondeados arbitrarios.
- **Identidad Específica al Dominio:** Una aplicación de finanzas personales debe proyectar confianza, orden contable, serenidad y claridad inmediata. El dinero debe sentirse tangible y comprensible a primera vista.
- **Gastar la audacia en un solo lugar:** El número principal (Patrimonio Neto) y la distinción cromática entre Activos (Cuentas/Bolsillos) y Pasivos (Deuda/Tarjetas) deben ser los protagonistas visuales indiscutibles. El resto de la interfaz debe ser disciplinada, limpia y sobria.

---

## 2. Sistema de Tokens Visuales para Flutter

### 2.1. Paleta de Color e Identidad Financiera
Evitar los verdes neón y rojos saturados estridentes que fatigan la vista. Utilizar una escala armónica y contrastada:

| Token | Propósito | Valor Hex / Flutter Color |
|---|---|---|
| `surfaceBase` | Fondo general de la aplicación | `#0B0F19` (Slate oscuro azulado) o `#0D1117` |
| `surfaceCard` | Fondo de tarjetas y contenedores | `#161F30` con borde `#1E293B` (1px) |
| `surfaceOverlay` | Fondos de diálogos modales y hojas | `#1A2234` |
| `primaryAccent` | Acento principal y acciones clave | `#3B82F6` (Azul zafiro / cobalto) |
| `assetPositive` | Activos, saldo a favor, ingresos | `#10B981` (Esmeralda templado) / `#059669` |
| `liabilityNegative`| Deuda, pasivos, gastos | `#F43F5E` (Rosa carmesí) o `#E11D48` |
| `textPrimary` | Títulos y saldos numéricos destacados | `#F8FAFC` (Blanco tiza suave) |
| `textSecondary` | Subtítulos, entidades, etiquetas | `#94A3B8` (Gris pizarra frío) |
| `textMuted` | Fechas secundarias, textos auxiliares | `#64748B` |

### 2.2. Jerarquía Tipográfica y Formato Numérico
- **Saldos Financieros:** El peso visual recae en los números (`FontWeight.w700` o `w800`). Utilizar `letterSpacing: -0.5` para números compactos y legibles (`Formatters.cop`).
- **Escala de Texto en Flutter (`TextTheme`):**
  - **Hero Balance (Patrimonio Neto):** `displaySmall` o `headlineMedium` (28–32sp, semibold/bold, color `#F8FAFC`).
  - **Títulos de Sección / Bancos:** `titleMedium` (16–18sp, `FontWeight.w600`, color `#E2E8F0`).
  - **Saldos Secundarios (Bolsillos / Cupo):** `bodyLarge` (14–15sp, `FontWeight.w600`).
  - **Metadatos y Badges:** `labelSmall` / `labelMedium` (11–12sp, `FontWeight.w500`, color `#94A3B8`).
- **Regla Tipográfica:** Máximo 2 familias o 1 familia bien modulada (ej. `Inter` o la fuente de sistema de Flutter). Prohibido mezclar tamaños y pesos sin una escala armónica definida.

### 2.3. Espaciado Rítmico y Ergonomía
- **Sistema de Espaciado Modular (Base 4/8px):**
  - Márgenes de pantalla: `16px` (móvil) / `24px` a `32px` (escritorio).
  - Espaciado entre tarjetas: `12px` a `16px`.
  - Padding interno de tarjetas: `16px` a `20px`.
  - Separación de elementos atómicos: `8px`.
- **Restricciones de Ancho (Max-Width Constraints):**
  - En interfaces web y de escritorio, el contenido principal debe estar contenido en `BoxConstraints(maxWidth: 960)` o `1100px`, centrado horizontalmente, evitando tarjetas estiradas sin proporción.
  - Los diálogos modales deben tener `BoxConstraints(maxWidth: 520)` y `maxHeight: MediaQuery.sizeOf(context).height * 0.85` envueltos en `SingleChildScrollView` para erradicar cualquier desbordamiento.

---

## 3. Principios de Componentes en Flutter

### 3.1. Tarjetas de Banco y Crédito (Credit & Bank Cards)
- **Cuentas Bancarias:**
  - Acabado sobrio con borde sutil `Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1)`.
  - Indicador claro de saldo total del banco vs. saldo fuera de bolsillos vs. saldo en bolsillos.
  - Los bolsillos dentro del banco deben verse como sub-cápsulas ordenadas con barras de proporción o chips visuales limpios.
- **Tarjetas de Crédito:**
  - Tratamiento visual diferenciado que exprese claramente su naturaleza de pasivo/crédito.
  - Indicador visual de consumo del cupo: barra de progreso sobria con el % utilizado (`debt / creditLimit`).
  - Fechas de corte y fecha límite de pago presentadas como badges estructurados, no como texto plano suelto.

### 3.2. Diálogos Modales y Formularios
- **Estructura Cohesiva:**
  - Encabezado: Título con icono temático, botón de cierre (`IconButton` o cruz) alineado sin desbordar (`Expanded` + `TextOverflow.ellipsis`).
  - Cuerpo: `SingleChildScrollView` con espaciado vertical rítmico (`SizedBox(height: 16)`).
  - Campos de entrada: `InputDecoration` con `filled: true`, color de fondo `#0F172A`, borde sutil y etiquetas claras en `sentence case`.
  - Acciones: Botón principal con peso cromático claro (`ElevatedButton` o `FilledButton`) y botón secundario (`TextButton` o `OutlinedButton`).
- **Feedback Interactivo:**
  - Deshabilitar botones durante operaciones asíncronas mostrando un `SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))` limpio.
  - Mensajes de error contextualmente ubicados bajo el campo o en un banner contextual no invasivo.

---

## 4. Checklist de Auto-Crítica de Diseño
Antes de dar por completado un cambio visual:
1. **¿Hay un elemento protagonista claro?** (El usuario debe entender su situación financiera en 2 segundos).
2. **¿Los contrastes cumplen accesibilidad (WCAG AA)?** Texto sobre fondos oscuros debe tener ratio mínimo de 4.5:1.
3. **¿Se eliminó el "ruido visual" accesorio?** Quitar bordes innecesarios, sombras excesivas o colores redundantes.
4. **¿Se verificó en resoluciones móvil (375x667 / 412x915) y escritorio (1280x800)?**
5. **¿La consola reporta cero errores o advertencias de layout?**
