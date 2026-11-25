extends RefCounted

const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const DigFx := preload("res://src/presentation/dig_fx.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const ParkSites := preload("res://src/presentation/park_sites.gd")

# The Dig's scenery (alpha dress push, unit WDG): both zones' landmarks, cut faces, rubble,
# struts, carts, shells and lamp lines along the rim, the drum look on every breach cover, the
# stone beds as the ground material, and the Dig's light. Presentation only. Nothing here
# collides, no gameplay rectangle moves, and breach.gd and terrain.apply_swap stay the owners of
# the break. Every instance stands outside the play rect plus its 8 m apron, on the rim's foot.
# A missing GLB is skipped with a warning; a breach whose skin cannot be built keeps its box.

# The directories are static vars so a test can point them at nothing and see the fallback.
const STONE_DIR := "res://assets/models/dig_stone/"
const MECH_DIR := "res://assets/models/dig_mechanical/"
# The authored ore cart (tools/blender/ore_cart.py) lives with the other recipe GLBs.
const CART_DIR := "res://assets/models/"
static var stone_dir := STONE_DIR
static var mech_dir := MECH_DIR
static var cart_dir := CART_DIR


static func reset_for_tests() -> void:
	stone_dir = STONE_DIR
	mech_dir = MECH_DIR
	cart_dir = CART_DIR
# The resource paths come from the one material slot table (material_slots.gd).
const SLOTS := {
	"stone": MaterialSlots.SLOTS["stone"]["path"],
	"steel": MaterialSlots.SLOTS["steel"]["path"],
	"enamel": MaterialSlots.SLOTS["enamel"]["path"],
	"elastomer": MaterialSlots.SLOTS["elastomer"]["path"],
	"glass": MaterialSlots.SLOTS["glass"]["path"],
}
const MINT := Color("8bf0d3")
# Warm white, not amber: amber belongs to an offered landing or reward (SHEET.md).
const LAMP_LIGHT := Color.WHITE
const BURY := 0.25
const ASSEMBLY_LIFT := 0.03
# The rim begins to climb at 162 m (Features.rim); everything stands at or beyond 160.
const FACE_C := 166.0
const TOE_C := 161.0
# The north, south, east and west edges: outward normal and the yaw that turns a model's -Z
# (its front, and the lamp's open side) toward the arena. The tangent is the yawed +X.
const EDGES := [
	{"n": Vector2(0, 1), "yaw": 0.0},
	{"n": Vector2(0, -1), "yaw": PI},
	{"n": Vector2(1, 0), "yaw": PI * 0.5},
	{"n": Vector2(-1, 0), "yaw": -PI * 0.5},
]

var _dir_cache := {}
var _warnings := {}
var _fx: Node3D
var _cart_bodies: Array[Transform3D] = []


# Built on first entry, not at boot: building the Dig's terrain at game start changes
# physics body creation order and so every seeded run (Rivet seed 1: 38208 -> 34066 ticks).
static func hook(ctx) -> void:
	ctx.events.stage_entered.connect(_on_stage_entered.bind(ctx))
	# The context owns the terrain, a RefCounted, so a handler on its signal bound to the context would
	# hold the context from the terrain: a cycle that outlives the game and keeps this script's statics
	# with it (scrapkeep#494). The handler takes the context through a weak reference.
	ctx.terrain.stage_built.connect(_on_stage_built_weak.bind(weakref(ctx)))


static func _on_stage_built_weak(stage: int, ctx_ref: WeakRef) -> void:
	var ctx = ctx_ref.get_ref()
	if ctx != null:
		_on_stage_built(stage, ctx)


# A Dig park stage built ahead on worker threads takes its park pass a step a frame from when
# its ground is done (ParkBuild), parked out of sight, while the current stage is calm (flow.calm(),
# as world.gd's contraptions); entry finishes whatever is left. A bot run
# that builds stages whole, or a stage on show, keeps the entry build.
static func _on_stage_built(stage: int, ctx) -> void:
	if not ctx.terrain.built_threaded(stage):
		return
	for row in ctx.stages.DEFS:
		if row["stage"] != stage:
			continue
		var root: Node3D = ctx.terrain.geometry_root(stage)
		var map = ctx.terrain.map_for(stage)
		if not ParkSites.is_park(map) or int(row.get("world", 0)) != 2 or root.visible or root.get_node_or_null("DigScenery") != null:
			return
		var builder := new()
		var scenery: Node3D = builder._begin_park(root, map, ctx.terrain.ground_callable(stage), stage)
		var step := ParkBuild.new()
		step.name = "ParkBuild"
		step.builder = builder
		step.flow = ctx.flow
		scenery.add_child(step)
		return


# Steps a park pass begun ahead, one step a frame, and leaves when it is done.
class ParkBuild extends Node:
	var builder
	# Steps wait while this flow is not calm; without one (a test) they run every frame.
	var flow

	func _process(_delta: float) -> void:
		if flow != null and not flow.calm():
			return
		if not builder._park_step():
			finish()

	func finish() -> void:
		while builder._park_step():
			pass
		queue_free()
		set_process(false)


# A Dig park stage (park_pit, park_sinkhole) takes the park pass (build_park). A park stage's root
# is freed when it leaves memory, so its scenery is built again on the entry that rebuilds it.
static func _on_stage_entered(stage: int, _retry: bool, ctx) -> void:
	for row in ctx.stages.DEFS:
		if row["stage"] != stage:
			continue
		var map = ctx.terrain.map_for(stage)
		var park := ParkSites.is_park(map) and int(row.get("world", 0)) == 2
		if row["map"] in ["dig", "dig_deep"] or park:
			var root: Node3D = ctx.terrain.geometry_root(stage)
			var ahead := root.get_node_or_null("DigScenery/ParkBuild")
			if ahead != null and not ahead.is_queued_for_deletion():
				ahead.finish()
			if root.get_node_or_null("DigScenery") == null:
				if park:
					build_park(root, map, ctx.terrain.ground_callable(stage), stage)
				else:
					build(root, map, row["map"])
			var fx := root.get_node("DigScenery/DigFx")
			fx.bind_context(ctx, stage)
		return


static func build(stage_root: Node3D, map: RefCounted, map_id: String) -> Node3D:
	var scenery := Node3D.new()
	scenery.name = "DigScenery"
	stage_root.add_child(scenery)
	var builder := new()
	builder._build(scenery, stage_root, map, map_id)
	return scenery


func _build(scenery: Node3D, stage_root: Node3D, map: RefCounted, map_id: String) -> void:
	_fx = DigFx.new()
	_fx.name = "DigFx"
	scenery.add_child(_fx)
	_fx.prepare(stage_root, map)
	var ground := func(x: float, z: float) -> float: return float(map.sample(x, z)[0])
	var batches := {}
	_ground_beds(scenery, stage_root)
	_edges(batches, ground, map_id, map.scatter["mix"])
	_landmark(batches, ground, map_id)
	_flush(scenery, batches)
	_lamp_lines(batches, ground, map_id)
	_flush(scenery, batches)
	_breach_skins(stage_root, map)
	_fx.finish_build()


# The park pass: the same kit seated on the park's own rows (park_sites.gd). Cut faces, rubble,
# struts and shells stand at the foot of the pit's benches and along the tubes and adits; ore carts
# park beside the haul roads; lamp lines hang on the walls of the adits (straight rails) and the
# lava tubes (curved rails), where the world look's lamp pool lights them. A park's ground is its
# own bake, so the stone beds stay on the old maps, and a park has no breach plates to skin.
static func build_park(stage_root: Node3D, map, ground: Callable, stage: int) -> Node3D:
	var builder := new()
	var scenery := builder._begin_park(stage_root, map, ground, stage)
	while builder._park_step():
		pass
	return scenery


# The park pass as steps, so it can run whole (build_park) or a step a frame (ParkBuild): the
# rim a row a step, the carts, the first flush, the lamps a tube a step, the last flush. Steps
# run in the same order either way, so the seeded draws and the result are the same.
var _scenery: Node3D
var _sites: ParkSites
var _rng: RandomNumberGenerator
var _batches := {}
var _rim_rows: Array = []
var _faces := 0
var _toes := 0
var _tubes: Array = []
var _tube := 0
var _line := 0
var _phase := 0


func _begin_park(stage_root: Node3D, map, ground: Callable, stage: int) -> Node3D:
	_scenery = Node3D.new()
	_scenery.name = "DigScenery"
	stage_root.add_child(_scenery)
	_fx = DigFx.new()
	_fx.name = "DigFx"
	_scenery.add_child(_fx)
	_fx.prepare(stage_root, map)
	_sites = ParkSites.new(map, ground, stage)
	_rng = RandomNumberGenerator.new()
	_rng.seed = ("dig_scenery_" + String(map.park["map"])).hash()
	_rim_rows = _park_rim_rows(_sites, _rng)
	_tubes = _park_lamp_rows(_sites)
	return _scenery


# One step of the park pass; false once the pass is done.
func _park_step() -> bool:
	match _phase:
		0:
			if _rim_rows.is_empty():
				_phase = 1
			else:
				_park_rim_row(_batches, _sites, _rng, _rim_rows.pop_front())
		1:
			_park_carts(_batches, _sites, _rng)
			_phase = 2
		2:
			_flush(_scenery, _batches)
			_phase = 3
		3:
			if _tube >= _tubes.size() or _line >= PARK_LAMPS_MAX:
				_phase = 4
			else:
				_park_lamp_row(_batches, _sites, _tube)
				_tube += 1
		4:
			_flush(_scenery, _batches)
			_fx.finish_build()
			_phase = 5
	return _phase < 5


# Rows whose flanks wear the cut kit, and how many seats each row draws.
const PARK_RIM_ROWS := {"bank": ["open_pit", "tailings_bench"], "terrace": ["open_pit", "tailings_bench"],
	"tunnel": ["lava_tube", "adit"], "half_pipe": ["lava_tube"], "drop": ["shaft", "lava_tube"]}
const PARK_RIM_SEATS := 3
const PARK_FACES_MAX := 48
const PARK_TOE_MAX := 72


func _park_rim_rows(sites: ParkSites, rng: RandomNumberGenerator) -> Array:
	var rows := []
	for element in PARK_RIM_ROWS:
		rows.append_array(sites.rows([element], PARK_RIM_ROWS[element]))
	_shuffle(rows, rng)
	return rows


const PARK_RIM_KINDS := {"long": "cut_face_long.glb", "scoop": "cut_face_scoop.glb"}
const PARK_RIM_HALVES := {"long": 4.0, "scoop": 3.0}


func _park_rim_row(batches: Dictionary, sites: ParkSites, rng: RandomNumberGenerator, row: Dictionary) -> void:
	for seat in sites.flank(row, PARK_RIM_SEATS, rng.randf_range(2.0, 6.0), rng):
		var at: Vector2 = seat["at"]
		var yaw := ParkSites.yaw_toward(seat["inward"])
		var roll := rng.randf()
		if roll < 0.4 and _faces < PARK_FACES_MAX:
			var kind := "long" if rng.randf() < 0.5 else "scoop"
			var s := rng.randf_range(1.7, 2.5)
			var foot := _park_seat(sites, at, seat["inward"], PARK_RIM_HALVES[kind] * s)
			if foot.y <= 3.0:
				var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(at.x, foot.x - BURY * s, at.y))
				if _put(batches, _stone(PARK_RIM_KINDS[kind]), xf):
					_fx.faces.append(xf * Vector3(0, 3.0, -0.7))
					_faces += 1
			continue
		if _toes >= PARK_TOE_MAX:
			continue
		var path := _stone("rubble_cluster.glb")
		var s := rng.randf_range(2.2, 3.4)
		var bury := 0.1
		var any_yaw := true
		if roll < 0.7:
			path = _mech("strut_tall.glb" if rng.randf() < 0.55 else "strut_bent.glb")
			s = rng.randf_range(2.0, 3.0)
			any_yaw = false
		elif roll < 0.85:
			path = _mech("shell_crescent.glb" if rng.randf() < 0.5 else "shell_saddle.glb")
			s = rng.randf_range(2.2, 3.2)
			bury = 0.05
		var foot := _park_seat(sites, at, seat["inward"], 1.5 * s)
		if foot.y > 2.5:
			continue
		var turn := yaw + (rng.randf_range(0.0, TAU) if any_yaw else rng.randf_range(-0.25, 0.25))
		_put(batches, path, Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * s), Vector3(at.x, foot.x - bury * s, at.y)))
		_toes += 1


# The haul roads: an ore cart parked beside a pit ramp or a tailings bench, now and then.
const PARK_CARTS_MAX := 10


func _park_carts(batches: Dictionary, sites: ParkSites, rng: RandomNumberGenerator) -> void:
	var rows := sites.rows(["flow_line", "bank"], ["open_pit", "tailings_bench", "adit"])
	_shuffle(rows, rng)
	var carts := 0
	for row in rows:
		if carts >= PARK_CARTS_MAX:
			return
		for seat in sites.flank(row, 1, rng.randf_range(2.0, 4.0), rng):
			var at: Vector2 = seat["at"]
			var s := 2.2
			var foot := _park_seat(sites, at, seat["inward"], 1.6 * s)
			if foot.y > 1.5:
				continue
			var yaw := ParkSites.yaw_toward(seat["inward"]) + PI * 0.5 + rng.randf_range(-0.2, 0.2)
			var body := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(at.x, foot.x, at.y))
			var body_path := cart_dir + "ore_cart_body.glb"
			if not _put(batches, body_path, body):
				return
			for socket: Transform3D in _sockets(body_path, "socket_wheel_"):
				_put(batches, cart_dir + "ore_cart_wheel.glb", body * socket)
			_cart_bodies.append(body)
			carts += 1


# A lamp line on each tube, adit or haul-ramp wall: from the row's centre line, walk out until the
# ground stands LAMP_WALL_M over the floor, and hang the rail there facing the floor. Every other tube
# section takes one, so the lamps pace the run instead of lining it.
const LAMP_WALL_M := 3.0
const PARK_LAMPS_MAX := 32


static func _park_lamp_rows(sites: ParkSites) -> Array:
	return sites.rows(["tunnel", "half_pipe"], ["lava_tube", "adit", "flooded_shaft"]) + sites.rows(["flow_line"], ["open_pit"])


# Tube k's lamp line, if it takes one; _line counts the lines hung so far.
func _park_lamp_row(batches: Dictionary, sites: ParkSites, k: int) -> void:
	var row: Dictionary = _tubes[k]
	var curved := String(row["landform"]) == "lava_tube"
	if curved and k % 2 == 1:
		return
	var f := ParkSites.frame(row)
	var centre: Vector2 = f["at"]
	var floor_y := sites.height(centre)
	var side := 1.0 if _line % 2 == 0 else -1.0
	var c := 0.5
	var reach := float(f["half_width"]) + 8.0
	while c < reach and sites.height(centre + f["cross"] * side * c) < floor_y + LAMP_WALL_M:
		c += 0.5
	if c >= reach:
		return
	var p: Vector2 = centre + f["cross"] * side * (c - 0.4)
	var xf := Transform3D(Basis(Vector3.UP, ParkSites.yaw_toward(-f["cross"] * side)), Vector3(p.x, floor_y + LAMP_WALL_M, p.y))
	for m in (2 if curved else 3):
		var file := "lamp_curve_module.glb" if curved else "lamp_straight_module.glb"
		if not _put(batches, _mech(file), xf, _line * 0.73, m == 1):
			break
		xf = xf * Transform3D(Basis.IDENTITY, Vector3(3.0, 0, -0.35) if curved else Vector3(2.667, 0, 0))
	_line += 1


# The lowest ground across a piece's width at a seat, and the spread: (low, high - low).
static func _park_seat(sites: ParkSites, at: Vector2, inward: Vector2, half: float) -> Vector2:
	var along := Vector2(-inward.y, inward.x)
	var low := INF
	var high := -INF
	for k in [-1.0, 0.0, 1.0]:
		var h: float = sites.height(at + along * k * half)
		low = minf(low, h)
		high = maxf(high, h)
	return Vector2(low, high - low)


# The ground's beds: the Dig's own stone material over the terrain mesh. The preset system
# rewrites a ground view's material on every preset change, so a dressing host puts it back.
# The target preset keeps its own ground shader on every map, so the beds stand in high and low.
class GroundBeds extends Node:
	var view: MeshInstance3D
	var material: Material

	func _sync_dressing() -> void:
		# The beds stand in every preset: the shipped high and its target alias keep a prebuilt slot
		# resource (GraphicsPreset._apply_material), and low gets the beds put back here.
		if view != null and material != null:
			view.material_override = material


func _ground_beds(scenery: Node3D, stage_root: Node3D) -> void:
	var material := _slot_material("stone")
	var body := stage_root.get_node_or_null("Ground")
	if material == null or body == null:
		push_warning("dig_scenery: stone material or ground missing, the Dig keeps the default ground")
		return
	var views := body.find_children("*", "MeshInstance3D", true, false)
	if views.is_empty():
		return
	var host := GroundBeds.new()
	host.name = "GroundBeds"
	host.view = views[0]
	host.material = material
	scenery.add_child(host)
	GraphicsPreset.register_dressing_host(host)


func _slot_material(slot: String) -> Material:
	if not SLOTS.has(slot):
		_warn_once("slot_" + slot, "material slot missing or unknown, that piece keeps the fallback")
		return null
	if _dir_cache.has(slot):
		return _dir_cache[slot]
	var path: String = SLOTS[slot]
	var usable := ResourceLoader.exists(path)
	if usable:
		for dependency in ResourceLoader.get_dependencies(path):
			var resource_path: String = dependency.get_slice("::", 2) if dependency.contains("::") else dependency
			if resource_path.begins_with("res://") and not ResourceLoader.exists(resource_path):
				usable = false
	var material := load(path) as Material if usable else null
	if material is ShaderMaterial and material.shader == null:
		material = null
	if material == null:
		_warn_once(path, "%s missing or malformed, that material keeps the fallback" % path)
	_dir_cache[slot] = material
	return material


# A GLB's socket nodes whose names start with the prefix, each as its transform in the GLB's space.
func _sockets(path: String, prefix: String) -> Array:
	var key := path + "#" + prefix
	if _dir_cache.has(key):
		return _dir_cache[key]
	var out := []
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var scene := packed.instantiate()
			for socket: Node3D in scene.find_children(prefix + "*", "Node3D", true, false):
				out.append(_relative(socket, scene))
			scene.free()
	_dir_cache[key] = out
	return out


# One entry per mesh in a GLB: {name, mesh, local, slot, material}; empty when the GLB is
# absent or has no mesh, which every caller reads as "skip this piece".
func _parts(path: String) -> Array:
	if _dir_cache.has(path):
		return _dir_cache[path]
	var parts := []
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var scene := packed.instantiate()
			for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
				if view.mesh == null or view.mesh.get_surface_count() == 0:
					continue
				var slot := ""
				var source := view.mesh.surface_get_material(0)
				if source != null:
					slot = String(source.resource_name)
				parts.append({"name": String(view.name), "mesh": view.mesh,
					"local": _relative(view, scene), "slot": slot, "material": _slot_material(slot)})
			scene.free()
	if parts.is_empty():
		push_warning("dig_scenery: %s missing or empty, that piece stays out" % path)
	_dir_cache[path] = parts
	return parts


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


func _stone(file: String) -> String:
	return stone_dir + file


func _mech(file: String) -> String:
	return mech_dir + file


# Queue one placed instance of every mesh in the GLB.
func _put(batches: Dictionary, path: String, xf: Transform3D, lamp_phase: float = -1.0, flicker: bool = false) -> bool:
	var parts := _parts(path)
	for part in parts:
		var key: String = path + "#" + part["name"]
		if not batches.has(key):
			batches[key] = {"name": path.get_file().get_basename() + "_" + part["name"],
				"mesh": part["mesh"], "material": part["material"], "xf": []}
			if lamp_phase >= 0.0 and _fx.available:
				batches[key]["material"] = _fx.lamp_material(part["slot"], part["material"])
				batches[key]["custom"] = []
		batches[key]["xf"].append(xf * part["local"])
		if batches[key].has("custom"):
			batches[key]["custom"].append(Color(1.0 if flicker else 0.0, lamp_phase, 0.0, 1.0))
	return not parts.is_empty()


func _flush(scenery: Node3D, batches: Dictionary) -> void:
	for key in batches:
		var batch: Dictionary = batches[key]
		var count: int = batch["xf"].size()
		if count == 0:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = batch.has("custom")
		multi.mesh = batch["mesh"]
		multi.instance_count = count
		var origins := PackedVector3Array()
		for i in count:
			multi.set_instance_transform(i, batch["xf"][i])
			if batch.has("custom"):
				multi.set_instance_custom_data(i, batch["custom"][i])
			origins.append((batch["xf"][i] as Transform3D).origin)
		var view := MultiMeshInstance3D.new()
		view.name = batch["name"]
		view.multimesh = multi
		# A headless renderer keeps no instance buffer, so tests read the placements from here.
		view.set_meta("origins", origins)
		view.material_override = batch["material"]
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scenery.add_child(view)
		GraphicsPreset.register_scenery(view)
		if batch.has("custom"):
			_fx.lamp_views.append(view)
		batch["xf"] = []
	batches.clear()
	# One shell node per cart per layer, so Godot measures each fade from its own cart.
	for body in _cart_bodies:
		for shell in RecipeProps.shells("ore_cart", scenery, body):
			GraphicsPreset.register_scenery(shell)
	_cart_bodies.clear()


# A point on an edge band: c metres out along the normal, a along the tangent.
static func _at(edge: Dictionary, c: float, a: float) -> Vector2:
	var n: Vector2 = edge["n"]
	var yaw: float = edge["yaw"]
	var t := Vector2(cos(yaw), -sin(yaw))
	return n * c + t * a


static func _tangent(edge: Dictionary) -> Vector2:
	var yaw: float = edge["yaw"]
	return Vector2(cos(yaw), -sin(yaw))


# The lowest ground under a piece's run, so the foot is buried and never floats.
static func _seat(ground: Callable, edge: Dictionary, c: float, a: float, half: float) -> Vector2:
	var low := INF
	var high := -INF
	for k in [-1.0, 0.0, 1.0]:
		var p := _at(edge, c, a + k * half)
		var h: float = ground.call(p.x, p.y)
		low = minf(low, h)
		high = maxf(high, h)
	return Vector2(low, high - low)


func _edges(batches: Dictionary, ground: Callable, map_id: String, mix: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("dig_scenery_" + map_id).hash()
	var kinds := {"long": "cut_face_long.glb", "scoop": "cut_face_scoop.glb"}
	var halves := {"long": 4.0, "scoop": 3.0}
	for edge in EDGES:
		var yaw: float = edge["yaw"]
		var faces := []
		for kind in ["long", "scoop"]:
			for i in int(mix[kind]):
				faces.append(kind)
		_shuffle(faces, rng)
		# Cut faces: a loose chain along the rim's foot, scale varied, gaps left between runs.
		var a := -138.0 + rng.randf_range(0.0, 6.0)
		for kind in faces:
			var s := rng.randf_range(1.7, 2.5)
			var half: float = halves[kind] * s
			a += half
			if a + half > 140.0:
				break
			var c := FACE_C + rng.randf_range(-1.5, 1.5)
			var seat := _seat(ground, edge, c, a, half)
			if seat.y <= 3.0:
				var p := _at(edge, c, a)
				var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x, seat.x - BURY * s, p.y))
				if _put(batches, _stone(kinds[kind]), xf):
					_fx.faces.append(xf * Vector3(0, 3.0, -0.7))
			a += half + rng.randf_range(2.0, 14.0)
		for i in int(mix["rubble"]):
			_toe(batches, ground, edge, rng, _stone("rubble_cluster.glb"), rng.randf_range(2.2, 3.4), 0.1, true)
		for i in int(mix["strut"]):
			var file := "strut_tall.glb" if rng.randf() < 0.55 else "strut_bent.glb"
			_toe(batches, ground, edge, rng, _mech(file), rng.randf_range(2.0, 3.0), 0.1, false)
		for i in int(mix["shell"]):
			var file := "shell_crescent.glb" if rng.randf() < 0.5 else "shell_saddle.glb"
			_toe(batches, ground, edge, rng, _mech(file), rng.randf_range(2.2, 3.2), 0.05, true)
		for i in int(mix["cart"]):
			_cart(batches, ground, edge, rng)


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap


# One prop at the rim's toe. A strut keeps its back (+Z, the wall side) to the rim.
func _toe(batches: Dictionary, ground: Callable, edge: Dictionary, rng: RandomNumberGenerator,
		path: String, s: float, bury: float, any_yaw: bool) -> void:
	var a := rng.randf_range(-138.0, 138.0)
	var c := TOE_C + rng.randf_range(0.0, 3.5)
	var seat := _seat(ground, edge, c, a, 1.5 * s)
	if seat.y > 2.5:
		return
	var p := _at(edge, c, a)
	var yaw: float = float(edge["yaw"]) + (rng.randf_range(0.0, TAU) if any_yaw else rng.randf_range(-0.25, 0.25))
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x, seat.x - bury * s, p.y))
	_put(batches, path, xf)


# A parked haul cart with its four tyres at the body's wheel sockets.
func _cart(batches: Dictionary, ground: Callable, edge: Dictionary, rng: RandomNumberGenerator) -> void:
	var a := rng.randf_range(-130.0, 130.0)
	var c := TOE_C + rng.randf_range(0.0, 2.0)
	var s := 2.2
	var seat := _seat(ground, edge, c, a, 1.6 * s)
	if seat.y > 1.5:
		return
	var p := _at(edge, c, a)
	var yaw: float = float(edge["yaw"]) + PI * 0.5 + rng.randf_range(-0.2, 0.2)
	var body := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x, seat.x, p.y))
	var body_path := cart_dir + "ore_cart_body.glb"
	if not _put(batches, body_path, body):
		return
	for socket: Transform3D in _sockets(body_path, "socket_wheel_"):
		_put(batches, cart_dir + "ore_cart_wheel.glb", body * socket)
	_cart_bodies.append(body)


# Zone A: the broken Daylight Cut pump impeller, upright in the south wall, face toward -Z, 30
# percent of its lower arc buried. Zone B: the Hollow Cistern intake bell on its spine, at the
# south edge. Both are background scenery with no collider (P-R6).
func _landmark(batches: Dictionary, ground: Callable, map_id: String) -> void:
	if map_id == "dig":
		var at := Vector2(-45.0, 178.0)
		var base := Vector3(at.x, float(ground.call(at.x, at.y)) - 0.3 * 24.0, at.y)
		_impeller(batches, Transform3D(Basis.IDENTITY, base))
	else:
		var at := Vector2(45.0, 176.0)
		var base := Vector3(at.x, float(ground.call(at.x, at.y)) - 0.5, at.y)
		_intake(batches, Transform3D(Basis.IDENTITY, base))


func _impeller(batches: Dictionary, root: Transform3D) -> void:
	var axle := root * Transform3D(Basis.IDENTITY, Vector3(0, 12, 0))
	for k in 8:
		_put(batches, _mech("impeller_rim_sector.glb"), axle * Transform3D(Basis(Vector3.BACK, k * PI / 4.0), Vector3.ZERO))
	var hub := axle * Transform3D(Basis.IDENTITY, Vector3(0.8, 0, 0))
	_put(batches, _mech("impeller_hub.glb"), hub)
	# Five unequal blunt vanes on the hub's sockets, four whole and one chipped.
	for i in 5:
		var angle := -i * TAU / 5.0
		var socket := Vector3(2.5 * sin(-angle), 2.5 * cos(-angle), 0.0)
		var file := "impeller_vane_chipped.glb" if i == 4 else "impeller_vane.glb"
		_put(batches, _mech(file), hub * Transform3D(Basis(Vector3.BACK, angle), socket))


func _intake(batches: Dictionary, root: Transform3D) -> void:
	for k in 4:
		_put(batches, _mech("intake_spine_segment.glb"), root * Transform3D(Basis.IDENTITY, Vector3(0, k * 6.0, 0)))
	_put(batches, _mech("intake_throat.glb"), root * Transform3D(Basis.IDENTITY, Vector3(0, 19.0, 0)))
	for k in 3:
		_put(batches, _mech("intake_petal.glb"), root * Transform3D(Basis(Vector3.UP, k * TAU / 3.0), Vector3(0, 10, 0)))


# Straight and curved rails on the rim wall, hung well above any shelf. Lens and rail are two
# meshes of one GLB; the GLB's own sockets chain the modules. Their lenses stay white and unpooled.
func _lamp_lines(batches: Dictionary, ground: Callable, map_id: String) -> void:
	var curved := map_id == "dig_deep"
	var line := 0
	for edge in EDGES:
		var yaw: float = edge["yaw"]
		for a in [-90.0, 40.0]:
			var wall_y: float = float(ground.call(_at(edge, FACE_C, a).x, _at(edge, FACE_C, a).y)) + 12.0
			var c := FACE_C
			while c < 198.0 and _height_at(ground, edge, c, a) < wall_y:
				c += 0.5
			if c >= 198.0:
				continue
			var p := _at(edge, c - 0.4, a)
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, wall_y, p.y))
			var modules := 2 if curved else 3
			for m in modules:
				var file := "lamp_curve_module.glb" if curved else "lamp_straight_module.glb"
				if not _put(batches, _mech(file), xf, line * 0.73, m == 1):
					break
				xf = xf * Transform3D(Basis.IDENTITY, Vector3(3.0, 0, -0.35) if curved else Vector3(2.667, 0, 0))
			line += 1


static func _height_at(ground: Callable, edge: Dictionary, c: float, a: float) -> float:
	var p := _at(edge, c, a)
	return ground.call(p.x, p.y)


# The drum look on each breach cover: rim, three membrane wedges and four mint tabs from
# the manifest's assembly for the cover's rectangle, a visual child of the existing cover body.
# The cover's box mesh hides once the skin stands; its collider, its meta and its position are
# untouched, so breach.gd's break and terrain.apply_swap park the skin with it.
func _breach_skins(stage_root: Node3D, map: RefCounted) -> void:
	var manifest = null
	if FileAccess.file_exists(_mech("manifest.json")):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(_mech("manifest.json")))
	for plate in map.breach_plates:
		var cover := stage_root.find_child("BreachPlate_%s" % plate["id"], true, false) as StaticBody3D
		if cover == null:
			continue
		var rect: Rect2 = plate["rect"]
		_skin(cover, rect, manifest)


func _skin(cover: StaticBody3D, rect: Rect2, manifest) -> void:
	if not manifest is Dictionary:
		_warn_once("manifest", "dig_mechanical manifest missing, breach covers keep their boxes")
		return
	var key := "breach_assembly_%dx%d" % [int(rect.size.x), int(rect.size.y)]
	if not manifest.get("assemblies", {}).has(key):
		_warn_once(key, "no breach assembly for %s" % key)
		return
	var skin := Node3D.new()
	skin.name = "BreachSkin"
	var box_top := 0.0
	for child in cover.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			box_top = child.shape.size.y * 0.5
	skin.position = Vector3(0, box_top + ASSEMBLY_LIFT, 0)
	for item: Dictionary in manifest["assemblies"][key]["instances"]:
		var parts := _parts(_mech(item["file"]))
		if parts.is_empty() or parts.any(func(part): return part["material"] == null):
			skin.free()
			return
		var rot: Array = item["rotation_degrees"]
		var scale_a: Array = item["scale"]
		var pos: Array = item["position"]
		var basis := Basis.from_euler(Vector3(deg_to_rad(rot[0]), deg_to_rad(rot[1]), deg_to_rad(rot[2])), EULER_ORDER_YXZ)
		basis = basis * Basis.from_scale(Vector3(scale_a[0], scale_a[1], scale_a[2]))
		var xf := Transform3D(basis, Vector3(pos[0], pos[1], pos[2]))
		if item.has("assembly_scale"):
			var whole: Array = item["assembly_scale"]
			xf = Transform3D(Basis.from_scale(Vector3(whole[0], whole[1], whole[2])), Vector3.ZERO) * xf
		for part in parts:
			var view := MeshInstance3D.new()
			view.name = "%s_%s" % [item["name"], part["name"]]
			view.mesh = part["mesh"]
			view.transform = xf * part["local"]
			view.material_override = part["material"]
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if String(item["name"]).begins_with("wedge_"):
				view.set_meta("wedge", true)
			if String(item["file"]) == "breach_tab.glb":
				# P-R6: every plate is slam-anywhere, so every tab reads mint; no slate state.
				view.set_instance_shader_parameter("state_tint", MINT)
			skin.add_child(view)
	cover.add_child(skin)
	for child in cover.get_children():
		if child is MeshInstance3D:
			child.visible = false


func _warn_once(key: String, message: String) -> void:
	if not _warnings.has(key):
		_warnings[key] = true
		push_warning("dig_scenery: " + message)
