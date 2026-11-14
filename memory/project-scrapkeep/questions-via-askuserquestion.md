---
name: questions-via-askuserquestion
description: "In Claude Code, put every question to Andrew through the AskUserQuestion tool, even when a skill (such as /tree) says to ask in plain text"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 049e0d00-3954-4193-a60b-081b120acf2f
  modified: 2026-10-02T23:49:42.501Z
---

When a question needs Andrew's answer, ask it with AskUserQuestion. Keep any context (a tree, a summary) in the reply text just before the tool call. This applies even when a skill's own instructions say not to use a question tool. The /tree skill says that because of a claude.ai display quirk, and the quirk doesn't apply in Claude Code.

**Why:** On 2026-09-26 the /tree skill asked its open questions in plain text. Andrew corrected it: "if you're asking these questions to me, you should use the ask user question tool."

**How to apply:** Put questions to Andrew in AskUserQuestion, with the recommended option first. Show the tree or context in the visible text above the call. Related: [[scrapkeep-design-principles]].

**Interview him, don't wait for feedback (2026-10-02).** When he is around but can't playtest, run short interview rounds (up to four questions each, a default on every one) on owner-level calls instead of waiting for him to volunteer opinions. His words: "there are a lot of things that you could should just interview me about ... sometimes I don't really think about the feedback in the moment ... or like unstructured." First rounds that day covered run shape, retries, run length, carry-over, Arizona per world, enemy homes, story, difficulty, camp, input, next pilot and showpiece. He took most defaults but wrote his own answer for the camp, so leave room for his words.
