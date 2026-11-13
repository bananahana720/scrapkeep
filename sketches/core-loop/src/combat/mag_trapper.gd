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
var windup_pose_enabled := true # Test seam: presentation only.
var _stack: Node3D
var _body: MeshInstance3D
var _top_disc: MeshInstance3D
var _top_rest := Vector3.ZERO
var _disc_material: StandardMaterial3D
var _top_link: MeshInstance3D


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
const BODY_LEAN := 0.22
const HOIST := 1.4
const SPIN := TAU * 1.25
const CORE_EMISSION := 0.6
# The mast that links the stack to the lifted disc, in stack space: its foot sits in the stack's
# top disc (the top face is at y 0.6) and its head in the lifted disc, so the disc never hangs free.
const LINK_FOOT := 0.5
const LINK_RADIUS := 0.16

static var _warned_asset := false
static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "MagTrapperBody"
	_visual_parent().add_child(dress)
	_body = MeshInstance3D.new()
	_body.name = "Cart"
	_body.mesh = parts["body"]
	_body.set_surface_override_material(parts["flash"], _material)
	dress.add_child(_body)
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
	_top_disc = MeshInstance3D.new()
	_top_disc.name = "MagTopDisc"
	_top_disc.mesh = parts["top"]
	_top_rest = parts["top_position"]
	_top_disc.position = _top_rest
	_top_disc.set_surface_override_material(parts["top_paint"], _disc_material)
	_stack.add_child(_top_disc)
	var mast := CylinderMesh.new()
	mast.top_radius = LINK_RADIUS
	mast.bottom_radius = LINK_RADIUS
	mast.height = 1.0
	mast.radial_segments = 8
	mast.rings = 1
	_top_link = MeshInstance3D.new()
	_top_link.name = "MagTopLink"
	_top_link.mesh = mast
	_top_link.material_override = Palette.solid(Palette.CHARCOAL)
	_stack.add_child(_top_link)


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
	var top_paint := 0
	var meshes := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("mag_trapper: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				flash = i
			elif slot == "paint" and node.name == "MagDiscs":
				disc_paint = i
			elif slot == "paint" and node.name == "MagTopDisc":
				top_paint = i
			mesh.surface_set_material(i, core if slot == "class_accent" else (painted if slot == "paint" else charcoal))
		meshes[node.name] = mesh
	_shared = {"body": meshes["MagTrapperBody"], "discs": meshes["MagDiscs"], "flash": flash, "disc_paint": disc_paint,
		"top": meshes["MagTopDisc"], "top_paint": top_paint,
		"top_position": (scene.find_child("MagTopDisc", true, false) as Node3D).position,
		"pivot": (scene.find_child("MagStack", true, false) as Node3D).position}
	scene.free()
	return _shared


# The discs' own material answers the hit event the body's does: enemy.flash() sets _flash,
# the base decays it, and this mirrors the same neutral pulse on the discs and settles them to plain white at rest
# (the discs carry no plating tint). The release flash (FX-05) reaches the discs the same way.
func _update_flash(delta: float) -> void:
	super(delta)
	if _disc_material == null:
		return
	if strike_flashing():
		_show_strike(_disc_material, Color.WHITE)
		return
	_disc_material.albedo_color = Color.WHITE.lerp(Color(1.0, 1.0, 0.85), FlashGuard.whiten(_flash))
	_disc_material.emission_enabled = _flash > 0.0
	_disc_material.emission = EventKinds.role_color("neutral")
	_disc_material.emission_energy_multiplier = FlashGuard.spike(0.0, _flash * 2.0)


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
		if pit.contains(ball) and fleet != null:
			fleet.discover("heavy_roll", ball)
		return true
	if not _holding() and not _catch():
		return true
	var to_centre: Vector3 = pit.center - ball
	to_centre.y = 0.0
	_pull(to_centre * CENTRE_PULL)
	return true


func _on_broken(_method: String) -> void:
	if fleet != null:
		fleet.discover("heavy_roll", _real_ball())


# E05 e05_stack_hoist: one disc rises clear and accelerates its spin on WARN's clock.
# Counter resets _t before calling _pose on release: LIVE at _t == 0 is that same
# endpoint, with the thrown disc hidden. No independent clock or pivot transform writes.
func _pose() -> void:
	if _top_disc == null:
		return
	var t := 0.0
	if windup_pose_enabled and not is_dead() and not is_queued_for_deletion():
		if phase == Phase.WARN:
			t = clampf(_warn_progress(), 0.0, 1.0)
		elif phase == Phase.LIVE and _t == 0.0:
			t = 1.0
	var raised := t * t * (3.0 - 2.0 * t)
	_body.rotation.x = -BODY_LEAN * raised
	_top_disc.position = _top_rest + Vector3.UP * HOIST * raised
	_top_disc.rotation.y = SPIN * t * t
	# The mast runs from the stack to the disc's centre and goes with the disc when it is thrown.
	var head := _top_disc.position.y
	_top_link.scale = Vector3(1.0, maxf(head - LINK_FOOT, 0.0001), 1.0)
	_top_link.position = Vector3(_top_disc.position.x, (head + LINK_FOOT) * 0.5, _top_disc.position.z)
	_top_disc.visible = not windup_pose_enabled or phase != Phase.LIVE or is_dead() or is_queued_for_deletion()
	_top_link.visible = _top_disc.visible
