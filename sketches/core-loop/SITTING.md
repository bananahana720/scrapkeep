> **Out of date (kept as history).** This is the checkpoint 1 sheet of October 2026 for build b9f9712. The world 1 sitting is described in [ROADMAP.md](../../project-guide/handoff/ROADMAP.md) ("Andrew plays") and marked on the Sitting Kit (`project-guide/handoff/sitting-kit/`).

# Checkpoint 1: the Cable Reach

About 30 to 40 minutes. One zone, one Warden, the slice table. This is the first build where everything from the alpha plan's first milestone is in: the harpoon for every pilot, the Warden's guard and core fight, packs, side activities, and growth that matters.

## Cold launch the exported alpha

This is separate from the checkpoint 1 steps below. It checks that the packaged Linux build starts on its own, outside the project, with no Godot editor. Build b9f9712. About five minutes to the first run, then play as long as you like.

1. Open a terminal.

2. Unpack the build into a new folder in your home directory.

   ```bash
   mkdir -p ~/scrapkeep-cold
   tar -xzf ~/Projects/scrapkeep/artifacts/local/alpha/export/b9f9712/scrapkeep-core-loop-b9f9712.tar.gz -C ~/scrapkeep-cold
   ```

3. Go into it and read the build's own sheet. Its first line must read `Scrapkeep core-loop alpha (b9f9712)`.

   ```bash
   cd ~/scrapkeep-cold/scrapkeep-core-loop-b9f9712
   cat HOW-TO-RUN.txt
   ```

4. Launch with a fresh save folder. Your normal save is not touched, so skip the rename in step 4 of HOW-TO-RUN.txt. The first launch builds shaders and takes longer.

   ```bash
   XDG_DATA_HOME="$HOME/.local/share/scrapkeep-cold-b9f9712" ./core-loop.x86_64
   ```

5. Check the title screen: amber **SCRAPKEEP**, stamped in at a slight tilt, with the buttons Play, Camp, Settings, Help, Achievements and Quit. There is no Continue button, and no Companion button yet: Companion joins the row once a run finds your first companion piece. If you see Continue or New run, the save is not fresh: close the game and repeat step 4 exactly.

6. Press H to read how to play, then close it. Press Space to start and pick any open pilot.

7. Play. The run is won by beating the Mind at the end of Highdraft: the crown, stage 6. Stop whenever you like.

8. Close the game window. Tell me "cold launch done" with three things: did it open, did you hear music on the first stage, and how far you got. If it did not open, paste the last 20 lines from the terminal.

## What is new since your lab runs

- **One harpoon for every pilot.** Right mouse bites and holds, release flings. Ctrl smashes the enemy on the line, or winches you to a post. A held line on an enemy reels you in.
- **You can see the harpoon.** A thick cable, brackets that pulse on a lockable target, a steady collar when you are hooked, a dry click when there is nothing to hook.
- **Key prompts appear only when the press would work,** and fade after you have used the verb a few times.
- **The Warden fight is rebuilt.** Hit it to fill its guard bar. When the guard breaks, the jaws open and the core glows mint. Smash the open core to break off one of its four health pieces.
- **The Warden's health is on the ground.** Four lit arcs round its feet, one per health piece. The boss plate on the HUD shows the same four.
- **Growing matters.** Each side activity pays a part and a big scrap haul. A full-size ball breaks the Warden in about 25 s; a starting-size ball takes three to four times as long.
- **Three side activities** stand on the map from the start: an ambush altar, a cracked cache, and a hauler bounty.
- **Enemies arrive as packs** and show their attack in their body before it lands. Six kinds on the slice.
- **The map has three lines down it,** one per pilot, and a shared ramp that throws you at the Warden.
- **Reaching a new ball size opens one upgrade pick** once you are on the ground and out of the fight.

## Added after this sheet was first written (3 October)

None of these change the fight. They are there if you want them.

- **Settings** from the title (S) or the pause menu: fullscreen, quality, and a rebind row for every verb. A key that another verb already uses reads "Taken".
- **Pilot cards show the unlock for a locked pilot.** Sable, Rivet and Kest are open on a fresh save. Press P on a card to change its paint.
- **Achievements** open from the title with A. Earning one shows a short note in play.
- **Key prompts follow your device and your bindings.** Pick up a gamepad and the prompts switch to pad buttons.
- **The recovered gamepad-menu changes passed independent source review and the executable gate at 286327f.** Physical controller operation still needs checking. A jumps and confirms; B boosts and backs out. Judge keyboard and mouse first.

## Checked candidate

The gamepad changes are integrated into `proto/alpha`. The recovery record at `artifacts/local/alpha/recovery-2026-10-03/RECOVERY.md` gives the final source identity, integrated gate and checkpoint results. Check its sitting status before launching. The current reconciliation also changes documentation, so the earlier 286327f gate alone does not qualify the final tree.

The game still opens Sable, Rivet and Kest on a fresh profile. Their campaign unlock conditions are approved future work. This sitting judges the Cable Reach loop, not the finished campaign or durable active-run saves.

## Steps

1. Open a terminal.

2. Launch the slice with a fresh save folder, so the first-time key prompts show again. The first launch builds shaders and takes longer than usual.

   ```bash
   XDG_DATA_HOME="$HOME/.local/share/scrapkeep-alpha-sitting-2026-10-03" scrapkeep game-completion-plan-75f776/core-loop -- --table=slice
   ```

3. Pick any pilot.

4. For the first five minutes, harpoon into an ordinary pack of enemies. Your earlier homing-smash verdict was super fun; judge whether the current latch, prompts and impact make that action clear and satisfying.

5. Then play however you like. Hold R to restart a run. Play at least two runs if you feel like it.

6. Close the game window when you are done.

7. Answer the five questions below. A word or two each is fine.

8. Tell me "sitting done". I read your run log from the save folder and report what it shows.

## Controls

| Verb | Key |
| --- | --- |
| Roll | W A S D |
| Look | Mouse |
| Jump | Space |
| Fire | Left mouse |
| Harpoon | Right mouse: press to bite, hold to keep, release to fling |
| Haul | Ctrl: smash the hooked enemy, or winch to a post. With no line, Ctrl brakes on the ground and slams in the air. |
| Boost | Shift: your pilot's own move |
| Special | F |
| Interact | E |
| Field notes | Tab |
| Pause | P or Esc |
| Restart | Hold R |

## Five questions

1. The loop in one sentence.
2. Best moment.
3. Worst frustration.
4. Would you play again right now?
5. Rate difficulty, pacing and clarity, each out of 5.

## Calls I made that only your play can judge

Say "veto" on any of these and I change it.

1. Holding the line on an enemy reels you toward it before you smash.
2. Right mouse while charging Sable's slingshot cancels the charge.
3. The hauler bounty sits on the straight route to the Warden, to guard the beeline.
4. Sable hops on the dive ramp for up to a second.
5. When you fall, the camera eases down toward the landing while your aim stays put.
6. The deflector's dish throws you back at nine tenths of your speed. It is the one enemy that turns you faster than the hold limit, because jumping off the rebound vaults you.
7. Guns fill the Warden's guard bar only a little and never break its core. Only your ball cracks it open.
