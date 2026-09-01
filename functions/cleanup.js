"use strict";

// What a deleted post leaves behind, and how much of it goes at a time. Kept
// apart from the trigger so the paging can be read and tested without
// Firestore: it is the only part with a loop in it.

// One page of stale rows at a time, asking again until a page comes back
// short. A post nobody touched costs one empty query.
const PAGE = 300;

/**
 * Clears what deleting a post does not: the comments under it, which Firestore
 * does not take with the document, and the notifications about it sitting in
 * other people's inboxes.
 *
 * Those rows are deletable by their recipient and by their actor, and whoever
 * deleted the post is usually neither. A client cannot even find them — an
 * inbox is readable only by its owner.
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
