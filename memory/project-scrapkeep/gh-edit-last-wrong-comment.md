---
name: gh-edit-last-wrong-comment
description: gh issue comment --edit-last can edit an older comment, not the one just posted; edit by comment id instead
metadata:
  type: feedback
---

On 2026-10-31, `gh issue comment 512 --edit-last` overwrote comment 6458631641 (a 28 Oct #550 post) instead of the watch comment 6541117515 posted minutes earlier. The original was recovered from the GraphQL `userContentEdits` history and restored by PATCH.

**Why:** the board issues hold many comments by the same account, and --edit-last did not pick the newest one.

**How to apply:** to amend a receipt, PATCH it by id (`gh api -X PATCH repos/bananahana720/scrapkeep/issues/comments/<id> -F body=@file`) using the id the post returned. Never use --edit-last on the boards. Related: [[read-board-without-gh-api]].
