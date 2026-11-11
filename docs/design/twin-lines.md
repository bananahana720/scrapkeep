# Twin lines: swing on one, sling between two

**Status: prototype, 11 Nov 2026. Built behind `--twin-lines=on`, off by default; with the flag off the game is unchanged.** Andrew's idea (11 Nov 19:35Z): grow the ball's harpoon into a swinging system with two grapple ends, taking the feel of pendulum web-swinging and of twin-anchor gear that reels in and slingshots between two points, and making it Scrapkeep's own. The two works he named are feel references only. Nothing here copies their names, moves, look or sound.

**The short answer.** Keep the harpoon exactly as it is and bolt a second, hand-fitted line beside it: the **off line**. It bites the world only. Two things become skills: **let go at the right moment** of a swing (the line lights mint when a release would pay), and **the sling**: with both lines on the world, reel both, and let go of the off line as the ball crosses the gap between them, and the stored tension throws it on. That is built and playable. Every taste call I made is listed under [Assumptions](#assumptions) for Andrew to overturn.

```
   one line: swing                         two lines: sling

        post                               post A ●───────────● post B
          ●                                        \         /
          |\                                        \  ball /     Ctrl reels both;
          | \   let go here: the line                \  ◯  /      tension fills (0.7 s)
          |  \  glows mint, +18 % speed               \ │ /
          |   ◯ ─ ─ ─►                                  ▼          let go of the off line
          |  ╱                                     ─ ─ ◯ ─ ─ ─ ►   in the gap: + up to 16 m/s
   bottom ◯                                       (the gap)
```

## What the harpoon does today

Read from `stage/alpha-w37` at cf3953a9.

| Part | Today | Where |
| --- | --- | --- |
| Aim | One aim record shared by the reticle, the world marker and the press. It locks an enemy inside a cone round the reticle, else takes the world under the centre ray. Walkable ground is refused. Reach 45 m. | `src/movement/harpoon.gd`, `game.gd aim_along` |
| Fire and hold | Right mouse (left trigger on a pad) fires; holding keeps the line; release drops it, with the tree's fling knob on release. | `player_ball.gd _read_grammar` |
| World line | A rope with no stretch: it cancels only the outward speed, so a fall turns into a pendulum. Ctrl winches it in (pull 45, top speed 16 m/s). | `augments.gd _grapple` |
| Body line | Grip by weight: lighter than you is a flail, heavier is a pole you orbit, close is a reel. Ctrl commits the smash; a Warden opens to it only in its stagger. | `grip.gd`, `augments.gd` |
| Chain and dunk | Airborne bites build the hook chain; a slam stores a dunk that the next reel impact spends. | `src/combat/chain.gd`, `dunk.gd` |

So the ball already swings on one line. What it lacks is a reason to time the let-go, and anything to do with a second point.

## The verbs

| Verb | Input | What happens | The skill |
| --- | --- | --- | --- |
| Fire the off line | Middle mouse or mouse back button; right stick click on a pad | Bites the world where the reticle aims. An enemy under the reticle is looked past along the same ray. | Picking a post that gives a good arc |
| Swing | Hold it | A pendulum, the same rope rule as the harpoon's world line | Reading the arc |
| Clean release | Let go of a swinging line, the off line or the harpoon's world line | Inside the up-swing window (climbing 0 to 45 degrees, fading over 15 more, faster than 8 m/s, below the post) the ball keeps 18 % more speed. A let-go outside it pays nothing and costs nothing. | Timing: this is the core of the swing |
| Sling | Both lines on the world, hold Ctrl | Ctrl already winches the harpoon; with the off line out it reels both. Tension fills over 0.7 s. Let go of the off line within the gap between the posts and the ball is thrown on by up to 16 m/s along its path. | Drawing it and letting go in the gap |
| Two shots | | The off line has two bites per time in the air; touching ground refills them. | Choosing your two posts |
| Fray | | The off line holds 3.5 s, flickering rust over its last 0.8 s, then snaps with no payment. | Never hang; keep moving |

The harpoon keeps everything it does today: enemy bites, grip, chain, smash, dunk. The off line touches none of them.

## Controls

| | Keyboard and mouse | Pad |
| --- | --- | --- |
| Harpoon (unchanged) | Right mouse | Left trigger |
| Off line | Middle mouse, or the back side button | Right stick click |
| Reel both | Ctrl (unchanged winch) | X (unchanged) |

The pad mapping is the prototype's weak point: the right stick click is awkward while aiming, and the free shoulder is taken (RB is hold-to-restart, LB the ultimate). If the off line stays, the pad layout needs one pass: the clean answer is the off line on RB with restart moved to a hold of Start. That changes `bindings.gd` and the glyphs, which belong to the UI thread, so it waits for the fit decision.

## How it reads on screen and in the ear

Following ruling cx, the read is carried by colour, shape and sound, with no words.

- **The off line is twine-coloured,** a warm off-white, so it never reads as the harpoon's line. It is a keeper's hand-fitted rope, and keepers are the mismatched, hand-made side of the four makers (Story map section 3).
- **It lights mint while a let-go would pay,** brighter the more it would pay. Mint is the keepers' colour, so "glows mint" means "yours, take it". The read is one rule: let go when it lights.
- **The harpoon gets the same read** through a thin mint halo round the ball while its world line is in the window, since its own line view belongs to `line_view.gd`.
- **It flickers rust as it frays.**
- **A paid release plays a plucked string,** a step up a pentatonic climb for a fuller payment, so a perfect release sounds higher than a near one. A keeper sound is a hand-made one, and a pluck is a rope letting go.

Not in the prototype: rumble (it goes through `juice.rumble(fact, share)` once that lands), a word stamp, a camera kick, a shot counter on the ball, and a bus event for the run log. Each needs one small call in a file another thread holds, and none is needed to judge the feel.

## How it meets the other systems

| System | Interaction | Built? |
| --- | --- | --- |
| Speed tiers | A sling or a chain of clean releases is a way into fast and blazing without the boost. The tiers read the ball's speed, so they take it as they find it. Ceiling 48 m/s for a payment. | Yes, by speed |
| Carve | A release that lands on a carve face keeps its speed through the grip, so swing-to-carve is a natural line. | Yes, by speed |
| Ram and bowl | A sling into a pack is a ram at sling speed. This is the payoff: draw, let go, bowl. | Yes, by speed |
| Hook chain | The off line bites the world only, so it never builds the chain. A clean release could count as a surface pivot later. | No, a proposal |
| Heat (PR 763) | If Heat fills on fast riding and near misses, a sling should fill it and a clean release could be a Heat tick. That joins the two systems: the sling is how you get hot on purpose. | No; after Heat lands |
| Heft and grip | The off line on an enemy would bring grip rules into the second line (a sling off a heavy body, a yank on a light one). Out of the prototype, so combat is unchanged. | No, the full version |
| Pylon and slam | A mount or a plant stands the off line's rule down that tick, as for the other augments. | Yes |

## Risks, and what the maps would need

| Risk | Why | Answer in the prototype | Answer if it stays |
| --- | --- | --- | --- |
| It trivialises the park maps | Two lines and infinite re-fires could cross every gap and skip every lane | Two shots per air time and a 3.5 s fray: you can swing and sling but not hang or chain forever | Read the map standard's ride lanes with it on; a gap that must stay a gap gets a no-bite face (the walkable-ground refusal already exists) |
| It trivialises Brindle | A sling over the bowl could skip his phase pressure | The off line bites the world only, so no new damage; the sling is only speed | Fight read on 24 seeds with the flag on, compared with off (band rules) |
| It goes against ruling cu (harder, never easier, through movement) | More movement is more escape | It costs a button and timing, and pays only for skill | Tune enemies against it, not it against enemies: chasers that catch a ball hanging in a sling draw |
| Too many inputs | A third mouse button and a pad stick click | One new input only; Ctrl is reused | The pad pass above |
| Camera | Big arcs and slings can outrun the chase camera | Not changed | A sling would want the camera to lead along the throw |
| Overlaps PR 763 and pass C | Both work around the harpoon | All code is in new files; two small hooks in unheld files | Sequence after Heat and pass C |

The maps would not need to change for the prototype. A full version would need: posts placed for arcs over the Spillway's open stretches (the flume's towers already are), and the map standard's checks read with the flag on.

## Three versions

| | A. Swing and sling (recommended, built) | B. Twin harpoons | C. Swing-only |
| --- | --- | --- | --- |
| What | The harpoon unchanged, plus the off line on the world; clean release and the sling | Two full harpoons, left and right, both biting enemies and world; reel both into a body for a double smash | One line, but every let-go is timed: the window, the glow and the pluck on the harpoon alone |
| Feel | Swing rhythm plus a big drawn throw | Closest to twin-anchor gear; the most combat | The pendulum swing only |
| Combat change | None | Large: chain, grip, smash and dunk all need two-line rules | None |
| New input | One | One, and the harpoon changes | None |
| Risk to the sitting | Low with the flag off | High | Very low |
| Cost | Built here | A thread of its own, then rebalance | A subset of A: the halo and pay on the harpoon |

I recommend **A**. It gives both feel references a home (the timed swing and the drawn sling) without touching combat, so it can be judged on its own. C is the fallback if the second button is too much: it keeps the timed release, the skill most of the fun hangs on. B is the most spectacular and the most expensive, and belongs after the alpha if A plays well.

## What to feel on the PC

Launch: `npm run play -- core-loop --twin-lines=on`, pick any pilot, go to the dam.

1. **The swing.** Fire the harpoon at a high wall post, swing, and let go when the halo lights. Does the extra speed feel earned, and does the light come early enough to act on?
2. **The off line.** Middle mouse at a post, swing, let go when the twine turns mint. Is the twine easy to tell from the harpoon in a fight?
3. **The sling.** Harpoon one post, off line another across a gap, hold Ctrl, let go of middle mouse as you pass between them. Does the draw-then-throw read, and is 16 m/s enough or too much?
4. **The limits.** Do two shots and the fray feel like a rhythm or a nag?
5. **The pluck.** Is a higher note for a better release readable, or noise?

## Assumptions

Each is a call I made that Andrew can overturn.

1. The second line is a new, separate line beside the harpoon, not a change to the harpoon.
2. The off line bites the world only in the prototype, so combat is untouched.
3. A clean release pays 18 % speed, inside a 0 to 45 degree climb window with a 15 degree fade, from 8 m/s.
4. The sling pays up to 16 m/s (the winch's top speed), filled over 0.7 s of reeling both, in full within 45 % of half the span from the gap's centre.
5. Two off-line shots per air time; the ground refills them.
6. The off line frays after 3.5 s.
7. The release pays on the harpoon's world line too, so the swing is a skill with one line.
8. Mint for "a release pays", twine for the off line, rust for fraying, a plucked string for a paid release.
9. Middle mouse or the back button, and the right stick click, for the prototype only.
10. Names: "off line", "clean release", "sling". Plain words for what each does.

## Where the code is

| File | What |
| --- | --- |
| `sketches/core-loop/src/movement/twin_lines.gd` | The whole rule, the flag and the input binding |
| `sketches/core-loop/src/presentation/twin_line_view.gd` | The cable, the post ring, the halo and the pluck |
| `sketches/core-loop/src/movement/rigid_ball.gd` | The hook: one create in setup, one call after the augments, one clear on a teleport |
| `sketches/core-loop/src/movement/intent.gd` | The off line's three input fields, filled only while the flag bound its action |
| `sketches/core-loop/tests/twin_lines_test.gd` | The swing, the window, the sling, the fray, the shots, and the flag off |

The flag is parsed inside `twin_lines.gd` rather than as a row in `tuning.gd`'s `FLAGS`, because PR 763 holds `tuning.gd`. If the off line stays, it moves to a `FLAGS` row after PR 763 stacks.
