extends SceneTree

# Shift variants (W46-08, src/core/shift_variants.gd):
# - Fresh/unstamped profile opens no variants, plays none, leaves run.extra clean and keeps
#   20-seed base run hashes identical.
# - Stamping first_warden opens overtime, brindle_routed opens dam_night_shift, mark_sable
#   opens crew_short; stamping mark_rivet does NOT open unbuilt flume_backwash.
# - First run after a variant opens plays its guaranteed debut and records the debut stat;
#   later runs draw deterministically from run_seed; Continue keeps saved variants without
#   re-rolling or consuming new debuts; bot runs never draw or consume debuts.
# - Each built variant changes exactly what its ShiftBoard.SEEDS line says:
#   - dam_night_shift: look id "dam_night", fuller dam crew (pack_scale up, interval_scale down,
#     no threat or Warden HP scaling per ruling al), and one extra salvage cage on the dam that
#     pays a scrap burst once with no pilot unlock, no lasting stat and no panel.
#   - overtime: wakes Wardens early (ahead of the ring) and pays one extra panel per run, banked once.
#   - crew_short: closes the dam shop on stage 1 and adds a cracked cache on the apron clear of surplus.
# - No lasting stat buff across runs.
# - Shift Board UI (AchievementsPage) lists each built variant under the rung that opens it
#   and never shows flume_backwash.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Profile := preload("res://src/core/profile.gd")
const RunState := preload("res://src/core/run_state.gd")
const RunStore := preload("res://src/core/run_store.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const Panels := preload("res://src/build/panels.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "user://test-shift-variants/"

var _t := T.new("shift_variants_test")
var _serial := 0
var _paths: Array[String] = []
var _game: Node = null
var _phase := 0
var _ticks := 0
var _base_stats := {}
var _base_pack_scale := 0.0
var _base_interval_scale := 0.0
var _base_threat := 0.0
var _base_warden_hp := 0.0
var _base_warden_plating := 0.0
var _base_cap := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	ShiftVariants.clear_force()
	_check_fresh_and_hashes()
	_check_unlocks_and_draws()
	_check_board_ui()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)


func _path(tag: String) -> String:
	_serial += 1
	var p := "%s%s-%d-%d.json" % [DIR, tag, OS.get_process_id(), _serial]
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	_paths.append(p)
	return p


func _fresh_profile(tag := "profile") -> Profile:
	var store := Profile.new(_path(tag))
	store.load_profile()
	return store


func _hash_seed(seed_value: int, profile) -> int:
	var run := RunState.new()
	run.run_seed_override = seed_value
	run.begin(ClassDef.by_id("pylon_engineer"))
	ShiftVariants.attach_run(run, profile, [], false)
	var picks := StartPicks.draw("pylon_engineer", run.run_seed, 0)
	var mod := StageModifier.pick(run.run_seed, 1, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.run_seed, 1, "panel_check"])
	var panel := Panels.draw(rng, "pylon_engineer")
	var doc := run.to_entrance_doc()
	return hash([
		ShiftVariants.active(run),
		run.extra.keys(),
		picks,
		mod,
		panel,
		doc.has(ShiftVariants.RUN_KEY),
		StageModifier.memo(run.run_seed, 1, mod),
	])


func _check_fresh_and_hashes() -> void:
	var fresh := _fresh_profile("fresh")
	_t.eq("fresh profile opens no variants", ShiftVariants.open_for(fresh), [])
	var all_empty := true
	var hashes_match := true
	for i in 20:
		var s := 1001 + i * 37
		if not ShiftVariants.active_for(fresh, s).is_empty():
			all_empty = false
		ShiftVariants.clear_force()
		var h_fresh := _hash_seed(s, fresh)
		ShiftVariants.force([])
		var h_base := _hash_seed(s, fresh)
		ShiftVariants.clear_force()
		if h_fresh != h_base:
			hashes_match = false
	_t.check("fresh profile plays no variants across 20 seeds", all_empty)
	_t.check("fresh profile 20-seed run hashes equal base", hashes_match)


func _check_unlocks_and_draws() -> void:
	var p := _fresh_profile("unlocks")
	p.earn("warden_broken", 1000)
	_t.eq("first_warden opens overtime", ShiftVariants.open_for(p), [ShiftVariants.OVERTIME])
	_t.check("overtime debut needed before first shift", ShiftVariants.debut_needed(ShiftVariants.OVERTIME, p))

	p.earn("brindle_routed", 1001)
	_t.eq("brindle_routed adds dam_night_shift", ShiftVariants.open_for(p), [ShiftVariants.OVERTIME, ShiftVariants.DAM_NIGHT_SHIFT])

	p.earn("brindle_mark_sable", 1002)
	_t.eq("mark_sable adds crew_short", ShiftVariants.open_for(p), [ShiftVariants.OVERTIME, ShiftVariants.DAM_NIGHT_SHIFT, ShiftVariants.CREW_SHORT])

	p.earn("brindle_mark_rivet", 1003)
	_t.check("mark_rivet does not open unbuilt flume_backwash", not ("flume_backwash" in ShiftVariants.open_for(p)))
	_t.eq("only the three built variants open", ShiftVariants.open_for(p).size(), 3)

	# Bot runs never consume debuts or draw variants.
	_t.eq("bot run consumes no debuts", ShiftVariants.consume_debuts(p, true), [])
	_t.eq("bot run plays no variants", ShiftVariants.resolve_run(p, 42, [], true), [])
	_t.check("bot run left debut intact", ShiftVariants.debut_needed(ShiftVariants.OVERTIME, p))

	# First real run consumes debuts and guarantees all newly opened variants play.
	var debuts := ShiftVariants.consume_debuts(p, false)
	_t.eq("first run consumes all three debuts", debuts, [ShiftVariants.OVERTIME, ShiftVariants.DAM_NIGHT_SHIFT, ShiftVariants.CREW_SHORT])
	_t.check("debut cleared after consumption", not ShiftVariants.debut_needed(ShiftVariants.OVERTIME, p))
	_t.eq("debut run plays all newly opened variants", ShiftVariants.resolve_run(p, 7, debuts, false), debuts)

	# Subsequent runs draw deterministically from run_seed (both hits and misses across 50 seeds).
	var hits := 0
	var misses := 0
	var deterministic := true
	for i in 50:
		var s := 2000 + i
		var a := ShiftVariants.active_for(p, s)
		var b := ShiftVariants.active_for(p, s)
		if a != b:
			deterministic = false
		if ShiftVariants.OVERTIME in a:
			hits += 1
		else:
			misses += 1
	_t.check("post-debut draws are deterministic per seed", deterministic)
	_t.check("post-debut draws both hit and miss across 50 seeds", hits > 0 and misses > 0, "hits=%d misses=%d" % [hits, misses])

	# Force seam overrides profile and ignores unbuilt ids.
	ShiftVariants.force([ShiftVariants.CREW_SHORT, "flume_backwash"])
	_t.eq("force ignores unbuilt ids", ShiftVariants.active(null), [ShiftVariants.CREW_SHORT])
	ShiftVariants.clear_force()
	_t.eq("clear_force restores normal resolution", ShiftVariants.forced(), null)


func _check_board_ui() -> void:
	var fresh := _fresh_profile("ui_fresh")
	_t.eq("board_lines still returns 3 lines", AchievementsPage.board_lines(fresh).size(), 3)
	var entries := AchievementsPage.variant_entries(fresh)
	_t.eq("board shows 3 built variants", entries.size(), 3)
	var ids := entries.map(func(e): return e["id"])
	_t.check("board hides unbuilt flume_backwash", not ("flume_backwash" in ids))
	var by_id := {}
	for e in entries:
		by_id[e["id"]] = e
	_t.eq("overtime sits under Warden Breaker", by_id[ShiftVariants.OVERTIME]["rung_name"], "Warden Breaker")
	_t.eq("dam_night_shift sits under Brindle Routed", by_id[ShiftVariants.DAM_NIGHT_SHIFT]["rung_name"], "Brindle Routed")
	_t.eq("crew_short sits under Sable's Mark", by_id[ShiftVariants.CREW_SHORT]["rung_name"], "Sable's Mark")
	_t.check("fresh board variants start locked", not bool(by_id[ShiftVariants.OVERTIME]["open"]) and not bool(by_id[ShiftVariants.DAM_NIGHT_SHIFT]["open"]) and not bool(by_id[ShiftVariants.CREW_SHORT]["open"]))

	var page := AchievementsPage.new()
	root.add_child(page)
	page.refresh(fresh, null)
	_t.eq("fresh AchievementsPage builds 3 variant cards", page.variant_cards.size(), 3)
	_t.check("fresh AchievementsPage has no flume_backwash card", not page.variant_cards.has("flume_backwash"))

	fresh.earn("warden_broken", 1000)
	fresh.earn("brindle_routed", 1001)
	fresh.earn("brindle_mark_sable", 1002)
	page.refresh(fresh, null)
	var open_entries := AchievementsPage.variant_entries(fresh)
	_t.check("stamped rungs mark all 3 board variants open", open_entries.all(func(e): return bool(e["open"])))
	root.remove_child(page)
	page.free()


func _start_run(variants: Array, seed_value := 404) -> void:
	ShiftVariants.force(variants)
	_game.ctx.calm = false
	_game.player.source = Intent.Scripted.new()
	_game.ctx.run.run_seed_override = seed_value
	_game.flow.show_title()
	_game.flow.press_start()
	_game.flow.choose_class(0)


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_ticks += 1
	if _ticks > 600:
		_t.check("test finished within tick watchdog", false, "stuck at phase %d" % _phase)
		_cleanup_and_quit()
		return true
	if _ticks < 4:
		return false
	match _phase:
		0:
			# Baseline run with no variants active.
			_start_run([], 404)
			var def: Dictionary = _game.flow.stage_def()
			var p: Dictionary = def.get("pressure", {})
			_base_pack_scale = float(p.get("pack_scale", 1.0))
			_base_interval_scale = float(p.get("interval_scale", 1.0))
			_base_threat = float(def["threat"])
			_base_warden_hp = float(def["warden_hp"])
			_base_warden_plating = float(def["warden_plating"])
			_base_cap = _game.world.director.cap()
			_base_stats = {
				"max_hp": _game.ctx.run.max_hp,
				"cruise": _game.player.tuning.f("cruise"),
				"parts": _game.ctx.run.parts.size(),
				"panels": _game.ctx.run.panels.size(),
				"heft": _game.ctx.run.heft(),
				"cogs": _game.ctx.run.cogs,
			}
			_t.eq("base look_id is empty", _game.flow.stage_look_id(), "")
			_t.check("base dam has no crew_short_cache site", not _has_crew_short_site())
			_t.check("base dam has no night_shift_cage", _game.world.rescue.cage(ShiftVariants.NIGHT_SHIFT_CAGE_QUEST) == null)
			# Base Warden does not wake at 50 m (outside 30 m ring).
			_move_from_warden(50.0)
			_game.flow.physics_step(0.016)
			_t.check("base Warden stays unengaged at 50 m", not _game.flow.engaged())
			# Base dam docks shop when reward is offered in gates.
			_game.flow._unseal()
			_game.ctx.events.reward_offered.emit([{"part_id": "part_a", "at": _game.flow.beacon.global_position, "facing": Vector3.FORWARD}])
			_t.check("base dam docks shop on reward_offered", _game.world.bay.docked)
			_phase = 1
		1:
			# Night Shift: look id + fuller crew (pressure only, no enemy health scaling) + extra salvage cage.
			_start_run([ShiftVariants.DAM_NIGHT_SHIFT], 404)
			var def: Dictionary = _game.flow.stage_def()
			var p: Dictionary = def.get("pressure", {})
			_t.eq("night shift stage 1 look_id is dam_night", _game.flow.stage_look_id(), "dam_night")
			_t.eq("night shift stage 2 look_id is empty", ShiftVariants.look_id(_game.ctx.run, 2), "")
			_t.check("night shift raises pack_scale", is_equal_approx(float(p["pack_scale"]), _base_pack_scale * ShiftVariants.NIGHT_PACK_SCALE))
			_t.check("night shift lowers interval_scale", is_equal_approx(float(p["interval_scale"]), _base_interval_scale * ShiftVariants.NIGHT_INTERVAL_SCALE))
			_t.eq("night shift keeps stage threat unchanged (ruling al)", float(def["threat"]), _base_threat)
			_t.eq("night shift keeps warden_hp unchanged (ruling al)", float(def["warden_hp"]), _base_warden_hp)
			_t.eq("night shift keeps warden_plating unchanged (ruling al)", float(def["warden_plating"]), _base_warden_plating)
			_t.check("night shift raises director crowd cap", _game.world.director.cap() > _base_cap, "%d vs %d" % [_game.world.director.cap(), _base_cap])
			_t.check("night shift appears on stage 1 card line", StageModifier.card_line(_game.ctx.run, _game.world.terrain, 1).contains("Night Shift"))
			_t.check("night shift does not appear on stage 2 card line", not StageModifier.card_line(_game.ctx.run, _game.world.terrain, 2).contains("Night Shift"))

			# Extra salvage cage on the dam: present, clear of yard-lock zone, flat ground, pays scrap once.
			var night_cage = _game.world.rescue.cage(ShiftVariants.NIGHT_SHIFT_CAGE_QUEST)
			_t.check("night shift builds one more cage on the dam", night_cage != null)
			_t.eq("night shift builds two cages total on the dam", _game.world.rescue.cages.size(), 2)
			var cage_at: Vector2 = ShiftVariants.NIGHT_SHIFT_CAGE["at"]
			_t.check("night shift cage sits outside the 200 m yard-lock trigger", cage_at.distance_to(Vector2(0.0, 575.0)) > 250.0)
			var scrap_before: int = _game.ctx.run.scrap
			var panels_before: int = _game.ctx.run.panels.size()
			var pilots_before: int = _unlocked_pilot_count()
			_game.world.rescue.complete(ShiftVariants.NIGHT_SHIFT_CAGE_QUEST)
			_t.eq("freeing night shift cage pays scrap burst", _game.ctx.run.scrap, scrap_before + ShiftVariants.NIGHT_SHIFT_CAGE_SCRAP)
			_t.eq("freeing night shift cage pays no panel", _game.ctx.run.panels.size(), panels_before)
			_t.eq("freeing night shift cage unlocks no pilot", _unlocked_pilot_count(), pilots_before)
			# Completing again in the same run pays nothing extra.
			_game.world.rescue.complete(ShiftVariants.NIGHT_SHIFT_CAGE_QUEST)
			_t.eq("night shift cage pays at most once per run", _game.ctx.run.scrap, scrap_before + ShiftVariants.NIGHT_SHIFT_CAGE_SCRAP)
			_phase = 2
		2:
			# Overtime: wakes Warden early at 50 m and breaking a Warden pays one panel per run, banked once.
			_start_run([ShiftVariants.OVERTIME], 404)
			var panels_before: int = _game.ctx.run.panels.size()
			_move_from_warden(50.0)
			_game.flow.physics_step(0.016)
			_t.check("overtime wakes Warden early at 50 m", _game.flow.engaged())
			# Break stage 1 Warden: pays 1 panel.
			_break_warden()
			_t.eq("overtime Warden break pays one extra panel", _game.ctx.run.panels.size(), panels_before + 1)
			# Retry restores stage-entry panels so retrying cannot farm panels.
			_game.flow.retry_stage()
			_t.eq("retry restores panels before Warden break", _game.ctx.run.panels.size(), panels_before)
			# A vanished Warden does not pay the bonus panel.
			_game.flow._warden_vanished()
			_t.eq("vanished Warden pays no overtime panel", _game.ctx.run.panels.size(), panels_before)
			# Retry and break stage 1 Warden legitimately, then advance to stage 2: stage 2 break pays 0 extra.
			_game.flow.retry_stage()
			_break_warden()
			_t.eq("retried stage 1 Warden break pays the run's one panel", _game.ctx.run.panels.size(), panels_before + 1)
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_break_warden()
			_t.eq("stage 2 Warden break pays no second overtime panel (one per run)", _game.ctx.run.panels.size(), panels_before + 1)
			_t.check("overtime appears on stage 1 and stage 2 card lines",
				StageModifier.card_line(_game.ctx.run, _game.world.terrain, 1).contains("Overtime")
				and StageModifier.card_line(_game.ctx.run, _game.world.terrain, 2).contains("Overtime"))
			_phase = 3
		3:
			# Short Crew: no dam shop on stage 1 and an extra cracked cache on the dam apron clear of surplus.
			_start_run([ShiftVariants.CREW_SHORT], 404)
			_t.check("crew_short adds crew_short_cache cracked_cache on dam", _has_crew_short_site())
			var map = _game.world.terrain.map()
			var at: Vector2 = ShiftVariants.CREW_SHORT_CACHE["at"]
			_t.check("crew_short cache sits inside dam play_rect", map.play_rect.has_point(at), str(at))
			var clear_of_drawn := true
			for s in _game.world.activities.sites:
				var s_at := Vector2(s.global_position.x, s.global_position.z)
				if s.drawn and at.distance_to(s_at) < 25.0:
					clear_of_drawn = false
			_t.check("crew_short cache stands clear of drawn pockets", clear_of_drawn)
			_game.flow._unseal()
			_game.ctx.events.reward_offered.emit([{"part_id": "part_a", "at": _game.flow.beacon.global_position, "facing": Vector3.FORWARD}])
			_t.check("crew_short keeps dam shop closed on stage 1", not _game.world.bay.docked)
			_t.check("crew_short leaves stage 2 shop open", ShiftVariants.dam_shop_open(_game.ctx.run, 2))
			_t.eq("crew_short adds no site on flume", ShiftVariants.extra_sites("park_flume", _game.ctx.run), [])
			_t.check("crew_short appears on stage 1 card line only",
				StageModifier.card_line(_game.ctx.run, _game.world.terrain, 1).contains("Short Crew")
				and not StageModifier.card_line(_game.ctx.run, _game.world.terrain, 2).contains("Short Crew"))
			_phase = 4
		4:
			# Live Flow debut + Continue round-trip through RunStore (non-bot player path).
			ShiftVariants.clear_force()
			var was_bot: bool = _game.bot_driven
			_game.bot_driven = false
			var prof := _fresh_profile("flow_debut")
			prof.earn("warden_broken", 1000)
			var store := RunStore.new(_path("run_save"))
			_game.ctx.profile = prof
			_game.flow.store = store
			_game.ctx.run.run_seed_override = 777
			_game.flow.show_title()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_t.eq("live flow debut activates overtime", ShiftVariants.active(_game.ctx.run), [ShiftVariants.OVERTIME])
			_t.check("live flow debut records seen stat on profile", int(prof.stat(ShiftVariants.debut_stat(ShiftVariants.OVERTIME))) == 1)
			# Stamp another rung mid-run, return to title, and Continue: saved run keeps overtime only
			# and does not consume the new rung's debut.
			prof.earn("brindle_routed", 1001)
			_game.flow.show_title()
			_t.check("resume_run succeeds with saved shift_variants", _game.flow.resume_run())
			_t.eq("Continue keeps original run's shift_variants", ShiftVariants.active(_game.ctx.run), [ShiftVariants.OVERTIME])
			_t.check("Continue does not consume newly stamped rung's debut", ShiftVariants.debut_needed(ShiftVariants.DAM_NIGHT_SHIFT, prof))
			_game.flow.store = null
			_game.bot_driven = was_bot
			_phase = 5
		5:
			# No lasting stat buff: after playing all variants, a clean run matches base stats.
			_start_run([], 404)
			var after_stats := {
				"max_hp": _game.ctx.run.max_hp,
				"cruise": _game.player.tuning.f("cruise"),
				"parts": _game.ctx.run.parts.size(),
				"panels": _game.ctx.run.panels.size(),
				"heft": _game.ctx.run.heft(),
				"cogs": _game.ctx.run.cogs,
			}
			_t.eq("no lasting stat buff after variant runs", after_stats, _base_stats)
			_phase = 6
			_cleanup_and_quit()
	return false


func _unlocked_pilot_count() -> int:
	if _game.ctx.profile == null:
		return 0
	return ClassDef.all().filter(func(d): return _game.ctx.profile.has_pilot(d.id)).size()


func _break_warden() -> void:
	if is_instance_valid(_game.flow.warden):
		_game.flow.warden.hp = 0.0
	_game.ctx.events.enemy_killed.emit("warden", _game.flow._warden_at, 0)


func _has_crew_short_site() -> bool:
	for s in _game.world.activities.sites:
		if s.row_id == "crew_short_cache" and s.id == "cracked_cache":
			return true
	return false


func _move_from_warden(distance: float) -> void:
	var w: Vector3 = _game.flow._warden_at
	var x: float = w.x
	var z: float = w.z - distance
	var y: float = _game.world.terrain.height(x, z) + 1.0
	_game.player.reset_to(Vector3(x, y, z), Vector3.ZERO)


func _cleanup_and_quit() -> void:
	ShiftVariants.clear_force()
	_finish.call_deferred()


func _finish() -> void:
	if is_instance_valid(_game):
		_game.queue_free()
		_game = null
		await process_frame
		await process_frame
	for p in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		if FileAccess.file_exists(p + ".prev"):
			DirAccess.remove_absolute(p + ".prev")
	quit(_t.verdict())
