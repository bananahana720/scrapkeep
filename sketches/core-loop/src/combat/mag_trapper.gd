extends "res://src/combat/counter.gd"

# The mag trapper (DESIGN-V2 section 10): a crew cart with a stack of pit discs on its
# back. It throws a disc at where the ball will be, and the disc's instant ring closes
# over the warning. Live, it is a magnetic pit: a ball inside it lighter than the
# disc's heft rating has its line pulled toward the centre, through the hold bound
# (holds.gd): the pull bends the path and never lowers the speed. Heft at or above the
# rating rolls straight through, so growing is the counter. A jump or a smash shatters
# the disc.

const PIT_RADIUS := 4.5
const PIT_REACH := 1.4
const LEAD := 0.7
const CENTRE_PULL := 2.5
const RATING_BASE := 1.6
const RATING_PER_THREAT := 0.4
const HP := 50.0

var rating := RATING_BASE
var _stack: Node3D
var _disc_material: StandardMaterial3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.2
	warn_seconds = 1.1
	live_seconds = 3.0
	rest_seconds = 3.5
	attack_range = 26.0
	rating = RATING_BASE + RATING_PER_THREAT * (threat - 1.0)


# C12 dressing (enemy_mag_trapper.glb). The counter's capsule crew is replaced by the glb's
# crew and cart (the collider _add_capsule laid stays), and the pit discs ride a pivot at the
# cart bed. The glb is read once; every trapper shares its meshes and adds its own flashing body and disc materials as
# surface overrides.
const TILT := 0.42
const SHUDDER := 0.012
const CORE_EMISSION := 0.6

static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "MagTrapperBody"
	_visual_parent().add_child(dress)
	var cart := MeshInstance3D.new()
	cart.name = "Cart"
	cart.mesh = parts["body"]
	cart.set_surface_override_material(parts["flash"], _material)
	dress.add_child(cart)
	_stack = Node3D.new()
	_stack.name = "MagStack"
	_stack.position = parts["pivot"]
	dress.add_child(_stack)
	var discs := MeshInstance3D.new()
	discs.name = "MagDiscs"
	discs.mesh = parts["discs"]
	_disc_material = Palette.solid(Color.WHITE)
	_disc_material.vertex_color_use_as_albedo = true
	discs.set_surface_override_material(parts["disc_paint"], _disc_material)
	_stack.add_child(discs)


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_mag_trapper.glb") as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var core := Palette.solid(Palette.HAZARD, CORE_EMISSION)
	var flash := 0
	var disc_paint := 0
	var meshes := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var slot := mesh.surface_get_material(i).resource_name
			if slot == "fleet_paint":
				flash = i
			elif slot == "paint" and node.name == "MagDiscs":
				disc_paint = i
			mesh.surface_set_material(i, core if slot == "class_accent" else (painted if slot == "paint" else charcoal))
		meshes[node.name] = mesh
	_shared = {"body": meshes["MagTrapperBody"], "discs": meshes["MagDiscs"], "flash": flash, "disc_paint": disc_paint,
		"pivot": (scene.find_child("MagStack", true, false) as Node3D).position}
	scene.free()
	return _shared


# The discs' own material answers the hit event the body's does: enemy.flash() sets _flash,
# the base decays it, and this mirrors the same amber pulse on the discs and settles them to plain white at rest
# (the discs carry no plating tint).
func _update_flash(delta: float) -> void:
	super(delta)
	if _disc_material == null:
		return
	_disc_material.albedo_color = Color.WHITE.lerp(Color(1.0, 1.0, 0.85), _flash)
	_disc_material.emission_enabled = _flash > 0.0
	_disc_material.emission = Palette.AMBER
	_disc_material.emission_energy_multiplier = _flash * 2.0


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	_facing(aim - global_position)
	return _commit_ring(Threat.Type.INSTANT, aim, PIT_RADIUS, PIT_REACH)


func _live(_delta: float) -> bool:
	var pit := telegraph()
	if pit == null:
		return false
	var player = _player()
	var ball := _real_ball()
	if not pit.contains(ball) or player.heft() >= rating:
		if _holding():
			_release("left")
		return true
	if not _holding() and not _catch():
		return true
	var to_centre: Vector3 = pit.center - ball
	to_centre.y = 0.0
	_pull(to_centre * CENTRE_PULL)
	return true


# The wind-up cocks the stack back on its pivot, easing with the warning's own progress
# (WARN phase, _warn_progress()); it reads that clock and adds none. The discs are hidden
# while the pit is live (the thrown disc has left), and come back upright.
func _pose() -> void:
	if _stack == null:
		return
	_stack.visible = phase != Phase.LIVE
	match phase:
		Phase.WARN:
			var t := clampf(_warn_progress(), 0.0, 1.0)
			_stack.rotation.x = -TILT * t * t * (3.0 - 2.0 * t) + sin(_t * 38.0) * SHUDDER * t
		Phase.LIVE:
			_stack.rotation.x = 0.0
		_:
			_stack.rotation.x = lerpf(_stack.rotation.x, 0.0, 1.0 - exp(-10.0 * get_physics_process_delta_time()))
