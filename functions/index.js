"use strict";

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { buildNotification, buildRoute } = require("./notification");

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
    // Where the database is. A function in another region still works — the
    // trigger is created next to Firestore either way — but every activity
    // would then cross the Pacific and back before a phone hears about it.
    region: "asia-northeast3",
    // A push nobody reads is not worth a retry: the row is already in the
    // inbox, and a retrying Firestore trigger is the one way this function
    // could run away with the bill.
    retry: false,
    // What is bounded here is the rate the bill can accumulate at, not the
    // number of pushes — sending through FCM is free, and the meter runs on
    // invocations and the time they take.
    //
    // Three instances is enough that a burst of activity queues for seconds
    // rather than piling up, and few enough that nothing can accelerate. The
    // work is two Firestore reads and one multicast, so thirty seconds is a
    // hung invocation, not a slow one.
    maxInstances: 3,
    timeoutSeconds: 30,
    // Never above zero. A warm instance is billed for sitting idle, which is
    // the one way this costs money on a day when nobody touches the app.
    minInstances: 0,
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
    const route = buildRoute(activity, message);
    // What the icon shows while the app is closed. Counted rather than
    // incremented: a push that never arrived would otherwise leave the number
    // wrong for good. The app corrects it the moment it is opened, since only
    // the device knows which actors this reader has blocked.
    const unread = await db
      .collection("users").doc(recipientId)
      .collection("activities").where("isRead", "==", false).count().get();

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      data: route,
      notification: { title: message.title, body: message.body || undefined },
      apns: { payload: { aps: { sound: "default", badge: unread.data().count } } },
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
