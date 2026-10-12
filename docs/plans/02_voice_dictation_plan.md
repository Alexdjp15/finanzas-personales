# Plan de Implementación — Dictado por Voz (Speech to Text) + NLP Flow

## 1. Objetivo
Integrar la funcionalidad de dictado por voz (Speech to Text) al sistema de ingreso rápido por procesamiento de lenguaje natural (NLP).
El usuario podrá presionar un botón de micrófono (en el Dashboard o dentro del diálogo NLP), hablar en español colombiano (`localeId: 'es_CO'`), y la aplicación transcribirá las palabras en tiempo real e invocará de manera reactiva `NlpParser.parse()` para pre-llenar la operación, monto, entidad de origen y bolsillo sin requerir digitación manual.

---

## 2. Decisiones de Arquitectura y Separación de Responsabilidades (SoC)

| Componente | Capa | Responsabilidad |
|---|---|---|
| `VoiceDictationService` | Dominio / Servicios (`lib/domain/services/voice_dictation_service.dart`) | Contrato abstracto e implementación que encapsula el SDK `speech_to_text`, gestiona inicialización, permisos, eventos de escucha (`onResult`, `onError`, `onStatusChange`), y soporte de fallback seguro. |
| `FakeVoiceDictationService` | Dominio / Testing | Doble de prueba configurable para testear flujos de voz en entornos sin hardware de micrófono (CI/Flutter test). |
| `voiceDictationProvider` | Presentación / Estado (`lib/presentation/providers/voice_dictation_provider.dart`) | StateNotifier/Notifier que expone `VoiceDictationState` (`isListening`, `isAvailable`, `status`, `lastWords`, `errorMessage`). |
| `NlpEntryDialog` | Presentación (`lib/presentation/screens/dialogs/nlp_entry_dialog.dart`) | Botón interactivo de micrófono con animación de escucha activa (rojo/pulso), enlace reactivo al `_phraseController` y auto-ejecución de `_onPhraseChanged()`. |
| `DashboardScreen` | Presentación (`lib/presentation/screens/dashboard_screen.dart`) | Botón de acceso rápido "Dictar por Voz" en el Command Bar superior para abrir el diálogo e iniciar la escucha de inmediato. |

---

## 3. Manejo de Casos Límite y Fallbacks

1. **Denegación de Permisos de Micrófono:** Notificación amigable vía SnackBar / Banner sin romper la UI ("Permiso de micrófono denegado. Puedes escribir la frase manualmente").
2. **Navegador sin Web Speech API:** Detección de `isAvailable == false` y deshabilitación elegante del botón de micrófono con tooltip explicativo.
3. **Pausas y Silencio:** El servicio finaliza la escucha automáticamente tras el timeout o pausa de silencio y procesa el resultado final con `NlpParser`.
4. **Cancelación Manual:** El usuario puede volver a presionar el botón de micrófono en cualquier momento para detener la escucha o continuar editando el texto reconocido.

---

## 4. Plan de Pruebas y Criterios de Aceptación (SDD)

1. **Tests Unitarios de Dominio y Servicio:**
   - Inicialización, transición de estados (`ready`, `listening`, `stopped`, `error`).
   - Emisión de palabras parciales y finales.
   - Manejo de excepciones y códigos de error (`error_permission`, `error_speech_timeout`).
2. **Tests de Widget:**
   - `NlpEntryDialog` muestra el botón de micrófono.
   - Al recibir transcripción de voz (ej. `"gasto almuerzo 25000"` o `"pago tc bancolombia 150000"`), actualiza el campo de texto y auto-completa los campos de confirmación.
   - El botón en Dashboard abre el diálogo e inicia escucha.
3. **Cero Advertencias y Cero Errores:**
   - `flutter analyze` con 0 issues.
   - `flutter test` con 100% de tests pasando en verde.
