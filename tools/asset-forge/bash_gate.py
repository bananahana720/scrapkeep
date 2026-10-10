#!/usr/bin/env python3
"""PreToolUse hook for the inner agent: Bash may run exactly `python3 <forge.py> run .`.
Claude Code auto-allows some read-only commands (cat, ls inside the working directory)
even in dontAsk mode, so the permission rules alone are not tight enough. argv[1] is the
one allowed command line."""
import json
import sys

allowed = sys.argv[1]
event = json.load(sys.stdin)
tool_input = event.get("tool_input") or {}
command = tool_input.get("command", "")
# A background run would overlap the next one on the same version dir.
if event.get("tool_name") == "Bash" and (command.strip() != allowed or tool_input.get("run_in_background")):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse", "permissionDecision": "deny",
        "permissionDecisionReason": "Bash may only run: %s. Use Read to look at files." % allowed}}))
sys.exit(0)
