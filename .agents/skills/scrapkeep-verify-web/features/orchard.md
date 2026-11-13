# The Iron Orchard

The third-person browser proof at `/orchard.html`: an entry card with "Enter the orchard", then a ball in an orchard lane with a wave plate, a hull bar and five skill tiles (Lightning, Strike, Conductor, Ram, Overcharge). It is preserved, not the current direction.

## Sub-features

- `OR-1` The entry card loads with no page error.
- `OR-2` Enter the orchard hides the card and draws the lane, the ball and the HUD.
- `OR-3` The Dashboard (I) opens.
- `OR-4` The QA replays on `/orchard.html?qa`.

## How to get to it (user POV)

- `npm run dev`, then open `http://127.0.0.1:5173/orchard.html`; or the PLAY THE IRON ORCHARD link on the yard's start screen.

## Driving it with Playwright

Preconditions: baseline (the skill's own Vite on 5199).

- **OR-1, OR-2:** `node .agents/skills/scrapkeep-verify-web/features/drive/orchard.mjs orchard`. Expect exit 0 and "2 of 2 checks held, 0 page error(s)", with the pictures `entry` and `inside`; `inside` shows the wave plate ("WAVE 1 / 3"), the hull bar and the skill tiles.
- **OR-3:** not driven by the script; press `i` after entering and take a picture.
- **OR-4:** not a user path. `CONTRIBUTING.md` names the buttons ("Run DOM input replay", "Run state fixtures", "Run input expedition") and says to record them separately.

## Gotchas

- Keep orchard combat state, rendering, models and input in their own modules (`AGENTS.md`); a proof here does not replace `npm run verify` and the orchard's own replays.
- The tab must stay visible during replays; a headless page counts as visible.
- A pass says the page starts and draws. It says nothing about the Godot game.
