extends Node3D

const Palette := preload("res://src/core/palette.gd")
const SteamCycle := preload("res://src/world/steam_cycle.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const Activities := preload("res://src/world/activities.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")

# The gorge's contraptions, built from the map's specs and run from world's physics
# tick (DESIGN-V2 section 9, VISUAL-LANGUAGE section 11). Every one is a momentum tool
# you ride, never a stop: a launcher that is not ready lets you roll through, a lift
# you are not on never holds you, and a door only stands where a valve opens it.
# Each shows its cycle on a bone gauge whose needle sweeps linearly, puffs steam at the
# fire moment, and reports a world fact with its own sound.
#
# step() returns facts for world to publish or apply:
#   {"kind": "ride", "ride": RideRail}           hold the ball to this rail
#   {"kind": "fact", "fact": String, "at": Vector3}   a WORLD_ROWS kind
#   {"kind": "codex", "id": String, "at": Vector3}
#   {"kind": "accel", "accel": Vector3}           a push to add this tick (a thermal)
#   {"kind": "carry", "accel": Vector3}           the barge under the ball accelerating
#   {"kind": "drag", "accel": Vector3}            a cinder floor slowing a ball that rolls on it
#   {"kind": "carry", "accel": Vector3}           also a glazed wall band speeding a ball that carves it

const GAUGE_REACH := 60.0
const RAM_REACH := 2.8
const SLAM_REACH := 4.5
const THERMAL_LIFT := 34.0
const THERMAL_GAP := 1.5
const WALL_REACH := 3.6
const WALL_SPEED := 8.0
const DOOR_SINK := 6.5
const DOOR_SECONDS := 0.6
# The valve door model (tools/blender/world_one/valve_door.py), built 12 by 6 by 1 m and scaled to each door.
const DOOR_MODEL := "res://assets/models/world_one/valve_door.glb"
const DOOR_MODEL_SIZE := Vector3(12.0, 6.0, 1.0)
const CABLE_REST := 1.0
const PUFF_SECONDS := 0.7
# How hard a ball the player is not steering keeps station on a barge, per second of
# relative speed: the ball's own rolling resistance and drag act against the world,
# not the deck, and would otherwise let it creep aft (measured: 6.6 m per crossing).
const KEEP_STATION := 4.0
# A cinder floor (the sinkhole's "Wall pays", 2026-10-17): strips of loose cinder down the middle of a tube's floor take
# drag (share of planar speed per second) from a ball rolling on them. Only a ball within CINDER_REACH of the ground
# counts, so a ball carving the wall above the strip, or in the air, is never slowed.
const CINDER_REACH := 1.4
# A glazed wall (the same pass): the polish band up a tube's walls, ancient lava glass, pushes a ball carving it `push`
# m/s/s along its planar travel, from 4 m/s up to the spec's `cap`. With #61's wall grip, carving lost speed against the
# floor and every pilot's floor line beat its wall line by 3 to 18 s; the glaze is what makes the wall the fast line.
const GLAZE_FROM := 4.0
# The glaze's tell while it pushes: a glaze_skim fact (WORLD_ROWS: a pale wave and a skimming zip) on the first tick
# and every GLAZE_GAP seconds after, so the band reads and sounds like a slick surface, not an invisible hand.
const GLAZE_GAP := 1.2
const CINDER_SHADER := preload("res://assets/materials/dig_stone/cinder.gdshader")
const CINDER_GRAIN := preload("res://assets/textures/packed-sand-floor.webp")

# The park's contraption skins (design-v3/PARK.md section 4, KC9): a spec with a `recipe` key draws that recipe's GLBs in
# place of the code primitive; a spec without one, or whose GLBs are missing, draws the primitive it always drew. The
# skin changes the picture only: colliders, positions, cycles and gauges stay the code's. Each GLB wears the enamel slot
# (recipe_props.gd) and takes its visibility ranges from its budget class in assets/asset_budgets.json, as park_recipes.gd.
# Origins: the lift and barge at the body centre, a launcher at its mouth point, the gauge on the ground under its post.
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
# The recipe a launcher style wears; a spec naming another recipe for its style draws the primitive.
const STYLE_RECIPE := {"cannon": "cannon", "trebuchet": "trebuchet", "geyser": "geyser_vent"}
# The lift plate radius and the barge plan the GLBs are drawn at; the skin is scaled to the spec's radius and size in X and Z.
const SKIN_LIFT_RADIUS := 4.5
# A lift is a cap on a solid drum (wave 37 lift-drum), so nothing gets under a raised plate and a ball that meets a raised
# lift glances off a pillar. LIFT_PROFILE is the cap's top outline at SKIN_LIFT_RADIUS, (radius, height) about the body,
# scaled in X and Z with the skin: flat to 2.7, then 1 in 6 down to the rim at 4.5 (a ball crossing the plate at rest rolls
# over the rim). The drum is the last point's radius from its height down, flush with the rim: no part of the lift is wider
# than what is under it, so a sinking lift has no underside to come down on a ball. The cap reads by colour (the charcoal
# collar under the rim). The collider, the code's drawn plate and drum, and tools/blender/park/contraptions/lift_platform.py's
# skin all come from these numbers.
const LIFT_PROFILE := [Vector2(0.0, 0.5), Vector2(2.7, 0.5), Vector2(4.5, 0.2)]
const LIFT_SIDES := 32
# The plate collider reaches LIFT_PLATE_FLOOR under the body origin, inside the drum, as deep as the plate always was: a fast
# firing plate cannot carry a ball resting on it down through its cap into the drum in one tick.
const LIFT_PLATE_FLOOR := -0.5
# At rest the plate's top sits 0.05 m over the foot; at full rise the drum still reaches LIFT_DRUM_BELOW m under the foot.
const LIFT_REST_SINK := 0.45
const LIFT_DRUM_BELOW := 2.5
# The drawn drum's charcoal bands: LIFT_BAND m tall every LIFT_BAND_EVERY m, and a collar twice as tall under the rim.
const LIFT_BAND := 0.35
const LIFT_BAND_EVERY := 2.5
const SKIN_BARGE_SIDE := 14.0

var map
var ground: Callable
var cruise := 14.0
var gravity := 26.0

# How far under the cable the ball hangs while it rides (MOTION-SPEC cableway row): the held path ends here
# below the cable end, which leaves the ball centre 1.1 m over a 2.4 m landing end.
const CABLE_HANG := 1.3
# The ride never lands the ball centre closer than this to the ground under the cable end.
const CABLE_LAND_CLEAR := 1.05

var barges: Array[Dictionary] = []
var lifts: Array[Dictionary] = []
var launchers: Array[Dictionary] = []
var cables: Array[Dictionary] = []
var valves: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var thermals: Array[Dictionary] = []
var cinders: Array[Dictionary] = []
var glazes: Array[Dictionary] = []
# One material for every cinder band, so the glow lights the whole floor at once.
var _cinder_mat: ShaderMaterial = null
var _cinder_glow := 0.0
# False while a map's contraptions wait for a loop mode (the Spillway's return lift in
# v2): world neither steps nor shows them.
var live := true

var _puffs: Array[Dictionary] = []
var _slams: Array[Vector3] = []
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
# Specs begin() took that are not built yet.
var _unbuilt: Array = []


func _init() -> void:
	_puff_rng.seed = 0x50FF


# How far under its end the ride hangs: CABLE_HANG, less where the ground is close, so the landing centre
# stays CABLE_LAND_CLEAR over it (zero where the cable end itself is that close: today's target).
static func cable_hang(end_y: float, ground_y: float) -> float:
	return clampf(end_y - ground_y - CABLE_LAND_CLEAR, 0.0, CABLE_HANG)


func setup(map_ref, ground_ref: Callable, cruise_speed: float, g: float) -> void:
	begin(map_ref, ground_ref, cruise_speed, g)
	finish()


# The same build a piece at a time, so a park stage built ahead adds its devices over frames
# (world.gd): begin() takes the specs, build_next() builds one, finish() builds the rest in
# order and resets. The result is setup()'s.
func begin(map_ref, ground_ref: Callable, cruise_speed: float, g: float) -> void:
	map = map_ref
	ground = ground_ref
	cruise = cruise_speed
	gravity = g
	name = "Contraptions"
	_gauge_mat = Palette.solid(Palette.SAND)
	_needle_mat = Palette.solid(Palette.CHARCOAL)
	_rust_mat = Palette.solid(Palette.RUST)
	_copper_mat = Palette.solid(Palette.COPPER)
	_ring_mat = Palette.solid(Palette.AMBER, 0.8)
	_hook_mat = Palette.solid(Palette.AMBER, 1.2)
	_steam_mat = Palette.unshaded(Color(Palette.SAND, 0.55))
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


# World attaches this owner beneath a stage root. Only cache-bearing specs need the
# game's existing context; standalone contraption geometry keeps its four-argument API.
func _setup_caches() -> void:
	if not valves.any(func(v): return v["spec"].has("cache")):
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
	for v in valves:
		if v["spec"].has("cache") and v["spec"].has("codex"):
			_cache_rules.ctx.codex.declare(v["spec"]["codex"])


# Back to the stage start: cycles on their seeded offsets, doors shut, walls whole.
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
		v["door"].position = v["door_home"]
		v["wheel"].rotation.z = 0.0
		if _cache_rules != null and v["spec"].has("cache"):
			if is_instance_valid(v.get("cache_site")):
				v["cache_site"].free()
			v.erase("cache_site")
			# Activities builds on the active terrain. A parked zone must not put
			# its pocket's colliders on the currently active zone's ground.
			if _cache_rules.ctx.terrain.map() != map:
				continue
			var s = _cache_rules._build("cracked_cache", v["spec"]["cache"]["at"])
			# The valve's door is this pocket's face. Keep the cache's side walls,
			# pedestal, seeded part roll and pickup rule, without an activity prompt.
			s.wall.free()
			s.wall = null
			s.view.hide()
			v["cache_site"] = s
		if v["plume"] != null:
			v["plume"].visible = false
	for w in walls:
		w["broken"] = false
		w["body"].position = w["home"]
		w["body"].visible = true
	_slams.clear()
	_thermal_quiet = 0.0
	_glaze_quiet = 0.0
	# Cache side walls are rebuilt by reset; finish them along with this zone's devices.
	if map.get_script().resource_path == "res://src/world/map_reach.gd":
		load("res://src/presentation/spillway_scenery.gd").dress_props(self)


func note_slam(at: Vector3) -> void:
	_slams.append(at)


# One physics tick. riding is true while world already holds the ball to a rail.
func step(delta: float, ball: Vector3, velocity: Vector3, kit, riding: bool, steering := false) -> Array:
	var facts := []
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
		# The ball hangs HANG below the cable and rides it down; the line view draws the hanger up to the cable.
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


# The cinders' telegraph (world.gd _step_cinder, cinder_heat.gd): 0 cold, 1 at the end of the grace, an ember glow.
func set_cinder_glow(glow: float) -> void:
	if _cinder_mat == null or is_equal_approx(glow, _cinder_glow):
		return
	_cinder_glow = glow
	_cinder_mat.set_shader_parameter("glow", glow)


# A puff of steam where a hot ball leaves the cinders.
func steam(at: Vector3) -> void:
	_puff(at + Vector3.UP * 0.5, 2.5)


# A cinder spec's strips are [x, z, yaw_deg, length, half_width] on the ground; each draws as a dark grit band.
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


# A glaze spec's strips are [x, z, yaw_deg, length, inner, outer]: the band between inner and outer metres off the
# tube's centre line, both walls. The wash models draw it (tools/blender/park/sinkhole_tubes.py's polished band).
func _build_glaze(spec: Dictionary) -> Dictionary:
	var strips := []
	for s: Array in spec["strips"]:
		var yaw := deg_to_rad(float(s[2]))
		strips.append({"centre": Vector2(float(s[0]), float(s[1])), "along": Vector2(sin(yaw), cos(yaw)), "half": float(s[3]) * 0.5, "inner": float(s[4]), "outer": float(s[5])})
	return {"spec": spec, "strips": strips}


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
		var f: float = 1.0 - p["left"] / PUFF_SECONDS
		var node: MeshInstance3D = p["node"]
		node.scale = Vector3.ONE * lerpf(0.4, 1.0, f) * p["size"]
		node.position.y += delta * 3.0
		if p["left"] <= 0.0:
			node.queue_free()
			_puffs.erase(p)
	for v in valves:
		if v["plume"] != null and v["plume"].visible:
			v["plume"].rotate_y(delta * 0.8)


static func _at_mouth(ball: Vector3, mouth: Vector3, radius: float) -> bool:
	return Vector2(ball.x - mouth.x, ball.z - mouth.z).length() <= radius and absf(ball.y - mouth.y) < 3.0


# ---- Skins ----

static func _recipe_of(spec: Dictionary) -> String:
	return String(spec.get("recipe", ""))


# The views of the recipe's GLB files under parent at xform, named Skin_<recipe>_<node>, in the enamel slot, tagged with
# SKIN_META and SKIN_ID_META, with the budget class's visibility ranges (base_end for the base, the class's shell ranges for
# shells, the first file's shell range index by order). files names GLBs of the recipe row's `part` ("base", "arm") and
# shells the row's shell files. [] when any named file is missing, with nothing added, so the caller draws the primitive.
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


# Turns the GLB's +Z onto a launcher's aim.
static func _aim_basis(aim: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(aim.x, aim.z))


# ---- Barges ----

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
	# The deck node owns the barge's picture and its drawn lean (_place_barge); the recipe views ride it, the recipe
	# floor (y +1.0 at the GLB origin) on the collider top. The recipe's low wall has no collider: the ball can clip it.
	# The striped box stays only when the recipe's base GLBs are missing.
	var deck := MeshInstance3D.new()
	body.add_child(deck)
	var floor_at := Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5 - 1.0, 0.0))
	# A row that names the park barge skin draws it, scaled to the row's plan; every other row draws what it drew before.
	var skin_at := Transform3D(Basis.from_scale(Vector3(size.x / SKIN_BARGE_SIDE, 1.0, size.z / SKIN_BARGE_SIDE)), floor_at.origin)
	if _recipe_of(spec) == "barge" and not _skin_views(spec, "barge", deck, skin_at).is_empty():
		pass
	elif RecipeProps.base("barge", deck, floor_at).is_empty():
		var dm := BoxMesh.new()
		dm.size = size
		deck.mesh = dm
		deck.material_override = Palette.striped(Palette.SANDSTONE, Palette.CHARCOAL)
	else:
		RecipeProps.shells("barge", deck, floor_at)
	add_child(body)
	return {"spec": spec, "body": body, "deck": deck, "time": 0.0, "tilt": Vector2.ZERO, "last": Vector3.INF, "velocity": Vector3.ZERO}


# A ball resting on a deck rides it. A rolling sphere on a deck that accelerates lags
# it by 5/7 of the deck's change of speed and rolls off (measured: 42 m of drift over
# one crossing), so while the ball rests on a barge it is given the barge's own
# acceleration, which for a rolling sphere makes it keep station exactly. Once the
# ball leaves the deck, by rolling or jumping, it is on its own.
func on_barge(b: Dictionary, ball: Vector3) -> bool:
	var body: AnimatableBody3D = b["body"]
	var size: Vector3 = b["spec"]["size"]
	var local := ball - body.global_position
	return absf(local.x) <= size.x * 0.5 + 0.5 and absf(local.z) <= size.z * 0.5 + 0.5 \
		and local.y > size.y * 0.5 and local.y < size.y * 0.5 + 1.8


# Where a barge is at time t along its lane: dwell at a, travel, dwell at b, travel back.
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


# The scripted settle: a barge leans a few degrees toward the ball's weight, a pure
# function of where the ball sits on the deck, so a test can hold it to a number.
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
	# The lean is drawn, not simulated: a tilted collider would roll the ball off.
	(b["deck"] as MeshInstance3D).basis = Basis.from_euler(Vector3(tilt.x, 0.0, tilt.y))


func barge_position(index: int) -> Vector3:
	return barges[index]["body"].global_position


# ---- Lifts ----

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
	# The drum: the outline's last point, down to LIFT_DRUM_BELOW under the foot at full rise.
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
		plate.material_override = Palette.striped(Palette.COPPER, Palette.CHARCOAL)
		body.add_child(plate)
	body.add_child(_drum_view(drum_r, drum_top, drum_len))
	add_child(body)
	var home := foot + Vector3.DOWN * LIFT_REST_SINK
	var needle := _dial(foot + Vector3(float(spec["radius"]) + 1.6, 0.0, 0.0), spec)
	return {"spec": spec, "body": body, "home": home, "needle": needle, "cycle": null}


# The drum as drawn: copper, a charcoal collar under the plate and a charcoal band every LIFT_BAND_EVERY m, flush with the
# collider (two meshes, in the contraptions' own copper and charcoal materials).
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
		view.add_child(mi)
	return view


# Turns an outline of (radius, height) points, top to bottom, round the Y axis in LIFT_SIDES steps: flat across each outline
# segment, round the axis, faces out.
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


# ---- Launchers ----

func _build_launcher(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var mouth: Vector3 = ground.call(at.x, at.y, 1.0)
	var root := Node3D.new()
	root.name = spec["id"]
	add_child(root)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = float(spec["radius"]) - 0.6
	tm.outer_radius = spec["radius"]
	ring.mesh = tm
	ring.material_override = _ring_mat
	ring.position = mouth + Vector3.DOWN * 0.8
	root.add_child(ring)
	var target: Vector3 = spec["target"]
	var aim := Vector3(target.x - mouth.x, 0.0, target.z - mouth.z).normalized()
	var arm: MeshInstance3D = null
	# A row whose recipe is its style's skin draws the GLB where the primitives below would go. The amber ring stays code.
	var style: String = spec["style"]
	var skin_xf := Transform3D(_aim_basis(aim), mouth)
	var skinned := false
	if STYLE_RECIPE.get(style, "") != "" and _recipe_of(spec) == STYLE_RECIPE[style]:
		skinned = not _skin_views(spec, _recipe_of(spec), root, skin_xf).is_empty()
	match spec["style"]:
		"cannon" when skinned:
			pass
		"trebuchet" when skinned:
			# The arm is a pivot the code poses each step (_launcher_pose); its GLB hangs from the pivot.
			arm = MeshInstance3D.new()
			arm.name = "TrebuchetArm"
			arm.position = mouth - aim * 6.0 + Vector3.UP * 10.5
			root.add_child(arm)
			_skin_views(spec, "trebuchet", arm, Transform3D.IDENTITY, "arm", false)
		"geyser" when skinned:
			var steam := MeshInstance3D.new()
			var steam_mesh := CylinderMesh.new()
			steam_mesh.top_radius = 2.4
			steam_mesh.bottom_radius = 1.6
			steam_mesh.height = 10.0
			steam.mesh = steam_mesh
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
			var band := MeshInstance3D.new()
			var km := TorusMesh.new()
			km.inner_radius = 2.2
			km.outer_radius = 2.9
			band.mesh = km
			band.material_override = _copper_mat
			band.position = barrel.position
			band.basis = barrel.basis
			root.add_child(band)
		"steam_lift":
			# The v3 loop's return (map_spillway.gd): the gorge lift's striped plate and
			# copper piston, as a launcher that throws the ball back to the shelf.
			var plate := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = float(spec["radius"]) - 0.8
			pm.bottom_radius = float(spec["radius"]) - 0.8
			pm.height = 0.3
			plate.mesh = pm
			plate.material_override = Palette.striped(Palette.COPPER, Palette.CHARCOAL)
			plate.position = mouth + Vector3.DOWN * 0.85
			root.add_child(plate)
			arm = MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 1.2
			sm.bottom_radius = 1.2
			sm.height = 6.0
			arm.mesh = sm
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
			var cm := CylinderMesh.new()
			cm.top_radius = 2.4
			cm.bottom_radius = 1.6
			cm.height = 10.0
			column.mesh = cm
			column.material_override = _steam_mat
			column.position = mouth + Vector3.UP * 4.0
			root.add_child(column)
			arm = column
	var needle := _dial(mouth + aim.cross(Vector3.UP) * (float(spec["radius"]) + 2.0) + Vector3.DOWN * 1.0, spec)
	return {"spec": spec, "root": root, "mouth": mouth, "aim": aim, "needle": needle, "arm": arm, "cycle": null}


# The trebuchet's arm cocks back as it charges; the geyser's column swells.
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


# ---- The grapple line ----

func _build_cable(spec: Dictionary) -> Dictionary:
	var from: Vector3 = spec["from"]
	var to: Vector3 = spec["to"]
	var cable := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.18
	cm.height = from.distance_to(to)
	cable.mesh = cm
	cable.material_override = _needle_mat
	cable.position = (from + to) * 0.5
	cable.basis = Basis.looking_at((to - from).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	add_child(cable)
	var hook := MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = float(spec["radius"]) - 0.5
	hm.outer_radius = spec["radius"]
	hook.mesh = hm
	hook.material_override = _hook_mat
	hook.position = from
	hook.basis = Basis.looking_at(Vector3(to.x - from.x, 0.0, to.z - from.z).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	add_child(hook)
	return {"spec": spec, "from": from, "to": to, "rest": 0.0}


# ---- Valves ----

func _build_valve(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var foot: Vector3 = ground.call(at.x, at.y, 0.0)
	# The authored valve (RecipeProps rows valve_wheel and valve_wheel_mount): the wheel frame rides the
	# "wheel" handle that smash and reset turn; the mount frame's two views stand still at the foot, directly
	# under this node, so the valve keeps three children before its door and collider paths hold.
	var wheel := Node3D.new()
	wheel.name = String(spec["id"]) + "_wheel"
	wheel.position = foot + Vector3.UP * 1.6
	wheel.rotation.x = PI * 0.5
	add_child(wheel)
	RecipeProps.base("valve_wheel", wheel, Transform3D.IDENTITY)
	RecipeProps.shells("valve_wheel", wheel, Transform3D.IDENTITY)
	RecipeProps.base("valve_wheel_mount", self, Transform3D(Basis.IDENTITY, foot))
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
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		mesh.material_override = Palette.striped(Palette.COPPER, Palette.CHARCOAL)
		door.add_child(mesh)
	door.position = door_foot + Vector3.UP * (size.y * 0.5 - 0.5)
	door.rotation.y = d["turn"]
	add_child(door)
	var plume: MeshInstance3D = null
	var vent = spec.get("vent")
	if vent != null:
		var vat: Vector2 = vent["at"]
		var vfoot: Vector3 = ground.call(vat.x, vat.y, 0.0)
		plume = MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 3.0
		pm.bottom_radius = 1.4
		pm.height = 18.0
		plume.mesh = pm
		plume.material_override = Palette.unshaded(Color(Palette.ANCIENT, 0.35))
		plume.position = vfoot + Vector3.UP * 9.0
		plume.visible = false
		add_child(plume)
		_dashed_ring(vfoot + Vector3.UP * 0.1, vent["radius"])
	return {"spec": spec, "wheel": wheel, "door": door, "door_home": door.position, "plume": plume, "open": false,
		"sink": 0.0, "at": wheel.position}


func _step_valve(v: Dictionary, delta: float, ball: Vector3, planar: float, facts: Array) -> void:
	if v["open"]:
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
	v["wheel"].rotation.z = 0.8
	facts.append({"kind": "fact", "fact": "valve_smashed", "at": at})
	facts.append({"kind": "fact", "fact": "route_opened", "at": v["door_home"]})
	if _cache_rules != null and v.has("cache_site"):
		var s = v["cache_site"]
		_cache_rules._finish(s, s.pedestal)
		if v["spec"].has("codex"):
			facts.append({"kind": "codex", "id": v["spec"]["codex"]["id"], "at": at})
	_puff(at, 5.0)
	var vent = v["spec"].get("vent")
	if vent != null:
		v["plume"].visible = true
		var vat: Vector2 = vent["at"]
		facts.append({"kind": "fact", "fact": "reactor_vented", "at": v["plume"].position})
		if Vector2(ball.x, ball.z).distance_to(vat) > float(vent["radius"]):
			facts.append({"kind": "codex", "id": "do_not_open_until_clear", "at": at})


# ---- The cracked wall (Rivet) ----

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
	# Two of the cracked cache's fracture panels (CrackedCache: a slab with its charcoal fault line) back to
	# back, each fitted to half the collider's depth, so the wall reads cracked from either approach; the
	# striped box with three cracks stays as the fallback.
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
		add_child(body)
		return {"spec": spec, "body": body, "home": body.position, "broken": false}
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = Palette.striped(Palette.SANDSTONE, Palette.VERDIGRIS)
	body.add_child(mesh)
	for k in 3:
		var crack := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(size.x * 0.7, 0.18, size.z + 0.1)
		crack.mesh = cm
		crack.material_override = _needle_mat
		crack.position = Vector3(0.0, -1.5 + k * 1.4, 0.0)
		crack.rotation.z = 0.5 - k * 0.45
		body.add_child(crack)
	body.position = foot + Vector3.UP * (size.y * 0.5 - 0.6)
	body.rotation.y = spec["turn"]
	add_child(body)
	return {"spec": spec, "body": body, "home": body.position, "broken": false}


# Only Rivet's overdrive sprint crumbles it, the tick before contact, so the ball never
# meets it as a wall. Anyone else meets a plain wall, which they can see. A wall whose
# spec sets "break_at_cruise" crumbles for any ball at 0.85 x cruise or faster (the cracked face's
# bar, Activities.RAM_MIN_PER_CRUISE, so a held roll at full speed counts).
func _step_wall(w: Dictionary, ball: Vector3, velocity: Vector3, kit, facts: Array) -> void:
	if w["broken"] or kit == null:
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
	facts.append({"kind": "codex", "id": "sprint_through", "at": centre})
	for k in 5:
		_puff(centre + Vector3(_puff_rng.randf_range(-3.0, 3.0), _puff_rng.randf_range(-1.5, 2.0), _puff_rng.randf_range(-1.0, 1.0)), 2.5)


# ---- Thermals (Kest) ----

func _build_thermal(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var base: Vector3 = ground.call(at.x, at.y, 0.0)
	var column := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = float(spec["radius"]) * 1.3
	cm.bottom_radius = float(spec["radius"]) * 0.5
	cm.height = spec["height"]
	column.mesh = cm
	column.material_override = Palette.unshaded(Color(Palette.SAND, 0.12))
	column.position = base + Vector3.UP * float(spec["height"]) * 0.5
	add_child(column)
	var grate := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = float(spec["radius"]) * 0.6
	gm.bottom_radius = float(spec["radius"]) * 0.6
	gm.height = 0.3
	grate.mesh = gm
	grate.material_override = Palette.striped(Palette.COPPER, Palette.CHARCOAL)
	grate.position = base + Vector3.UP * 0.1
	add_child(grate)
	return {"spec": spec, "base": base}


# ---- Shared visuals ----

# A bone gauge dial on a post; returns the needle to turn.
# A row with one of the park's skins draws the gauge skin for the post, face and redline; the needle stays code.
func _dial(at: Vector3, spec := {}) -> MeshInstance3D:
	if SKINS.has(_recipe_of(spec)) and not _skin_views(spec, "gauge", self, Transform3D(Basis.IDENTITY, at)).is_empty():
		var needle := MeshInstance3D.new()
		var nm := BoxMesh.new()
		nm.size = Vector3(0.12, 0.95, 0.05)
		needle.mesh = nm
		needle.material_override = _needle_mat
		needle.position = at + Vector3.UP * 3.4 + Vector3(0.0, 0.0, 0.12)
		add_child(needle)
		return needle
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.2
	pm.bottom_radius = 0.2
	pm.height = 3.0
	post.mesh = pm
	post.material_override = _copper_mat
	post.position = at + Vector3.UP * 1.5
	add_child(post)
	var face := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 1.1
	fm.bottom_radius = 1.1
	fm.height = 0.15
	face.mesh = fm
	face.material_override = _gauge_mat
	face.position = at + Vector3.UP * 3.4
	face.rotation.x = PI * 0.5
	add_child(face)
	var redline := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.2, 0.5, 0.05)
	redline.mesh = rm
	redline.material_override = _rust_mat
	redline.position = face.position + Vector3(0.75, 0.55, 0.1)
	redline.rotation.z = -0.8
	add_child(redline)
	var needle := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.12, 0.95, 0.05)
	needle.mesh = nm
	needle.material_override = _needle_mat
	needle.position = face.position + Vector3(0.0, 0.0, 0.12)
	add_child(needle)
	return needle


# The needle sweeps linearly from -120 to +120 degrees: it measures time.
static func _needle(needle: MeshInstance3D, g: float) -> void:
	needle.rotation.z = -lerpf(-2.1, 2.1, clampf(g, 0.0, 1.0))


func _puff(at: Vector3, size: float) -> void:
	var node := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	node.mesh = s
	node.material_override = _steam_mat
	node.position = to_local(at) if is_inside_tree() else at
	add_child(node)
	_puffs.append({"node": node, "left": PUFF_SECONDS, "size": size})


func _dashed_ring(at: Vector3, radius: float) -> void:
	for k in 16:
		var a := TAU * k / 16.0
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.3, 0.06, radius * TAU / 32.0)
		dash.mesh = dm
		dash.material_override = _gauge_mat
		dash.position = at + Vector3(cos(a), 0.0, sin(a)) * radius
		dash.rotation.y = -a
		add_child(dash)
