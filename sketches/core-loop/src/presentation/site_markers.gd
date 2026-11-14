extends Node3D

# Site markers (map audit unit 4, map standard point 1: "smaller signs mark caches and objectives, never a HUD arrow"):
# a thin smoke plume over each place worth a detour that has nothing tall of its own, so a player on the line can see
# it from a distance and choose to go. Three site kinds and the furnace's horizon column, told apart by shape and motion first and by shade second, so none
# borrows a pickup's glow, an enemy's paint or a colour-law row (LEGIBILITY section 1). One exemption: the furnace's
# glow is the bowl melt's own colour, near amber, because it is the bowl's light seen from afar; its place under a dark
# column on the horizon, not its hue, tells it from an offer:
#
# - cache: a rib cache still waiting (scrap_field.gd caches()). A keeper's brew fire: one pale wisp that leans and curls.
# - cage: a caged pilot not yet freed (rescue_site.gd). A smoke signal: pale puffs rising in an even beat.
# - rogue: the stage's rogue site while its machine still sleeps (world.gd rogue_plan). Works exhaust: a dark column
#   that chugs in puffs that drift off the beat, the rogue's old work cycle (STORY-MAP section 3).
# - crew: a Fleet crew home still standing (director.gd live_homes()), so a fork shows which branch holds the fight.
#   A work crew's steam: a squat column of quick, even puffs, lower than a cache's wisp and a cage's signal
#   (13 Nov 2026, "Give maps routes and life": a route with a fight on it reads from the fork).
# - furnace: Brindle's Slag Bowl, ahead of the world's last stage's exit gate where its launch lands (Arena.place_ahead).
#   A tall works column lit from below by the furnace (hand-overs audit T6, ruling cv: the next place is in view before
#   you leave). It is a horizon sign: it shows from the drop-in, so it has no far fade, and past PULL_M it is drawn
#   pulled in along the eye's ray and shrunk by the same share (landmark_impostor.gd's method), so it covers the pixels
#   it would at its true distance while staying inside the far plane. It stands from the stage's start until the launch.
#
# A plume fades out over LEAVE_S once its thing is done: the cache taken, the cage spent, the rogue woken (the rogue wakes
# 63 m out, where its plume is at full strength). Leaving the stage takes every plume down at once. Secrets (field finds) keep
# no sign by rule (activities.gd _dress_find), standing activities have their amber column, Signal caches their mast.
# Smoke is drawn, not simulated: one camera-facing quad a site with a shader, no particles and no light. It is a sign
# for the middle distance: gone inside GONE_M so it never stands over the thing it marks, full from FULL_M to
# FAR_FULL_M, and gone again by FAR_GONE_M, inside the chase camera's 700 m far plane.

const Shade := preload("res://src/presentation/site_markers.gdshader")
const Arena := preload("res://src/boss/arena.gd")
const Yard := preload("res://src/presentation/arena_bowl_yard.gd")

const CREW_SMOKE := Color("ece6d8")
const WORKS_SMOKE := Color("262826")
# The furnace's light on the foot of its column: the bowl's own melt at its working heat (arena_bowl_yard.gd MELT), on
# the gold side of MELT_MIN_HUE as the melt is, so it never reads as the live slag's or HAZARD's red-orange.
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
# The boss whose bowl stands a furnace column, by Worlds' boss kind.
const FURNACE_BOSS := "brindle"
# A far kind past this distance is drawn pulled in to it: chase_camera.gd's 700 m far plane, less the column's reach.
const PULL_M := 520.0
const GONE_M := 12.0
const FULL_M := 40.0
const FAR_FULL_M := 450.0
const FAR_GONE_M := 600.0
# Past GROW_FROM_M a plume grows with distance, up to GROW_MAX times its size, so it keeps the screen size it has at
# GROW_FROM_M for as long as it can: a sign, not scenery to scale (PC film of 79dcc01b: nothing read at 300 m).
const GROW_FROM_M := 130.0
const GROW_MAX := 2.5
# The site list is read four times a second; the fade follows the camera every frame it moves.
const READ_EVERY := 0.25
const LEAVE_S := 1.0
# An eye that moved less than this since the last fade changes no plume enough to redraw it.
const EYE_STILL_M := 0.25

var ctx
# key -> the plume's MeshInstance3D; each carries meta "kind".
var views := {}
# Plumes whose site is done, fading out; each carries meta "leave", its remaining share from 1 to 0.
var leaving: Array[MeshInstance3D] = []
var _clock := 0.0
var _last_eye := Vector3.INF
# The furnace column's foot for the stage it was read on: [stage, foot], foot null for none. Read once a stage.
var _furnace: Array = [0, null]
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
	_furnace = [0, null]
	_clock = 0.0


func _on_cleared(_reason: String) -> void:
	sync([])
	_clock = READ_EVERY


# The share of a plume's alpha it shows for an eye distance_m away (horizontal): the one rule for distance. A far kind
# has no far fade, and its own near fade (its row's "near", [gone, full]): the furnace has thinned out by the time the
# ball rolls up to the gate in front of it, so the stage's clear at the launch takes nothing still showing.
static func near_alpha(distance_m: float, far := false, near := Vector2(GONE_M, FULL_M)) -> float:
	var share := smoothstep(near.x, near.y, distance_m)
	return share if far else share * (1.0 - smoothstep(FAR_FULL_M, FAR_GONE_M, distance_m))


# The furnace column's site while it stands, else {}: on the last stage of a world whose boss is FURNACE_BOSS, from the
# stage's start until its launch, at the foot of the bowl the launch lands in. boss_kind is the boss that will run after
# the stage ("" when the table runs none or its row is not built), showing tells whether the run is still on the stage
# (not in the boss, the summary or a menu), foot is the ground under the bowl's centre (furnace_foot).
static func furnace_site(world_last: bool, boss_kind: String, showing: bool, foot) -> Dictionary:
	if not world_last or boss_kind != FURNACE_BOSS or not showing or not foot is Vector3:
		return {}
	return {"key": "furnace", "kind": "furnace", "at": foot}


# The ground under the bowl Arena.place_ahead puts past stage's exit gate, or null when there is no terrain to read or
# the stage's map states no exit row: the bowl then falls back over the beacon, not ahead of a launch (arena.gd).
static func furnace_foot(terrain, stage: int):
	if terrain == null or not terrain.has_method("height") or not terrain.has_method("map_for"):
		return null
	var map = terrain.map_for(stage)
	if map == null or not map.has_method("handover") or not map.handover().has("exit"):
		return null
	var bowl: Vector3 = Arena.place_ahead(terrain, stage)
	return _ground(terrain, Vector3(bowl.x, 0.0, bowl.z))


# Every site that wants a plume now, as [{key, kind, at}] with at the plume's foot. world is the World node (its
# rescue's waiting() and its rogue_plan), scrap the build's scrap field (its caches(), each with the foot under its
# panel, which can be a deck over the baked ground), terrain answers height(x, z) for the rogue site; any may be null.
# rogue_plan is World's public plan var, read as is: world.gd is another unit's this wave.
static func sites(world, scrap, terrain) -> Array:
	var out := []
	if scrap != null and scrap.has_method("caches"):
		for c in scrap.caches():
			var item: Node3D = c["item"]
			if is_instance_valid(item):
				# Keyed by where it stands: two caches never share a spot, and the key carries no object id.
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


# Puts up a plume for each site in list that has none and takes down every plume whose site is gone: faded out over
# LEAVE_S when fade is true and the plume shows, else at once (with every plume still fading out).
func sync(list: Array, fade := false) -> void:
	var wanted := {}
	for s in list:
		wanted[s["key"]] = true
		if not views.has(s["key"]):
			views[s["key"]] = _plume(String(s["kind"]), s["at"], String(s["key"]))
			_last_eye = Vector3.INF
	for key in views.keys():
		if not wanted.has(key):
			var view: MeshInstance3D = views[key]
			views.erase(key)
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
	# Each plume owns a copy of its kind's material: per-instance shader uniforms overflow the project's global
	# buffer on the compatibility renderer, and a stage stands only a handful of plumes.
	var material: ShaderMaterial = _material(kind).duplicate()
	material.set_shader_parameter("near_alpha", 0.0)
	material.set_shader_parameter("seed", float(absi(hash(key)) % 1000) / 1000.0)
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quad turns about its axis in the shader, so its bounds must cover the turn at its largest.
	view.extra_cull_margin = float(row["width"]) * 0.5 * GROW_MAX
	view.set_meta("kind", kind)
	view.set_meta("at", at)
	view.set_meta("far", bool(row.get("far", false)))
	view.set_meta("near", row.get("near", Vector2(GONE_M, FULL_M)))
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
		for p in ["tint", "alpha", "foot", "crown", "rim_dark", "sway", "sway_hz", "rise", "grain", "puffs", "stutter"]:
			m.set_shader_parameter(p, row[p])
		m.set_shader_parameter("glow", row.get("glow", Color(0.0, 0.0, 0.0, 0.0)))
		_materials[kind] = m
	return _materials[kind]


# The scale a plume takes for an eye distance_m away (horizontal): 1 near, growing past GROW_FROM_M to GROW_MAX.
static func grow(distance_m: float) -> float:
	return clampf(distance_m / GROW_FROM_M, 1.0, GROW_MAX)


# The share a far kind is drawn at for an eye distance_m away (horizontal): 1 inside PULL_M, then PULL_M / distance, so
# it is drawn at PULL_M along the eye's ray at the size that covers the same pixels.
static func pull(distance_m: float) -> float:
	return minf(1.0, PULL_M / maxf(distance_m, 0.001))


# Each plume's shown share and size for an eye; a plume with nothing to show is hidden, so it costs no draw. An eye
# that has not moved since the last call changes nothing, unless a plume is fading out.
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


# Runs each leaving plume's share down by delta / LEAVE_S and frees the ones that reach 0.
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


# The furnace column's site for the run's stage now (furnace_site), reading the bowl's foot once a stage.
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
