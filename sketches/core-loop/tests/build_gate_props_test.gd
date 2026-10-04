extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Regression for the Spillway kerb (map_spillway.gd build_props, CHUTES[2]): a reward
# gate opened at (-31.9, 15.2, 13.2) facing +X with a 2 x 2.4 x 16 m kerb box at x -34,
# z 9 to 25, sitting 2 m before the arch across its approach line. A player rolling
# straight at the arch hit the kerb: an unforeseen stop (momentum is sacred).
#
# reward_gates.gd's choose_placement/_candidate only checked terrain climb, never
# static props, so this test sweeps a ball-sized sphere (radius 1.0 m, the ball's own
# probe) along every gate's approach line and its 6 m run-out past the arch, and fails
# if either crosses a StaticBody3D other than the terrain's own "Ground" body. The
# check is independent of reward_gates.gd's own probe: it asks the physics world
# directly, the same ground truth the ball rolls on.

const PROBE_RADIUS := 1.0
const RUN_OUT := 6.0
const SEEDS := 20

var _game
var _failures := 0
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
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
	if _ticks < 12:
		return false
	_check_repro()
	_check_sweep()
	print("build_gate_props_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


# The active stage's own terrain body: the one StaticBody3D every gate placement must
# be allowed to stand on (terrain.gd _build_ground names it "Ground").
func _ground_rid(stage: int) -> RID:
	var holder: Node3D = _game.ctx.terrain.geometry_root(stage)
	if holder == null:
		return RID()
	var ground := holder.get_node_or_null("Ground")
	return ground.get_rid() if ground != null else RID()


# True when a ball-sized sphere swept from from_xz to to_xz (both raised to the
# ground's own height plus the probe radius) hits anything on the world layer other
# than the excluded ground body.
func _blocked(from_xz: Vector3, to_xz: Vector3, exclude: Array) -> bool:
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var terrain = _game.ctx.terrain
	var from := Vector3(from_xz.x, terrain.height(from_xz.x, from_xz.z) + PROBE_RADIUS, from_xz.z)
	var to := Vector3(to_xz.x, terrain.height(to_xz.x, to_xz.z) + PROBE_RADIUS, to_xz.z)
	var sphere := SphereShape3D.new()
	sphere.radius = PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.exclude = exclude
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	return space.cast_motion(query)[1] < 1.0


# Places the ball, opens the gates on the given stage, and appends a description of
# every blocked approach or run-out to bad.
func _open_and_check(label: String, stage: int, ball_xz: Vector3, heading: Vector3, bad: Array) -> void:
	var terrain = _game.ctx.terrain
	var build = _game.ctx.build
	terrain.use(stage)
	_game.run.stage = stage
	build.gates.close()
	var at: Vector3 = terrain.drop_point(ball_xz.x, ball_xz.z, 1.05)
	_game.player.reset_to(at, heading * 20.0)
	_game.player.body().global_position = at
	build._on_flow_changed("gates")
	var offers: Array = build.gates.offers
	if offers.is_empty():
		bad.append("%s: no gates opened" % label)
		return
	var exclude := [_ground_rid(stage)]
	for offer in offers:
		var gate_at: Vector3 = offer["at"]
		var facing: Vector3 = offer["facing"]
		if _blocked(at, gate_at, exclude):
			bad.append("%s: approach from %s to gate at %s is blocked" % [label, at, gate_at])
		var run_out: Vector3 = gate_at + facing * RUN_OUT
		if _blocked(gate_at, run_out, exclude):
			bad.append("%s: run-out past gate at %s is blocked" % [label, gate_at])
	build.gates.close()


# The traced repro: the ball on the -X side of the chute-2 kerb (x -34, z 9 to 25),
# heading +X straight at the arch that used to land beside it.
func _check_repro() -> void:
	var bad: Array = []
	_open_and_check("stage 1 chute-2 kerb repro", 1, Vector3(-44.0, 0.0, 13.0), Vector3(1.0, 0.0, 0.0), bad)
	_report("gate clears the chute-2 kerb", bad.is_empty(),
		"ball at x -44, z 13, heading +X, toward the kerb at x -34: %s" % [bad])


# 2026-10-04: 20 seeded approaches on the two alpha maps. Reach gates are fixed,
# so approach starts belong to their authored south bowl, not the retired gorge rectangle.
func _check_sweep() -> void:
	var bad: Array = []
	var rng := RandomNumberGenerator.new()
	for seed_value in SEEDS:
		rng.seed = 9000 + seed_value
		var stage: int = (seed_value % _game.ctx.stages.COUNT) + 1
		var map = _game.ctx.terrain.map_for(stage)
		var r: Rect2 = map.play_rect
		var x := rng.randf_range(r.position.x + 10.0, r.end.x - 10.0)
		var z := rng.randf_range(r.position.y + 10.0, r.end.y - 10.0)
		var angle := rng.randf_range(0.0, TAU)
		var heading := Vector3(cos(angle), 0.0, sin(angle))
		if not map.gate_slots.is_empty():
			# Approach each occupied slot from 8-24 m north in its clear corridor.
			var slot: Dictionary = map.gate_slots[0 if seed_value % 4 == 1 else 2]
			x = slot["at"].x + rng.randf_range(-3.0, 3.0)
			z = slot["at"].y - rng.randf_range(8.0, 24.0)
			heading = Vector3(0.0, 0.0, 1.0)
		_open_and_check("seed %d stage %d" % [seed_value, stage], stage, Vector3(x, 0.0, z), heading, bad)
	_report("20 seeded sweeps clear props", bad.is_empty(),
		"seeded ball positions and headings across both alpha maps: %s" % [bad])
