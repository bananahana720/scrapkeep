extends "res://src/combat/enemy.gd"

const Roster := preload("res://src/combat/roster.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# One swarm-remnant drone (DESIGN-V2 section 10): a small flat cast triangle, the only
# identical things in the game on purpose (VISUAL-LANGUAGE section 11). Alone it is
# weak: low health, light enough to crush, harmless to touch. Its formation (swarm.gd)
# decides where it flies and when it dives; a hard knock on any drone of a forming or
# locked rack scatters the whole rack (a diving drone meeting the ball does not). While the rack is scattered it follows the ball with its blue seam dark
# (C11), and a follower that reaches another enemy launches into it as a pin carrier.

const HP := 12.0
# At rest the drone sits on the ground (its box's half height), so its shadow touches it.
const HOVER := 0.3
const HOVER_HIGH := 3.4
const CLIMB := 6.0
const SLOT_GAIN := 5.0
const MAX_SPEED := 26.0
const FOLLOW_GAP := 4.5
const FOLLOW_CLOSE := 2.5
const DIVE_REACH := 1.6
const DIVE_DAMAGE := 8.0
const DIVE_SHOVE := 3.0
const SCATTER_FORCE := 5.0
const PIN_REACH := 2.2
const PIN_LAUNCH := 4.0
const SIZE := 0.75
# Scattered drones keep SPREAD metres apart, so a broken rack reads as broken, not stacked.
const SPREAD := 1.5
const SPREAD_GAIN := 16.0
# The slab stands SLAB_HEIGHT tall on the floor of its box; the faces toward its heading
# carry the threat stripe. Scattered, each tilts by its own angle and the inlay dims.
const SLAB_HEIGHT := 0.42
const LEADING := 0.3
const SCATTER_TILT := [16.0, 23.0, 30.0]
const SEAM_LIT := 2.2
const SEAM_DIM := 0.3

var swarm
var fleet
var index := 0
var pins_led := 0
var _seam: MeshInstance3D
var _body: MeshInstance3D
var _slab: Node3D
var _seam_material: StandardMaterial3D
var _seamless := false
static var _shared: Array = []
static var _asset_warned := false
static var _hazard_stripe: StandardMaterial3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "swarm_remnant"
	faction = Roster.SWARM
	fleet = spec.get("fleet")
	swarm = spec.get("swarm")
	_set_health(HP * threat)
	scrap_value = 1
	weight = 0.4
	radius = SIZE
	half_height = 0.3
	_build_body()
	if swarm != null:
		index = swarm.add(self)


func state_name() -> String:
	return ["forming", "locked", "diving", "scattered"][swarm.state] if swarm != null else "idle"


func knock(direction: Vector3, force: float) -> void:
	super.knock(direction, force)
	if swarm != null and force / weight >= SCATTER_FORCE and swarm.state in [swarm.State.FORMING, swarm.State.LOCKED]:
		swarm.scatter(global_position)


# The seam goes dark while the drone follows: hue alone never flips a hostile into an
# ally, so its edge stays and only the ancient light leaves it.
func set_seamless(on: bool) -> void:
	_seamless = on
	if _seam_material != null:
		_seam_material.emission_energy_multiplier = SEAM_DIM if on else SEAM_LIT
		_seam_material.albedo_color = Roster.ANCIENT_LIGHT.darkened(0.6) if on else Roster.ANCIENT_LIGHT
	if _slab != null:
		var heading := Vector3.RIGHT.rotated(Vector3.UP, float(index) * 2.4)
		_slab.basis = Basis(heading, deg_to_rad(float(SCATTER_TILT[index % SCATTER_TILT.size()]))) if on else Basis.IDENTITY


func seam_lit() -> bool:
	return not _seamless


func commit_formation_lane(from: Vector3, heading: Vector3, lane_length: float, lane_width: float) -> Node3D:
	var lane := _commit_lane(Threat.Type.LANE, from, heading, lane_length, lane_width)
	lane.owner_voice = String(Roster.faction(Roster.SWARM)["voice"])
	lane.mechanic_tag = String(Roster.row("swarm_remnant")["tag"])
	return lane


func drop_formation_lane() -> void:
	_clear_telegraph()


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if not _in_play() or target == null or swarm == null:
		_hover(delta, Vector3.ZERO)
		return
	var ball := _ball()
	var speed: float = target.planar_velocity().length()
	swarm.step(delta, ball, speed)
	var desired := Vector3.ZERO
	match swarm.state:
		swarm.State.SCATTERED:
			desired = (_follow(ball, speed) + _spread()).limit_length(MAX_SPEED)
			_lead_into_pin()
		_:
			var to_slot: Vector3 = swarm.slot(index) - global_position
			to_slot.y = 0.0
			desired = (to_slot * SLOT_GAIN).limit_length(MAX_SPEED)
			if swarm.state == swarm.State.DIVING:
				_dive_check(ball)
	_hover(delta, desired)


# At the ball's heels: its speed, plus FOLLOW_CLOSE a metre of gap still to close.
func _follow(ball: Vector3, speed: float) -> Vector3:
	var to := Vector3(ball.x - global_position.x, 0.0, ball.z - global_position.z)
	if to.length() <= FOLLOW_GAP:
		return Vector3.ZERO
	return to.normalized() * minf(speed + (to.length() - FOLLOW_GAP) * FOLLOW_CLOSE, MAX_SPEED)


func _spread() -> Vector3:
	var push := Vector3.ZERO
	for other in swarm.alive():
		if other == self:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var gap := away.length()
		if gap < SPREAD:
			var dir := away / gap if gap > 0.01 else Vector3.RIGHT.rotated(Vector3.UP, float(index))
			push += dir * (SPREAD - gap) * SPREAD_GAIN
	return push


func _dive_check(ball: Vector3) -> void:
	if swarm.stung:
		return
	var lane = swarm.lane()
	if lane == null or not lane.contains(ball) or global_position.distance_to(ball) > DIVE_REACH + radius:
		return
	swarm.stung = true
	hit_player.emit(DIVE_DAMAGE, lane.dir * DIVE_SHOVE)
	swarm.end_dive()


# A follower that reaches another enemy launches into it, fast enough for combat's pin
# rule to count it: the ball led the drone there.
func _lead_into_pin() -> void:
	if _knocked_speed() > Weapons.PIN_MIN_SPEED:
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or enemy.get("kind") == "swarm_remnant" or not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() - float(enemy.get("radius")) > PIN_REACH:
			continue
		pins_led += 1
		_knock = to.normalized() * (Weapons.PIN_MIN_SPEED + PIN_LAUNCH)
		velocity = Vector3(_knock.x, velocity.y, _knock.z)
		if fleet != null:
			fleet.on_follower_launched(self, enemy)
		return


func _hover(delta: float, desired: Vector3) -> void:
	var horizontal := Vector3(_knock.x, 0.0, _knock.z)
	if horizontal.length() < 1.0:
		horizontal = desired
	var ground: float = terrain.height(global_position.x, global_position.z) if terrain != null else 0.0
	var hover := HOVER_HIGH if swarm != null and swarm.flying_high() else HOVER
	velocity = Vector3(horizontal.x, (ground + hover - global_position.y) * CLIMB + maxf(0.0, _knock.y), horizontal.z)
	_knock.y = 0.0
	move_and_slide()
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
	if horizontal.length() > 0.5:
		rotation.y = atan2(horizontal.x, horizontal.z)


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE * 2.0, 0.6, SIZE * 2.0)
	shape.shape = box
	add_child(shape)
	_slab = Node3D.new()
	_slab.name = "Slab"
	_visual_parent().add_child(_slab)
	var parts := _parts()
	if not parts.is_empty():
		_base_color = Color.WHITE
		_material = Palette.solid(Color.WHITE)
		_material.vertex_color_use_as_albedo = true
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_slab.add_child(mi)
			if part.name == "RemnantBody":
				_body = mi
			elif part.name == "RemnantSeam":
				_seam = mi
				_seam_material = (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
				mi.set_surface_override_material(0, _seam_material)
		return
	_base_color = Roster.ANCIENT_ENAMEL
	_material = Palette.solid(Roster.ANCIENT_ENAMEL)
	var prism := CylinderMesh.new()
	prism.radial_segments = 3
	prism.top_radius = SIZE
	prism.bottom_radius = SIZE
	prism.height = 0.22
	_body = MeshInstance3D.new()
	_body.mesh = prism
	_body.material_override = _material
	_slab.add_child(_body)
	var edge := CylinderMesh.new()
	edge.radial_segments = 3
	edge.top_radius = SIZE * 0.55
	edge.bottom_radius = SIZE * 0.55
	edge.height = 0.24
	_seam = MeshInstance3D.new()
	_seam.mesh = edge
	_seam_material = Palette.solid(Roster.ANCIENT_LIGHT, SEAM_LIT)
	_seam.material_override = _seam_material
	_seam.position = Vector3.UP * 0.02
	_slab.add_child(_seam)


static func hazard_stripe() -> StandardMaterial3D:
	if _hazard_stripe == null:
		_hazard_stripe = StandardMaterial3D.new()
		_hazard_stripe.albedo_texture = Threat.Painter.stripe_texture()
		_hazard_stripe.uv1_triplanar = true
		_hazard_stripe.uv1_scale = Vector3.ONE / (Threat.STRIPE_PITCH * sqrt(2.0))
		_hazard_stripe.roughness = 0.6
	return _hazard_stripe


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_one/enemy_swarm_remnant.glb"
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		_asset_warning()
		return []
	var scene := packed.instantiate()
	var parts: Array = []
	var names := []
	var valid := scene != null
	var low := INF
	var high := -INF
	if scene != null:
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				valid = false
				continue
			var mesh: Mesh = mi.mesh.duplicate()
			var flash := -1
			var slots := []
			for i in mesh.get_surface_count():
				var source := mesh.surface_get_material(i)
				if source == null:
					valid = false
					continue
				var slot := source.resource_name
				slots.append(slot)
				if slot == "ancient_enamel":
					flash = i
				var mat := Palette.solid(Roster.ANCIENT_LIGHT, SEAM_LIT) if slot == "ancient_light" else Palette.solid(Color.WHITE)
				mat.vertex_color_use_as_albedo = slot == "paint"
				mesh.surface_set_material(i, mat)
			valid = valid and ((mi.name == "RemnantBody" and slots.size() == 2 and "ancient_enamel" in slots and "paint" in slots)
				or (mi.name == "RemnantSeam" and slots == ["ancient_light"]))
			var xform := mi.transform
			var ancestor := mi.get_parent()
			while ancestor != scene and ancestor is Node3D:
				xform = ancestor.transform * xform
				ancestor = ancestor.get_parent()
			if valid and mi.name == "RemnantBody":
				var bounds: AABB = xform * mesh.get_aabb()
				low = bounds.position.y
				high = bounds.end.y
				mesh = _leading_split(mesh, slots)
				flash = 0
			names.append(String(mi.name))
			parts.append({"name": mi.name, "mesh": mesh, "xform": xform, "flash": flash})
		scene.free()
	names.sort()
	if not valid or names != ["RemnantBody", "RemnantSeam"] or high <= low:
		_asset_warning()
		return []
	var stand := SLAB_HEIGHT / (high - low)
	var lift := Transform3D(Basis.from_scale(Vector3(1.0, stand, 1.0)), Vector3.UP * (-0.3 - low * stand))
	for part in parts:
		part.xform = lift * part.xform
	_shared = parts
	return _shared


static func _leading_split(mesh: Mesh, slots: Array) -> ArrayMesh:
	var hull := SurfaceTool.new()
	var edge := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var enamel := Roster.ANCIENT_ENAMEL.srgb_to_linear()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var cs = arrays[Mesh.ARRAY_COLOR]
		var ix = arrays[Mesh.ARRAY_INDEX]
		var count: int = ix.size() if ix != null else vs.size()
		for k in range(0, count, 3):
			var tri := [ix[k], ix[k + 1], ix[k + 2]] if ix != null else [k, k + 1, k + 2]
			var n: Vector3 = (ns[tri[0]] + ns[tri[1]] + ns[tri[2]]).normalized()
			var tool := edge if n.z > LEADING and absf(n.y) < 0.5 else hull
			for v in tri:
				tool.set_normal(ns[v])
				tool.set_color(enamel if slots[i] == "ancient_enamel" or cs == null else cs[v])
				tool.add_vertex(vs[v])
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	hull.set_material(painted)
	edge.set_material(hazard_stripe())
	var out := hull.commit()
	return edge.commit(out)


static func _asset_warning() -> void:
	if not _asset_warned:
		_asset_warned = true
		push_warning("swarm_remnant: missing or malformed model; using cast triangle fallback")
