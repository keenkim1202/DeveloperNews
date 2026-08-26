"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { buildNotification } = require("../notification");

test("names the actor and carries the excerpt", () => {
  const message = buildNotification(
    { kind: "postComment", actorName: "Ada", preview: "Worth a read" }, "en");

  assert.strictEqual(message.title, "Ada commented on your post");
  assert.strictEqual(message.body, "Worth a read");
});

test("writes Korean for a Korean reader", () => {
  const message = buildNotification(
    { kind: "postLike", actorName: "Ada", preview: "x" }, "ko-KR");

  assert.strictEqual(message.title, "Ada님이 회원님의 글을 좋아합니다");
});

// A deleted account resolves to no name. "Someone liked your post" still says
// what happened; an empty name would read as a broken string.
test("falls back when the actor has no name", () => {
  assert.strictEqual(
    buildNotification({ kind: "postLike", actorName: "", preview: "x" }, "en").title,
    "Someone liked your post");
  assert.strictEqual(
    buildNotification({ kind: "postLike", preview: "x" }, "ko").title,
    "누군가님이 회원님의 글을 좋아합니다");
});

// A follow points at no content, so there is no excerpt to show. An empty
// second line reads as a notification that got cut off.
test("a follow carries no body", () => {
  const message = buildNotification({ kind: "follow", actorName: "Ada" }, "en");

  assert.strictEqual(message.title, "Ada started following you");
  assert.strictEqual(message.body, "");
});

test("an unknown kind sends nothing", () => {
  assert.strictEqual(buildNotification({ kind: "somethingNew" }, "en"), null);
});

test("an untranslated locale falls back to English", () => {
  assert.strictEqual(
    buildNotification({ kind: "follow", actorName: "Ada" }, "fr-FR").title,
    "Ada started following you");
});
