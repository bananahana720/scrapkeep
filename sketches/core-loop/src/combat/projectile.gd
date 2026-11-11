extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The lobber's shell. Its landing ring is committed the moment it is fired, as a
# PROJECTILE threat: a reticle whose brackets close as the shell falls, under a dotted
# trace of the flight. The flight is solved exactly, so the shell flies the drawn trace
# and lands on the ring's centre at FLIGHT seconds, and the blast hurts only a ball the
# ring contains at that instant. Killing the lobber does not recall a shell
# already in the air; what was shown still lands.
#
# A shell can be batted: a bolt or a rolling ball that reaches it in flight sends it
# back at the lobber that fired it (bat()). The return is committed the same way, as
# a new ring, drawn in AMBER because it is yours now: it never hurts the player, and
# combat resolves its blast against every enemy the ring contains.

const GRAVITY := 26.0
const BLAST_RADIUS := 3.6
const DAMAGE := 12.0
const SHOVE := 5.0
const HIT_RADIUS := 0.9
const RETURN_FLIGHT := 0.9
# The first seconds of a covered flight in which the muzzle is clear of cover, and the collision layer
# terrain and landform bodies are on (Godot's default 1; the ball is alone on layer 2).
const COVER_CLEAR_SECONDS := 0.15
const COVER_MASK := 1
# How far above its ring's seat a hit still counts as the landing ground, not cover (metres).
const COVER_SEAT_BAND := 0.25
# The batting cue (LEGIBILITY section 6): while the ball could reach the landing point before
# the shell lands, the shell wears the will_break row's rim, and a rising ping sounds when the
# rim first lights. The ping is SfxBank's "vault_rise", the breathy rising sweep. Visual and
# sound only: the flight, the ring and combat's BAT_REACH are untouched.
const RIM_SIZE := 3.6
const RIM_PING := "vault_rise"
const RIM_PING_DB := -2.0

signal hit_player(amount: float, shove: Vector3)
signal exploded(at: Vector3, radius: float, hit: bool)
signal returned_landed(shell: Node3D)

var target
var terrain
var world_root: Node
var live := Callable()
var lobber: Node3D
var origin := Vector3.ZERO
var landing := Vector3.ZERO
var flight := 1.9
var launch := Vector3.ZERO
var ring: Node3D
var returned := false
# Whether terrain and landforms stop this shell in flight (the stage's hazard.shell_cover_by_stage, passed in
# by combat): a covered shell bursts harmlessly where its path meets static geometry short of its landing.
var covered := false
# Test seam: the rim and its ping off, nothing else changes.
var rim_cue_enabled := true
var pings := 0

# The shell's sphere, its glow and the rim's quad are the same for every shot and never written
# after, so they are made once, not per shot inside the lobber's physics step. The rim's material
# pulses per shot, so each shot keeps its own; the first one is held for the session, because
# freeing the last rim material frees its shader and the next shot compiled it again (about 5 ms
# on the 4080, in a lobber volley's physics tick).
static var _shell_mesh: SphereMesh
static var _shell_material: StandardMaterial3D
static var _rim_quad: QuadMesh
static var _held_rim: StandardMaterial3D

var _age := 0.0
var _rim: MeshInstance3D
var _rim_material: StandardMaterial3D
var _pinged := false
var _rim_clock := 0.0


# Fixed flight time turns the arc into one solve instead of an iterative aim.
static func lob_velocity(from: Vector3, to: Vector3, seconds: float) -> Vector3:
	var v := (to - from) / seconds
	v.y += 0.5 * GRAVITY * seconds
	return v


func setup(target_ref, terrain_ref, root_ref: Node, live_ref: Callable, from: Vector3, to: Vector3, seconds: float,
		lobber_ref: Node3D = null, cover_ref := false) -> void:
	covered = cover_ref
	target = target_ref
	terrain = terrain_ref
	world_root = root_ref
	live = live_ref
	lobber = lobber_ref
	origin = from
	landing = to
	flight = seconds
	launch = lob_velocity(from, to, seconds)
	add_to_group("enemy_shot")
	position = from
	if _shell_mesh == null:
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = 0.75
		_shell_mesh.height = 1.5
		_shell_material = Palette.solid(Palette.HAZARD, 3.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _shell_mesh
	mesh.material_override = _shell_material
	add_child(mesh)
	_build_rim()
	ring = Telegraph.ring(root_ref, terrain_ref, Threat.Type.PROJECTILE, to, BLAST_RADIUS)
	ring.set_flight(from, Threat.lob_bump(GRAVITY, seconds))


# Sends the shell back at its lobber, or back where it came from if the lobber is gone.
# Returns false for a shell already batted.
func bat() -> bool:
	if returned or _age >= flight:
		return false
	returned = true
	var home := origin
	if is_instance_valid(lobber) and not lobber.is_dead():
		home = lobber.global_position
	var to := Vector3(home.x, terrain.height(home.x, home.z), home.z)
	origin = position
	landing = to
	flight = RETURN_FLIGHT
	_age = 0.0
	launch = lob_velocity(origin, landing, flight)
	if is_instance_valid(ring):
		ring.queue_free()
	ring = Telegraph.ring(world_root, terrain, Threat.Type.PROJECTILE, to, BLAST_RADIUS, 3.5, Palette.AMBER)
	ring.set_flight(origin, Threat.lob_bump(GRAVITY, flight))
	return true


func _physics_process(delta: float) -> void:
	if live.is_valid() and not live.call():
		return
	var before := position
	_age = minf(_age + delta, flight)
	position = origin + launch * _age + Vector3.DOWN * 0.5 * GRAVITY * _age * _age
	if covered and not returned and _age < flight and _age > COVER_CLEAR_SECONDS and _burst_on_cover(before):
		return
	_step_rim(delta)
	if is_instance_valid(ring):
		ring.set_progress(_age / flight)
	if _age < flight:
		return
	if returned:
		returned_landed.emit(self)
		exploded.emit(landing, BLAST_RADIUS, false)
		queue_free()
		return
	var hit := false
	if is_instance_valid(ring) and target != null and ring.contains(target.ball_position()):
		hit = true
		var away: Vector3 = target.ball_position() - landing
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3.ZERO
		hit_player.emit(DAMAGE, away * SHOVE + Vector3.UP * 3.0)
	exploded.emit(landing, BLAST_RADIUS, hit)
	queue_free()


# Casts the step just flown against static geometry. A hit short of the landing ring bursts the shell
# there, harmlessly. Returns true when the shell is gone.
func _burst_on_cover(from: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(from, position, COVER_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var at: Vector3 = hit["position"]
	if Vector2(at.x - landing.x, at.z - landing.z).length() <= BLAST_RADIUS:
		return false
	# Cover stands above the ground the ring is seated on. A hit no higher than that seat is the shell meeting
	# its own landing ground (an arena floor raised over the aim point, say), so it flies on and lands.
	if is_instance_valid(ring) and at.y <= ring.center.y + COVER_SEAT_BAND:
		return false
	exploded.emit(at, BLAST_RADIUS, false)
	if is_instance_valid(ring):
		ring.queue_free()
	queue_free()
	return true


# Whether the ball can bat this shell: at cruise or faster (combat._bat_by_ball's floor), and at its
# planar speed it reaches the landing point before the shell lands.
func ball_can_reach() -> bool:
	if returned or target == null or _age >= flight or not target.has_method("planar_velocity"):
		return false
	if target.has_method("speed_tier") and target.speed_tier() < SpeedTier.CRUISE:
		return false
	var ball: Vector3 = target.ball_position()
	var heading: Vector3 = target.planar_velocity()
	var speed := Vector2(heading.x, heading.z).length()
	if speed < 0.01:
		return false
	var away := Vector2(ball.x - landing.x, ball.z - landing.z).length()
	return away / speed < flight - _age


func rim_on() -> bool:
	return rim_cue_enabled and ball_can_reach()


func rim_visible() -> bool:
	return _rim != null and _rim.visible


func rim_color() -> Color:
	var color := _rim_material.albedo_color
	color.a = 1.0
	return color


func _build_rim() -> void:
	_rim_material = Palette.solid(EventKinds.state_color("will_break"), 0.0, false)
	_rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_rim_material.no_depth_test = true
	_rim_material.albedo_texture = Icons.shape("ring")
	if _held_rim == null:
		_held_rim = _rim_material
	_rim = MeshInstance3D.new()
	_rim.name = "BatRim"
	if _rim_quad == null:
		_rim_quad = QuadMesh.new()
		_rim_quad.size = Vector2.ONE * RIM_SIZE
	_rim.mesh = _rim_quad
	_rim.material_override = _rim_material
	_rim.visible = false
	add_child(_rim)


func _step_rim(delta: float) -> void:
	var on := rim_on()
	_rim.visible = on
	if not on:
		_rim_clock = 0.0
		return
	var row := EventKinds.state_row("will_break")
	var color := EventKinds.state_color("will_break")
	if String(row.get("motion", "none")) == "pulse":
		_rim_clock += delta
		color.a = 0.8 + 0.2 * sin(TAU * 2.0 * _rim_clock)
	_rim_material.albedo_color = color
	if not _pinged:
		_pinged = true
		pings += 1
		_ping()


func _ping() -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = SfxBank.stream(RIM_PING)
	player.volume_db = SfxBank.trim_db(RIM_PING) + RIM_PING_DB
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _exit_tree() -> void:
	if is_instance_valid(ring):
		ring.queue_free()
