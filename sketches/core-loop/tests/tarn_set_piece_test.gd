extends "res://tests/tarn_claw_drag_test.gd"

# 2026-10-11 (PC-TARN): three timing/threshold checks extend the expected count from 50 to 53.

const Enemy := preload("res://src/combat/enemy.gd")
const Progress := preload("res://src/core/progress.gd")
const Profile := preload("res://src/core/profile.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Synth := preload("res://src/presentation/synth.gd")

# PC-TARN, 2026-10-11. Expected: 53 checks including the count assertion.
# Shares the real-game fixture, never the drag test's cases. Rows are called through the
# framework dispatch; throws use CharacterBody3D collision motion. Grants save/reload.


func _initialize() -> void:
	_t = T.new("tarn_set_piece_test")
	# 2026-10-16 (pilot paint): Redjaw Teeth is live; the pending check splits into three.
	_expected_checks = 55
	super._initialize()


func _piece(id: String, from: Vector3, to: Vector3) -> void:
	var ult = _combat.ultimate
	_player.abilities.ultimate_id = id
	ult._id = id
	ult._plan = {"path": "arc", "from": from, "to": to, "flight": 2.4, "seconds": 2.75, "beats": 7,
		"legs": [{"mode": "arc", "to": to, "seconds": 2.4, "beats": 7, "strike": true}]}
	ult.last_plan = ult._plan
	ult._leg = 0
	ult._leg_time = 0.0
	ult._phase = "flight"
	ult._posture_spent = {}
	_game.events.ultimate_started.emit(id, "arc", from, to, 2.75)


func _tech(id: String, beat: int, ball: Vector3, aim := Vector3.FORWARD) -> int:
	return int(_combat.ultimate._ult_rows[id]["tech"].call(beat, ball, aim, 1.0))


func _land(id: String, at: Vector3) -> Array:
	return _combat.ultimate._ult_rows[id]["landing"].call(at, 1.0, 1.0)


func _boss(dx: float) -> Node3D:
	var enemy := Enemy.new()
	enemy.kind = "brindle_hull"
	enemy.weight = 1.0
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	_game.add_child(enemy)
	enemy.add_to_group("enemy")
	enemy.global_position = _player.ball_position() + Vector3.RIGHT * dx
	return enemy


func _run() -> void:
	await _boot()
	_t.eq("base Q is Redjaw Rend", _player.abilities.ultimate_id, "redjaw_rend")
	_t.check("all three rows register tech, peak and landing", Claw.SET_PIECES.all(func(id): return _combat.ultimate._ult_rows.has(id) and _combat.ultimate._ult_rows[id].keys() == ["tech", "peak", "landing"]))
	var ball: Vector3 = _player.ball_position()
	_piece("redjaw_rend", ball, ball + Vector3.RIGHT * 25.0)
	var light := _enemy("chaser", 4.0)
	var heavy := _enemy("lobber", 6.0)
	_t.eq("one side snatches at most two", _tech("redjaw_rend", 1, ball), 2)
	_t.check("only light joins the class I tow", _claw.tow == [light])
	_t.check("heavy still takes snatch damage", _hits(heavy).any(func(row): return absf(float(row[2]) - 12.0) < 0.001))
	_t.check("light is chewed", _hits(light).any(func(row): return absf(float(row[2]) - 4.0) < 0.001))
	await _fresh()
	ball = _player.ball_position()
	_piece("redjaw_rend", ball, ball + Vector3.RIGHT * 25.0)
	for x in [2.0, 4.0, 6.0, 8.0, 9.0]:
		_enemy("chaser", x)
	_tech("redjaw_rend", 1, ball)
	_tech("redjaw_rend", 3, ball)
	_tech("redjaw_rend", 5, ball)
	_t.eq("class I caps tow at three", _claw.tow.size(), 3)
	_game.run.mass = 1500.0
	_claw.tow.clear()
	_tech("redjaw_rend", 1, ball)
	_tech("redjaw_rend", 3, ball)
	_tech("redjaw_rend", 5, ball)
	_t.eq("class IV can tow five available bodies", _claw.tow.size(), 5)
	_t.check("tow never exceeds 2 plus class", _claw.tow.size() <= 2 + _game.run.heft_class())

	await _fresh()
	ball = _player.ball_position()
	_piece("redjaw_rend", ball, ball + Vector3.RIGHT * 25.0)
	var boss := _boss(4.0)
	var warden := _enemy("warden", 6.0)
	warden.set_physics_process(false)
	var original := [boss.global_position, warden.global_position]
	_tech("redjaw_rend", 1, ball)
	_t.check("boss and Warden never tow", _claw.tow.is_empty())
	_t.eq("snatch moves neither protected body", [boss.global_position, warden.global_position], original)
	_land("redjaw_rend", ball)
	_t.eq("landing marks neither protected body", [_combat._clamped.has(boss.get_instance_id()), _combat._clamped.has(warden.get_instance_id())], [false, false])
	_t.check("whole set piece respects posture cap", warden.posture() <= 45.0)
	_t.eq("landing moves neither protected body", [boss.global_position, warden.global_position], original)

	await _fresh()
	ball = _player.ball_position()
	_piece("redjaw_rend", ball, ball)
	light = _enemy("chaser", 3.0)
	_claw.tow.append(light)
	var result := _land("redjaw_rend", ball)
	_t.eq("landing hits carried body", result[0], 1)
	_t.near("carried landing is x1.25", float(result[1]), 75.0)
	_t.check("landing knock is inward", (light._knock as Vector3).dot(ball - light.global_position) > 0.0)
	_t.near("landing mark lasts 3s", float(_combat._clamped[light.get_instance_id()]) - _combat._clock, 3.0)
	_t.check("landing releases tow", _claw.tow.is_empty())

	await _fresh()
	ball = _player.ball_position()
	_piece("rake_run", ball, ball + Vector3.RIGHT * 20.0)
	var inside := _enemy("chaser", 3.0, 2.0)
	var gap := _enemy("chaser", 3.0, 0.0)
	var outside := _enemy("chaser", 3.0, 4.0)
	_t.eq("rake hits exactly one body in drawn strips", _tech("rake_run", 1, ball + Vector3.RIGHT * 6.0), 1)
	_t.eq("rake deals ten", _hits(inside).map(func(row): return row[2]), [10.0])
	_t.eq("rake leaves centre gap clear", _hits(gap), [])
	_t.eq("rake leaves outside strip clear", _hits(outside), [])
	_t.check("rake knock points inward", (inside._knock as Vector3).dot(ball + Vector3.RIGHT * 6.0 - inside.global_position) > 0.0)
	_t.near("rake mark lasts 1.5s", float(_combat._clamped[inside.get_instance_id()]) - _combat._clock, 1.5)
	_t.check("renderer gets exact committed geometry", _claw._rakes.all(func(r): return _player.indicator.shapes[r["layer"]] == r["shape"]))
	_claw.step(2.01)
	_t.eq("rake drawing expires after 2s", _claw._rakes.size(), 0)
	_land("rake_run", ball)
	_t.near("rake landing grants three seconds frenzy", _combat._overdrive, 3.0)

	await _fresh()
	ball = _player.ball_position()
	_player.abilities.ultimate_id = "vice_leap"
	var aim := {"origin": ball + Vector3.UP * 2.0, "forward": Vector3(1.0, -0.5, 0.0).normalized(), "harpoon": {"state": 0}}
	var anchor := ball + Vector3.RIGHT * 15.0
	_player.grapple_to(anchor, Vector3.LEFT, null)
	var plan: Dictionary = _combat.ultimate.plan(ball, aim)
	_t.eq("Vice Leap chooses valid arc before a standing line", plan["path"], "arc")
	var normal_beats: int = plan["beats"]
	_player.tree._knobs["ult_beats"] = 2
	var longer: Dictionary = _combat.ultimate.plan(ball, aim)
	_t.eq("ult_beats adds two snatch beats", longer["beats"], normal_beats + 2)
	_player.tree._knobs.clear()
	_piece("vice_leap", ball, anchor)
	light = _enemy("chaser", 4.0)
	_tech("vice_leap", 1, ball)
	_t.eq("Vice Leap hurls one light body", _claw.hurls.size(), 1)
	await _drag_for(2.4)
	_t.check("hurled body arrives within 2m of B", light.global_position.distance_to(anchor) <= 2.0, str(light.global_position.distance_to(anchor)))
	_combat.ultimate._ult_rows["vice_leap"]["peak"].call(ball)
	_t.near("vice radius is class radius plus two", float(_claw._vice["radius"]), 8.0)
	_player.tree._knobs["ult_radius"] = 2.0
	_combat.ultimate._ult_rows["vice_leap"]["peak"].call(ball)
	_t.near("ult_radius widens vice by two more", float(_claw._vice["radius"]), 10.0)
	var landed := _land("vice_leap", anchor)
	_t.eq("Vice Leap landing reaches its thrown catch", landed[0], 1)
	_t.near("Vice Leap mark lasts four seconds", float(_combat._clamped[light.get_instance_id()]) - _combat._clock, 4.0)
	_player.tree._knobs.clear()

	await _fresh()
	ball = _player.ball_position()
	_piece("rake_run", ball, ball + Vector3.RIGHT * 20.0)
	_player.tree._knobs["ult_volley"] = 1
	_tech("rake_run", 1, ball + Vector3.RIGHT * 6.0)
	_t.near("ult_volley widens rake to 4.5m", float(_claw.rake_shapes[0]["width"]), 4.5)
	_player.tree._knobs.clear()
	var encore_target := _enemy("chaser", 15.0)
	_t.check("encore can find a second landing", _combat.ultimate._encore_target(ball) != null and is_instance_valid(encore_target))
	_t.eq("encore node sets second leg switch", preload("res://src/core/trees/tarn.gd").NODES[17]["knob"], {"ult_encore": true})

	await _grants()
	_finish()


func _grants() -> void:
	await _fresh()
	var store := Profile.new("user://tarn-grants-%d.json" % OS.get_process_id())
	store.load_profile()
	var progress := Progress.new()
	progress.rows = {}
	var grant_ids := ["ach_tarn_dragged", "ach_tarn_six_at_once", "ach_tarn_hold_still"]
	for id in grant_ids:
		progress.rows[id] = Achievements.row(id)
	progress.setup(_game.events, null, store, func(): return 50.0, _game.ctx.codex)
	var found: Array = []
	var frames: Array = []
	_game.events.synergy_discovered.connect(func(id: String, _category: String, _first: bool):
		found.append(id)
		frames.append([id, Engine.get_physics_frames()]))
	var codex = _game.ctx.codex
	codex.mark_discovered("loaded_line")
	codex.mark_discovered("set_piece")
	codex.mark_discovered("set_piece_breakout")
	for i in 10:
		var light := _enemy("chaser", 3.0)
		_cast(light)
		await _drag_for(0.15)
		if i == 8:
			_t.check("nine distinct drags do not grant the trail", not store.earned("ach_tarn_dragged"))
		_player.kit.drop_line("reset")
		_player.kit.rewind_left = 0.0
		_player.abilities.refill()
		_player._fire_latched = false
		light.remove_from_group("enemy")
		light.queue_free()
	_claw.step(DT)
	_t.eq("Claw Drag codex opens once", found.count("tarn_claw_drag"), 1)
	_t.eq("ten distinct drags fire stage discovery", found.count("tarn_dragged"), 1)
	_game.events.ultimate_landed.emit("redjaw_rend", _player.ball_position(), 5, 300.0)
	_t.eq("five hits do not grant teeth", store.earned("ach_tarn_six_at_once"), false)
	_game.events.ultimate_landed.emit("redjaw_rend", _player.ball_position(), 6, 360.0)
	var ball: Vector3 = _player.ball_position()
	_piece("redjaw_rend", ball, ball)
	var enemy := _enemy("chaser", 3.0)
	_claw.tow.append(enemy)
	_land("redjaw_rend", ball)
	await physics_frame
	_claw.step(DT)
	_piece("redjaw_rend", ball, ball)
	_claw.tow.append(enemy)
	_land("redjaw_rend", ball)
	await physics_frame
	_claw.step(DT)
	_t.eq("Redjaw Rend codex opens once", found.count("tarn_redjaw_rend"), 1)
	_player.abilities.ultimate_id = "redjaw_rend"
	for i in 3:
		var ult = _combat.ultimate
		ult._phase = "idle"
		ult.meter.locked = false
		ult.meter.refund(100.0)
		_combat.fleet.holds.immune_left = 0.0
		_combat.fleet.holds.catch(enemy, "net", ["jump"])
		ult.start(ult.plan(ball, {"origin": ball, "forward": Vector3.UP, "harpoon": {"state": 0}}))
		ult.recall()
	await physics_frame
	_claw.step(DT)
	_t.eq("three Q breaks fire hidden discovery", found.count("tarn_hold_still"), 1)
	var pilot_frames: Array = frames.filter(func(row): return String(row[0]).begins_with("tarn_")).map(func(row): return row[1])
	var unique_frames := {}
	for frame in pilot_frames:
		unique_frames[frame] = true
	_t.check("pilot cards never share a discovery tick", pilot_frames.size() == unique_frames.size())
	var framework_frames: Array = frames.filter(func(row): return row[0] in ["loaded_line", "set_piece", "set_piece_breakout"]).map(func(row): return row[1])
	_t.check("pilot cards follow the framework on a later tick", pilot_frames.all(func(frame): return not framework_frames.has(frame)))
	_t.check("all three grants earned", grant_ids.all(func(id): return store.earned(id)))
	var items := ["trail_tarn_claw_marks", "shell_tarn_redjaw_teeth", "outfit_tarn_steady_cap"]
	_t.check("all three looks unlocked", items.all(func(id): return store.has_cosmetic(id)))
	# Re-pinned 2026-10-16 (COSMETICS-ART-BRIEFS port note 1): the shell is live; the trail and outfit wait.
	_t.check("pending art hidden on the trail and outfit", items.filter(func(id): return id != "shell_tarn_redjaw_teeth").all(func(id): return Cosmetics.PENDING_ART.has(id)))
	_t.check("the shell is live", not Cosmetics.is_pending("shell_tarn_redjaw_teeth") and FileAccess.file_exists("res://assets/models/world_one/shell_tarn_redjaw_teeth.glb"))
	_t.check("no price", items.all(func(id): return not Cosmetics.row(id).has("price") and not Cosmetics.row(id).has("cost")))
	var reload_store := Profile.new(store.path)
	reload_store.load_profile()
	_t.check("grants survive reload", grant_ids.all(func(id): return reload_store.earned(id)) and items.all(func(id): return reload_store.has_cosmetic(id)))
	var audio := Audio.new()
	_t.eq("claw cue declares Tarn motif", Audio.LINE_CLAW_DRAG["motif"], "tarn")
	audio.free()
	progress.free()
