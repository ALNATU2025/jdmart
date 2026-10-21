import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { PAYMENT_WINDOW_MINUTES } from "./catalog";
import { MONIME_ACCESS_TOKEN, MONIME_SPACE_ID } from "./monime";
import { notifyUser } from "./notify";
import { expireCheckout, reconcile } from "./orders";
import { REGION } from "./region";

const db = () => getFirestore();
const short = (id: string) => id.slice(0, 8).toUpperCase();
const money = (n: number) => `Le ${Number(n).toLocaleString("en-US", { maximumFractionDigits: 2 })}`;

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------
export const onOrderCreated = onDocumentCreated({ document: "orders/{orderId}", region: REGION }, async (event) => {
  const o = event.data?.data();
  if (!o || o.paymentMethod !== "cod") return; // online orders notify the seller once paid
  await notifyUser(o.sellerId, "New order 🛒", `${o.buyerName} ordered ${o.items.length} item(s) • ${money(o.total)} (cash on delivery)`, {
    type: "order",
    orderId: event.params.orderId,
  });
});

export const onOrderUpdated = onDocumentUpdated({ document: "orders/{orderId}", region: REGION }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const id = event.params.orderId;
  const data = { type: "order", orderId: id };

  if (before.paymentStatus !== "paid" && after.paymentStatus === "paid" && after.paymentMethod === "online") {
    await notifyUser(after.sellerId, "New paid order 🛒", `${after.buyerName} paid ${money(after.total)}. Please prepare the items.`, data);
  }
  if (before.status === after.status) return;

  switch (after.status) {
    case "confirmed":
      if (before.status === "pending" && after.paymentMethod === "cod") {
        await notifyUser(after.buyerId, "Order confirmed", `${after.sellerName} confirmed order #${short(id)}.`, data);
      }
      break;
    case "shipped":
      await notifyUser(after.buyerId, "On the way 🚚", `Order #${short(id)} from ${after.sellerName} is on its way.`, data);
      break;
    case "delivered":
      await notifyUser(after.buyerId, "Delivered ✅", `Order #${short(id)} was delivered. Tap to leave a review.`, data);
      break;
    case "cancelled":
      if (after.cancelledBy === "buyer") {
        await notifyUser(after.sellerId, "Order cancelled", `${after.buyerName} cancelled order #${short(id)}.`, data);
      } else if (after.cancelledBy === "seller") {
        await notifyUser(after.buyerId, "Order declined", `${after.sellerName} couldn't fulfil order #${short(id)}.`, data);
      }
      break;
  }
});

export const onMessageCreated = onDocumentCreated(
  { document: "chats/{chatId}/messages/{messageId}", region: REGION },
  async (event) => {
    const m = event.data?.data();
    if (!m) return;
    const chat = (await db().collection("chats").doc(event.params.chatId).get()).data();
    if (!chat) return;
    const toBuyer = m.senderId !== chat.buyerId;
    const to = toBuyer ? chat.buyerId : chat.sellerId;
    const from = toBuyer ? chat.sellerName : chat.buyerName;
    await notifyUser(to, from, String(m.text ?? ""), { type: "chat", chatId: event.params.chatId });
  },
);

// ---------------------------------------------------------------------------
// Ratings: keep product and seller averages up to date.
// ---------------------------------------------------------------------------
export const onReviewWritten = onDocumentWritten(
  { document: "products/{productId}/reviews/{userId}", region: REGION },
  async (event) => {
    const productRef = db().collection("products").doc(event.params.productId);
    const reviews = await productRef.collection("reviews").get();
    const ratings = reviews.docs.map((d) => Number(d.data().rating) || 0).filter((r) => r > 0);
    const count = ratings.length;
    const avg = count ? Math.round((ratings.reduce((a, b) => a + b, 0) / count) * 10) / 10 : 0;
    const product = await productRef.get();
    if (!product.exists) return;
    await productRef.update({ ratingAvg: avg, ratingCount: count });

    // Seller rating = weighted average over the seller's products.
    const sellerId = product.data()!.sellerId as string;
    const products = await db().collection("products").where("sellerId", "==", sellerId).select("ratingAvg", "ratingCount").get();
    let total = 0;
    let n = 0;
    for (const d of products.docs) {
      const c = d.id === productRef.id ? count : Number(d.data().ratingCount) || 0;
      const a = d.id === productRef.id ? avg : Number(d.data().ratingAvg) || 0;
      total += a * c;
      n += c;
    }
    await db().collection("users").doc(sellerId).set(
      { ratingAvg: n ? Math.round((total / n) * 10) / 10 : 0, ratingCount: n },
      { merge: true },
    );
  },
);

// ---------------------------------------------------------------------------
// Housekeeping
// ---------------------------------------------------------------------------

/** When a listing is deleted, remove its photos and reviews. */
export const onProductDeleted = onDocumentDeleted({ document: "products/{productId}", region: REGION }, async (event) => {
  const p = event.data?.data();
  const id = event.params.productId;
  if (p?.sellerId) {
    await getStorage().bucket().deleteFiles({ prefix: `products/${p.sellerId}/${id}/` }).catch((e) => logger.warn(e));
  }
  await db().recursiveDelete(db().collection("products").doc(id).collection("reviews"));
});

/** Keep the seller's name and verified badge on their listings in sync. */
export const onUserUpdated = onDocumentUpdated({ document: "users/{uid}", region: REGION }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.name === after.name && before.verified === after.verified) return;
  const products = await db().collection("products").where("sellerId", "==", event.params.uid).get();
  const writer = db().bulkWriter();
  products.docs.forEach((d) => writer.update(d.ref, { sellerName: after.name, sellerVerified: after.verified === true }));
  await writer.close();
});

/** Cancels online orders that were not paid in time and releases their stock. */
export const expireUnpaidOrders = onSchedule(
  { schedule: "every 10 minutes", region: REGION, secrets: [MONIME_ACCESS_TOKEN, MONIME_SPACE_ID] },
  async () => {
    const cutoff = new Date(Date.now() - PAYMENT_WINDOW_MINUTES * 60_000);
    const stale = await db()
      .collection("checkouts")
      .where("status", "==", "awaiting_payment")
      .where("createdAt", "<", cutoff)
      .limit(100)
      .get();
    for (const d of stale.docs) {
      try {
        const status = await reconcile(d.id); // pays it if Monime says completed
        if (status === "awaiting_payment") await expireCheckout(d.id, "timeout");
      } catch (e) {
        logger.error(`Could not reconcile ${d.id}`, e);
      }
    }
  },
);

// ---------------------------------------------------------------------------
// Monime webhook. Register this URL in the Monime dashboard:
//   https://<region>-<project>.cloudfunctions.net/monimeWebhook
// We don't trust the payload: we re-fetch the session from Monime's API.
// ---------------------------------------------------------------------------
export const monimeWebhook = onRequest(
  { region: REGION, secrets: [MONIME_ACCESS_TOKEN, MONIME_SPACE_ID] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }
    try {
      const body = (req.body ?? {}) as { object?: { id?: string; type?: string }; data?: { reference?: string } };
      const type = body.object?.type ?? "";
      if (type.includes("checkout")) {
        const reference = body.data?.reference;
        let checkoutId = typeof reference === "string" ? reference : null;
        if (!checkoutId && body.object?.id) {
          const match = await db().collection("checkouts").where("monimeSessionId", "==", body.object.id).limit(1).get();
          checkoutId = match.empty ? null : match.docs[0].id;
        }
        if (checkoutId) await reconcile(checkoutId);
      }
      res.status(200).send("ok");
    } catch (e) {
      logger.error("Monime webhook error", e);
      res.status(500).send("error"); // Monime retries
    }
  },
);

/** Small helper used by deleteAccount. */
export async function anonymiseChats(uid: string) {
  const chats = await db().collection("chats").where("participants", "array-contains", uid).get();
  const writer = db().bulkWriter();
  chats.docs.forEach((d) => {
    const c = d.data();
    writer.update(d.ref, c.buyerId === uid ? { buyerName: "Deleted user" } : { sellerName: "Deleted user" });
  });
  await writer.close();
}

