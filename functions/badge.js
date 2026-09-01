"use strict";

// The number the push puts on the app icon. Kept apart from the trigger so the
// failure it swallows can be tested without Firestore.

/**
 * How many rows the recipient has yet to read, or null if that cannot be
 * answered. A number nobody could read is worth less than the notification it
 * would have ridden on, so failing to count is not failing to send.
 */
async function countUnread(db, recipientId) {
  try {
    const result = await db
      .collection("users").doc(recipientId)
      .collection("activities").where("isRead", "==", false).count().get();
    return result.data().count;
  }
  catch {
    return null;
  }
}

module.exports = { countUnread };
