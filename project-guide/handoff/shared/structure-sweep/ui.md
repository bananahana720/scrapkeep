# Structure survey: ui
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Claude Opus 5.5 (claude-opus-5-5), effort high   files read: 30 (in full or in part; the other ui files measured by git grep, rg and wc)   date: 2026-11-27

All paths are relative to `sketches/core-loop/`. Every count comes from running the named command in the read-only checkout at the commit above.

## Module map
Files of 400 lines or more (`wc -l src/ui/*.gd`). The slice is 87 files and 27,947 lines.

src/ui/screens.gd | 1945 | title, pause-free menus, every title page toggle, the camp walk, jukebox and radio key handling, the ending, comic, tips, chase board, summary stats, deck dealing | about 60 private vars: page nodes (`_help`, `_achievements`, `_work_orders`, `_logbook`, `_settings`, `_jukebox`, `_radio`, `_camp`), `_state`, `_walking`, the dealt deck | game.gd, tests/support/menu_screens.gd
src/ui/hud.gd | 1766 | the in-run HUD: toast cards and queue, event line, stage titles, layout, objective and detour reading, prompt placement | the `UiProfile` instance (`profile`, hud.gd:394), toast queue, current detour site, layout rects | game.gd; core/play_watch.gd and core/sitting_notes.gd call `objective_reading()`
src/ui/customize_page.gd | 968 | the camp customize page (pilot looks, unlocks) | page rows, focus index | screens.gd camp
src/ui/class_card.gd | 858 | pilot select card | card art, static `reduced_motion` | screens.gd, game.gd
src/ui/settings_pages.gd | 855 | settings tabs and rows | rows, SettingsStore values | screens.gd, pause_menu.gd
src/ui/class_preview.gd | 826 | pilot preview stage | preview rig, static `reduced_motion`; reads `hud.profile` | screens.gd
src/ui/moss_bubble.gd | 782 | the companion speech bubble | queue, static `reduced_motion` | hud.gd
src/ui/ending_sequence.gd | 759 | the ending cards | sequence step | screens.gd, world/victory_lap.gd
src/ui/aim_reticle.gd | 747 | the reticle and per-hand marks | static `reduced_motion` | hud.gd, game.gd
src/ui/edge_markers.gd | 707 | off-screen markers | marker list | hud.gd
src/ui/logbook_page.gd | 685 | the logbook page | pages | screens.gd
src/ui/work_orders_page.gd | 673 | the work orders page | rows, two hand-built focus rings | screens.gd
src/ui/workshop.gd | 637 | the camp workshop | stock rows | game.gd (node "Workshop")
src/ui/shop_counter.gd | 609 | in-run shop counter | offer rows | build/shop.gd
src/ui/pause_menu.gd | 579 | pause menu | buttons; calls `game.radio_deck.toggle_off()` | game.gd
src/ui/ability_bar.gd | 577 | the ability slots | slots, static `reduced_motion` | hud.gd
src/ui/nixie_rail.gd | 560 | the tube rail | tubes | hud.gd
src/ui/start_pick_card.gd | 537 | the start pick card | tiles, tier buttons | core/flow.gd (constructs it)
src/ui/achievements_page.gd | 493 | the achievements page | rows, four StyleBoxFlat | screens.gd
src/ui/field_notes.gd | 477 | field notes and the title objective line | notes | screens.gd, hud.gd
src/ui/build_readout.gd | 458 | the build readout | rows | hud.gd, pause_menu.gd
src/ui/comic_page.gd | 455 | the comic page | panels | screens.gd
src/ui/boss_plate.gd | 428 | the boss health plate | plate, static `reduced_motion` | hud.gd, presentation
src/ui/reward_view.gd | 416 | the reward pick view | offers, static `reduced_motion` | game.gd, presentation
src/ui/key_glyphs.gd | 408 | keycap and pad glyph drawing | glyph cache | keycap.gd and screens

## Outward dependencies
Count is preload lines in src/ui naming that directory (`git grep -h -o 'preload("res://src/[a-z_]*/' -- src/ui | sort | uniq -c`).

- src/core: most common; examples `core/palette.gd` (in most files), `core/bindings.gd` (glyphs.gd:2). Higher to lower, fine.
- src/build: examples `build/item_gen.gd` and `build/parts.gd` (odds_readout.gd), `build/consumables.gd` (hud.gd). Fine in direction, but see UI-06.
- src/world: examples `world/events.gd`, `world/stage_modifier.gd`, `world/hull_mark.gd`, `world/interactables.gd` (all hud.gd). Fine.
- src/movement: `movement/tuning.gd` (hud.gd, screens.gd). Fine.
- src/presentation: `presentation/player_fx.gd` (screens.gd, hud.gd), `presentation/damage_numbers.gd`, `presentation/panel_fx.gd` (hud.gd). Sibling layer, fine.
- Lower layers preloading src/ui (`git grep -n 'preload("res://src/ui/' -- src/core src/build src/combat src/world src/boss src/movement`), all lower→higher:
  - core: ability_state.gd:5 Glyphs, content_registry.gd:21 Icons, flow.gd:17 StartPickCard, pilot_story.gd:6 WordBudget.
  - build: shop.gd:9 OddsReadout; reward_gates.gd:8-13 WorldPrompt, Icons, UiFonts, ScreenRegions; fabricators.gd:8 WorldPrompt.
  - combat: active_rack.gd:8 WorldPrompt; mind_hand.gd:4 and projectile.gd:7 Icons; miniboss.gd:6, pit_jaw.gd:7, warden_reactor.gd:11 UiTokens (only for `UiTokens.reduced_motion`).
  - world: activities.gd:12 OddsReadout; bay.gd, device.gd, event_view.gd WorldPrompt; device.gd and camp_hub.gd Glyphs; camp_hub.gd Keycap, UiFonts, ChoiceButton, CallerTile, UiTokens; world.gd:24 WhyCallout; victory_lap.gd EndingSequence.
  - boss: mind_dress.gd UiFonts and UiTokens; requisition.gd WorldPrompt and UiTokens.
  - core/core-to-hud by call, not preload: core/play_watch.gd:112 and core/sitting_notes.gd:127 call `hud.objective_reading()`.

## Findings  (max 20, best first)

### UI-01 callouts.gd and meta_page.gd are dead in the game; only tests load them
- kind: B
- evidence: `git grep -l -F "res://src/ui/callouts.gd" -- src | grep -v '^src/ui/callouts.gd'` = 0 hits; `-- tests` = 5 (audio_cue_resolution_test.gd:12, fleet_rogue_hand_test.gd:249, hud_words_test.gd:25, mass_icon_test.gd:20, ui_contract_test.gd:11). `git grep -l -F "res://src/ui/meta_page.gd" -- src` = 0 outside itself; tests = 2 (meta_options_test.gd:12, w50_ui_stage_d_test.gd:24). Neither file has a `class_name`, and `git grep -n '"callouts\|"meta_page' -- src` finds no string load. The last game preload went in 1ef8dfe9c ("O1: one objective board and a HUD cut to what the fight needs") for callouts.gd and 762771d5e for meta_page.gd (`git log -S'res://src/ui/callouts.gd' -- src`). Test-only.
- fix: list both files and the test cases that load only them in `housekeeping/pending-deletes.md` (deletion needs Andrew's go-ahead). Alternative: keep them and mark them parked in a header comment. Pick the delete list.
- files to change: src/ui/callouts.gd, src/ui/meta_page.gd (138 + 167 lines), the cases in the 7 tests above that exist only for them.
- size: small (305 lines out, test cases trimmed).
- risk: low; nothing in src loads them.
- behaviour-preserving: yes; the game never loads them.
- tests that cover it: the 7 listed tests; the remaining cases in them must still pass.
- guard: none needed after deletion.

### UI-02 screens.gd reaches into radio_deck's private `_save()`
- kind: C
- evidence: src/ui/screens.gd:1125-1127 `if game.get("radio_deck") != null: game.radio_deck._save()`; the target is src/presentation/radio_deck.gd:264 `func _save()` (clears `_dirty`, writes `profile.set_radio(radio.to_dict())`, `profile.save()`). Also tests/radio_test.gd:322 `deck._save()`. `git grep -n '\._save()' -- src` shows screens.gd:1127 as the only cross-file caller.
- fix: add a public `radio_deck.save()` (or `close_page()` that saves) and call it from screens.gd. Alternative: rename `_save` to `save`. Pick the public `save()` that wraps `_save`, so the test can move to it too.
- files to change: src/presentation/radio_deck.gd, src/ui/screens.gd, tests/radio_test.gd.
- size: tiny (5 lines).
- risk: low; same call, same order.
- behaviour-preserving: yes.
- tests that cover it: tests/radio_test.gd.
- guard: none new; DEEP-SWEEP reach-in pattern.

### UI-03 radio and jukebox rules live in screens.gd's key handler
- kind: C (also H for screens.gd)
- evidence: screens.gd:1077-1110 (`radio_key`) mutates core/radio.gd state directly: `radio.nudge(...)`, `radio.new_mixtape()`, `radio.mixtape = made`, `radio.shuffle_mixtape(radio.mixtape, rng)` with a fresh `RandomNumberGenerator.new(); rng.randomize()`, `radio.tune(radio.MIXTAPE)`, `radio.mixtape = key - KEY_1`. screens.gd:1112-1123 (`_radio_track`) calls `add_to`/`remove_from` and `audio.play`. screens.gd:1005-1038 (`jukebox_key`, `_spin_toggle`, `_refresh_jukebox`) drive `audio.spin`, `stop_spin`, `set_spin_detent`. `git grep -l 'radio_key\|_radio_track' -- tests` = 0, so the key mapping has no direct test.
- fix: move the key-to-radio mapping into one call on the owner, `game.radio_deck.press(keycode, focused_track)`, and the jukebox keys into `jukebox_page.gd` (`jukebox_page.press(keycode)`); screens.gd keeps only the routing. Alternative: move both into radio_page.gd. Pick radio_deck for radio (it already owns the save and the radio) and jukebox_page for the jukebox. The `rng.randomize()` call moves unchanged.
- files to change: src/ui/screens.gd, src/presentation/radio_deck.gd, src/ui/jukebox_page.gd.
- size: medium (about 120 lines moved).
- risk: medium; key order and the mixtape shuffle must stay identical; no physics or save-format change.
- behaviour-preserving: yes if moved verbatim.
- tests that cover it: tests/radio_test.gd (deck side); no test presses the keys, so add one before the move.
- guard: the new key test.

### UI-04 twelve hand-listed page-visibility guards in screens.gd
- kind: A (also G)
- evidence: sibling `.visible` lists at screens.gd:651, 675, 694, 713, 751, 771, 838 (`page_open`), 1190 (`overlay_open`), 1299, 1307, 1348, 1692. The lists differ: `page_open` (838) names jukebox and radio but not camp, `overlay_open` (1190) names camp but not settings, `toggle_help` (651) leaves out jukebox and radio. Each `toggle_*` (649, 673, 692, 711, 749, 770) repeats the open sequence `_actions.visible = false; _show("", AMBER, ""); page.visible = true; focus` and the close sequence.
- fix: one `_pages` array built in setup plus `_other_page_open(except)`; the six toggles share one `_toggle_page(page, focus_button_id)` helper. Alternative: a page-stack object. Pick the array and helper; the stack is a wider change.
- files to change: src/ui/screens.gd.
- size: medium (about 100 lines shrink to about 40).
- risk: medium; the lists differ today, so each difference must be kept or ruled a bug before folding. `git grep -l 'toggle_settings\|toggle_help\|toggle_logbook' -- tests` = 15 files exercise them.
- behaviour-preserving: unsure; keep each guard's exact page set (pass it explicitly) to be sure.
- tests that cover it: the 15 files, including tests/support/menu_screens.gd.
- guard: a test that every page node is in `_pages`.

### UI-05 core calls the HUD for the objective; the objective rule is assembled in hud.gd
- kind: C
- evidence: hud.gd:1315-1368 `objective_reading()` reads flow.state_name, flow.sealed, warden.fight/staggered, gate.lock_active/locked, mount_driver.plate_reading/plate_targets, boss.plate_reading, flow.boss_row, beacon.fraction, gate.yard_fraction and calls `Objectives.choose(reading)`. Core calls it: core/play_watch.gd:112 `_game.hud.objective_reading()`, core/sitting_notes.gd:127 `game.hud.objective_reading().get("words","")`. `git grep -n 'objective_reading(' -- src tools tests | grep -v 'func '` = 45 hits; 9 test files.
- fix: move the reading assembly to `core/objectives.gd` as `Objectives.reading(ctx)`; hud.gd and both core callers call that. Alternative: game.gd owns it. Pick objectives.gd, which already owns `choose`.
- files to change: src/ui/hud.gd, src/core/objectives.gd, src/core/play_watch.gd, src/core/sitting_notes.gd, tests that call `hud.objective_reading()` (may keep a hud forward for them).
- size: medium (about 55 lines moved).
- risk: medium; play_watch and sitting_notes feed bot and sitting reads, so the returned dictionary must be byte-identical.
- behaviour-preserving: yes if moved verbatim.
- tests that cover it: the 9 test files that grep `objective_reading`.
- guard: lint that src/core does not name `.hud.`.

### UI-06 OddsReadout.odds_for is a build rule living in ui
- kind: C
- evidence: src/ui/odds_readout.gd preloads build/item_gen.gd and build/parts.gd; `odds_for(rarities, class_id)` computes live rarity odds per pilot from `Parts.offer_pool` and `ItemGen.odds`. Callers: build/shop.gd:280, 536, 641, 664, 668; world/activities.gd:2310-2311; tests visible_odds_test.gd (172, 225, 264, 283-291), shop_hook_stock_test.gd (72, 87, 100, 120). `git grep -l odds_for -- tests` = 2.
- fix: move `odds_for` into build/item_gen.gd; odds_readout.gd keeps `rows()` and `text()` and calls it. Alternative: build/parts.gd. Pick item_gen.gd, which owns `odds`.
- files to change: src/ui/odds_readout.gd, src/build/item_gen.gd, src/build/shop.gd, src/world/activities.gd, the 2 tests.
- size: small.
- risk: low; pure function, no RNG.
- behaviour-preserving: yes.
- tests that cover it: visible_odds_test.gd, shop_hook_stock_test.gd.
- guard: none.

### UI-07 two UiProfile objects write one ui-profile.json
- kind: F
- evidence: hud.gd:394 `profile = UiProfile.new(game.storage_dir)` and presentation/codex_banner.gd:153 `profile = UiProfile.new(storage_dir)` (storage_dir set at presentation/presentation.gd:127). Both load and save the same file (ui_profile.gd `FILE`), reconciled only by `_merge_disk()` at save. Other readers go through the HUD one: class_preview.gd:303-317 (`hud.get("profile")`), screens.gd:575, 580 (`game.hud.profile.mark_seen(PrologueRows.ID)`). `git grep -l UiProfile -- tests` = 11.
- fix: one game-owned instance, passed to hud and codex_banner. Alternative: a static shared instance in ui_profile.gd. Pick game-owned; a static adds reset work in test_batch_driver (L14).
- files to change: src/game.gd, src/ui/hud.gd, src/presentation/codex_banner.gd, src/presentation/presentation.gd.
- size: small.
- risk: medium; touches the save path but not its format; the merge already hides most races.
- behaviour-preserving: yes for the file contents; in-memory views stop diverging.
- tests that cover it: the 11 UiProfile tests, first_steps_*, harpoon_canon_test.gd, launch_take_test.gd.
- guard: a test that hud.profile and banner.profile are the same object.

### UI-08 reduced motion is copied into thirteen static vars, and combat reads the ui one
- kind: E (also F)
- evidence: game.gd:1064-1079 `set_motion_statics` writes `AbilityBar`, `UiTokens`, `AimReticle`, `RewardView`, `MossBubble`, `caller_tile.gd`, `ClassCard`, `PilotAntics`, `ClassPreview`, `BossPlate`, `flourish_player.gd`, `HighdraftFx.preferred`, `WorldFx.preferred` and `EnemyMotion.motion_scale`. Combat reads the ui copy: miniboss.gd:482, pit_jaw.gd:250, warden_reactor.gd:372, 428, experimental/dynamic_setpieces.gd:785, 929, 972 (`UiTokens.reduced_motion`), mixed with `EnemyMotion.motion_scale <= 0.0`. `git grep -c reduced_motion -- src/ui` = 61 sites in 21 files.
- fix: one owner, a core `Motion` (or `AccessPrefs`) static with `reduced()`; ui and combat read it; `set_motion_statics` sets one field. Alternative: keep the copies and only move combat off UiTokens. Pick the single owner, staged: combat first, ui files next.
- files to change: src/game.gd, a new src/core/motion.gd (or an existing core settings owner), the 10 ui files, 3 combat files, dynamic_setpieces.gd, tools/test_batch_driver.gd `_reset()`.
- size: medium.
- risk: medium; touches many files, but only a bool read; must reset in `_reset()` (L14); test_batch_reset_test.gd covers the reset.
- behaviour-preserving: yes.
- tests that cover it: 36 test files grep `reduced_motion`; test_batch_reset_test.gd.
- guard: lint that src/combat, src/boss and src/world do not name `UiTokens.reduced_motion`.

### UI-09 three panel systems and 24 hand-built StyleBoxFlat
- kind: G
- evidence: `UiTokens.plate(` 4 sites in 3 files; `ScrapFrame.` 70 sites in 22 files; `UiDraw.panel(` 2 sites; `StyleBoxFlat.new()` 24 sites in 12 files (ability_bar 74-78, 100; achievements_page 74, 229, 308, 433; build_readout 76; camp_menu 68; camp_scrapbook 174; controls_diagram 289; customize_page 128, 650; field_notes 394; growth_sheet 103; keycap 66; work_orders_page 400, 497; ui_tokens 82, 121, 127). Focus rings: `focus_ring(` 8 sites in 6 files against `add_theme_stylebox_override("focus"` 11 sites in 10 files, and hand-built rings at work_orders_page.gd:400 and 497. Commands: `git grep -c -F '<pattern>' -- src/ui`.
- fix: route the hand-built focus rings through `UiTokens.focus_ring()` first (pure swap where the values match). Leave the panel look (ScrapFrame against `UiTokens.plate`) to the owner. Alternative: fold everything into ScrapFrame now. Pick the focus-ring swap; the panel merge changes what the player sees.
- files to change: work_orders_page.gd and the other files with a hand-built focus StyleBoxFlat.
- size: small for the focus rings; large for panels.
- risk: low for rings whose values match; a mismatch is a visual change.
- behaviour-preserving: yes only where values match; otherwise no.
- tests that cover it: tests/ui_tokens_test.gd, ui_contract_test.gd.
- guard: lint that `StyleBoxFlat.new()` in src/ui appears only in ui_tokens.gd and scrap_frame.gd, with an allow list for the rest.

### UI-10 41 hand-built labels against an 11-site label helper
- kind: G
- evidence: `Label.new()` 41 sites in 27 files; `UiDraw.label(` 11 sites in 5 files (camp_enemy_picker, companion_panel, ending_sequence, jukebox_page, radio_page); `add_theme_font_override("font", UiFonts.bold())` 39 sites in 26 files. Commands: `git grep -c -F 'Label.new()' -- src/ui`, `git grep -c -F 'UiDraw.label(' -- src/ui`.
- fix: move hand-built labels to `UiDraw.label(size, colour, words)` file by file, where each sets only font, size and colour. Alternative: a `UiTokens.label()`. Pick UiDraw.label, which exists.
- files to change: up to 27 ui files, a few at a time.
- size: medium overall, small per file.
- risk: low; same theme overrides.
- behaviour-preserving: yes where the overrides match exactly.
- tests that cover it: ui_text_floor_test.gd, hud_words_test.gd, the word lint.
- guard: count guard on `Label.new()` in src/ui that may only fall.

### UI-11 core/flow.gd builds a UI node
- kind: C
- evidence: core/flow.gd:17 preloads src/ui/start_pick_card.gd; flow.gd:101-106 `start_card = StartPickCard.new()`, `layer.add_child(start_card)`, connects its three signals; flow.gd:333-347 positions it and sets its interactivity. `git grep -l 'StartPickCard\|start_card' -- tests` = 15.
- fix: game.gd (or screens.gd) builds the card and hands flow the three signals; flow keeps `take_start_pick`, `reroll_start_pick`, `choose_run_tier`. Alternative: leave it and document. Pick the move; flow keeps its public calls.
- files to change: src/core/flow.gd, src/game.gd.
- size: small to medium.
- risk: high; flow.gd is formally modelled (scrapkeep-verify-formal) and the card's build order is part of run start; signal connect order must stay.
- behaviour-preserving: unsure; needs the formal skill run and the 15 tests.
- tests that cover it: the 15 files; the formal model for flow.
- guard: lint that src/core does not preload `res://src/ui/`.

### UI-12 ui leaf files that lower layers preload, sorted by where they belong
- kind: C
- evidence (from `git grep -n 'preload("res://src/ui/' -- src/core src/build src/combat src/world src/boss src/movement`):
  - glyphs.gd: input-to-glyph mapping over core/bindings.gd plus `static var device` written at game.gd:1199; read by core/ability_state.gd:731, world/device.gd:114, world/camp_hub.gd:171, 401-402, 782. Not pure data (reads InputMap, holds state). Belongs beside core/bindings.gd.
  - word_budget.gd `words_in(text)`: pure text count, used by core/pilot_story.gd:1806. Belongs in core; `count(root, camera)` stays ui.
  - why_callout.gd `warden_fight_live(flow)` (lines 112-115): a game predicate on flow, used by world/world.gd:957. Belongs on flow (`flow.warden_fight_live()`).
  - icons.gd `IDS`, `EXTRA`: pure data, used by core/content_registry.gd:313, 388 to validate ids. The texture and SDF code is ui. Data could move to a core table, but icons.gd also owns the art; low payoff.
  - screen_regions.gd: pure layout fractions, used by build/reward_gates.gd and 3 presentation files. Fine where it is (presentation data).
  - ui_fonts.gd, ui_tokens.gd, world_prompt.gd, keycap.gd, choice_button.gd used by world/boss/build: these build world-space prompts and camp UI; they are presentation and the callers are presentation code in world files. Not a finding.
- fix: move `Glyphs` to core (keep a ui forward for one wave), `WordBudget.words_in` to a core text util, `warden_fight_live` onto flow. Pick these three; leave icons, regions, fonts, tokens.
- files to change: src/ui/glyphs.gd, src/core/bindings.gd (or new core/glyphs.gd), src/ui/word_budget.gd, src/core/pilot_story.gd, src/ui/why_callout.gd, src/core/flow.gd, src/world/world.gd.
- size: small each.
- risk: low for words_in and warden_fight_live (pure); medium for Glyphs (static var must reset in `_reset()`).
- behaviour-preserving: yes.
- tests that cover it: `git grep -l warden_fight_live -- tests` = 0 (add one); glyph tests via 11 ui files; word_budget 44 test refs.
- guard: lint that src/core does not preload `res://src/ui/`.

### UI-13 hud.gd chooses the detour site
- kind: C
- evidence: hud.gd:1370-1408 `detour_reading` picks the detour site with the ahead-of-Warden rule (`_ahead_of`, `LET_GO_M`), reads `game.world.get("rescue")`, `_detour_site.rule.finishes`, `.surge_live`. `git grep -n 'detour_reading(' -- src | grep -v 'func '` = hud.gd:1578 only; 6 hits overall.
- fix: move the choice to the world or objectives owner (`Objectives.detour(ctx)`) with UI-05; hud draws what it returns. Alternative: leave until UI-05. Pick doing it with UI-05.
- files to change: src/ui/hud.gd, src/core/objectives.gd.
- size: small.
- risk: medium; the `_detour_site` hold is frame state.
- behaviour-preserving: yes if moved verbatim with its held state.
- tests that cover it: the tests behind the 6 hits.
- guard: same as UI-05.

### UI-14 screens.gd opens the scrapbook store itself
- kind: C
- evidence: screens.gd:742-746 `_journal_pages()` builds `ScrapbookStore.new(dir).summaries()` (core/scrapbook_store.gd) inside the UI; class_preview.gd:316 fetches `hud.get("profile")`.
- fix: game (or the logbook page's owner) passes the summaries in; class_preview takes the profile at setup. Alternative: leave. Pick passing in at setup.
- files to change: src/ui/screens.gd, src/ui/class_preview.gd, src/game.gd.
- size: small.
- risk: low; read-only store use.
- behaviour-preserving: yes.
- tests that cover it: logbook tests via tests/support/menu_screens.gd.
- guard: none.

### UI-15 thin modules
- kind: D
- evidence: ui_draw.gd `width()` forwards to `UiFonts.width()` with nothing added; results_odds.gd (14 lines) is one static `text(seen)` with one dev caller, screens.gd:484.
- fix: callers of `UiDraw.width` call `UiFonts.width`; fold `ResultsOdds.text` into screens.gd's dev branch or into odds_readout.gd. Pick folding into odds_readout.gd next to UI-06.
- files to change: src/ui/ui_draw.gd, src/ui/results_odds.gd, src/ui/screens.gd, callers of `UiDraw.width`.
- size: tiny.
- risk: low.
- behaviour-preserving: yes.
- tests that cover it: ui_text_floor_test.gd.
- guard: none.

### UI-16 raw colours outside the token file
- kind: E
- evidence: `git grep -n 'Color("' -- src/ui | grep -v ui_tokens.gd`: caller_tile.gd:22, comic_page.gd:11, launch_card.gd:19, nixie_rail.gd:107; ui_tokens.gd HANDS holds five raw hex colours next to `Palette` names.
- fix: name each in core/palette.gd or `UiTokens`. Low payoff.
- files to change: the four files, ui_tokens.gd, core/palette.gd.
- size: tiny.
- risk: low.
- behaviour-preserving: yes.
- tests that cover it: ui_tokens_test.gd (contrast).
- guard: lint for `Color("` in src/ui outside ui_tokens.gd.

## Not findings
- hud.gd prompt placement statics (1454-1528): pure and tested; a natural seam but not a defect.
- ui_fonts.gd `_faces` cache: has `reset_for_tests()`.
- UiTokens.THEME_PATH: baked by tools/ui_theme_build.gd and checked by ui_tokens_test.gd:43-45.
- presentation/sound_twins.gd:32-211 pins ui function names as strings: an intended content pin; any move in UI-03, UI-05 or UI-13 needs a re-pin.
- ui_profile.gd writes through SafeStore.write_atomic: L2 compliant.
- S8 Back buttons through ChoiceButton: already linted.
- screen_regions.gd preloaded by build and presentation: pure layout data, fine.
- world and boss files preloading WorldPrompt, UiFonts, Keycap: they build world-space presentation; direction is acceptable.
- core/colour_meanings.gd naming ui paths: data, not a dependency.

## Needs the owner
- Two persisted seen-sets: UiProfile `callouts_seen` (`seen`, void `mark_seen`) and core/profile.gd:484-492 `_doc["seen"]` (`is_seen`, bool `mark_seen`). Merging them changes the save format.
- Deleting callouts.gd and meta_page.gd (UI-01) needs the deletion go-ahead.
- One panel look: ScrapFrame against UiTokens.plate and UiDraw.panel (UI-09) is a visual change.
- Whether the page guards' different page sets (UI-04) are intended or bugs.
