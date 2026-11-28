extends Node3D

const Shade := preload("res://src/presentation/site_markers.gdshader")
const Arena := preload("res://src/boss/arena.gd")
const Palette := preload("res://src/core/palette.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Yard := preload("res://src/presentation/arena_bowl_yard.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const Comfort := preload("res://src/core/comfort.gd")

const CREW_SMOKE := Color("ece6d8")
const FLAG_OUT_M := 9.0
const FLAG_ASIDE_M := 4.0
const FLAG_RING := 16
const FLAG_LEVEL_M := 0.6
const WORKS_SMOKE := Color("262826")
const FURNACE_GLOW: Color = Yard.MELT[2]["color"]
const KINDS := {
	"cache": {"tint": CREW_SMOKE, "height": 34.0, "width": 14.0, "alpha": 1.0, "foot": 0.12, "crown": 0.85, "rim_dark": 0.45,
		"sway": 0.3, "sway_hz": 0.12, "rise": 0.06, "grain": Vector2(3.0, 7.0), "puffs": 0.0, "stutter": 0.0},
	"cage": {"tint": CREW_SMOKE, "height": 44.0, "width": 18.0, "alpha": 1.0, "foot": 0.14, "crown": 0.85, "rim_dark": 0.5,
		"sway": 0.12, "sway_hz": 0.1, "rise": 0.09, "grain": Vector2(2.5, 5.0), "puffs": 4.0, "stutter": 0.0},
	"rogue": {"tint": WORKS_SMOKE, "height": 48.0, "width": 20.0, "alpha": 1.0, "foot": 0.2, "crown": 0.9, "rim_dark": 1.0,
		"sway": 0.08, "sway_hz": 0.07, "rise": 0.07, "grain": Vector2(2.0, 4.0), "puffs": 6.0, "stutter": 0.8},
	"crew": {"tint": CREW_SMOKE, "height": 30.0, "width": 16.0, "alpha": 1.3, "foot": 0.1, "crown": 0.8, "rim_dark": 0.6,
		"sway": 0.05, "sway_hz": 0.2, "rise": 0.16, "grain": Vector2(3.0, 6.0), "puffs": 9.0, "stutter": 0.0},
	"furnace": {"tint": WORKS_SMOKE, "height": 170.0, "width": 80.0, "alpha": 1.8, "foot": 0.3, "crown": 0.95, "rim_dark": 0.7,
		"sway": 0.06, "sway_hz": 0.05, "rise": 0.035, "grain": Vector2(2.0, 3.5), "puffs": 0.0, "stutter": 0.0,
		"glow": Color(FURNACE_GLOW, 0.85), "far": true, "near": Vector2(60.0, 140.0)},
}
const VISITED_SPECS := {
	"cache": {"flips": true, "mark": "flag", "color": Palette.SAND, "tie": Palette.COPPER, "glow": 0.0, "still": true},
	"crew": {"flips": true, "mark": "chalk_x", "color": Palette.SAND, "tie": Palette.SAND, "glow": 0.0, "still": true},
	"cage": {"flips": true, "mark": "scarf_post", "color": Palette.SAND, "tie": Palette.COPPER, "glow": 0.0, "still": true},
	"rogue": {"flips": true, "mark": "wreck", "color": Palette.CHARCOAL, "tie": Palette.CHARCOAL, "glow": 0.0, "still": true},
	"shortcut": {"flips": true, "mark": "scorched_frame", "color": Palette.CHARCOAL, "tie": Palette.CHARCOAL, "glow": 0.0, "still": true},
	"cable": {"flips": true, "mark": "severed", "color": Palette.CHARCOAL, "tie": Palette.CHARCOAL, "glow": 0.0, "still": true},
	"furnace": {"flips": false, "mark": "", "color": WORKS_SMOKE, "tie": WORKS_SMOKE, "glow": 0.0, "still": true},
}
const FURNACE_BOSS := "brindle"
const PULL_M := 520.0
const GONE_M := 12.0
const FULL_M := 40.0
const FAR_FULL_M := 450.0
const FAR_GONE_M := 600.0
const GROW_FROM_M := 130.0
const GROW_MAX := 2.5
const READ_EVERY := 0.25
const LEAVE_S := 1.0
const EYE_STILL_M := 0.25

var ctx
var views := {}
var leaving: Array[MeshInstance3D] = []
var _clock := 0.0
var _last_eye := Vector3.INF
var _furnace: Array = [0, null]
var _visited := {}
var _rogue_key := ""
var flags: Array[Node3D] = []
static var _materials := {}
static var _meshes := {}


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "SiteMarkers"
	var events = ctx.get("events")
	if events != null:
		events.stage_entered.connect(_on_stage_entered)
		events.stage_content_cleared.connect(_on_cleared)
		if events.has_signal("rescue_completed"):
			events.rescue_completed.connect(_on_rescue_completed)
		if events.has_signal("enemy_killed"):
			events.enemy_killed.connect(_on_enemy_killed)
		if events.has_signal("activity_done"):
			events.activity_done.connect(_on_activity_done)


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	sync([])
	reset_visited()
	_drop_flags()
	_furnace = [0, null]
	_clock = 0.0


func _on_cleared(_reason: String) -> void:
	sync([])
	reset_visited()
	_drop_flags()
	_clock = READ_EVERY


func _on_rescue_completed(quest_id: String) -> void:
	var key := "cage:" + quest_id
	if views.has(key):
		mark_visited(key, "cage", views[key].get_meta("at"))


func _on_activity_done(id: String, at: Vector3) -> void:
	if id != "cracked_cache":
		return
	var key := "cracked_cache:%d,%d" % [roundi(at.x), roundi(at.z)]
	if not mark_visited(key, "cache", at):
		return
	var terrain = ctx.get("terrain") if ctx != null else null
	var raised := CrackedCache.raise_flag(self, pocket_flag_foot(at, terrain), Comfort.reduced_motion)
	if raised != null:
		flags.append(raised)


static func pocket_flag_foot(at: Vector3, terrain) -> Vector3:
	if terrain == null or not terrain.has_method("height"):
		return at
	var best := Vector3.FORWARD
	var low := INF
	for k in FLAG_RING:
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / FLAG_RING)
		var probe := at + way * FLAG_OUT_M
		var across := way.cross(Vector3.UP) * FLAG_OUT_M * 0.7
		var off: float = absf(terrain.height(probe.x, probe.z) - at.y) + 0.05 * (
			absf(terrain.height(probe.x + across.x, probe.z + across.z) - at.y)
			+ absf(terrain.height(probe.x - across.x, probe.z - across.z) - at.y))
		if off < low - 0.01:
			low = off
			best = way
	var foot := at + best * FLAG_OUT_M
	var aside := foot + best.cross(Vector3.UP) * -FLAG_ASIDE_M
	if absf(terrain.height(aside.x, aside.z) - at.y) <= FLAG_LEVEL_M:
		foot = aside
	return Vector3(foot.x, terrain.height(foot.x, foot.z), foot.z)


func _drop_flags() -> void:
	for raised in flags:
		if is_instance_valid(raised):
			raised.queue_free()
	flags.clear()


func _on_enemy_killed(kind: String, at: Vector3, _scrap_value: int) -> void:
	if not Rogue.ROWS.has(kind):
		return
	var key := _rogue_key if _rogue_key != "" else "rogue:" + kind
	mark_visited(key, "rogue", at)


static func visited_spec(kind: String) -> Dictionary:
	return VISITED_SPECS.get(kind, {}).duplicate()


func mark_visited(key: String, kind: String, at: Vector3 = Vector3.ZERO) -> bool:
	if key == "" or _visited.has(key) or not VISITED_SPECS.has(kind):
		return false
	var spec: Dictionary = VISITED_SPECS[kind]
	if not bool(spec["flips"]):
		return false
	_visited[key] = {
		"key": key, "kind": kind, "at": at, "mark": String(spec["mark"]),
		"color": spec["color"], "tie": spec["tie"], "glow": float(spec["glow"]),
		"still": bool(spec["still"]),
	}
	return true


func is_visited(key: String) -> bool:
	return _visited.has(key)


func visited_state(key: String) -> Dictionary:
	return _visited.get(key, {}).duplicate()


func visited_sites() -> Array:
	var out := []
	for row: Dictionary in _visited.values():
		out.append(row.duplicate())
	return out


func reset_visited() -> void:
	_visited.clear()
	_rogue_key = ""


static func near_alpha(distance_m: float, far := false, near := Vector2(GONE_M, FULL_M)) -> float:
	var share := smoothstep(near.x, near.y, distance_m)
	return share if far else share * (1.0 - smoothstep(FAR_FULL_M, FAR_GONE_M, distance_m))


static func furnace_site(world_last: bool, boss_kind: String, showing: bool, foot) -> Dictionary:
	if not world_last or boss_kind != FURNACE_BOSS or not showing or not foot is Vector3:
		return {}
	return {"key": "furnace", "kind": "furnace", "at": foot}


static func furnace_foot(terrain, stage: int):
	if terrain == null or not terrain.has_method("height") or not terrain.has_method("map_for"):
		return null
	var map = terrain.map_for(stage)
	if map == null or not map.has_method("handover") or not map.handover().has("exit"):
		return null
	var bowl: Vector3 = Arena.place_ahead(terrain, stage)
	return _ground(terrain, Vector3(bowl.x, 0.0, bowl.z))


static func sites(world, scrap, terrain) -> Array:
	var out := []
	if scrap != null and scrap.has_method("caches"):
		for c in scrap.caches():
			var item: Node3D = c["item"]
			if is_instance_valid(item):
				var foot: Vector3 = c["foot"]
				out.append({"key": "cache:%d:%d" % [roundi(foot.x * 10.0), roundi(foot.z * 10.0)], "kind": "cache", "at": foot})
	var rescue = world.get("rescue") if world != null else null
	if rescue != null:
		for cage in rescue.waiting():
			out.append({"key": "cage:" + String(cage["quest"]), "kind": "cage", "at": cage["at"]})
	var director = world.get("director") if world != null else null
	if director != null and director.has_method("live_homes"):
		for home in director.live_homes():
			var spot: Vector2 = home["at"]
			out.append({"key": "crew:" + String(home["id"]), "kind": "crew", "at": _ground(terrain, Vector3(spot.x, 0.0, spot.y))})
	var plan = world.get("rogue_plan") if world != null else null
	if plan is Dictionary and not plan.is_empty():
		var at: Vector2 = plan["at"]
		out.append({"key": "rogue:" + String(plan["site"]), "kind": "rogue", "at": _ground(terrain, Vector3(at.x, 0.0, at.y))})
	return out


static func _ground(terrain, at: Vector3) -> Vector3:
	if terrain == null or not terrain.has_method("height"):
		return at
	return Vector3(at.x, terrain.height(at.x, at.z), at.z)


func sync(list: Array, fade := false) -> void:
	var wanted := {}
	for s in list:
		wanted[s["key"]] = true
		if String(s["kind"]) == "rogue":
			_rogue_key = String(s["key"])
		if not views.has(s["key"]):
			views[s["key"]] = _plume(String(s["kind"]), s["at"], String(s["key"]))
			_last_eye = Vector3.INF
	for key in views.keys():
		if not wanted.has(key):
			var view: MeshInstance3D = views[key]
			views.erase(key)
			var kind := String(view.get_meta("kind"))
			if fade and kind != "rogue":
				mark_visited(key, kind, view.get_meta("at"))
			if fade and view.visible:
				view.set_meta("leave", 1.0)
				leaving.append(view)
			else:
				view.queue_free()
	if not fade:
		for view in leaving:
			view.queue_free()
		leaving.clear()


func _plume(kind: String, at: Vector3, key: String) -> MeshInstance3D:
	var row: Dictionary = KINDS[kind]
	var view := MeshInstance3D.new()
	view.name = "Plume_" + key.replace(":", "_")
	view.mesh = _mesh(kind)
	# Per-material copy avoids overflowing Godot Compatibility renderer per-instance uniform buffer.
	var material: ShaderMaterial = _material(kind).duplicate()
	material.set_shader_parameter("near_alpha", 0.0)
	material.set_shader_parameter("seed", float(absi(hash(key)) % 1000) / 1000.0)
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.extra_cull_margin = float(row["width"]) * 0.5 * GROW_MAX
	view.set_meta("kind", kind)
	view.set_meta("at", at)
	view.set_meta("far", bool(row.get("far", false)))
	view.set_meta("near", row.get("near", Vector2(GONE_M, FULL_M)))
	add_child(view, true)
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
		for p in ["tint", "alpha", "foot", "crown", "rim_dark", "sway", "sway_hz", "rise", "grain", "puffs", "stutter"]:
			m.set_shader_parameter(p, row[p])
		m.set_shader_parameter("glow", row.get("glow", Color(0.0, 0.0, 0.0, 0.0)))
		_materials[kind] = m
	return _materials[kind]


static func grow(distance_m: float) -> float:
	return clampf(distance_m / GROW_FROM_M, 1.0, GROW_MAX)


static func pull(distance_m: float) -> float:
	return minf(1.0, PULL_M / maxf(distance_m, 0.001))


func fade_for(eye: Vector3) -> void:
	if leaving.is_empty() and eye.distance_squared_to(_last_eye) < EYE_STILL_M * EYE_STILL_M:
		return
	_last_eye = eye
	for key in views:
		_show(views[key], eye, 1.0)
	for view in leaving:
		_show(view, eye, float(view.get_meta("leave")))


static func _show(view: MeshInstance3D, eye: Vector3, keep: float) -> void:
	var at: Vector3 = view.get_meta("at")
	var distance := Vector2(at.x - eye.x, at.z - eye.z).length()
	var far: bool = view.get_meta("far")
	var share := near_alpha(distance, far, view.get_meta("near")) * keep
	view.visible = share > 0.0
	if far:
		var k := pull(distance)
		view.global_position = eye + (at - eye) * k
		view.scale = Vector3.ONE * k
	else:
		view.scale = Vector3.ONE * grow(distance)
	(view.material_override as ShaderMaterial).set_shader_parameter("near_alpha", share)


func leave(delta: float) -> void:
	for i in range(leaving.size() - 1, -1, -1):
		var view := leaving[i]
		var keep := float(view.get_meta("leave")) - delta / LEAVE_S
		if keep > 0.0:
			view.set_meta("leave", keep)
		else:
			view.queue_free()
			leaving.remove_at(i)


func _process(delta: float) -> void:
	if ctx == null:
		return
	_clock -= delta
	if _clock <= 0.0:
		_clock = READ_EVERY
		var root = ctx.get("root")
		var world: Node = root.get_node_or_null("World") if root != null else null
		var build = ctx.get("build")
		var list := sites(world, build.get("scrap") if build != null else null, ctx.get("terrain"))
		var furnace := _furnace_now()
		if not furnace.is_empty():
			list.append(furnace)
		sync(list, true)
	leave(delta)
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		fade_for(camera.global_position)


func _furnace_now() -> Dictionary:
	var flow = ctx.get("flow")
	var run = ctx.get("run")
	var stages = ctx.get("stages")
	if flow == null or run == null or stages == null or not flow.has_method("boss_row"):
		return {}
	var stage: int = run.stage
	var world_last: bool = stages.is_world_last(stage)
	var kind := ""
	if world_last and String(stages.BOSS) != "":
		var row: Dictionary = flow.boss_row(stages.world_of(stage))
		kind = String(row.get("kind", "")) if bool(row.get("built", false)) else ""
	var showing: bool = flow.state in [flow.STAGE, flow.BEACON, flow.GATES, flow.LAUNCH]
	if world_last and kind == FURNACE_BOSS and showing and int(_furnace[0]) != stage:
		_furnace = [stage, furnace_foot(ctx.get("terrain"), stage)]
	return furnace_site(world_last, kind, showing, _furnace[1] if int(_furnace[0]) == stage else null)
