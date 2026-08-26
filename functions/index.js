"use strict";

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { buildNotification } = require("./notification");

initializeApp();

// FCM says this when a token belongs to an app that has been deleted or has
// re-registered. The row is dead and every later send would fail the same way.
const DEAD_TOKEN = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

exports.sendActivityPush = onDocumentCreated(
  {
    document: "users/{userId}/activities/{activityId}",
    // A push nobody reads is not worth a retry: the row is already in the
    // inbox, and a retrying Firestore trigger is the one way this function
    // could run away with the bill.
    retry: false,
    maxInstances: 10,
  },
  async (event) => {
    const activity = event.data?.data();
    if (!activity) {
      return;
    }

    const recipientId = event.params.userId;
    const db = getFirestore();

    const tokenDocs = await db
      .collection("users").doc(recipientId)
      .collection("pushTokens").get();
    if (tokenDocs.empty) {
      return;
    }

    // The activity stores an id, not a name — the app resolves names when it
    // renders the inbox, and a name copied onto every row would go stale.
    const actor = await db.collection("users").doc(activity.actorId).get();
    const message = buildNotification(
      { ...activity, actorName: actor.get("displayName") },
      tokenDocs.docs[0].get("locale"));
    if (!message) {
      return;
    }

    const tokens = tokenDocs.docs.map((doc) => doc.id);
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body || undefined },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });

    // Tokens the device no longer answers to are removed here rather than left
    // to fail on every future activity.
    const dead = response.responses
      .map((result, index) => ({ result, token: tokens[index] }))
      .filter(({ result }) => result.error && DEAD_TOKEN.has(result.error.code))
      .map(({ token }) => token);
    await Promise.all(dead.map((token) =>
      db.collection("users").doc(recipientId)
        .collection("pushTokens").doc(token).delete()));
  });
