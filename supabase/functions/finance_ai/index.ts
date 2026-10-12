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
    pockets?: Array<{ id: string; name: string; account_id?: string; balance?: number }>;
    cards?: Array<{ id: string; name: string; entity?: string; last_four_digits?: string }>;
  };
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

type AiRequest = ParseIntentRequest | ChatCopilotRequest | AuditExpensesRequest;

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
      const { text, catalog } = body;
      const catalogInfo = JSON.stringify(catalog ?? {}, null, 2);

      const systemPrompt = `Eres el Asistente Financiero Inteligente de Colombia para Finanzas Personales.
Tu tarea es analizar frases en lenguaje natural (escritas o dictadas por voz) y clasificarlas en una estructura JSON estricta.
Debes entender perfectamente modismos, jerga financiera colombiana y términos coloquiales:
- "lucas" o "barras" = miles de pesos (ej: "45 barras" = 45000 COP, "50 lucas" = 50000 COP, "media luca" = 500 COP, "10 barras" = 10000 COP).
- "palos" = millones de pesos (ej: "2 palos" = 2000000 COP).
- "tanqueé" / "almorcé" / "compré" / "pagué" = gasto (expense).
- "quincena", "prima", "honorarios", "me entró", "me consignaron" = ingreso (income).
- "pago tc", "abono a la tarjeta", "le metí a la tarjeta" = pago de tarjeta (card_payment).
- "pasar de X a Y", "mover", "transferir" = transferencia (transfer).
- "crea suscripción", "crear suscripción", "suscripción a netflix", "cobro fijo mensual", "pago mensual cada 15", "los 15" = create_recurring.
  * Para suscripciones, extrae en el objeto "recurring":
    - name: nombre del servicio (ej. "Netflix", "Spotify")
    - amount: monto mensual en COP (ej. 45 barras = 45000)
    - day_of_month: día de corte/cobro del mes del 1 al 31 (ej. cada 15 = 15)
    - source_name: cuenta o tarjeta mencionada (ej. "nequi")
    - is_card: boolean si es tarjeta de crédito
- "crea tarjeta", "crear tarjeta", "nueva tarjeta", "alta de tarjeta" = create_card.
- "crea bolsillo", "crear bolsillo", "nuevo bolsillo" = create_pocket.
- "crea cuenta", "crear cuenta", "abrir cuenta" = create_account.

Catálogo actual del usuario (cuentas, bolsillos y tarjetas existentes):
${catalogInfo}

Si el usuario menciona un banco o bolsillo, busca el ID más coincidente en el catálogo actual.
Si es una creación, extrae los datos correspondientes.

Debes responder ÚNICAMENTE con un JSON válido sin markdown ni comillas triples:
{
  "intent_type": "expense" | "income" | "transfer" | "card_payment" | "create_recurring" | "create_card" | "create_pocket" | "create_account",
  "amount": number | null,
  "source_type": "account" | "card" | null,
  "source_id": string | null,
  "source_name": string | null,
  "pocket_id": string | null,
  "pocket_name": string | null,
  "to_pocket_id": string | null,
  "to_pocket_name": string | null,
  "target_card_id": string | null,
  "target_card_name": string | null,
  "description": string,
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

      const systemPrompt = `Eres "Copiloto Financiero IA", un asesor experto en finanzas personales para Colombia.
Tu tono es cálido, conciso, constructivo y muy práctico. Explicas en pesos colombianos (COP).
Tienes acceso a la situación financiera actual del usuario:
${contextString}

Reglas:
1. Responde preguntas sobre sus saldos, patrimonio neto, deudas y capacidad de ahorro.
2. Da sugerencias directas para controlar deudas y evitar intereses en tarjetas de crédito.
3. Si el usuario te pregunta cosas generales de finanzas, responde de manera breve y accionable.
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
