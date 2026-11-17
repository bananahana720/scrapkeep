extends RefCounted

const AppShell := preload("res://src/core/app_shell.gd")
const Palette := preload("res://src/core/palette.gd")
const Arena := preload("res://src/boss/arena.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const Yard := preload("res://src/presentation/arena_bowl_yard.gd")
const ASSET_DIR := "res://assets/models/bosses"
const SPILLWAY_DIR := "res://assets/models/world_one"
const FOUNDRY_PARTS := ["RimRepairs", "CraneRails", "PourSpouts", "CooledSlagPools", "CastFloorSeams", "MastCollars", "BankCopperCourses"]
const SPILLWAY_PARTS := ["rock_a", "rock_c", "slab_a", "slab_b"]
# Foundry parts authored on the bowl's own faces (the repairs on the rim wall, the copper courses on the bank, the pools
# and seams on the floor) stand SURFACE_STANDOFF_M in from and up off the bowl, so their faces do not z-fight the bowl's
# (clip audit, 30 Oct: BankCopperCourses 161 m2 in the bank's plane, RimRepairs 46 m2 in the rim wall's).
const ON_BOWL_PARTS := ["RimRepairs", "CooledSlagPools", "CastFloorSeams", "BankCopperCourses"]
const SURFACE_STANDOFF_M := 0.02
# The Fleet yard behind the rim (tools/blender/bosses/arena_bowl_yard.py): static parts, the two melt parts that glow
# with the phase, and the two plush crew the stands seat by MultiMesh.
const YARD_PARTS := ["YardDeck", "FleetStands", "CupolaFurnaces", "LadleCars", "LedgerBoard", "IngotStock", "CrewYard"]
const GLOW_PARTS := ["LadleMelt", "FurnaceGlow"]
const CREW_PARTS := ["CrewFan", "CrewPennant"]
# Mirrors the recipe's STANDS and tiers: sector centre and half width in degrees, then tier radius and plank top.
const STANDS := [Vector2(95.0, 18.0), Vector2(225.0, 12.0), Vector2(300.0, 18.0)]
const TIERS := 5
const TIER_R0 := 69.0
const TIER_DR := 2.4
const TIER_Y0 := 18.0
const TIER_DY := 2.0
const SEAT_PITCH := 2.0
# The crew sit at mascot scale, so a fan reads from the far side of the bowl, 140 m away.
const CREW_SCALE := 1.35
# Half the seats are taken, one fan in five waves a pennant; a fixed private stream, so every bowl seats the same crowd.
const SEAT_FILL := 0.5
const PENNANT_SHARE := 0.2
const CROWD_SEED := 0x5b0b
# Fur tints over the recipe's neutral fur: badger, fox, mole, otter, pack rat. Kept muted under the dressing rule.
const CREW_TINTS := [Color(0.92, 0.92, 0.92), Color(1.0, 0.82, 0.66), Color(0.78, 0.7, 0.64), Color(0.86, 0.78, 0.66), Color(0.95, 0.9, 0.82)]
const DECK_Y := 15.0
const LEDGER_ANGLE := 180.0
const LEDGER_R := 76.0
# Dry crew-log signs, not reads: none of them is in the riding lane or on a telegraph.
const SIGNS := [
	{"name": "LedgerTitle", "angle": 180.0, "r": 75.5, "y": 28.1, "size": 116, "text": "REQUISITION LEDGER", "lit": true},
	{"name": "SafetyTally", "angle": 279.5, "r": 70.06, "y": 18.6, "size": 46, "text": "SLAG BOWL\nDAYS WITHOUT A\nREQUISITION: 0"},
	{"name": "HiringNotice", "angle": 64.0, "r": 69.84, "y": 19.9, "size": 40, "text": "HANDS WANTED\nAPPLY WITHIN"},
]
const SIGN_FONT := "res://assets/fonts/NotoSans-Bold.ttf"
const SLOTS := {
	"foundry_steel": Vector2(0.87, 0.18), "foundry_copper": Vector2(0.76, 0.28),
	"cooled_slag": Vector2(0.97, 0.04), "paint": Vector2(0.95, 0.0),
	"bare_metal": Vector2(0.8, 0.15), "rubber": Vector2(0.98, 0.0),
	"slag_glow": Vector2(0.6, 0.0),
}

# Tests can redirect either folder. Nothing is loaded or built until the bowl is warmed or built.
static var asset_dir := ASSET_DIR
static var spillway_dir := SPILLWAY_DIR


# Each kit's parts read ahead by warm(), by file path until build takes them.
static var _ahead := {}
# The kit warm() is part way through: its path, the loaded scene, the views still to copy and the parts so far.
static var _reading := {}
static var _requested := {}


# A step a call while the world's last stage runs (boss.gd's warm_arena): a kit's file, then one part's
# mesh copy a call; true once every kit is read. A played game reads the file on a loader thread; headless
# reads it here, since the dummy rasterizer's mesh RIDs are not thread-safe (as requisition.gd). Reading a
# kit whole took 23-31 ms frames on the 4080 at the flume Warden's engage.
static func warm() -> bool:
	for kit in _kits():
		if _ahead.has(kit[0]):
			continue
		if _reading.is_empty() or _reading.path != kit[0]:
			var packed = _read(kit[0])
			if packed is bool:
				return false
			_drop_reading()
			_reading = _open(kit[0], packed, kit[1])
			if _reading.is_empty():
				_ahead[kit[0]] = {}
			return false
		if not _reading.views.is_empty():
			_reading.ok = _reading.ok and new()._take(_reading.views.pop_back(), _reading.scene, _reading.result)
			return false
		_ahead[kit[0]] = _close(_reading, kit[1])
		_reading = {}
		return false
	return true


static func drop_ahead() -> void:
	_ahead.clear()
	# A loader thread still reading a kit is waited out, so no load is left in flight at a quit.
	for path in _requested:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(path)
	_requested.clear()
	_drop_reading()


static func _drop_reading() -> void:
	if not _reading.is_empty() and is_instance_valid(_reading.scene):
		_reading.scene.free()
	_reading = {}


# The kit's scene, false while a loader thread still reads it, or null when it cannot load.
static func _read(path: String):
	if not ResourceLoader.exists(path):
		return null
	if AppShell.headless():
		return load(path) as PackedScene
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
		_requested[path] = true
		return false
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	_requested.erase(path)
	return ResourceLoader.load_threaded_get(path) as PackedScene if status == ResourceLoader.THREAD_LOAD_LOADED else null


static func _kits() -> Array:
	return [[asset_dir.path_join("arena_bowl_foundry.glb"), FOUNDRY_PARTS], [spillway_dir.path_join("clutter_kit.glb"), SPILLWAY_PARTS],
		[asset_dir.path_join("arena_bowl_yard.glb"), YARD_PARTS + GLOW_PARTS + CREW_PARTS]]


static func build(arena: Node3D) -> Node3D:
	var builder := new()
	var kits := _kits()
	var foundry: Dictionary = _ahead[kits[0][0]] if _ahead.has(kits[0][0]) else builder._parts(kits[0][0], kits[0][1])
	var stone: Dictionary = _ahead[kits[1][0]] if _ahead.has(kits[1][0]) else builder._parts(kits[1][0], kits[1][1])
	var yard: Dictionary = _ahead[kits[2][0]] if _ahead.has(kits[2][0]) else builder._parts(kits[2][0], kits[2][1])
	_ahead.clear()
	_drop_reading()
	if foundry.is_empty() or stone.is_empty():
		push_warning("arena_bowl_dress: missing or malformed foundry/Spillway kit; Slag Bowl keeps its greybox")
		return null
	var dressing := Node3D.new()
	dressing.name = "ArenaBowlDress"
	# In by the standoff at the rim wall's radius (less further in, where the bank and floor need the lift instead), and up.
	var inward := 1.0 - SURFACE_STANDOFF_M / Arena.BANK_R
	var standoff := Transform3D(Basis.from_scale(Vector3(inward, 1.0, inward)), Vector3(0.0, SURFACE_STANDOFF_M, 0.0))
	for part in FOUNDRY_PARTS:
		var local: Transform3D = foundry[part].local
		builder._view(dressing, part, foundry[part].mesh, standoff * local if ON_BOWL_PARTS.has(part) else local)
	var rubble := Node3D.new()
	rubble.name = "SpillwayRimStone"
	dressing.add_child(rubble)
	for i in 16:
		var angle := float(i) * TAU / 16.0 + 0.09 * sin(float(i) * 2.7)
		var size := 4.5 + 1.5 * sin(float(i) * 1.9)
		var at := Vector3(cos(angle), 0, sin(angle)) * (65.0 + 2.0 * sin(float(i) * 1.3))
		at.y = 9.0 + 0.4 * sin(float(i))
		var part: String = SPILLWAY_PARTS[i % SPILLWAY_PARTS.size()]
		var placement := Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(size, size * 0.7, size)), at)
		builder._view(rubble, "RimStone_%d" % i, stone[part].mesh, placement * stone[part].local)
	# The yard is its own kit: without it the foundry dressing still stands, the rim just has no crowd.
	if yard.is_empty():
		push_warning("arena_bowl_dress: missing or malformed arena_bowl_yard.glb; Slag Bowl dresses without its Fleet yard")
	else:
		builder._yard(dressing, yard)
	arena.add_child(dressing)
	builder._surfaces(arena)
	return dressing


# The Fleet yard on the game bus, once the bowl is in the tree: a bowl built ahead has no parent
# to read the bus from when its dressing is built.
static func bind_yard(arena: Node3D) -> void:
	var yard = arena.get_node_or_null("ArenaBowlDress/FleetYard")
	if yard == null:
		return
	var events = arena.get_parent().get("events") if arena.get_parent() != null else null
	yard.bind(events)


func _yard(dressing: Node3D, parts: Dictionary) -> void:
	var yard: Node3D = Yard.new()
	yard.name = "FleetYard"
	dressing.add_child(yard)
	for part in YARD_PARTS:
		_view(yard, part, parts[part].mesh, parts[part].local)
		# Behind the wall a yard part's shadow falls only on the yard deck, out of the fight's sight, so only the
		# furnaces (tall enough to throw theirs into the bowl) pay for a shadow pass.
		if part != "CupolaFurnaces":
			(yard.get_node(part) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	yard.melt_material = _slot_material("slag_glow")
	for part in GLOW_PARTS:
		_view(yard, part, parts[part].mesh, parts[part].local)
		var view := yard.get_node(part) as MeshInstance3D
		view.material_override = yard.melt_material
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rests := {"CrewFan": [], "CrewPennant": []}
	var tints := {"CrewFan": [], "CrewPennant": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = CROWD_SEED
	for stand: Vector2 in STANDS:
		var lo := deg_to_rad(stand.x - stand.y)
		var span := deg_to_rad(stand.y * 2.0)
		for k in TIERS:
			var r := TIER_R0 + TIER_DR * k
			var count := floori(span * r / SEAT_PITCH)
			for j in count:
				var taken := rng.randf() < SEAT_FILL
				var kind := "CrewPennant" if rng.randf() < PENNANT_SHARE else "CrewFan"
				var turn := rng.randf_range(-0.18, 0.18)
				var size := CREW_SCALE * rng.randf_range(0.92, 1.08)
				var tint: Color = CREW_TINTS[rng.randi_range(0, CREW_TINTS.size() - 1)]
				if not taken:
					continue
				var angle := lo + span * (j + 0.5) / count
				var at := Vector3(cos(angle) * (r - 0.3), TIER_Y0 + TIER_DY * k, sin(angle) * (r - 0.3))
				# The crew are built facing +X; PI - angle turns them to the bowl's centre.
				rests[kind].append(Transform3D(Basis(Vector3.UP, PI - angle + turn).scaled(Vector3.ONE * size), at))
				tints[kind].append(tint)
	for kind in CREW_PARTS:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = parts[kind].mesh
		multi.instance_count = rests[kind].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, rests[kind][i])
			multi.set_instance_color(i, tints[kind][i])
		var crowd := MultiMeshInstance3D.new()
		crowd.name = kind + "s"
		crowd.multimesh = multi
		crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		yard.add_child(crowd)
		yard.seat(crowd, rests[kind])
	var font := load(SIGN_FONT) as Font
	# The ledger's figure reads from the fight's camera across the bowl (about 100 m); the caption reads up close.
	yard.ledger_line = _sign(yard, font, {"name": "LedgerLine", "angle": LEDGER_ANGLE, "r": LEDGER_R - 0.5, "y": DECK_Y + 10.5,
		"size": 230, "text": "", "lit": true})
	yard.ledger_caption = _sign(yard, font, {"name": "LedgerCaption", "angle": LEDGER_ANGLE, "r": LEDGER_R - 0.5,
		"y": DECK_Y + 7.35, "size": 96, "text": "", "lit": true})
	for row in SIGNS:
		_sign(yard, font, row)


func _sign(parent: Node3D, font: Font, row: Dictionary) -> Label3D:
	var angle := deg_to_rad(row.angle)
	var label := Label3D.new()
	label.name = row.name
	label.text = row.text
	label.font = font
	label.font_size = row.size
	label.pixel_size = 0.01
	label.outline_size = 0
	# The ledger's chalk is unshaded so the board's own shadow and the haze never sink it; the small notices take the light.
	var lit: bool = row.get("lit", false)
	label.modulate = Palette.LEDGER if lit else Palette.LEDGER.darkened(0.12)
	label.double_sided = false
	label.shaded = not lit
	label.position = Vector3(cos(angle) * row.r, row.y, sin(angle) * row.r)
	# A Label3D reads from +Z: turn +Z to face the bowl's centre.
	label.basis = Basis(Vector3.UP, atan2(-cos(angle), -sin(angle)))
	parent.add_child(label)
	return label


func _parts(path: String, required: Array) -> Dictionary:
	var reading := _open(path, load(path) as PackedScene if ResourceLoader.exists(path) else null, required)
	if reading.is_empty():
		return {}
	for view in reading.views:
		reading.ok = reading.ok and _take(view, reading.scene, reading.result)
	return _close(reading, required)


# The kit's instance and its required views; empty when the file is missing or carries a collider.
static func _open(path: String, packed: PackedScene, required: Array) -> Dictionary:
	if packed == null:
		return {}
	var scene := packed.instantiate()
	if not scene.find_children("*", "CollisionObject3D", true, false).is_empty():
		scene.free()
		return {}
	var views := []
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if String(view.name) in required and view.mesh != null and view.mesh.get_surface_count() > 0:
			views.append(view)
	return {"path": path, "scene": scene, "views": views, "result": {}, "ok": true}


# Copies one part's mesh with the slot materials into result; false when the part is malformed.
func _take(view: MeshInstance3D, scene: Node, result: Dictionary) -> bool:
	var mesh := view.mesh.duplicate() as ArrayMesh
	if mesh == null:
		return true
	for surface in mesh.get_surface_count():
		var source := view.mesh.surface_get_material(surface)
		if source == null or not SLOTS.has(String(source.resource_name)):
			return false
		var arrays := mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].size() != arrays[Mesh.ARRAY_VERTEX].size():
			return false
		mesh.surface_set_material(surface, _slot_material(String(source.resource_name)))
	result[String(view.name)] = {"mesh": mesh, "local": _relative(view, scene)}
	return true


static func _close(reading: Dictionary, required: Array) -> Dictionary:
	reading.scene.free()
	return reading.result if reading.ok and reading.result.size() == required.size() else {}


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			transform = walk.transform * transform
		walk = walk.get_parent()
	return transform


func _slot_material(slot: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = slot
	material.vertex_color_use_as_albedo = true
	material.roughness = SLOTS[slot].x
	material.metallic = SLOTS[slot].y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if slot in ["foundry_steel", "foundry_copper"]:
		material.albedo_texture = Palette.look_texture("rusted-salvaged-plate-worn", true)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE / 4.0
	elif slot == "slag_glow":
		# The only lit dressing: the yard sets its colour and energy by phase (arena_bowl_yard.gd MELT).
		material.emission_enabled = true
	return material


func _view(parent: Node3D, label: String, mesh: Mesh, transform: Transform3D) -> void:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.transform = transform
	parent.add_child(view)


func _surfaces(arena: Node3D) -> void:
	var floor_mat := _slot_material("foundry_steel")
	floor_mat.resource_name = "bowl_cast_floor"
	floor_mat.albedo_color = Color("56594f")
	floor_mat.albedo_texture = Palette.look_texture("riveted-gyro-metal", true)
	floor_mat.roughness = 0.93
	floor_mat.uv1_scale = Vector3.ONE / 9.0
	var bank_mat := Palette.ground_material().duplicate() as ShaderMaterial
	bank_mat.resource_name = "bowl_sandstone_bank"
	bank_mat.set_shader_parameter("cliff_only", true)
	bank_mat.set_shader_parameter("local_pattern", true)
	var wall_mat := _slot_material("foundry_steel")
	wall_mat.resource_name = "bowl_rusted_rim"
	wall_mat.albedo_color = Color("84604b")
	var ramp_mat := _slot_material("foundry_copper")
	ramp_mat.resource_name = "bowl_cast_ramps"
	ramp_mat.albedo_color = Palette.COPPER
	var mast_mat := _slot_material("foundry_steel")
	mast_mat.resource_name = "bowl_crane_masts"
	# A weathered steel upright against the copper of the inward ramp and the rim repairs.
	mast_mat.albedo_color = Color("b7b6a3")
	# Only arena-owned views carry this metadata. Combat/hazards and vent pads stay live.
	for view: MeshInstance3D in arena.get_children().filter(func(n): return n is MeshInstance3D):
		match view.get_meta("bowl_surface", ""):
			"Floor": view.material_override = floor_mat
			"Bank": view.material_override = bank_mat
			"RimWall": view.material_override = wall_mat
			"Ramp": view.material_override = ramp_mat
			"Kicker":
				view.material_override = ramp_mat
				_kicker(arena, view)
			"Mast", "Crossbar": view.material_override = mast_mat


# The authored kicker replaces the greybox view where the collider stands: one holder per kicker at the wedge's own
# frame (arena.gd _wedge), its base views and detail shells at the holder's origin, so the recipe's riding face lies on
# the collider plane. The greybox view stays in the tree, hidden, and the collider is untouched.
func _kicker(arena: Node3D, view: MeshInstance3D) -> void:
	var holder := Node3D.new()
	holder.name = "KickerWedge"
	holder.transform = view.transform * (view.get_meta(Arena.WEDGE_FRAME) as Transform3D)
	arena.add_child(holder, true)
	RecipeProps.base("kicker_wedge", holder, Transform3D.IDENTITY)
	RecipeProps.shells("kicker_wedge", holder, Transform3D.IDENTITY)
	view.visible = false
