# Story threads, core-loop v2

An older telling. The current story facts are in [design-v3/STORY-MAP.md](../design-v3/STORY-MAP.md) (9 Nov 2026); where the two differ, that page is the current one.

The story-thread board. It sits beside `DESIGN-V2.md` (what the game does), `VISUAL-LANGUAGE.md` (how it looks), `SOUND-STORY.md` (how it sounds and what it means) and `PROGRESSION.md` (what carries across runs, written in parallel; this board leaves it hooks and designs no progression). The vision keeper owns it under `PROTOCOL.md`.

Four rules govern every thread:

1. **Read on the move.** A beat is a fragment, a line, a material or a motif. There is no cutscene and no stop; the HUD carries no lore (`SOUND-STORY.md` §5).
2. **Never resolved.** The cause of the collapse, the uplift and Brindle's ending stay open on purpose. A beat adds a reading, never a verdict.
3. **Discovered, not announced** (DESIGN-V2 §13). A thread is found in play, the codex, a secret, a repeated interaction or an odd combination. It is never a tutorial.
4. **Every thread rides a mechanic.** A beat that changes nothing the player does is decoration; a beat the player can miss and still play fairly is the standard.

## 1. The threads

| # | Thread | What it says | The mechanic it rides | Where the player meets it | Stays unresolved |
| --- | --- | --- | --- | --- | --- |
| T1 | **The collapse's cause** | Humans ended themselves by nuclear war, drones, a superintelligence, or all three | The three family Wardens (DESIGN-V2 §11: reactor relic, swarm hive, the Mind's hand), one per stage, so one run meets all three causes; the reactor's terrain hazards; the swarm's formations; the Mind's counters | The Warden fights; codex world fragments in vaults and secrets; the two material eras | Which cause, or whether it was ever one thing |
| T2 | **The uplift** | Animals became the reigning species by evolution, or by something humans left behind | The pilots' kits are their cultures' tools (grapple, rail, lift); the Caretaker Node plaque; Moss's shop is a repair culture at work | Class select (species and culture names), codex world fragments, the workshop bay | Whether anyone uplifted them, and whether it was the Mind |
| T3 | **Moss remembers you** | Maintenance is social; someone notices what you neglect (BIBLE.md:384) | Run history (`run_log.gd` records: class, outcome, stages, deaths, codex) keys his lines; the heft-locked top shelf is a growth goal you can read | The workshop bay after each Warden break | Moss's own species and where he learned |
| T4 | **Brindle's arc toward the arena** | The Fleet counts ancient housings as inventory; inventory woke | Difficulty ticks add one of Brindle's layers (anvil, brass) per tick; requisition tags on dug-up housings; his arena quotes the three stages in reverse (G6) | Reinforcement packs, Fleet dig sites, codex fragments 3 and 9, the arena | Whether Brindle knew, and what he does after the arena |
| T5 | **The Mind's hands learn** | Something is reading you and answering | In-run adaptation: it counters the player's last pattern, bounded and telegraphed by the inverted class motif and the trigger icon (DESIGN-V2 §10) | Stage 3 and its Warden; the codex enemy page fills with what it learned | Whether it is the Mind itself, a hand of it, or an echo running on its own |
| T6 | **The reigning animals** | Life found a way; the fox winches, the mole cuts, the bird lifts | Class identity: the three kits are three engineering cultures (BIBLE §2), so how a class plays is where it comes from | Class select, the shells' silhouettes, the pilots visible in the cockpit | Whether species means anything beyond culture (the Bible says it never determines temperament) |
| T7 | **Salvagers repurpose what ended us** | Everything you own was pulled from a hull and made to work | Scrap accretion and the reward gates: heft is literally the ruin bolted on; the codex build page names where a part family comes from | Every pickup, every gate, the build sheet | Whether repurposing is repair or repetition |

## 2. Beats per run

A run is one pass through the story, in order, and each stop tells a different piece. The order is the demo's run (DESIGN-V2 §14.1).

| Stop | Story beat | Carried by |
| --- | --- | --- |
| Title | An assembled machine under an enormous sky (the Bible's fantasy); the ancients' Cherenkov blue glows nowhere yet | Look and the idle band |
| Class select | Who you are and where you learned: species, culture, the kit as a tradition (T2, T6); the class motif plays whole once | The class row; Bible §4 sample barks as the one line per pilot |
| Stage 1, reactor-relic Warden | The first cause: heat, craters, vents; hazards that become terrain (T1); Fleet crews arriving with the clock (T4) | The Warden's Geiger tick and Ab pedal; terrain events; `threat_rose` adding the anvil |
| Moss, visit 1 | A repair culture at work; the shelf, the hook, the refusal (T3); the first "remembers you" line if there is history | The bay, the lounge sax, Moss's babble |
| Stage 2, swarm-hive Warden | The second cause: many identical things awaiting an operator (T1); the gorge's two material eras around the dam-works towers (T2, T7) | The formation chord; fragment 5; the landmark's blue beacon |
| Moss, visit 2 | The loop's variations; a heavier ball; the brass now under the level theme (T4) | Run state and the Fleet layers |
| Stage 3, the Mind's hand Warden | The third cause: something reads you back (T5); the class motif returned wrong | The inverted quote, the trigger icon, the counter |
| Moss, visit 3 | The top shelf if the ball is heavy enough: the gag and the growth goal are one thing (T3) | The heft lock |
| Brindle's arena | Inventory that woke; the three stages quoted in reverse; the Requisition's cracked plating showing a blue seam (T4, proposed callback C10) | G6, the weak-point mechanic |
| Summary | What the codex learned this run; what the Mind learned about you (T5) | The codex's `discovered_this_run()`, the run log |

Nothing in this table is a screen the player reads. Each beat is a thing seen, heard or fought.

## 3. Beats across runs

What the player learns and roughly when. Fragments are found, not scheduled, so the bands are expectations, not gates; `PROGRESSION.md` may attach milestones to them.

| Thread | First run | Runs 2 to 10 | Runs 10 to 50 |
| --- | --- | --- | --- |
| T1 cause | Three Wardens, three kinds of machine, one blue light. One or two fragments. | Fragments accumulate; the player notices every fragment names a different cause and fragment 2 names all three. The codex world page groups them by the family they were found near. | The player can argue any cause from the fragments and none is settled. Fragment 10 ("It was never one thing") is the late find. |
| T2 uplift | Species and culture names on class select. | The Caretaker Node plaque and the Roost proverb. Moss's shop is a fourth culture. | Nothing new is added, on purpose. Re-reading is the beat. |
| T3 Moss | The shelf, the hook, the refusal loop once. | Lines that remember: a death, a win, a class switch, skipped visits. The loop's variations run out of new beats around visit 15 and start repeating with a "you again" flavour. | The relent has been earned at least once. Moss's lines refer to how many times. |
| T4 Brindle | The Fleet as reinforcements; the arena; the reverse quotes. | Requisition tags read; the brass foreshadowing is noticed as Brindle's; fragment 9. | The blue seam in the Requisition's plating (C10, if built) reframes the arena as a second act, never stated. |
| T5 the Mind | One Warden that counters your habit, telegraphed. | The codex enemy page names the habit it countered. The player experiments to bait it. | If `PROGRESSION.md` takes the across-runs hook, the Mind's opening stance is seeded from the last run's most-used trigger, still telegraphed and bounded. |
| T6 animals | Three pilots visible through the glass. | Each class's culture explains its kit; the codex npc page stays reserved. | No canon roster; the Bible keeps it open. |
| T7 salvage | Heft grows and the shell shows it. | Part families read as where they came from on the build page. | Rare_plus Cores and Hearts read as the best of what was buried, without a word saying so. |

## 4. Never resolved, on purpose

- Which cause ended the humans, or whether it was one.
- Whether anyone uplifted the animals, and whether the Mind is the reason they can think or the reason the humans cannot.
- What Moss is, and where he learned to weld.
- Whether Brindle knew the housings would wake, and what he does after the arena.
- Whether the Mind's hands are the Mind, or an echo running without it.
- Whether the salvagers' repurposing is repair or the same mistake with better welds.

A writer who finds a beat that would settle one of these turns it into a beat that supports two readings, or drops it.

## 5. Callback index

DESIGN-V2 §13's standing rule: when a joke, reference, lore fact or motif lines up with a mechanic, build it, discovered not announced, logged in DESIGN-NOTES as "Callback:" and listed here so callbacks never collide. Status: **built** (in code on the base), **spec** (in DESIGN-V2, VISUAL-LANGUAGE or SOUND-STORY, not yet built), **proposed** (this board, for the owning unit to take or refuse).

| # | Callback | The mechanic it rides | How it is discovered | Owner | Status |
| --- | --- | --- | --- | --- | --- |
| C1 | The rice cooker: the stage clear cadences A7b9 to D with two "done" beeps (G2, Andrew's end-of-cycle reference) | Stage clear and the launch build resolving on landing | Heard on every clear | W5 | built |
| C2 | Brindle quotes each stage's motif in reverse order (G6): the arena replays your run backwards | Boss phases | Heard across the three phases | W5 | built |
| C3 | The Potion Seller homage: Moss refuses the top shelf until the next heft class; the lock is the pressure-dial icon with a notch | Heft classes and the shop | The loop, then the relent; codex entry "Too heavy for you" | W4, W1, vision keeper | spec (DESIGN-V2 §12) |
| C4 | The vault kick's octave leap: exit speed is ×1.8 and an octave is ×2 | Vault kick | Heard; the codex build page for Sable's vault names it | W3, W5 | spec (SOUND-STORY §2) |
| C5 | The Fleet motif is Brindle's Neapolitan lean (D Eb D) in miniature; each difficulty tick adds one of his layers | `threat_rose` and the level theme | Noticed by ear across a run, confirmed in the arena | W5 | spec (DESIGN-V2 §11 ruling 2) |
| C6 | The Mind's hands play your class motif back, inverted, one note wrong: the only hostile use of a class row | The Mind's adaptation telegraph | Heard the first time it counters you | W7, W5 | spec (DESIGN-V2 §11 ruling 3) |
| C7 | Tenacity's shimmer is the same cymbal choke as Rivet's ignored crowd control, because both mean "cannot be held" | Tenacity immunity | Heard by Rivet players first | W3, W5 | spec (SOUND-STORY §4) |
| C8 | Fragment 9, "Inventory does not wake", as the codex world entry for breaking a Warden before that stage's first difficulty tick (merged with PROGRESSION §6.3) | The difficulty clock and the par ghost | Found by being fast; read, then the Warden | vision keeper, W4 | spec (SOUND-STORY §5, PROGRESSION §6) |
| C9 | **Moss's shop bell is the rice cooker's two "done" beeps** on high D, so a purchase reads as a cycle finished; G2's jingle itself is untouched | Shop purchase | Heard on the first buy; a player who knows the clear jingle smiles | W5 | proposed |
| C10 | **The Requisition runs on a dug-up core.** Brindle's weak point is a cracked plate with a Cherenkov-blue seam behind it; danger stays HAZARD and brass still marks the owner (VISUAL-LANGUAGE §4) | Boss weak-point mechanic | Seen at phase 3 when the plating cracks; codex enemy page "Inventory" | W7, V1 | proposed |
| C11 | **Awaiting operator.** Bowling through a swarm formation scatters it; for 2 s the scattered drones follow the nearest moving mass, which is the ball, and can be led into another enemy for pins. While following they lose their blue seams, keep their hostile edge and hold one loose unison buzz panned to the ball, then go silent (primer reconciliation 7) | Pins (DESIGN-V2 §3) and the swarm's flocking | An odd combination: scatter, then ram; codex enemy page "Awaiting operator" quotes fragment 5 | W7, W5 | proposed |
| C12 | **Do not open until clear.** A pressure valve beside a reactor-relic vent, when smashed while the ball is outside the footprint, blows the vent early and leaves its crater as a ride | Pressure valves and terrain events (§9) | Digging: a valve where it should not be; codex world page quotes fragment 1 | W6, W7 | proposed |
| C13 | **What it learned about you.** The codex enemy page for the Mind's hand lists the three triggers you fired most this run, read from the same counts the adaptation reads; the summary screen shows the same three | The run log's trigger counts | The codex after a stage-3 Warden | W7, W1 | proposed |
| C14 | **Moss notices what you neglect** (BIBLE.md:384). If you leave the bay without buying and die in the next stage carrying scrap worth a shelf part, his next "remembers you" line says so | Run log: scrap at death, last visit's purchases | The next visit | W4, vision keeper | proposed |
| C15 | **"Give it a moment."** Kest's Bible bark is the codex build entry for the `kest_triple_catch` milestone (a detonation line catching 3 charges, PROGRESSION §2); completing the milestone is the discovery | The milestone's counter (`on_chain_detonation`) | Codex build page on the milestone | W3, progression | spec (primer reconciliation 5) |
| C16 | **"Measured twice. Firing once."** Rivet's bark is the codex entry for `rivet_full_blast` (a full-gauge blast hitting 6+) | The milestone's counter (`on_blast_release`) | Codex build page on the milestone | W3, progression | spec |
| C17 | **"Quiet part's over."** Sable's bark is the codex entry for `sable_vault_chain` (3 vault kicks within 6 s) | The milestone's counter (`on_vault_kick`) | Codex build page on the milestone | W3, progression | spec |
| C18 | **The landmark hums home.** The dam-works tower's blue beacon carries a sub pulse on bar 1 of each phrase, panned toward it, louder as you near it: the ancient light is also the way home | Orientation from every layer (§9) | Noticed by ear when lost | W6, W5 | Wave 3 must (SOUND-STORY §7) |
| C19 | **Strike, Spare, Turkey.** Bowling scores as codex build entries for pin chains (PROGRESSION §6.2) | Pins and `ten_pin` | The codex names it after it happens | W4, progression | spec |
| C20 | **"Everything that flies was taught by something that fell."** Fragment 6 is Kest's `kest_taught_by_falling` milestone entry (PROGRESSION §6.4) | A rocket jump within 1 s of a 20 m drop | Codex after the jump | W3, progression | spec |
| C21 | **The valves.** Pressure levels as pressure valves on the bay's exit wall, smashed open on the way out; the valve's smash womp and hiss, never the danger tick (PROGRESSION §6.5) | The contraption valve grammar (§9) | Only visible in the bay | W4, W6 | spec, later than the demo |

**The title's beacon (reconciled 2026-09-27).** The landmark's Cherenkov light is dark on the title of a fresh profile, so the first blue belongs to stage 1's Warden; after the first win the title's beacon lights, because the world remembers too (a `PROGRESSION.md` hook on `runs.won`).

Collision rules: no two callbacks share a mechanic as their sole rider (C11 and C13 both touch the swarm and the Mind but ride pins and the run log respectively); no callback uses a class instrument for a hostile or a hostile timbre for the player; every callback keeps the danger area HAZARD and the words on the HUD at zero.

## 6. Hooks for PROGRESSION.md

This board designs no progression. It names the records that exist and the milestones a progression designer could hang lines or unlocks on.

**Records that exist today.** `run_log.gd` writes one cumulative record per death and per run end to `runs.ndjson`: class, outcome (won, died, abandoned), stages with their Warden and event outcomes, deaths, the arena block, and the codex ids discovered this run. `codex.gd` keeps `codex.json` across runs: discovered entries by category. Nothing else persists.

**"Moss remembers you" keys.** Each of Moss's memory lines (`SOUND-STORY.md` §8) is keyed to one of these; `PROGRESSION.md` may add keys, and each new key needs a line from the vision keeper.

| Key | Read from | Line family |
| --- | --- | --- |
| `first_visit` | no record | the welcome |
| `died_last_run` and the class matched | last record's outcome and class | the death line |
| `won_last_run` | last record's outcome | the win line |
| `class_changed` | last record's class against this run's | the new-pilot line |
| `skipped_visits >= 3` | proposed counter in the run record (visits offered against entered) | the bell line |
| `relented_before` | proposed: codex entry "Too heavy for you" discovered | the returning-heavy line |
| `neglected` (C14) | proposed: scrap at death against the shelf price at the last visit | the neglect line |
| `refused_before` | `profile.json` `moss.refusals` (PROGRESSION §8) | the loop's variation index and the "back for the hook" line |
| `sold_back` | `profile.json` `moss.sold_families` | the shelf bias line |
| `neglected_ability` | `profile.json` `moss.neglected` per pilot (the ability used least) | the neglected-key line |
| `fragment_carried` | a `world` codex id discovered this run | the "off my bench" line |
| `pressure` | `profile.json` `pressure.selected` (later) | no line; the valves' state |

This is the one Moss key table (primer reconciliation 4): these names key the lines in `SOUND-STORY.md` §8, and `PROGRESSION.md` §3 and §8 own where each fact persists under its `moss_*` id.

**Mastery milestones a thread could mark.** Seen all three family Wardens in one run; read N world fragments; won a run; reached heft class 4; broke free of a chain by your own action; baited the Mind's counter; scattered a formation into a pin (C11). Each is a codex discovery today or a one-line addition to the run record, and each is a natural place for a line, a title-screen change or an unlock that `PROGRESSION.md` owns.

## 7. Questions for Andrew

At most three, each with the default the board uses until he rules.

1. **What is Moss?** The Bible leaves the species open (BIBLE.md:384). Default: unseen. Moss is a voice and a pair of hands behind the workbench shutter; the shutter has a service hatch at ball height. It keeps T2's ambiguity, spares a hero asset, and makes his first reveal a later-run beat if Andrew ever wants one.
2. **Does the Mind learn across runs?** Default: within a run only for the demo. The across-runs seed (the last run's most-used trigger sets the stage-3 Warden's opening stance, still telegraphed and bounded) is left as a `PROGRESSION.md` hook, off unless he wants it.
3. **How does the arena end?** Default: Brindle is routed, the summary plays, and one Cherenkov flicker crosses the dug-up housings behind the wreck (C10's seam), so the second act is felt and never stated. The alternative is a clean victory with nothing waking.
