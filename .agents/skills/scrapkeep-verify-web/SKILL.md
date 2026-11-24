---
name: scrapkeep-verify-web
description: "Verify Scrapkeep's browser pages by serving them locally and driving them in headless Chromium: the Sitting Kit page Andrew marks his sitting on, and the two preserved browser proofs (the yard at / and the Iron Orchard at /orchard.html). Use when a change touches one of those pages or its server and you need to show it working in a browser; the Godot game is scrapkeep-verify-game, the packed build is scrapkeep-verify-build, and which checks qualify a diff stays in scrapkeep-verify."
---

# Verify a browser page in a real browser

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill owns a browser proof of three pages. The Sitting Kit is live: Andrew records his verdicts on it. The yard and the orchard are preserved proofs, not the current direction, and their checks never qualify the Godot game (`AGENTS.md`). `npm run verify` and the QA replays in `CONTRIBUTING.md` stay the required checks for browser-proof code (`scrapkeep-verify` picks them); this skill adds the look at the page a user gets.

All commands run from the repository root. `W=.agents/skills/scrapkeep-verify-web`.

## Launch

1. `npm ci` once, so Vite and Playwright are present. (design choice)
2. `$W/scripts/web.sh start` starts two servers in the background and waits until both answer: Vite on 127.0.0.1:5199 (the yard at `/`, the orchard at `/orchard.html`) and the Sitting Kit server on 127.0.0.1:8799. The ports are this skill's own, so a `npm run dev` on 5173 or Andrew's kit on 8765 is never touched; `VERIFY_WEB_VITE_PORT` and `VERIFY_WEB_KIT_PORT` change them. (VWB-01)
3. The kit server is started with `--verdicts` pointing at a scratch file under the run folder, so a drive can never write Andrew's verdicts. (VWB-01)
4. Teardown is `$W/scripts/web.sh stop`.

## Doctor

`$W/scripts/web.sh doctor` is read-only. It fails unless both servers are the ones this checkout started (by pid file), both answer, the kit's `/api/build` names this checkout's commit, and a Chromium is present. Run it before the first drive and after any drive that fails in a way you did not expect.

## Drive

Each feature has one Playwright script; run it with `node`, with an optional evidence name:

| Page | Command |
| --- | --- |
| Sitting Kit | `node .agents/skills/scrapkeep-verify-web/features/drive/sitting-kit.mjs [<name>]` |
| The yard | `node .agents/skills/scrapkeep-verify-web/features/drive/yard.mjs [<name>]` |
| The Iron Orchard | `node .agents/skills/scrapkeep-verify-web/features/drive/orchard.mjs [<name>]` |

A script exits 0 only when every check held, the page threw no error and at least one check ran. Handles are element ids and data attributes the pages already carry (`#gate`, `#pips button`, `.vbtn[data-v="notyet"]`, `button[data-choice="veto"]`, `#start`, `#help`), never coordinates. To prove a change, copy the feature's script, add the clicks and checks for it with `proof.check(step, seen, ok)` and `proof.shot(label)` from the drive library, and read [features/](features/README.md) first: a proof through one entry point is incomplete when the map lists others.

Chromium is `CHROMIUM_PATH`, else the cloud's preinstalled browser, else `/usr/bin/chromium`. Do not run `playwright install`.

## Evidence

Each drive writes `artifacts/local/verify-web/<name>/`: numbered pictures, a rows file (every check with what was seen, the page errors, the commit) and `identity.txt`. That folder is gitignored scratch: attach the decisive pictures and rows to the pull request, or copy them to the area's folder under `/mnt/project-files/`.

Proof standards:

- Click what a user clicks. The QA panels (`?qa`) stage state and replay input; they are the repo's regression checks, not a user path, and a proof says which of the two it used.
- Show the action and the result, and for the kit check the file the server wrote, not only the page.
- Open the pictures yourself before calling a proof. (VWB-02)
- Limits to state: headless Chromium with a software renderer, one viewport (1440x900), no sound heard, no feel or frame rate judged.

## Cleanup

`$W/scripts/web.sh stop` stops only the two servers whose pid files it wrote and removes the scratch verdicts file. It never kills by name or by port. Evidence folders stay. Run it after a failed drive too, then `start` again.

## Helpers

- `$W/scripts/web.sh start|doctor|stop`: the servers.
- `.agents/skills/scrapkeep-verify-web/features/drive/lib.mjs`: `drive(name, steps)` opens the browser, collects checks and pictures, and sets the exit code.
- `.agents/skills/scrapkeep-verify-web/features/drive/sitting-kit.mjs` and the yard and orchard scripts beside it: one drive a page.

## Lessons and updates

[references/lessons.md](references/lessons.md) holds VWB-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row. Keep the feature map honest with `/astack:create-verification-skill maintain`.

## Host adapter

- Claude Code: `/scrapkeep-verify-web`.
- Report the actual model and `CLAUDE_EFFORT` or its absence.
