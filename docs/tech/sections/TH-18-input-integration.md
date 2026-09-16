# TH-18: Input-device and focus integration

## Sources

This section implements [TH-18](../../../BACKLOG.md#th-18) revision 1 at source base `bb97c4111d1e7b2dd40cae575eccde17878b07c5`. Every line reference below is a line at that base. It is the engineering contract TH-12 and PD-02 route device work to: it maps physical keyboard, mouse and controller actions onto the gameplay and interface intents the admitted sections already name, fixes what device loss, application focus loss and pointer capture must do so that neither navigation nor a lost device can cast, requires full coverage of gameplay and menus by both device classes, and records every hardware claim as unqualified with the future native physical test each transition needs. It fixes no binding, no controller layout, no glyph, no dead zone, no sensitivity, no repeat value, no supported-device list and no qualification. It adds no module, no command, no published result, no dependency edge and no durable field.

A citation written as `TH-12 FI-08 line 139` means the rule whose ID is `FI-08` is at line 139 of that section at this base; a citation written as `HF-04a line 92` names a line with no rule ID of its own. Dependency bytes are hashed below so a reader can prove the cited bytes.

- Bible [§ 6. Core Systems](../../../BIBLE.md#6-core-systems), file bytes SHA256 `98e19c20d6b0247af5b8b573bf6b5e3c1bdcfb2958dba11def8f834f8d9d01e3`, cited by system page. [Movement, camera and active aim](../../../BIBLE.md#movement-camera-and-active-aim): line 481 makes ordinary movement always available and places rolling, jumping, rebounds and impacts in the core experience; line 483 fixes camera-relative movement with active and focused aim, states that mouse control is demonstrated in the orchard, that standalone PC and controller are the production target, and that physical controller feel still requires play evidence. [Abilities, ultimates and combat rhythm](../../../BIBLE.md#abilities-ultimates-and-combat-rhythm): line 501 has low-cooldown abilities used while moving; line 503 has ultimates charge through useful class actions. [Four slots and milestone progression](../../../BIBLE.md#four-slots-and-milestone-progression): lines 533 to 536 are the four slots and their access; line 544 states that the prototype's input arrangement must be mapped deliberately into the four-tree design and that a deployment action creates no fifth slot. [Runs, regions, exits and saves](../../../BIBLE.md#runs-regions-exits-and-saves): line 584 states that pausing the dashboard is not a completed-level checkpoint. [HUD, dashboard and settings](../../../BIBLE.md#hud-dashboard-and-settings): line 590 has the combat HUD answer aim and available actions; line 596 gives the dashboard its five regions; line 602 names sensitivity among the settings, requires keyboard navigation, focus restoration and pointer recapture to avoid accidental casts, and states that controller mappings need hardware evidence.
- [adr/TADR-001-engine-language-platforms.md § Decision](../../../adr/TADR-001-engine-language-platforms.md#decision), file bytes SHA256 `84d0873543acb547d6ffd860ab51659b3a634ab0429f310bc41c7951c822f4e9`. Line 23 recommends Godot 4.7.2 with typed GDScript, names Windows 11 x64 and Linux x64 as the initial production qualification targets, and requires that **keyboard/mouse and controller must cover the full game and menus**. Line 39, under [Later qualification and reconsideration](../../../adr/TADR-001-engine-language-platforms.md#later-qualification-and-reconsideration), requires an explicitly authorized native slice to qualify focus/input transitions and real controller operation before wider implementation.
- [docs/adr/0005-caster-input-and-dashboard.md](../../adr/0005-caster-input-and-dashboard.md), file bytes SHA256 `b570704c73a14729c3e62eda1bfebd8066da1bc09e0cc840f3914f40e42adb21`, read as browser-proof evidence and not as native qualification. Line 11 gives browser input orchestration focus, pointer capture, physical key state and dashboard navigation, and gives the simulation cast preparation and cancellation. Line 13 has dashboard entry pause, cancel prepared attacks, clear held controls and release capture, and resume only after valid mouse capture or a supported non-mouse control path, with a retry click that never doubles as a shot. Line 15 records the browser bindings, including Escape cancelling targeting. Line 19 states that held-key clearing and simulation cancellation solve different problems and neither is optional. Line 21 states that synthetic events do not prove capture and a gamepad mapping does not establish hardware usability.
- [HF-03a: Module ownership and owned records](HF-03a-module-map.md), section bytes SHA256 `95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc`. Line 27 defines `Values` and limits an injected reference to listed commands or readers. Lines 31 to 37 are the module table every module, command, published result and record below is taken from: line 31 Session (`handle_focus_or_modal_change`, `request_pause`, `resume`, `request_preferences_change`), line 32 Encounter (`submit_action`, `cancel_prepared`, `read_committed_results`), **line 36 InputAdapter**, which imports the engine physical input and focus interfaces, exposes `sample_input`, `read_frame`, `clear_physical_input` and `set_input_context`, and publishes `InputFrame`, `ActionRequest` and `FocusOrModalRequest` with no committed cast, damage or gameplay pause decision, and line 37 Presentation. Line 39 fixes dependency direction. Line 43 leaves concrete payload schemas with their producer cards. Line 45 places input, modal and pause coordination in `SessionControl`. Line 46 places prepared actions in `EncounterState`. Line 50 gives `PhysicalInputState` held controls, prior samples and edge detection, and `InputContextState` the routing context and unpublished buffers, and states that clearing physical input cannot mutate a prepared action. Line 51 places the camera and UI display state in `PresentationState`.
- [HF-03b: Dependency edges and interface walkthroughs](HF-03b-dependency-graph.md), section bytes SHA256 `7c29b6ee0fcff3749c0d30d69b3977d529732338dd794ee0019d6a6a1392d183`. Lines 27 to 42 are edges D01 to D16; the edges used below are D01 at line 27, D04 at line 30, **D05 at line 31** (`set_input_context` and `clear_physical_input`; read `ActionRequest` and `FocusOrModalRequest`), D06 at line 32 and D08 at line 34. Line 44 states that `sample_input` has no module caller and that the engine physical input and focus interfaces drive it. Line 52 records that Presentation holds no edge to Session, Encounter or CollisionQueries. Line 74 limits a signal connection to the module holding the edge. Line 79 states that a UI control records a `UiRequest` value and calls nothing. Line 83 defines a `local` step. Line 94 is register entry DF-04.
- [HF-04a: Fixed tick, pause and encounter lifecycle](HF-04a-runtime-lifecycle.md), section bytes SHA256 `e0058ee153804188424a753f1d4af8a3dc9fee4b45e7c82bc6625df7f80fe43d`. Line 20 makes Encounter the only gameplay-time owner and line 22 leaves `h` unset. **Line 24**, as revised under FR-06 (TRACKING EV-0364), makes the control drain non-advancing, changing only owned control, prepared and inbox state, unable to decrement a cooldown, move an actor, consume gameplay randomness, apply damage or release a cast, and states that **gameplay randomness here means the encounter's `EncounterRandomState`**. Line 26 serializes every operation with the owned tick, latches a request raised during a tick, and states that no later input event may turn a focus-loss clear into a release edge. Line 46 is F-INPUT, line 47 F-CONTROL (focus and window notifications), line 51 **F-OTHER**, under which any engine callback not named needs an existing owner and interface and explicit classification before implementation. Line 53 keeps the drain, input clearing and menu handling callable during a pause. Lines 61 and 62 are P0 and P1. Line 77 lets continuous samples replace older ones, forbids discrete edges from disappearing or accumulating into a post-pause burst, invalidates the old generation on a focus, modal or input-context change and keeps cancellation explicit. Line 79 holds the last committed state under a pause. **Lines 87 to 90 are O1 to O4.** **Line 92** fixes O1, O2, O3 for focus loss, dashboard entry and any modal transition out of gameplay, latches a mid-tick notification, makes capture release and restoration InputAdapter's input-context work coordinated by Session, keeps a rejected capture paused with a retry that cannot become a shot, admits a supported non-mouse input path as resume readiness without establishing hardware support, and states that regaining focus alone never resumes gameplay. Line 94 refuses a bare pause as accidental-cast protection. Line 102 routes control latency to HF-02's `B-load` and `N-load`. Walk T2 at lines 141 to 146 is focus loss during preparation.
- [HF-07a: Save envelope and preferences record](HF-07a-save-envelope.md), section bytes SHA256 `dfcd6a98d2fe8d07f69ff5bb336f563192604ad383a106b05902d9a60ea87d06`, with its [CSV copy](HF-07a-save-envelope.csv) bytes SHA256 `96212b0087f2cd971e272078679e39e3ba24417d2ce8d01f92b312e4dc827941`. The CSV's seven groups are the closed durable surface; its `preferences` group, rows 66 to 71, is `preferences.schema_version`, `preferences.sensitivity`, `preferences.sound`, `preferences.ui_scale`, `preferences.impact_shake` and `preferences.reduced_motion`, and no row names a binding, a device, a controller or an input context. Line 185 is `preferences.sensitivity`, aim and look sensitivity, whose range, default and axis split are unresolved. Line 205 states the record's shape. Line 271 lists those parameters as unresolved without a question ID. **Line 272 states that input rebinding is deliberately not a preferences field** and that adding one requires a product decision no source has made.
- [TH-01: The complete run loop](TH-01-complete-loop.md), section bytes SHA256 `7557b49def4ca418b4dc290fbec9ebde91a2da949574167793403a075f4b40e3`. RL2 at line 36, RL4 at line 38 and RL9 at line 43; line 45 defines Paused as O3 applied to RL2, staging nothing and no checkpoint, as HF-07b SEAM-7 fixes. IF-14 at line 87 routes `submit_action` at RL2. **IF-19 at line 92** reads UI requests at RL4, RL5, RL6, RL9 and Paused RL2 for menu and navigation requests, and **IF-26 at line 99** shows diagnostics at RL3 to RL9 and at Paused RL2, both as repaired at TRACKING EV-0365. IF-31 at line 104 handles focus or a modal change in any ticking state. **IF-32 at line 105** admits a preference change at RL4 and RL9 only. IF-33 at line 106 samples input. IF-35 at line 108 reads the action request and the focus or modal notification before routing either. LO-12 at line 139 keeps rendering and UI out of the loop.
- [TH-02: Movement, camera and active aim](TH-02-movement-camera-and-active-aim.md), section bytes SHA256 `5a1cff2277b4e6857f520b0241be226f4f861c711df3bc4c3904e7f9c2e89d0c`. MA-01 to MA-03 at lines 34 to 36 are the supported and airborne movement states; **MA-06 at line 39** is free active aim and **MA-07 at line 40** focused aim, left when the focus request is released or the input generation is invalidated. Line 45 defines neutral re-arm. MI-01 at line 74 samples movement, aim and focus controls; MI-02 at line 75 is O1 with the input context; MI-03 at line 76 reads the requests; MI-05 at line 78 captures the frame; MI-06 at line 79 integrates the aim pose. MO-02 at line 119 has Encounter integrate aim samples into the authoritative aim pose; MO-03 at line 120 keeps the camera downstream of gameplay. MO-14 at line 131 and MO-15 at line 132 are the drain and edge rules for movement. ME-05 at line 186, ME-10 at line 191 and ME-11 at line 192 are the held-control, stale-generation and mid-run preference cases. MF-06 at line 204 is denied capture. MP-05 at line 219 names standalone PC and controller as production input targets; MP-07 at line 221 leaves the defensive response set unset under Q-P21; MP-21 at line 235 leaves aim sensitivity, focused-aim framing and inversion unset; MP-24 at line 238 leaves controller mappings, remapping and accessibility unset under Q-P30.
- [TH-04: Abilities, ultimates and combat rhythm](TH-04-abilities-ultimates-and-combat-rhythm.md), section bytes SHA256 `bf4e87d79d33f9709d4784cacf6015ce3506518d7f3bfa5a9c1940561b59de27`. AS-01 to AS-04 at lines 39 to 42 are the weapon, main hero skill, mobility and ultimate slots; line 44 leaves the prototype action-to-slot mapping to Q-P11. AA-01 at line 52 keeps availability Encounter's; AA-07 at line 58 makes a refusal cost nothing. AV-05 at line 68 is charging and **AV-06 at line 69** is prepared, left when a release edge is captured, O2 discards the preparation or the action becomes illegal. AI-02 at line 127 reads the prepare, release or activation request; AI-07 at line 132 admits a prepare; AI-28 at line 153 is O2. **AO-08 at line 201** states that cancellation is not an activation. AP-01 at line 267 is four build slots; AP-23 at line 289 leaves the input-to-slot mapping unset under Q-P11; AP-37 at line 303 leaves accidental-activation prevention scope unset under Q-P30.
- [TH-12: HUD, dashboard and settings](TH-12-hud-dashboard-and-settings.md), section bytes SHA256 `84d9a2550066ee215c107cad67724523cdca5ee5f423826d0c986bf5a9020d28`. Its input-class table at lines 40 to 46 is PD-02's. HD-01 at line 74 gives the HUD no focusable control. SO-02 at line 116, **SO-03 at line 117** (preferences admitted at RL4 and RL9 only) and SO-04 at line 118 are the settings rules. **FI-01 to FI-14 at lines 132 to 145** are the focus-restoration and input-clearing rules this section extends to devices, among them FI-04 at line 135, FI-08 at line 139, FI-09 at line 140, FI-10 at line 141, FI-11 at line 142 and FI-12 at line 143. UI-01 to UI-22 at lines 153 to 174 are its interface rows, of which UI-02 at line 154, UI-05 at line 157, UI-09 at line 161, UI-10 at line 162, UI-11 at line 163, UI-12 at line 164, UI-15 at line 167 and UI-22 at line 174 name intents below. **Line 218 is the seam**: device loss and recovery, full keyboard and controller coverage of gameplay and menus, focus return across devices and any device-level capture protocol are TH-18's. UP-02 at line 258, UP-15 at line 271, UP-16 at line 272 and UP-17 at line 273 are parameter rows reused below. Walks UN at lines 304 to 313, UM at lines 332 to 337 and UR at lines 343 to 349 are the keyboard and controller navigation, close and resume walks.
- [PD-02: Production interface states and acceptance](../../product/sections/PD-02-interface-states.md), section bytes SHA256 `7a17619a2949ed8e57da9541a54dab046c504e9d8eb592d1f08a5d92ecdf2905`, the admitted product surface. The input-class vocabulary is at lines 44 to 50. Views VW-1 to VW-6 are at lines 60 to 65. Focus and recapture requirements FP-01 to FP-14 are at lines 105 to 118; **FP-14 at line 118** states controller support as a requirement claimed nowhere and routes full coverage, device loss and focus return to TH-18; line 120 states that the accidental-cast guarantee is structural. IP-02 at line 129 and IP-04 at line 131 are the controller-mapping and focus-order parameters.
- Godot 4.7 documentation retrieved through Context7 library `/websites/godotengine_en_4_7` between `2026-09-16T18:50:54Z` and `2026-09-16T18:51:27Z`; each command and its output are retained under `artifacts/local/tasks/TH-18/ctx7/`. Only these retrieved statements are cited: [`Input.get_connected_joypads()`](https://docs.godotengine.org/en/4.7/classes/class_input.html) returns the device IDs of all currently connected joypads; a C# page shows a handler attached to `Input.Singleton.JoyConnectionChanged` ([C# differences](https://docs.godotengine.org/en/4.7/tutorials/scripting/c_sharp/c_sharp_differences.html)); by default controller inputs can be captured by all windows, including unfocused ones, and `ignore_joypad_on_unfocused_application` ignores joypad input while the application is not focused ([controllers page](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html)); `InputEvent.is_echo()` is true only for a repeated `InputEventKey`, and the key repeat delay and speed can be changed or disabled by the user in the operating system ([InputEvent](https://docs.godotengine.org/en/4.7/classes/class_inputevent.html)); `MOUSE_MODE_CAPTURED` hides the cursor and locks it to the window centre for relative motion ([Input](https://docs.godotengine.org/en/4.7/classes/class_input.html)); a Control receives focus enter and exit notifications ([custom GUI controls](https://docs.godotengine.org/en/4.7/tutorials/ui/custom_gui_controls.html)). Two retrieval limits are recorded rather than filled from memory: the connection signal's parameters and delivery timing were not returned, and the application and window focus notification constants were not returned, so the focus notification family below is cited from HF-04a line 47 only. These pages describe engine mechanisms; none qualifies this contract.
- The question register entries this section exposes and does not answer: [Q-P30](../../../BACKLOG.md#q-p30), [Q-P32](../../../BACKLOG.md#q-p32) (its bounds; its recorded reduced-motion setting and aim-point ruling at TRACKING EV-0248 and EV-0284 are read as given), [Q-P21](../../../BACKLOG.md#q-p21), [Q-P11](../../../BACKLOG.md#q-p11), [Q-E01](../../../BACKLOG.md#q-e01), [Q-E03](../../../BACKLOG.md#q-e03) and [Q-E04](../../../BACKLOG.md#q-e04). No proposal recorded on an open question is assumed anywhere below.
- Concurrent cards in the Handoff-8 sprint (TRACKING EV-0367), none admitted at this base and none cited with bytes: PD-03, TH-19, SC-01, SC-02, SC-03, SC-04, SC-05, SC-06 and SC-08. The three with a seam to this section are stated under [Seams stated and not decided](#seams-stated-and-not-decided) from their BACKLOG card text alone.

## Contract

### What this section fixes

It fixes twelve physical action kinds across two device classes; fifteen intents, each tied to a TH-02, TH-04 or TH-12 row by ID and each covered by both device classes; eight coverage rules; eight device-loss rules; eight focus and clearing rules; five pointer-capture rules; eighteen interface rows, each naming one HF-03a command, published result or owned record on one HF-03b edge; fourteen transitions, each naming a future native physical test; fourteen native physical tests; eight hardware rows, every one unqualified; ten edge cases; seven failure modes; thirty tunable parameters, each carrying a source line or a question ID; and three paper traces with a named outcome each.

It fixes no key, button, axis or glyph for any intent, no controller layout, no dead zone, no trigger threshold, no sensitivity range, no repeat delay or rate, no supported-device list, no controller count, no latency and no hardware qualification. Where an intent needs one of those, the rule below names what must be true of it and the parameter table routes the value to its question.

### Vocabulary

**Device class** is either `keyboard/mouse` or `controller`, the two classes TADR-001 line 23 requires to cover the full game and menus. **Physical action kind** is the shape of a physical input a class can produce, never a specific key, button or axis. **Intent** is what a physical action may become, and it carries PD-02's **input class** (lines 44 to 50) unchanged: `navigation`, `ui-request`, `control`, `gameplay` or `display`, of which only `gameplay` may reach `submit_action`, at RL2 only. **Bound device** is a device from which InputAdapter recorded a held control, a sample or an edge in the current input-context generation; the record is InputAdapter's `InputContextState` routing context (HF-03a line 50). **Neutral re-arm** is TH-02's modifier at line 45 and HF-04a O1 at line 87.

### Physical action kinds

| ID | Device class | Physical action kind | What it can supply | Source |
| --- | --- | --- | --- | --- |
| IK-01 | keyboard/mouse | Relative pointer motion while the pointer is captured | A continuous two-axis aim sample | BIBLE line 483; ADR 0005 line 11; Godot `MOUSE_MODE_CAPTURED` |
| IK-02 | keyboard/mouse | A mouse button press and release while the pointer is captured | A held control and its press and release edges | BIBLE line 483; ADR 0005 line 11 |
| IK-03 | keyboard/mouse | A key press and release | A held control and its press and release edges | BIBLE line 602; HF-03a line 50 |
| IK-04 | keyboard/mouse | A held set of keys composing a direction | A continuous two-axis direction sample | BIBLE line 483; HF-04a line 77 |
| IK-05 | keyboard/mouse | Pointer position and a button activation over a visible, uncaptured cursor | A focus target and an activation edge in an interface view | BIBLE line 602; TH-12 FI-10 line 141 |
| IK-06 | controller | An analog two-axis stick | A continuous two-axis sample | BIBLE line 483; TADR-001 line 23 |
| IK-07 | controller | A digital button press and release | A held control and its press and release edges | TADR-001 line 23; HF-03a line 50 |
| IK-08 | controller | An analog trigger read as a held control | A held control and its press and release edges once an actuation threshold is crossed | TADR-001 line 23; DP-09 |
| IK-09 | controller | A digital directional pad | A discrete direction edge, or a held direction | TADR-001 line 23; HF-03a line 50 |
| IK-10 | keyboard/mouse | A keyboard or mouse connection change | A device-loss or device-connected observation | TADR-001 line 23; DP-27 |
| IK-11 | controller | A controller connection change | A device-loss or device-connected observation | Godot `Input.get_connected_joypads()` and `JoyConnectionChanged` |
| IK-12 | both | An application or window focus change reported by the operating system | A focus-lost or focus-regained observation | HF-04a F-CONTROL line 47; HF-03a line 36 |

### Intents and their device coverage

Every intent row names the admitted row IDs it is taken from; this table adds no intent those rows lack. `States` is where the intent is admitted as its class; elsewhere the physical action produces nothing or is refused and shown. The two coverage columns name physical action kinds, not bindings; which specific key, button or axis serves each intent is DP-07's. Every coverage cell is a requirement, and every hardware claim behind it is unqualified (HQ-01 to HQ-08).

| ID | Intent | Input class | Vocabulary rows | States | Keyboard/mouse coverage | Controller coverage |
| --- | --- | --- | --- | --- | --- | --- |
| IN-01 | Move, camera-relative | gameplay | TH-02 MA-01, MO-02 | RL2 | IK-04 | IK-06 |
| IN-02 | Aim, free active aim | gameplay | TH-02 MA-06, MO-02 | RL2 | IK-01 | IK-06 |
| IN-03 | Focused aim, held | gameplay | TH-02 MA-07 | RL2 | IK-02 or IK-03 | IK-07 or IK-08 |
| IN-04 | Jump or air action | gameplay | TH-02 MA-02, MA-03 | RL2 | IK-03 | IK-07 |
| IN-05 | Weapon action: prepare, release or activate | gameplay | TH-04 AS-01, AV-06, AI-02 | RL2 | IK-02 | IK-07 or IK-08 |
| IN-06 | Main hero skill activation | gameplay | TH-04 AS-02, AI-02 | RL2 | IK-02 or IK-03 | IK-07 or IK-08 |
| IN-07 | Mobility activation | gameplay | TH-04 AS-03, AI-02 | RL2 | IK-03 | IK-07 |
| IN-08 | Ultimate activation | gameplay | TH-04 AS-04, AV-05, AI-02 | RL2 | IK-03 | IK-07 |
| IN-09 | Open the dashboard or pause from gameplay | control | TH-12 UI-02, FI-01 | RL2 | IK-03 | IK-07 |
| IN-10 | Move interactive focus | navigation | TH-12 UI-10, UN.7, UN.8 | Paused RL2, RL4, RL5, RL6, RL9 | IK-03 or IK-05 | IK-09 or IK-06 |
| IN-11 | Switch between the dashboard's views | navigation | TH-12 UP-02, UI-10 | Paused RL2, RL4, RL5, RL6, RL9 | IK-03 or IK-05 | IK-07 |
| IN-12 | Activate the focused control, including an equipment change, a respec request, an offer answer and a held-transition retry | ui-request | TH-12 UI-10, UI-11, UI-12, UI-22, DS-5 | Paused RL2 for menu requests, RL4, RL5, RL6, RL9, Held | IK-03 or IK-05 | IK-07 |
| IN-13 | Adjust a setting's value | ui-request | TH-12 SO-02, SO-03, UI-15 | RL4, RL9; shown refused under Paused RL2 | IK-03 or IK-05 | IK-09 or IK-06 |
| IN-14 | Close a view or go back without resuming | navigation | TH-12 UM.1, FI-09 | Paused RL2, RL4, RL5, RL6, RL9 | IK-03 or IK-05 | IK-07 |
| IN-15 | Resume gameplay, including a capture retry on the keyboard/mouse path | control | TH-12 UI-05, FI-08, FI-10 | Paused RL2 | IK-03 or IK-05 | IK-07 |

Two candidate intents are deliberately absent. A baseline defensive response is not an intent at this base because TH-02 MP-07 leaves the set unset under Q-P21 (DP-19). A player-initiated cancel of a prepared action without pausing, which the browser proof binds (ADR 0005 line 15), is not in TH-04's availability vocabulary, whose AV-06 is left only by a release edge, O2 or illegality; adding one is a TH-04 revision under the input-to-slot mapping Q-P11 owns (DP-18).

### Coverage rules

| ID | Rule | Source |
| --- | --- | --- |
| IC-01 | Both device classes cover every intent. Each of IN-01 to IN-15 names a keyboard/mouse kind and a controller kind, and no gameplay intent or menu view is reachable by one class only. A pointer is never required to reach a control, and a controller is never required to aim. | TADR-001 line 23; BIBLE line 483; PD-02 FP-14 line 118 |
| IC-02 | Coverage is stated in physical action kinds. The specific key, button, axis and glyph per intent, the controller layout and any remapping are unset; a binding chosen by an implementation is a proposal until Q-P30 is answered and is never a production default. | BIBLE line 602; TH-02 MP-24 line 238; TH-12 UP-15 line 271 |
| IC-03 | One physical control maps to at most one intent per input context. A control that serves a gameplay intent in the gameplay context may serve a menu intent in the menu context, but a single press never becomes two intents across the context change: the press that opens a view is consumed as UI input and produces no gameplay release edge, and the press that resumes is consumed the same way. | HF-04a lines 87, 90; TH-12 FI-04 line 135 |
| IC-04 | Interactive focus is single and shared across device classes. Pointer activation, keyboard navigation and controller navigation move and act on the same focus owner, so a player who changes class in a view finds focus where the other class left it and never two focus positions. Whether pointer hover alone moves that focus is DP-16's. | TH-12 FI-11 line 142; PD-02 FP-09 line 113; Godot Control focus notifications |
| IC-05 | Menu navigation reaches every focusable control of every view with directional input from either class, entering on and restoring to a named, visible control. Which control and in what order is DP-17's. | PD-02 FP-09 line 113; TH-12 FI-11 line 142 |
| IC-06 | Samples from both classes are admitted in one gameplay context. Continuous samples may replace older unconsumed samples, and each discrete edge from either class is consumed at most once. How continuous samples from two bound classes combine is DP-13's and is not chosen here. | HF-04a lines 62, 77; TH-02 MO-15 line 132 |
| IC-07 | A repeated key event is never a gameplay edge. An edge is a transition from an observed neutral sample to a pressed one, and the operating system's key repeat, which the user may change or disable, produces no such transition. Held-direction repeat for menu navigation on either class is DP-12's. | HF-03a line 50; HF-04a line 77; Godot `InputEvent.is_echo()` |
| IC-08 | The only saved input setting is `preferences.sensitivity`, whose axis split, and therefore whether pointer and stick sensitivity are separate, is unresolved. Input rebinding is not a preferences field, so no settings view offers one; adding one is an HF-07a revision, not an implementation choice. | HF-07a lines 185, 271, 272; CSV row 67; TH-12 SO-04 line 118 |

### Device loss and connection

| ID | Rule | Source |
| --- | --- | --- |
| DL-01 | InputAdapter alone observes a device connection change, through `sample_input` driven by the engine's physical input interfaces. No other module holds the observation, and no module calls `sample_input`. | HF-03a line 36; HF-03b lines 44, 94 |
| DL-02 | **Loss is not release.** When a device is lost, InputAdapter drops that device's held controls and continuous samples from `PhysicalInputState` without deriving a release edge from them, so a prepared action held on the lost device is never released by the loss, whether or not a tick reads a frame before Session drains. | HF-04a lines 26, 87; TH-04 AV-06 line 69; HF-03a line 50 |
| DL-03 | InputAdapter publishes the loss as a `FocusOrModalRequest` that identifies a device loss, the device class and whether the lost device was bound. That result is the only one of InputAdapter's published results that reaches Session outside a gameplay action; this contract names no payload field and adds no published result. | HF-03a lines 36, 43; HF-03b line 31 |
| DL-04 | **Losing a bound device during RL2 is a transition out of gameplay.** Session reads the request before routing any action request, and runs O1, then applied O2, then O3 before any interface is shown, exactly as for focus loss. A notification arriving mid-tick is latched and the sequence completes at the first non-reentrant control boundary before another tick. The pause stages nothing and is not a checkpoint. | HF-04a lines 26, 90, 92; TH-01 IF-35 line 108, line 45; BIBLE line 602 |
| DL-05 | A control first observed pressed after its device connects produces no edge in any input class until it has been observed neutral, so plugging in or re-pairing a device with a control held cannot navigate, activate, resume or fire. | HF-03a line 50; HF-04a line 87; TH-02 line 45 |
| DL-06 | A device connecting or reconnecting never resumes gameplay by itself. InputAdapter publishes the connection as a `FocusOrModalRequest`; Session keeps the pause, and leaving it takes a deliberate `control` action through O4. | HF-04a lines 90, 92; TH-12 FI-09 line 140 |
| DL-07 | Losing a device that is not bound changes no gameplay state and requires no drain; InputAdapter updates its own records only. Whether the player is told, and how, is DP-14's; while unpaused at RL2 no diagnostic is admitted, because TH-01 IF-26 admits one at RL3 to RL9 and Paused RL2 only. | TH-01 IF-26 line 99; HF-03a line 50 |
| DL-08 | The engine delivery of a connection change is not named in HF-04a's callback families, so it falls under F-OTHER, which grants no gameplay-time permission and requires an existing owner and interface and explicit classification before implementation. This section supplies the owner (InputAdapter), the interface (`sample_input`, then `FocusOrModalRequest` on D05) and the required allowed work, which is exactly F-INPUT's: InputAdapter updates its own physical and input-context records and nothing else. Naming the delivery in HF-04a's table is an HF-04a revision this section does not perform; dependent implementation is gated until it is made. | HF-04a lines 46, 51 |

### Focus, modal clearing and prepared cancellation

| ID | Rule | Source |
| --- | --- | --- |
| FC-01 | Application or window focus loss, dashboard or pause entry, and bound-device loss are the three transitions out of gameplay this section routes. Each performs O1, then O2, then O3, and the interactive view is shown only after that sequence returns. | HF-04a lines 87 to 89, 92; TH-12 FI-01 line 132; DL-04 |
| FC-02 | **Opening a modal clears a prepared action before any commit.** O2 discards uncommitted preparation and old-generation requests at a serialized control boundary before the view is shown and before another tick, with no cooldown, charge, random draw, damage or cast. A preparation cannot survive into a view and cannot be committed by the view's first navigation press. | HF-04a lines 24, 88; TH-04 AV-06 line 69, AO-08 line 201 |
| FC-03 | O1 and O2 are both required. O1 clears held and pending physical state and advances the generation but cannot cancel a preparation; O2 cancels the preparation but clears no physical state; a bare pause does neither. | HF-04a lines 87, 88, 94; ADR 0005 line 19; TH-12 FI-05 line 136 |
| FC-04 | Aim is released with the generation. The committed aim pose is held, not moved, by the drain; MA-06 and MA-07 are left at the next eligible C-TICK because the input generation their samples belonged to was invalidated. No drain step changes an aim pose. | TH-02 MA-06 line 39, MA-07 line 40; HF-04a lines 24, 79 |
| FC-05 | **While the application does not hold operating-system focus, no device's input becomes any input class.** Controller input reaches unfocused windows by default, so InputAdapter admits none of it as navigation, a UI request, a control action or gameplay; whether the engine property or InputAdapter's own gate enforces this is an implementation choice qualified by NT-10. | Godot controllers page, window focus; HF-04a line 92; PD-02 FP-07 line 111 |
| FC-06 | Regaining focus returns the player to the paused interface and never resumes gameplay by itself. Every control observed held when focus returns produces no edge in any input class until observed neutral, as DL-05 requires for a connection. | HF-04a line 92; TH-12 FI-09 line 140; DL-05 |
| FC-07 | Leaving a view restores interactive focus to a named, visible, non-committing control, whichever device class closed it, and closing is never resuming. | TH-12 FI-11 line 142, FI-09 line 140; PD-02 FP-09 line 113 |
| FC-08 | At RL4, RL5, RL6 and RL9 nothing is ticking and no encounter preparation exists, so focus loss or device loss there performs no O2 and no pause; InputAdapter updates its own records, FC-05 to FC-07 and DL-05 still apply, and Session may show a status diagnostic, which IF-26 admits there. | TH-01 RL4 line 38, RL9 line 43, IF-26 line 99, IF-31 line 104 |

### Pointer capture

| ID | Rule | Source |
| --- | --- | --- |
| CA-01 | Pointer motion and pointer buttons supply gameplay samples and edges only while capture holds in the gameplay context. An uncaptured pointer at unpaused RL2 produces no sample, no edge and no request. | HF-04a line 92; ADR 0005 line 13; Godot `MOUSE_MODE_CAPTURED` |
| CA-02 | Capture is released by O1 on every transition out of gameplay, as InputAdapter's input-context work coordinated by Session, and is acquired only inside O4 on the keyboard/mouse path. The activation that requests it is consumed as UI input and never doubles as a shot. | HF-04a lines 87, 90, 92; TH-12 FI-04 line 135 |
| CA-03 | The input path a resume uses is the device class of the control that activated it. A keyboard/mouse resume requires granted capture; a controller resume requires a connected controller observed neutral and requests no capture. | HF-04a lines 90, 92; IC-01 |
| CA-04 | A denied capture keeps the interface paused, shows the capture state plainly and exposes the retry, which is IN-15 again; the retry cannot become a shot. A controller player is never blocked by a denied capture, because CA-03 requests none on that path. | HF-04a line 92; TH-12 FI-10 line 141; TH-02 MF-06 line 204 |
| CA-05 | After a controller resume, the pointer stays uncaptured and CA-01 applies. The route to pointer aim is a later resume through the keyboard/mouse path; whether capture may be acquired mid-play without that route is DP-15's and would require its own O1 and O2 handling by revision. | HF-04a line 77; DP-15 |

### Interfaces

Every row names one HF-03a command, published result or owned record on one HF-03b edge. `Edge` is a D identifier, `local` for a step that makes no cross-module call (HF-03b line 83), or `none` where the engine drives the callback (HF-03b line 44). `Class` is HF-04a's callback family, following HF-04a's own definitions as TH-01, TH-02 and TH-12 do. This table adds no row to TH-01's interface table and no command to HF-03a's lists.

| ID | Operation | Caller to target | Edge | Command or published result | Class | States | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| II-01 | Sample held controls, continuous samples and edges from either device class | InputAdapter | none | `sample_input`; `PhysicalInputState` | F-INPUT | RL2 to RL9 | TH-01 IF-33 line 106; TH-02 MI-01 line 74 |
| II-02 | Observe an application or window focus change | InputAdapter | none | `sample_input`; `InputContextState` | F-CONTROL | any | HF-04a line 47; HF-03b line 44 |
| II-03 | Observe a device connection change | InputAdapter | none | `sample_input`; `PhysicalInputState` | F-OTHER | any | HF-04a line 51; DL-08 |
| II-04 | Read the action request and the focus, modal or device request before routing either | Session to InputAdapter | D05 | `ActionRequest`, `FocusOrModalRequest` | F-PROCESS | RL2 for an action request; any state for a focus, modal or device request | TH-01 IF-35 line 108; TH-12 UI-01 line 153 |
| II-05 | Handle a focus, modal or device change | Session | local | `handle_focus_or_modal_change` | F-CONTROL | any ticking state | TH-01 IF-31 line 104; TH-12 UI-02 line 154 |
| II-06 | Release held physical input, set the input context and release or restore capture, O1 | Session to InputAdapter | D05 | `clear_physical_input`, `set_input_context` | F-CONTROL | RL2 to RL8 | HF-04a lines 87, 92; TH-12 UI-03 line 155 |
| II-07 | Cancel uncommitted preparation, O2 | Session to Encounter | D01 | `cancel_prepared` | F-CONTROL | the RL2 exit to a view | HF-04a line 88; TH-12 UI-04 line 156 |
| II-08 | Solo pause, O3 | Session | local | `request_pause` | F-CONTROL | RL2 to RL8 | HF-04a line 89; TH-12 UI-05 line 157 |
| II-09 | Check resume readiness and resume, O4 | Session | local | `SessionControl`, `resume` | F-CONTROL | Paused RL2 | HF-04a line 90; TH-12 UI-05 line 157 |
| II-10 | Present the held snapshot and the opened view | Session to Presentation | D06 | `present_snapshot` | F-PROCESS | RL2 to RL9 | TH-12 UI-07 line 159 |
| II-11 | Show a device, focus or capture status, or a refusal | Session to Presentation | D06 | `show_diagnostic` | F-PROCESS | RL3 to RL9, and Paused RL2 | TH-01 IF-26 line 99; TH-12 UI-08 line 160 |
| II-12 | Record a navigation, UI request or resume activation in the view | Presentation | local | `PresentationState` | F-INPUT | RL4, RL5, RL6, RL9, and Paused RL2 for menu and navigation requests | TH-12 UI-10 line 162; HF-03b line 79 |
| II-13 | Read the recorded UI request values | Session to Presentation | D06 | `read_ui_requests`; `UiRequest` | F-PROCESS | RL4, RL5, RL6, RL9, and Paused RL2 for menu and navigation requests | TH-01 IF-19 line 92; TH-12 UI-09 line 161 |
| II-14 | Route an admitted gameplay request into the encounter inbox | Session to Encounter | D01 | `submit_action`; `ActionRejected` on refusal | F-PROCESS | RL2 only | TH-01 IF-14 line 87; TH-12 UI-18 line 170 |
| II-15 | Capture the tick's input frame | Encounter to InputAdapter | D08 | `read_frame`; `InputFrame` | C-TICK P1 | RL2 | TH-02 MI-05 line 78; TH-12 UI-20 line 172 |
| II-16 | Integrate aim samples into the authoritative aim pose and admit a prepare | Encounter | local | `EncounterState` | C-TICK P2 | RL2 | TH-02 MI-06 line 79; TH-04 AI-07 line 132 |
| II-17 | Read the committed results and the provisional preview a view holds | Session to Encounter | D01 | `read_committed_results`; `EncounterSnapshot`, `AimPreview` | F-PROCESS | RL2 | TH-01 IF-17 line 90; TH-12 UI-06 line 158 |
| II-18 | Commit a sensitivity change Session admitted on its own record at RL4 or RL9 | Session to Persistence | D04 | `commit_preferences`; `PreferencesSnapshot` | F-PROCESS request, F-ASYNC completion | RL4, RL9 | TH-01 IF-32 line 105; TH-12 UI-15 line 167 |

Three consequences the table makes checkable. InputAdapter is never a caller on a module edge, and `sample_input` has no module caller. Presentation appears only as a target on D06 and as the caller of a `local` step on its own record. And `submit_action` appears in one row, II-14, whose state is RL2 only.

### Owned data

1. **InputAdapter writes `PhysicalInputState` and `InputContextState` and no other record.** It holds held controls, prior samples, edge detection, the bound-device record, the current routing context with its capture state, and the unpublished frame and request buffers. Clearing or dropping a device's controls cannot mutate a prepared action, a pause state, a save or the run (HF-03a line 50).
2. **Session writes `SessionControl`**, which holds input, modal and pause coordination and the resume readiness it checks, and decides the pause; InputAdapter decides none (HF-03a lines 36, 45).
3. **Encounter writes `EncounterState`**, including prepared actions and the authoritative aim pose; O2 is its own cancellation at Session's request (HF-03a line 46; HF-04a line 88).
4. **Presentation writes `PresentationState`**, which holds the single interactive focus and the recorded request values; it calls nothing and decides nothing (HF-03a lines 37, 51; HF-03b line 79).
5. **Persistence writes `PreferencesRecord`** and nothing here adds a field to it. No device, binding, bound-device record, input context, capture state or focus position is durable, and none is in HF-07a's CSV (HF-07a lines 205, 272).

### Transitions and the native physical test each needs

Every row is unqualified at this base. `Test` names the future native physical test in the next table that would qualify it; none has been run and none can run before Q-E01's slice exists.

| ID | Transition | Trigger and device class | Required result | Rules | Test |
| --- | --- | --- | --- | --- | --- |
| IT-01 | RL2 to Paused RL2 | The pause or dashboard control, keyboard/mouse | O1, O2, O3 before the view; capture released; no cast | FC-01, FC-02, CA-02 | NT-01 |
| IT-02 | RL2 to Paused RL2 | The pause or dashboard control, controller, with a prepared action held on a trigger | O1, O2, O3 before the view; preparation cleared before any commit | FC-01, FC-02, IC-03 | NT-02 |
| IT-03 | RL2 to Paused RL2 | Application focus loss while aiming with captured pointer | The same sequence; capture released; controller input while unfocused becomes nothing | FC-01, FC-05, CA-02 | NT-03 |
| IT-04 | RL2 to Paused RL2 | Loss of the bound controller during focused aim with a prepared action | No release from the loss; then O1, O2, O3 | DL-02, DL-04, FC-04 | NT-04 |
| IT-05 | RL2 unchanged | Loss of a device that is not bound | No drain and no gameplay change | DL-07 | NT-05 |
| IT-06 | Paused RL2 unchanged | A controller reconnects with a control held | No edge until neutral; no resume | DL-05, DL-06 | NT-06 |
| IT-07 | Paused RL2 unchanged | Application focus regained with controls held on both classes | Paused interface; no edge until neutral; focus on a named control | FC-06, FC-07 | NT-07 |
| IT-08 | Paused RL2 to RL2 | Resume by pointer with capture granted | O1 again, neutral re-arm, unpause last; the click is not a shot | CA-02, CA-03 | NT-08 |
| IT-09 | Paused RL2 unchanged | Resume by pointer with capture denied, then retry | Stays paused; capture state shown; retry is not a shot | CA-04 | NT-09 |
| IT-10 | Paused RL2 to RL2 | Resume by controller with a mouse connected | No capture requested; O1 again; uncaptured pointer supplies nothing | CA-03, CA-05 | NT-10 |
| IT-11 | Paused RL2 unchanged | Navigation across views by controller then by keyboard/mouse, then close | Single shared focus; close restores to a non-committing control and resumes nothing | IC-04, IC-05, FC-07 | NT-11 |
| IT-12 | RL4 or RL9 unchanged; Paused RL2 refused | A setting adjusted by either class | Committed at RL4 and RL9; shown refused under Paused RL2 | IN-13 | NT-12 |
| IT-13 | Paused RL2 unchanged | The last connected input device is lost | Resume refused for want of a valid input path | DL-06, CA-03 | NT-13 |
| IT-14 | RL4, RL5, RL6 or RL9 unchanged | Focus loss or device loss with no encounter ticking | No O2 and no pause; no edge until neutral on return | FC-08, DL-05 | NT-14 |

| ID | Physical procedure on the approved native slice | Observable pass condition | Gate |
| --- | --- | --- | --- |
| NT-01 | On each target platform, hold a movement key and a prepared weapon on a mouse button, then press the pause control | Tick position and cooldowns frozen from the drain; no committed attack for the preparation; cursor visible and uncaptured when the view appears; no gameplay edge on resume from the still-held key | Q-E01; Q-E03 |
| NT-02 | With a physical controller, hold a prepare on a trigger, then press the controller's pause control | No committed attack before or after the view appears; focus rests on a named control; the trigger re-arms only after neutral | Q-E01; Q-E03 |
| NT-03 | Aim with captured pointer, switch the operating system's focus to another application, then press controller buttons while unfocused | Gameplay frozen at the drain; no navigation, activation or resume from the unfocused presses | Q-E01; Q-E03 |
| NT-04 | Hold focused aim and a prepare on a wired or wireless controller, then physically disconnect it | No release and no committed attack from the loss; the paused interface appears with the device status | Q-E01; Q-E03 |
| NT-05 | While playing on keyboard/mouse, disconnect an idle controller | Tick continues; no pause, no drain and no gameplay change | Q-E01; Q-E03 |
| NT-06 | While paused, reconnect a controller with a button held | No navigation or activation until the button is released and pressed again; gameplay stays paused | Q-E01; Q-E03 |
| NT-07 | Return operating-system focus with a key and a controller button held | Paused interface with focus on a named control; neither held control acts until released | Q-E01; Q-E03 |
| NT-08 | Resume with the pointer on a platform that grants capture | Capture held; the resume click fires nothing; the first gameplay advance follows the unpause | Q-E01; Q-E03 |
| NT-09 | Resume with the pointer where capture is refused, then retry | Paused with the capture state shown; no shot from either click | Q-E01; Q-E03 |
| NT-10 | Resume with the controller while a mouse is connected, then move and click the mouse | No capture requested; pointer motion and clicks supply no gameplay sample or edge | Q-E01; Q-E03 |
| NT-11 | Navigate every dashboard view with the controller alone, then with the keyboard alone, then with the pointer, and close | Every focusable control reached by each class; one focus position throughout; close restores to a non-committing control without resuming | Q-E01; Q-E03; Q-P30 |
| NT-12 | Adjust sensitivity with each class at the intermission and at a mid-encounter pause | Committed at the intermission; refused and shown mid-encounter | Q-E01; Q-P30 |
| NT-13 | While paused, disconnect every input device, then reconnect one | Resume refused with no device; after reconnection resume still requires a deliberate action | Q-E01; Q-E03 |
| NT-14 | At the intermission and the post-run surface, lose focus and disconnect a device, then return | No pause state appears where none applies; no held control acts until neutral | Q-E01; Q-E03 |

### Hardware rows

| ID | Hardware claim | Status | Future native test | Gate |
| --- | --- | --- | --- | --- |
| HQ-01 | Keyboard input, repeat and focus behaviour on Windows 11 x64 | unqualified | NT-01, NT-07, NT-11 | Q-E03; Q-E01 |
| HQ-02 | Keyboard input, repeat and focus behaviour on Linux x64 | unqualified | NT-01, NT-07, NT-11 | Q-E03; Q-E01 |
| HQ-03 | Relative pointer motion, capture grant and capture denial on Windows 11 x64 | unqualified | NT-08, NT-09, NT-10 | Q-E03; Q-E01 |
| HQ-04 | Relative pointer motion, capture grant and capture denial on Linux x64 | unqualified | NT-08, NT-09, NT-10 | Q-E03; Q-E01 |
| HQ-05 | Controller buttons, sticks, triggers and directional pad on Windows 11 x64, for a device set not chosen | unqualified | NT-02, NT-11 | Q-E03; Q-P30 |
| HQ-06 | Controller buttons, sticks, triggers and directional pad on Linux x64, for a device set not chosen | unqualified | NT-02, NT-11 | Q-E03; Q-P30 |
| HQ-07 | Controller connection and disconnection observation and timing on both platforms | unqualified | NT-04, NT-05, NT-06, NT-13 | Q-E03; Q-E01 |
| HQ-08 | Controller input received while the application is unfocused, and its suppression, on both platforms | unqualified | NT-03, NT-07 | Q-E03; Q-E01 |

### Edge cases

| ID | Case | Required behaviour | Source |
| --- | --- | --- | --- |
| IE-01 | A controller disconnects while its trigger holds a prepared weapon and a tick reads a frame before Session drains | The frame carries no release edge and no sample from the lost device, so the preparation stays prepared; O2 then cancels it. | DL-02; HF-04a line 26; TH-04 AV-06 line 69 |
| IE-02 | Device loss and an action request from the other class arrive at the same boundary | Both are read before either is routed; the device request is legal in any state, and the action request is rejected as a gameplay action once the state is paused. | TH-01 IF-35 line 108; HF-04a line 77 |
| IE-03 | The player presses the pause control on the controller while holding a prepare on the same controller | The pause press is consumed as UI input; O2 cancels the preparation before the view; the held trigger re-arms only after neutral. | IC-03; FC-02; HF-04a line 87 |
| IE-04 | A controller button is pressed while another application has focus | It becomes nothing in any input class, and still becomes nothing when focus returns while it is held. | FC-05; FC-06 |
| IE-05 | The player resumes by controller, then clicks the mouse to fire | The uncaptured pointer supplies no edge; nothing fires. | CA-01; CA-05 |
| IE-06 | Capture is denied and the player, unaware, clicks again | The interface stays paused and shows the capture state; each click is a retry, never a shot. | CA-04; TH-12 FI-10 line 141 |
| IE-07 | A held navigation key repeats through the operating system while a view opens over it | The repeat is not an edge; the key was cleared by O1 and must be observed neutral before it acts in the view. | IC-07; HF-04a line 87 |
| IE-08 | The player changes device class mid-view | Focus stays where the previous class left it; there is one focus owner. | IC-04 |
| IE-09 | The same physical controller disconnects and reconnects repeatedly while paused | Each change is a request read by Session; none resumes; every held control re-arms only after neutral. | DL-05; DL-06 |
| IE-10 | A controller is lost at the intermission while the equipment view is open | No drain and no pause; focus stays on its control; the view remains usable by the other class. | FC-08; IC-01 |

### Failure modes

| ID | Failure | Required behaviour | Source |
| --- | --- | --- | --- |
| IX-01 | A device loss is delivered as a release of its held controls | A defect. Loss is not release; a release derived from a loss could cast a prepared action outside the drain. | DL-02; HF-04a line 26 |
| IX-02 | A view is shown before O2 applies | A defect. The preparation could be committed by a tick or a press the view invited. | FC-02; HF-04a line 92 |
| IX-03 | A reconnect, a focus return or a view close resumes gameplay | A defect. Only O4 through a deliberate `control` action resumes. | DL-06; FC-06; FC-07 |
| IX-04 | Controller input from an unfocused session reaches navigation or gameplay | A defect against FC-05; HQ-08 remains unqualified until NT-03 runs. | FC-05 |
| IX-05 | No valid input path exists at resume | O4 is refused and the pause kept; no fallback path is invented. | HF-04a line 90; CA-03 |
| IX-06 | An intent is reachable by one device class only | A coverage defect against TADR-001 line 23, reported against IC-01 rather than accepted as a layout choice. | IC-01 |
| IX-07 | An implementation needs a binding field, a device list or a saved controller setting | A request for an HF-07a field or a Q-P30 answer by revision; no field and no list is added here. | IC-08; HF-07a line 272 |

### Tunable parameters

Every row carries either a source line or a question ID. `unset` means no cited source states a value and the named question owns it; a dependent implementation is gated until that question is answered. No row gated on Q-P30 or Q-P32 states a value.

| ID | Parameter | Value at this base | Source line or question | What it gates |
| --- | --- | --- | --- | --- |
| DP-01 | Initial production qualification platforms | Windows 11 x64 and Linux x64 | TADR-001 line 23 | HQ-01 to HQ-08 |
| DP-02 | Device classes that must cover the full game and menus | 2: keyboard/mouse and controller | TADR-001 line 23; BIBLE line 483 | IC-01 and every coverage cell |
| DP-03 | Build slots whose action a physical control reaches | 4 | BIBLE lines 533 to 536; TH-04 AP-01 line 267 | IN-05 to IN-08 |
| DP-04 | Control operations performed before an interactive view is shown | 3, in the order O1, O2, O3 | HF-04a lines 87 to 89, 92 | FC-01, FC-02 |
| DP-05 | Saved input-related preferences | 1: `preferences.sensitivity` | HF-07a line 185; CSV row 67 | IC-08, IN-13 |
| DP-06 | Saved binding fields | 0 | HF-07a line 272 | IC-02, IC-08 |
| DP-07 | Specific key, button, axis and glyph per intent per device class, the controller layout and remapping | unset | Q-P30; BIBLE line 602; TH-12 UP-15 line 271 | IC-02 and every coverage cell's binding |
| DP-08 | Controller device set, and any other hardware, for qualification | unset | Q-E03; Q-P30 | HQ-05 to HQ-08 |
| DP-09 | Stick dead zones and trigger actuation threshold | unset | Q-P30; Q-P21 | IK-06, IK-08 |
| DP-10 | Sensitivity range, default and axis split, including whether pointer and stick sensitivity are separate | unset | HF-07a line 271; TH-12 UP-19 line 275 | IC-08, IN-13 |
| DP-11 | Stick aim response curve, acceleration, focused-aim framing and inversion | unset | Q-P32; Q-P21; TH-02 MP-21 line 235 | IN-02, IN-03 |
| DP-12 | Held-direction repeat delay and rate for menu navigation on either class | unset | Q-P30 | IC-07, IN-10 |
| DP-13 | How continuous samples from two bound device classes combine | unset | Q-P30 | IC-06 |
| DP-14 | Whether an unbound device's loss is announced, and the wording of device, focus and capture status | unset | Q-P30 | DL-07, II-11 |
| DP-15 | Whether pointer capture may be acquired mid-play without the resume route | unset | Q-P30 | CA-05 |
| DP-16 | Whether pointer hover alone moves interactive focus | unset | Q-P30; TH-12 UP-17 line 273 | IC-04 |
| DP-17 | The control focus lands on and restores to per view, and the focus order within a view | unset | Q-P30; TH-12 UP-17 line 273; PD-02 IP-04 line 131 | IC-05, FC-07 |
| DP-18 | A player-initiated cancel of a prepared action without pausing | unset; no intent at this base | Q-P11; TH-04 AP-23 line 289 | The intent table |
| DP-19 | Baseline defensive response intent | unset | Q-P21; TH-02 MP-07 line 221 | The intent table |
| DP-20 | Accessibility input settings beyond the five saved preferences | unset | Q-P30; TH-12 UP-16 line 272 | IC-08 by revision |
| DP-21 | Accidental-activation prevention scope beyond the structural guarantee | unset | Q-P30; TH-04 AP-37 line 303 | FC-02's acceptance method |
| DP-22 | Control latency between a focus or device notification and the completed drain | unset | Q-E03; HF-04a line 102 | DL-04, FC-01 |
| DP-23 | Fixed gameplay interval `h` | unset | Q-E03; HF-04a line 22 | Every tick-counted observation in NT-01 to NT-14 |
| DP-24 | Concurrent controller limit per platform | unset | Q-E03 | HQ-05 to HQ-07 |
| DP-25 | How keyboard and mouse connection changes are observed on each platform | unset | Q-E03 | IK-10, HQ-01 to HQ-04 |
| DP-26 | Controller vibration and haptic response | unset | Q-P32 | Nothing above; no rule uses it |
| DP-27 | Keyboard and mouse loss handling acceptance, given no engine mechanism was retrieved | unset | Q-E03; Q-E01 | IK-10, DL-01 for that class |
| DP-28 | Controller glyph assets and their admission | unset | Q-P30 | DP-07's glyphs |
| DP-29 | Renderer and backend configuration the physical tests run against | unset | Q-E04 | NT-01 to NT-14 |
| DP-30 | The approved native slice that could run any physical test | unset | Q-E01; TADR-001 line 39 | NT-01 to NT-14 and HQ-01 to HQ-08 |

### Seams stated and not decided

- **TH-12** is admitted and its line 218 hands this section device loss, full coverage, focus return across devices and the device-level capture protocol. Every rule above is consistent with TH-12's FI-01 to FI-14 and extends them to devices; none replaces one. Where the two sections describe one moment they name the same callback families: the request read under F-PROCESS, the drain under F-CONTROL, navigation under F-INPUT, the first advance at C-TICK P1, and no HF-07b transition, because the pause stages nothing (TH-01 line 45).
- **HF-04a** owns the callback families. DL-08 records that a device connection delivery is F-OTHER at this base and states the classification it requires; the revision that names it is HF-04a's, not performed here.
- **SC-01**, character and progression definitions, is concurrent and not admitted. A kit's action definitions decide what IN-05 to IN-08 activate; this section maps controls to slot actions by slot identity only and assumes no definition field.
- **PD-03**, the sound and feel event brief, is concurrent and not admitted, and its card excludes controller tests. Audible device, focus or capture status and controller vibration are feel events it may name; this section chooses none (DP-14, DP-26).
- **TH-19**, source-asset import and export admission, is concurrent and not admitted. Controller glyph assets, when Q-P30 chooses them, would be admitted through it (DP-28).
- SC-02 to SC-06 and SC-08 have no seam to this section.

## Scenarios

Three paper traces, covering the card's verification: a disconnect during aim, controller modal navigation, and focus return. Each step names its device class, PD-02's input class, the edge or `local`, the interface row, HF-04a's callback family, **the gate that admits it**, and its gameplay effect in a closed vocabulary: `none`, or `tick` for a C-TICK row that advances one tick at unpaused RL2 without drawing gameplay randomness, applying damage or releasing a cast. Admissibility is argued from each step's gate, not from the outcome sentence. Nothing here was executed.

| Trace | What it traces | Steps | Named outcome |
| --- | --- | --- | --- |
| DA | Controller disconnect during focused aim with a prepared weapon | DA.1 to DA.17 | DA.18 |
| CN | Controller modal navigation from a prepared action into the dashboard | CN.1 to CN.15 | CN.16 |
| FT | Focus return across devices, resumed by controller | FT.1 to FT.20 | FT.21 |

### DA: a controller disconnect during aim

| Step | Position | Device class | Input class | Caller to target | Edge | Interface | Callback | Gate that admits the step | Gameplay effect | Reaches `submit_action` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DA.1 | RL2 | controller | gameplay | Encounter to InputAdapter | D08 | II-15 `read_frame`; `InputFrame` | C-TICK P1 | An eligible invocation at unpaused RL2; P1 captures one frame carrying the held stick aim samples, the held focused-aim control and the prepare edge, consumed once (HF-04a line 62) | tick | No |
| DA.2 | RL2 | controller | gameplay | Encounter | local | II-16 `EncounterState` | C-TICK P2 | The same invocation; aim integrates into the authoritative pose in MA-07 and the prepare is admitted to AV-06; P6 commits and publishes (TH-02 MO-02 line 119; TH-04 AI-07 line 132) | tick | No |
| DA.3 | RL2 | controller | control | InputAdapter | none | II-03 `sample_input`; `PhysicalInputState` | F-OTHER | A connection change delivered by the engine; InputAdapter drops the lost controller's held controls and samples without a release edge and publishes a device-loss `FocusOrModalRequest` naming it bound (DL-02, DL-03, DL-08) | none | No |
| DA.4 | RL2 | none | control | Session to InputAdapter | D05 | II-04 `FocusOrModalRequest` | F-PROCESS | D05's permitted use; a device request is legal in any state and is read before any action request is routed (TH-01 IF-35 line 108) | none | No |
| DA.5 | RL2 | none | control | Session | local | II-05 `handle_focus_or_modal_change` | F-CONTROL | Session's own command for a bound-device loss; a notification during a tick is latched until the first non-reentrant control boundary (HF-04a lines 26, 92; DL-04) | none | No |
| DA.6 | RL2 | none | control | Session to InputAdapter | D05 | II-06 `clear_physical_input`, `set_input_context` | F-CONTROL | O1 on D05's permitted use; held, previous-edge and pending state cleared, generation advanced, no release edge (HF-04a line 87) | none | No |
| DA.7 | RL2 | none | control | Session to Encounter | D01 | II-07 `cancel_prepared` | F-CONTROL | O2 on D01's permitted use at a serialized boundary; the preparation and old-generation requests are discarded with no cooldown, draw, damage or cast (HF-04a lines 24, 88; TH-04 AO-08 line 201) | none | No |
| DA.8 | RL2 | none | control | Session | local | II-08 `request_pause` | F-CONTROL | O3, only after O1 and O2 (HF-04a lines 89, 92) | none | No |
| DA.9 | Paused RL2 | none | display | Session to Presentation | D06 | II-10 `present_snapshot` | F-PROCESS | The view is shown after the drain returned; the held aim pose is displayed at its last committed value and not advanced (HF-04a line 79; FC-04) | none | No |
| DA.10 | Paused RL2 | none | display | Session to Presentation | D06 | II-11 `show_diagnostic` | F-PROCESS | A diagnostic is admitted at Paused RL2 (TH-01 IF-26 line 99); the device status wording is DP-14's | none | No |
| DA.11 | Paused RL2 | controller | control | InputAdapter | none | II-03 `sample_input`; `PhysicalInputState` | F-OTHER | The controller reconnects with its trigger still held; the held trigger yields no edge until neutral and the connection is published as a request (DL-05, DL-06) | none | No |
| DA.12 | Paused RL2 | controller | control | Presentation | local | II-12 `PresentationState` | F-INPUT | After the button is observed neutral and pressed again, the resume control records a request value and calls nothing (HF-03b line 79; HF-04a line 46) | none | No |
| DA.13 | Paused RL2 | none | control | Session to Presentation | D06 | II-13 `read_ui_requests`; `UiRequest` | F-PROCESS | D06's permitted use; a menu request at Paused RL2 (TH-01 IF-19 line 92) | none | No |
| DA.14 | Paused RL2 | none | control | Session | local | II-09 `SessionControl` readiness for `resume` | F-CONTROL | O4's readiness: the controller path is valid and needs no capture, O2 was applied at DA.7, modal focus is resolved (HF-04a lines 90, 92; CA-03) | none | No |
| DA.15 | Paused RL2 | none | control | Session to InputAdapter | D05 | II-06 `clear_physical_input`, `set_input_context` | F-CONTROL | O1 again inside O4; the resume press is consumed as UI input and every held control needs neutral re-arm (HF-04a lines 87, 90) | none | No |
| DA.16 | Paused RL2 | none | control | Session | local | II-09 `resume` | F-CONTROL | Unpause last; resume does not tick, release or synthesize a cast (HF-04a line 90) | none | No |
| DA.17 | RL2 | controller | gameplay | Encounter to InputAdapter | D08 | II-15 `read_frame`; `InputFrame` | C-TICK P1 | The next eligible invocation at unpaused RL2 is the first advance; P1 validates the new generation, so the still-held trigger supplies no edge and MA-07 is left (HF-04a line 62; TH-02 MA-07 line 40) | tick | No |

**DA.18, named outcome.** The prepared weapon was never released: the loss derived no release edge at DA.3 and O2 discarded the preparation at DA.7, before the view and before another tick. Focused aim ended at DA.17 because its generation was invalidated at DA.6, and no drain step moved the aim pose. Reconnecting resumed nothing; the resume at DA.16 came from a deliberate press observed after neutral. No step between DA.3 and DA.16 advanced the tick, and no step reached `submit_action`.

### CN: controller modal navigation

| Step | Position | Device class | Input class | Caller to target | Edge | Interface | Callback | Gate that admits the step | Gameplay effect | Reaches `submit_action` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CN.1 | RL2 | controller | gameplay | Encounter to InputAdapter | D08 | II-15 `read_frame`; `InputFrame` | C-TICK P1 | An eligible invocation at unpaused RL2; P1 captures the trigger's prepare edge once (HF-04a line 62) | tick | No |
| CN.2 | RL2 | controller | gameplay | Encounter | local | II-16 `EncounterState` | C-TICK P2 | The prepare is admitted to AV-06 and published at P6 (TH-04 AI-07 line 132, AV-06 line 69) | tick | No |
| CN.3 | RL2 | controller | control | InputAdapter | none | II-01 `sample_input`; `PhysicalInputState` | F-INPUT | The pause control's press is a neutral-to-pressed edge; InputAdapter updates its own records and publishes the modal request; no cast from an input callback (HF-04a line 46; IC-03) | none | No |
| CN.4 | RL2 | none | control | Session to InputAdapter | D05 | II-04 `FocusOrModalRequest` | F-PROCESS | D05's permitted use; the modal request is read before any action request is routed (TH-01 IF-35 line 108) | none | No |
| CN.5 | RL2 | none | control | Session | local | II-05 `handle_focus_or_modal_change` | F-CONTROL | Session's own command; latched if a tick is in flight (HF-04a lines 26, 92) | none | No |
| CN.6 | RL2 | none | control | Session to InputAdapter | D05 | II-06 `clear_physical_input`, `set_input_context` | F-CONTROL | O1; the pause press is consumed as UI input and the held trigger is cleared without a release edge (HF-04a line 87) | none | No |
| CN.7 | RL2 | none | control | Session to Encounter | D01 | II-07 `cancel_prepared` | F-CONTROL | O2; the preparation is discarded before any view and any tick (HF-04a line 88; FC-02) | none | No |
| CN.8 | RL2 | none | control | Session | local | II-08 `request_pause` | F-CONTROL | O3 after O1 and O2 (HF-04a lines 89, 94) | none | No |
| CN.9 | Paused RL2 | none | display | Session to Presentation | D06 | II-10 `present_snapshot` | F-PROCESS | The view appears after the drain; focus lands on a named, visible control (TH-12 FI-11 line 142) | none | No |
| CN.10 | Paused RL2 | controller | navigation | Presentation | local | II-12 `PresentationState` | F-INPUT | A directional pad edge moves the single shared focus; navigation cannot reach `submit_action` (IC-04; PD-02 line 46) | none | No |
| CN.11 | Paused RL2 | controller | navigation | Presentation | local | II-12 `PresentationState` | F-INPUT | A button edge switches to the settings view; focus lands on a named control (IN-11; IC-05) | none | No |
| CN.12 | Paused RL2 | controller | ui-request | Presentation | local | II-12 `PresentationState` | F-INPUT | A stick direction on the sensitivity control records a change request value and calls nothing (IN-13; HF-03b line 79) | none | No |
| CN.13 | Paused RL2 | none | ui-request | Session to Presentation | D06 | II-13 `read_ui_requests`; `UiRequest` | F-PROCESS | D06's permitted use at Paused RL2 (TH-01 IF-19 line 92) | none | No |
| CN.14 | Paused RL2 | none | display | Session to Presentation | D06 | II-11 `show_diagnostic` | F-PROCESS | The preference change is refused because it is admitted at RL4 and RL9 only, and the refusal is shown at Paused RL2 (TH-12 SO-03 line 117; TH-01 IF-32 line 105, IF-26 line 99) | none | No |
| CN.15 | Paused RL2 | controller | navigation | Presentation | local | II-12 `PresentationState` | F-INPUT | A back press closes the view; focus restores to a named, non-committing control and closing is not resuming (FC-07; TH-12 FI-09 line 140) | none | No |

**CN.16, named outcome.** The encounter is paused with no prepared action: O2 cleared it at CN.7, after the modal request and before the view at CN.9, and no tick ran between CN.2 and the end of the trace, so nothing could commit it. Every view was reached with controller input alone, focus was single throughout, the refused setting change was shown rather than applied, and closing left the player paused on a non-committing control. No navigation, UI-request, control or display step reached `submit_action`.

### FT: focus return across devices

| Step | Position | Device class | Input class | Caller to target | Edge | Interface | Callback | Gate that admits the step | Gameplay effect | Reaches `submit_action` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FT.1 | RL2 | keyboard/mouse | gameplay | Encounter to InputAdapter | D08 | II-15 `read_frame`; `InputFrame` | C-TICK P1 | An eligible invocation at unpaused RL2 with capture held; P1 captures pointer aim samples, a held movement key and a mouse-button prepare edge once (HF-04a line 62; CA-01) | tick | No |
| FT.2 | RL2 | keyboard/mouse | gameplay | Encounter | local | II-16 `EncounterState` | C-TICK P2 | Aim integrates into MA-06 and the prepare is admitted to AV-06 (TH-02 MO-02 line 119; TH-04 AI-07 line 132) | tick | No |
| FT.3 | RL2 | keyboard/mouse | control | InputAdapter | none | II-02 `sample_input`; `InputContextState` | F-CONTROL | The operating system reports application focus lost; InputAdapter records it and publishes the focus request (HF-04a line 47; HF-03b line 44) | none | No |
| FT.4 | RL2 | none | control | Session to InputAdapter | D05 | II-04 `FocusOrModalRequest` | F-PROCESS | D05's permitted use; read before routing (TH-01 IF-35 line 108) | none | No |
| FT.5 | RL2 | none | control | Session | local | II-05 `handle_focus_or_modal_change` | F-CONTROL | Session's own command; latched if a tick is in flight (HF-04a lines 26, 92) | none | No |
| FT.6 | RL2 | none | control | Session to InputAdapter | D05 | II-06 `clear_physical_input`, `set_input_context` | F-CONTROL | O1; held key and button cleared without a release edge, generation advanced, capture released as input-context work (HF-04a lines 87, 92; CA-02) | none | No |
| FT.7 | RL2 | none | control | Session to Encounter | D01 | II-07 `cancel_prepared` | F-CONTROL | O2; the mouse-button preparation is discarded before any view (HF-04a line 88; FC-02) | none | No |
| FT.8 | RL2 | none | control | Session | local | II-08 `request_pause` | F-CONTROL | O3 after O1 and O2 (HF-04a line 89) | none | No |
| FT.9 | Paused RL2 | none | display | Session to Presentation | D06 | II-10 `present_snapshot` | F-PROCESS | The paused interface is prepared with the held snapshot (HF-04a line 79) | none | No |
| FT.10 | Paused RL2 | controller | navigation | InputAdapter | none | II-01 `sample_input`; `PhysicalInputState` | F-INPUT | A controller button press that would otherwise be navigation arrives while another application holds focus and is admitted as no request of any class (FC-05; Godot controllers page, window focus) | none | No |
| FT.11 | Paused RL2 | keyboard/mouse | control | InputAdapter | none | II-02 `sample_input`; `InputContextState` | F-CONTROL | Focus regained; the still-held movement key and the still-held controller button yield no edge until neutral, and the regain is published as a request (FC-06) | none | No |
| FT.12 | Paused RL2 | none | control | Session to InputAdapter | D05 | II-04 `FocusOrModalRequest` | F-PROCESS | D05's permitted use; regaining focus never resumes gameplay, so Session keeps the pause (HF-04a line 92) | none | No |
| FT.13 | Paused RL2 | none | display | Session to Presentation | D06 | II-11 `show_diagnostic` | F-PROCESS | The capture state is shown plainly at Paused RL2 (TH-01 IF-26 line 99; TH-12 FI-10 line 141) | none | No |
| FT.14 | Paused RL2 | controller | navigation | Presentation | local | II-12 `PresentationState` | F-INPUT | After the controller button is observed neutral, a directional edge moves the single focus to the resume control (IC-04; FC-06) | none | No |
| FT.15 | Paused RL2 | controller | control | Presentation | local | II-12 `PresentationState` | F-INPUT | A fresh button edge activates resume and records a request value; it calls nothing (HF-03b line 79) | none | No |
| FT.16 | Paused RL2 | none | control | Session to Presentation | D06 | II-13 `read_ui_requests`; `UiRequest` | F-PROCESS | D06's permitted use at Paused RL2 (TH-01 IF-19 line 92) | none | No |
| FT.17 | Paused RL2 | none | control | Session | local | II-09 `SessionControl` readiness for `resume` | F-CONTROL | O4's readiness on the controller path: no capture requested, O2 applied at FT.7, modal focus resolved (HF-04a lines 90, 92; CA-03) | none | No |
| FT.18 | Paused RL2 | none | control | Session to InputAdapter | D05 | II-06 `clear_physical_input`, `set_input_context` | F-CONTROL | O1 again; the resume press is consumed as UI input and neutral re-arm is required (HF-04a lines 87, 90) | none | No |
| FT.19 | Paused RL2 | none | control | Session | local | II-09 `resume` | F-CONTROL | Unpause last; no tick on resume (HF-04a line 90) | none | No |
| FT.20 | RL2 | controller | gameplay | Encounter to InputAdapter | D08 | II-15 `read_frame`; `InputFrame` | C-TICK P1 | The first advance at unpaused RL2; the new generation carries no edge from the held key, no pointer sample because capture was not reacquired, and no preparation (HF-04a line 62; CA-05) | tick | No |

**FT.21, named outcome.** Gameplay resumed on the controller path with nothing escaping: the mouse preparation was discarded at FT.7 before the view; the controller press made while unfocused at FT.10 became nothing; regaining focus at FT.11 resumed nothing and the keys held across it could not act; the resume came from a fresh controller press after neutral; and the uncaptured pointer supplies no sample or edge until a later keyboard/mouse resume acquires capture. No step between FT.3 and FT.19 advanced the tick, and no step reached `submit_action`.

## Unresolved questions

Seven questions this section exposes and does not answer. No proposal recorded on a still-open question is assumed anywhere above.

| Question | What the input contract needs from it | Where it is exposed |
| --- | --- | --- |
| [Q-P30](../../../BACKLOG.md#q-p30) | Controller mappings, remapping, accessibility settings and the acceptance method for keyboard and controller navigation and accidental-cast prevention, and therefore every binding, glyph, repeat value, focus order and status wording above. | DP-07 to DP-09, DP-12 to DP-17, DP-20, DP-21, DP-28; HQ-05, HQ-06; NT-11, NT-12 |
| [Q-P32](../../../BACKLOG.md#q-p32) | Its bounds on impact response and comfort, which reach stick aim response and any vibration. Its recorded reduced-motion setting and its ruling that a presentation-owned aim point needs a TADR-002 amendment (TRACKING EV-0248, EV-0284) are read as given. | DP-11, DP-26 |
| [Q-P21](../../../BACKLOG.md#q-p21) | The baseline defensive response set and what establishes acceptable handling, which decides whether a defensive intent exists and how dead zones are judged. | DP-09, DP-11, DP-19 |
| [Q-P11](../../../BACKLOG.md#q-p11) | How the prototype's actions map into the four slots, including whether a cancel-targeting action exists in the native kit. | DP-18; IN-05 to IN-08 content |
| [Q-E03](../../../BACKLOG.md#q-e03) | Controller devices, hardware and OS support details, control latency and the fixed interval. | DP-08, DP-22 to DP-25, DP-27; HQ-01 to HQ-08; NT-01 to NT-14 |
| [Q-E04](../../../BACKLOG.md#q-e04) | The renderer and backend configuration under which the physical tests run. | DP-29 |
| [Q-E01](../../../BACKLOG.md#q-e01) | The approved native slice that could run any physical test. | DP-27, DP-30; every NT row |

The sensitivity range, default and axis split are unresolved without a question ID at HF-07a line 271 and are recorded as DP-10 rather than raised as a new question. Input rebinding is not a preferences field at HF-07a line 272; adding one is a revision.

## Re-verification triggers

- Andrew answers Q-P30, Q-P32, Q-P21 or Q-P11: the affected DP rows gain values or intents, and IC-02, IC-05, IC-07, DL-07 and the intent table are re-read. The contract is expected to hold without a new module, command or edge.
- Andrew answers Q-E03, Q-E04 or Q-E01, or a native slice is authorized: every HQ and NT row becomes a test to run, and this section's evidence limits stop being sufficient.
- HF-04a names a device connection delivery in a callback family: DL-08, II-03 and steps DA.3 and DA.11 are re-read and re-classed.
- HF-04a changes O1 to O4, line 26, line 77, line 92 or a callback family; HF-03a changes the InputAdapter, Session, Encounter or Presentation row; or HF-03b changes D01, D04, D05, D06 or D08: the interface table and all three traces are re-checked.
- TH-12 changes FI-01 to FI-14, UI-01 to UI-22 or its line 218 seam; TH-02 changes MA-06, MA-07, MO-02 or its input rows; TH-04 changes AS-01 to AS-04, AV-06 or AO-08; or TH-01 changes IF-19, IF-26, IF-31, IF-32 or IF-35: every row citing them is re-resolved by ID and line.
- HF-07a adds a binding, device or input field, or changes its line 271 or 272: IC-08, DP-05, DP-06 and DP-10 are re-read.
- PD-02 is revised: the input-class vocabulary and FP-14 are re-resolved by line.
- SC-01, PD-03 or TH-19 is admitted: its seam above is replaced by a citation, and any difference is a finding on the card that owns it.
- TADR-001 line 23 or 39, or Bible lines 481, 483, 533 to 536, 544 or 602, change: coverage and the platform rows are re-read.
- Any cited section's bytes change from the SHA256 stated in [Sources](#sources): every citation into it is re-resolved by line.

## Procedure performed

Verified the clean worktree `wt/TH-18` at base `bb97c4111d1e7b2dd40cae575eccde17878b07c5` and runtime `CLAUDE_EFFORT=high` before any write. Read the assignment packet, the exact TH-18 card, `AGENTS.md`, the project desk, `CONTRIBUTING.md`, ORCHESTRATOR's handoff and review section and both project skills; read TADR-001, ADR 0005 and Bible § 6 at the cited pages; read HF-04a, HF-03a and TH-12 in full, HF-03b's contract, TH-02's contract, TH-04's contract and parameters, TH-01's states and interfaces, PD-02's contract, HF-07a's preferences rows and its CSV, and the seven question-register entries. Recomputed every dependency hash stated above from the worktree's bytes, and resolved every cited row ID to its line at this base.

Retrieved Godot 4.7 facts through Context7 library `/websites/godotengine_en_4_7` under the coordinator's amendment to the packet, nine queries in all, with each command, retrieval time and output saved under `artifacts/local/tasks/TH-18/ctx7/`, and cited only statements those outputs contain. Pages first fetched with `curl` before the amendment are retained beside them and cited nowhere.

Took every module, command, published result and record from HF-03a's table at lines 31 to 37 and every edge from HF-03b's adjacency rows at lines 27 to 42, reading each edge's permitted-use cell directly. Took every intent from a TH-02, TH-04 or TH-12 row and every input class from PD-02's vocabulary. Walked the card's three verification cases as step tables whose admissibility is argued from each step's gate and whose gameplay effect is a closed vocabulary, so that "nothing escaped the drain" is an assertion over rows rather than over the outcome sentence.

Wrote an executable paper check at `artifacts/local/tasks/TH-18/paper_check.py`. It accepts an explicit repository root and an `--out` directory, writes its receipts there, and is disposable and gitignored. It asserts: the seven required headings; that every dependency SHA256 stated in Sources matches the named file; that every intent names at least one vocabulary row that exists by ID in TH-02, TH-12 or TH-04; that every gameplay and menu intent has a keyboard/mouse and a controller coverage cell naming defined physical action kinds of the matching class, or an unset parameter row with a question ID; that every module named appears in HF-03a's module table and every command, published result or record belongs to the right module's list; that every edge used is an HF-03b adjacency row whose From and To equal the caller and target and whose permitted-use cell names the interface; that the three traces each reach a bolded named outcome; that no non-C-TICK step has a gameplay effect other than `none`, that every `tick` step is a C-TICK row at unpaused RL2, and that no tick falls between a trace's trigger and its completed resume; that O2 precedes the first view and any commit after each modal or loss trigger; that only `gameplay` rows at RL2 may reach `submit_action` and none does in these traces; that every transition row names a defined native physical test and every hardware row is marked unqualified with a defined test; and that every parameter row carries a source line or a question ID with no value on a Q-P30 or Q-P32 row. It also checks every stated count against the rows counted and every `<section> <ID> line <n>` citation against the cited file. It then runs eight negative controls over mutated copies (O2 moved after the view, a paused step advancing the tick, a hardware row marked qualified, O1 on the wrong edge, a menu intent with no controller coverage, an intent citing a missing TH-02 row, a Q-P30 parameter given a value, and a transition with no native test) and fails unless each mutation is detected by the check it targets. Counts and exit codes are in the receipts.

Required checks are `npm run check:scope -- bb97c4111d1e7b2dd40cae575eccde17878b07c5 <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift` and the paper check above. No build, browser, engine or game ran for this section. No proof page, source file, other technical or product section, ADR, README or board file was touched, and the coordinator-owned sections index is not edited; its proposed new line travels in the handoff.

## Evidence limits

This is a paper specification. No key, button, stick, trigger, pointer, capture, focus change or device connection has been observed; no intent has been routed; no drain has run. The paper check tests this document's internal consistency and its citations against the admitted corpus; it tests no engine, no operating system and no device.

Every hardware row is unqualified. Coverage by both device classes is a requirement from TADR-001 line 23, not a claim that any controller, keyboard or mouse works on either platform; Bible line 602 states that controller mappings need hardware evidence, and none exists. A supported non-mouse input path can satisfy resume readiness under HF-04a line 92; that establishes no hardware support.

The Godot statements cited are documentation retrieved through Context7 on 16 September 2026. They describe engine mechanisms and prove nothing about this game's behaviour; the connection signal's parameters and timing and the focus notification constants were not retrieved and are asserted nowhere. ADR 0005 and the orchard are browser-proof evidence only, and their tests cannot qualify this native contract.

Admission of this section is documentation admission. It authorizes no input implementation, no binding, no controller procurement and no hardware acceptance, and both browser proofs remain separate surfaces.
