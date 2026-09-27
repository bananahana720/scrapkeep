extends "res://src/combat/enemy.gd"

const Roster := preload("res://src/combat/roster.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# One swarm-remnant drone (DESIGN-V2 section 10): a small flat cast triangle, the only
# identical things in the game on purpose (VISUAL-LANGUAGE section 11). Alone it is
# weak: low health, light enough to crush, harmless to touch. Its formation (swarm.gd)
# decides where it flies and when it dives; a hard knock on any drone scatters the
# whole rack. While the rack is scattered it follows the ball with its blue seam dark
# (C11), and a follower that reaches another enemy launches into it as a pin carrier.

const HP := 12.0
const HOVER := 1.4
const CLIMB := 6.0
const SLOT_GAIN := 5.0
const MAX_SPEED := 26.0
const FOLLOW_GAP := 3.0
const FOLLOW_MIN := 8.0
const DIVE_REACH := 1.6
const DIVE_DAMAGE := 4.0
const DIVE_SHOVE := 3.0
const SCATTER_FORCE := 5.0
const PIN_REACH := 2.2
const PIN_LAUNCH := 4.0
const SIZE := 0.75

var swarm
var fleet
var index := 0
var dive_hit := false
var pins_led := 0
var _seam: MeshInstance3D
var _body: MeshInstance3D


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
	if swarm != null and force / weight >= SCATTER_FORCE and swarm.state != swarm.State.SCATTERED:
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


func _follow(ball: Vector3, speed: float) -> Vector3:
	var to := Vector3(ball.x - global_position.x, 0.0, ball.z - global_position.z)
	if to.length() <= FOLLOW_GAP:
		return Vector3.ZERO
	return to.normalized() * clampf(speed + 2.0, FOLLOW_MIN, MAX_SPEED)


func _dive_check(ball: Vector3) -> void:
	if dive_hit:
		return
	var lane = swarm.lane()
	if lane == null or not lane.contains(ball) or global_position.distance_to(ball) > DIVE_REACH + radius:
		return
	dive_hit = true
	hit_player.emit(DIVE_DAMAGE, lane.dir * DIVE_SHOVE)


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
	velocity = Vector3(horizontal.x, (ground + HOVER - global_position.y) * CLIMB + maxf(0.0, _knock.y), horizontal.z)
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
	var prism := CylinderMesh.new()
	prism.radial_segments = 3
	prism.top_radius = SIZE
	prism.bottom_radius = SIZE
	prism.height = 0.22
	_body = MeshInstance3D.new()
	_body.mesh = prism
	_body.material_override = _material
	add_child(_body)
	var edge := CylinderMesh.new()
	edge.radial_segments = 3
	edge.top_radius = SIZE * 0.55
	edge.bottom_radius = SIZE * 0.55
	edge.height = 0.24
	_seam = MeshInstance3D.new()
	_seam.mesh = edge
	_seam.material_override = Palette.solid(Roster.ANCIENT_LIGHT, 2.2)
	_seam.position = Vector3.UP * 0.02
	add_child(_seam)
