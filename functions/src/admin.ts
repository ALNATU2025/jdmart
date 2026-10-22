// Admin roles.
//
// The super admin is fixed below. Other admins are listed in admins/{email}
// (managed from the app's Admin console by the super admin). At every sign-in
// verifyLoginCode puts the role into the user's token as custom claims
// ({admin: true} and, for the owner, {superAdmin: true}); firestore.rules and
// storage.rules check those claims.
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { notifyAdmins } from "./notify";
import { REGION } from "./region";

/** Owner of JDMart. Keep in sync with AppConfig.superAdminEmail in the app. */
export const SUPER_ADMIN_EMAIL = "alusinebarrie578@gmail.com";

export interface RoleClaims {
  admin?: boolean;
  superAdmin?: boolean;
}

/** The claims a given email should have. */
export async function roleClaims(email: string): Promise<RoleClaims> {
  const e = email.trim().toLowerCase();
  if (e === SUPER_ADMIN_EMAIL) return { admin: true, superAdmin: true };
  const doc = await getFirestore().collection("admins").doc(e).get();
  return doc.exists ? { admin: true } : {};
}

/** Updates the stored claims on the user record if they differ. */
export async function syncClaims(uid: string, claims: RoleClaims): Promise<void> {
  const user = await getAuth().getUser(uid);
  const current = (user.customClaims ?? {}) as RoleClaims;
  if (current.admin !== claims.admin || current.superAdmin !== claims.superAdmin) {
    await getAuth().setCustomUserClaims(uid, { ...claims });
  }
}

function requireAdmin(req: CallableRequest<unknown>, superOnly = false) {
  const token = req.auth?.token as (Record<string, unknown> | undefined);
  if (!req.auth || !token) throw new HttpsError("unauthenticated", "Please sign in first.");
  if (superOnly ? token.superAdmin !== true : token.admin !== true) {
    throw new HttpsError("permission-denied", superOnly ? "Only the super admin can do this." : "Admins only.");
  }
  return req.auth.uid;
}

/** Super admin: add or remove an admin by email. */
export const adminSetRole = onCall({ region: REGION }, async (req) => {
  const caller = requireAdmin(req, true);
  const data = (req.data ?? {}) as { email?: unknown; admin?: unknown };
  const email = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new HttpsError("invalid-argument", "Enter a valid email.");
  if (email === SUPER_ADMIN_EMAIL) throw new HttpsError("failed-precondition", "The super admin can't be changed.");
  const makeAdmin = data.admin === true;

  const ref = getFirestore().collection("admins").doc(email);
  if (makeAdmin) {
    await ref.set({ email, addedBy: caller, createdAt: FieldValue.serverTimestamp() });
  } else {
    await ref.delete();
  }

  // If they already have an account, update their claims now (applies at next token refresh / sign-in).
  try {
    const user = await getAuth().getUserByEmail(email);
    await syncClaims(user.uid, makeAdmin ? { admin: true } : {});
  } catch (e) {
    if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
  }
  await notifyAdmins(makeAdmin ? "Admin added" : "Admin removed", `${email} ${makeAdmin ? "is now an admin" : "is no longer an admin"}.`, {
    type: "admin",
  });
  logger.info(`${caller} set admin=${makeAdmin} for ${email}`);
  return { ok: true };
});

/** Admin: suspend (disable sign-in) or restore a user. */
export const adminSetUserDisabled = onCall({ region: REGION }, async (req) => {
  const caller = requireAdmin(req);
  const callerIsSuper = (req.auth?.token as Record<string, unknown>).superAdmin === true;
  const data = (req.data ?? {}) as { uid?: unknown; disabled?: unknown };
  const uid = typeof data.uid === "string" ? data.uid : "";
  if (!uid) throw new HttpsError("invalid-argument", "Missing user.");
  if (uid === caller) throw new HttpsError("failed-precondition", "You can't suspend yourself.");
  const disabled = data.disabled === true;

  const target = await getAuth().getUser(uid);
  const claims = (target.customClaims ?? {}) as RoleClaims;
  if ((target.email ?? "").toLowerCase() === SUPER_ADMIN_EMAIL || claims.superAdmin) {
    throw new HttpsError("permission-denied", "The super admin can't be suspended.");
  }
  if (claims.admin && !callerIsSuper) {
    throw new HttpsError("permission-denied", "Only the super admin can suspend another admin.");
  }

  await getAuth().updateUser(uid, { disabled });
  if (disabled) await getAuth().revokeRefreshTokens(uid);
  await getFirestore().collection("users").doc(uid).set({ suspended: disabled }, { merge: true });
  await notifyAdmins(disabled ? "Account suspended" : "Account restored", `${target.email ?? uid} was ${disabled ? "suspended" : "restored"}.`, {
    type: "user",
    userId: uid,
  });
  logger.info(`${caller} set disabled=${disabled} for ${uid}`);
  return { ok: true };
});
