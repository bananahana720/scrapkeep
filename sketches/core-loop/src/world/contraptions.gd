extends Node3D

const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Groups := preload("res://src/core/groups.gd")
const SteamCycle := preload("res://src/world/steam_cycle.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const Activities := preload("res://src/world/activities.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Interactables := preload("res://src/world/interactables.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")


class SluicePayDevice extends "res://src/world/device.gd":
	var owner_contraptions
	var valve_id := ""

	func _init() -> void:
		family = "ally"

	func build() -> void:
		pass

	func ready_now() -> bool:
		return owner_contraptions != null and is_instance_valid(owner_contraptions) \
			and bool(owner_contraptions.sluice_pay_read(valve_id)["can_pay"])

	func gauge() -> float:
		return float(owner_contraptions.sluice_pay_read(valve_id)["gauge"]) \
			if owner_contraptions != null and is_instance_valid(owner_contraptions) else -1.0

	func show_prompt(_targeted: bool) -> void:
		if prompt == null or _prompt_anchor == null:
			return
		_prompt_anchor.global_position = reach_point() + Vector3.UP * 2.2
		var info: Dictionary = owner_contraptions.sluice_pay_read(valve_id) \
			if owner_contraptions != null and is_instance_valid(owner_contraptions) else {"active": false}
		if not bool(info["active"]):
			prompt.set_interact("", "", "", -1.0)
			return
		var icon: String = Interactables.row(family)["icon"]
		prompt.set_interact(icon, "", "", float(info["gauge"]) if not bool(info["can_pay"]) else -1.0)

	func fire() -> bool:
		return owner_contraptions != null and is_instance_valid(owner_contraptions) \
			and owner_contraptions.pay_sluice(valve_id)


const GAUGE_REACH := 60.0
const RAM_REACH := 2.8
const SLAM_REACH := 4.5
const THERMAL_LIFT := 34.0
const THERMAL_GAP := 1.5
const WALL_REACH := 3.6
const WALL_SPEED := 8.0
const SURGE_WARN_S := 1.0
const SURGE_MIN_WARN := 0.6
const SURGE_LIVE_S := 0.6
const SURGE_DEFAULT_CHARGE := 12.0
const SURGE_DEFAULT_LENGTH := 24.0
const SURGE_DEFAULT_HALF_WIDTH := 4.5
const SURGE_REACH := 3.0
const SURGE_ENEMY_DAMAGE := 25.0
const SURGE_ENEMY_TOSS := 18.0
const SURGE_BALL_DAMAGE := 16.0
const SURGE_BALL_TOSS := 16.0
const SURGE_BALL_LIFT := 8.0
const SURGE_SOURCE := "works_surge"
const DOOR_SINK := 6.5
const DOOR_SECONDS := 0.6
const DOOR_MODEL := "res://assets/models/world_one/valve_door.glb"
const DOOR_MODEL_SIZE := Vector3(12.0, 6.0, 1.0)
const CABLE_REST := 1.0
const PUFF_SECONDS := 0.7
const KEEP_STATION := 4.0
const CINDER_REACH := 1.4
const GLAZE_FROM := 4.0
const GLAZE_GAP := 1.2
const CINDER_SHADER := preload("res://assets/materials/dig_stone/cinder.gdshader")
const CINDER_GRAIN := preload("res://assets/textures/packed-sand-floor.webp")

const SKIN_DIR := "res://assets/models/park/contraptions/"
const SKIN_META := "contraption_recipe"
const SKIN_ID_META := "contraption_id"
const SKINS := {
	"gauge": {"budget": "detail", "base": ["gauge"], "shells": ["gauge_detail1", "gauge_detail2"]},
	"geyser_vent": {"budget": "detail", "base": ["geyser_vent"], "shells": ["geyser_vent_detail1", "geyser_vent_detail2"]},
	"lift_platform": {"budget": "detail", "base": ["lift_platform"], "shells": ["lift_platform_detail1", "lift_platform_detail2"]},
	"cannon": {"budget": "landform", "base": ["cannon"], "shells": ["cannon_detail1", "cannon_detail2"]},
	"trebuchet": {"budget": "landform", "base": ["trebuchet"], "shells": ["trebuchet_detail1", "trebuchet_detail2"], "arm": ["trebuchet_arm"]},
	"barge": {"budget": "landform", "base": ["barge"], "shells": ["barge_detail1", "barge_detail2"]},
}
const STYLE_RECIPE := {"cannon": "cannon", "trebuchet": "trebuchet", "geyser": "geyser_vent"}
const SKIN_LIFT_RADIUS := 4.5
const LIFT_PROFILE := [Vector2(0.0, 0.5), Vector2(2.7, 0.5), Vector2(4.5, 0.2)]
const LIFT_SIDES := 32
const LIFT_PLATE_FLOOR := -0.5
const LIFT_REST_SINK := 0.45
const LIFT_DRUM_BELOW := 2.5
const LIFT_BAND := 0.35
const LIFT_BAND_EVERY := 2.5
const SKIN_BARGE_SIDE := 14.0
const PART_VIEW_END_M := 420.0
const DIAL_VIEW_END_M := 250.0
const PART_VIEW_MARGIN_M := 30.0

var map
var ground: Callable
var cruise := 14.0
var gravity := 26.0

const CABLE_HANG := 1.3
const CABLE_LAND_CLEAR := 1.05

var barges: Array[Dictionary] = []
var lifts: Array[Dictionary] = []
var launchers: Array[Dictionary] = []
var cables: Array[Dictionary] = []
var valves: Array[Dictionary] = []
var sluice_valves: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var thermals: Array[Dictionary] = []
var cinders: Array[Dictionary] = []
var glazes: Array[Dictionary] = []
var test_no_warn := false
var _cinder_mat: ShaderMaterial = null
var _cinder_glow := 0.0
var live := true

var _puffs: Array[Dictionary] = []
var _slams: Array[Vector3] = []
var _pending_facts: Array[Dictionary] = []
var _ctx: Variant = null
var _thermal_quiet := 0.0
var _glaze_quiet := 0.0
var _gauge_mat: Material
var _needle_mat: Material
var _rust_mat: Material
var _copper_mat: Material
var _ring_mat: Material
var _hook_mat: Material
var _steam_mat: Material
var _cache_rules
var _puff_rng := RandomNumberGenerator.new()
var _unbuilt: Array = []


func _init() -> void:
	_puff_rng.seed = 0x50FF


static func cable_hang(end_y: float, ground_y: float) -> float:
	return clampf(end_y - ground_y - CABLE_LAND_CLEAR, 0.0, CABLE_HANG)


func setup(map_ref, ground_ref: Callable, cruise_speed: float, g: float) -> void:
	begin(map_ref, ground_ref, cruise_speed, g)
	finish()


func begin(map_ref, ground_ref: Callable, cruise_speed: float, g: float) -> void:
	map = map_ref
	ground = ground_ref
	cruise = cruise_speed
	gravity = g
	name = "Contraptions"
	_gauge_mat = PaletteMaterials.solid(Palette.SAND)
	_needle_mat = PaletteMaterials.solid(Palette.CHARCOAL)
	_rust_mat = PaletteMaterials.solid(Palette.RUST)
	_copper_mat = PaletteMaterials.solid(Palette.COPPER)
	_ring_mat = PaletteMaterials.solid(Palette.AMBER, 0.8)
	_hook_mat = PaletteMaterials.solid(Palette.AMBER, 1.2)
	_steam_mat = PaletteMaterials.unshaded(Color(Palette.SAND, 0.55))
	_unbuilt = map.contraptions.duplicate()


func unbuilt() -> bool:
	return not _unbuilt.is_empty()


func build_next() -> void:
	if _unbuilt.is_empty():
		return
	var spec: Dictionary = _unbuilt.pop_front()
	match spec["kind"]:
		"barge":
			barges.append(_build_barge(spec))
		"lift":
			lifts.append(_build_lift(spec))
		"launcher":
			launchers.append(_build_launcher(spec))
		"cable":
			cables.append(_build_cable(spec))
		"valve":
			valves.append(_build_valve(spec))
		"sluice_valve":
			sluice_valves.append(_build_sluice_valve(spec))
		"cracked_wall":
			walls.append(_build_wall(spec))
		"thermal":
			thermals.append(_build_thermal(spec))
		"cinder":
			cinders.append(_build_cinder(spec))
		"glaze":
			glazes.append(_build_glaze(spec))


func finish() -> void:
	while unbuilt():
		build_next()
	_setup_caches()
	reset()


func _sealed() -> Array:
	return valves.filter(func(d): return d["spec"].has("cache")) + walls.filter(func(d): return sealed_wall(d["spec"]))


static func sealed_wall(spec: Dictionary) -> bool:
	return spec.get("cache") is Dictionary and spec["cache"].has("face")


func _setup_caches() -> void:
	if _sealed().is_empty():
		return
	var owner_node := get_parent()
	while owner_node != null and not "ctx" in owner_node:
		owner_node = owner_node.get_parent()
	if owner_node == null or owner_node.get("ctx") == null:
		return
	_cache_rules = Activities.new()
	_cache_rules.ctx = owner_node.get("ctx")
	_cache_rules.set_physics_process(false)
	add_child(_cache_rules)
	for d in _sealed():
		if d["spec"].has("codex"):
			_cache_rules.ctx.codex.declare(d["spec"]["codex"])


func reset() -> void:
	for b in barges:
		b["time"] = b["spec"]["offset"]
		b["last"] = Vector3.INF
		b["velocity"] = Vector3.ZERO
		_place_barge(b, Vector3.INF)
	for l in lifts:
		l["cycle"] = SteamCycle.new(SteamCycle.PERIODIC, l["spec"]["charge"], l["spec"]["offset"])
		l["cycle"].rise = l["spec"].get("rise_seconds", 0.85)
		_place_lift(l)
	for l in launchers:
		l["cycle"] = SteamCycle.new(SteamCycle.ON_DEMAND, l["spec"]["charge"], 0.0)
	for c in cables:
		c["rest"] = 0.0
	for v in valves:
		v["open"] = false
		v["sink"] = 0.0
		v["spin"] = 0.0
		v["door"].position = v["door_home"]
		v["wheel"].rotation.z = 0.0
		if v["plume"] != null:
			v["plume"].visible = false
	for s in sluice_valves:
		_reset_sluice_valve(s)
	_register_sluice_devices()
	for w in walls:
		w["broken"] = false
		w["body"].position = w["home"]
		w["body"].visible = true
	for d in _sealed():
		_seal_cache(d)
	_slams.clear()
	_pending_facts.clear()
	for p in _puffs:
		if is_instance_valid(p.get("node")):
			(p["node"] as Node).free()
	_puffs.clear()
	for child in get_children():
		if child is GPUParticles3D:
			child.free()
	_thermal_quiet = 0.0
	_glaze_quiet = 0.0
	if map.get_script().resource_path == "res://src/world/map_reach.gd":
		load("res://src/presentation/spillway_scenery.gd").dress_props(self)


func _seal_cache(d: Dictionary) -> void:
	if _cache_rules == null:
		return
	if is_instance_valid(d.get("cache_site")):
		d["cache_site"].free()
	d.erase("cache_site")
	if _cache_rules.ctx.terrain.map() != map:
		return
	var cache: Dictionary = d["spec"]["cache"]
	var room := {}
	if cache.has("face"):
		room["face"] = cache["face"]
	var s = _cache_rules._build("cracked_cache", cache["at"], room)
	s.wall.free()
	s.wall = null
	s.view.hide()
	s.set_meta("sealed", String(d["spec"]["id"]))
	d["cache_site"] = s


func _open_cache(d: Dictionary, at: Vector3, facts: Array) -> void:
	if _cache_rules == null or not d.has("cache_site"):
		return
	var s = d["cache_site"]
	_cache_rules._finish(s, s.pedestal)
	if d["spec"].has("codex"):
		facts.append({"kind": "codex", "id": d["spec"]["codex"]["id"], "at": at})


func note_slam(at: Vector3) -> void:
	_slams.append(at)


func bind_context(ctx_ref: Variant) -> void:
	_ctx = ctx_ref
	_register_sluice_devices()


func pay_sluice(id: String, run_ref: Variant = null) -> bool:
	if not _sluice_active():
		return false
	for s in sluice_valves:
		if String(s["spec"]["id"]) == id:
			return _try_pay_sluice(s, run_ref if run_ref != null else _ctx_field("run"), _pending_facts)
	return false


func sluice_state(id: String) -> Dictionary:
	for s in sluice_valves:
		if String(s["spec"]["id"]) == id:
			var h: Hazard = s["hazard"]
			var warn_vis := h != null and is_instance_valid(h) and h.state == Hazard.WARN and h.visible and h.painter() != null
			return {
				"state": String(s["state"]),
				"warn_elapsed": float(s["warn_elapsed"]),
				"warn_seconds": float(s["warn_seconds"]),
				"last_warn_visible_s": float(s["last_warn_visible_s"]),
				"charge_left": float(s["charge_left"]),
				"charges_fired": int(s["charges_fired"]),
				"times_paid": int(s["times_paid"]),
				"enemies_thrown": int(s["enemies_thrown"]),
				"ball_hits": int(s["ball_hits"]),
				"props_broken": int(s["props_broken"]),
				"warning_visible": warn_vis,
				"last_ball_toss": s["last_ball_toss"],
				"lane_front": h.lane_front if h != null and is_instance_valid(h) else -1.0,
				"device": s.get("device"),
			}
	return {}


func telegraphs(ball: Vector3) -> Array:
	var out: Array = []
	if not _sluice_active():
		return out
	for s in sluice_valves:
		if _delegated_to_grapple_sluice(String(s["spec"]["id"])):
			continue
		var h: Hazard = s["hazard"]
		if h != null and is_instance_valid(h) and not h.is_done():
			out.append({"id": h.get_instance_id(), "cause": SURGE_SOURCE, "covers": h.contains(ball)})
	return out


func _sluice_active() -> bool:
	return live and is_inside_tree() and is_visible_in_tree()


func _delegated_to_grapple_sluice(id: String) -> bool:
	var world_ref = _ctx_field("world")
	if world_ref == null or not is_instance_valid(world_ref):
		return false
	var flood_ref = world_ref.get("flood")
	if flood_ref == null or not is_instance_valid(flood_ref):
		return false
	var sv = flood_ref.get("sluice_valves")
	if sv == null or not is_instance_valid(sv) or not sv.has_method("valve_of"):
		return false
	return not (sv.valve_of(id) as Dictionary).is_empty()


func step(delta: float, ball: Vector3, velocity: Vector3, kit, riding: bool, steering := false) -> Array:
	var facts := []
	if not _pending_facts.is_empty():
		facts.append_array(_pending_facts)
		_pending_facts.clear()
	for b in barges:
		b["time"] += delta
		_place_barge(b, ball)
		var at: Vector3 = b["body"].global_position
		var v: Vector3 = (at - (b["last"] as Vector3)) / delta if b["last"] != Vector3.INF else Vector3.ZERO
		var a: Vector3 = (v - (b["velocity"] as Vector3)) / delta if b["last"] != Vector3.INF else Vector3.ZERO
		b["last"] = at
		b["velocity"] = v
		if on_barge(b, ball):
			var keep := Vector3.ZERO if steering else (v - velocity) * KEEP_STATION
			facts.append({"kind": "carry", "accel": a + keep})
	for l in lifts:
		var what: String = l["cycle"].step(delta)
		_place_lift(l)
		if what == "fired":
			var top: Vector3 = l["home"]
			facts.append({"kind": "fact", "fact": "lift_fired", "at": top})
			_puff(top + Vector3.UP * 0.5, 4.0)
		_needle(l["needle"], l["cycle"].gauge())
	var planar := Vector2(velocity.x, velocity.z).length()
	for l in launchers:
		var what: String = l["cycle"].step(delta)
		if what == "charging":
			facts.append({"kind": "fact", "fact": "launcher_charging", "at": l["mouth"]})
		_needle(l["needle"], l["cycle"].gauge())
		_launcher_pose(l)
		if riding or not _at_mouth(ball, l["mouth"], l["spec"]["radius"]):
			continue
		if l["cycle"].trigger():
			var spec: Dictionary = l["spec"]
			var ride = RideRail.arc(spec["style"], ball, spec["target"], planar, spec["floor"], spec["min_flight"], gravity)
			facts.append({"kind": "ride", "ride": ride})
			facts.append({"kind": "fact", "fact": String(spec["style"]) + "_fired", "at": l["mouth"]})
			_puff(l["mouth"] + Vector3.UP * 1.5, 6.0)
			riding = true
	for c in cables:
		c["rest"] = maxf(0.0, c["rest"] - delta)
		if riding or c["rest"] > 0.0 or ball.distance_to(c["from"]) > c["spec"]["radius"]:
			continue
		c["rest"] = CABLE_REST
		var end: Vector3 = c["to"]
		var hang := cable_hang(end.y, (ground.call(end.x, end.z, 0.0) as Vector3).y)
		var ride = RideRail.line("grapple_line", ball, end - Vector3.UP * hang, planar, c["spec"]["floor"])
		ride.cable_from = c["from"]
		ride.cable_to = c["to"]
		facts.append({"kind": "ride", "ride": ride})
		facts.append({"kind": "fact", "fact": "ride_grapple_line", "at": c["from"]})
		riding = true
	for v in valves:
		_step_valve(v, delta, ball, planar, facts)
	if not sluice_valves.is_empty():
		var motion := {"pos": ball, "vel": velocity, "planar": planar, "riding": riding}
		for s in sluice_valves:
			_step_sluice_valve(s, delta, motion, facts)
	for w in walls:
		_step_wall(w, ball, velocity, kit, facts)
	_thermal_quiet = maxf(0.0, _thermal_quiet - delta)
	for t in thermals:
		if kit == null or not kit.gliding:
			continue
		var base: Vector3 = t["base"]
		if Vector2(ball.x - base.x, ball.z - base.z).length() > t["spec"]["radius"] or ball.y < base.y or ball.y > base.y + t["spec"]["height"]:
			continue
		facts.append({"kind": "accel", "accel": Vector3.UP * THERMAL_LIFT})
		if _thermal_quiet <= 0.0:
			_thermal_quiet = THERMAL_GAP
			facts.append({"kind": "fact", "fact": "thermal_ride", "at": ball})
			facts.append({"kind": "codex", "id": "steam_thermal", "at": ball})
	if not riding:
		var glazed := false
		for g in glazes:
			if _on_glaze(g, ball, velocity):
				facts.append({"kind": "carry", "accel": Vector3(velocity.x, 0.0, velocity.z).normalized() * float(g["spec"]["push"])})
				glazed = true
				break
		if not glazed:
			_glaze_quiet = 0.0
		else:
			_glaze_quiet -= delta
			if _glaze_quiet <= 0.0:
				_glaze_quiet = GLAZE_GAP
				facts.append({"kind": "fact", "fact": "glaze_skim", "at": ball})
		for c in cinders:
			if _on_cinder(c, ball):
				facts.append({"kind": "drag", "accel": -Vector3(velocity.x, 0.0, velocity.z) * float(c["spec"]["drag"])})
				break
	_slams.clear()
	return facts


func set_cinder_glow(glow: float) -> void:
	if _cinder_mat == null or is_equal_approx(glow, _cinder_glow):
		return
	_cinder_glow = glow
	_cinder_mat.set_shader_parameter("glow", glow)


func steam(at: Vector3) -> void:
	_puff(at + Vector3.UP * 0.5, 2.5)


func _build_cinder(spec: Dictionary) -> Dictionary:
	if _cinder_mat == null:
		_cinder_mat = ShaderMaterial.new()
		_cinder_mat.shader = CINDER_SHADER
		_cinder_mat.set_shader_parameter("tex_grain", CINDER_GRAIN)
		_cinder_mat.set_shader_parameter("ember", Vector3(Palette.HAZARD.r, Palette.HAZARD.g, Palette.HAZARD.b))
	var mat := _cinder_mat
	var strips := []
	for s: Array in spec["strips"]:
		var yaw := deg_to_rad(float(s[2]))
		var along := Vector3(sin(yaw), 0.0, cos(yaw))
		var half := float(s[3]) * 0.5
		var a: Vector3 = ground.call(float(s[0]) - along.x * half, float(s[1]) - along.z * half, 0.0)
		var b: Vector3 = ground.call(float(s[0]) + along.x * half, float(s[1]) + along.z * half, 0.0)
		var band := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(float(s[4]) * 2.0, a.distance_to(b))
		band.mesh = plane
		band.material_override = mat
		var mid := (a + b) * 0.5 + Vector3.UP * 0.04
		var fwd := (b - a).normalized()
		var up := (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
		band.transform = Transform3D(Basis(up.cross(fwd).normalized(), up, fwd), mid)
		add_child(band)
		strips.append({"centre": Vector2(float(s[0]), float(s[1])), "along": Vector2(along.x, along.z), "half": half, "side": float(s[4])})
	return {"spec": spec, "strips": strips}


func _build_glaze(spec: Dictionary) -> Dictionary:
	var strips := []
	for s: Array in spec["strips"]:
		var yaw := deg_to_rad(float(s[2]))
		strips.append({"centre": Vector2(float(s[0]), float(s[1])), "along": Vector2(sin(yaw), cos(yaw)), "half": float(s[3]) * 0.5, "inner": float(s[4]), "outer": float(s[5])})
	if bool(spec.get("sheen", false)):
		_glaze_sheen(strips)
	return {"spec": spec, "strips": strips}


const SHEEN_STEP_M := 6.0
const SHEEN_ACROSS_M := 2.0
const SHEEN_LIFT := 0.06


func _glaze_sheen(strips: Array) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.25
	mat.metallic_specular = 0.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	for strip: Dictionary in strips:
		var along: Vector2 = strip["along"]
		var side := Vector2(along.y, -along.x)
		var half: float = strip["half"]
		var rows := maxi(1, ceili(half * 2.0 / SHEEN_STEP_M))
		var cols := maxi(1, ceili((float(strip["outer"]) - float(strip["inner"])) / SHEEN_ACROSS_M))
		for sign_v: float in [-1.0, 1.0]:
			for r in rows:
				for c in cols:
					var quad: Array[Vector3] = []
					for corner: Vector2 in [Vector2(r, c), Vector2(r + 1, c), Vector2(r + 1, c + 1), Vector2(r, c + 1)]:
						var u: float = -half + half * 2.0 * corner.x / rows
						var v: float = lerpf(float(strip["inner"]), float(strip["outer"]), corner.y / cols) * sign_v
						var p: Vector2 = strip["centre"] + along * u + side * v
						quad.append((ground.call(p.x, p.y, 0.0) as Vector3) + Vector3.UP * SHEEN_LIFT)
					st.set_color(Palette.VERDIGRIS.lightened(0.35) if r % 2 == 0 else Palette.VERDIGRIS)
					for tri: Array in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
						if (tri[1] - tri[0]).cross(tri[2] - tri[0]).y > 0.0:
							tri = [tri[0], tri[2], tri[1]]
						for p3: Vector3 in tri:
							st.add_vertex(p3)
	st.generate_normals()
	var band := MeshInstance3D.new()
	band.name = "GlazeSheen"
	band.mesh = st.commit()
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)


func _on_glaze(g: Dictionary, ball: Vector3, velocity: Vector3) -> bool:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < GLAZE_FROM or speed > float(g["spec"]["cap"]):
		return false
	if ball.y - ground.call(ball.x, ball.z, 0.0).y > CINDER_REACH:
		return false
	var p := Vector2(ball.x, ball.z)
	for s: Dictionary in g["strips"]:
		var rel: Vector2 = p - s["centre"]
		var v := absf(rel.dot(Vector2(s["along"].y, -s["along"].x)))
		if absf(rel.dot(s["along"])) <= s["half"] and v >= s["inner"] and v <= s["outer"]:
			return true
	return false


func _on_cinder(c: Dictionary, ball: Vector3) -> bool:
	var floor_y: float = ground.call(ball.x, ball.z, 0.0).y
	if ball.y - floor_y > CINDER_REACH:
		return false
	var p := Vector2(ball.x, ball.z)
	for s: Dictionary in c["strips"]:
		var rel: Vector2 = p - s["centre"]
		var u: float = rel.dot(s["along"])
		var v: float = rel.dot(Vector2(s["along"].y, -s["along"].x))
		if absf(u) <= s["half"] and absf(v) <= s["side"]:
			return true
	return false


func _process(delta: float) -> void:
	for p in _puffs.duplicate():
		p["left"] -= delta
		var node = p.get("node")
		if node == null or not is_instance_valid(node):
			_puffs.erase(p)
			continue
		var f: float = clampf(1.0 - p["left"] / PUFF_SECONDS, 0.0, 1.0)
		node.scale = Vector3.ONE * lerpf(0.4, 1.15, f) * p["size"]
		node.position.y += delta * 3.0
		node.transparency = clampf(f * f, 0.0, 1.0)
		if p["left"] <= 0.0:
			node.queue_free()
			_puffs.erase(p)
	for v in valves:
		var plume = v.get("plume")
		if plume != null and is_instance_valid(plume) and plume.visible:
			plume.rotate_y(delta * 0.8)
	for s in sluice_valves:
		var wheel = s.get("wheel")
		if (s["state"] == "warning" or s["state"] == "surging") and wheel != null and is_instance_valid(wheel):
			(wheel as Node3D).rotation.z += delta * 4.0


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or is_visible_in_tree():
		return
	for s in sluice_valves:
		if s["state"] == "warning" or s["state"] == "surging":
			_enter_sluice_charge(s)


func _exit_tree() -> void:
	for s in sluice_valves:
		_drop_sluice_hazard(s)
		var dev = s.get("device")
		if dev != null and is_instance_valid(dev) and dev.system != null and is_instance_valid(dev.system) and dev.system.has_method("unregister"):
			dev.system.unregister(dev)
			dev.system = null
		s["device"] = null


static func _at_mouth(ball: Vector3, mouth: Vector3, radius: float) -> bool:
	return Vector2(ball.x - mouth.x, ball.z - mouth.z).length() <= radius and absf(ball.y - mouth.y) < 3.0


static func _recipe_of(spec: Dictionary) -> String:
	return String(spec.get("recipe", ""))


static func _skin_views(spec: Dictionary, recipe: String, parent: Node3D, xform: Transform3D, part := "base", shells := true) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var row: Dictionary = SKINS.get(recipe, {})
	if row.is_empty() or not row.has(part):
		return out
	var files: Array = []
	for file: String in row[part]:
		files.append([file, 0])
	if shells:
		for file: String in row["shells"]:
			files.append([file, files.size() - row[part].size() + 1])
	for entry: Array in files:
		if not ResourceLoader.exists(SKIN_DIR + String(entry[0]) + ".glb"):
			push_warning("contraptions: %s missing, %s draws its primitive" % [entry[0], spec.get("id", "")])
			return out
	var ranges := ParkRecipes.ranges(String(row["budget"]))
	for entry: Array in files:
		var packed := load(SKIN_DIR + String(entry[0]) + ".glb") as PackedScene
		if packed == null:
			continue
		var scene := packed.instantiate()
		for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if source.mesh == null:
				continue
			var view := MeshInstance3D.new()
			view.name = "Skin_%s_%s" % [recipe, source.name]
			view.mesh = source.mesh
			for i in source.mesh.get_surface_count():
				var original := source.mesh.surface_get_material(i)
				var material := RecipeProps.slot_material(String(original.resource_name) if original != null else "")
				if material != null:
					view.set_surface_override_material(i, material)
			view.set_meta(SKIN_META, recipe)
			view.set_meta(SKIN_ID_META, String(spec.get("id", "")))
			view.set_meta(RecipeProps.META_FADE, true)
			parent.add_child(view)
			view.transform = xform * _node_in(source, scene)
			var shell_index: int = int(entry[1])
			if shell_index == 0:
				view.visibility_range_end = float(ranges.get("base_end", 0.0))
				view.visibility_range_end_margin = float(ranges.get("base_margin", 0.0))
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				var shell_ranges: Array = ranges.get("shells", [])
				var sr: Array = shell_ranges[shell_index - 1] if shell_index - 1 < shell_ranges.size() else [0.0, 0.0]
				view.visibility_range_end = float(sr[0])
				view.visibility_range_end_margin = float(sr[1])
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			out.append(view)
		scene.free()
	return out


static func _node_in(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


static func _aim_basis(aim: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(aim.x, aim.z))


static func _range_part(view: GeometryInstance3D, end_m := PART_VIEW_END_M) -> void:
	if view == null or view.visibility_range_end > 0.0:
		return
	view.visibility_range_end = end_m
	view.visibility_range_end_margin = PART_VIEW_MARGIN_M
	view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func _range_tree(root: Node, end_m := PART_VIEW_END_M) -> void:
	if root == null:
		return
	if root is GeometryInstance3D:
		_range_part(root as GeometryInstance3D, end_m)
	for child in root.get_children():
		_range_tree(child, end_m)


func _build_barge(spec: Dictionary) -> Dictionary:
	var body := AnimatableBody3D.new()
	body.name = spec["id"]
	body.sync_to_physics = true
	var size: Vector3 = spec["size"]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var deck := MeshInstance3D.new()
	body.add_child(deck)
	var floor_at := Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5 - 1.0, 0.0))
	var skin_at := Transform3D(Basis.from_scale(Vector3(size.x / SKIN_BARGE_SIDE, 1.0, size.z / SKIN_BARGE_SIDE)), floor_at.origin)
	if _recipe_of(spec) == "barge" and not _skin_views(spec, "barge", deck, skin_at).is_empty():
		pass
	elif RecipeProps.base("barge", deck, floor_at).is_empty():
		deck.mesh = PropMeshes.barge_hull(size)
		deck.material_override = PropMeshes.weathered_material(Palette.SANDSTONE, 0.78, 0.18, 0.0, "barge_hull")
	else:
		RecipeProps.shells("barge", deck, floor_at)
	add_child(body)
	return {"spec": spec, "body": body, "deck": deck, "time": 0.0, "tilt": Vector2.ZERO, "last": Vector3.INF, "velocity": Vector3.ZERO}


func on_barge(b: Dictionary, ball: Vector3) -> bool:
	var body: AnimatableBody3D = b["body"]
	var size: Vector3 = b["spec"]["size"]
	var local := ball - body.global_position
	return absf(local.x) <= size.x * 0.5 + 0.5 and absf(local.z) <= size.z * 0.5 + 0.5 \
		and local.y > size.y * 0.5 and local.y < size.y * 0.5 + 1.8


static func barge_offset(spec: Dictionary, t: float) -> float:
	var travel: float = spec["travel"]
	var dwell: float = spec["dwell"]
	var period := 2.0 * (travel + dwell)
	var s := fposmod(t, period)
	if s < dwell:
		return 0.0
	if s < dwell + travel:
		return smoothstep(0.0, 1.0, (s - dwell) / travel)
	if s < 2.0 * dwell + travel:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (s - 2.0 * dwell - travel) / travel)


const BARGE_TILT := 3.0


static func barge_tilt(local: Vector3, size: Vector3) -> Vector2:
	var fx := clampf(local.x / (size.x * 0.5), -1.0, 1.0)
	var fz := clampf(local.z / (size.z * 0.5), -1.0, 1.0)
	return Vector2(fz, -fx) * deg_to_rad(BARGE_TILT)


func _place_barge(b: Dictionary, ball: Vector3) -> void:
	var spec: Dictionary = b["spec"]
	var at: Vector3 = (spec["a"] as Vector3).lerp(spec["b"], barge_offset(spec, b["time"]))
	var size: Vector3 = spec["size"]
	var target := Vector2.ZERO
	if ball != Vector3.INF:
		var local: Vector3 = ball - ((get_parent() as Node3D).global_position + at)
		if absf(local.x) < size.x * 0.5 and absf(local.z) < size.z * 0.5 and local.y > 0.0 and local.y < size.y + 2.5:
			target = barge_tilt(local, size)
	b["tilt"] = (b["tilt"] as Vector2).lerp(target, 0.05)
	var tilt: Vector2 = b["tilt"]
	var body: AnimatableBody3D = b["body"]
	body.transform = Transform3D(Basis.IDENTITY, at)
	(b["deck"] as MeshInstance3D).basis = Basis.from_euler(Vector3(tilt.x, 0.0, tilt.y))


func barge_position(index: int) -> Vector3:
	return barges[index]["body"].global_position


func _build_lift(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var foot: Vector3 = ground.call(at.x, at.y, 0.0)
	var body := AnimatableBody3D.new()
	body.name = spec["id"]
	body.sync_to_physics = true
	var skin_scale: float = float(spec["radius"]) / SKIN_LIFT_RADIUS
	var outline: Array[Vector2] = []
	for p: Vector2 in LIFT_PROFILE:
		outline.append(Vector2(p.x * skin_scale, p.y))
	var plate_points := PackedVector3Array()
	for p: Vector2 in outline + [Vector2(outline[outline.size() - 1].x, LIFT_PLATE_FLOOR)]:
		if p.x > 0.0:
			for k in LIFT_SIDES:
				var a := TAU * float(k) / float(LIFT_SIDES)
				plate_points.append(Vector3(p.x * cos(a), p.y, p.x * sin(a)))
	var plate_shape := CollisionShape3D.new()
	plate_shape.name = "Plate"
	var hull := ConvexPolygonShape3D.new()
	hull.points = plate_points
	plate_shape.shape = hull
	body.add_child(plate_shape)
	var drum_r: float = outline[outline.size() - 1].x
	var drum_top: float = outline[outline.size() - 1].y
	var drum_len := float(spec["rise"]) + LIFT_DRUM_BELOW - LIFT_REST_SINK + drum_top
	var drum := CollisionShape3D.new()
	drum.name = "Drum"
	var cyl := CylinderShape3D.new()
	cyl.radius = drum_r
	cyl.height = drum_len
	drum.shape = cyl
	drum.position = Vector3.UP * (drum_top - drum_len * 0.5)
	body.add_child(drum)
	var skinned := _recipe_of(spec) == "lift_platform" and not _skin_views(spec, "lift_platform", body,
		Transform3D(Basis.from_scale(Vector3(skin_scale, 1.0, skin_scale)), Vector3.ZERO)).is_empty()
	if not skinned:
		var plate := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lathe(st, outline)
		plate.mesh = st.commit()
		plate.material_override = PaletteMaterials.striped(Palette.COPPER, Palette.CHARCOAL)
		body.add_child(plate)
	body.add_child(_drum_view(drum_r, drum_top, drum_len))
	add_child(body)
	var home := foot + Vector3.DOWN * LIFT_REST_SINK
	var needle := _dial(foot + Vector3(float(spec["radius"]) + 1.6, 0.0, 0.0), spec)
	return {"spec": spec, "body": body, "home": home, "needle": needle, "cycle": null}


func _drum_view(r: float, top: float, length: float) -> Node3D:
	var copper := SurfaceTool.new()
	var charcoal := SurfaceTool.new()
	copper.begin(Mesh.PRIMITIVE_TRIANGLES)
	charcoal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := top
	var bottom := top - length
	_lathe(charcoal, [Vector2(r, y), Vector2(r, y - LIFT_BAND * 2.0)])
	y -= LIFT_BAND * 2.0
	while y > bottom:
		var y1 := maxf(y - (LIFT_BAND_EVERY - LIFT_BAND), bottom)
		_lathe(copper, [Vector2(r, y), Vector2(r, y1)])
		y = y1
		if y > bottom:
			y1 = maxf(y - LIFT_BAND, bottom)
			_lathe(charcoal, [Vector2(r, y), Vector2(r, y1)])
			y = y1
	var view := Node3D.new()
	view.name = "DrumView"
	for part: Array in [["Copper", copper, _copper_mat], ["Bands", charcoal, _needle_mat]]:
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = (part[1] as SurfaceTool).commit()
		mi.material_override = part[2]
		_range_part(mi)
		view.add_child(mi)
	return view


static func _lathe(st: SurfaceTool, outline: Array) -> void:
	for i in outline.size() - 1:
		var p0: Vector2 = outline[i]
		var p1: Vector2 = outline[i + 1]
		var tangent := p1 - p0
		if tangent.length() < 0.0001:
			continue
		var n := Vector2(-tangent.y, tangent.x).normalized()
		for k in LIFT_SIDES:
			var a0 := TAU * float(k) / float(LIFT_SIDES)
			var a1 := TAU * float(k + 1) / float(LIFT_SIDES)
			var quad := [Vector3(p0.x * cos(a0), p0.y, p0.x * sin(a0)), Vector3(p0.x * cos(a1), p0.y, p0.x * sin(a1)),
				Vector3(p1.x * cos(a1), p1.y, p1.x * sin(a1)), Vector3(p1.x * cos(a0), p1.y, p1.x * sin(a0))]
			var normals := [Vector3(n.x * cos(a0), n.y, n.x * sin(a0)), Vector3(n.x * cos(a1), n.y, n.x * sin(a1)),
				Vector3(n.x * cos(a1), n.y, n.x * sin(a1)), Vector3(n.x * cos(a0), n.y, n.x * sin(a0))]
			for j: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(normals[j])
				st.add_vertex(quad[j])


func _place_lift(l: Dictionary) -> void:
	var ext: float = l["cycle"].extension() if l["cycle"] != null else 0.0
	var body: AnimatableBody3D = l["body"]
	body.transform = Transform3D(Basis.IDENTITY, (l["home"] as Vector3) + Vector3.UP * float(l["spec"]["rise"]) * ext)


func lift_top(index: int) -> float:
	return lifts[index]["body"].global_position.y + 0.5


func _build_launcher(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var mouth: Vector3 = ground.call(at.x, at.y, 1.0)
	var root := Node3D.new()
	root.name = spec["id"]
	add_child(root)
	var ring := MeshInstance3D.new()
	ring.mesh = PropMeshes.launcher_mouth_ring(float(spec["radius"]))
	ring.material_override = _ring_mat
	ring.position = mouth + Vector3.DOWN * 0.8
	root.add_child(ring)
	var target: Vector3 = spec["target"]
	var aim := Vector3(target.x - mouth.x, 0.0, target.z - mouth.z).normalized()
	var arm: MeshInstance3D = null
	var style: String = spec["style"]
	var skin_xf := Transform3D(_aim_basis(aim), mouth)
	var skinned := false
	if STYLE_RECIPE.get(style, "") != "" and _recipe_of(spec) == STYLE_RECIPE[style]:
		skinned = not _skin_views(spec, _recipe_of(spec), root, skin_xf).is_empty()
	match spec["style"]:
		"cannon" when skinned:
			pass
		"trebuchet" when skinned:
			arm = MeshInstance3D.new()
			arm.name = "TrebuchetArm"
			arm.position = mouth - aim * 6.0 + Vector3.UP * 10.5
			root.add_child(arm)
			_skin_views(spec, "trebuchet", arm, Transform3D.IDENTITY, "arm", false)
		"geyser" when skinned:
			var steam := MeshInstance3D.new()
			steam.mesh = PropMeshes.fluted_plume_column(1.6, 2.4, 10.0)
			steam.material_override = _steam_mat
			steam.position = mouth + Vector3.UP * 4.0
			root.add_child(steam)
			arm = steam
		"cannon":
			var barrel := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 2.0
			bm.bottom_radius = 2.8
			bm.height = 8.0
			barrel.mesh = bm
			barrel.material_override = _rust_mat
			barrel.position = mouth - aim * 5.0 + Vector3.UP * 2.0
			barrel.basis = Basis.looking_at(aim + Vector3.UP * 0.9, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			root.add_child(barrel)
			arm = barrel
			var band := MeshInstance3D.new()
			band.mesh = PropMeshes.cannon_band_collar()
			band.material_override = _copper_mat
			band.position = barrel.position
			band.basis = barrel.basis
			root.add_child(band)
		"steam_lift":
			var plate := MeshInstance3D.new()
			plate.mesh = PropMeshes.thermal_grate(float(spec["radius"]) - 0.8)
			plate.material_override = PropMeshes.weathered_material(Palette.COPPER, 0.64, 0.42, 0.0, "steam_lift_plate")
			plate.position = mouth + Vector3.DOWN * 0.85
			root.add_child(plate)
			arm = MeshInstance3D.new()
			arm.mesh = PropMeshes.lift_piston()
			arm.scale = Vector3(1.2, 0.5, 1.2)
			arm.material_override = _copper_mat
			arm.position = mouth - aim * (float(spec["radius"]) + 1.5) + Vector3.UP * 2.0
			root.add_child(arm)
		"trebuchet":
			for side in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(1.0, 12.0, 1.0)
				post.mesh = pm
				post.material_override = _rust_mat
				post.position = mouth - aim * 6.0 + aim.cross(Vector3.UP) * side * 3.0 + Vector3.UP * 5.0
				root.add_child(post)
			arm = MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(1.0, 1.0, 20.0)
			arm.mesh = am
			arm.material_override = _copper_mat
			arm.position = mouth - aim * 6.0 + Vector3.UP * 10.5
			root.add_child(arm)
		"geyser":
			var column := MeshInstance3D.new()
			column.mesh = PropMeshes.fluted_plume_column(1.6, 2.4, 10.0)
			column.material_override = _steam_mat
			column.position = mouth + Vector3.UP * 4.0
			root.add_child(column)
			arm = column
	_range_tree(root)
	var needle := _dial(mouth + aim.cross(Vector3.UP) * (float(spec["radius"]) + 2.0) + Vector3.DOWN * 1.0, spec)
	return {"spec": spec, "root": root, "mouth": mouth, "aim": aim, "needle": needle, "arm": arm, "cycle": null}


func _launcher_pose(l: Dictionary) -> void:
	var arm: MeshInstance3D = l["arm"]
	if arm == null:
		return
	var g: float = l["cycle"].gauge()
	match l["spec"]["style"]:
		"trebuchet":
			var aim: Vector3 = l["aim"]
			arm.basis = Basis.looking_at(aim.rotated(aim.cross(Vector3.UP).normalized(), lerpf(-0.9, 0.7, g)), Vector3.UP)
		"geyser", "steam_lift":
			arm.scale = Vector3(1.0, lerpf(0.2, 1.3, g), 1.0)
		"cannon":
			arm.scale = Vector3(1.0 + 0.08 * g, 1.0 - 0.14 * g, 1.0 + 0.08 * g)


func _build_cable(spec: Dictionary) -> Dictionary:
	var from: Vector3 = spec["from"]
	var to: Vector3 = spec["to"]
	var cable := MeshInstance3D.new()
	cable.mesh = PropMeshes.grapple_cable_span(from.distance_to(to))
	cable.material_override = _needle_mat
	cable.position = (from + to) * 0.5
	cable.basis = Basis.looking_at((to - from).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	add_child(cable)
	var hook := MeshInstance3D.new()
	hook.mesh = PropMeshes.grapple_target_ring(float(spec["radius"]))
	hook.material_override = _hook_mat
	hook.position = from
	hook.basis = Basis.looking_at(Vector3(to.x - from.x, 0.0, to.z - from.z).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	_range_part(hook)
	add_child(hook)
	var shackle := MeshInstance3D.new()
	shackle.name = "GrappleShackle"
	shackle.mesh = PropMeshes.grapple_hook_anchor()
	shackle.material_override = PropMeshes.weathered_material(Palette.CHARCOAL.lightened(0.08), 0.56, 0.52, 0.0, "grapple_shackle")
	shackle.basis = Basis(Vector3.RIGHT, -PI * 0.5)
	shackle.position = shackle.basis * (Vector3.UP * (float(spec["radius"]) + 0.35))
	_range_part(shackle)
	hook.add_child(shackle)
	return {"spec": spec, "from": from, "to": to, "rest": 0.0}


func _build_valve(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var foot: Vector3 = ground.call(at.x, at.y, 0.0)
	var wheel := Node3D.new()
	wheel.name = String(spec["id"]) + "_wheel"
	wheel.position = foot + Vector3.UP * 1.6
	wheel.rotation.x = PI * 0.5
	add_child(wheel)
	for v in RecipeProps.base("valve_wheel", wheel, Transform3D.IDENTITY):
		_range_part(v)
	RecipeProps.shells("valve_wheel", wheel, Transform3D.IDENTITY)
	for v in RecipeProps.base("valve_wheel_mount", self, Transform3D(Basis.IDENTITY, foot)):
		_range_part(v)
	RecipeProps.shells("valve_wheel_mount", self, Transform3D(Basis.IDENTITY, foot))
	var d: Dictionary = spec["door"]
	var dat: Vector2 = d["at"]
	var door_foot: Vector3 = ground.call(dat.x, dat.y, 0.0)
	var size: Vector3 = d["size"]
	var door := StaticBody3D.new()
	door.name = String(spec["id"]) + "_door"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	door.add_child(shape)
	var view := ModelKit.part(DOOR_MODEL, ["ValveDoor"], "ValveDoor", door)
	if view != null:
		view.scale = size / DOOR_MODEL_SIZE
	else:
		var mesh := MeshInstance3D.new()
		mesh.mesh = PropMeshes.valve_door_slab(size)
		mesh.material_override = PropMeshes.weathered_material(Palette.COPPER, 0.68, 0.35, 0.0, "valve_door")
		door.add_child(mesh)
	door.position = door_foot + Vector3.UP * (size.y * 0.5 - 0.5)
	door.rotation.y = d["turn"]
	_range_tree(door)
	add_child(door)
	var plume: MeshInstance3D = null
	var vent = spec.get("vent")
	if vent != null:
		var vat: Vector2 = vent["at"]
		var vfoot: Vector3 = ground.call(vat.x, vat.y, 0.0)
		plume = MeshInstance3D.new()
		plume.mesh = PropMeshes.fluted_plume_column(1.4, 3.0, 18.0)
		plume.material_override = PaletteMaterials.unshaded(Color(Palette.ANCIENT, 0.35))
		plume.position = vfoot + Vector3.UP * 9.0
		plume.visible = false
		add_child(plume)
		_dashed_ring(vfoot + Vector3.UP * 0.1, vent["radius"])
	return {"spec": spec, "wheel": wheel, "door": door, "door_home": door.position, "plume": plume, "open": false,
		"sink": 0.0, "spin": 0.0, "at": wheel.position}


func _step_valve(v: Dictionary, delta: float, ball: Vector3, planar: float, facts: Array) -> void:
	if v["open"]:
		if float(v["spin"]) < 1.0:
			v["spin"] = minf(1.0, float(v["spin"]) + delta / 0.45)
			var u := 1.0 - pow(1.0 - float(v["spin"]), 3.0)
			v["wheel"].rotation.z = TAU * u
		if v["sink"] < 1.0:
			v["sink"] = minf(1.0, v["sink"] + delta / DOOR_SECONDS)
			v["door"].position = (v["door_home"] as Vector3) + Vector3.DOWN * DOOR_SINK * v["sink"]
		if v["sink"] >= 1.0 and _cache_rules != null and v.has("cache_site"):
			_cache_rules._watch_pickup(v["cache_site"], ball)
		return
	var at: Vector3 = v["at"]
	var smashed := planar >= cruise and Vector2(ball.x - at.x, ball.z - at.z).length() <= RAM_REACH and absf(ball.y - at.y) < 3.0
	for s in _slams:
		if s.distance_to(at) <= SLAM_REACH:
			smashed = true
	if not smashed:
		return
	v["open"] = true
	v["spin"] = 0.08
	v["wheel"].rotation.z = 0.5
	facts.append({"kind": "fact", "fact": "valve_smashed", "at": at})
	facts.append({"kind": "fact", "fact": "route_opened", "at": v["door_home"]})
	_open_cache(v, at, facts)
	_puff(at, 5.0)
	var vent = v["spec"].get("vent")
	if vent != null:
		v["plume"].visible = true
		var vat: Vector2 = vent["at"]
		facts.append({"kind": "fact", "fact": "reactor_vented", "at": v["plume"].position})
		if Vector2(ball.x, ball.z).distance_to(vat) > float(vent["radius"]):
			facts.append({"kind": "codex", "id": "do_not_open_until_clear", "at": at})


func _build_sluice_valve(spec: Dictionary) -> Dictionary:
	var id := String(spec["id"])
	var at_2d := _vec2_of(spec.get("at", Vector2.ZERO))
	var foot: Vector3 = ground.call(at_2d.x, at_2d.y, 0.0)
	var holder := Node3D.new()
	holder.name = id
	add_child(holder)
	var wheel := Node3D.new()
	wheel.name = id + "_wheel"
	wheel.position = foot + Vector3.UP * 1.6
	wheel.rotation.x = PI * 0.5
	holder.add_child(wheel)
	if RecipeProps.base("valve_wheel", wheel, Transform3D.IDENTITY).is_empty():
		var rim := MeshInstance3D.new()
		rim.mesh = PropMeshes.sluice_wheel()
		rim.position = Vector3(0.0, 0.38, 0.0)
		rim.material_override = PropMeshes.weathered_material(Palette.RUST, 0.68, 0.38, 0.0, "sluice_wheel", true, 2.2)
		wheel.add_child(rim)
	else:
		RecipeProps.shells("valve_wheel", wheel, Transform3D.IDENTITY)
	if RecipeProps.base("valve_wheel_mount", holder, Transform3D(Basis.IDENTITY, foot)).is_empty():
		var post := MeshInstance3D.new()
		post.mesh = PropMeshes.sluice_post()
		post.material_override = PropMeshes.weathered_material(Palette.COPPER, 0.62, 0.44, 0.0, "sluice_post", true, 2.2)
		post.position = foot + Vector3.UP * 0.8
		holder.add_child(post)
	else:
		RecipeProps.shells("valve_wheel_mount", holder, Transform3D(Basis.IDENTITY, foot))
	var lane: Dictionary = spec.get("lane", {})
	var from_2d := _vec2_of(lane.get("from", at_2d), at_2d)
	var lane_from: Vector3 = ground.call(from_2d.x, from_2d.y, 0.0)
	var dir := Vector3.FORWARD
	var length := SURGE_DEFAULT_LENGTH
	if lane.has("to"):
		var to_2d := _vec2_of(lane["to"], from_2d + Vector2(0.0, SURGE_DEFAULT_LENGTH))
		var span := to_2d - from_2d
		if span.length() > 0.01:
			dir = Vector3(span.x, 0.0, span.y).normalized()
			length = float(lane.get("length", span.length()))
	else:
		var dir_2d := _vec2_of(lane.get("dir", Vector2(0.0, 1.0)), Vector2(0.0, 1.0))
		if dir_2d.length() > 0.01:
			dir = Vector3(dir_2d.x, 0.0, dir_2d.y).normalized()
		length = float(lane.get("length", SURGE_DEFAULT_LENGTH))
	length = maxf(1.0, length)
	var half_width := maxf(0.5, float(lane.get("half_width", float(lane.get("width", SURGE_DEFAULT_HALF_WIDTH * 2.0)) * 0.5)))
	var reach := maxf(0.5, float(lane.get("reach", SURGE_REACH)))
	var charge := maxf(0.1, float(spec.get("charge", SURGE_DEFAULT_CHARGE)))
	var price := maxi(0, int(spec.get("price", 0)))
	var side := Vector3.UP.cross(dir).normalized()
	var needle := _dial(foot + side * 2.2, spec)
	var pay_ring: MeshInstance3D = null
	var pay_device: SluicePayDevice = null
	if price > 0:
		pay_ring = MeshInstance3D.new()
		pay_ring.name = id + "_pay_ring"
		pay_ring.mesh = PropMeshes.sluice_pay_ring()
		pay_ring.material_override = _ring_mat
		pay_ring.position = foot + Vector3.UP * 0.45
		holder.add_child(pay_ring)
		pay_device = SluicePayDevice.new()
		pay_device.owner_contraptions = self
		pay_device.valve_id = id
		pay_device.position = foot
		holder.add_child(pay_device)
		pay_device.setup(_resolve_ctx(), _resolve_interact(), {"id": id})
	_range_tree(holder)
	if not is_in_group(Groups.WORLD_TELEGRAPHS):
		add_to_group(Groups.WORLD_TELEGRAPHS)
	return {
		"spec": spec,
		"holder": holder,
		"wheel": wheel,
		"needle": needle,
		"pay_ring": pay_ring,
		"device": pay_device,
		"at": wheel.position,
		"lane_from": lane_from,
		"dir": dir,
		"length": length,
		"half_width": half_width,
		"reach": reach,
		"charge": charge,
		"price": price,
		"state": "ready",
		"charge_left": 0.0,
		"warn_elapsed": 0.0,
		"warn_seconds": SURGE_WARN_S,
		"last_warn_visible_s": 0.0,
		"hazard": null,
		"struck_enemies": {},
		"ball_hit": false,
		"props_broken_this_surge": false,
		"charges_fired": 0,
		"times_paid": 0,
		"enemies_thrown": 0,
		"ball_hits": 0,
		"props_broken": 0,
		"last_ball_toss": Vector3.ZERO,
	}


func _reset_sluice_valve(s: Dictionary) -> void:
	_drop_sluice_hazard(s)
	var charge: float = s["charge"]
	var offset: float = float(s["spec"].get("offset", charge))
	var ready := offset >= charge
	s["state"] = "ready" if ready else "charging"
	s["charge_left"] = 0.0 if ready else clampf(charge - offset, 0.0, charge)
	s["warn_elapsed"] = 0.0
	s["warn_seconds"] = maxf(SURGE_MIN_WARN, float(s["spec"].get("warn", SURGE_WARN_S)))
	s["last_warn_visible_s"] = 0.0
	s["struck_enemies"] = {}
	s["ball_hit"] = false
	s["props_broken_this_surge"] = false
	s["charges_fired"] = 0
	s["times_paid"] = 0
	s["enemies_thrown"] = 0
	s["ball_hits"] = 0
	s["props_broken"] = 0
	s["last_ball_toss"] = Vector3.ZERO
	(s["wheel"] as Node3D).rotation.z = 0.0
	_needle(s["needle"], 1.0 if ready else 1.0 - float(s["charge_left"]) / charge)
	if s["pay_ring"] != null:
		(s["pay_ring"] as MeshInstance3D).visible = ready


func _drop_sluice_hazard(s: Dictionary) -> void:
	var h = s.get("hazard")
	if h != null and is_instance_valid(h):
		h.finish()
		if h.is_in_group(Threat.GROUP):
			h.remove_from_group(Threat.GROUP)
		h.queue_free()
	s["hazard"] = null


func _try_pay_sluice(s: Dictionary, run_ref: Variant, facts: Array) -> bool:
	if not _sluice_active() or s["state"] != "ready" or _delegated_to_grapple_sluice(String(s["spec"]["id"])):
		return false
	var price: int = int(s["price"])
	if price <= 0:
		return false
	if run_ref == null or not run_ref.has_method("spend_scrap") or not bool(run_ref.spend_scrap(price)):
		return false
	return _arm_sluice(s, facts, true)


func _arm_sluice(s: Dictionary, facts: Array, paid: bool) -> bool:
	if s["state"] != "ready" or _delegated_to_grapple_sluice(String(s["spec"]["id"])):
		return false
	_drop_sluice_hazard(s)
	var h := Hazard.new()
	var g := ground
	h.ground = func(point: Vector3) -> float: return (g.call(point.x, point.z, 0.0) as Vector3).y
	var warn := 0.0
	if test_no_warn:
		h.warn_floor = 0.0001
		warn = 0.0001
	else:
		h.warn_floor = SURGE_MIN_WARN
		warn = maxf(SURGE_MIN_WARN, float(s["spec"].get("warn", SURGE_WARN_S)))
	h.commit_lane(SURGE_SOURCE + "_" + String(s["spec"]["id"]), Threat.Type.LANE,
		s["lane_from"], s["dir"], 0.0, float(s["length"]), float(s["half_width"]),
		float(s["reach"]), warn, SURGE_LIVE_S)
	add_child(h)
	s["hazard"] = h
	s["state"] = "warning"
	s["warn_elapsed"] = 0.0
	s["warn_seconds"] = h.warn_seconds
	s["struck_enemies"] = {}
	s["ball_hit"] = false
	s["props_broken_this_surge"] = false
	if paid:
		s["times_paid"] = int(s["times_paid"]) + 1
	if s["pay_ring"] != null:
		(s["pay_ring"] as MeshInstance3D).visible = false
	facts.append({"kind": "fact", "fact": "sluice_warning", "at": s["at"]})
	_puff(s["at"], 4.5)
	return true


func _step_sluice_valve(s: Dictionary, delta: float, motion: Dictionary, facts: Array) -> void:
	if _delegated_to_grapple_sluice(String(s["spec"]["id"])):
		_drop_sluice_hazard(s)
		var delegated_dev = s.get("device")
		if delegated_dev != null and is_instance_valid(delegated_dev) and delegated_dev.system != null \
				and is_instance_valid(delegated_dev.system) and delegated_dev.system.has_method("unregister"):
			delegated_dev.system.unregister(delegated_dev)
			delegated_dev.system = null
		s["device"] = null
		var ring = s.get("pay_ring")
		if ring != null and is_instance_valid(ring):
			(ring as MeshInstance3D).visible = false
		return
	var live_dev = s.get("device")
	if live_dev != null and is_instance_valid(live_dev) and live_dev.system == null:
		_register_sluice_device(s)
	var ball: Vector3 = motion["pos"]
	var planar: float = float(motion["planar"])
	match String(s["state"]):
		"ready":
			var at: Vector3 = s["at"]
			var flat_dist := Vector2(ball.x - at.x, ball.z - at.z).length()
			var rammed := planar >= cruise * Activities.RAM_MIN_PER_CRUISE and flat_dist <= RAM_REACH and absf(ball.y - at.y) < 3.0
			for slam_at in _slams:
				if slam_at.distance_to(at) <= SLAM_REACH:
					rammed = true
			if rammed:
				_arm_sluice(s, facts, false)
		"warning":
			var h = s.get("hazard")
			if h == null or not is_instance_valid(h):
				_enter_sluice_charge(s)
				return
			var age_before: float = float(h.age)
			var vis_before: bool = h.state == Hazard.WARN and h.visible and h.painter() != null
			h.step(delta)
			if vis_before:
				s["warn_elapsed"] = float(s["warn_elapsed"]) + minf(delta, maxf(0.0, h.warn_seconds - age_before))
			if h.state == Hazard.WARN:
				return
			s["last_warn_visible_s"] = float(s["warn_elapsed"])
			s["state"] = "surging"
			s["charges_fired"] = int(s["charges_fired"]) + 1
			facts.append({"kind": "fact", "fact": "sluice_open", "at": s["lane_from"]})
			var lane_from: Vector3 = s["lane_from"]
			var lane_dir: Vector3 = s["dir"]
			var lane_len: float = float(s["length"])
			_puff(lane_from + Vector3.UP * 1.2, 5.0)
			_puff(lane_from + lane_dir * (lane_len * 0.5) + Vector3.UP * 1.2, 4.0)
			if is_inside_tree():
				for frac in [0.1, 0.38, 0.68, 0.94]:
					var spot := lane_from + lane_dir * (lane_len * float(frac)) + Vector3.UP * 0.9
					FxLibrary.burst(self, "steam_puff", spot, 8, Color("e8efe9"))
					FxLibrary.burst(self, "slam_dust", spot, 6)
			_apply_surge(s, h, motion)
			if h.is_done():
				_enter_sluice_charge(s)
		"surging":
			var h: Hazard = s["hazard"]
			if h == null or not is_instance_valid(h):
				_enter_sluice_charge(s)
				return
			h.step(delta)
			if h.is_live():
				_apply_surge(s, h, motion)
			if h.is_done():
				_enter_sluice_charge(s)
		"charging":
			var left := maxf(0.0, float(s["charge_left"]) - delta)
			s["charge_left"] = left
			_needle(s["needle"], 1.0 - left / float(s["charge"]))
			if left <= 0.0:
				s["state"] = "ready"
				_needle(s["needle"], 1.0)
				if s["pay_ring"] != null:
					(s["pay_ring"] as MeshInstance3D).visible = true


func _enter_sluice_charge(s: Dictionary) -> void:
	_drop_sluice_hazard(s)
	s["state"] = "charging"
	s["charge_left"] = float(s["charge"])
	s["struck_enemies"] = {}
	s["ball_hit"] = false
	s["props_broken_this_surge"] = false
	_needle(s["needle"], 0.0)


func _apply_surge(s: Dictionary, h: Hazard, motion: Dictionary) -> void:
	var ball: Vector3 = motion["pos"]
	var velocity: Vector3 = motion["vel"]
	var planar: float = float(motion["planar"])
	var riding: bool = bool(motion["riding"])
	var dir: Vector3 = s["dir"]
	if not bool(s["props_broken_this_surge"]):
		s["props_broken_this_surge"] = true
		s["props_broken"] = int(s["props_broken"]) + _break_lane_props(h)
	var tree := get_tree() if is_inside_tree() else null
	if tree != null:
		var push := (dir + Vector3.UP * 0.35).normalized()
		var thrown := HazardHits.strike(tree, h.contains, SURGE_SOURCE, SURGE_ENEMY_DAMAGE, SURGE_ENEMY_TOSS,
			s["struck_enemies"], func(_p: Vector3) -> Vector3: return push)
		s["enemies_thrown"] = int(s["enemies_thrown"]) + thrown
	if bool(s["ball_hit"]) or riding or bool(_ctx_field("calm", false)):
		return
	if not h.contains(ball):
		return
	if SpeedTier.of(planar, cruise) >= SpeedTier.CRUISE:
		return
	s["ball_hit"] = true
	s["ball_hits"] = int(s["ball_hits"]) + 1
	var run_ref = _ctx_field("run")
	if run_ref != null and run_ref.has_method("damage"):
		run_ref.damage(SURGE_BALL_DAMAGE, SURGE_SOURCE)
	var toss := dir * SURGE_BALL_TOSS + Vector3.UP * SURGE_BALL_LIFT
	s["last_ball_toss"] = toss
	var player_ref = _ctx_field("player")
	if player_ref != null and player_ref.has_method("set_velocity_now"):
		player_ref.set_velocity_now(velocity + toss, SURGE_SOURCE)


func _break_lane_props(h: Hazard) -> int:
	var props = _ctx_field("destructibles")
	if props == null or not is_instance_valid(props) or not props.has_method("ids") or not props.has_method("on_blast"):
		return 0
	var run_ref = _ctx_field("run")
	var heft := int(run_ref.heft_class()) if run_ref != null and run_ref.has_method("heft_class") else -1
	var before: int = int(props.intact_count())
	for id: String in props.ids():
		if props.state_of(id) != "intact":
			continue
		var box: AABB = props.bounds_of(id)
		var centre := box.get_center()
		var foot := Vector3(centre.x, box.position.y + 0.1, centre.z)
		if h.contains(centre) or h.contains(foot):
			props.on_blast(centre, 0.25, SURGE_SOURCE, 1, heft)
	return maxi(0, before - int(props.intact_count()))


func _resolve_ctx() -> Variant:
	if _ctx != null:
		return _ctx
	var owner_node := get_parent()
	while owner_node != null and not "ctx" in owner_node:
		owner_node = owner_node.get_parent()
	if owner_node != null and owner_node.get("ctx") != null:
		_ctx = owner_node.get("ctx")
	return _ctx


func _ctx_field(key: String, fallback: Variant = null) -> Variant:
	var c: Variant = _resolve_ctx()
	if c == null:
		return fallback
	if c is Dictionary:
		return (c as Dictionary).get(key, fallback)
	if c is Object:
		var val: Variant = (c as Object).get(key)
		return fallback if val == null else val
	return fallback


func _sluice_by_id(id: String) -> Dictionary:
	for s in sluice_valves:
		if String(s["spec"]["id"]) == id:
			return s
	return {}


func sluice_pay_read(id: String) -> Dictionary:
	if _delegated_to_grapple_sluice(id):
		return {"active": false, "can_pay": false, "gauge": -1.0}
	var active := _sluice_active()
	var s := _sluice_by_id(id)
	if s.is_empty():
		return {"active": false, "can_pay": false, "gauge": -1.0}
	var price: int = int(s["price"])
	var run_ref = _ctx_field("run")
	var can_pay: bool = active and s["state"] == "ready" and price > 0 \
		and run_ref != null and run_ref.has_method("spend_scrap") and int(run_ref.get("scrap")) >= price
	var g := -1.0
	if s["state"] == "warning" or s["state"] == "surging":
		g = 0.0
	elif s["state"] == "charging":
		g = clampf(1.0 - float(s["charge_left"]) / float(s["charge"]), 0.0, 1.0)
	elif s["state"] == "ready" and price > 0 and run_ref != null:
		g = clampf(float(run_ref.get("scrap")) / float(price), 0.0, 1.0)
	return {"active": active, "can_pay": can_pay, "gauge": g}


func _resolve_interact() -> Variant:
	var direct = _ctx_field("interact")
	if direct != null and is_instance_valid(direct) and direct.has_method("register"):
		return direct
	var root_node = _ctx_field("root")
	if root_node is Node and is_instance_valid(root_node):
		var found := (root_node as Node).get_node_or_null("Interact")
		if found != null and found.has_method("register"):
			return found
	var walk := get_parent()
	while walk != null:
		var found := walk.get_node_or_null("Interact")
		if found != null and found.has_method("register"):
			return found
		walk = walk.get_parent()
	return null


func _register_sluice_devices() -> void:
	for s in sluice_valves:
		_register_sluice_device(s)


func _register_sluice_device(s: Dictionary) -> void:
	var dev: Node3D = s.get("device")
	if dev == null or not is_instance_valid(dev):
		return
	if _delegated_to_grapple_sluice(String(s["spec"]["id"])):
		if dev.system != null and is_instance_valid(dev.system) and dev.system.has_method("unregister"):
			dev.system.unregister(dev)
			dev.system = null
		if s.get("pay_ring") != null:
			(s["pay_ring"] as MeshInstance3D).visible = false
		return
	var interact = _resolve_interact()
	if interact == null or not is_instance_valid(interact) or not interact.has_method("register"):
		return
	if dev.system != null and dev.system != interact and is_instance_valid(dev.system) and dev.system.has_method("unregister"):
		dev.system.unregister(dev)
	dev.ctx = _resolve_ctx()
	dev.system = interact
	interact.register(dev)


static func _vec2_of(value: Variant, fallback := Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector3:
		return Vector2((value as Vector3).x, (value as Vector3).z)
	if value is Array:
		var a := value as Array
		if a.size() == 2:
			return Vector2(float(a[0]), float(a[1]))
		if a.size() >= 3:
			return Vector2(float(a[0]), float(a[2]))
	return fallback


func _build_wall(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var foot: Vector3 = ground.call(at.x, at.y, 0.0)
	var size: Vector3 = spec["size"]
	var body := StaticBody3D.new()
	body.name = spec["id"]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var panel := CrackedCache.model_part("CacheWall", body)
	if panel != null:
		var aabb := panel.mesh.get_aabb()
		var fit := size / aabb.size * Vector3(1.0, 1.0, 0.5)
		var back := CrackedCache.model_part("CacheWall", body)
		back.name = "CacheWallBack"
		for face in [[panel, 0.0], [back, PI]]:
			var turn := Basis(Vector3.UP, face[1])
			face[0].transform = Transform3D(turn * Basis.from_scale(fit), turn * (-aabb.get_center() * fit + Vector3(0.0, 0.0, size.z * 0.25)))
		body.position = foot + Vector3.UP * (size.y * 0.5 - 0.6)
		body.rotation.y = spec["turn"]
		_range_tree(body)
		add_child(body)
		return {"spec": spec, "body": body, "home": body.position, "broken": false}
	var mesh := MeshInstance3D.new()
	mesh.mesh = PropMeshes.cracked_wall_slab(size)
	mesh.material_override = PropMeshes.weathered_material(Palette.SANDSTONE, 0.84, 0.08, 0.0, "cracked_wall")
	body.add_child(mesh)
	for k in 3:
		var crack := MeshInstance3D.new()
		crack.mesh = PropMeshes.bevel_prop_box(Vector3(size.x * 0.7, 0.18, size.z + 0.1))
		crack.material_override = _needle_mat
		crack.position = Vector3(0.0, -1.5 + k * 1.4, 0.0)
		crack.rotation.z = 0.5 - k * 0.45
		body.add_child(crack)
	body.position = foot + Vector3.UP * (size.y * 0.5 - 0.6)
	body.rotation.y = spec["turn"]
	_range_tree(body)
	add_child(body)
	return {"spec": spec, "body": body, "home": body.position, "broken": false}


func _step_wall(w: Dictionary, ball: Vector3, velocity: Vector3, kit, facts: Array) -> void:
	if w["broken"]:
		if _cache_rules != null and w.has("cache_site"):
			_cache_rules._watch_pickup(w["cache_site"], ball)
		return
	if kit == null:
		return
	var flat := Vector2(velocity.x, velocity.z).length()
	if not kit.sprinting and not (w["spec"].get("break_at_cruise", false) and flat >= cruise * Activities.RAM_MIN_PER_CRUISE):
		return
	var body: StaticBody3D = w["body"]
	var centre: Vector3 = body.global_position
	var along: Vector3 = body.global_basis.z
	var rel := ball - centre
	var ahead := absf(rel.dot(along)) - float(w["spec"]["size"].z) * 0.5
	var side := absf(rel.dot(body.global_basis.x))
	if flat < WALL_SPEED or ahead > WALL_REACH + flat / 30.0 or side > float(w["spec"]["size"].x) * 0.5 + 1.0 or absf(rel.y) > 4.0:
		return
	w["broken"] = true
	body.position = (w["home"] as Vector3) + Vector3.DOWN * 400.0
	body.visible = false
	facts.append({"kind": "fact", "fact": "wall_crumbled", "at": centre})
	facts.append({"kind": "fact", "fact": "route_opened", "at": centre})
	if sealed_wall(w["spec"]):
		_open_cache(w, centre, facts)
	else:
		facts.append({"kind": "codex", "id": "sprint_through", "at": centre})
	for k in 5:
		_puff(centre + Vector3(_puff_rng.randf_range(-3.0, 3.0), _puff_rng.randf_range(-1.5, 2.0), _puff_rng.randf_range(-1.0, 1.0)), 2.5)


func _build_thermal(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var base: Vector3 = ground.call(at.x, at.y, 0.0)
	var column := MeshInstance3D.new()
	column.mesh = PropMeshes.fluted_plume_column(float(spec["radius"]) * 0.5, float(spec["radius"]) * 1.3, float(spec["height"]))
	column.material_override = PaletteMaterials.unshaded(Color(Palette.SAND, 0.12))
	column.position = base + Vector3.UP * float(spec["height"]) * 0.5
	add_child(column)
	var grate := MeshInstance3D.new()
	grate.mesh = PropMeshes.thermal_grate(float(spec["radius"]) * 0.6)
	grate.material_override = PropMeshes.weathered_material(Palette.COPPER, 0.64, 0.42, 0.0, "thermal_grate")
	grate.position = base + Vector3.UP * 0.1
	add_child(grate)
	return {"spec": spec, "base": base}


func _dial(at: Vector3, spec := {}) -> MeshInstance3D:
	if SKINS.has(_recipe_of(spec)) and not _skin_views(spec, "gauge", self, Transform3D(Basis.IDENTITY, at)).is_empty():
		var needle := MeshInstance3D.new()
		needle.mesh = PropMeshes.dial_needle()
		needle.material_override = _needle_mat
		needle.position = at + Vector3.UP * 3.4 + Vector3(0.0, 0.0, 0.12)
		_range_part(needle, DIAL_VIEW_END_M)
		add_child(needle)
		return needle
	var post := MeshInstance3D.new()
	post.mesh = PropMeshes.dial_post()
	post.material_override = PropMeshes.weathered_material(Palette.COPPER, 0.62, 0.44, 0.0, "dial_post")
	post.position = at + Vector3.UP * 1.5
	_range_part(post, DIAL_VIEW_END_M)
	add_child(post)
	var face := MeshInstance3D.new()
	face.mesh = PropMeshes.dial_bezel()
	face.material_override = PropMeshes.weathered_material(Palette.SAND.darkened(0.08), 0.78, 0.10, 0.0, "dial_face")
	face.position = at + Vector3.UP * 3.4
	face.rotation.x = PI * 0.5
	_range_part(face, DIAL_VIEW_END_M)
	add_child(face)
	var redline := MeshInstance3D.new()
	redline.mesh = PropMeshes.dial_redline()
	redline.material_override = _rust_mat
	redline.position = face.position + Vector3(0.58, 0.44, 0.1)
	redline.rotation.z = -0.8
	_range_part(redline, DIAL_VIEW_END_M)
	add_child(redline)
	var needle := MeshInstance3D.new()
	needle.mesh = PropMeshes.dial_needle()
	needle.material_override = _needle_mat
	needle.position = face.position + Vector3(0.0, 0.0, 0.12)
	_range_part(needle, DIAL_VIEW_END_M)
	add_child(needle)
	return needle


static func _needle(needle: MeshInstance3D, g: float) -> void:
	needle.rotation.z = -lerpf(-2.1, 2.1, clampf(g, 0.0, 1.0))


func _puff(at: Vector3, size: float) -> void:
	var node := MeshInstance3D.new()
	node.mesh = PropMeshes.steam_puff_cloud()
	node.material_override = _steam_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = to_local(at) if is_inside_tree() else at
	add_child(node)
	_puffs.append({"node": node, "left": PUFF_SECONDS, "size": size})
	if is_inside_tree():
		FxLibrary.burst(self, "steam_puff", at, 8)


func _dashed_ring(at: Vector3, radius: float) -> void:
	var dash_mesh := PropMeshes.vent_dash_segment(radius * TAU / 32.0)
	for k in 16:
		var a := TAU * k / 16.0
		var dash := MeshInstance3D.new()
		dash.mesh = dash_mesh
		dash.material_override = _gauge_mat
		dash.position = at + Vector3(cos(a), 0.0, sin(a)) * radius
		dash.rotation.y = -a
		_range_part(dash)
		add_child(dash)
