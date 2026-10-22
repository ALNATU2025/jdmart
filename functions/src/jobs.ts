// Jobs: keep the application count up to date and notify people.
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentDeleted, onDocumentWritten } from "firebase-functions/v2/firestore";
import { notifyAdmins, notifyUser } from "./notify";
import { REGION } from "./region";

const db = () => getFirestore();

export const onApplicationWritten = onDocumentWritten(
  { document: "jobs/{jobId}/applications/{applicantId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const jobRef = db().collection("jobs").doc(event.params.jobId);
    const data = { type: "job", jobId: event.params.jobId };

    try {
      if (!before && after) {
        await jobRef.update({ applicationsCount: FieldValue.increment(1) });
        await Promise.all([
          notifyUser(after.ownerId, "New applicant 👤", `${after.applicantName} applied for ${after.jobTitle}.`, data),
          notifyUser(after.applicantId, "Application sent 📨", `Your application for ${after.jobTitle} at ${after.company} was sent.`, data),
          notifyAdmins("New job application", `${after.applicantName} applied for ${after.jobTitle} (${after.company}).`, data),
        ]);
      } else if (before && !after) {
        const job = await jobRef.get();
        if (job.exists) await jobRef.update({ applicationsCount: FieldValue.increment(-1) });
      } else if (before && after && before.status !== after.status && after.status === "shortlisted") {
        await notifyUser(
          after.applicantId,
          "You've been shortlisted 🎉",
          `${after.company} shortlisted you for ${after.jobTitle}. They may contact you soon.`,
          data,
        );
      }
    } catch (e) {
      logger.warn("onApplicationWritten", e);
    }
  },
);

/** Deleting a job removes its applications. */
export const onJobDeleted = onDocumentDeleted({ document: "jobs/{jobId}", region: REGION }, async (event) => {
  await db().recursiveDelete(db().collection("jobs").doc(event.params.jobId).collection("applications"));
});
