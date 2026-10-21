import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";

/** Sends a push notification to every device of a user and prunes dead tokens. */
export async function notifyUser(uid: string, title: string, body: string, data: Record<string, string> = {}) {
  const ref = getFirestore().collection("users").doc(uid).collection("private").doc("account");
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
