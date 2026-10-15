// Supabase Edge Function: finance_ai
// Powered by Google AI Studio (Gemini Flash & Flash-Lite)
// Supports: parse_intent, chat_copilot, audit_expenses

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ParseIntentRequest {
  action: "parse_intent";
  text: string;
  catalog?: {
    accounts?: Array<{ id: string; name: string }>;
    pockets?: Array<{ id: string; name: string; account_id?: string; bank_account_id?: string; balance?: number }>;
    cards?: Array<{ id: string; name: string; entity?: string; last_four_digits?: string }>;
  };
  available_accounts?: Array<{ id: string; name: string }>;
  available_pockets?: Array<{ id: string; name: string; account_id?: string; bank_account_id?: string }>;
}

interface ChatCopilotRequest {
  action: "chat_copilot";
  message: string;
  history?: Array<{ role: "user" | "model"; text: string }>;
  financial_context?: {
    net_worth?: number;
    total_assets?: number;
    total_debt?: number;
    accounts?: Array<{ name: string; balance?: number }>;
    pockets?: Array<{ name: string; balance: number }>;
    cards?: Array<{ name: string; entity: string; debt: number; available: number }>;
    recent_transactions?: Array<{ description: string; amount: number; type: string; date: string }>;
  };
}

interface AuditExpensesRequest {
  action: "audit_expenses";
  transactions: Array<{ description: string; amount: number; type: string; date: string }>;
  pockets?: Array<{ name: string; balance: number }>;
  cards?: Array<{ name: string; debt: number; limit: number }>;
}

interface ParseReceiptRequest {
  action: "parse_receipt";
  image_base64: string;
  mime_type?: string;
  available_accounts?: Array<{ id: string; name: string }>;
  available_pockets?: Array<{ id: string; name: string; account_id?: string; bank_account_id?: string }>;
}

interface WebhookIngestRequest {
  action?: "webhook_ingest";
  raw_text: string;
  user_id?: string;
  source?: string;
}

type AiRequest = ParseIntentRequest | ChatCopilotRequest | AuditExpensesRequest | ParseReceiptRequest | WebhookIngestRequest;

async function callGemini(payload: Record<string, unknown>, apiKey: string): Promise<Record<string, unknown>> {
  const preferredModel = (Deno.env.get("GEMINI_MODEL") || "gemini-2.0-flash").trim().replace(/^models\//, "");

  // Model candidates with automatic fallback in case of deprecation (404), overload (503), or quota limits (429)
  const candidateModels = [
    preferredModel,
    "gemini-2.0-flash",
    "gemini-flash-latest",
    "gemini-3.5-flash-lite",
    "gemini-flash-lite-latest",
    "gemini-3.5-flash",
    "gemini-3.8-flash",
  ].filter((v, idx, arr) => arr.indexOf(v) === idx);

  let lastError = "";

  for (const model of candidateModels) {
    const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    try {
      const res = await fetch(apiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        return await res.json();
      }

      const errText = await res.text();
      lastError = `[${model}] HTTP ${res.status}: ${errText}`;

      // If 404 (model retired), 503 (high demand), or 429 (rate-limited / quota), try the next candidate model
      if (res.status === 404 || res.status === 503 || res.status === 429) {
        console.warn(`Model ${model} returned status ${res.status}, falling back to alternative model...`);
        continue;
      } else {
        throw new Error(`Gemini API Error (${res.status}): ${errText}`);
      }
    } catch (e: any) {
      if (e.message?.startsWith("Gemini API Error")) throw e;
      lastError = e.message || String(e);
    }
  }

  throw new Error(`Todos los modelos de Gemini fallaron. Último error: ${lastError}`);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({
          error: "GEMINI_API_KEY no está configurada en los secretos de Supabase.",
          fallback: true,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body: AiRequest = await req.json();
    const action = body.action;

    if (action === "parse_intent") {
      const { text, catalog, available_accounts, available_pockets } = body as ParseIntentRequest;
      const accountsList = available_accounts || catalog?.accounts || [];
      const pocketsList = available_pockets || catalog?.pockets || [];
      const cardsList = catalog?.cards || [];
      const catalogInfo = JSON.stringify({
        available_accounts: accountsList,
        available_pockets: pocketsList,
        cards: cardsList,
      }, null, 2);

      const systemPrompt = `Eres el Asistente Financiero Inteligente de Colombia para Finanzas Personales.
Tu tarea es analizar frases en lenguaje natural (escritas o dictadas por voz) y clasificarlas en una estructura JSON estricta.
Debes entender perfectamente modismos, jerga financiera colombiana y términos coloquiales:
- "lucas" o "barras" = miles de pesos (ej: "45 barras" = 45000 COP, "50 lucas" = 50000 COP, "media luca" = 500 COP, "10 barras" = 10000 COP).
- "mil" o "k" = miles de pesos (ej: "15 mil" = 15000 COP).
- "palos" = millones de pesos (ej: "2 palos" = 2000000 COP).
- REGLAS ESTRICTAS DE DIRECCIONALIDAD BANCARIA EN COLOMBIA (Ingreso vs Gasto):
  * INGRESOS (intent_type: "income"):
    Frases que denotan dinero recibido o entrante: "me transfirieron", "te transfirieron", "recibiste", "te llegó", "te enviaron", "abono a tu cuenta", "recepción de transferencia", "consignación recibida", "me consignaron", "me pagaron", "me entró", "quincena", "prima", "honorarios".
    -> REGLA DE ORO OBLIGATORIA: Frases como "me transfirieron 25.000 pesos a la cuenta de Bancolombia Carlos Vives" DEBEN clasificarse como intent_type: "income" hacia la cuenta mencionada (Bancolombia), con amount: 25000 y description: "Carlos Vives" (el remitente/nota).
  * GASTOS (intent_type: "expense"):
    Frases que denotan dinero saliente o compras: "transferiste a", "enviaste a", "pagaste", "compraste", "compra por", "débito por", "retiro cajero", "tanqueé", "almorcé".
- "pago tc", "abono a la tarjeta", "le metí a la tarjeta" = pago de tarjeta (card_payment).
- "pasar de X a Y", "mover", "transferir de A a B" = transferencia interna (transfer).
- "crea suscripción", "crear suscripción", "suscripción a netflix", "cobro fijo mensual", "pago mensual cada 15", "los 15", "recuérdame pagar", "recuerdame pagar", "recordar recibo", "factura del agua", "recibo del agua", "factura de la luz", "energía", "energia", "gas", "internet", "arriendo", "servicios públicos" = create_recurring.
  * Para suscripciones, cobros fijos y recordatorios de servicios públicos:
    - Regla de negocio de monto variable: Si el usuario NO menciona un valor monetario en la frase, asigna amount: 0 en el objeto recurring (y en la raíz) y clasifícalo como recordatorio recurrente de monto variable sin lanzar error.
    - name: nombre del servicio, recibo o cobro (ej. "Factura del agua", "Energía", "Internet", "Netflix", "Arriendo", "Spotify")
    - amount: monto mensual en COP, o 0 si no se mencionó ningún valor
    - day_of_month: día de cobro o corte del 1 al 31 (ej: "los 10" -> 10, "cada 15" -> 15). Si no se menciona día, asignar 1 por defecto.
    - source_name: cuenta o tarjeta mencionada (ej. "nequi", "bancolombia") o null si no se mencionó
    - is_card: boolean si es tarjeta de crédito
- "crea tarjeta", "crear tarjeta", "nueva tarjeta", "alta de tarjeta" = create_card.
- "crea bolsillo", "crear bolsillo", "nuevo bolsillo" = create_pocket.
- "crea cuenta", "crear cuenta", "abrir cuenta" = create_account.

Cuentas y bolsillos disponibles del usuario actual:
${catalogInfo}

REGLAS DE EMPAREJAMIENTO DE CUENTAS Y BOLSILLOS:
1. Compara nombres de cuentas y bolsillos ignorando mayúsculas/minúsculas, tildes y preposiciones o conectores ("en el bolsillo", "desde el bolsillo", "del bolsillo", "de bolsillo", "bolsillo", "desde la cuenta", "en la cuenta", "cuenta", "por", "en", "desde", "con", "a").
2. Si el usuario dice "me gasté 15 mil en almuerzo desde nequi bolsillo personal", mapea con máxima precisión:
   - operation / intent_type: "expense"
   - amount: 15000
   - bank_account / source_name: "Nequi"
   - source_id: id correspondiente de la cuenta Nequi en available_accounts
   - source_type: "account"
   - pocket / pocket_name: "Personal"
   - pocket_id: id correspondiente del bolsillo Personal en available_pockets
   - note / description: "Almuerzo"
3. Si el usuario menciona un banco o bolsillo existente, enlaza siempre su source_id y pocket_id correspondientes desde el catálogo.

Debes responder ÚNICAMENTE con un JSON válido sin markdown ni comillas triples:
{
  "intent_type": "expense" | "income" | "transfer" | "card_payment" | "create_recurring" | "create_card" | "create_pocket" | "create_account",
  "operation": "expense" | "income" | "transfer" | "card_payment" | "create_recurring" | "create_card" | "create_pocket" | "create_account",
  "amount": number | null,
  "source_type": "account" | "card" | null,
  "source_id": string | null,
  "source_name": string | null,
  "bank_account": string | null,
  "pocket_id": string | null,
  "pocket_name": string | null,
  "pocket": string | null,
  "to_pocket_id": string | null,
  "to_pocket_name": string | null,
  "target_card_id": string | null,
  "target_card_name": string | null,
  "description": string,
  "note": string,
  "recurring": {
    "name": string,
    "amount": number,
    "day_of_month": number,
    "source_name": string | null,
    "source_id": string | null,
    "is_card": boolean
  } | null,
  "card": {
    "name": string,
    "entity": string,
    "credit_limit": number,
    "cut_off_day": number,
    "payment_due_day": number,
    "franchise": string,
    "last_four_digits": string
  } | null,
  "pocket": {
    "name": string,
    "account_id": string | null,
    "account_name": string | null,
    "initial_balance": number
  } | null,
  "account": {
    "name": string,
    "account_number": string,
    "initial_balance": number
  } | null
}`;

      const geminiJson: any = await callGemini({
        contents: [
          {
            role: "user",
            parts: [{ text: `Entrada del usuario: "${text}"` }],
          },
        ],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      }, apiKey);

      const candidate = geminiJson.candidates?.[0];
      const parts = candidate?.content?.parts ?? [];
      const rawText = parts.map((p: any) => p.text ?? "").join("").trim() || "{}";
      const cleanJson = rawText.replace(/```json/gi, "").replace(/```/g, "").trim();
      const parsedData = JSON.parse(cleanJson);

      return new Response(JSON.stringify({ success: true, intent: parsedData, is_ai: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "chat_copilot") {
      const { message, history, financial_context } = body;
      const contextString = JSON.stringify(financial_context ?? {}, null, 2);

      const systemPrompt = `Eres "Sof.IA", una asesora financiera personal, cercana, estratégica y experta en finanzas personales para Colombia.
Tu tono es cálido, empático, conciso, constructivo y muy práctico. Explicas con claridad en pesos colombianos (COP) adaptándote a la jerga y realidad económica colombiana.
Tienes acceso a la situación financiera actual del usuario:
${contextString}

Reglas:
1. Responde preguntas sobre sus saldos, patrimonio neto, deudas y capacidad de ahorro con consejos prácticos y cercanos.
2. Da sugerencias directas y estratégicas para controlar deudas, gestionar bolsillos y evitar intereses en tarjetas de crédito.
3. Si el usuario te pregunta dudas financieras cotidianas en Colombia, responde de manera breve, accionable y motivadora.
4. Mantén las respuestas claras, completas y estructuradas (2 a 4 párrafos cortos o viñetas concisas). No dejes ideas truncadas o inconclusas.`;

      const contents = [];
      if (history && history.length > 0) {
        for (const item of history) {
          contents.push({
            role: item.role === "model" ? "model" : "user",
            parts: [{ text: item.text }],
          });
        }
      }
      contents.push({
        role: "user",
        parts: [{ text: message }],
      });

      const geminiJson: any = await callGemini({
        contents,
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 2048,
        },
      }, apiKey);

      const candidate = geminiJson.candidates?.[0];
      const parts = candidate?.content?.parts ?? [];
      const reply = parts.map((p: any) => p.text ?? "").join("").trim() || "No pude generar una respuesta.";

      return new Response(JSON.stringify({ success: true, reply, is_ai: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "audit_expenses") {
      const { transactions, pockets, cards } = body;

      const systemPrompt = `Eres un Auditor Forense de Finanzas Personales especializado en Colombia.
Analiza la lista de transacciones proporcionada para detectar:
1. "Gastos Hormiga": Gastos pequeños y recurrentes menores a $20.000 COP (cafés, snacks, domicilios cortos, propinas, suscripciones chicas). Calcula cuánto suman en total y qué porcentaje representan.
2. "Posibles Cobros Duplicados": Transacciones del mismo monto en fechas muy cercanas o el mismo día.
3. "Fugas de Liquidez": Gastos no esenciales que debilitan los bolsillos.
4. "Plan de Optimización": 3 consejos muy concretos para ahorrar este mes.

Responde ÚNICAMENTE en JSON válido:
{
  "total_analyzed_expenses": number,
  "ant_expenses_total": number,
  "ant_expenses_count": number,
  "ant_expenses_items": [
    { "description": string, "amount": number, "date": string }
  ],
  "potential_duplicates": [
    { "description": string, "amount": number, "dates": string[], "note": string }
  ],
  "liquidity_leaks": [
    { "category": string, "total_impact": number, "recommendation": string }
  ],
  "actionable_tips": [
    string
  ],
  "summary_text": string
}`;

      const dataPayload = JSON.stringify({ transactions, pockets, cards }, null, 2);

      const geminiJson: any = await callGemini({
        contents: [
          {
            role: "user",
            parts: [{ text: `Datos para auditoría:\n${dataPayload}` }],
          },
        ],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      }, apiKey);

      const candidate = geminiJson.candidates?.[0];
      const parts = candidate?.content?.parts ?? [];
      const rawText = parts.map((p: any) => p.text ?? "").join("").trim() || "{}";
      const cleanJson = rawText.replace(/```json/gi, "").replace(/```/g, "").trim();
      const auditResult = JSON.parse(cleanJson);

      return new Response(JSON.stringify({ success: true, audit: auditResult, is_ai: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "parse_receipt") {
      const { image_base64, mime_type, available_accounts, available_pockets } = body as ParseReceiptRequest;
      if (!image_base64) {
        return new Response(JSON.stringify({ error: "No se proporcionó 'image_base64' para analizar." }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Clean prefix if data URI was provided
      const cleanBase64 = image_base64.replace(/^data:[a-zA-Z0-9\/+-]+;base64,/, "").trim();
      const resolvedMime = (mime_type || "image/jpeg").toLowerCase();

      const userContextInfo = [];
      if (available_accounts && available_accounts.length > 0) {
        userContextInfo.push(`Cuentas disponibles del usuario:\n${JSON.stringify(available_accounts, null, 2)}`);
      }
      if (available_pockets && available_pockets.length > 0) {
        userContextInfo.push(`Bolsillos disponibles del usuario:\n${JSON.stringify(available_pockets, null, 2)}`);
      }
      const contextSection = userContextInfo.length > 0 ? `\n\nContexto del usuario:\n${userContextInfo.join("\n\n")}\nUsa las cuentas o bolsillos del usuario si coinciden con la entidad detectada.` : "";

      const systemPrompt = `Eres Sof.IA, experta en visión artificial y procesamiento forense de comprobantes bancarios en Colombia.
Analiza la imagen adjunta correspondiente a un comprobante o captura de pantalla de transferencia bancaria (Nequi, Bancolombia, Daviplata, Dale, Nu, Transfiya, Lulo, Davivienda, etc.).${contextSection}
Reglas de extracción:
1. Detecta la entidad bancaria o billetera emisora por los colores, tipografía y logotipo (ej: Nequi = fucsia/morado, Bancolombia = franja amarilla/blanca/negra, Daviplata = rojo casita, Nu = morado).
2. Discrimina con total exactitud la DIRECCIONALIDAD:
   - "expense": si el comprobante indica salida de dinero ("Envío exitoso", "Transferencia exitosa", "Pagaste", "Enviaste a", "Comprobante de envío", "Débito").
   - "income": si el comprobante indica entrada de dinero ("Te transfirieron", "Plata recibida", "Comprobante de recepción", "Te llegó plata", "Recibiste").
3. Monto exacto (amount): número entero en COP sin puntuación ni símbolos de moneda.
4. Remitente o destinatario (recipient_or_sender): nombre o número de teléfono/cuenta de la contraparte si es legible.
5. Fecha (date): formato YYYY-MM-DD o texto visible.
6. Código de referencia o comprobante (reference_code): número de referencia de la transacción.
7. Descripción (description): resumen breve del movimiento (ej. "Envío Nequi a Juan Perez" o "Recepción de Pedro").
8. PRIVACIDAD: La imagen solo es procesada en memoria efímera por este modelo y jamás se almacena en base de datos ni storage.

Responde ÚNICAMENTE en JSON válido sin markdown ni comillas triples:
{
  "operation": "expense" | "income",
  "amount": number,
  "bank_name": string,
  "recipient_or_sender": string | null,
  "date": string | null,
  "reference_code": string | null,
  "description": string
}`;

      const geminiJson: any = await callGemini({
        contents: [
          {
            role: "user",
            parts: [
              {
                inlineData: {
                  mimeType: resolvedMime,
                  data: cleanBase64,
                },
              },
              {
                text: "Analiza el comprobante bancario colombiano adjunto y devuelve los datos estructurados.",
              },
            ],
          },
        ],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      }, apiKey);

      const candidate = geminiJson.candidates?.[0];
      const parts = candidate?.content?.parts ?? [];
      const rawText = parts.map((p: any) => p.text ?? "").join("").trim() || "{}";
      const cleanJson = rawText.replace(/```json/gi, "").replace(/```/g, "").trim();
      const receiptData = JSON.parse(cleanJson);

      return new Response(JSON.stringify({ success: true, receipt: receiptData, is_ai: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "webhook_ingest" || (!action && (body as any).raw_text)) {
      const { raw_text, user_id, source } = body as WebhookIngestRequest;
      const textToAnalyze = (raw_text || "").trim();

      if (!textToAnalyze) {
        return new Response(JSON.stringify({ error: "Falta 'raw_text' para el webhook." }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const systemPrompt = `Eres Sof.IA, el Asistente Financiero Inteligente de Colombia para Finanzas Personales.
Tu tarea es analizar textos de notificaciones automáticas (SMS bancarios de Bancolombia, Davivienda, Nequi, Daviplata o notificaciones de Apple Pay / Google Wallet).
Clasifica con exactitud la transacción en JSON:
- INGRESOS (intent_type: "income"): "me transfirieron", "te transfirieron", "recibiste", "te llegó", "te enviaron", "abono a tu cuenta", "consignación recibida".
- GASTOS (intent_type: "expense"): "compra por", "pagaste", "enviaste a", "débito por", "retiro cajero", "transferiste a".
- Extrae: amount, source_name (banco/tarjeta), description (comercio o remitente/destinatario).

Responde ÚNICAMENTE en JSON válido:
{
  "intent_type": "expense" | "income" | "transfer" | "card_payment",
  "amount": number | null,
  "source_name": string | null,
  "source_type": "account" | "card" | null,
  "description": string,
  "date": string | null
}`;

      const geminiJson: any = await callGemini({
        contents: [
          {
            role: "user",
            parts: [{ text: `Texto de notificación recibido: "${textToAnalyze}"` }],
          },
        ],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      }, apiKey);

      const candidate = geminiJson.candidates?.[0];
      const parts = candidate?.content?.parts ?? [];
      const rawText = parts.map((p: any) => p.text ?? "").join("").trim() || "{}";
      const cleanJson = rawText.replace(/```json/gi, "").replace(/```/g, "").trim();
      const parsedData = JSON.parse(cleanJson);

      return new Response(
        JSON.stringify({
          success: true,
          action: "webhook_ingest",
          source: source || "shortcut",
          user_id: user_id || null,
          raw_text: textToAnalyze,
          intent: parsedData,
          is_ai: true,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ error: `Acción '${action}' no reconocida.` }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    return new Response(
      JSON.stringify({
        error: error.message || "Error interno al procesar con IA.",
        fallback: true,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
