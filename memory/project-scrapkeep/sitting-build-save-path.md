---
name: sitting-build-save-path
description: "Where the installed Scrapkeep AppImage keeps its real save, and the w19 world 1 sitting plan to start it fresh"
metadata:
  node_type: memory
  type: project
  originSessionId: 271afd7e-ed7d-4b9b-88a2-421b8a22c1b2
  modified: 2026-10-26T21:55:48.888Z
---

The installed AppImage (~/.local/share/scrapkeep/Scrapkeep.AppImage, menu entry ~/.local/share/applications/scrapkeep.desktop, plus a "sitting" action with --profile=sitting that never saves) keeps its real save at ~/.local/share/godot/app_userdata/core-loop/profile.json. Dev and editor runs on the PC share that folder. A clean boot check uses XDG_DATA_HOME/XDG_CACHE_HOME/XDG_CONFIG_HOME in a scratch folder.

**Why:** unit 24 (coordinator call 23 Oct) wants the world 1 sitting on a fresh profile that saves, so Andrew feels the first-hour ladder across runs.
**How to apply:** only when installing the final sitting build, rename profile.json to profile.pre-w19-sitting.json (keep it) and tell Andrew where the old save is (coordinator, 26 Oct 21:55Z). Never on a dry run. Off-screen boot proof: gamescope --backend headless --prefer-vk-device 10de:2704 -- <AppImage> --gpu-index 0, read SCRAPKEEP_MENU_READY. See [[pc-gpu-rules]].
