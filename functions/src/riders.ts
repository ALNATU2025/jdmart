// Verified riders: people apply in the app (riders/{uid}), admins approve them,
// and only approved riders can take deliveries.
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { notifyAdmins, notifyUser } from "./notify";
import { REGION } from "./region";

const db = () => getFirestore();

/** Rider details copied onto a delivery so buyer and seller can recognise them. */
export async function approvedRider(uid: string) {
  const snap = await db().collection("riders").doc(uid).get();
  const r = snap.data();
  if (!r || r.status !== "approved") {
    throw new HttpsError(
      "permission-denied",
      "Only verified JDMart riders can take deliveries. Apply in Account → Deliveries & tracking → Become a verified rider.",
    );
  }
  return {
    riderName: (r.name as string) ?? "Rider",
    riderPhotoUrl: (r.photoUrl as string | null) ?? null,
    riderVehicle: (r.vehicleType as string) ?? "",
    riderPlate: (r.plate as string) ?? "",
  };
}

/** Notifies applicants and admins as rider applications move along. */
export const onRiderWritten = onDocumentWritten({ document: "riders/{uid}", region: REGION }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  const uid = event.params.uid;
  if (!after) return;
  const data = { type: "rider", userId: uid };
  if (!before || (before.status !== "pending" && after.status === "pending")) {
    await Promise.all([
      notifyUser(uid, "Rider application received 🛵", "We'll review your details and let you know soon.", data),
      notifyAdmins("New rider application 🛵", `${after.name} (${after.vehicleType} ${after.plate ?? ""}, ${after.city}) wants to deliver.`, data),
    ]);
    return;
  }
  if (before.status === after.status) return;
  switch (after.status) {
    case "approved":
      await notifyUser(uid, "You're a verified rider ✅", "You can now accept JDMart deliveries. Sellers can also pick you from the rider list.", data);
      break;
    case "rejected":
      await notifyUser(uid, "Rider application not approved", after.reviewNote ? `Reason: ${after.reviewNote}` : "Please check your details and apply again.", data);
      break;
    case "suspended":
      await notifyUser(uid, "Rider account suspended", after.reviewNote ? `Reason: ${after.reviewNote}` : "Contact JDMart support for details.", data);
      break;
  }
});

/** Seller picks a verified rider for an order (instead of sharing the code). */
export const assignRider = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in first.");
  const data = (req.data ?? {}) as Record<string, unknown>;
  const orderId = typeof data.orderId === "string" ? data.orderId : "";
  const riderId = typeof data.riderId === "string" ? data.riderId : "";
  if (!orderId || !riderId) throw new HttpsError("invalid-argument", "Missing order or rider.");
  const rider = await approvedRider(riderId);
  const priv = await db().collection("users").doc(riderId).collection("private").doc("account").get();

  const ref = db().collection("deliveries").doc(orderId);
  const d = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data();
    if (!d) throw new HttpsError("not-found", "Open delivery tracking on the order first.");
    if (d.sellerId !== uid) throw new HttpsError("permission-denied", "Only the seller can choose the rider.");
    if (d.status !== "waiting") throw new HttpsError("failed-precondition", "This delivery already has a rider.");
    if (riderId === d.buyerId || riderId === d.sellerId) throw new HttpsError("failed-precondition", "Choose someone else as the rider.");
    tx.update(ref, {
      riderId,
      ...rider,
      riderPhone: (priv.data()?.phone as string | undefined) ?? "",
      status: "assigned",
      participants: FieldValue.arrayUnion(riderId),
      assignedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return d;
  });

  const short = orderId.slice(0, 8).toUpperCase();
  const info = { type: "delivery", orderId };
  await Promise.all([
    notifyUser(riderId, "New delivery job 🛵", `${d.sellerName} chose you to deliver order #${short} to ${d.dropoff || "the buyer"}.`, info),
    notifyUser(d.buyerId, "Rider assigned 🛵", `${rider.riderName} (${rider.riderVehicle} ${rider.riderPlate}) is delivering order #${short}.`, info),
    notifyAdmins("Rider assigned 🛵", `${rider.riderName} assigned to order #${short} by ${d.sellerName}.`, info),
  ]);
  return { ok: true };
});
