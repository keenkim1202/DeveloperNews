"use strict";

// What a push for an activity says. Kept apart from the trigger so it can be
// read and tested without Firebase: it is the only part with branches.

const TEXT = {
  en: {
    postLike: (who) => `${who} liked your post`,
    postComment: (who) => `${who} commented on your post`,
    commentReply: (who) => `${who} replied to your comment`,
    commentLike: (who) => `${who} liked your comment`,
    follow: (who) => `${who} started following you`,
    someone: "Someone",
  },
  ko: {
    postLike: (who) => `${who}님이 회원님의 글을 좋아합니다`,
    postComment: (who) => `${who}님이 회원님의 글에 댓글을 남겼습니다`,
    commentReply: (who) => `${who}님이 회원님의 댓글에 답글을 남겼습니다`,
    commentLike: (who) => `${who}님이 회원님의 댓글을 좋아합니다`,
    follow: (who) => `${who}님이 회원님을 팔로우하기 시작했습니다`,
    someone: "누군가",
  },
};

/** The reader's language, defaulting to English for anything not translated. */
function stringsFor(locale) {
  return String(locale || "").toLowerCase().startsWith("ko") ? TEXT.ko : TEXT.en;
}

/**
 * The title and body for one activity, or null for a kind we do not send.
 *
 * The title carries who did what, mirroring the row in the app; the body is the
 * excerpt the activity was written with. A follow has no excerpt, so it has no
 * body — a notification with an empty second line reads as a truncation.
 */
function buildNotification(activity, locale) {
  const strings = stringsFor(locale);
  const line = strings[activity.kind];
  if (!line) {
    return null;
  }
  const who = clip((activity.actorName || "").trim(), NAME_LIMIT) || strings.someone;
  const preview = clip((activity.preview || "").trim(), PREVIEW_LIMIT);
  return {
    title: line(who),
    body: activity.kind === "follow" ? "" : preview,
  };
}

/**
 * A display name and an excerpt are both as long as whoever wrote them made
 * them, and neither is shown past a line or two on the lock screen. Clipping
 * them keeps the payload under the APNs limit, which rejects the notification
 * outright rather than trimming it.
 */
const NAME_LIMIT = 60;
const PREVIEW_LIMIT = 200;

function clip(text, limit) {
  return text.length > limit ? `${text.slice(0, limit)}…` : text;
}

/**
 * Fields the app needs to rebuild the route, under the name the inbox document
 * already uses so one parser answers both. FCM values are strings.
 */
const ROUTE_KEYS = ["kind", "actorId", "targetCollection", "targetPostId",
                    "commentId", "storyURL", "storyTitle"];

/**
 * APNs rejects a payload over 4 KB outright, and a story URL has no length
 * anyone controls. The title and body count against the same budget, so they
 * are measured with the route. Past it the route goes and the notification
 * stays: a tap without one lands in the inbox.
 */
const PAYLOAD_BUDGET = 3000;

function buildRoute(activity, message = {}) {
  const route = {};
  for (const key of ROUTE_KEYS) {
    if (activity[key] != null) {
      route[key] = String(activity[key]);
    }
  }
  const payload = JSON.stringify([message.title, message.body, route]);
  return Buffer.byteLength(payload) > PAYLOAD_BUDGET ? {} : route;
}

module.exports = { buildNotification, buildRoute };
