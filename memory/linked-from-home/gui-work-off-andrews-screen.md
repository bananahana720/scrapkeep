---
name: gui-work-off-andrews-screen
description: "Never pop windows onto Andrew's active workspace; do visual/GUI work headless or via claude-open on workspace 10"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 45199d33-955e-4e58-887a-39edc625fb1b
  modified: 2026-09-22T22:14:47.076Z
---

When Claude needs a GUI window or a visual check, it must not open windows where Andrew is working. Windows that popped up mid-task disrupted him.

In order of preference:
1. **Headless, no window at all.** Render pages with `chromium --headless=new --disable-gpu --user-data-dir=/tmp/claude-1000/<name> --window-size=W,H --screenshot=<out.png> file://…`, and render images or video offscreen.
2. **`claude-open <cmd> [args]`** (`~/.local/bin/claude-open`) launches a window on workspace 10 (SUPER+0) with `silent`, so it never takes focus. Use `CLAUDE_WS=special:claude` for fully hidden. Close the window when done: `hyprctl dispatch "hl.dsp.window.close({ window = \"address:0x…\" })"`.
3. Only show something on his screen when he asks to see it.

Hyprland 0.56 specifics:
- `hyprctl dispatch` takes Lua (`hl.dsp.*`); legacy names like `togglespecialworkspace` fail with a Lua syntax error.
- `hyprctl dispatch '<x>'` is wrapped as `return hl.dispatch(<x>)`, so it takes exactly one `hl.dsp.*` expression; a `local` or a loop fails with "unexpected symbol". Statements and introspection go through `hyprctl eval`. Look names up in `/usr/share/hypr/stubs/hl.meta.lua` before trying them (2026-10-08: `hl.dsp.focuswindow` and `hl.dsp.movecursor` do not exist). Working forms: focus `hl.dsp.focus({ window = "title:…" })`, launch `hl.dsp.exec_cmd("…")`, move `hl.dsp.window.move({ window = …, workspace = N, follow = true })`, close `hl.dsp.window.close({ window = … })`, pointer `hl.dsp.cursor.move({ x = X, y = Y })`.
- Launch rules are `hyprctl eval 'hl.exec_cmd("cmd", { workspace = "10 silent", float = true, size = {w,h} })'`. Never wrap the command in uwsm-app, because a new PID means the rule doesn't match.
- Chromium `--app` windows ignore `--class` on Wayland; their class is built from the URL.
- A grim screenshot only captures the visible workspace.

**Why:** Andrew asked on 2026-09-22 after a test window landed on his active workspace.
**How to apply:** Any time a task needs a browser, app window or screenshot for verification, go headless first, otherwise use claude-open, and clean up after. Related: [[omarchy-live-wallpaper]].

**Silent by default (2026-09-28, dotfiles fed8317):** Andrew found Claude's native Godot perf runs loud. `claude-open` now routes the launched app's audio to a `claude_silent` null sink (created on first use) via `env PULSE_SINK`. The app still renders audio, so perf cost is unchanged, but nothing reaches the speakers. `CLAUDE_OPEN_AUDIO=1` opts out when a check needs to hear it. A window launched any other way is not muted.

**Wait mode (2026-09-28, dotfiles 2e24c09):** claude-open returns as soon as Hyprland has the launch, so `flock <lock> claude-open ...` dropped the lock before the app rendered. `CLAUDE_OPEN_WAIT=1` finds the launched PID (tagged via `env CLAUDE_OPEN_TAG`) and blocks until it exits; use it for any locked or timed run. The app's stdout stays with Hyprland, so pass it its own log flag (Godot `--log-file <path>`).

**Browser tabs are fine (2026-10-02):** "you can open it on screen... usually you'll be working in your own tab, so I think that's fine if it's on the browser." A tab in his browser (the Claude in Chrome tab group, or a local dev server like Remotion Studio opened as a tab) is OK and doesn't need the headless or claude-open route. New native windows still follow the rules above.
