# Patch: pilot sheet (proposal, hidden seventh pilot)

Status: **proposal, 13 Nov 2026, from the thread "Design a hidden hacker character". Nothing here is built, played or ruled.** Andrew asked for a special hidden character who is a hacker, "a twist on necromancy ... the cyberpunk version of it", and to "go big and bold" (project chat, 13 Nov 2026 21:11Z). His four picks (who, how the raising works, how Patch is found, whether Patch freed the rogues) are on the design page https://claude.ai/artifact/YZG9B1gL1SBfZ1Cb8gmiCe; this sheet is written on the recommended option for each and changes with his picks. It lands after the world 1 sitting and does not touch the sitting build. Paths without a prefix are under `sketches/core-loop/`. A number marked **start** is a starting value to tune in play.

Reads with: [STORY-MAP.md](../STORY-MAP.md) (the four makers and how each moves and sounds; this sheet uses its words), [SKILL-BAR.md](../SKILL-BAR.md) (the six slots), [PILOTS.md](../PILOTS.md) section 7 (hull ratios) and [LEGIBILITY.md](../LEGIBILITY.md) section 13.

Terms, defined once:

- **Husk**: an ordinary machine Patch's run has broken, lying where it fell for 6 s (start) before it clears as it does today.
- **Hand**: a husk stood back up on the crew's side. It does its old job at machines for one shift.
- **Shift**: a hand's working time, 12 s (start). When it ends the hand clocks out for good.
- **Headcount**: how many hands can be out at once.

## 1. Fantasy and difference

**Fantasy.** A possum who plays dead and clocks dead machines back in. Break a machine, stamp it back onto the shift, and it works for the crew.

**What only Patch does.** Enemies change sides. Every other pilot's power is in the ball; Patch's power is standing next to it. This is the story's moral as a kit (STORY-MAP section 1): nobody is right alone, and mixed parts that work together beat one perfect answer. It also sets up the ending, where the beaten Mind is stamped HIRED and joins the crew as one more pair of hands.

**Who.** A keeper who learned the old works' command lines and how to cut and splice them. Hangs upside down by the tail in the cockpit, typing on a netbook held overhead. Sound and look are set in 2010 (ruling cr): a netbook under stickers, USB sticks on a lanyard, a dish cut from a wok. Instrument in the band: a sampler, which plays a machine's work noise back with swing. Intro card: "PATCH. Possum. Status: dead. Has been asked not to be disturbed." Wink: when the ball is scrapped Patch plays dead; the retry caption reads "Not dead. Checked."

## 2. Kit

| Slot | Id | Name | What it does |
| --- | --- | --- | --- |
| Weapon | `pointer` | Pointer | A weak, fast pulse. Hands go for whatever Patch last shot. |
| Slot 2 | `clock_in` | Clock In | Every husk in a ring around the ball stands up as a hand, up to the headcount. |
| Slot 3, line | `patch_cable` | Patch Cable | Harpoon a live ordinary machine: its next attack is done to its neighbours. On a boss weak point, the hatch stays open half again as long (start). |
| Shift | `remote_in` | Remote In | Swap places with the nearest hand, keeping speed. With no hand out, a short dash. |
| Smash | `hard_reset` | Hard Reset | The slam reboots live machines in its ring for 1 s (start) and refills every hand's shift. |
| Ultimate | `all_hands` | All Hands | A ride from A to B. Ordinary machines passed on the way down tools; at the landing they all do their job on one target at once. |

## 3. Limits

- Headcount 2 at heft class I, 3 at class III, 4 at class V (start). An elite takes two seats.
- Only ordinary machines become husks. Wardens, bosses and rogue mini-bosses never do, and the Fleet's people are never touched (ruling ch).
- A hand deals 60% (start) of its listed damage to machines and takes damage as any machine does.
- Hull 85, growth 7.5 per heft class (ratios 0.85 and 0.75 to Sable): the lightest after Kest, and it keeps the rule that a lighter hull never grows faster.
- The weakest weapon row on the roster. With no hands out Patch is in trouble, on purpose.
- Boss rooms: two husks fold into the ball and ride through the gate, so a fight with no small machines starts with a crew. The precedent is carry a core (ruling df).
- Overpowered pays: a raised machine pays its scrap again at half when its shift ends, and one Hard Reset inside a full headcount keeps four hands working.

Difficulty: a seventh pilot with allies moves every band. The kit ships only with a band read through the board thread.

## 4. How a hand reads (no new models, no label)

The machine changes sides by changing the things STORY-MAP section 3 already assigns to each maker.

| Carrier | Foreman's machine | Patch's hand |
| --- | --- | --- |
| Colour | uranium-green seam light | Patch's colour on the seam; a cut cable trails off it |
| Shape | brass Fleet tag | a paw-print sticker over the tag |
| Motion | smooth, in unison | loose, bouncy, a little late |
| Sound | tool noise on the grid | the same noise through the sampler, off the grid, in the live key |
| Time left | | a punch card over it fills with holes |

Patch's colour is a test-card pink (working call). It must pass a colour-blind check against `Palette.HAZARD` and the Mind's purple (hue 300 to 330) before it is used; the fallback is a cold white. Shape id `bracket`.

## 5. Found, not unlocked

A fresh profile shows no seventh card and no hint. `unlock.hidden` keeps the card off pilot select until the rule is met.

Three sightings across three runs, on the field finds in `src/core/secrets.gd` (`FIND_KINDS` crack and radio): a third tell, a modem handshake heard through a wall. First find: a possum flat on its back beside a warm netbook ("Not in."). Second: the room has moved with the run seed, nobody home, a cut cable on the bench. Third: Patch sits up and signs the board. One clue in plain sight: every rogue's cut command line carries a small paw-print sticker.

## 6. Story (new facts need Andrew)

- Proposed: Patch cut the rogues' command lines. They did not come over; they went back to work for nobody (ruled 23 Oct: freed, not corrupted). Patch has been trying to get it right since. This is pick 4 on the page and is not a fact until he rules.
- The Foreman answers in memos, in its voice (STORY-MAP "The Foreman's voice"): "We've noticed a sign-in from a new device." "This unit has accepted a counter-offer. We wish it well in its next role." "Your access is under review. No action is required from you." The crew, when a shift ends: "Good shift."
- Later worlds: a hand is whatever that world's roster holds, so each new machine kind works as a hand from one row. In the Highdraft the Mind's hand can take one back, with a 1 s purple warning that a shot breaks.

## 7. As data

One row in `src/core/class_def.gd` `all()`, plus the unlock rule `find:patch` in `UNLOCK_BYS` and its achievement row:

```gdscript
make({"id": "line_splicer", "display_name": "Patch", "role": "Line splicer", "species": "possum",
	"pitch": "Break a machine, then clock it back in. It works your shift. You are not much alone.",
	"weapon_id": "pointer", "movement_id": "remote_in", "special_id": "clock_in", "smash_id": "hard_reset",
	"line_id": "patch_cable", "ultimate_id": "all_hands",
	"base_hp": 85.0, "hp_growth": 7.5,
	"color": PATCH_COLOR, "shape": "bracket", "motif": "patch", "sound": "modem_chirp",
	"bible_home": "Patch, machines that change sides",
	"unlock": {"by": "find:patch", "hidden": true, "label": "Somebody keeps cutting the cables."},
	"synergy_hooks": PackedStringArray(["on_clock_in", "on_shift_end", "on_cable_misfire"])}),
```

Each enemy kind gets one row saying what it does as a hand; the default is its own attack aimed at machines.

## 8. Build order, after the sitting

1. The side rule: a machine can be on the crew's side. It lives inside the module that owns enemy state, with one small call for the kit (deep modules). Those files belong to the board thread, so this unit goes through it.
2. The six kit rows, the tree, the sheet's tests and the band read.
3. The find, the look (one new model: the possum and the ball's dressings; hands reuse bodies on screen, at most four) and the sampler sound.
