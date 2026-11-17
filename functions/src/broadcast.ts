// Admin "Send notification": a message to every user (or one town), pushed
// to phones through FCM topics. Apps subscribe to "all" and "city_<town>".
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { REGION } from "./region";

export const cityTopic = (city: string) => `city_${city.toLowerCase().replace(/[^a-z0-9]+/g, "_")}`;

export const onBroadcastCreated = onDocumentCreated({ document: "broadcasts/{id}", region: REGION }, async (event) => {
  const b = event.data?.data();
  if (!b) return;
  const topic = b.audience === "city" && typeof b.city === "string" && b.city ? cityTopic(b.city) : "all";
  const image = typeof b.imageUrl === "string" && b.imageUrl.startsWith("https://") ? b.imageUrl : undefined;
  const data: Record<string, string> = { type: b.productId ? "product" : "broadcast", broadcastId: event.params.id };
  if (b.productId) data.productId = String(b.productId);
  try {
    await getMessaging().send({
      topic,
      notification: { title: String(b.title ?? "JDMart"), body: String(b.body ?? "").slice(0, 180), imageUrl: image },
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "jdmart_alerts",
          color: "#0029A8",
          icon: "ic_stat_jdmart",
          sound: "default",
          defaultVibrateTimings: true,
          priority: "max",
          visibility: "public",
          imageUrl: image,
        },
      },
      apns: { payload: { aps: { sound: "default", "mutable-content": 1 } }, fcmOptions: { imageUrl: image } },
    });
    await event.data?.ref.update({ sentAt: new Date(), topic });
  } catch (e) {
    logger.error("Broadcast failed", e);
  }
});
