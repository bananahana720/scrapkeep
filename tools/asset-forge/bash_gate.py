#!/usr/bin/env python3
"""PreToolUse hook for the inner agent: Bash may run exactly `python3 <forge.py> run .`.
Claude Code auto-allows some read-only commands (cat, ls inside the working directory)
even in dontAsk mode, so the permission rules alone are not tight enough. argv[1] is the
one allowed command line."""
import json
import sys

allowed = sys.argv[1]
event = json.load(sys.stdin)
command = (event.get("tool_input") or {}).get("command", "")
if event.get("tool_name") == "Bash" and command.strip() != allowed:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse", "permissionDecision": "deny",
        "permissionDecisionReason": "Bash may only run: %s. Use Read to look at files." % allowed}}))
sys.exit(0)
