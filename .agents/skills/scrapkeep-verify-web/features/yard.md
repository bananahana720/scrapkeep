# The yard

The original browser proof at `/`: a start screen with three heroes (Pip, Rivet, Moss), How to play, and START EXPEDITION, which opens an isometric yard where the ball rolls with W A S D. It is preserved, not the current direction.

## Sub-features

- `YD-1` The start screen loads with no page error and shows START EXPEDITION.
- `YD-2` How to play opens the field manual and closes again.
- `YD-3` A hero card can be picked.
- `YD-4` START EXPEDITION hides the start screen and draws the yard with its HUD.
- `YD-5` The other entries: the Iron Orchard link, today's shared yard, the field collection.

## How to get to it (user POV)

- `npm run dev`, then open `http://127.0.0.1:5173/`. `?quality=low` turns the effects down.

## Driving it with Playwright

Preconditions: baseline (the skill's own Vite on 5199).

- **YD-1 to YD-4:** `node .agents/skills/scrapkeep-verify-web/features/drive/yard.mjs yard`. Expect exit 0 and "2 of 2 checks held, 0 page error(s)", with four pictures: `start-screen`, `how-to-play`, `hero-picked`, `in-expedition`.
- **YD-2:** click `#help`, take the picture, press Escape.
- **YD-3:** click the card whose text holds "Rivet".
- **YD-4:** click `#start`, wait until it is no longer shown, hold `w` for three seconds, take the picture: it shows the yard, the wave plate and the score.
- **YD-5:** not driven by the script; `#daily-start` and `#open-collection` are the handles.
- **The repo's regression replay** (not a user path): `GAME_URL=http://127.0.0.1:5199 CHROMIUM_PATH=<chromium> npm run test:browser` clicks `#qa-run` on `/?qa&quality=low`.

## Gotchas

- The script loads `/?quality=low`, because the software renderer is slow with effects on. Say so in the receipt.
- Sound needs a user gesture and is never heard here.
- A pass says the page starts and draws. It says nothing about the Godot game.
