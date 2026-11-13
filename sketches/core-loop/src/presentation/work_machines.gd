extends Node3D

# Looping workers (BACKLOG W1-93; DECISIONS machine lore, 22 Oct 2026): the works machines that kept
# doing their old jobs after the people left, set beside the lines a pilot rides so a park reads as a
# place that is still running. They are neither friend nor foe: no event, no damage, no target, no
# telegraph colour. Each kind is one GLB whose named nodes this module turns on a fixed work cycle;
# pose() is the cycle itself, pure, so a test samples it without a game.
#
# Solid (agreed with the collisions thread, PR 950): only a machine's fixed footings and housings
# carry a StaticBody3D on the world layer, so the ball bumps them like any wall. Moving parts never
# collide, and every row stands clear of the pilot lines (tests/work_machines_test.gd), so no line
# gains a wall and a fight never lands under a boom. Built on every preset: the bodies exist for bots
# and players alike.

const WORLD_LAYER := 1
const VIEW_END_M := 900.0
const STILL_BEYOND_M := 700.0
const SWAY_STEP_S := 1.0 / 60.0
const GRAVITY := 9.8
const SWAY_DAMP := 0.6
const SWAY_MAX := 0.25

# The conveyor's buckets ride a MultiMesh each way, built from the GLB's CupFull and CupEmpty.
const CONVEYOR := {
	"model": "res://assets/models/world_one/works_conveyor.glb",
	"scale": 1.6,
	"belt": {"from": Vector3(0.0, 3.0, 13.0), "to": Vector3(0.0, 16.0, -11.0), "spacing_m": 2.0, "ride_m": 0.35, "return_m": 1.35},
	"start": {"run_m": 0.0},
	"steps": [
		[16.0, {"run_m": 32.0}],
		[5.0, {}],
	],
	"solid": [
		{"size": Vector3(3.6, 1.4, 3.0), "at": Vector3(0.0, 0.7, 13.6)},
		{"size": Vector3(4.0, 14.5, 3.6), "at": Vector3(0.0, 7.25, -11.0)},
		{"size": Vector3(5.0, 2.0, 5.0), "at": Vector3(0.0, 1.0, -15.6)},
	],
}

# One row per kind: its model (drawn at "scale", 1 when absent), its work cycle and the boxes that stand solid, in the machine's frame
# (origin on the ground under its pivot, the working side towards -Z). A cycle is a list of steps,
# [seconds, {channel: target}]: each step eases its channels from where the last step left them to
# its targets (a channel it does not name holds), and the cycle starts where its last step ends, so
# it loops without a seam. Channels: slew_deg (a derrick's boom about its mast), drop_m (its hoist
# rope below the boom's tip), lift_m (a sluice's leaf above its sill; the handwheel turns with it),
# run_m (how far a conveyor's belt has run; its buckets repeat every spacing_m, so a cycle whose run
# is a whole number of spacings loops cleanly). A kind's "start" overrides where a channel starts.
const KINDS := {
	"derrick": {
		"model": "res://assets/models/world_one/works_derrick.glb",
		"reach_m": 24.3,
		"sway": 0.6,
		"steps": [
			[4.0, {"drop_m": 1.0}],
			[11.0, {"slew_deg": 55.0}],
			[4.0, {"drop_m": 9.0}],
			[3.0, {}],
			[4.0, {"drop_m": 1.0}],
			[11.0, {"slew_deg": -55.0}],
			[4.0, {"drop_m": 9.0}],
			[3.0, {}],
		],
		"solid": [
			{"size": Vector3(6.0, 1.0, 6.0), "at": Vector3(0.0, 0.5, 0.0)},
			{"size": Vector3(1.6, 23.0, 1.6), "at": Vector3(0.0, 12.5, 0.0)},
			{"size": Vector3(3.2, 1.6, 3.2), "at": Vector3(-10.61, 0.8, 10.61)},
			{"size": Vector3(3.2, 1.6, 3.2), "at": Vector3(10.61, 0.8, 10.61)},
			{"size": Vector3(5.0, 3.6, 4.0), "at": Vector3(0.0, 1.8, 7.5)},
		],
	},
	"sluice": {
		"model": "res://assets/models/world_one/works_sluice.glb",
		"scale": 1.35,
		"wheel_rad_per_m": 2.4,
		"steps": [
			[6.0, {"lift_m": 4.2}],
			[7.0, {}],
			[8.0, {"lift_m": 0.0}],
			[9.0, {}],
		],
		"solid": [
			{"size": Vector3(1.0, 3.4, 18.0), "at": Vector3(-4.5, 1.7, 0.0)},
			{"size": Vector3(1.0, 3.4, 18.0), "at": Vector3(4.5, 1.7, 0.0)},
			{"size": Vector3(2.2, 10.0, 3.0), "at": Vector3(-4.6, 5.0, 0.0)},
			{"size": Vector3(2.2, 10.0, 3.0), "at": Vector3(4.6, 5.0, 0.0)},
		],
	},
	"conveyor": CONVEYOR,
}

# The named nodes a kind's channels drive.
const NODES := ["Slew", "Hook", "Fall", "Load", "Gate", "Wheel", "BeltFull", "BeltEmpty"]

# Where each park's machines stand: kind, ground point, yaw (the working side's centre, Godot yaw)
# and a phase offset in seconds so two machines never move in step.
const ROWS := {
	"park_dam": [
		{"id": "dam_pour_derrick", "kind": "derrick", "at": Vector2(-120.0, 600.0), "yaw_deg": 90.0, "phase_s": 0.0},
		{"id": "wheelhouse_sluice", "kind": "sluice", "at": Vector2(20.0, -280.0), "yaw_deg": -90.0, "phase_s": 4.0},
		{"id": "rim_batch_conveyor", "kind": "conveyor", "at": Vector2(-200.0, -240.0), "yaw_deg": 45.0, "phase_s": 7.0},
	],
	"park_flume": [
		{"id": "weir_pond_derrick", "kind": "derrick", "at": Vector2(-520.0, -700.0), "yaw_deg": 90.0, "phase_s": 11.0},
		{"id": "rim_road_sluice", "kind": "sluice", "at": Vector2(-140.0, -80.0), "yaw_deg": 0.0, "phase_s": 17.0},
		{"id": "bench_batch_conveyor", "kind": "conveyor", "at": Vector2(-160.0, 380.0), "yaw_deg": -135.0, "phase_s": 3.0},
	],
}

var ctx
var map_id := ""
# Built machines: {row, kind, root, slew, hook, fall, load, t, sway, sway_v, last_slew, last_rate}.
var machines: Array = []
var _built_for := -1
static var _scenes := {}


static func rows_for(map: String) -> Array:
	return ROWS.get(map, [])


# A row's pivot and the ground corners of every solid box, in park metres (x, z).
static func footprint(row: Dictionary) -> PackedVector2Array:
	var kind: Dictionary = KINDS[row.kind]
	var basis := Basis(Vector3.UP, deg_to_rad(float(row.yaw_deg))).scaled(Vector3.ONE * float(kind.get("scale", 1.0)))
	var out := PackedVector2Array([row.at])
	for box in kind.solid:
		for cx in [-0.5, 0.5]:
			for cz in [-0.5, 0.5]:
				var c: Vector3 = basis * (box.at + Vector3(box.size.x * cx, 0.0, box.size.z * cz))
				out.append(row.at + Vector2(c.x, c.z))
	return out


# Where a derrick's boom tip passes over its whole slew, 21 points; empty for a kind with no boom.
static func reach(row: Dictionary) -> PackedVector2Array:
	var kind: Dictionary = KINDS[row.kind]
	var out := PackedVector2Array()
	if not kind.has("reach_m"):
		return out
	var lo := INF
	var hi := -INF
	for step in kind.steps:
		if step[1].has("slew_deg"):
			lo = minf(lo, step[1].slew_deg)
			hi = maxf(hi, step[1].slew_deg)
	for i in 21:
		var yaw := deg_to_rad(float(row.yaw_deg) + lerpf(lo, hi, i / 20.0))
		var tip: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, -float(kind.reach_m) * float(kind.get("scale", 1.0)))
		out.append(row.at + Vector2(tip.x, tip.z))
	return out


static func cycle_s(kind: String) -> float:
	var total := 0.0
	for step in KINDS[kind].steps:
		total += float(step[0])
	return total


# The channels at the end of a kind's cycle, which is also where it starts.
static func rest(kind: String) -> Dictionary:
	var at := {}
	for step in KINDS[kind].steps:
		at.merge(step[1], true)
	return at


# The work cycle at time t (seconds) for a kind: every channel's value. Pure and periodic.
static func pose(kind: String, t: float) -> Dictionary:
	var at := rest(kind)
	at.merge(KINDS[kind].get("start", {}), true)
	var s := fposmod(t, cycle_s(kind))
	for step in KINDS[kind].steps:
		var length: float = step[0]
		var targets: Dictionary = step[1]
		if s >= length:
			at.merge(targets, true)
			s -= length
			continue
		var k := _ease(s / length)
		for channel in targets:
			at[channel] = lerpf(float(at[channel]), float(targets[channel]), k)
		break
	return at


# Smootherstep: machinery takes up and lets off slack, it never snaps.
static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func setup(context) -> void:
	ctx = context
	name = "WorkMachines"
	ctx.events.stage_entered.connect(_stage_entered)
	ctx.events.stage_content_cleared.connect(_stage_cleared)
	if ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage(ctx.terrain.stage)


func _stage_entered(stage: int, _retry: bool) -> void:
	_build_stage(stage)


func _stage_cleared(_reason: String) -> void:
	_clear()


func _clear() -> void:
	for m in machines:
		if is_instance_valid(m.root):
			m.root.queue_free()
	machines.clear()
	_built_for = -1


func _build_stage(stage: int) -> void:
	if stage == _built_for and not machines.is_empty():
		return
	_clear()
	_built_for = stage
	map_id = String(ctx.stages.of(stage).map)
	var rows := rows_for(map_id)
	if rows.is_empty():
		return
	var ground: Callable = ctx.terrain.ground_callable(stage)
	for row in rows:
		var built := _build(row, ground)
		if not built.is_empty():
			machines.append(built)
	_tick(0.0)


func _build(row: Dictionary, ground: Callable) -> Dictionary:
	var kind: Dictionary = KINDS[row.kind]
	var scene := _scene(kind.model)
	if scene == null:
		return {}
	var root := scene.instantiate() as Node3D
	root.name = String(row.id)
	add_child(root)
	var yaw := deg_to_rad(float(row.yaw_deg))
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * float(kind.get("scale", 1.0)))
	# Seat on the lowest of the pivot and the footings, so nothing stands on air.
	var floor_y := INF
	for p in footprint(row):
		floor_y = minf(floor_y, ground.call(p.x, p.y, 0.0).y)
	root.transform = Transform3D(basis, Vector3(row.at.x, floor_y, row.at.y))
	_paint(root)
	var body := StaticBody3D.new()
	body.name = "Footings"
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(WORLD_LAYER, true)
	root.add_child(body)
	for box in kind.solid:
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = box.size
		shape.shape = cube
		shape.position = box.at
		body.add_child(shape)
	if kind.has("belt"):
		_belt(root, kind.belt)
	var nodes := {}
	for node_name in NODES:
		var node := root.find_child(node_name, true, false)
		if node != null:
			nodes[node_name] = node
	return {
		"row": row, "kind": String(row.kind), "root": root, "nodes": nodes, "posed": false,
		"t": float(row.get("phase_s", 0.0)), "sway": 0.0, "sway_v": 0.0, "last_slew": NAN, "last_rate": 0.0,
	}


# A conveyor's two runs of buckets: one MultiMesh per run from the GLB's CupFull and CupEmpty, which
# stay in the kit only as templates.
static func _belt(root: Node3D, belt: Dictionary) -> void:
	var count := int(Vector3(belt.to - belt.from).length() / float(belt.spacing_m))
	for pair in [["CupFull", "BeltFull"], ["CupEmpty", "BeltEmpty"]]:
		var cup := root.find_child(pair[0], true, false) as MeshInstance3D
		if cup == null:
			continue
		cup.visible = false
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = cup.mesh
		multi.instance_count = count
		var view := MultiMeshInstance3D.new()
		view.name = pair[1]
		view.multimesh = multi
		view.visibility_range_end = VIEW_END_M
		root.add_child(view)


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if _scenes[path] == null:
			push_warning("work_machines: %s missing; its machines stay unbuilt" % path)
	return _scenes[path]


# The kit is vertex coloured: each mesh, once per process, swaps its imported surfaces for one material
# that takes the paint from the vertices, and every view of it shares that mesh.
static var _painted := {}


static func _paint(root: Node) -> void:
	for view: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		view.visibility_range_end = VIEW_END_M
		var source := view.mesh
		if not _painted.has(source):
			var mesh := source.duplicate() as Mesh
			for s in mesh.get_surface_count():
				var mat := StandardMaterial3D.new()
				mat.vertex_color_use_as_albedo = true
				mat.roughness = 0.78
				mat.metallic = 0.15
				mesh.surface_set_material(s, mat)
			_painted[source] = mesh
		view.mesh = _painted[source]


func _process(delta: float) -> void:
	_tick(minf(delta, 0.1))


func _tick(delta: float) -> void:
	var eye: Variant = _eye()
	for m in machines:
		m.t += delta
		if eye != null and m.posed and eye.distance_to(m.root.global_position) > STILL_BEYOND_M:
			continue
		_apply(m, delta)
		m.posed = true


func _eye() -> Variant:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam != null else null


# Poses the nodes from the cycle.
func _apply(m: Dictionary, delta: float) -> void:
	var p := pose(m.kind, m.t)
	var nodes: Dictionary = m.nodes
	if p.has("lift_m"):
		var lift := float(p.lift_m)
		if nodes.has("Gate"):
			nodes.Gate.position.y = lift
		if nodes.has("Wheel"):
			nodes.Wheel.rotation.x = lift * float(KINDS[m.kind].wheel_rad_per_m)
	if p.has("slew_deg"):
		_derrick(m, p, delta)
	if p.has("run_m"):
		_conveyor(m, float(p.run_m))


# Each bucket sits spacing_m behind the next: up the carrying run loaded, back down under it empty.
func _conveyor(m: Dictionary, run: float) -> void:
	var placed := buckets(m.kind, run)
	for pair in [["BeltFull", "full"], ["BeltEmpty", "empty"]]:
		if not m.nodes.has(pair[0]):
			continue
		var multi: MultiMesh = m.nodes[pair[0]].multimesh
		var list: Array = placed[pair[1]]
		for i in mini(multi.instance_count, list.size()):
			multi.set_instance_transform(i, list[i])


# Where a conveyor's buckets are after its belt has run `run` metres, in the machine's frame: {full, empty},
# one Transform3D per bucket, each facing along the carrying run. Pure.
static func buckets(kind: String, run: float) -> Dictionary:
	var belt: Dictionary = KINDS[kind].belt
	var spacing: float = belt.spacing_m
	var along: Vector3 = belt.to - belt.from
	var length := along.length()
	var dir := along / length
	var up := -dir.cross(Vector3.RIGHT).normalized()
	var facing := Basis.looking_at(dir, up)
	var offset := fposmod(run, spacing)
	var full := []
	var empty := []
	for i in int(length / spacing):
		var d := fposmod(offset + i * spacing, length)
		full.append(Transform3D(facing, belt.from + dir * d + up * float(belt.ride_m)))
		empty.append(Transform3D(facing, belt.to - dir * d - up * float(belt.return_m)))
	return {"full": full, "empty": empty}


# A derrick slews its boom and hoists its bucket, and the hook swings on its rope as the boom's tip
# speeds up and slows down.
func _derrick(m: Dictionary, p: Dictionary, delta: float) -> void:
	var nodes: Dictionary = m.nodes
	var slew := deg_to_rad(float(p.slew_deg))
	if nodes.has("Slew"):
		nodes.Slew.rotation.y = slew
	var rope := 1.0 + float(p.get("drop_m", 0.0))
	if nodes.has("Fall"):
		nodes.Fall.scale = Vector3(1.0, rope, 1.0)
	if nodes.has("Load"):
		nodes.Load.position.y = -rope
	if delta > 0.0 and not is_nan(m.last_slew):
		var rate: float = (slew - m.last_slew) / delta
		var accel: float = (rate - m.last_rate) / delta
		m.last_rate = rate
		var reach: float = KINDS[m.kind].reach_m * KINDS[m.kind].sway
		var left := delta
		while left > 0.0:
			var dt := minf(left, SWAY_STEP_S)
			var a: float = -GRAVITY / (rope + 3.0) * sin(m.sway) - SWAY_DAMP * m.sway_v - accel * reach / (rope + 3.0)
			m.sway_v += a * dt
			m.sway = clampf(m.sway + m.sway_v * dt, -SWAY_MAX, SWAY_MAX)
			left -= dt
	m.last_slew = slew
	# The tip moves sideways (along the slew's tangent), so the rope leans about the boom's own axis.
	if nodes.has("Hook"):
		nodes.Hook.rotation.z = m.sway
