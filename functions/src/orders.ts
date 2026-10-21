import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type DocumentReference,
  type Transaction,
} from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { DELIVERY_FEES, MAX_ITEMS_PER_CHECKOUT, PAYMENT_WINDOW_MINUTES } from "./catalog";
import {
  MONIME_ACCESS_TOKEN,
  MONIME_SPACE_ID,
  createCheckoutSession,
  getCheckoutSession,
  monimeConfigured,
} from "./monime";
import { REGION } from "./region";

const db = () => getFirestore();

type OrderStatus = "pending" | "confirmed" | "shipped" | "delivered" | "cancelled";

interface OrderItem {
  productId: string;
  title: string;
  price: number;
  quantity: number;
  categoryId: string;
  image: string | null;
}

interface OrderDoc {
  checkoutId: string;
  buyerId: string;
  buyerName: string;
  sellerId: string;
  sellerName: string;
  items: OrderItem[];
  subtotal: number;
  deliveryFee: number;
  total: number;
  paymentMethod: "online" | "cod";
  paymentStatus: "unpaid" | "paid" | "cod" | "refund_due";
  status: OrderStatus;
  address: string;
  city: string;
  phone: string;
  note: string;
  cancelledBy?: "buyer" | "seller" | "system";
  createdAt: FieldValue | Timestamp;
  updatedAt: FieldValue | Timestamp;
}

function requireUid(req: CallableRequest<unknown>): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in first.");
  return uid;
}

const str = (v: unknown, min: number, max: number, field: string): string => {
  if (typeof v !== "string") throw new HttpsError("invalid-argument", `${field} is required.`);
  const t = v.trim();
  if (t.length < min || t.length > max) throw new HttpsError("invalid-argument", `${field} is not valid.`);
  return t;
};

const round2 = (n: number) => Math.round(n * 100) / 100;

function hostingUrl(path: string): string {
  const project = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "";
  return `https://${project}.web.app${path}`;
}

/** Puts stock back for the given items (used on cancel / payment expiry). */
async function restoreStock(tx: Transaction, items: OrderItem[]) {
  const refs = items.map((i) => db().collection("products").doc(i.productId));
  const snaps = await Promise.all(refs.map((r) => tx.get(r)));
  snaps.forEach((snap, idx) => {
    if (!snap.exists) return;
    const data = snap.data()!;
    const update: Record<string, unknown> = {
      stock: FieldValue.increment(items[idx].quantity),
      updatedAt: FieldValue.serverTimestamp(),
    };
    // Sold out because of this order? Make it available again.
    if (data.status === "sold" && (data.stock ?? 0) <= 0) update.status = "active";
    tx.update(refs[idx], update);
  });
}

// ---------------------------------------------------------------------------
// placeOrder: validates the cart against live prices and stock, reserves stock
// and creates one order per seller. Online payments get a Monime checkout page.
// ---------------------------------------------------------------------------
export const placeOrder = onCall(
  { region: REGION, secrets: [MONIME_ACCESS_TOKEN, MONIME_SPACE_ID], enforceAppCheck: false },
  async (req) => {
    const uid = requireUid(req);
    const data = (req.data ?? {}) as Record<string, unknown>;

    const method = data.paymentMethod === "online" ? "online" : data.paymentMethod === "cod" ? "cod" : null;
    if (!method) throw new HttpsError("invalid-argument", "Choose a payment method.");
    if (method === "online" && !monimeConfigured()) {
      throw new HttpsError("failed-precondition", "Online payment isn't available yet. Please choose Cash on Delivery.");
    }
    const city = str(data.city, 2, 40, "Town");
    if (!(city in DELIVERY_FEES)) throw new HttpsError("invalid-argument", "We don't deliver to that town yet.");
    const address = str(data.address, 5, 300, "Address");
    const phone = str(data.phone, 8, 20, "Phone number");
    const note = typeof data.note === "string" ? data.note.trim().slice(0, 400) : "";

    const rawItems = Array.isArray(data.items) ? data.items : [];
    if (rawItems.length === 0) throw new HttpsError("invalid-argument", "Your cart is empty.");
    if (rawItems.length > MAX_ITEMS_PER_CHECKOUT) throw new HttpsError("invalid-argument", "Too many items in one order.");
    const wanted = new Map<string, number>();
    for (const it of rawItems as Array<Record<string, unknown>>) {
      const id = typeof it.productId === "string" ? it.productId : "";
      const q = Number(it.quantity);
      if (!id || !Number.isInteger(q) || q < 1 || q > 1000) throw new HttpsError("invalid-argument", "Invalid cart item.");
      wanted.set(id, (wanted.get(id) ?? 0) + q);
    }

    const buyerSnap = await db().collection("users").doc(uid).get();
    if (!buyerSnap.exists) throw new HttpsError("failed-precondition", "Please complete your profile first.");
    const buyerName = String(buyerSnap.data()!.name ?? "Buyer");

    const checkoutRef = db().collection("checkouts").doc();
    const fee = DELIVERY_FEES[city];

    const result = await db().runTransaction(async (tx) => {
      const ids = [...wanted.keys()];
      const refs = ids.map((id) => db().collection("products").doc(id));
      const snaps = await tx.getAll(...refs);

      const bySeller = new Map<string, { sellerName: string; items: OrderItem[] }>();
      snaps.forEach((snap, idx) => {
        const qty = wanted.get(ids[idx])!;
        if (!snap.exists) throw new HttpsError("not-found", "An item in your cart was removed by the seller.");
        const p = snap.data()!;
        if (p.status !== "active") throw new HttpsError("failed-precondition", `"${p.title}" is no longer available.`);
        if ((p.stock ?? 0) < qty) {
          throw new HttpsError("failed-precondition", `Only ${p.stock ?? 0} of "${p.title}" left. Please update your cart.`);
        }
        if (p.sellerId === uid) throw new HttpsError("failed-precondition", "You can't buy your own listing.");

        const left = (p.stock ?? 0) - qty;
        tx.update(refs[idx], {
          stock: FieldValue.increment(-qty),
          ...(left <= 0 ? { status: "sold" } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        });

        const group = bySeller.get(p.sellerId) ?? { sellerName: String(p.sellerName ?? ""), items: [] };
        group.items.push({
          productId: snap.id,
          title: String(p.title),
          price: Number(p.price),
          quantity: qty,
          categoryId: String(p.categoryId ?? "other"),
          image: Array.isArray(p.images) && p.images.length > 0 ? String(p.images[0]) : null,
        });
        bySeller.set(p.sellerId, group);
      });

      const orderIds: string[] = [];
      let grandTotal = 0;
      for (const [sellerId, g] of bySeller) {
        const subtotal = round2(g.items.reduce((s, i) => s + i.price * i.quantity, 0));
        const total = round2(subtotal + fee);
        grandTotal += total;
        const ref = db().collection("orders").doc();
        const order: OrderDoc = {
          checkoutId: checkoutRef.id,
          buyerId: uid,
          buyerName,
          sellerId,
          sellerName: g.sellerName,
          items: g.items,
          subtotal,
          deliveryFee: fee,
          total,
          paymentMethod: method,
          paymentStatus: method === "cod" ? "cod" : "unpaid",
          status: "pending",
          address,
          city,
          phone,
          note,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        tx.set(ref, order);
        orderIds.push(ref.id);
      }

      grandTotal = round2(grandTotal);
      tx.set(checkoutRef, {
        buyerId: uid,
        orderIds,
        total: grandTotal,
        paymentMethod: method,
        status: method === "cod" ? "cod" : "awaiting_payment",
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(Date.now() + PAYMENT_WINDOW_MINUTES * 60_000),
      });
      return { orderIds, total: grandTotal, groups: [...bySeller.values()] };
    });

    if (method === "cod") {
      return { checkoutId: checkoutRef.id, orderIds: result.orderIds, total: result.total, paymentUrl: null };
    }

    // Online payment: create the Monime hosted checkout page.
    try {
      const allItems = result.groups.flatMap((g) => g.items);
      const deliveryTotal = round2(fee * result.groups.length);
      const lineItems =
        allItems.length <= 15
          ? [
              ...allItems.map((i) => ({ name: i.title, amountLeones: i.price, quantity: i.quantity })),
              { name: `Delivery to ${city}`, amountLeones: deliveryTotal, quantity: 1 },
            ]
          : [{ name: `JDMart order (${allItems.length} items)`, amountLeones: result.total, quantity: 1 }];
      const session = await createCheckoutSession({
        reference: checkoutRef.id,
        name: "JDMart order",
        items: lineItems,
        successUrl: hostingUrl(`/payment/success.html?c=${checkoutRef.id}`),
        cancelUrl: hostingUrl(`/payment/cancel.html?c=${checkoutRef.id}`),
        metadata: { checkoutId: checkoutRef.id, buyerId: uid },
      });
      await checkoutRef.update({ monimeSessionId: session.id, redirectUrl: session.redirectUrl });
      return {
        checkoutId: checkoutRef.id,
        orderIds: result.orderIds,
        total: result.total,
        paymentUrl: session.redirectUrl,
      };
    } catch (e) {
      logger.error("Monime checkout creation failed", e);
      await expireCheckout(checkoutRef.id, "payment_setup_failed");
      throw new HttpsError("unavailable", "Couldn't start the payment. Please try again or choose Cash on Delivery.");
    }
  },
);

// ---------------------------------------------------------------------------
// Payment confirmation (called by the app, the webhook and the scheduler).
// We never trust the client: the status always comes from Monime's API.
// ---------------------------------------------------------------------------
export async function markPaid(checkoutId: string): Promise<string> {
  return db().runTransaction(async (tx) => {
    const ref = db().collection("checkouts").doc(checkoutId);
    const snap = await tx.get(ref);
    if (!snap.exists) return "missing";
    const c = snap.data()!;
    if (c.status === "paid") return "paid";
    const orderRefs = (c.orderIds as string[]).map((id) => db().collection("orders").doc(id));
    const orders = await Promise.all(orderRefs.map((r) => tx.get(r)));

    if (c.status !== "awaiting_payment") {
      // Paid after the order had already expired: flag for a manual refund.
      tx.update(ref, { status: "paid_after_expiry", paidAt: FieldValue.serverTimestamp() });
      orderRefs.forEach((r) => tx.update(r, { paymentStatus: "refund_due", updatedAt: FieldValue.serverTimestamp() }));
      logger.warn(`Checkout ${checkoutId} paid after expiry — refund needed`);
      return "paid_after_expiry";
    }
    tx.update(ref, { status: "paid", paidAt: FieldValue.serverTimestamp() });
    orders.forEach((o, i) => {
      if (!o.exists) return;
      tx.update(orderRefs[i], {
        paymentStatus: "paid",
        status: o.data()!.status === "pending" ? "confirmed" : o.data()!.status,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return "paid";
  });
}

export async function expireCheckout(checkoutId: string, reason: string): Promise<string> {
  return db().runTransaction(async (tx) => {
    const ref = db().collection("checkouts").doc(checkoutId);
    const snap = await tx.get(ref);
    if (!snap.exists) return "missing";
    const c = snap.data()!;
    if (c.status !== "awaiting_payment") return String(c.status);
    const orderRefs = (c.orderIds as string[]).map((id) => db().collection("orders").doc(id));
    const orders = await Promise.all(orderRefs.map((r) => tx.get(r)));
    const items = orders.flatMap((o) => (o.exists ? (o.data()!.items as OrderItem[]) : []));
    await restoreStock(tx, items); // reads before writes
    tx.update(ref, { status: "expired", expiredReason: reason, updatedAt: FieldValue.serverTimestamp() });
    orderRefs.forEach((r) =>
      tx.update(r, { status: "cancelled", cancelledBy: "system", cancelReason: "Payment not completed", updatedAt: FieldValue.serverTimestamp() }),
    );
    return "expired";
  });
}

/** Checks one checkout with Monime and updates it. Returns the new status. */
export async function reconcile(checkoutId: string): Promise<string> {
  const snap = await db().collection("checkouts").doc(checkoutId).get();
  if (!snap.exists) return "missing";
  const c = snap.data()!;
  if (c.status !== "awaiting_payment" || !c.monimeSessionId || !monimeConfigured()) return String(c.status);
  const session = await getCheckoutSession(String(c.monimeSessionId));
  if (session.reference && session.reference !== checkoutId) {
    logger.error(`Reference mismatch for ${checkoutId}`);
    return String(c.status);
  }
  if (session.status === "completed") return markPaid(checkoutId);
  if (session.status === "expired" || session.status === "cancelled") return expireCheckout(checkoutId, `monime_${session.status}`);
  const created = (c.createdAt as Timestamp | undefined)?.toMillis() ?? Date.now();
  if (Date.now() - created > PAYMENT_WINDOW_MINUTES * 60_000) return expireCheckout(checkoutId, "timeout");
  return "awaiting_payment";
}

export const confirmPayment = onCall({ region: REGION, secrets: [MONIME_ACCESS_TOKEN, MONIME_SPACE_ID] }, async (req) => {
  const uid = requireUid(req);
  const checkoutId = str((req.data as Record<string, unknown>)?.checkoutId, 1, 100, "checkoutId");
  const snap = await db().collection("checkouts").doc(checkoutId).get();
  if (!snap.exists || snap.data()!.buyerId !== uid) throw new HttpsError("not-found", "Order not found.");
  try {
    return { status: await reconcile(checkoutId) };
  } catch (e) {
    logger.error("confirmPayment failed", e);
    throw new HttpsError("unavailable", "Couldn't reach the payment service. Please try again in a minute.");
  }
});

// ---------------------------------------------------------------------------
// Order changes
// ---------------------------------------------------------------------------
const TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  pending: ["confirmed", "cancelled"],
  confirmed: ["shipped", "cancelled"],
  shipped: ["delivered"],
  delivered: [],
  cancelled: [],
};

async function cancelInTx(tx: Transaction, ref: DocumentReference, o: DocumentData, by: "buyer" | "seller", reason: string) {
  await restoreStock(tx, o.items as OrderItem[]);
  tx.update(ref, {
    status: "cancelled",
    cancelledBy: by,
    cancelReason: reason.slice(0, 200),
    paymentStatus: o.paymentStatus === "paid" ? "refund_due" : o.paymentStatus,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

export const cancelOrder = onCall({ region: REGION }, async (req) => {
  const uid = requireUid(req);
  const data = (req.data ?? {}) as Record<string, unknown>;
  const orderId = str(data.orderId, 1, 100, "orderId");
  const reason = typeof data.reason === "string" ? data.reason : "";
  await db().runTransaction(async (tx) => {
    const ref = db().collection("orders").doc(orderId);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Order not found.");
    const o = snap.data()!;
    if (o.buyerId !== uid) throw new HttpsError("permission-denied", "This isn't your order.");
    if (o.status !== "pending" && o.status !== "confirmed") {
      throw new HttpsError("failed-precondition", "This order is already on its way and can't be cancelled.");
    }
    await cancelInTx(tx, ref, o, "buyer", reason || "Cancelled by buyer");
  });
  return { ok: true };
});

export const updateOrderStatus = onCall({ region: REGION }, async (req) => {
  const uid = requireUid(req);
  const data = (req.data ?? {}) as Record<string, unknown>;
  const orderId = str(data.orderId, 1, 100, "orderId");
  const next = data.status as OrderStatus;
  if (!(next in TRANSITIONS)) throw new HttpsError("invalid-argument", "Unknown status.");

  await db().runTransaction(async (tx) => {
    const ref = db().collection("orders").doc(orderId);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Order not found.");
    const o = snap.data()!;
    if (o.sellerId !== uid) throw new HttpsError("permission-denied", "Only the seller can update this order.");
    const current = o.status as OrderStatus;
    if (!TRANSITIONS[current].includes(next)) {
      throw new HttpsError("failed-precondition", `Can't change an order from ${current} to ${next}.`);
    }
    if (next !== "cancelled" && o.paymentMethod === "online" && o.paymentStatus !== "paid") {
      throw new HttpsError("failed-precondition", "Wait until the buyer has paid.");
    }
    if (next === "cancelled") {
      await cancelInTx(tx, ref, o, "seller", "Declined by seller");
      return;
    }

    if (next === "delivered") {
      const statsRef = db().collection("sellerStats").doc(uid);
      const sellerRef = db().collection("users").doc(uid);
      tx.set(
        statsRef,
        {
          deliveredRevenue: FieldValue.increment(Number(o.total)),
          deliveredOrders: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.update(sellerRef, { salesCount: FieldValue.increment(1) });
      // Lets the buyer review these products (checked by security rules).
      for (const item of o.items as OrderItem[]) {
        tx.set(db().collection("users").doc(o.buyerId).collection("purchases").doc(item.productId), {
          orderId,
          deliveredAt: FieldValue.serverTimestamp(),
        });
      }
    }
    tx.update(ref, {
      status: next,
      ...(next === "delivered" && o.paymentStatus === "cod" ? { paymentStatus: "paid" } : {}),
      [`${next}At`]: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});
