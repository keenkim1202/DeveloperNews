"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { cleanUpAfterPost, PAGE } = require("../cleanup");

/**
 * A Firestore stand-in that answers the collection-group query with the pages it
 * was given, one per call, and records what was asked of it.
 */
function makeDb(pages) {
  const deleted = [];
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => {
      const docs = pages.shift() ?? [];
      return { empty: docs.length === 0, docs };
    },
  };
  return {
    deleted,
    recursivelyDeleted: [],
    recursiveDelete(ref) {
      this.recursivelyDeleted.push(ref);
      return Promise.resolve();
    },
    collection: (name) => ({ doc: (id) => `${name}/${id}` }),
    collectionGroup: () => query,
    batch: () => ({
      delete: (ref) => deleted.push(ref),
      commit: async () => {},
    }),
  };
}

function page(size, prefix) {
  return Array.from({ length: size }, (_, index) => ({ ref: `${prefix}-${index}` }));
}

test("takes the comments under the post with it", async () => {
  const db = makeDb([[]]);

  await cleanUpAfterPost(db, "feedPosts", "post-1");

  assert.deepStrictEqual(db.recursivelyDeleted, ["feedPosts/post-1"]);
});

test("stops at a short page rather than asking for one more", async () => {
  const db = makeDb([page(2, "a"), page(5, "b")]);

  await cleanUpAfterPost(db, "feedPosts", "post-1");

  assert.deepStrictEqual(db.deleted, ["a-0", "a-1"]);
});

test("keeps going while the pages come back full", async () => {
  const db = makeDb([page(PAGE, "a"), page(1, "b"), page(9, "c")]);

  await cleanUpAfterPost(db, "posts", "post-1");

  assert.strictEqual(db.deleted.length, PAGE + 1);
});
