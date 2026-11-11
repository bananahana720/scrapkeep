extends Node3D

# Site markers (map audit unit 4, map standard point 1: "smaller signs mark caches and objectives, never a HUD arrow"):
# a thin smoke plume over each place worth a detour that has nothing tall of its own, so a player on the line can see
# it from a distance and choose to go. Three kinds, told apart by shape and motion first and by shade second, so none
# borrows a pickup's glow, an enemy's paint or a colour-law row (LEGIBILITY section 1):
#
# - cache: a rib cache still waiting (scrap_field.gd caches()). A keeper's brew fire: one pale wisp that leans and curls.
# - cage: a caged pilot not yet freed (rescue_site.gd). A smoke signal: pale puffs rising in an even beat.
# - rogue: the stage's rogue site while its machine still sleeps (world.gd rogue_plan). Works exhaust: a dark column
#   that chugs in puffs that drift off the beat, the rogue's old work cycle (STORY-MAP section 3).
#
# A plume goes the moment its thing is done: the cache taken, the cage spent, the rogue woken. Secrets (field finds) keep
# no sign by rule (activities.gd _dress_find), standing activities have their amber column, Signal caches their mast.
# Smoke is drawn, not simulated: one camera-facing quad a site with a shader, no particles and no light. It is a sign
# for the middle distance: gone inside GONE_M so it never stands over the thing it marks, full from FULL_M to
# FAR_FULL_M, and gone again by FAR_GONE_M, inside the chase camera's 700 m far plane.

const Shade := preload("res://src/presentation/site_markers.gdshader")

const CREW_SMOKE := Color("ece6d8")
const WORKS_SMOKE := Color("262826")
const KINDS := {
	"cache": {"tint": CREW_SMOKE, "height": 30.0, "width": 12.0, "alpha": 0.95, "foot": 0.1, "crown": 0.7,
		"sway": 0.35, "sway_hz": 0.12, "rise": 0.06, "grain": Vector2(3.0, 7.0), "puffs": 0.0, "stutter": 0.0},
	"cage": {"tint": CREW_SMOKE, "height": 40.0, "width": 16.0, "alpha": 0.9, "foot": 0.14, "crown": 0.85,
		"sway": 0.12, "sway_hz": 0.1, "rise": 0.09, "grain": Vector2(2.5, 5.0), "puffs": 4.0, "stutter": 0.0},
	"rogue": {"tint": WORKS_SMOKE, "height": 44.0, "width": 18.0, "alpha": 0.9, "foot": 0.2, "crown": 0.9,
		"sway": 0.08, "sway_hz": 0.07, "rise": 0.07, "grain": Vector2(2.0, 4.0), "puffs": 6.0, "stutter": 0.8},
}
const GONE_M := 12.0
const FULL_M := 40.0
const FAR_FULL_M := 450.0
const FAR_GONE_M := 600.0
# The site list is read four times a second; the fade follows the camera every frame.
const READ_EVERY := 0.25

var ctx
# key -> the plume's MeshInstance3D; each carries meta "kind".
var views := {}
var _clock := 0.0
static var _materials := {}
static var _meshes := {}


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "SiteMarkers"
	var events = ctx.get("events")
	if events != null:
		# A new stage reads its sites on the next frame; leaving one takes every plume down at once.
		events.stage_entered.connect(_on_stage_entered)
		events.stage_content_cleared.connect(_on_cleared)


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	sync([])
	_clock = 0.0


func _on_cleared(_reason: String) -> void:
	sync([])
	_clock = READ_EVERY


# The share of a plume's alpha it shows for an eye distance_m away (horizontal): the one rule for distance.
static func near_alpha(distance_m: float) -> float:
	return smoothstep(GONE_M, FULL_M, distance_m) * (1.0 - smoothstep(FAR_FULL_M, FAR_GONE_M, distance_m))


# Every site that wants a plume now, as [{key, kind, at}] with at the plume's foot. world is the World node (its
# rescue and rogue_plan), scrap the build's scrap field (its caches()), terrain answers height(x, z); any may be null.
static func sites(world, scrap, terrain) -> Array:
	var out := []
	if scrap != null and scrap.has_method("caches"):
		for c in scrap.caches():
			var item: Node3D = c["item"]
			if is_instance_valid(item):
				out.append({"key": "cache:%d" % item.get_instance_id(), "kind": "cache", "at": _ground(terrain, c["at"])})
	var rescue = world.get("rescue") if world != null else null
	if rescue != null:
		for cage in rescue.cages:
			if is_instance_valid(cage) and not cage.spent:
				out.append({"key": "cage:" + String(cage.quest), "kind": "cage", "at": cage.global_position})
	var plan = world.get("rogue_plan") if world != null else null
	if plan is Dictionary and not plan.is_empty():
		var at: Vector2 = plan["at"]
		out.append({"key": "rogue:" + String(plan["site"]), "kind": "rogue", "at": _ground(terrain, Vector3(at.x, 0.0, at.y))})
	return out


static func _ground(terrain, at: Vector3) -> Vector3:
	if terrain == null or not terrain.has_method("height"):
		return at
	return Vector3(at.x, terrain.height(at.x, at.z), at.z)


# Puts up a plume for each site in list that has none and takes down every plume whose site is gone.
func sync(list: Array) -> void:
	var wanted := {}
	for s in list:
		wanted[s["key"]] = true
		if not views.has(s["key"]):
			views[s["key"]] = _plume(String(s["kind"]), s["at"], String(s["key"]))
	for key in views.keys():
		if not wanted.has(key):
			views[key].queue_free()
			views.erase(key)


func _plume(kind: String, at: Vector3, key: String) -> MeshInstance3D:
	var row: Dictionary = KINDS[kind]
	var view := MeshInstance3D.new()
	view.name = "Plume_" + key.replace(":", "_")
	view.mesh = _mesh(kind)
	# Each plume owns a copy of its kind's material: per-instance shader uniforms overflow the project's global
	# buffer on the compatibility renderer, and a stage stands only a handful of plumes.
	var material: ShaderMaterial = _material(kind).duplicate()
	material.set_shader_parameter("near_alpha", 0.0)
	material.set_shader_parameter("seed", float(absi(hash(key)) % 1000) / 1000.0)
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quad turns about its axis in the shader, so its bounds must cover the turn.
	view.extra_cull_margin = float(row["width"]) * 0.5
	view.set_meta("kind", kind)
	add_child(view)
	view.global_position = at
	view.visible = false
	return view


static func _mesh(kind: String) -> QuadMesh:
	if not _meshes.has(kind):
		var row: Dictionary = KINDS[kind]
		var quad := QuadMesh.new()
		quad.size = Vector2(float(row["width"]), float(row["height"]))
		quad.center_offset = Vector3(0.0, float(row["height"]) * 0.5, 0.0)
		_meshes[kind] = quad
	return _meshes[kind]


static func _material(kind: String) -> ShaderMaterial:
	if not _materials.has(kind):
		var row: Dictionary = KINDS[kind]
		var m := ShaderMaterial.new()
		m.shader = Shade
		for p in ["tint", "alpha", "foot", "crown", "sway", "sway_hz", "rise", "grain", "puffs", "stutter"]:
			m.set_shader_parameter(p, row[p])
		_materials[kind] = m
	return _materials[kind]


# Each plume's shown share for an eye; a plume with nothing to show is hidden, so it costs no draw.
func fade_for(eye: Vector3) -> void:
	for view: MeshInstance3D in views.values():
		var at := view.global_position
		var share := near_alpha(Vector2(at.x - eye.x, at.z - eye.z).length())
		view.visible = share > 0.0
		(view.material_override as ShaderMaterial).set_shader_parameter("near_alpha", share)


func _process(delta: float) -> void:
	if ctx == null:
		return
	_clock -= delta
	if _clock <= 0.0:
		_clock = READ_EVERY
		var root = ctx.get("root")
		var world: Node = root.get_node_or_null("World") if root != null else null
		var build = ctx.get("build")
		sync(sites(world, build.get("scrap") if build != null else null, ctx.get("terrain")))
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		fade_for(camera.global_position)
