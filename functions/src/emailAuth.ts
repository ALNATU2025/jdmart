// Email sign-in with a 6-digit code sent from your Gmail account.
//
// Flow: the app calls requestLoginCode(email) -> we email a code ->
// the app calls verifyLoginCode(email, code) -> we return a Firebase custom
// token -> the app signs in with it. No passwords, no SMS.
//
// Secrets (set once with the Firebase CLI):
//   firebase functions:secrets:set GMAIL_USER           e.g. jdmart.sl@gmail.com
//   firebase functions:secrets:set GMAIL_APP_PASSWORD   16-character Google "App password"
//
// Gmail limits: about 500 emails/day on a normal Gmail account and 2,000/day on
// Google Workspace. Move to a transactional email service when you outgrow that.
import { createHash, randomBytes, randomInt, timingSafeEqual } from "crypto";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import nodemailer from "nodemailer";
import { roleClaims, syncClaims } from "./admin";
import { REGION } from "./region";

export const GMAIL_USER = defineSecret("GMAIL_USER");
export const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");

const CODE_TTL_MINUTES = 10;
const MAX_ATTEMPTS = 5; // wrong guesses allowed per code
const MAX_CODES_PER_HOUR = 5; // per email address
const RESEND_AFTER_SECONDS = 60;

const db = () => getFirestore();
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function normaliseEmail(v: unknown): string {
  const e = typeof v === "string" ? v.trim().toLowerCase() : "";
  if (!EMAIL_RE.test(e) || e.length > 254) throw new HttpsError("invalid-argument", "Enter a valid email address.");
  return e;
}

/** Document id for an email address (hashed so the address isn't the key). */
const docId = (email: string) => createHash("sha256").update(email).digest("hex");
const hashCode = (code: string, salt: string) => createHash("sha256").update(`${salt}:${code}`).digest("hex");

function emailHtml(code: string): string {
  return `<!doctype html><html><body style="margin:0;background:#F4F6FA;font-family:Arial,Helvetica,sans-serif;color:#142237">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px 12px">
    <table role="presentation" width="100%" style="max-width:440px;background:#ffffff;border-radius:16px;padding:28px" cellpadding="0" cellspacing="0">
      <tr><td style="font-size:22px;font-weight:bold"><span style="color:#0029A8">JD</span><span style="color:#FB6401">Mart</span></td></tr>
      <tr><td style="padding-top:18px;font-size:15px;line-height:1.5">Your sign-in code is:</td></tr>
      <tr><td style="padding:14px 0;font-size:34px;font-weight:bold;letter-spacing:8px;color:#0029A8">${code}</td></tr>
      <tr><td style="font-size:13px;line-height:1.5;color:#6B7385">It expires in ${CODE_TTL_MINUTES} minutes.
        If you didn't try to sign in to JDMart, you can ignore this email. Never share this code with anyone.</td></tr>
    </table>
    <p style="font-size:12px;color:#6B7385">JDMart · Buy Smart. Sell Faster.</p>
  </td></tr></table></body></html>`;
}

export const requestLoginCode = onCall(
  { region: REGION, secrets: [GMAIL_USER, GMAIL_APP_PASSWORD] },
  async (req) => {
    const email = normaliseEmail((req.data as Record<string, unknown> | undefined)?.email);
    const ref = db().collection("emailCodes").doc(docId(email));
    const now = Date.now();

    const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
    const salt = randomBytes(16).toString("hex");

    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const d = snap.data();
      const lastSent = (d?.sentAt as Timestamp | undefined)?.toMillis() ?? 0;
      if (now - lastSent < RESEND_AFTER_SECONDS * 1000) {
        throw new HttpsError("resource-exhausted", "Please wait a minute before asking for another code.");
      }
      const windowStart = (d?.windowStart as Timestamp | undefined)?.toMillis() ?? 0;
      const inWindow = now - windowStart < 60 * 60 * 1000;
      const sentInWindow = inWindow ? Number(d?.sentInWindow ?? 0) : 0;
      if (sentInWindow >= MAX_CODES_PER_HOUR) {
        throw new HttpsError("resource-exhausted", "Too many codes requested. Please try again in an hour.");
      }
      tx.set(ref, {
        hash: hashCode(code, salt),
        salt,
        attempts: 0,
        expiresAt: Timestamp.fromMillis(now + CODE_TTL_MINUTES * 60_000),
        sentAt: Timestamp.fromMillis(now),
        windowStart: inWindow ? Timestamp.fromMillis(windowStart) : Timestamp.fromMillis(now),
        sentInWindow: sentInWindow + 1,
      });
    });

    try {
      // Tolerate stray spaces / line breaks pasted into the secrets.
      const user = GMAIL_USER.value().trim();
      const pass = GMAIL_APP_PASSWORD.value().replace(/\s+/g, "");
      const transport = nodemailer.createTransport({ service: "gmail", auth: { user, pass } });
      await transport.sendMail({
        from: `"JDMart" <${user}>`,
        to: email,
        subject: `${code} is your JDMart sign-in code`,
        text: `Your JDMart sign-in code is ${code}. It expires in ${CODE_TTL_MINUTES} minutes. Never share this code with anyone.`,
        html: emailHtml(code),
      });
    } catch (e) {
      logger.error("Sending login email failed", e);
      await ref.update({ sentAt: Timestamp.fromMillis(0) }); // allow an immediate retry
      throw new HttpsError("unavailable", "We couldn't send the email. Please check the address and try again.");
    }
    return { ok: true, expiresInMinutes: CODE_TTL_MINUTES };
  },
);

export const verifyLoginCode = onCall({ region: REGION }, async (req) => {
  const data = (req.data ?? {}) as Record<string, unknown>;
  const email = normaliseEmail(data.email);
  const code = typeof data.code === "string" ? data.code.trim() : "";
  if (!/^\d{6}$/.test(code)) throw new HttpsError("invalid-argument", "Enter the 6-digit code from the email.");

  const ref = db().collection("emailCodes").doc(docId(email));
  const ok = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data();
    if (!d || !d.hash) throw new HttpsError("not-found", "Please request a new code.");
    if ((d.expiresAt as Timestamp).toMillis() < Date.now()) {
      tx.update(ref, { hash: FieldValue.delete() });
      throw new HttpsError("deadline-exceeded", "This code has expired. Please request a new one.");
    }
    if (Number(d.attempts ?? 0) >= MAX_ATTEMPTS) {
      throw new HttpsError("resource-exhausted", "Too many wrong attempts. Please request a new code.");
    }
    const expected = Buffer.from(String(d.hash), "hex");
    const actual = Buffer.from(hashCode(code, String(d.salt)), "hex");
    const match = expected.length === actual.length && timingSafeEqual(expected, actual);
    if (match) {
      tx.update(ref, { hash: FieldValue.delete(), attempts: 0 }); // one-time use
    } else {
      tx.update(ref, { attempts: FieldValue.increment(1) });
    }
    return match;
  });
  if (!ok) throw new HttpsError("permission-denied", "That code is incorrect. Please check the email and try again.");

  // Find or create the Firebase user for this email, then issue a sign-in token.
  const auth = getAuth();
  let uid: string;
  try {
    const user = await auth.getUserByEmail(email);
    if (user.disabled) {
      throw new HttpsError("permission-denied", "This account has been suspended. Please contact JDMart support.");
    }
    uid = user.uid;
    if (!user.emailVerified) await auth.updateUser(uid, { emailVerified: true });
  } catch (e) {
    if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
    uid = (await auth.createUser({ email, emailVerified: true })).uid;
  }

  // Admin roles travel in the token (checked by the security rules).
  const claims = await roleClaims(email);
  await syncClaims(uid, claims);
  const token = await auth.createCustomToken(uid, { ...claims });
  return { token };
});
