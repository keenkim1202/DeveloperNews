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
  const who = (activity.actorName || "").trim() || strings.someone;
  const preview = (activity.preview || "").trim();
  return {
    title: line(who),
    body: activity.kind === "follow" ? "" : preview,
  };
}

/**
 * Fields the app needs to rebuild the route, under the name the inbox document
 * already uses so one parser answers both. FCM values are strings.
 */
const ROUTE_KEYS = ["kind", "actorId", "targetCollection", "targetPostId",
                    "commentId", "storyURL", "storyTitle"];

/**
 * APNs rejects a payload over 4 KB outright, and a story URL has no length
 * anyone controls. Past the budget the route is dropped rather than the
 * notification: the reader lands in the inbox, which is where a tap went
 * before there was a route at all.
 */
const ROUTE_BUDGET = 3000;

function buildRoute(activity) {
  const route = {};
  for (const key of ROUTE_KEYS) {
    if (activity[key] != null) {
      route[key] = String(activity[key]);
    }
  }
  return Buffer.byteLength(JSON.stringify(route)) > ROUTE_BUDGET ? {} : route;
}

module.exports = { buildNotification, buildRoute };
