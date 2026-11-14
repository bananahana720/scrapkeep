---
name: remote-control-idle-sweep
description: A project thread running on the PC over Remote Control is stopped after about 60 minutes without a turn; background jobs do not count
metadata:
  node_type: memory
  type: project
  originSessionId: a7876736-4776-4a34-8a42-2176187dfd0c
  modified: 2026-11-14T08:11:51.291Z
---

The desktop app's Remote Control idle sweep stops a PC session that goes about 60 minutes without a turn. A running background job does not count as activity. Source: the coordinator's note of 2026-11-14, after the board traced a session that dropped at 06:30 that day (not verified by me).

**Why:** a thread waiting on a long gate or render loses its session and its in-flight context.

**How to apply:** while holding a PC session, cap every background wait at about 45 minutes, then take a short turn and wait again. See [[fast-focused-tests-cloud-cpu]] for where long runs should go.
