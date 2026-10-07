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
const HOVER := 1.4
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

var swarm
var fleet
var index := 0
var pins_led := 0
var _seam: MeshInstance3D
var _body: MeshInstance3D
static var _shared: Array = []
static var _asset_warned := false


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
	if _seam != null:
		_seam.visible = not on


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
			desired = _follow(ball, speed)
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
	_base_color = Roster.ANCIENT_ENAMEL
	_material = Palette.solid(Roster.ANCIENT_ENAMEL)
	var parts := _parts()
	if not parts.is_empty():
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			if part.name == "RemnantBody":
				_body = mi
			elif part.name == "RemnantSeam":
				_seam = mi
		return
	var prism := CylinderMesh.new()
	prism.radial_segments = 3
	prism.top_radius = SIZE
	prism.bottom_radius = SIZE
	prism.height = 0.22
	_body = MeshInstance3D.new()
	_body.mesh = prism
	_body.material_override = _material
	_visual_parent().add_child(_body)
	var edge := CylinderMesh.new()
	edge.radial_segments = 3
	edge.top_radius = SIZE * 0.55
	edge.bottom_radius = SIZE * 0.55
	edge.height = 0.24
	_seam = MeshInstance3D.new()
	_seam.mesh = edge
	_seam.material_override = Palette.solid(Roster.ANCIENT_LIGHT, 2.2)
	_seam.position = Vector3.UP * 0.02
	_visual_parent().add_child(_seam)


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
				var mat := Palette.solid(Roster.ANCIENT_LIGHT, 2.2) if slot == "ancient_light" else Palette.solid(Color.WHITE)
				mat.vertex_color_use_as_albedo = slot == "paint"
				mesh.surface_set_material(i, mat)
			valid = valid and ((mi.name == "RemnantBody" and slots.size() == 2 and "ancient_enamel" in slots and "paint" in slots)
				or (mi.name == "RemnantSeam" and slots == ["ancient_light"]))
			var xform := mi.transform
			var ancestor := mi.get_parent()
			while ancestor != scene and ancestor is Node3D:
				xform = ancestor.transform * xform
				ancestor = ancestor.get_parent()
			names.append(String(mi.name))
			parts.append({"name": mi.name, "mesh": mesh, "xform": xform, "flash": flash})
		scene.free()
	names.sort()
	if not valid or names != ["RemnantBody", "RemnantSeam"]:
		_asset_warning()
		return []
	_shared = parts
	return _shared


static func _asset_warning() -> void:
	if not _asset_warned:
		_asset_warned = true
		push_warning("swarm_remnant: missing or malformed model; using cast triangle fallback")
