#!/usr/bin/env python3
"""Exercises the users/{uid}/activities rules against the Firestore emulator.

Setup writes go through the emulator's `owner` bypass; every assertion is made
with an unsigned emulator ID token so the rules actually run.

Run it from the repo root, with a JDK on PATH:

    PATH="/opt/homebrew/opt/openjdk/bin:$PATH" \\
      firebase emulators:exec --only firestore "python3 scripts/test-firestore-rules.py"

Not wired into CI, which has no emulator. Run it by hand whenever the
activities rules change — every denial it checks is one a client cannot be
trusted to enforce.
"""
import base64, json, sys, urllib.request, urllib.error

PID = json.load(open('.firebaserc'))['projects']['default']
BASE = f"http://127.0.0.1:8080/v1/projects/{PID}/databases/(default)/documents"

ALICE = "alice-uid"   # post author / notification recipient
BOB = "bob-uid"       # actor


def token(uid):
    def seg(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b'=').decode()
    header = seg({"alg": "none", "typ": "JWT"})
    payload = seg({
        "iss": f"https://securetoken.google.com/{PID}", "aud": PID,
        "auth_time": 1000, "user_id": uid, "sub": uid, "iat": 1000,
        "exp": 9999999999, "firebase": {"identities": {}, "sign_in_provider": "custom"},
    })
    return f"{header}.{payload}."


def request(method, path, body=None, uid=None, query=""):
    req = urllib.request.Request(BASE + path + query, method=method)
    req.add_header("Authorization", "Bearer " + (token(uid) if uid else "owner"))
    data = None
    if body is not None:
        req.add_header("Content-Type", "application/json")
        data = json.dumps(body).encode()
    try:
        with urllib.request.urlopen(req, data) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()


def s(v):
    return {"stringValue": v}


def activity(kind, target_collection=None, target_post=None, comment_id=None,
             actor=BOB, is_read=False, preview="hi", parent_comment_id=None):
    fields = {"kind": s(kind), "actorId": s(actor), "preview": s(preview),
              "isRead": {"booleanValue": is_read}}
    if parent_comment_id:
        fields["parentCommentId"] = s(parent_comment_id)
    if target_collection:
        fields["targetCollection"] = s(target_collection)
    if target_post:
        fields["targetPostId"] = s(target_post)
    if comment_id:
        fields["commentId"] = s(comment_id)
    return fields


def stable_id(fields):
    """Mirrors ActivityDocument.stableId, which the create rule pins the
    document id to."""
    parts = [fields["kind"]["stringValue"]]
    if "targetCollection" in fields:
        parts.append(fields["targetCollection"]["stringValue"])
        parts.append(fields["targetPostId"]["stringValue"])
    if "commentId" in fields:
        parts.append(fields["commentId"]["stringValue"])
    parts.append(fields["actorId"]["stringValue"])
    return "_".join(parts)


def write_activity(fields, uid, recipient=ALICE, doc_id=None):
    """Commits with createdAt transformed to request.time, which is what the
    client's serverTimestamp() resolves to and what the create rule requires.

    The id defaults to the one the rule pins; pass doc_id to write elsewhere."""
    name = (f"projects/{PID}/databases/(default)/documents"
            f"/users/{recipient}/activities/{doc_id or stable_id(fields)}")
    body = {"writes": [{
        "update": {"name": name, "fields": fields},
        "updateTransforms": [
            {"fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"}],
    }]}
    url = f"http://127.0.0.1:8080/v1/projects/{PID}/databases/(default)/documents:commit"
    req = urllib.request.Request(url, method="POST")
    req.add_header("Authorization", "Bearer " + token(uid))
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, json.dumps(body).encode()) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()


results = []


def check(label, got_ok, want_ok, detail=""):
    ok = got_ok == want_ok
    results.append(ok)
    verdict = "PASS" if ok else "FAIL"
    print(f"[{verdict}] {label} (allowed={got_ok}, expected={want_ok}) {detail if not ok else ''}")


# --- setup, as owner ------------------------------------------------------
request("PATCH", f"/users/{ALICE}", {"fields": {"displayName": s("Alice"),
        "followedUserIds": {"arrayValue": {"values": []}}}})
request("PATCH", f"/users/{BOB}", {"fields": {"displayName": s("Bob"),
        "followedUserIds": {"arrayValue": {"values": []}}}})
# A post Alice owns, liked by nobody.
request("PATCH", "/feedPosts/post-alice", {"fields": {
    "authorId": s(ALICE), "comment": s("c"), "storyURL": s("u"), "storyTitle": s("t"),
    "likeCount": {"integerValue": "0"}, "likedBy": {"arrayValue": {"values": []}}}})
# A post Bob owns, so Alice is not its author.
request("PATCH", "/feedPosts/post-bob", {"fields": {
    "authorId": s(BOB), "comment": s("c"), "storyURL": s("u"), "storyTitle": s("t"),
    "likeCount": {"integerValue": "0"}, "likedBy": {"arrayValue": {"values": []}}}})
# A comment on Alice's post, written by Alice.
request("PATCH", "/feedPosts/post-alice/comments/comment-alice",
        {"fields": {"authorId": s(ALICE), "text": s("mine")}})

# --- forgery, before Bob has done anything --------------------------------
code, body = write_activity(activity("postLike", "feedPosts", "post-alice"), BOB)
check("forged postLike without actually liking", code == 200, False, body)

code, body = write_activity(activity("postComment", "feedPosts", "post-alice", "nope"), BOB)
check("forged postComment naming a comment that does not exist", code == 200, False, body)

code, body = write_activity(activity("follow"), BOB)
check("forged follow without actually following", code == 200, False, body)

code, body = write_activity(activity("follow", preview="x" * 141), BOB)
check("preview over the 140 cap", code == 200, False, body)

code, body = write_activity(activity("adminAlert"), BOB)
check("unknown kind", code == 200, False, body)

code, body = write_activity(activity("follow", actor=ALICE), ALICE, recipient=ALICE)
check("activity addressed to yourself", code == 200, False, body)

code, body = write_activity(activity("follow", actor=ALICE), BOB)
check("actorId spoofed to someone else", code == 200, False, body)

# --- the earned paths -----------------------------------------------------
request("PATCH", f"/users/{BOB}", {"fields": {"displayName": s("Bob"),
        "followedUserIds": {"arrayValue": {"values": [s(ALICE)]}}}})
code, body = write_activity(activity("follow"), BOB)
check("follow after actually following", code == 200, True, body)

request("PATCH", "/feedPosts/post-alice", {"fields": {
    "authorId": s(ALICE), "comment": s("c"), "storyURL": s("u"), "storyTitle": s("t"),
    "likeCount": {"integerValue": "1"},
    "likedBy": {"arrayValue": {"values": [s(BOB)]}}}})
code, body = write_activity(activity("postLike", "feedPosts", "post-alice"), BOB)
check("postLike after actually liking", code == 200, True, body)

request("PATCH", "/feedPosts/post-alice/comments/comment-bob",
        {"fields": {"authorId": s(BOB), "text": s("nice")}})
code, body = write_activity(activity("postComment", "feedPosts", "post-alice", "comment-bob"), BOB)
check("postComment after actually commenting", code == 200, True, body)

code, body = write_activity(activity("commentLike", "feedPosts", "post-alice", "comment-alice"), BOB)
check("commentLike without actually liking the comment", code == 200, False, body)

request("PATCH", "/feedPosts/post-alice/comments/comment-alice", {"fields": {
    "authorId": s(ALICE), "text": s("mine"),
    "likeCount": {"integerValue": "1"},
    "likedBy": {"arrayValue": {"values": [s(BOB)]}}}})
code, body = write_activity(activity("commentLike", "feedPosts", "post-alice", "comment-alice"), BOB)
check("commentLike after actually liking the comment", code == 200, True, body)

# --- replies name the comment they answer -------------------------------
# Bob's reply to Alice's comment.
request("PATCH", "/feedPosts/post-alice/comments/reply-bob", {"fields": {
    "authorId": s(BOB), "text": s("answering"),
    "parentCommentId": s("comment-alice")}})
code, body = write_activity(
    activity("commentReply", "feedPosts", "post-alice", "reply-bob",
             parent_comment_id="comment-alice"), BOB)
check("reply announced to the author of the comment it answers", code == 200, True, body)

# The same real reply, addressed to someone who did not write the parent.
request("PATCH", f"/users/carol-uid", {"fields": {"displayName": s("Carol"),
        "followedUserIds": {"arrayValue": {"values": []}}}})
code, body = write_activity(
    activity("commentReply", "feedPosts", "post-alice", "reply-bob",
             parent_comment_id="comment-alice"), BOB, recipient="carol-uid")
check("reply misaddressed to someone who wrote no parent", code == 200, False, body)

# A reply pointing at a parent it does not actually answer.
request("PATCH", "/feedPosts/post-alice/comments/comment-carol", {"fields": {
    "authorId": s(ALICE), "text": s("unrelated")}})
code, body = write_activity(
    activity("commentReply", "feedPosts", "post-alice", "comment-bob",
             parent_comment_id="comment-alice"), BOB)
check("reply claiming a parent it does not answer", code == 200, False, body)

# One earned action must not be replayable under a second document id, or a
# single like fills the 100-row listener and displaces real activity.
code, body = write_activity(activity("postLike", "feedPosts", "post-alice"), BOB,
                            doc_id="postLike-copy-2")
check("earned like replayed under a second document id", code == 200, False, body)

code, body = write_activity(activity("postComment", "feedPosts", "post-alice", "comment-bob"), BOB,
                            doc_id="postComment-copy-2")
check("earned comment replayed under a second document id", code == 200, False, body)

# Bob liked his own post; Alice is not its author, so her inbox must reject it.
request("PATCH", "/feedPosts/post-bob", {"fields": {
    "authorId": s(BOB), "comment": s("c"), "storyURL": s("u"), "storyTitle": s("t"),
    "likeCount": {"integerValue": "1"},
    "likedBy": {"arrayValue": {"values": [s(BOB)]}}}})
code, body = write_activity(activity("postLike", "feedPosts", "post-bob"), BOB)
check("real like, but delivered to a non-author's inbox", code == 200, False, body)

# --- read, mark-as-read, and the unread-reset hole ------------------------
LIKE_ROW = stable_id(activity("postLike", "feedPosts", "post-alice"))
FOLLOW_ROW = stable_id(activity("follow"))
code, body = request("GET", f"/users/{ALICE}/activities/{LIKE_ROW}", uid=BOB)
check("actor reading the recipient's inbox", code == 200, False, body)

code, body = request("GET", f"/users/{ALICE}/activities/{LIKE_ROW}", uid=ALICE)
check("recipient reading their own inbox", code == 200, True, body)

code, body = request("PATCH", f"/users/{ALICE}/activities/{LIKE_ROW}",
                     {"fields": {"isRead": {"booleanValue": True}}},
                     uid=ALICE, query="?updateMask.fieldPaths=isRead")
check("recipient marking a row read", code == 200, True, body)

code, body = write_activity(activity("postLike", "feedPosts", "post-alice"), BOB)
check("actor resetting a read row back to unread", code == 200, False, body)

code, body = request("PATCH", f"/users/{ALICE}/activities/{LIKE_ROW}",
                     {"fields": {"isRead": {"booleanValue": False}}},
                     uid=ALICE, query="?updateMask.fieldPaths=isRead")
check("recipient marking a row back to unread", code == 200, False, body)

code, body = request("DELETE", f"/users/{ALICE}/activities/{FOLLOW_ROW}", uid=BOB)
check("actor withdrawing their own row", code == 200, True, body)

print()
print(f"{sum(results)}/{len(results)} passed")
sys.exit(0 if all(results) else 1)
