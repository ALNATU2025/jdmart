// Notifications for everything that happens in JDMart: the person involved
// gets an in-app (and push) notification, and admins see it in the activity feed.
import { getFirestore } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { avatarOf, notifyAdmins, notifyUser } from "./notify";
import { REGION } from "./region";

const money = (n: unknown) => `Le ${Number(n ?? 0).toLocaleString("en-US", { maximumFractionDigits: 2 })}`;

/** New member. */
export const onUserCreated = onDocumentCreated({ document: "users/{uid}", region: REGION }, async (event) => {
  const u = event.data?.data();
  if (!u) return;
  const uid = event.params.uid;
  await Promise.all([
    notifyUser(uid, "Welcome to JDMart 🎉", "Buy, sell, find jobs and track deliveries — all in one place.", { type: "welcome" }),
    notifyAdmins("New member 👋", `${u.name ?? "Someone"} from ${u.city ?? "Sierra Leone"} joined JDMart.`, {
      type: "user",
      userId: uid,
      image: typeof u.avatarUrl === "string" ? u.avatarUrl : "",
    }),
  ]);
});

/** New listing. */
export const onProductCreated = onDocumentCreated({ document: "products/{id}", region: REGION }, async (event) => {
  const p = event.data?.data();
  if (!p) return;
  const image = Array.isArray(p.images) && typeof p.images[0] === "string" ? p.images[0] : "";
  const data = { type: "product", productId: event.params.id, image };
  await Promise.all([
    notifyUser(p.sellerId, "Your listing is live ✅", `"${p.title}" is now visible to buyers across Sierra Leone.`, data),
    notifyAdmins("New listing 🏷️", `${p.sellerName} listed "${p.title}" for ${money(p.price)} in ${p.city}.`, data),
  ]);
});

/** Listing featured / hidden / restored (by admins). */
export const onProductUpdated = onDocumentUpdated({ document: "products/{id}", region: REGION }, async (event) => {
  const b = event.data?.before.data();
  const a = event.data?.after.data();
  if (!b || !a) return;
  const data = { type: "product", productId: event.params.id };
  if (!b.featured && a.featured) {
    await notifyUser(a.sellerId, "Your listing is featured ⭐", `"${a.title}" now appears in Featured on the home page.`, data);
  }
  if (b.status !== "hidden" && a.status === "hidden") {
    await Promise.all([
      notifyUser(a.sellerId, "Listing hidden", `"${a.title}" was hidden. It may break JDMart rules — contact support if this is a mistake.`, data),
      notifyAdmins("Listing hidden", `"${a.title}" by ${a.sellerName} is now hidden.`, data),
    ]);
  } else if (b.status === "hidden" && a.status === "active") {
    await notifyUser(a.sellerId, "Listing restored", `"${a.title}" is visible to buyers again.`, data);
  } else if (b.status !== "sold" && a.status === "sold") {
    await notifyAdmins("Item sold 🎉", `${a.sellerName} marked "${a.title}" as sold.`, data);
  }
});

/** New review. */
export const onReviewCreated = onDocumentCreated(
  { document: "products/{productId}/reviews/{uid}", region: REGION },
  async (event) => {
    const r = event.data?.data();
    if (!r) return;
    const product = (await getFirestore().collection("products").doc(event.params.productId).get()).data();
    if (!product) return;
    const stars = "★".repeat(Number(r.rating) || 0);
    const data = { type: "product", productId: event.params.productId };
    await Promise.all([
      notifyUser(product.sellerId, `New review ${stars}`, `${r.userName} reviewed "${product.title}"${r.comment ? `: ${r.comment}` : "."}`, data),
      notifyAdmins("New review", `${r.userName} gave "${product.title}" ${r.rating}/5.`, data),
    ]);
  },
);

/** Report filed. */
export const onReportCreated = onDocumentCreated({ document: "reports/{id}", region: REGION }, async (event) => {
  const r = event.data?.data();
  if (!r) return;
  await Promise.all([
    notifyAdmins("Listing reported 🚩", `Reason: ${r.reason}`, { type: "report", productId: String(r.productId ?? ""), reportId: event.params.id }),
    notifyUser(r.reporterId, "Report received", "Thanks for helping keep JDMart safe. Our team will review it.", { type: "info" }),
  ]);
});

/** New job post. */
export const onJobCreated = onDocumentCreated({ document: "jobs/{id}", region: REGION }, async (event) => {
  const j = event.data?.data();
  if (!j) return;
  const data = { type: "job", jobId: event.params.id };
  await Promise.all([
    notifyUser(j.ownerId, "Your job is live 💼", `"${j.title}" is now visible to job seekers.`, data),
    notifyAdmins("New job post 💼", `${j.company} is hiring: ${j.title} (${j.city}).`, data),
  ]);
});

/** Job hidden by admins. */
export const onJobUpdated = onDocumentUpdated({ document: "jobs/{id}", region: REGION }, async (event) => {
  const b = event.data?.before.data();
  const a = event.data?.after.data();
  if (!b || !a || b.status === a.status) return;
  const data = { type: "job", jobId: event.params.id };
  if (a.status === "hidden") {
    await notifyUser(a.ownerId, "Job hidden", `"${a.title}" was hidden by JDMart moderators.`, data);
  } else if (a.status === "closed") {
    await notifyAdmins("Job closed", `${a.company} closed "${a.title}" (${a.applicationsCount ?? 0} applied).`, data);
  }
});

/** CV profile created. */
export const onTalentCreated = onDocumentCreated({ document: "talent/{uid}", region: REGION }, async (event) => {
  const t = event.data?.data();
  if (!t) return;
  await Promise.all([
    notifyUser(event.params.uid, "Your CV profile is live 🪪", "Employers can now find you in Find talent.", { type: "talent", userId: event.params.uid }),
    notifyAdmins("New CV profile", `${t.name} — ${t.headline} (${t.city}).`, { type: "talent", userId: event.params.uid }),
  ]);
});

/** Skill profile created (Find skills). */
export const onSkillCreated = onDocumentCreated({ document: "skills/{uid}", region: REGION }, async (event) => {
  const s = event.data?.data();
  if (!s) return;
  const uid = event.params.uid;
  const skills = Array.isArray(s.skills) ? s.skills.slice(0, 3).join(", ") : "";
  const image = typeof s.photoUrl === "string" && s.photoUrl ? s.photoUrl : await avatarOf(uid);
  await Promise.all([
    notifyUser(uid, "You're listed in Find skills 🛠️", "People near you can now find you and call you.", { type: "skill", userId: uid }),
    notifyAdmins("New skill profile 🛠️", `${s.name} — ${skills} (${s.area ? `${s.area}, ` : ""}${s.city}).`, {
      type: "skill",
      userId: uid,
      image,
    }),
  ]);
});
