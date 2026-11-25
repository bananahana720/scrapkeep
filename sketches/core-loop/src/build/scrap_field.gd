extends Node3D

const Palette := preload("res://src/core/palette.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Panels := preload("res://src/build/panels.gd")
const PanelShell := preload("res://src/build/panel_shell.gd")
const PICKUP_GLB := "res://assets/models/world_one/scrap_pickups.glb"
const PICKUP_VARIANTS := ["BentPlate", "GearSegment", "PipeStub", "BoltCluster"]
# The money, in the same kit: a worn steel cog with bone teeth (W1-21).
const COG_PART := "Cog"
static var _pickup_mesh_cache: Array[Mesh] = []
static var _recovery_mesh_cache: Array[Mesh] = []
static var _cog_model: Mesh = null
static var model_path := PICKUP_GLB
static var _pickup_assets := {}


static func reset_for_tests() -> void:
	model_path = PICKUP_GLB
	_pickup_mesh_cache.clear()
	_recovery_mesh_cache.clear()
	_cog_model = null
	_pickup_assets.clear()
	_ground_plates.clear()

# Scrap laid along the terrain's scrap lines. The magnet grows with heft (6 m times the
# square root of heft, capped at 18 m) and reaches further again the faster you roll,
# and a piece it catches homes in faster than the ball can outrun it, so taking scrap
# never asks you to slow down or turn back (momentum is sacred). A caught piece stays
# caught until it lands on the ball. Pickups never touch the ball's velocity.

const MAGNET_PER_ROOT_HEFT := 6.0
const MAGNET_CAP := 18.0
# Extra magnet reach per m/s of ball speed, on top of the capped heft reach, so a fast
# ball still catches what it passes.
const MAGNET_PER_SPEED := 0.3
const COLLECT := 2.0
const HOME_SPEED := 16.0
const HOME_OVER_BALL := 1.4
const SPACING := 8.0
const MAX_PER_LINE := 14
# A trail piece floats this far over the ground, as a line's does; the trail is walked in steps this long.
const TRAIL_OVER_GROUND := 1.4
const TRAIL_STEP_M := 1.0
const TRAIL_DROP := 1.0
# A caught piece swings in on a curve (v3 W11): sideways and up at this share of its
# homing speed while far, straight in as it closes, so the pull reads as a greedy
# swirl. The homing term is unchanged, so the pull takes as long as it did.
const ARC_SIDE := 0.6
const ARC_LIFT := 0.3
# Readable cap (SCRAP-LEAK): kills and drops that nobody collects must not grow the scene
# without bound (SR2's soak reached 21,000 nodes in 10 minutes). Past MAX_PIECES loose
# pieces or MAX_GEARS loose gears, the oldest uncaught one folds its value into the piece
# just dropped, so the newest scrap stays where the fight is and no value is lost. The
# stage layout is never folded (a line's pieces are under the cap, and a trail's are passed
# over, so a long fight leaves the phrases ahead whole) and nothing here draws rng.
const MAX_PIECES := 400
const MAX_GEARS := 200
# Distant 0.65 m pickups drop out past this range so a park-wide landmark camera does not draw scrap a kilometre away.
const PICKUP_VIEW_END_M := 300.0
const PICKUP_VIEW_MARGIN_M := 20.0
# The live caps; a test's planted control raises them to prove the cap is what holds the count.
var max_pieces := MAX_PIECES
var max_gears := MAX_GEARS

var magnet_scale := 1.0
# The run's heft; build sets it every tick.
var heft := 1.0

# Recovery clusters (the durability prototype): scrap a hit spilled, each worth several
# units, ahead of or beside the ball's outgoing line. They sit in _items like any piece, so
# the magnet and the arc pull work on them, but step() reports them apart in
# recovered_values, and one nobody reaches expires after RECOVERY_LIFE seconds.
const RECOVERY_LIFE := 20.0
const RECOVERY_MAX_CLUSTERS := 6
const RECOVERY_AHEAD := Vector2(6.0, 16.0)
const RECOVERY_SIDE := 4.5
# One cluster taken back, with its scrap value. Audio chimes on it; the mass is still
# credited by build from recovered_values, and this is no pickup (no scrap_collected).
signal recovered(value: int)
# What the last step() collected and let expire, as scrap values.
var recovered_values: Array[int] = []
var expired_values: Array[int] = []

# Cogs (CG1): the spend wallet's pickups, steel gears that share the magnet and the arc
# pull but never add mass. A scrap line lays one gear worth COG_LINE_VALUE beside every
# COG_LINE_EVERY-th piece, and a kill drops one 1-cog gear per scrap unit it drops, so a
# run earns about the cogs it once earned as wallet scrap from lines and kills. Gears are
# placed without the rng, so the loot stream draws what it drew before.
const COG_LINE_EVERY := 2
const COG_LINE_VALUE := 2
const COG_LINE_SIDE := 1.5
const COG_RING := 1.8
# What the last step() collected as cogs, one value per gear.
var cog_values: Array[int] = []
# Grey panel pickups (build/panels.gd): item -> {id, jackpot}. A panel on the ground is its own kit plate from
# the ball (panel_shell.gd), lying flat at GROUND_PLATE times the plate's size so it reads from the gameplay
# camera. They never fold or expire; what
# the last step() took is in panel_takes, one {id, jackpot, at} per panel.
var _panels := {}
var panel_takes: Array[Dictionary] = []
var _panel_mesh: BoxMesh
var _panel_material: Material
var _panel_column: CylinderMesh
var _panel_column_material: Material
const GROUND_PLATE := 2.0
static var _ground_plates := {}
# Rib caches (panels waiting at the end of a dead end): a tall thin column that clears the
# route's skyline, and a two-note chime loop heard from CACHE_HEAR metres.
# Each maps the panel to the ground it was dropped on.
var _caches := {}
# The pieces lay_trail laid (item -> true): the fold passes over them.
var _trail := {}
var _cache_column: CylinderMesh
const CACHE_COLUMN := 14.0
const CACHE_HEAR := 45.0
const SPIN_RANGE := 120.0

var _value := {}
var _age := {}
var _cogs := {}
# Units a folded piece carries beyond its own one (plain pieces only; gears fold into _cogs).
var _units := {}
var _cog_material: Material
var _cog_mesh: Mesh
var _cluster_material: Material
var _cluster_mesh: BoxMesh
var _items: Array[MeshInstance3D] = []
var _caught := {}
var _catch_serial := 0
var _material: Material
var _mesh: BoxMesh
var _spin := 0.0


func setup() -> void:
	_material = Palette.solid(Palette.ARC, 1.6)
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(0.8, 0.8, 0.8)
	_cluster_material = Palette.solid(Palette.AMBER, 2.2)
	_cluster_mesh = BoxMesh.new()
	_cluster_mesh.size = Vector3(1.4, 1.4, 1.4)
	_cog_material = Palette.solid(Palette.STEEL, 1.8)
	_cog_mesh = CylinderMesh.new()
	_cog_mesh.top_radius = 0.45
	_cog_mesh.bottom_radius = 0.45
	_cog_mesh.height = 0.18
	_cog_mesh.radial_segments = 8
	# A grey panel on the ground: a steel plate under a short bone light column, the grey rung's
	# read from a distance (the ladder page: "short for grey, tall for gold").
	_panel_mesh = BoxMesh.new()
	_panel_mesh.size = Vector3(0.9, 0.16, 0.7)
	_panel_material = Palette.solid(Palette.SLATE, 0.9)
	_panel_column = CylinderMesh.new()
	_panel_column.top_radius = 0.06
	_panel_column.bottom_radius = 0.16
	_panel_column.height = 2.4
	_panel_column.radial_segments = 6
	_panel_column_material = Palette.unshaded(Palette.SAND)
	_cache_column = CylinderMesh.new()
	_cache_column.top_radius = 0.03
	_cache_column.bottom_radius = 0.2
	_cache_column.height = CACHE_COLUMN
	_cache_column.radial_segments = 6
	if not _pickup_meshes().is_empty():
		_material = _pickup_material(Palette.ARC)
		_cluster_material = _pickup_material(Palette.AMBER)
		_material.resource_name = "field"
		_cluster_material.resource_name = "field"
	if _cog_model != null:
		_cog_mesh = _cog_model
		_cog_material = _cog_glow()


static func _pickup_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/pickup.gdshader")
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("face_energy", 0.06)
	material.set_shader_parameter("rim_energy", 1.25)
	material.set_shader_parameter("emission_ceiling", 1.35)
	return material


# The cog's glow: the pickup shader's rim in bone over the steel, softer than the mint field's.
static func _cog_glow() -> ShaderMaterial:
	var material := _pickup_material(Palette.SAND)
	material.set_shader_parameter("rim_energy", 0.9)
	material.set_shader_parameter("emission_ceiling", 1.0)
	return material


# A field piece, a recovery cluster and a cog as _add draws them, each pickup variant once (BakeWarm builds
# them at stage entry, so the run's first kill draws no pickup surface for the first time).
static func warm_views() -> Array[Node3D]:
	var views: Array[Node3D] = []
	var meshes: Array[Mesh] = _pickup_meshes()
	if meshes.is_empty():
		return views
	var material := _pickup_material(Palette.ARC)
	for mesh in meshes + _recovery_mesh_cache:
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.material_override = material
		views.append(view)
	if _cog_model != null:
		var cog := MeshInstance3D.new()
		cog.mesh = _cog_model
		cog.material_override = _cog_glow()
		views.append(cog)
	return views


static func _pickup_meshes() -> Array[Mesh]:
	if _pickup_assets.has(model_path):
		_pickup_mesh_cache = _pickup_assets[model_path]["meshes"]
		_recovery_mesh_cache = _pickup_assets[model_path]["recovery"]
		_cog_model = _pickup_assets[model_path]["cog"]
		return _pickup_mesh_cache
	_pickup_mesh_cache = []
	_recovery_mesh_cache = []
	_cog_model = null
	var packed := load(model_path) as PackedScene if ResourceLoader.exists(model_path) else null
	if packed != null:
		var scene := packed.instantiate()
		if scene != null:
			var parts := scene.find_children("*", "MeshInstance3D", true, false)
			if parts.size() == PICKUP_VARIANTS.size() + 1:
				for variant in PICKUP_VARIANTS:
					var part := scene.find_child(variant, true, false) as MeshInstance3D
					if not _valid_pickup(part):
						_pickup_mesh_cache.clear()
						break
					_pickup_mesh_cache.append(part.mesh)
				var cog := scene.find_child(COG_PART, true, false) as MeshInstance3D
				_cog_model = cog.mesh if _valid_pickup(cog) else null
			scene.free()
	if _cog_model == null:
		push_warning("scrap field: missing or malformed cog model; using cog disc fallback")
	if _pickup_mesh_cache.is_empty():
		push_warning("scrap field: missing or malformed model; using scrap box fallback")
	else:
		for mesh in _pickup_mesh_cache:
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				vertices[i] *= 1.75
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var cluster := ArrayMesh.new()
			cluster.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			cluster.surface_set_material(0, mesh.surface_get_material(0))
			_recovery_mesh_cache.append(cluster)
	_pickup_assets[model_path] = {"meshes": _pickup_mesh_cache, "recovery": _recovery_mesh_cache, "cog": _cog_model}
	return _pickup_mesh_cache


static func _valid_pickup(part: MeshInstance3D) -> bool:
	if part == null or not part.mesh is ArrayMesh or part.mesh.get_surface_count() != 1 \
			or not part.transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var mesh := part.mesh
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	if material == null or material.resource_name != "field" \
			or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var triangles := (indices.size() if not indices.is_empty() else vertices.size()) / 3
	if vertices.is_empty() or vertices.size() > 610 or colors.size() != vertices.size() or triangles > 270:
		return false
	for vertex in vertices:
		if vertex.abs().x > 0.401 or vertex.abs().y > 0.401 or vertex.abs().z > 0.401:
			return false
	for color in colors:
		if color.a < 0.999:
			return false
	return true


func lay_out(terrain, lines: Array, density: float, rng: RandomNumberGenerator) -> void:
	clear()
	for line in lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var n := clampi(int(from.distance_to(to) / SPACING * density), 4, int(MAX_PER_LINE * density))
		for i in n:
			var t := (i + 0.5) / float(n)
			var spot := from.lerp(to, t)
			spot += Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			_add(terrain.drop_point(spot.x, spot.y, 1.4))
			if i % COG_LINE_EVERY == COG_LINE_EVERY - 1:
				var across := (to - from).orthogonal().normalized() * COG_LINE_SIDE
				var gear := spot + across
				_add_cog(terrain.drop_point(gear.x, gear.y, 1.4), COG_LINE_VALUE)


# Scrap along a map's trail, laid to the beat (ruling cd): one piece every spacing_m of ground rolled, in phrases of
# `phrase` pieces with `rest` empty beats between, so a ball holding its speed takes them in time and the pickup ladder
# climbs once a phrase. Adds to what lay_out laid. It draws no rng and lays no gears: the same stage always has the same
# trail. A piece is a pickup like any other (1 scrap and 1 mass, and it fires the on-pickup procs), so a whole trail is
# about 100 mass, a fifth of a heft step: something to follow and hear far more than power.
func lay_trail(terrain, trail: Dictionary) -> void:
	for spot in trail_spots(trail, func(x: float, z: float) -> float: return terrain.height(x, z)):
		_trail[_add(spot + Vector3.UP * TRAIL_OVER_GROUND)] = true


# Where the trail's pieces still on the field float, in the order laid.
func trail_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for item in _items:
		if _trail.has(item):
			out.append(item.position)
	return out


# Where a trail's pieces stand on the ground, in line order. The line is walked in TRAIL_STEP_M steps and measured over
# the ground it crosses (ground: Callable (x, z) -> height), so a slope keeps the same rolled distance between pieces.
# The beats keep counting where no piece can stand, and that beat stays empty:
#   a ledge   a step steeper than TRAIL_DROP is flown, not rolled: its run counts only up to a step short of the next
#             beat, so no piece stands on its face and the piece due there stands a step past its foot instead (the
#             beat slips by that much, and a long face holds one beat, not several);
#   a gap     trail["gaps"], [from, to] in metres of plan distance along the line: a built ramp over the ground.
# Beat 0 is the line's start and stays empty (the drop-in); a phrase the line ends inside is left out whole.
static func trail_spots(trail: Dictionary, ground: Callable) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var points: PackedVector2Array = trail.get("points", PackedVector2Array())
	var spacing := float(trail.get("spacing_m", 0.0))
	var phrase := int(trail.get("phrase", 0))
	var period := phrase + int(trail.get("rest", 0))
	var gaps: Array = trail.get("gaps", [])
	if points.size() < 2 or spacing <= 0.0 or phrase <= 0:
		return spots
	var last := Vector3(points[0].x, ground.call(points[0].x, points[0].y), points[0].y)
	var rolled := 0.0
	var plan := 0.0
	var beat := 1
	var whole := 0
	for i in range(1, points.size()):
		var leg := points[i] - points[i - 1]
		var steps := maxi(1, ceili(leg.length() / TRAIL_STEP_M))
		for s in range(1, steps + 1):
			var p := points[i - 1] + leg * (float(s) / steps)
			var here := Vector3(p.x, ground.call(p.x, p.y), p.y)
			var run := Vector2(here.x - last.x, here.z - last.z).length()
			if absf(here.y - last.y) > run * TRAIL_DROP:
				rolled = minf(rolled + run, spacing * beat - TRAIL_STEP_M)
			else:
				var stride := last.distance_to(here)
				while stride > 0.0 and rolled + stride >= spacing * beat:
					var t := (spacing * beat - rolled) / stride
					var at := plan + run * t
					if (beat - 1) % period < phrase and not gaps.any(func(g: Array) -> bool: return at >= g[0] and at <= g[1]):
						spots.append(last.lerp(here, t))
					if (beat - 1) % period == phrase - 1:
						whole = spots.size()
					beat += 1
				rolled += stride
			plan += run
			last = here
	spots.resize(whole)
	return spots


func clear() -> void:
	for item in _items:
		item.queue_free()
	_items.clear()
	_caught.clear()
	_catch_serial = 0
	_value.clear()
	_age.clear()
	_cogs.clear()
	_units.clear()
	_panels.clear()
	_caches.clear()
	_trail.clear()


# Scrap pieces and recovery clusters on the field; gears and panels are counted apart.
func count() -> int:
	return _items.size() - _cogs.size() - _panels.size()


func panel_count() -> int:
	return _panels.size()


# Vacuums pickups within `radius` of the line segment [from, to] toward `from` by `step_dist`,
# marking them caught so the normal magnet pull completes collection without exposing _items/_caught.
func pull_along_segment(from: Vector3, to: Vector3, radius: float, step_dist: float) -> int:
	var pulled := 0
	for item in _items:
		if not is_instance_valid(item):
			continue
		var closest := Geometry3D.get_closest_point_to_segment(item.global_position, from, to)
		if closest.distance_to(item.global_position) <= radius:
			item.global_position = item.global_position.move_toward(from, step_dist)
			if not _caught.has(item):
				_caught[item] = _catch_side(item)
			pulled += 1
	return pulled


# One grey panel dropped at `at`, waiting for the ball like a gear: the panel's own kit plate, lying flat.
func drop_panel(at: Vector3, panel_id: String, jackpot := false, cache := false) -> void:
	var plate := ground_plate(panel_id)
	var item := _add(at + Vector3.UP * 1.2, plate if plate != null else _panel_mesh, _panel_material)
	if plate != null:
		item.material_override = null
	var column := MeshInstance3D.new()
	column.mesh = _cache_column if cache else _panel_column
	column.material_override = _panel_column_material
	column.position = Vector3.UP * ((CACHE_COLUMN if cache else _panel_column.height) * 0.5 + 0.1)
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.add_child(column)
	_panels[item] = {"id": panel_id, "jackpot": jackpot}
	if cache:
		_caches[item] = at
		var chime := AudioStreamPlayer3D.new()
		chime.name = "CacheChime"
		chime.stream = SfxBank.loop_stream("panel_cache")
		chime.bus = "SFX"
		chime.volume_db = SfxBank.trim_db("panel_cache")
		chime.unit_size = 10.0
		chime.max_distance = CACHE_HEAR
		chime.autoplay = true
		item.add_child(chime)


# The kit plate panel_shell.gd bolts onto the ball for this panel, GROUND_PLATE times larger with its own two
# materials; null when the plate does not load (panel_shell reports that), and the field draws its slate box.
static func ground_plate(panel_id: String) -> Mesh:
	var silhouette: String = Panels.ROWS[panel_id]["silhouette"] if Panels.ROWS.has(panel_id) else "tile"
	if _ground_plates.has(silhouette):
		return _ground_plates[silhouette]
	var source := PanelShell.plate_mesh(silhouette)
	if source == null:
		return null
	var plate := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			vertices[i] *= GROUND_PLATE
		arrays[Mesh.ARRAY_VERTEX] = vertices
		plate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		plate.surface_set_material(surface, source.surface_get_material(surface))
	_ground_plates[silhouette] = plate
	return plate


# The rib caches still waiting on the ground.
func cache_count() -> int:
	return _caches.size()


# Where each waiting rib cache stands, with its panel id: [{at, foot, id, item}], foot the ground it was
# dropped on, which stays put while the magnet pulls the panel.
func caches() -> Array:
	var out := []
	for item in _caches:
		out.append({"at": item.global_position, "foot": _caches[item], "id": _panels[item]["id"], "item": item})
	return out


# Takes back every rib cache still waiting (a retry places the stage's caches again).
func clear_caches() -> void:
	for item in _caches.keys():
		if is_instance_valid(item):
			_items.erase(item)
			_forget(item)
			item.queue_free()
	_caches.clear()


func cog_count() -> int:
	return _cogs.size()


# The cogs the field's gears hold.
func cog_value() -> int:
	var total := 0
	for v in _cogs.values():
		total += int(v)
	return total


# `amount` 1-cog gears in a ring around `at`, placed without the rng.
func drop_cogs(at: Vector3, amount: int) -> void:
	for i in amount:
		var angle := TAU * i / float(maxi(1, amount))
		_add_cog(at + Vector3(cos(angle) * COG_RING, 1.2, sin(angle) * COG_RING), 1)
	_fold_gears()


# A Warden's cogs along the same line as its scrap, offset to one side.
func drop_cogs_line(at: Vector3, heading: Vector3, length: float, amount: int) -> void:
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	var side := flat.cross(Vector3.UP).normalized() * COG_LINE_SIDE
	for i in amount:
		var t := (i + 0.5) / float(maxi(1, amount))
		_add_cog(at + flat * length * t + side + Vector3.UP * 1.2, 1)
	_fold_gears()


# Live recovery clusters, and the scrap they hold.
func recovery_count() -> int:
	return _value.size()


func recovery_value() -> int:
	var total := 0
	for v in _value.values():
		total += int(v)
	return total


# Lays `amount` out as at most `count` valued clusters ahead of and beside `heading`, on
# the ground. Never touches the ball: a spill is something to roll through, not a stop.
func drop_recovery(terrain, from: Vector3, heading: Vector3, amount: int, count: int, rng: RandomNumberGenerator) -> void:
	var n := clampi(mini(count, RECOVERY_MAX_CLUSTERS), 0, amount)
	if n <= 0:
		return
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	if flat.length() < 0.1:
		flat = Vector3.FORWARD
	var side := flat.cross(Vector3.UP).normalized()
	var base := amount / n
	var extra := amount - base * n
	for i in n:
		var t := (i + 0.5) / float(n)
		var ahead := lerpf(RECOVERY_AHEAD.x, RECOVERY_AHEAD.y, rng.randf())
		var lateral := (t * 2.0 - 1.0) * RECOVERY_SIDE + rng.randf_range(-1.0, 1.0)
		var spot := from + flat * ahead + side * lateral
		var item := _add(terrain.drop_point(spot.x, spot.z, 1.4) if terrain != null else spot, _cluster_mesh, _cluster_material)
		_value[item] = base + (1 if i < extra else 0)
		_age[item] = 0.0


func drop(at: Vector3, amount: int, rng: RandomNumberGenerator) -> void:
	for i in amount:
		_add(at + Vector3(rng.randf_range(-2.0, 2.0), 1.2, rng.randf_range(-2.0, 2.0)))
	_fold_pieces()


# The heft part of the reach, monotonic in heft and capped at 18 m.
func heft_reach() -> float:
	return minf(MAGNET_CAP, MAGNET_PER_ROOT_HEFT * sqrt(maxf(1.0, heft)) * magnet_scale)


func magnet_reach(ball_speed: float) -> float:
	return heft_reach() + MAGNET_PER_SPEED * ball_speed


# Pull scales by the same factor as the reach.
func pull_scale() -> float:
	return heft_reach() / MAGNET_PER_ROOT_HEFT


# Scrap scattered along a line, for a Warden's payout thrown toward the gates.
func drop_line(at: Vector3, heading: Vector3, length: float, amount: int, rng: RandomNumberGenerator) -> void:
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	for i in amount:
		var t := (i + 0.5) / float(maxi(1, amount))
		_add(at + flat * length * t + Vector3(rng.randf_range(-1.5, 1.5), 1.2, rng.randf_range(-1.5, 1.5)))
	_fold_pieces()


# Returns where each piece was taken this tick; the run state owns the total.
func step(ball: Vector3, ball_speed: float, delta: float) -> Array[Vector3]:
	_spin += delta * 2.4
	recovered_values.clear()
	expired_values.clear()
	cog_values.clear()
	panel_takes.clear()
	var taken: Array[Vector3] = []
	var reach := magnet_reach(ball_speed)
	var home := (HOME_SPEED + ball_speed * HOME_OVER_BALL) * pull_scale()
	var active_range := maxf(maxf(reach, SPIN_RANGE), COLLECT)
	var active_sq := active_range * active_range
	var i := _items.size() - 1
	while i >= 0:
		var item := _items[i]
		var offset := ball - item.global_position
		var is_caught := _caught.has(item)
		var is_recovery := _value.has(item)
		if is_recovery and not is_caught:
			_age[item] += delta
			if _age[item] >= RECOVERY_LIFE:
				expired_values.append(int(_value[item]))
				_forget(item)
				_items.remove_at(i)
				item.queue_free()
				i -= 1
				continue
		if not is_caught and offset.length_squared() > active_sq:
			i -= 1
			continue
		var distance := offset.length()
		if distance <= COLLECT or (is_caught and distance <= home * delta):
			if is_recovery:
				recovered_values.append(int(_value[item]))
				recovered.emit(int(_value[item]))
			elif _cogs.has(item):
				cog_values.append(int(_cogs[item]))
			elif _panels.has(item):
				panel_takes.append((_panels[item] as Dictionary).merged({"at": item.global_position}))
			else:
				for _unit in 1 + int(_units.get(item, 0)):
					taken.append(item.global_position)
			_forget(item)
			_items.remove_at(i)
			_caught.erase(item)
			item.queue_free()
		else:
			if distance < reach and not is_caught:
				_caught[item] = _catch_side(item)
				is_caught = true
			if is_caught:
				var far := clampf(distance / reach, 0.0, 1.0)
				var side := offset.cross(Vector3.UP)
				side = side.normalized() * float(_caught[item]) if side.length() > 0.01 else Vector3.ZERO
				item.global_position += (offset / distance + side * ARC_SIDE * far + Vector3.UP * ARC_LIFT * far) * home * delta
				item.scale = Vector3.ONE * clampf(distance / reach, 0.45, 1.0)
			# A panel turns upright so its light column stays a column.
			if distance <= SPIN_RANGE or is_caught:
				item.rotation = Vector3(0.0 if _panels.has(item) else _spin * 0.7, _spin, 0.0)
		i -= 1
	return taken


# The swirl side of a caught piece: the bot's sign when it set one, else this field's catch serial,
# so the sign alternates +1, -1, ... in catch order. Runtime identity never reaches the side.
func _catch_side(item: MeshInstance3D) -> float:
	if item.has_meta("bot_side"):
		return float(item.get_meta("bot_side"))
	var side := 1.0 if _catch_serial % 2 == 0 else -1.0
	_catch_serial += 1
	return side


func _forget(item: MeshInstance3D) -> void:
	_value.erase(item)
	_age.erase(item)
	_cogs.erase(item)
	_units.erase(item)
	_panels.erase(item)
	_caches.erase(item)
	_trail.erase(item)


# Loose scrap pieces: no recovery cluster, no gear.
func _piece_total() -> int:
	return _items.size() - _cogs.size() - _value.size() - _panels.size()


# Folds the oldest uncaught loose pieces into the newest until the field is at the cap.
func _fold_pieces() -> void:
	var over := _piece_total() - max_pieces
	var newest: MeshInstance3D = null
	var i := _items.size() - 1
	while i >= 0 and newest == null:
		if not _cogs.has(_items[i]) and not _value.has(_items[i]) and not _panels.has(_items[i]):
			newest = _items[i]
		i -= 1
	var j := 0
	while over > 0 and newest != null and j < _items.size():
		var item := _items[j]
		if item == newest:
			break
		if _cogs.has(item) or _value.has(item) or _panels.has(item) or _caught.has(item) or _trail.has(item):
			j += 1
			continue
		_units[newest] = int(_units.get(newest, 0)) + 1 + int(_units.get(item, 0))
		_forget(item)
		_items.remove_at(j)
		item.queue_free()
		over -= 1


# The same for gears: the folded gear's cogs add to the newest gear's value.
func _fold_gears() -> void:
	var over := _cogs.size() - max_gears
	var newest: MeshInstance3D = null
	var i := _items.size() - 1
	while i >= 0 and newest == null:
		if _cogs.has(_items[i]):
			newest = _items[i]
		i -= 1
	var j := 0
	while over > 0 and newest != null and j < _items.size():
		var item := _items[j]
		if item == newest:
			break
		if not _cogs.has(item) or _caught.has(item):
			j += 1
			continue
		_cogs[newest] = int(_cogs[newest]) + int(_cogs[item])
		_forget(item)
		_items.remove_at(j)
		item.queue_free()
		over -= 1


func _add_cog(at: Vector3, value: int) -> void:
	_cogs[_add(at, _cog_mesh, _cog_material)] = value


func _add(at: Vector3, mesh: Mesh = null, material: Material = null) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh if mesh != null else _mesh
	item.material_override = material if material != null else _material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rare kit panels stay unranged so their cache columns remain visible across the park; small scrap and cogs fade at PICKUP_VIEW_END_M.
	if material != _panel_material:
		item.visibility_range_end = PICKUP_VIEW_END_M
		item.visibility_range_end_margin = PICKUP_VIEW_MARGIN_M
		item.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not _pickup_mesh_cache.is_empty() and (mesh == null or mesh == _cluster_mesh):
		# Position is already seeded by the field; visual selection never draws RNG.
		var seed_key := "%d:%d:%d" % [roundi(at.x * 1000.0), roundi(at.y * 1000.0), roundi(at.z * 1000.0)]
		var variant := int(seed_key.hash() % PICKUP_VARIANTS.size())
		item.mesh = _recovery_mesh_cache[variant] if mesh == _cluster_mesh else _pickup_mesh_cache[variant]
		item.set_meta("scrap_variant", PICKUP_VARIANTS[variant])
	item.position = at
	add_child(item)
	_items.append(item)
	return item
