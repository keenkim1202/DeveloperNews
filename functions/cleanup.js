"use strict";

// Kept apart from the trigger so the paging can be tested without Firestore:
// it is the only part of this with a loop in it.

// One page at a time, asked again until a page comes back short. A post nobody
// touched costs one empty query.
const PAGE = 300;

/**
 * Clears what deleting a post does not: the comments Firestore leaves under it,
 * and the notifications about it in other people's inboxes. A client cannot
 * reach those — an inbox is readable only by its owner, who is rarely the one
 * deleting the post.
 */
async function cleanUpAfterPost(db, collection, postId) {
  await db.recursiveDelete(db.collection(collection).doc(postId));

  for (;;) {
    const stale = await db.collectionGroup("activities")
      .where("targetCollection", "==", collection)
      .where("targetPostId", "==", postId)
      .limit(PAGE)
      .get();
    if (stale.empty) {
      return;
    }
    const batch = db.batch();
    stale.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    // A short page is the end of them. Asking again would cost a query to be
    // told the same thing.
    if (stale.docs.length < PAGE) {
      return;
    }
  }
}

module.exports = { cleanUpAfterPost, PAGE };
