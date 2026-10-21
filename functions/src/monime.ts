// Minimal Monime client (https://docs.monime.io) — Sierra Leone payments:
// Orange Money, Afrimoney and cards through one hosted checkout page.
//
// Secrets (set once with the Firebase CLI):
//   firebase functions:secrets:set MONIME_ACCESS_TOKEN
//   firebase functions:secrets:set MONIME_SPACE_ID      (starts with "spc-")
import { defineSecret } from "firebase-functions/params";

export const MONIME_ACCESS_TOKEN = defineSecret("MONIME_ACCESS_TOKEN");
export const MONIME_SPACE_ID = defineSecret("MONIME_SPACE_ID");

const BASE = "https://api.monime.io/v1";
const VERSION = "caph.2025-08-23";

export type SessionStatus = "pending" | "completed" | "cancelled" | "expired";

export interface LineItem {
  name: string;
  amountLeones: number; // unit price in Leones; converted to cents for Monime
  quantity: number;
}

export function monimeConfigured(): boolean {
  try {
    return MONIME_ACCESS_TOKEN.value().length > 0 && MONIME_SPACE_ID.value().startsWith("spc-");
  } catch {
    return false;
  }
}

function headers(idempotencyKey?: string): Record<string, string> {
  const h: Record<string, string> = {
    "Authorization": `Bearer ${MONIME_ACCESS_TOKEN.value()}`,
    "Monime-Space-Id": MONIME_SPACE_ID.value(),
    "Monime-Version": VERSION,
    "Content-Type": "application/json",
  };
  if (idempotencyKey) h["Idempotency-Key"] = idempotencyKey.slice(0, 64);
  return h;
}

/** SLE amounts are sent in the minor unit: Le 1 = 100. */
const toMinor = (leones: number) => Math.round(leones * 100);

export async function createCheckoutSession(opts: {
  reference: string;
  name: string;
  items: LineItem[];
  successUrl: string;
  cancelUrl: string;
  metadata?: Record<string, string>;
}): Promise<{ id: string; redirectUrl: string }> {
  const res = await fetch(`${BASE}/checkout-sessions`, {
    method: "POST",
    headers: headers(opts.reference),
    body: JSON.stringify({
      name: opts.name.slice(0, 150),
      reference: opts.reference,
      successUrl: opts.successUrl,
      cancelUrl: opts.cancelUrl,
      metadata: opts.metadata ?? {},
      lineItems: opts.items.slice(0, 16).map((i) => ({
        type: "custom",
        name: i.name.slice(0, 100),
        price: { currency: "SLE", value: toMinor(i.amountLeones) },
        quantity: i.quantity,
      })),
    }),
  });
  const body = (await res.json().catch(() => ({}))) as {
    success?: boolean;
    result?: { id?: string; redirectUrl?: string };
    messages?: unknown;
  };
  if (!res.ok || !body.result?.id || !body.result.redirectUrl) {
    throw new Error(`Monime checkout failed (${res.status}): ${JSON.stringify(body.messages ?? body)}`);
  }
  return { id: body.result.id, redirectUrl: body.result.redirectUrl };
}

export async function getCheckoutSession(id: string): Promise<{ status: SessionStatus; reference: string | null }> {
  const res = await fetch(`${BASE}/checkout-sessions/${encodeURIComponent(id)}`, { headers: headers() });
  const body = (await res.json().catch(() => ({}))) as {
    result?: { status?: SessionStatus; reference?: string | null };
  };
  if (!res.ok || !body.result?.status) {
    throw new Error(`Monime lookup failed (${res.status})`);
  }
  return { status: body.result.status, reference: body.result.reference ?? null };
}
