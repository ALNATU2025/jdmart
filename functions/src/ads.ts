// Paid ads. Phones schedule their own reminders (works without billing);
// these functions add instant pushes when the server is running.
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { notifyAdmins, notifyUser } from "./notify";
import { REGION } from "./region";

const money = (n: unknown) => `Le ${Number(n ?? 0).toLocaleString("en-US", { maximumFractionDigits: 2 })}`;

/** New ad request: tell admins to check the payment. */
export const onAdCreated = onDocumentCreated({ document: "ads/{id}", region: REGION }, async (event) => {
  const a = event.data?.data();
  if (!a) return;
  await notifyAdmins(
    "New ad to approve 📣",
    `${a.sellerName} paid ${money(a.amount)} (${a.payMethod}, ref ${a.payRef}) to advertise "${a.title}" for ${a.days} day(s).`,
    { type: "admin", adId: event.params.id },
  );
});

/** Approved / rejected: tell the seller; approved ads are pushed to everyone. */
export const onAdUpdated = onDocumentUpdated({ document: "ads/{id}", region: REGION }, async (event) => {
  const b = event.data?.before.data();
  const a = event.data?.after.data();
  if (!b || !a || b.status === a.status) return;
  const data = { type: "product", productId: String(a.productId ?? "") };

  if (a.status === "rejected") {
    await notifyUser(a.sellerId, "Ad not approved", a.note || `We couldn't confirm the payment for "${a.title}".`, data);
    return;
  }
  if (a.status !== "active") return;

  await notifyUser(a.sellerId, "Your ad is live 🚀", `"${a.title}" is now shown to every JDMart user for ${a.days} day(s).`, data);
  try {
    await getMessaging().send({
      topic: "sponsored",
      notification: { title: `⭐ ${a.title}`, body: `${money(a.price)}${a.city ? ` • ${a.city}` : ""} — tap to see it on JDMart` },
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "jdmart_promos",
          color: "#FB6401",
          icon: "ic_stat_jdmart",
          imageUrl: typeof a.imageUrl === "string" ? a.imageUrl : undefined,
        },
      },
    });
  } catch (e) {
    logger.warn("Sponsored push failed", e);
  }
});
