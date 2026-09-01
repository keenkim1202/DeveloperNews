"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { countUnread } = require("../badge");

function makeDb(answer) {
  const query = {
    where: () => query,
    count: () => query,
    get: async () => {
      if (answer instanceof Error) {
        throw answer;
      }
      return { data: () => ({ count: answer }) };
    },
  };
  return {
    collection: () => ({ doc: () => ({ collection: () => query }) }),
  };
}

test("counts the rows the reader has not read", async () => {
  assert.strictEqual(await countUnread(makeDb(3), "me"), 3);
});

// The notification is worth more than the number on it.
test("answers nothing rather than failing the push", async () => {
  assert.strictEqual(await countUnread(makeDb(new Error("nope")), "me"), null);
});
