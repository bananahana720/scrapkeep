extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const FloodCycle := preload("res://src/world/flood_cycle.gd")
const Parts := preload("res://src/build/parts.gd")

# Integration I1: nothing from the stages reaches the Brindle arena (DESIGN-NOTES
# spine call 34). A real, non-calm run with the real combat, world and build modules
# breaks each Warden, takes a gate and launches, through stages 1 and 2 into stage 3.
# Stage 3 runs until its content is live: director spawns, a flood at full height,
# scrap and fabricators. Its launch enters the arena through flow, with the spine's
# boss double standing in for Brindle. For 5 s the arena must hold no stage enemy, no
# director spawn, no push on the ball, no stage scrap, fabricator or gate, and no
# collidable or visible stage map, while the weapon keeps firing. Then the player dies,
# flow's R path retries the arena, and the same holds again. T replaying stage 3 brings
# the stage back.

const WINDOW := 450
const STAGE_WAIT := 20
const LIVE_LIMIT := 90 * 40
const TICK_LIMIT := 90 * 90
const APPROACH := 16.0
const APPROACH_SPEED := 20.0
const DUNK_EVERY := 45
const DUNK_TICKS := 12
# E1-06 tap-spark / hold-arc cadence (PILOT-CADENCE.md section 3.2): pulse press, hold past
# the charge threshold, and release periodically across the 450-tick arena window.
const FIRE_CYCLE := 45
const FIRE_HOLD := 33
# Item effects that push the ball themselves (item_effects.gd _surge and the dash). The run takes
# a gate offer without one, so the no-push check reads the stages and not the player's own build:
# since the cobalt floor (#536) the first offer can be Slipstream, whose surge on a speed tier up
# is the build working as meant.
const BALL_MOVERS := ["speed", "dash"]


# Reads the push the ball has been handed this tick, after every other node's physics
# step has added to it and before the ball's body spends it.
class PushProbe:
	extends Node

	var player
	var armed := false
	var worst := 0.0
	var ticks := 0

	func _physics_process(_delta: float) -> void:
		if not armed:
			return
		ticks += 1
		worst = maxf(worst, (player.body().external_accel as Vector3).length())


# Preserve the legacy three-stage rule on a double using surviving maps.
# F6 2026-10-04: the Warden break arms its whole health before the strike, as only a shatter may.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _boss
var _probe := PushProbe.new()
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _started := false
var _done := false
var _phase := "stage"
var _wait := 0
var _offer := {}
var _cycle
var _live := {}
var _clears: Array[Dictionary] = []
var _window := {}
var _shots := 0
var _spawned := 0
var _scrap_events := 0
var _discoveries := 0


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)
	_probe.process_physics_priority = 1000
	root.add_child(_probe)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if not _started:
		if _game.flow == null:
			return false
		_start()
		return false
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_report("timeout", false, "stalled in flow state %s, test phase %s" % [_game.flow.state_name(), _phase])
		return _finish()
	_step()
	return false


func _start() -> void:
	_started = true
	var events = _game.events
	_boss = BossDouble.new()
	_game.add_child(_boss)
	_boss.setup(_game.ctx)
	_probe.player = _game.player
	events.stage_entered.connect(func(_stage: int, _retry: bool): _wait = 0)
	events.reward_offered.connect(_on_offered)
	events.stage_content_cleared.connect(_on_cleared)
	events.shot_fired.connect(func(_w: String, _f: Vector3, _t: Vector3): _shots += 1)
	events.enemy_spawned.connect(func(_e: Node3D, _k: String): _spawned += 1)
	events.scrap_collected.connect(func(_a: int, _at: Vector3, _t: int): _scrap_events += 1)
	events.synergy_discovered.connect(func(_id: String, _c: String, _f: bool): _discoveries += 1)
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(1000000.0)


func _world():
	return _game.get_node("World")


func _build():
	return _game.ctx.build


# Runs synchronously inside flow's publication, after combat's own handler (combat
# connected at setup) and before the boss module's enter_arena.
func _on_cleared(reason: String) -> void:
	_clears.append({
		"reason": reason,
		"enemy": get_nodes_in_group("enemy").size(),
		"enemy_shot": get_nodes_in_group("enemy_shot").size(),
		"telegraph": get_nodes_in_group("telegraph").size(),
	})


func _break_warden() -> void:
	var warden = _game.flow.warden
	if is_instance_valid(warden):
		# F6 2026-10-04: a posture Warden loses health only to what a shatter armed; arm it all.
		warden._armed = warden.max_hp
		_game.ctx.spawner.strike(warden, "arc", 1000000.0)


func _on_offered(offers: Array) -> void:
	if not _game.flow.in_stage() or offers.is_empty() or _phase == "gate":
		return
	_offer = offers[0]
	for offer in offers:
		var d: Resource = Parts.def(offer["part_id"])
		if d == null or not String(d.effect.get("do", "")) in BALL_MOVERS:
			_offer = offer
			break
	var facing: Vector3 = _offer["facing"]
	var start: Vector3 = _offer["at"] - facing * APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * APPROACH_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}
	_phase = "gate"


func _step() -> void:
	var flow = _game.flow
	match _phase:
		"stage":
			_wait += 1
			if _game.run.stage < 3 and _wait == STAGE_WAIT:
				_break_warden()
			elif _game.run.stage == 3 and _wait == 1:
				_cycle = _world().events.flood
				if _cycle != null:
					_cycle.phase = FloodCycle.HIGH
					_cycle.elapsed = 0.0
				_phase = "live"
				_wait = 0
		"gate":
			if flow.state_name() == "launch" or flow.state_name() == "stage":
				_source.hold = {}
				_phase = "flight" if _game.run.stage == 3 else "stage"
		"live":
			_wait += 1
			if _cycle != null and _cycle.phase != FloodCycle.HIGH:
				_cycle.phase = FloodCycle.HIGH
			if _live_content(false) or _wait >= LIVE_LIMIT:
				_live_content(true)
				_probe.worst = 0.0
				_probe.armed = true
				_phase = "dunk"
				_wait = 0
		"dunk":
			_wait += 1
			if _cycle != null:
				_cycle.phase = FloodCycle.HIGH
			_place_ball(_dunk_point(), Vector3.ZERO)
			if _wait >= DUNK_TICKS:
				_probe.armed = false
				_phase = "exit"
				_break_warden()
		"exit", "flight":
			if flow.state_name() == "boss":
				_open_window("entry")
		"window":
			_step_window()
		"retry":
			_wait += 1
			if _wait == 2:
				_leave_arena_debris()
			elif _wait == 4:
				_game.run.damage(1.0e9, "test")
				var dead: String = flow.state_name()
				flow.retry_stage()
				_window_entry_state = dead
				_open_window("retry")
		"replay":
			_wait += 1
			if _wait == 3:
				_check_replay()
				_finish()


var _window_entry_state := ""


# Stage 3 counts as live once the director has put its own enemies in (anything but the
# Warden and the vault), the flood is up and the scrap field and fabricators stand.
func _live_content(report: bool) -> bool:
	var director_enemies := 0
	for enemy in get_nodes_in_group("enemy"):
		if enemy.get("kind") in ["chaser", "lobber"]:
			director_enemies += 1
	var world = _world()
	var basin: Dictionary = world.terrain.map().basin
	var floor_y: float = world.terrain.height(basin["centre"].x, basin["centre"].y)
	var water: float = world.flood.surface_y() - floor_y
	var scrap: int = _build().scrap.count()
	var fabs: int = _build().fabricators.records().size()
	var live: bool = director_enemies >= 2 and water > 3.0 and scrap > 0 and fabs > 0 and is_instance_valid(_game.flow.warden)
	if report:
		_live = {"director": director_enemies, "water": water, "scrap": scrap, "fabs": fabs}
		_report("stage 3 live", live,
			"after %.1f s of stage 3: %d director enemies alive (%d enemies in all), flood %.1f m deep, %d scrap pickups, %d fabricators, Warden standing"
				% [_wait / 90.0, director_enemies, get_nodes_in_group("enemy").size(), water, scrap, fabs])
	return live


func _place_ball(at: Vector3, velocity: Vector3) -> void:
	_game.player.reset_to(at, velocity)
	_game.player.body().global_position = at


# A metre under the stage flood's full surface, in stage 3's basin. In the stage the
# probe must see the flood push the ball here, or its zero in the arena proves nothing.
func _dunk_point() -> Vector3:
	var world = _world()
	var basin: Dictionary = world.terrain.map().basin
	var c: Vector2 = basin["centre"]
	var floor_y: float = world.terrain.height(c.x, c.y)
	return Vector3(c.x, floor_y + 7.0 - 1.0, c.y)


func _open_window(which: String) -> void:
	if which == "entry":
		_report("stage push probe", _probe.worst > 0.0,
			"the ball dunked in stage 3's flooded basin was pushed at %.1f m/s^2, so the probe sees world pushes" % _probe.worst)
	_phase = "window"
	_wait = 0
	_window = {"which": which, "shots": _shots, "spawned": _spawned, "scrap": _scrap_events, "discoveries": _discoveries,
		"enemies_max": 0, "shots_max": 0, "maps_seen": 0, "maps_solid": 0, "ray_hits": 0,
		"entries": _boss.entries, "not_stage": 0}
	_probe.worst = 0.0
	_probe.ticks = 0
	_probe.armed = true
	_source.hold = {}
	_source.press = {}
	# The stage's flood clock, forced back to full height: if the world still ran it,
	# the dunks below would be pushed.
	if _cycle != null:
		_cycle.phase = FloodCycle.HIGH
		_cycle.elapsed = 0.0


func _step_window() -> void:
	_wait += 1
	var w := _window
	w["enemies_max"] = maxi(w["enemies_max"], get_nodes_in_group("enemy").size())
	w["shots_max"] = maxi(w["shots_max"], get_nodes_in_group("enemy_shot").size())
	if _game.flow.in_stage():
		w["not_stage"] += 1
	if _wait % DUNK_EVERY < DUNK_TICKS:
		_place_ball(_dunk_point(), Vector3(2.0, 0.0, 0.0))
	if _wait == 5 or _wait == WINDOW - 5:
		_check_maps(w)
	if _wait < WINDOW:
		var pulse: int = (_wait - 1) % FIRE_CYCLE
		if pulse == 0:
			_source.hold = {"fire_held": true}
			_source.press = {"fire_pressed": true}
		elif pulse == FIRE_HOLD:
			_source.hold = {}
			_source.press = {"fire_released": true}
		return
	_probe.armed = false
	var which: String = w["which"]
	var clear: Dictionary = _clears[-1] if not _clears.is_empty() else {}
	var world = _world()
	var build = _build()
	_report("%s cleared" % which, _clears.size() == (1 if which == "entry" else 2) and clear.get("reason", "") == ("arena" if which == "entry" else "arena_retry")
			and clear.get("enemy", -1) == 0 and clear.get("enemy_shot", -1) == 0 and clear.get("telegraph", -1) == 0,
		"stage_content_cleared(%s) #%d left %d enemy, %d enemy_shot and %d telegraph nodes before the boss entered%s"
			% [clear.get("reason", "?"), _clears.size(), clear.get("enemy", -1), clear.get("enemy_shot", -1), clear.get("telegraph", -1),
				"" if which == "entry" else " (death in %s, then R)" % _window_entry_state])
	_report("%s no stage enemies" % which, w["enemies_max"] == 0 and w["shots_max"] == 0 and w["not_stage"] == 0,
		"over 5 s in the arena at most %d enemies and %d enemy shots stood; in_stage() true on %d ticks"
			% [w["enemies_max"], w["shots_max"], w["not_stage"]])
	_report("%s no director spawn" % which, _spawned == w["spawned"] and world.director.arrivals.is_empty(),
		"%d enemy_spawned over 5 s in the arena; %d arrival rings pending" % [_spawned - w["spawned"], world.director.arrivals.size()])
	_report("%s no pushes" % which, _probe.ticks >= WINDOW - 2 and _probe.worst == 0.0,
		"largest push handed to the ball over %d arena ticks was %.3f m/s^2, with the ball held in the old flood basin %d ticks of every %d and the stage flood clock forced high"
			% [_probe.ticks, _probe.worst, DUNK_TICKS, DUNK_EVERY])
	var fab_nodes: int = build.fabricators.get_child_count()
	var scrap_nodes: int = build.scrap.get_child_count()
	var gate_nodes: int = build.gates.get_child_count()
	_report("%s no stage scrap or fabricators" % which,
		build.scrap.count() == 0 and scrap_nodes == 0 and build.fabricators.records().is_empty() and fab_nodes == 0
			and gate_nodes == 0 and not build.gates.is_open() and _scrap_events - w["scrap"] == _discoveries - w["discoveries"],
		"%d scrap pickups (%d nodes), %d fabricators (%d nodes), %d gate nodes, %d scrap_collected over 5 s against %d discovery bursts"
			% [build.scrap.count(), scrap_nodes, build.fabricators.records().size(), fab_nodes, gate_nodes, _scrap_events - w["scrap"],
				_discoveries - w["discoveries"]])
	_report("%s stage maps parked" % which, w["maps_seen"] == 0 and w["maps_solid"] == 0 and w["ray_hits"] == 0,
		"at 5 ticks and at 4.9 s: %d stage maps visible, %d stage colliders in the physics space, %d world-layer hits under the arena"
			% [w["maps_seen"], w["maps_solid"], w["ray_hits"]])
	_report("%s world idle" % which, not world.launch.flying() and not world.flood.visible and world.vault == null,
		"launch rail flying %s, flood plane shown %s, vault %s" % [world.launch.flying(), world.flood.visible, world.vault])
	_report("%s weapons fire" % which, _shots - w["shots"] >= 10 and _game.flow.state_name() == "boss" and _boss.entries == w["entries"],
		"%d shot_fired over 5 s with fire pulsed, flow in %s" % [_shots - w["shots"], _game.flow.state_name()])
	_source.hold = {}
	_source.press = {}
	if which == "entry":
		_phase = "retry"
	else:
		_game.run.damage(1.0e9, "test")
		_game.flow.replay_stage(3)
		_phase = "replay"
	_wait = 0


func _check_maps(w: Dictionary) -> void:
	var terrain = _world().terrain
	for i in 3:
		var holder: Node3D = terrain.geometry_root(i + 1)
		if holder.is_visible_in_tree():
			w["maps_seen"] += 1
		w["maps_solid"] += _in_space(holder)
	var under: Vector3 = terrain.beacon_point(3)
	var query := PhysicsRayQueryParameters3D.create(under + Vector3.UP * 60.0, under + Vector3.DOWN * 60.0, 1)
	# The double's own arena floor is the boss's geometry, not the stage's.
	if is_instance_valid(_boss.arena_floor):
		query.exclude = [_boss.arena_floor.get_rid()]
	var hit: Dictionary = _game.player.body().get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		w["ray_hits"] += 1


# How many collision objects under this node are in a physics space right now.
func _in_space(node: Node) -> int:
	var count := 0
	if node is PhysicsBody3D:
		count += 1 if PhysicsServer3D.body_get_space((node as CollisionObject3D).get_rid()).is_valid() else 0
	elif node is Area3D:
		count += 1 if PhysicsServer3D.area_get_space((node as CollisionObject3D).get_rid()).is_valid() else 0
	for child in node.get_children():
		count += _in_space(child)
	return count


# Arena leftovers a retry must also sweep: an enemy and a lobber the fight left standing.
func _leave_arena_debris() -> void:
	var at: Vector3 = _game.player.ball_position() + Vector3(20.0, 0.0, 0.0)
	_game.ctx.spawner.spawn_enemy("chaser", at)
	_game.ctx.spawner.spawn_enemy("lobber", at + Vector3(0.0, 0.0, 10.0))
	if _cycle != null:
		_cycle.phase = FloodCycle.HIGH


func _check_replay() -> void:
	var terrain = _world().terrain
	var holder: Node3D = terrain.geometry_root(3)
	var build = _build()
	_report("replay restores stage 3", _game.flow.in_stage() and holder.is_visible_in_tree() and _in_space(holder) > 0
			and build.scrap.count() > 0 and not build.fabricators.records().is_empty(),
		"T replay: flow in %s, stage 3 map shown %s with %d colliders in space, %d scrap pickups, %d fabricators"
			% [_game.flow.state_name(), holder.is_visible_in_tree(), _in_space(holder), build.scrap.count(), build.fabricators.records().size()])


func _finish() -> bool:
	_done = true
	print("int_arena_standdown_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
