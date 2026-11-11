# One name for one thing

The one home for what each thing is called in player text (ruling cx, [LEGIBILITY.md](LEGIBILITY.md) section 13, pattern W7). The coordinator's calls of 10 Nov 2026, for Andrew's veto. A new name, or a change to one, is made here first.

Facts checked in the code at the wave 35 stage head: `run.cogs` is the money a shop spends and `run.scrap` is what the ball rolls up, so they are two things; the HUD has a HEALTH bar and a separate ARMOUR bar that only shows in armour mode; the Q verb is `ultimate` and the F verb is `active` in `src/core/bindings.gd`.

The `Lint` column holds the exact strings `npm run sketch:lint` bans from player text (rule W7, whole words, any case). A string goes there only when a plain match is safe: it can never be right in player text. A row whose retirement depends on meaning has "reviewer" in that cell, and a reviewer checks it by reading.

| Thing | Use | Retire from player text | Lint |
| --- | --- | --- | --- |
| Money a shop takes | cogs (with the cog icon; the number alone where the icon is beside it) | "scrap" as a price | reviewer |
| What the ball rolls up | scrap | "salvage", "parts" for scrap | `salvage` |
| How much scrap the ball carries | heft | "mass", "scrap mass", "weight", "ballast" as a stat name, "Grow" as an instruction (say "Roll up scrap" or "Get heavy") | `scrap mass`; the rest reviewer |
| The grey bar that shows in armour mode, and Brindle's plates | armour | "armour" for health or heft | reviewer |
| Enemy toughness against a hit | plating | "plating" for the player's health | reviewer |
| The Q ability | ultimate. On a card: "Ultimate becomes <name>." Never a typed key letter in a sentence, because keys can be rebound; draw the keycap where a mark fits | "set piece", "Q:", "Q becomes" as typed text | `set piece`, `Q becomes` |
| The F ability | active, shown as its keycap on the bar slot | "your active" in a tip with a typed F | reviewer (the typed F is rule W4) |
| The 1, 2, 3 keys | picks ("Pick 1") | "slot" | reviewer (the lore keeps "slot canyon" and "cartridge slot") |
| Storing a charge | bank | "stockpile", "stock" | `stockpile`, `stockpiles`, `stockpiled` |
| Getting a charge back | refill | "hands back", "refund", "recharge", "return", "give back" | `hands back`, `give back`, `gives back`; "refund", "recharge" and "return" reviewer (a record sleeve's "No refunds." is a joke) |
| Coming off a wall or body | bounce | "rebound" | `rebound`, `rebounds` |
| The rope | harpoon | "grapple", "rope" as its name | `grapple` |
| Attaching the harpoon | hook | "bite", "latch on" | `latch on` |
| The companion | SPIL-9, introduced once as "SPIL-9, your companion" | "Companion" as a screen title | reviewer |
| The things you fight | machines | "enemies", "foes", "the miniboss" (name the machine) | `foes`, `miniboss` |
| Beating a machine, in a count | clocked out | "kills" | reviewer |
| Starting over | New run | "Restart run", "Run again" | `Restart run`, `Run again` |
| Leaving a page | Back, always shown with the Esc keycap | H, A, J, R, K as the Back key; "Esc to close" as text; "Return", "Close" | reviewer (rule S8 checks Back buttons and close hints) |
| Upgrades plus parts on the ball | build | "kit" for the build ("kit" stays for a pilot's own abilities) | reviewer |
| The relay mast | mast | "stake" as a noun, "post" | reviewer |
| What jams picks 2 and 3 | pulse | "mats" | `mats` |
| The flume's Warden | the name on its card, "Meltdown Warden" | "Reactor Warden" on the plate | reviewer (the dam's Warden keeps "Reactor Warden") |
| The dam's Warden | Reactor Warden | nothing | |
| Sable's special | discharge | "detonation", "the gauge" | `the gauge`; "detonation" reviewer (Kest's "detonation line" keeps the word) |
| The music pages | Radio for the page, record for the jukebox, take for the radio | "tracks", "tunes", "Mixtapes" as a second page name | `Mixtapes`, `tunes`; "tracks" reviewer |
| A thing earned and listed on the Achievements page | achievement | "badge" | `badge`, `badges` |
| A record's second version | B-side | "remix", "radio song" | `remix`, `radio song` |

Not changed, and on Andrew's veto page instead: whether "The Foreman" and "The Mind" are one voice by design (a story call), and the "NEXT SHIFT" plate on the run summary (in-world voice).

The word "class" must never reach the player (rule W4 in the lint). One line still did at the wave 35 stage head: `src/build/lanes.gd:25` ("once your heft reaches the next class"); use "tier".
