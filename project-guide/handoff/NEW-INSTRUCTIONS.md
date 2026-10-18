# Project instructions for the new Scrapkeep project

Paste everything below the line into the new project's instructions.

---

## What this project is

Scrapkeep is Andrew's Godot 4.7.2 roguelite (repo bananahana720/scrapkeep, game in `sketches/core-loop`). The goal is a finished-feeling Linux alpha by wave 21, accepted at his 11-area playtest sitting: no "Not yet", no open blocker, frame times in budget on his 4080, and zero placeholders.

Start every session at `project-guide/handoff/README.md` in the repo. The decisions register (`project-guide/handoff/DECISIONS.md`) holds every ruling. Check it before deciding anything; newest ruling wins.

## Direction principles

1. **Intent everywhere.** Every park, level and moment gets the care of the first one. World 1 is not front-loaded as trailer bait.
2. **Unique enemies per world.** Enemies are never rehashed and never gimmicks. They build on the core verbs (roll, ram, grapple, carve), and later worlds are harder remixes as the pilot grows.
3. **Every idea is a motif.** Place it deliberately and in harmony, not spread evenly.
4. **Chaos you can learn.** Many attackers, fair and readable. Difficulty scales with player power, like Isaac, but never so far that it cancels a nutty build.
5. **Overpowered pays.** Strong builds and lucky runs are never punished; an insane setup or plain luck always earns a reward.
6. **Items and actives go broad and deep.** Tiers, actives (magic-like but explained in-universe), elemental affixes, weapon overrides, and maker, zone or race families with collectible sets. Andrew's examples model ambition only; never copy them on the nose.
7. **Discovery and collecting are the long-term pull.** Secrets, unlocks, hidden tunes, and lore found over runs.
8. **The Mind is a through-line from the first world onward.** It is "All hands": the crew were its hands, so it grew its own.
9. **A playground that makes you smile.** Melodrama that winks, with energy and switch-ups over tidy theory. Scott Pilgrim is the touchstone. Borrow anime tropes, not East Asian sound. Written lore stays in a dry crew-log voice.
10. **Stay consistent with himself.** One register, newest ruling wins, nothing re-decided without new information.
11. **Claude runs operations at full speed with standing merge authority.** Andrew is the vision stakeholder, brought design calls early and often.
12. **Polish everything.** Bake models and use denser polygons where frame times allow, in the "Soft toy" look: crews and round bodies smooth, machines crisp and bevelled. Tie animation keyframes into smooth blends. A joke must still mean something.
13. **Promote fast.** Short waves, each promoted to main promptly. Open PRs roll to the next wave instead of blocking it. Fail fast in testing and red teaming, and keep tightening the verification loops.

After the alpha (parked until the sitting): monster origins, park societies, pilot personality, richer world transitions, alternate paths, and New Game Plus. The roadmap is ordered by what to add, not by dates.

## How we work

- **Phone-first.** Andrew decides through cards in the project chat: at most three open, one question each, a recommended option, game terms, and the measured number when there is one. While a card waits, work continues on the recommended option.
- **Every ask of Andrew goes in the project chat.** Make it one line, or a paste-ready command he runs in his own terminal. Threads never ask him in-thread.
- **Verify before recording.** Every tap is checked against the timeline before it goes in the register. A rule change is a card.
- **Speed.** 12+ cloud threads at once. An ask becomes a draft PR in under 2 h, and a draft PR gets a gate verdict in under 4 h. Split work into code-side and Blender-side threads, sized to each sandbox.
- **No thread grades its own work.** A game change needs a tool check plus an independent reviewer. The cloud gate is the gate of record except for GPU checks, and a red team plays every stage head.
- **Cloud and PC.** Cloud threads edit `src/` and `assets/` on their own branches and gate them in the cloud. Andrew's 4080 keeps GPU checks, ACE-Step music and the real export proof.
- **Merges.** The coordinator merges gate-passed PRs, including to main, and does git housekeeping. Prefer a new branch and a fresh PR over force-push.
- **Files.** Keep the register, lessons and handoff files in the repo under `project-guide/handoff/`, so any session or account can read them.
