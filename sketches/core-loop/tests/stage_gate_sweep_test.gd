extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Gorge := preload("res://src/world/map_gorge.gd")

# DESIGN-NOTES #39 carried into the gorge: a reward gate never opens across a prop's
# approach. The Spillway sweep (build_gate_props_test) proved the kerbs; the gorge adds
# tall and moving things: the landmark towers, the cable tower, the hover barges, the
# steam lifts, the tunnel roofs and bridges, the valve doors, the cracked wall and, once
# the terrain events have fired, the cave-in seal and the impact crater.
#
# Three checks:
#   1. The probe sees every obstacle class: a ball-sized sphere swept straight through
#      each one is reported blocked (so a clear result below is not a blind probe).
#   2. Gates opened with the ball placed in front of each obstacle, heading at it, have
#      clear approaches and run-outs, by build's straight sweep and by a sweep that
#      follows the ground in 4 m steps (the ball rolls the ground, not the chord).
#   3. 24 seeded ball positions and headings on stage 2, and 8 more after both terrain
#      swaps, the same.
#
# Evidence limit: the barges and lifts are checked where they stand at the moment the
# gates open; a barge that later sails across a gate's line is a moving hazard the
# placement cannot foresee (logged in DESIGN-NOTES v2 W6).

const PROBE_RADIUS := 1.0
const RUN_OUT := 6.0
const STEP := 4.0
const SEEDS := 24
const SEEDS_AFTER := 8

# The gorge obstacle rule stays on the legacy map in the test double.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _ticks := 0
var _last_hit := ""


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _ticks == 4:
		_game.flow.enter_stage(2, Vector3.ZERO, false)
		return false
	if _ticks < 12:
		return false
	if _ticks == 12:
		_check_seen()
		_check_targeted()
		_check_seeded("seeded", SEEDS, 7200)
		# A moved body reaches the physics space at the scene tree's transform flush, so
		# the swapped colliders are asked about on a later tick, as the ball meets them.
		_game.world._swap("cave_in")
		_game.world._swap("impact")
		return false
	if _ticks < 15:
		return false
	_check_swaps_seen()
	_check_seeded("seeded after both swaps", SEEDS_AFTER, 7700)
	print("stage_gate_sweep_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _ground_rid() -> RID:
	var ground: Node = _game.ctx.terrain.geometry_root(2).get_node_or_null("Ground")
	return ground.get_rid() if ground != null else RID()


func _cast(from: Vector3, to: Vector3, exclude: Array) -> bool:
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.exclude = exclude
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	var hit: bool = space.cast_motion(query)[1] < 1.0
	_last_hit = ""
	if hit:
		query.transform = Transform3D(Basis.IDENTITY, from)
		var info := space.get_rest_info(query)
		if info.is_empty():
			var at: Array = space.cast_motion(query)
			query.transform = Transform3D(Basis.IDENTITY, from + (to - from) * at[1])
			query.motion = Vector3.ZERO
			info = space.get_rest_info(query)
		if not info.is_empty():
			var body = instance_from_id(info["collider_id"])
			_last_hit = String(body.name) if body != null else "?"
	return hit


func _raised(p: Vector3) -> Vector3:
	return Vector3(p.x, _game.ctx.terrain.height(p.x, p.z) + PROBE_RADIUS, p.z)


# Build's own chord, then the ground-following steps.
func _blocked(from_xz: Vector3, to_xz: Vector3, exclude: Array) -> String:
	if _cast(_raised(from_xz), _raised(to_xz), exclude):
		return "chord hit %s" % _last_hit
	var flat := Vector3(to_xz.x - from_xz.x, 0.0, to_xz.z - from_xz.z)
	var steps := maxi(1, ceili(flat.length() / STEP))
	for i in steps:
		var a := _raised(from_xz + flat * (float(i) / steps))
		var b := _raised(from_xz + flat * (float(i + 1) / steps))
		# A step that climbs is lifted to the higher end, so a slope is not read as a prop.
		var top := maxf(a.y, b.y) + 0.35
		if _cast(Vector3(a.x, top, a.z), Vector3(b.x, top, b.z), exclude):
			return "hit %s near %s" % [_last_hit, _v(a)]
	return ""


func _node(name: String) -> Node3D:
	for holder in [_game.ctx.terrain.geometry_root(2), _game.world.contraptions[2]]:
		var n := (holder as Node).find_child(name, true, false)
		if n != null:
			return n
	return null


func _through(label: String, centre: Vector3, along: Vector3, span: float, seen: Array, missed: Array) -> void:
	if _cast(centre - along * span, centre + along * span, [_ground_rid()]):
		seen.append(label)
	else:
		missed.append("%s at %s" % [label, _v(centre)])


func _check_seen() -> void:
	var seen := []
	var missed := []
	var foot: float = _game.ctx.terrain.height(Gorge.TOWER.x, Gorge.TOWER.z)
	_through("landmark tower", Vector3(Gorge.TOWER.x, foot + 20.0, Gorge.TOWER.z), Vector3.RIGHT, 16.0, seen, missed)
	var sat: Vector2 = Gorge.SATELLITES[2]["at"]
	_through("satellite tower", Vector3(sat.x, _game.ctx.terrain.height(sat.x, sat.y) + 10.0, sat.y), Vector3.RIGHT, 10.0, seen, missed)
	_through("cable tower", Vector3(48.0, _game.ctx.terrain.height(48.0, -108.0) + 6.0, -108.0), Vector3.RIGHT, 6.0, seen, missed)
	var zc: float = (Gorge.BRIDGES[0].x + Gorge.BRIDGES[0].y) * 0.5
	_through("bridge deck", Vector3(10.0, Gorge.flank(zc) - 0.7, zc), Vector3.BACK, 10.0, seen, missed)
	for name in ["TunnelRoof_w1", "TunnelRoof_w2", "TunnelRoof_e1", "TunnelRoof_e2"]:
		var roof := _node(name)
		if roof == null:
			missed.append("%s not found" % name)
		else:
			_through(name, roof.global_position + Vector3.UP * 3.0, Vector3.DOWN, 3.0, seen, missed)
	for name in ["barge_west", "barge_east", "lift_west", "cracked_wall", "vent_valve_door", "skylight_valve_door"]:
		var n := _node(name)
		if n == null:
			missed.append("%s not found" % name)
		else:
			_through(name, n.global_position, Vector3.RIGHT, 9.0, seen, missed)
	_report("the probe sees every gorge obstacle", missed.is_empty(),
		"a %.0f m sphere swept through each: seen %s; missed %s" % [PROBE_RADIUS, seen, missed])


func _check_swaps_seen() -> void:
	var seen := []
	var missed := []
	var seal := _node("CaveInSeal")
	if seal == null:
		missed.append("CaveInSeal not found")
	else:
		# The rubble is a mound the ball rolls onto, so the probe drops onto its crown.
		var crown := Vector3(seal.global_position.x, _game.ctx.terrain.height(seal.global_position.x, seal.global_position.z), seal.global_position.z)
		_through("cave-in rubble", crown + Vector3.UP * 2.0, Vector3.DOWN, 3.0, seen, missed)
	var rim := Vector3(Gorge.IMPACT.x + Gorge.CRATER_RIM, 0.0, Gorge.IMPACT.y)
	rim.y = _game.ctx.terrain.height(rim.x, rim.z)
	_through("impact crater rim", rim + Vector3.UP * 2.0, Vector3.DOWN, 3.0, seen, missed)
	_report("the probe sees the swapped-in terrain", missed.is_empty(),
		"after both swaps: seen %s; missed %s" % [seen, missed])


func _open_and_check(label: String, ball_xz: Vector3, heading: Vector3, bad: Array) -> int:
	var terrain = _game.ctx.terrain
	var build = _game.ctx.build
	build.gates.close()
	var at: Vector3 = terrain.drop_point(ball_xz.x, ball_xz.z, 1.05)
	_game.player.reset_to(at, heading * 20.0)
	_game.player.body().global_position = at
	build._on_flow_changed("gates")
	var offers: Array = build.gates.offers
	if offers.is_empty():
		bad.append("%s: no gates opened" % label)
		return 0
	var exclude := [_ground_rid()]
	for offer in offers:
		var gate_at: Vector3 = offer["at"]
		var facing: Vector3 = offer["facing"]
		var why := _blocked(at, gate_at, exclude)
		if why != "":
			bad.append("%s: approach from %s to gate at %s blocked (%s)" % [label, _v(at), _v(gate_at), why])
		why = _blocked(gate_at, gate_at + facing * RUN_OUT, exclude)
		if why != "":
			bad.append("%s: run-out past gate at %s blocked (%s)" % [label, _v(gate_at), why])
	build.gates.close()
	return offers.size()


# The ball 20 m short of each obstacle, rolling straight at it.
func _check_targeted() -> void:
	var bad := []
	var gates := 0
	var cases := [
		["landmark tower", Vector2(Gorge.TOWER.x + 30.0, Gorge.TOWER.z), Vector3.LEFT],
		["satellite tower", Vector2(-72.0 + 20.0, -16.0), Vector3.LEFT],
		["cable tower", Vector2(48.0, -108.0 + 20.0), Vector3.FORWARD],
		["west barge dock", Vector2(-12.0, -92.0 - 22.0), Vector3.BACK],
		["east barge dock", Vector2(30.0, -40.0 + 22.0), Vector3.FORWARD],
		["west tunnel mouth", Vector2(-42.7 + 22.0, 3.5), Vector3.LEFT],
		["east tunnel and cracked wall", Vector2(52.24 - 20.0, 0.8), Vector3.RIGHT],
		["bridges from the trough", Vector2(0.0, -12.0), Vector3.BACK],
		["steam lift", Vector2(-24.0, -56.0 - 20.0), Vector3.BACK],
		["impact site", Vector2(Gorge.IMPACT.x - 36.0, Gorge.IMPACT.y), Vector3.RIGHT],
	]
	for c in cases:
		gates += _open_and_check(c[0], Vector3(c[1].x, 0.0, c[1].y), c[2], bad)
	_report("gates clear the gorge's obstacles", bad.is_empty(),
		"%d cases, %d gates, ball 20 m short of each obstacle heading at it: %s" % [cases.size(), gates, bad])


func _check_seeded(label: String, count: int, base_seed: int) -> void:
	var bad := []
	var gates := 0
	var rng := RandomNumberGenerator.new()
	var r: Rect2 = _game.ctx.terrain.map_for(2).play_rect
	for i in count:
		rng.seed = base_seed + i
		var x := rng.randf_range(r.position.x + 10.0, r.end.x - 10.0)
		var z := rng.randf_range(r.position.y + 10.0, r.end.y - 10.0)
		var angle := rng.randf_range(0.0, TAU)
		gates += _open_and_check("seed %d" % i, Vector3(x, 0.0, z), Vector3(cos(angle), 0.0, sin(angle)), bad)
	_report("%d %s sweeps clear" % [count, label], bad.is_empty(),
		"%d gates opened across the gorge's play rect: %s" % [gates, bad])


static func _v(p: Vector3) -> String:
	return "(%.0f, %.1f, %.0f)" % [p.x, p.y, p.z]
