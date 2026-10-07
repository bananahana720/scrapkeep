extends RefCounted

const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const DigFx := preload("res://src/presentation/dig_fx.gd")

# The Dig's scenery (alpha dress push, unit WDG): both zones' landmarks, cut faces, rubble,
# struts, carts, shells and lamp lines along the rim, the drum look on every breach cover, the
# stone beds as the ground material, and the Dig's light. Presentation only. Nothing here
# collides, no gameplay rectangle moves, and breach.gd and terrain.apply_swap stay the owners of
# the break. Every instance stands outside the play rect plus its 8 m apron, on the rim's foot.
# A missing GLB is skipped with a warning; a breach whose skin cannot be built keeps its box.

# The directories are static vars so a test can point them at nothing and see the fallback.
static var stone_dir := "res://assets/models/dig_stone/"
static var mech_dir := "res://assets/models/dig_mechanical/"
const SLOTS := {
	"stone": "res://assets/materials/dig_stone/stone.tres",
	"steel": "res://assets/materials/dig_mechanical/steel.tres",
	"enamel": "res://assets/materials/dig_mechanical/enamel.tres",
	"elastomer": "res://assets/materials/dig_mechanical/elastomer.tres",
	"glass": "res://assets/materials/dig_mechanical/glass.tres",
}
const MINT := Color("8bf0d3")
# Warm white, not amber: amber belongs to an offered landing or reward (SHEET.md).
const LAMP_LIGHT := Color(1.0, 0.93, 0.82)
const DAYLIGHT := Color(1.0, 0.95, 0.80)
const APRON := 8.0
const BURY := 0.25
const ASSEMBLY_LIFT := 0.03
# Per zone: [cut faces per edge (long, scoop), rubble, struts, carts, shells]. Zone A favours long
# cuts, zone B scooped faces and sheltered recesses; B keeps the machines sparse (BUILD-SPEC).
const MIX := {
	"dig": {"long": 8, "scoop": 3, "rubble": 12, "strut": 5, "cart": 2, "shell": 3},
	"dig_deep": {"long": 3, "scoop": 8, "rubble": 12, "strut": 2, "cart": 1, "shell": 6},
}
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


# Built on first entry, not at boot: building the Dig's terrain at game start changes
# physics body creation order and so every seeded run (Rivet seed 1: 38208 -> 34066 ticks).
static func hook(ctx) -> void:
	ctx.events.stage_entered.connect(_on_stage_entered.bind(ctx))


static func _on_stage_entered(stage: int, _retry: bool, ctx) -> void:
	for row in ctx.stages.DEFS:
		if row["stage"] == stage and row["map"] in ["dig", "dig_deep"]:
			var root: Node3D = ctx.terrain.geometry_root(stage)
			if root.get_node_or_null("DigScenery") == null:
				build(root, ctx.terrain.map_for(stage), row["map"])
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
	_edges(batches, ground, map_id)
	_landmark(batches, ground, map_id)
	_flush(scenery, batches)
	_lamp_lines(scenery, batches, ground, map_id)
	_flush(scenery, batches)
	_breach_skins(stage_root, map)
	_fx.finish_build()


# The ground's beds: the Dig's own stone material over the terrain mesh. The preset system
# rewrites a ground view's material on every preset change, so a dressing host puts it back.
# The target preset keeps its own ground shader on every map, so the beds stand in high and low.
class GroundBeds extends Node:
	var view: MeshInstance3D
	var material: Material

	func _sync_dressing() -> void:
		# The target preset owns every ground (target_material_test); the beds stand in the others.
		if view != null and material != null and GraphicsPreset.current != "target":
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


func _edges(batches: Dictionary, ground: Callable, map_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("dig_scenery_" + map_id).hash()
	var mix: Dictionary = MIX.get(map_id, MIX["dig"])
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
	if not _put(batches, _mech("cart_body.glb"), body):
		return
	for socket in [Vector3(-0.74, 0.3, -0.95), Vector3(0.74, 0.3, -0.95), Vector3(-0.74, 0.3, 0.95), Vector3(0.74, 0.3, 0.95)]:
		_put(batches, _mech("cart_wheel.glb"), body * Transform3D(Basis.IDENTITY, socket))


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


# Straight and curved rails on the rim wall, hung well above any shelf, each with one warm
# light. Lens and rail are two meshes of one GLB; the GLB's own sockets chain the modules.
func _lamp_lines(scenery: Node3D, batches: Dictionary, ground: Callable, map_id: String) -> void:
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
			var first := xf
			var modules := 2 if curved else 3
			for m in modules:
				var file := "lamp_curve_module.glb" if curved else "lamp_straight_module.glb"
				if not _put(batches, _mech(file), xf, line * 0.73, m == 1):
					break
				xf = xf * Transform3D(Basis.IDENTITY, Vector3(3.0, 0, -0.35) if curved else Vector3(2.667, 0, 0))
			var light := OmniLight3D.new()
			light.name = "LampLight"
			light.light_color = LAMP_LIGHT
			light.light_energy = 1.6
			light.omni_range = 24.0
			light.shadow_enabled = false
			scenery.add_child(light)
			light.transform = first * Transform3D(Basis.IDENTITY, Vector3(4.0, -2.0, -3.0))
			_fx.lights.append({"node": light, "phase": line * 0.73, "rest": light.transform})
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
		_daylight(cover, rect)


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


# A faint daylight shaft and a cool-warm pool above the membrane: light from the breach
# overhead. Both are children of the cover, so they leave with it when the plate breaks.
func _daylight(cover: StaticBody3D, rect: Rect2) -> void:
	if cover.find_child("BreachSkin", false, false) == null:
		return
	var top := 0.0
	for child in cover.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			top = child.shape.size.y * 0.5
	var shaft := MeshInstance3D.new()
	shaft.name = "DaylightShaft"
	var cone := CylinderMesh.new()
	cone.top_radius = minf(rect.size.x, rect.size.y) * 0.5
	cone.bottom_radius = maxf(rect.size.x, rect.size.y) * 0.5 + 1.0
	cone.height = 26.0
	cone.radial_segments = 24
	cone.rings = 1
	shaft.mesh = cone
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(DAYLIGHT.r, DAYLIGHT.g, DAYLIGHT.b, 0.07)
	shaft.material_override = material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.position = Vector3(0, top + 13.0, 0)
	cover.add_child(shaft)
	var pool := SpotLight3D.new()
	pool.name = "DaylightPool"
	pool.light_color = DAYLIGHT
	pool.light_energy = 3.0
	pool.spot_range = 40.0
	pool.spot_angle = 24.0
	pool.shadow_enabled = false
	pool.position = Vector3(0, top + 26.0, 0)
	pool.rotation_degrees = Vector3(-90, 0, 0)
	cover.add_child(pool)
