extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")
const PilotBlocks := preload("res://tests/support/pilot_blocks.gd")

# Every achievement pays a reward (the eleven record-only rows of wave 20 pay a paint since 12 Nov 2026),
# and every earned paint has exactly one earner (alpha wave 14).
#   F1 the table sizes: 16 achievements, 18 paints, no empty reward;
#   F2 waking_stilled: only the world-two boss earns it, and it pays Dig Ochre;
#   F3 highdraft_reached: entering world three earns it, and it pays Highdraft Sky;
#   F4 codex_keeper: ten first-time discoveries earn it; a repeat discovery does not count;
#   F5 every non-starter paint is the reward of exactly one row, every starter of none;
#   F6 every earned tint stays at least 0.31 from HAZARD and BRASS, and both tables validate;
#   F7 mind_quieted keeps the cannon-unlock text and pilot, and both pilots stay pending.
# Isolated: a fresh profile and listener per row, on the real bus.

const NOW := 1700000000.0
const TINT_MARGIN := 0.31
const MIND_TEXT := "Quiet the Mind. An old cannon in the Highdraft remembers."

var _t := T.new("achievement_fill_test")
var _game
var _profiles := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_tables()
	_waking()
	_highdraft()
	_codex()
	_earners()
	_tints()
	_mind()
	_game.free()
	quit(_t.verdict())


func _fresh():
	_profiles += 1
	var profile := Profile.new("%s/fill_%d.json" % [_game.storage_dir, _profiles])
	profile.load_profile()
	var progress := Progress.new()
	_game.add_child(progress)
	# No run: the game's own listener settles grants in the shared run first. None of the three rows reads it.
	progress.setup(_game.events, null, profile, func(): return NOW)
	return profile


func _tables() -> void:
	# Re-pinned 2026-10-10 (w13 B5, CUSTOMIZE.md section 8): the skill bar's three shared grant rows and
	# their three items; was 36 and 38.
	# Re-pinned 2026-10-11 (w13 SG12, merge): the four ach_meta_* between-run option grants; was 39.
	# 2026-10-12 (W13 coordinator): the pins hold the shared rows; each P-C kit's rows sit in its
	# marked block and its own tests count them (tests/support/pilot_blocks.gd). Was the total,
	# which every kit merge broke (49 and 47 on 19b3656). 2026-10-17 (first-win secrets, Andrew's Q8):
	# six hidden secret_paint_* rows and their six paints join the shared rows; with the crown pass's
	# isles_rescued (Tally's sky-islands rescue) that makes 50 and 47 (43 and 41 before).
	# 2026-10-19 (w20 ACHIEVEMENTS-REFRESH): six reward-free content-family records (RECORD_ONLY); was 50.
	# 2026-10-24 merge of #406 (world 1 unit 16, shift board: six brindle_mark_* rows, each paying
	# one item) onto the w19 Spillway roster (five reward-free records): 56 + 5 + 6.
	_t.eq("F1 sixty-seven achievements", PilotBlocks.shared(_t, Achievements.ids(), "res://src/core/achievements.gd").size(), 67)
	# 2026-11-11 (systems audit pass D, row 31): four paints for the ach_meta_* grants; was 47.
	# 2026-11-12 (feature-fit.md row 30): eleven paints for the record-only rows; was 51.
	_t.eq("F1 sixty-two cosmetics", PilotBlocks.shared(_t, Cosmetics.ids(), "res://src/core/cosmetics.gd").size(), 62)
	# A pilot's "or" rule row (class_def.gd unlock) pays that pilot through the class row, so its own reward is empty.
	var or_rows := ClassDef.all().filter(func(d): return d.unlock.has("or")).map(func(d): return ClassDef.unlock_row(String(d.unlock["or"])))
	var empty := Achievements.ids().filter(func(id): return Achievements.reward_of(id).is_empty() and not or_rows.has(id))
	_t.eq("F1 no achievement has an empty reward", empty, [])


func _waking() -> void:
	var profile = _fresh()
	_game.events.world_entered.emit(1)
	_game.events.boss_defeated.emit()
	_t.check("F2 a world-one boss does not earn waking_stilled", not profile.earned("waking_stilled"), "world 1")
	_game.events.world_entered.emit(3)
	_game.events.boss_defeated.emit()
	_t.check("F2 a world-three boss does not earn waking_stilled", not profile.earned("waking_stilled"), "world 3")
	_game.events.world_entered.emit(2)
	_game.events.boss_defeated.emit()
	_t.check("F2 the world-two boss earns waking_stilled", profile.earned("waking_stilled"), "world 2")
	_t.check("F2 it pays Dig Ochre", profile.has_cosmetic("paint_tarn_dig"), "paint_tarn_dig")


func _highdraft() -> void:
	var profile = _fresh()
	_game.events.world_entered.emit(2)
	_t.check("F3 world two does not earn highdraft_reached", not profile.earned("highdraft_reached"), "world 2")
	_game.events.world_entered.emit(3)
	_t.check("F3 world three earns highdraft_reached", profile.earned("highdraft_reached"), "world 3")
	_t.check("F3 it pays Highdraft Sky", profile.has_cosmetic("paint_any_sky"), "paint_any_sky")


func _codex() -> void:
	var profile = _fresh()
	for i in 9:
		_game.events.synergy_discovered.emit("fill_%d" % i, "combat", true)
	for i in 3:
		_game.events.synergy_discovered.emit("fill_0", "combat", false)
	_t.check("F4 nine new and three repeat discoveries do not earn codex_keeper", not profile.earned("codex_keeper"), "count %s" % profile.stat("ach.codex_keeper"))
	_game.events.synergy_discovered.emit("fill_9", "combat", true)
	_t.check("F4 the tenth new discovery earns codex_keeper", profile.earned("codex_keeper"), "count %s" % profile.stat("ach.codex_keeper"))
	_t.check("F4 it pays Moth Grey", profile.has_cosmetic("paint_any_moth"), "paint_any_moth")


func _earners() -> void:
	var earners := {}
	for id in Achievements.ids():
		var target := String(Achievements.reward_of(id).get("cosmetic", ""))
		if target != "":
			earners[target] = earners.get(target, []) + [id]
	var wrong := []
	for paint in Cosmetics.ids():
		var want := 0 if Cosmetics.row(paint)["starter"] else 1
		if earners.get(paint, []).size() != want:
			wrong.append("%s %s" % [paint, earners.get(paint, [])])
	_t.eq("F5 each earned paint has one earner and each starter none", wrong, [])
	var loose := earners.keys().filter(func(paint): return not Cosmetics.ids().has(paint))
	_t.eq("F5 every paint reward resolves", loose, [])


func _tints() -> void:
	var close := []
	for paint in Cosmetics.ids():
		if Cosmetics.row(paint)["starter"]:
			continue
		var tint: Color = Cosmetics.row(paint)["tint"]
		for hue in [Palette.HAZARD, Palette.BRASS]:
			if Vector3(tint.r - hue.r, tint.g - hue.g, tint.b - hue.b).length() < TINT_MARGIN:
				close.append(paint)
	_t.eq("F6 earned tints keep 0.31 from HAZARD and BRASS", close, [])
	var pilots: Array = ClassDef.all().map(func(d): return d.id)
	_t.eq("F6 achievements validate", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots, Cosmetics.ids()), [])
	_t.eq("F6 cosmetics validate", Cosmetics.validate(Cosmetics.ROWS, pilots), [])


func _mind() -> void:
	_t.eq("F7 mind_quieted keeps its text", Achievements.row("mind_quieted")["text"], MIND_TEXT)
	_t.eq("F7 mind_quieted pays the remembered cannon", Achievements.reward_of("mind_quieted"), {"pilot": "remembered_cannon"})
	_t.eq("F7 ledger_balanced pays Tally", Achievements.reward_of("ledger_balanced"), {"pilot": "tally"})
	_t.check("F7 no pilot stays pending; the cannon and Tally have class rows", Achievements.PENDING_PILOTS.is_empty()
			and ClassDef.by_id("remembered_cannon") != null and ClassDef.by_id("tally") != null, "%s" % [Achievements.PENDING_PILOTS])
