// Delivery tracking with a shared code.
//
// When an order is confirmed, the buyer or seller opens tracking: we create
// deliveries/{orderId} with a secret code (e.g. JD-7K3P-9QXA). The seller gives
// the code to a dispatch rider, who enters it in the app and becomes the rider
// for that order. Buyer, seller and rider can then see each other's live
// location on the map (each person chooses when to share).
//
// The buyer also gets a 4-digit handover PIN (deliveries/{id}/secrets/pin,
// readable only by the buyer). The rider must enter it to mark the order
// delivered, so a delivery can't be completed without the buyer.
import { randomInt } from "crypto";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { notifyAdmins, notifyUser } from "./notify";
import { advanceOrderInTx, type OrderStatus } from "./orders";
import { REGION } from "./region";

const db = () => getFirestore();
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O, 1/I

function uidOf(req: CallableRequest<unknown>): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in first.");
  return uid;
}

function newCodeKey(): string {
  let k = "";
  for (let i = 0; i < 8; i++) k += CODE_CHARS[randomInt(CODE_CHARS.length)];
  return k;
}
const displayCode = (key: string) => `JD-${key.slice(0, 4)}-${key.slice(4)}`;

/** "jd-7k3p 9qxa" -> "7K3P9QXA" */
function normaliseCode(v: unknown): string {
  const raw = typeof v === "string" ? v.toUpperCase().replace(/[^A-Z0-9]/g, "") : "";
  const key = raw.startsWith("JD") && raw.length === 10 ? raw.slice(2) : raw;
  if (key.length !== 8) throw new HttpsError("invalid-argument", "Enter the 8-character delivery code, e.g. JD-7K3P-9QXA.");
  return key;
}

function orderIdOf(data: unknown): string {
  const id = (data as Record<string, unknown> | undefined)?.orderId;
  if (typeof id !== "string" || id.length < 1 || id.length > 100) throw new HttpsError("invalid-argument", "Missing order.");
  return id;
}

/** Buyer or seller: get (and create on first use) the tracking code of an order. */
export const openDelivery = onCall({ region: REGION }, async (req) => {
  const uid = uidOf(req);
  const orderId = orderIdOf(req.data);
  const order = await db().collection("orders").doc(orderId).get();
  const o = order.data();
  if (!o) throw new HttpsError("not-found", "Order not found.");
  if (uid !== o.buyerId && uid !== o.sellerId) throw new HttpsError("permission-denied", "This isn't your order.");
  if (o.status === "pending" || o.status === "cancelled") {
    throw new HttpsError("failed-precondition", "Delivery tracking starts once the seller confirms the order.");
  }

  const ref = db().collection("deliveries").doc(orderId);
  const code = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return snap.data()!.code as string;
    const seller = await tx.get(db().collection("users").doc(o.sellerId).collection("private").doc("account"));
    const key = newCodeKey();
    tx.set(ref, {
      orderId,
      code: displayCode(key),
      codeKey: key,
      buyerId: o.buyerId,
      sellerId: o.sellerId,
      buyerName: o.buyerName ?? "",
      sellerName: o.sellerName ?? "",
      buyerPhone: o.phone ?? "",
      sellerPhone: (seller.data()?.phone as string | undefined) ?? "",
      dropoff: [o.address, o.city].filter((x: unknown) => typeof x === "string" && x).join(", "),
      riderId: null,
      riderName: null,
      riderPhone: null,
      status: o.status === "delivered" ? "delivered" : o.status === "shipped" ? "picked_up" : "waiting",
      participants: [o.buyerId, o.sellerId],
      locations: {},
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(ref.collection("secrets").doc("pin"), {
      pin: String(randomInt(0, 10000)).padStart(4, "0"),
      buyerId: o.buyerId,
    });
    return displayCode(key);
  });
  return { code };
});

/** Anyone with the code: buyer/seller open it, anyone else becomes the rider. */
export const joinDelivery = onCall({ region: REGION }, async (req) => {
  const uid = uidOf(req);
  const key = normaliseCode((req.data as Record<string, unknown> | undefined)?.code);
  const found = await db().collection("deliveries").where("codeKey", "==", key).limit(1).get();
  if (found.empty) throw new HttpsError("not-found", "No delivery with that code. Check it and try again.");
  const ref = found.docs[0].ref;

  const result = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data()!;
    const participants = (d.participants as string[]) ?? [];
    if (participants.includes(uid)) {
      const role = uid === d.riderId ? "rider" : uid === d.sellerId ? "seller" : "buyer";
      return { orderId: snap.id, role, joined: false, d };
    }
    if (d.status === "delivered") throw new HttpsError("failed-precondition", "This delivery is already complete.");
    if (d.riderId) throw new HttpsError("already-exists", "This delivery already has a rider.");

    const [profile, priv] = await Promise.all([
      tx.get(db().collection("users").doc(uid)),
      tx.get(db().collection("users").doc(uid).collection("private").doc("account")),
    ]);
    if (!profile.exists) throw new HttpsError("failed-precondition", "Please complete your profile first.");
    tx.update(ref, {
      riderId: uid,
      riderName: profile.data()!.name ?? "Rider",
      riderPhone: (priv.data()?.phone as string | undefined) ?? "",
      status: d.status === "waiting" ? "assigned" : d.status,
      participants: FieldValue.arrayUnion(uid),
      assignedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { orderId: snap.id, role: "rider", joined: true, d, riderName: profile.data()!.name as string };
  });

  if (result.joined) {
    const msg = `${result.riderName ?? "A rider"} is delivering order #${result.orderId.slice(0, 8).toUpperCase()}.`;
    const data = { type: "delivery", orderId: result.orderId };
    await Promise.all([
      notifyUser(result.d.buyerId, "Rider assigned 🛵", msg, data),
      notifyUser(result.d.sellerId, "Rider assigned 🛵", msg, data),
      notifyAdmins("Rider assigned 🛵", msg, data),
    ]);
  }
  return { orderId: result.orderId, role: result.role };
});

/** Rider actions: pickup, deliver (with the buyer's PIN) or release the job. */
export const deliveryAction = onCall({ region: REGION }, async (req) => {
  const uid = uidOf(req);
  const data = (req.data ?? {}) as Record<string, unknown>;
  const orderId = orderIdOf(data);
  const action = data.action;
  if (action !== "pickup" && action !== "deliver" && action !== "release") {
    throw new HttpsError("invalid-argument", "Unknown action.");
  }
  const ref = db().collection("deliveries").doc(orderId);
  const orderRef = db().collection("orders").doc(orderId);

  const d = await db().runTransaction(async (tx) => {
    const [snap, orderSnap, pinSnap] = await Promise.all([
      tx.get(ref),
      tx.get(orderRef),
      tx.get(ref.collection("secrets").doc("pin")),
    ]);
    const d = snap.data();
    const o = orderSnap.data();
    if (!d || !o) throw new HttpsError("not-found", "Delivery not found.");
    if (d.riderId !== uid) throw new HttpsError("permission-denied", "Only the rider can do this.");
    if (o.status === "cancelled") throw new HttpsError("failed-precondition", "This order was cancelled.");

    if (action === "release") {
      if (d.status !== "assigned") throw new HttpsError("failed-precondition", "You've already picked up this package.");
      tx.update(ref, {
        riderId: null,
        riderName: null,
        riderPhone: null,
        status: "waiting",
        participants: FieldValue.arrayRemove(uid),
        [`locations.${uid}`]: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return d;
    }

    if (action === "pickup") {
      if (d.status !== "assigned") throw new HttpsError("failed-precondition", "This package was already picked up.");
      if (o.status === "confirmed") advanceOrderInTx(tx, orderRef, o, "shipped" as OrderStatus);
      tx.update(ref, { status: "picked_up", pickedUpAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      return d;
    }

    // deliver
    if (d.status === "delivered") throw new HttpsError("failed-precondition", "Already delivered.");
    const pin = typeof data.pin === "string" ? data.pin.trim() : "";
    if (!pin || pin !== pinSnap.data()?.pin) {
      throw new HttpsError("permission-denied", "Wrong PIN. Ask the buyer for the 4-digit handover PIN in their app.");
    }
    if (o.status === "confirmed" || o.status === "shipped") advanceOrderInTx(tx, orderRef, o, "delivered" as OrderStatus);
    tx.update(ref, { status: "delivered", deliveredAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    return d;
  });

  const short = orderId.slice(0, 8).toUpperCase();
  const info = { type: "delivery", orderId };
  if (action === "pickup") {
    await notifyUser(d.buyerId, "Picked up 📦", `${d.riderName ?? "Your rider"} picked up order #${short}. Track it live.`, info);
  } else if (action === "deliver") {
    await Promise.all([
      notifyUser(d.buyerId, "Delivered ✅", `Order #${short} was delivered. Tap to leave a review.`, info),
      notifyUser(d.sellerId, "Delivered ✅", `${d.riderName ?? "The rider"} delivered order #${short}.`, info),
      notifyUser(uid, "Delivery complete 🎉", `You delivered order #${short}. Great job!`, info),
      notifyAdmins("Delivery completed", `${d.riderName ?? "Rider"} delivered order #${short}.`, info),
    ]);
  } else {
    await notifyUser(d.sellerId, "Rider released the job", `Order #${short} needs a new rider. Share the code again.`, info);
  }
  return { ok: true };
});
