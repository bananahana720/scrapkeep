---
name: session-start-standing-ok
description: Andrew 2026-10-19 — standing go-ahead to start local or cloud sessions without asking; app still blocks starts on automated turns
metadata:
  type: feedback
---

Andrew (2026-10-19 01:50Z): the coordinator may start new local or cloud sessions whenever the work needs one, without asking him first. Use initiation "user_asked" on any turn his own message started.

**Why:** he saw a proposal card for a fix session and said he'd rather not be asked; he trusts the coordinator to keep work moving.

**How to apply:** the app refuses `start_session` on a turn that another session's message or an automated event (watcher, task notification) started. That's a technical limit, not a permission one. On those turns, post an "own_initiative" card for anything urgent, or queue it and start it with "user_asked" on his next message without asking. Respect the lane cap in [[cloud-lanes-github-bus]] and the budget line ([[alpha-usage-stance]]).
