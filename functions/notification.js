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

module.exports = { buildNotification };
