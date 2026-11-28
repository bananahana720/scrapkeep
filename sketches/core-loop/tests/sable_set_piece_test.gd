# 2026-10-11 (PC-SABLE): Pin 39 checks after adding the peak motif cue assertion.
extends SceneTree
# PC-SABLE: real physics flights, hook rays, timed stake life and Warden resolutions.
# Expected check count is pinned below; an empty or truncated run fails.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const Harpoon := preload("res://src/movement/harpoon.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const T := preload("res://tests/support/t.gd")
const EXPECTED_CHECKS := 39
const BEAT := 60.0 / 172.0
var _t := T.new("sable_set_piece_test")
var _game
var _player
var _ult
var _combat
var _stakes
var _home := Vector3.ZERO
var _release := Vector3.ZERO
var _apex_hits := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _never() -> bool:
	return false


func _reset(id := "cable_run") -> void:
	_ult._abort("stage")
	_stakes.fold()
	_player.reset_to(_home)
	_player.abilities.ultimate_id = id
	_player.tree._knobs = {}
	_ult.meter.locked = false
	_ult.meter.refund(100.0)
	for i in 3:
		await physics_frame


func _plan(to: Vector3, mode := "line") -> Dictionary:
	var from: Vector3 = _player.ball_position()
	var seconds := Ultimate.round_flight(from.distance_to(to), BEAT)
	var beats := roundi(seconds / BEAT)
	return {"from": from, "to": to, "path": mode, "target": null, "beats": beats, "flight": seconds,
		"seconds": seconds + Ultimate.WINDUP_SECONDS,
		"legs": [{"mode": mode, "to": to, "beats": beats, "seconds": seconds, "strike": true}]}


func _ride(to: Vector3, mode := "line") -> void:
	_ult.start(_plan(to, mode))
	var was_recover := false
	for i in 360:
		await physics_frame
		if _ult.phase() == "recover" and not was_recover:
			_release = _player.state.velocity
			was_recover = true
		if _ult.phase() == "idle":
			return


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_ult = _combat.ultimate
	_stakes = _ult.stakes
	for i in 36:
		await physics_frame
	_home = _game.ctx.terrain.drop_point(-45.0, 6.0, 1.0) + Vector3.UP * 8.0
	_ult.beat_seconds = func(): return BEAT
	_t.eq("three Sable dispatch rows", ["cable_run", "ball_lightning", "outpost"].all(func(id): return _ult._ult_rows.has(id)), true)
	await _reset()
	var start: Vector3 = _player.ball_position()
	var to := start + Vector3(32.0, 0.0, 0.0)
	var planned := _plan(to)
	await _ride(to)
	_t.eq("real Cable Run reaches idle", _ult.phase(), "idle")
	_t.eq("one stake per planned beat", _stakes.beat_log.size(), int(planned["beats"]))
	_t.check("normal ride has five to nine beats", _stakes.beat_log.size() >= 5 and _stakes.beat_log.size() <= 9)
	_t.eq("one beachhead in addition to beat stakes", _stakes.nodes.size(), _stakes.beat_log.size() + 1)
	_t.check("every beat callback within one sixteenth", _stakes.beat_log.all(func(row): return absf(float(row["time"]) - float(row["expected"])) <= BEAT / 4.0))
	var note_log: Array = _game.presentation.audio.sable_note_log.filter(func(row): return row["kind"] == "stake")
	_t.eq("one actual audio note decision per stake beat", note_log.size(), _stakes.beat_log.size())
	_t.check("Sable peak resolves her motif stinger", _game.presentation.audio.cue_log.any(func(row): return row[0] == "ultimate_peak" and row[1] == "sable_arpeggio"))
	_t.check("stake geometry has no lights or per-instance material", _stakes.nodes.all(func(n): return n.find_children("*", "Light3D", true, false).is_empty() and n.find_children("*", "MeshInstance3D", true, false).all(func(mesh): return mesh.material_override == null)))
	_t.check("blazing exit in range", _release.length() >= 27.1 - 0.001 and _release.length() <= 45.001, str(_release))
	_t.near("flat exit tips up twelve degrees", rad_to_deg(asin(_release.normalized().y)), 12.0, 2.0)
	_t.check("the log keeps stake counts", _game.ctx.run_log._record["ultimates"].back().has("stakes") and _game.ctx.run_log._record["ultimates"].back().has("stakes_hooked"))
	_stakes.set_physics_process(false)
	var stake = _stakes.nodes.front()
	var collision_free: bool = (stake.collision_layer & _player.body().collision_mask) == 0 and stake.collision_mask == 0
	_t.check("stake cannot collide with the ball", collision_free)
	# Restart the lifetime at the landing boundary, then query real physics at 5.9/6.1.
	_stakes.arm()
	_stakes.step(5.9)
	await physics_frame
	var eye: Vector3 = stake.global_position + Vector3(3.0, 0.0, 0.0)
	var target := Harpoon.target(_player.kit, _player.tuning, _game.get_world_3d().direct_space_state, [], eye, Vector3.LEFT, eye)
	_t.check("anchor query bites a stake at 5.9 seconds", target.get("body") == stake, str(target))
	_player.grapple_to(stake.global_position, Vector3.LEFT, stake)
	_t.eq("stake bite is a pivot not an enemy link", _player.chain.combo, 0)
	_t.eq("stake hook is counted", _stakes.hooked, 1)
	_t.eq("late hook updates the run log", _game.ctx.run_log._record["ultimates"].back().get("stakes_hooked", -1), 1)
	_stakes.step(0.2)
	_t.eq("all stakes gone at 6.1 seconds", _stakes.nodes.size(), 0)
	_stakes.set_physics_process(true)
	await _reset()
	_ult._id = "cable_run"
	_ult._plan = {"from": _home}
	_ult._record = {"stakes": 0}
	var enemy: Node3D = _combat.spawn_enemy("chaser", _home + Vector3.RIGHT * 50.0)
	enemy.live = _never
	enemy.hp = 5000.0
	enemy.max_hp = 5000.0
	var before: float = enemy.hp
	var mult := 1.6
	var result: Array = _ult._sable_landing(enemy.global_position, 1.3, mult)
	# The chaser is a soaked Spillway crew (design-v3/SPILLWAY-ROSTER.md): the arc landing reads its wet multiplier.
	var soaked := DamageFamilies.mult(String(DamageFamilies.ARMOUR_OF.get("chaser", "")), "arc", "")
	_t.near("landing damage is heft times paid chain", before - enemy.hp, 60.0 * 1.3 * mult * soaked, 0.01)
	_t.eq("landing reports hits", int(result[0]), 1)
	_t.eq("heft-I landing radius", _ult.landing_radius(), 6.0)
	for i in 14:
		_stakes.plant(_home + Vector3.RIGHT * i)
	_t.eq("eleven-stake cap", _stakes.nodes.size(), 11)
	_stakes.begin()
	_t.eq("a new route folds old stakes", _stakes.nodes.size(), 0)
	await _reset("ball_lightning")
	_t.eq("Ball Lightning chooses arcs only", AbilityState.ABILITIES["ball_lightning"]["paths"], ["arc"])
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 12.0, 12.0)
	collision.shape = box
	wall.add_child(collision)
	root.add_child(wall)
	wall.global_position = _home + Vector3(8.0, -3.0, 0.0)
	await physics_frame
	_player.state.air_actions = 0
	await _ride(_player.ball_position(), "hop")
	_t.eq("apex discharge fires once", _ult._lightning_peaks, 1)
	_t.check("lightning landing tags a steep fixture", _player.face_tags.size() >= 1)
	_t.eq("lightning restores air jump", _player.state.air_actions, 1)
	_t.near("lightning bounce is upward", _release.y, 8.0, 0.1)
	wall.queue_free()
	await _reset("outpost")
	to = _player.ball_position() + Vector3(28.0, 0.0, 0.0)
	planned = _plan(to)
	var flight_speed: float = (_player.ball_position() - to).length() / float(planned["flight"])
	await _ride(to)
	_t.eq("Outpost ends mounted", _player.kit.mounted, true)
	_t.near("Outpost banks flight speed", _player.kit.mount_banked, flight_speed, 1.0)
	var plant_preview: Dictionary = _combat.discharge_preview(_player.kit.mount_banked)
	_t.near("Outpost plant discharge uses bank", _combat.last_burst.get("damage", -1), plant_preview["damage"], 0.01)
	_stakes.set_physics_process(false)
	# Force each turret to have a target, so a zero-fire run cannot pass the budget.
	enemy.global_position = _stakes.nodes.front().global_position + Vector3(1.0, 0.0, 1.0)
	_stakes.sentry_log.clear()
	_stakes._sentry_clock = 0.0
	_stakes._sentry_left = 4.0
	_stakes.step(4.01)
	_t.check("Outpost sentries fire within the three-per-beat budget", not _stakes.sentry_log.is_empty() and _stakes.sentry_log.all(func(n): return n > 0 and n <= 3), str(_stakes.sentry_log))
	_t.eq("sentry window ends at four seconds", _stakes._sentry_left, 0.0)
	_stakes.set_physics_process(true)
	await _reset()
	var warden: Node3D = _combat.spawn_enemy("warden", _game.ctx.terrain.drop_point(-25.0, 6.0, 1.0))
	_ult._id = "cable_run"
	_ult._record = {"stakes": 0}
	_ult._posture_spent = {}
	before = warden.posture()
	for i in 9:
		_combat.ult_hit(warden, "arc", 12.0, warden.global_position, false)
	_combat.ult_hit(warden, "arc", 60.0, warden.global_position, true)
	_t.check("closed Warden gains at most the cap once", warden.posture() - before > 0.0 and warden.posture() - before <= Ultimate.warden_cap(warden.monster_build()) + 0.001 and warden.chunks_left() == 4)
	warden._apply_posture({"gain": 100.0, "contact": false})
	await physics_frame
	_combat.ult_hit(warden, "arc", 60.0, warden.global_position, true)
	_t.eq("open core shatters a chunk", warden.chunks_left(), 3)
	for signal_name in ["stage_entered", "player_died", "stage_content_cleared"]:
		_stakes.plant(_home)
		match signal_name:
			"stage_entered": _game.events.stage_entered.emit(1, true)
			"player_died": _game.events.player_died.emit()
			"stage_content_cleared": _game.events.stage_content_cleared.emit("retry")
		_t.eq("stakes fold on " + signal_name, _stakes.nodes.size(), 0)
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())
