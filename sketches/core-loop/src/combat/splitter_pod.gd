extends "res://src/combat/counter.gd"

# A Splitter pod (roster_specials.gd): one torn-off pod of the Splitter (splitter.gd),
# budded off it or popped out of it when it is rammed. It chases the ball, and close in it
# lights a FUSE-second fuse that commits a ring round itself, then blows up. A ball still in
# the ring takes the blast; one that rolled out of it has found the trick. The spent husk
# sits out the shared recovery, then crumbles: that is no kill, so it pays and counts nothing
# (combat.gd skips record_kill for a "fuse" death).
# It asks the attacker budget before its fuse like every counter, and a pod destroyed
# before its blast pops like any enemy. Light enough (WEIGHT) for a grown ball to flail.

const Splitter := preload("res://src/combat/splitter.gd")
# The piece glb (PR #24), read through the Splitter's cache.
const BODY := "res://assets/models/world_one/enemy_splitter_piece.glb"

const HP := 40.0
const WEIGHT := 0.6
# The piece recipe's collider core (tools/blender/world_one/enemy_splitter_piece.py).
const BODY_RADIUS := 0.6
const BODY_HALF := 0.9
const WALK := 10.0
const BLAST_RADIUS := 4.5
const BLAST_RANGE := 3.5
const BLAST_DAMAGE := 12.0
const BLAST_SHOVE := 8.0
const FUSE := 1.0
const GLOW_IDLE := 1.0
const GLOW_FUSE := 5.0
const GLOW_SPENT := 0.1
# How long a spent husk stands after its recovery before it crumbles.
const CRUMBLE := 0.15

var blasts := 0
var spent := false
var _crumble := 0.0
var _ring_had_ball := false
var _glow: StandardMaterial3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 1
	weight = WEIGHT
	walk_speed = WALK
	keep_near = 0.0
	keep_far = 0.0
	attack_range = BLAST_RANGE
	warn_seconds = FUSE
	live_seconds = 0.05
	rest_seconds = 2.6
	first_rest = 0.5


# It runs straight at the ball, until it has blown.
func _roam(to_ball: Vector3) -> Vector3:
	if spent:
		return Vector3.ZERO
	var distance := to_ball.length()
	return to_ball / distance * walk_speed if distance > 0.5 else Vector3.ZERO


# The piece glb (PR #24) over the recipe's collider: the shell on fleet paint, which
# flashes, and the lit seam edges, which burn brighter as the fuse runs.
func _build_crew() -> void:
	radius = BODY_RADIUS
	half_height = BODY_HALF
	_add_capsule(BODY_RADIUS, BODY_HALF * 2.0, Palette.RUST).free()
	_glow = Palette.solid(Palette.AMBER, GLOW_IDLE)
	for part in Splitter.parts(BODY)["meshes"]:
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, _material if part.paint else _glow)
		_visual_parent().add_child(mi)
		if part.paint:
			_crew = mi
	_base_color = Color.WHITE
	_material.albedo_color = _base_color
	_material.vertex_color_use_as_albedo = true


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	var ring := _commit_ring(Threat.Type.INSTANT, global_position, BLAST_RADIUS, 2.2, Palette.HAZARD)
	_ring_had_ball = ring != null and ring.contains(_real_ball())
	return ring


func _go_live() -> void:
	blasts += 1
	var ring := telegraph()
	var ball := _real_ball()
	if ring != null and ring.contains(ball):
		var out: Vector3 = ball - global_position
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
		hit_player.emit(BLAST_DAMAGE, dir * BLAST_SHOVE + Vector3.UP * 3.0)
	elif ring != null and _ring_had_ball and fleet != null:
		fleet.discover("fuse_pod", ball)
	# Spent: from here a kill pays nothing, and it never fuses again.
	spent = true
	scrap_value = 0


func _wants_attack(to_ball: Vector3) -> bool:
	return not spent and super(to_ball)


func _physics_process(delta: float) -> void:
	super(delta)
	if not spent or _dead or phase != Phase.ROAM or recovering():
		return
	_crumble += delta
	if _crumble >= CRUMBLE:
		last_damage_source = "fuse"
		_die()


# E25 e25_pod_glow: the seam glow blinks faster and burns brighter as the fuse runs, then
# goes dark on the spent husk. It reads the counter's warn clock; no timer of its own.
func _pose() -> void:
	if _glow == null:
		return
	if spent:
		_glow.emission_energy_multiplier = GLOW_SPENT
		return
	var burn := clampf(_warn_progress(), 0.0, 1.0) if phase == Phase.WARN else 0.0
	var blink := 0.5 + 0.5 * sin(_t * TAU * FlashGuard.rate(lerpf(3.0, 10.0, burn)))
	_glow.emission_energy_multiplier = FlashGuard.spike(GLOW_IDLE, lerpf(GLOW_IDLE, GLOW_FUSE, burn * blink))
