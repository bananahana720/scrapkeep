extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Gorge := preload("res://src/world/map_gorge.gd")

# The gorge's callbacks (DESIGN-V2 section 13), each riding a mechanic that stands on
# its own:
#   Rivet, a mole, sprints through the cracked tunnel wall; Sable meets the same wall
#     as a wall. The shortcut opens only to the overdrive sprint.
#   Kest, a bird, rides a steam vent like a thermal while gliding; a glide beside the
#     vent does not climb.
#   C12: smashing the valve beside the dug-up reactor vent from outside its ring opens
#     the tunnel door and vents the reactor early.
# Each is discovered in play (a codex entry), never announced.
#
# Evidence limit: scripted lines in calm, except the thermal, which is a world push and
# so measured with calm off for its one second.

const SIM_SCALE := 2.0
const APPROACH := 14.0
const SPEED := 18.0

# 2026-10-04: the authored gorge route remains on a test double after the alpha repoint.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _source := Intent.Scripted.new()
var _phase := "boot"
var _clock := 0.0
var _heard: Array = []
var _found: Array = []
var _probe := {}


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _contraptions():
	return _game.world.contraptions[2]


func _run_as(index: int) -> void:
	_game.flow._begin_run(_game.flow.classes[index])
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	_source.hold = {}


func _put(xz: Vector2, velocity: Vector3, lift := 1.05) -> void:
	var at: Vector3 = _game.ctx.terrain.drop_point(xz.x, xz.y, lift)
	_game.player.reset_to(at, velocity)
	_game.player.body().global_position = at


func _wall_line() -> Array:
	var ends: Array = Gorge.TUNNELS["e1"]
	var dir: Vector2 = ((ends[1] as Vector2) - (ends[0] as Vector2)).normalized()
	var wall: Vector2 = (ends[0] as Vector2).lerp(ends[1], 0.16)
	return [wall, dir]


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = _source
			_game.events.world_fact.connect(func(kind: String, _at: Vector3): _heard.append(kind))
			_game.events.synergy_discovered.connect(func(id: String, _c: String, _f: bool): _found.append(id))
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "sable_wall"
			_clock = 0.0
		"sable_wall":
			if _clock < 0.05:
				_run_as(0)
				var line := _wall_line()
				var start: Vector2 = line[0] - line[1] * APPROACH
				_put(start, Vector3(line[1].x, 0.0, line[1].y) * SPEED)
				Engine.time_scale = SIM_SCALE
			elif _clock > 2.0:
				var wall: Dictionary = _contraptions().walls[0]
				_probe["sable"] = _game.player.planar_velocity().length()
				_report("the cracked wall holds against Sable", not wall["broken"] and _probe["sable"] < 4.0,
					"rolled at it at %.0f m/s without a sprint: broken %s, speed after %.1f m/s" % [SPEED, wall["broken"], _probe["sable"]])
				var body: StaticBody3D = wall["body"]
				var views := body.find_children("*", "MeshInstance3D", true, false)
				var box: Vector3 = (body.get_child(0).shape as BoxShape3D).size
				var bounds := AABB()
				for v: MeshInstance3D in views:
					var b: AABB = v.transform * v.mesh.get_aabb()
					bounds = b if bounds.size == Vector3.ZERO else bounds.merge(b)
				_report("the cracked wall wears the fracture panel on both faces", views.size() == 2
					and views.all(func(v): return not v.mesh is PrimitiveMesh) and bounds.size.is_equal_approx(box)
					and bounds.get_center().is_equal_approx(Vector3.ZERO), "%d views, bounds %s against collider %s" % [views.size(), bounds, box])
				_phase = "rivet_wall"
				_clock = 0.0
		"rivet_wall":
			if _clock < 0.05:
				_run_as(1)
				_heard.clear()
				var line := _wall_line()
				var start: Vector2 = line[0] - line[1] * APPROACH
				var dir := Vector3(line[1].x, 0.0, line[1].y)
				_put(start, dir * SPEED)
				_game.camera.yaw = atan2(-dir.x, -dir.z)
				_source.press = {"movement_pressed": true}
				_source.hold = {"movement_held": true, "move": Vector2(0.0, 1.0)}
			elif _clock > 1.6:
				var wall: Dictionary = _contraptions().walls[0]
				var planar: float = _game.player.planar_velocity().length()
				_report("Rivet sprints through the crack", wall["broken"] and planar >= SPEED * 0.85 and _found.has("sprint_through")
					and _heard.has("wall_crumbled"),
					"sprinting %s at it: broken %s, through at %.1f m/s, codex sprint_through %s, heard wall_crumbled %s"
						% [_game.player.kit.sprinting, wall["broken"], planar, _found.has("sprint_through"), _heard.has("wall_crumbled")])
				_source.hold = {}
				_phase = "thermal"
				_clock = 0.0
		"thermal":
			if _clock < 0.05:
				_run_as(2)
				var t: Dictionary = _contraptions().thermals[0]
				var base: Vector3 = t["base"]
				_put(Vector2(base.x, base.z), Vector3(0.0, -2.0, 0.0), 30.0)
				_source.press = {"jump_pressed": true}
				_source.hold = {"jump_held": true}
				_game.ctx.calm = false
				_probe["y0"] = _game.player.ball_position().y
			elif _clock > 1.2 and not _probe.has("in"):
				_probe["in"] = _game.player.ball_position().y - _probe["y0"]
				_probe["gliding"] = _game.player.kit.gliding
				var t: Dictionary = _contraptions().thermals[0]
				var base: Vector3 = t["base"]
				_put(Vector2(base.x + 22.0, base.z), Vector3(0.0, -2.0, 0.0), 30.0)
				_source.press = {"jump_pressed": true}
				_probe["y1"] = _game.player.ball_position().y
				_clock = 0.06
			elif _probe.has("in") and _clock > 1.26 + 1.14:
				_game.ctx.calm = true
				var beside: float = _game.player.ball_position().y - _probe["y1"]
				_report("Kest rides a steam vent like a thermal", _probe["gliding"] and _probe["in"] > beside + 3.0 and _found.has("steam_thermal")
					and _heard.has("thermal_ride"),
					"air jump then glide (gliding %s): over 1.2 s she moved %.1f m vertically in the vent and %.1f m beside it; codex steam_thermal %s"
						% [_probe["gliding"], _probe["in"], beside, _found.has("steam_thermal")])
				_source.hold = {}
				_phase = "valve"
				_clock = 0.0
		"valve":
			if _clock < 0.05:
				_run_as(0)
				_heard.clear()
				var v: Dictionary = _contraptions().valves[1]
				var at: Vector3 = v["at"]
				var vent: Vector2 = Gorge.REACTOR_VENT
				var away := (Vector2(at.x, at.z) - vent).normalized()
				var start := Vector2(at.x, at.z) + Vector2(-away.y, away.x) * APPROACH
				var dir := (Vector2(at.x, at.z) - start).normalized()
				_put(start, Vector3(dir.x, 0.0, dir.y) * SPEED)
			elif _clock > 1.8:
				var v: Dictionary = _contraptions().valves[1]
				var door: Node3D = v["door"]
				var sunk: float = (v["door_home"] as Vector3).y - door.position.y
				_report("the reactor valve opens from outside the ring (C12)", v["open"] and sunk > 5.0 and _found.has("do_not_open_until_clear")
					and _heard.has("reactor_vented") and _heard.has("valve_smashed"),
					"rammed the valve at %.0f m/s from outside the vent's %.0f m ring: open %s, door sunk %.1f m, codex %s, heard %s"
						% [SPEED, Gorge.REACTOR_RING, v["open"], sunk, _found.has("do_not_open_until_clear"),
							_heard.filter(func(k): return k in ["valve_smashed", "route_opened", "reactor_vented"])])
				Engine.time_scale = 1.0
				print("stage_callbacks_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				_game.free()
				quit(0 if _failures == 0 else 1)
				return true
	return false
