import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION } from "./region";
import { anonymiseChats } from "./triggers";

/**
 * Deletes a user's account and personal data (required by Google Play and the
 * App Store). Orders that are still in progress must be finished first; past
 * orders are kept (with the name anonymised) because the other party needs them.
 */
export const deleteAccount = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in first.");
  const db = getFirestore();

  const open = ["pending", "confirmed", "shipped"];
  const [asBuyer, asSeller] = await Promise.all([
    db.collection("orders").where("buyerId", "==", uid).where("status", "in", open).limit(1).get(),
    db.collection("orders").where("sellerId", "==", uid).where("status", "in", open).limit(1).get(),
  ]);
  if (!asBuyer.empty || !asSeller.empty) {
    throw new HttpsError(
      "failed-precondition",
      "You have orders in progress. Please complete or cancel them before deleting your account.",
    );
  }

  // Listings (photos and reviews are cleaned up by onProductDeleted).
  const products = await db.collection("products").where("sellerId", "==", uid).get();
  const writer = db.bulkWriter();
  products.docs.forEach((d) => writer.delete(d.ref));

  // Anonymise past orders.
  const [bought, sold] = await Promise.all([
    db.collection("orders").where("buyerId", "==", uid).get(),
    db.collection("orders").where("sellerId", "==", uid).get(),
  ]);
  bought.docs.forEach((d) => writer.update(d.ref, { buyerName: "Deleted user", phone: "", address: "", note: "" }));
  sold.docs.forEach((d) => writer.update(d.ref, { sellerName: "Deleted user" }));
  await writer.close();

  // Jobs: my job posts (their applications are removed by onJobDeleted),
  // my applications to other jobs, and my CV profile and files.
  const [myJobs, myApps] = await Promise.all([
    db.collection("jobs").where("ownerId", "==", uid).get(),
    db.collectionGroup("applications").where("applicantId", "==", uid).get(),
  ]);
  const jobWriter = db.bulkWriter();
  myJobs.docs.forEach((d) => jobWriter.delete(d.ref));
  myApps.docs.forEach((d) => jobWriter.delete(d.ref));
  jobWriter.delete(db.collection("talent").doc(uid));
  await jobWriter.close();
  await getStorage().bucket().deleteFiles({ prefix: `cvs/${uid}/` }).catch((e) => logger.warn(e));

  await anonymiseChats(uid);
  await db.recursiveDelete(db.collection("users").doc(uid)); // profile, private data, wishlist, purchases
  await db.collection("sellerStats").doc(uid).delete();
  await getStorage().bucket().deleteFiles({ prefix: `avatars/${uid}/` }).catch((e) => logger.warn(e));
  await getAuth().deleteUser(uid);
  logger.info(`Deleted account ${uid}`);
  return { ok: true };
});
