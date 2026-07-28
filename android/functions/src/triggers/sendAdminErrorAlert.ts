/**
 * Section 14.1 — sendAdminErrorAlert
 * Trigger: Firestore write on systemLogs (severity = ERROR).
 * Purpose: Emails admin instantly when a critical error is logged.
 *
 * 🔶 Actually SENDING an email needs an outbound mail provider (e.g. the
 * "Trigger Email" Firebase Extension backed by SendGrid/SMTP, or a
 * direct API call to a transactional email service) and its own API
 * key/credentials — outside the scope of what this codebase can wire up
 * without those secrets. This function does everything up to that
 * point: detects new ERROR-severity logs and writes a `mail` document in
 * the shape the official "Trigger Email" Firebase Extension expects
 * (https://extensions.dev/extensions/firebase/firestore-send-email) —
 * installing that extension against this `mail` collection is the
 * remaining step, entirely configuration (no code), once you have an
 * email provider's credentials.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {SystemLog} from "../types";

const db = admin.firestore();

const ADMIN_ALERT_EMAIL =
  process.env.ADMIN_ALERT_EMAIL ?? "shahidul.admin@diu.edu.bd"; // Section 10.1 demo admin

export const sendAdminErrorAlert = functions.firestore
  .document("systemLogs/{logId}")
  .onCreate(async (snap, context) => {
    const log = snap.data() as SystemLog;
    if (log.severity !== "ERROR") return;

    try {
      // 🔶 See file-level doc comment — this writes the document the
      // "Trigger Email" extension watches; install that extension
      // (or swap this for a direct provider call) to actually deliver it.
      await db.collection("mail").add({
        to: [ADMIN_ALERT_EMAIL],
        message: {
          subject: `[Talent Tracker AI] Critical error: ${log.source}`,
          text:
            `A critical error was logged in Talent Tracker AI.\n\n` +
            `Source: ${log.source}\n` +
            `Message: ${log.message}\n` +
            `Log ID: ${context.params.logId}\n\n` +
            `Open the System Error Log screen (S-31) in the Admin Portal for details.`,
        },
      });
    } catch (error) {
      // Deliberately does NOT call logSystemError here — an error inside
      // the error-alerting function itself would otherwise trigger
      // another systemLogs write and risk an infinite loop.
      functions.logger.error("sendAdminErrorAlert failed to queue the alert email", {
        logId: context.params.logId,
        error,
      });
    }
  });
