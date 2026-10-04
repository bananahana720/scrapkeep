extends SceneTree

# Legacy plating/third-stage rule: use the multiworld double, not the alpha route.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Warden := preload("res://src/combat/warden.gd")
const StageDefs := preload("res://tests/doubles/two_world_defs.gd").FirstWorld

# The Warden's per-stage lessons, as data, and the event miniboss's plating.
# - Stage 2, "caps": a stomp of force 10 at heft 1 (punch 41) lands on a vent cap at
#   plating 0 for 1.5 times its punch, though the Warden's plating is 60; the same
#   stomp off the caps chips 20% and is deflected.
# - Stage 3, "magnet": a real bolt on the magnet during a tug drops plating_of(warden)
#   to 0 for 3.0 s, within one tick. With drive held away from the Warden, planar
#   speed stays above 0.8 x cruise through a whole tug.
# - Stage 2's event miniboss has plating 1.25 x stage 2's Warden plating (80, so 100).
# Waits for the Warden's cycles run at WAIT_SCALE; every measurement runs at 1.

const WAIT_SCALE := 3.0
const STAND_OFF := 12.0
const TICK := 1.0 / 90.0

# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _phase := "setup"
var _warden: Node3D
var _anchor := Vector3.ZERO
var _zero_ticks := 0
var _stun_seen := false
var _min_planar := INF
var _tug_ticks := 0
var _pulled_ticks := 0
var _tug_min := INF
var _control_ticks := 0
var _away := Vector3.ZERO
var _clock := 0.0


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	match _phase:
		"setup":
			_setup()
			_caps()
			_miniboss()
			_start_magnet()
		"await_tug":
			_game.player.reset_to(_anchor)
			if _warden.state_name() == "tug":
				Engine.time_scale = 1.0
				_source.hold = {"fire_held": true}
				_phase = "shoot_magnet"
				_clock = 0.0
		"shoot_magnet":
			_game.player.reset_to(_anchor)
			_aim_at(_warden.magnet_point())
			if _warden.magnet_stuns >= 1:
				_source.hold = {}
				_stun_seen = true
				_phase = "time_unplated"
			elif _warden.state_name() != "tug":
				_report("magnet_stun", false, "the tug ended without a bolt on the magnet")
				return _finish()
		"time_unplated":
			_game.player.reset_to(_anchor)
			if _combat.plating_of(_warden) == 0.0:
				_zero_ticks += 1
			else:
				var seconds := _zero_ticks * TICK
				_report("magnet_stun", _stun_seen and absf(seconds - Warden.UNPLATE_SECONDS) <= TICK + 0.0001 and _combat.plating_of(_warden) == StageDefs.of(3)["warden_plating"],
					"a bolt on the magnet mid-tug held plating_of(warden) at 0 for %d ticks = %.3f s (needs 3.0 +- 1 tick), then back to %.0f"
						% [_zero_ticks, seconds, _combat.plating_of(_warden)])
				Engine.time_scale = WAIT_SCALE
				_phase = "await_second_tug"
		"await_second_tug":
			_game.player.reset_to(_anchor)
			if _warden.state_name() == "tug":
				Engine.time_scale = 1.0
				_start_run_away()
				_phase = "tug_run"
		"tug_run":
			var flat: Vector3 = _game.player.ball_position() - _warden.global_position
			flat.y = 0.0
			if _warden.state_name() == "tug":
				_tug_ticks += 1
				var zone: Node3D = _warden.get("_magnet_ring")
				if is_instance_valid(zone) and zone.contains(_game.player.ball_position()):
					_pulled_ticks += 1
				if flat.length() <= _warden.reach:
					_min_planar = minf(_min_planar, _game.player.planar_velocity().length())
				return false
			# The same run with no tug, for comparison.
			_tug_min = _min_planar
			_min_planar = INF
			_control_ticks = 0
			_warden.lesson = "plate"
			_start_run_away()
			_phase = "control_run"
		"control_run":
			var flat: Vector3 = _game.player.ball_position() - _warden.global_position
			flat.y = 0.0
			_control_ticks += 1
			if flat.length() <= _warden.reach:
				_min_planar = minf(_min_planar, _game.player.planar_velocity().length())
			if _control_ticks < _tug_ticks:
				return false
			var cruise: float = _game.ctx.tuning.f("cruise")
			_report("tug_escape", _tug_ticks > 60 and _pulled_ticks > 60 and _tug_min > 0.8 * cruise,
				"driving away through a %.2f s tug, %d ticks inside the pull wedge, planar speed never fell below %.2f m/s (needs > %.2f, 0.8 x cruise); the same run with no tug bottomed at %.2f m/s"
					% [_tug_ticks * TICK, _pulled_ticks, _tug_min, 0.8 * cruise, _min_planar])
			return _finish()
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.ctx._hit_stop = Callable()
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_combat.heft_override = 1.0


func _enter(stage: int) -> void:
	_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_game.run.set_max_hp(99999.0)


func _pin(at: Vector3) -> void:
	_anchor = at
	_anchor.y = _game.ctx.terrain.height(at.x, at.z) + 1.05
	_game.player.reset_to(_anchor)
	_game.player.body().global_position = _anchor


func _caps() -> void:
	_enter(2)
	var ctx = _game.ctx
	var warden: Node3D = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(2))
	var cap: Vector3 = warden.cap_points()[0]
	_game.player.reset_to(cap + Vector3.UP * 1.3)
	_game.player.body().global_position = cap + Vector3.UP * 1.3
	var before: float = warden.hp
	var deflections: int = _combat.deflections
	var punch: float = _combat.punch_of("stomp", 10.0)
	_combat.strike(warden, "stomp", 10.0)
	var on_cap: float = before - warden.hp
	_report("cap_stomp", warden.lesson == "caps" and punch < warden.plating and is_equal_approx(on_cap, punch * Warden.CAP_MULT)
			and _combat.deflections == deflections,
		"stage 2 plating %.0f: a force-10 stomp (punch %.1f) on a vent cap dealt %.2f (1.5x, no deflection)" % [warden.plating, punch, on_cap])
	var off: Vector3 = warden.global_position + Vector3(STAND_OFF, 0.0, 0.0)
	_pin(off)
	before = warden.hp
	_combat.strike(warden, "stomp", 10.0)
	var off_cap: float = before - warden.hp
	_report("cap_miss", is_equal_approx(off_cap, punch * 0.2) and _combat.deflections == deflections + 1,
		"the same stomp away from the caps dealt %.2f (20%% chip) and was deflected" % off_cap)
	warden.queue_free()


func _miniboss() -> void:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(2) + Vector3(40.0, 0.0, 0.0)
	var boss: Node3D = ctx.spawner.spawn_enemy("miniboss", ctx.terrain.drop_point(at.x, at.z, 3.6))
	var want: float = 1.25 * StageDefs.of(2)["warden_plating"]
	_report("miniboss_plating", _combat.plating_of(boss) == want,
		"stage 2 event miniboss plating_of = %.1f (needs 1.25 x %.0f = %.0f)" % [_combat.plating_of(boss), StageDefs.of(2)["warden_plating"], want])
	boss.queue_free()


func _start_magnet() -> void:
	_enter(3)
	var ctx = _game.ctx
	_warden = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(3))
	_pin(_warden.global_position - ctx.terrain.entry_heading(3) * STAND_OFF)
	Engine.time_scale = WAIT_SCALE
	_phase = "await_tug"


# Rolls the ball away from the Warden at cruise, down the pull wedge (within 15 degrees
# of the magnet's line, downhill where the ground allows), with drive held away from it
# for the whole tug.
func _start_run_away() -> void:
	var ctx = _game.ctx
	var centre: Vector3 = _warden.global_position
	var line: Vector3 = _warden.magnet_dir()
	var best := line
	var lowest := INF
	for i in 7:
		var heading: Vector3 = line.rotated(Vector3.UP, deg_to_rad(-15.0 + 5.0 * i))
		var probe: Vector3 = centre + heading * 24.0
		var h: float = ctx.terrain.height(probe.x, probe.z)
		if h < lowest:
			lowest = h
			best = heading
	_away = best
	var start: Vector3 = centre + _away * 8.0
	start.y = ctx.terrain.height(start.x, start.z) + 1.05
	var cruise: float = ctx.tuning.f("cruise")
	_game.player.reset_to(start, _away * cruise)
	_game.player.body().global_position = start
	_game.camera.snap(_away, -0.2)
	_source.hold = {"move": Vector2(0.0, 1.0)}


func _aim_at(point: Vector3) -> void:
	var cam = _game.camera
	var d: Vector3 = (point - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)


func _finish() -> bool:
	Engine.time_scale = 1.0
	_source.hold = {}
	var ok := _failures == 0
	print("combat_warden_lessons_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
