import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";

const db = () => getFirestore();

/** Sends push notifications to a user's devices and prunes dead tokens. */
async function push(uid: string, title: string, body: string, data: Record<string, string>) {
  const ref = db().collection("users").doc(uid).collection("private").doc("account");
  const snap = await ref.get();
  const tokens: string[] = (snap.data()?.pushTokens as string[] | undefined) ?? [];
  if (tokens.length === 0) return;

  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body: body.slice(0, 180) },
    data,
    android: { priority: "high", notification: { color: "#0029A8" } },
    apns: { payload: { aps: { sound: "default" } } },
  });

  const dead = res.responses
    .map((r, i) => (!r.success && r.error && /registration-token-not-registered|invalid-argument/.test(r.error.code) ? tokens[i] : null))
    .filter((t): t is string => t !== null);
  if (dead.length > 0) {
    await ref.update({ pushTokens: FieldValue.arrayRemove(...dead) });
    logger.info(`Removed ${dead.length} stale push tokens for ${uid}`);
  }
}

/**
 * Notifies a user: saves it in their in-app inbox (users/{uid}/notifications)
 * and sends a push notification to their devices.
 */
export async function notifyUser(uid: string, title: string, body: string, data: Record<string, string> = {}) {
  if (!uid) return;
  try {
    await db().collection("users").doc(uid).collection("notifications").add({
      title,
      body: body.slice(0, 300),
      type: data.type ?? "info",
      data,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.warn(`Could not save notification for ${uid}`, e);
  }
  try {
    await push(uid, title, body, data);
  } catch (e) {
    logger.warn(`Push failed for ${uid}`, e);
  }
}

let adminUidsCache: { at: number; uids: string[] } | null = null;

/** Uids of the super admin and every admin (cached for 5 minutes). */
async function adminUids(): Promise<string[]> {
  if (adminUidsCache && Date.now() - adminUidsCache.at < 5 * 60_000) return adminUidsCache.uids;
  const { SUPER_ADMIN_EMAIL } = await import("./admin");
  const emails = [SUPER_ADMIN_EMAIL, ...(await db().collection("admins").get()).docs.map((d) => d.id)];
  const uids: string[] = [];
  for (const email of emails) {
    try {
      uids.push((await getAuth().getUserByEmail(email)).uid);
    } catch {
      // admin hasn't signed up yet
    }
  }
  adminUidsCache = { at: Date.now(), uids };
  return uids;
}

/**
 * Records an event in the admin activity feed (adminFeed) and pushes it to
 * every admin's devices.
 */
export async function notifyAdmins(title: string, body: string, data: Record<string, string> = {}) {
  try {
    await db().collection("adminFeed").add({
      title,
      body: body.slice(0, 300),
      type: data.type ?? "info",
      data,
      createdAt: FieldValue.serverTimestamp(),
    });
    const uids = await adminUids();
    await Promise.all(uids.map((u) => push(u, `Admin • ${title}`, body, { ...data, admin: "1" }).catch(() => undefined)));
  } catch (e) {
    logger.warn("notifyAdmins failed", e);
  }
}
