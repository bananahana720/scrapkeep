extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

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

var _age := 0.0


# Fixed flight time turns the arc into one solve instead of an iterative aim.
static func lob_velocity(from: Vector3, to: Vector3, seconds: float) -> Vector3:
	var v := (to - from) / seconds
	v.y += 0.5 * GRAVITY * seconds
	return v


func setup(target_ref, terrain_ref, root_ref: Node, live_ref: Callable, from: Vector3, to: Vector3, seconds: float,
		lobber_ref: Node3D = null) -> void:
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
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	mesh.mesh = sphere
	mesh.material_override = Palette.solid(Palette.HAZARD, 3.0)
	add_child(mesh)
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
	_age = minf(_age + delta, flight)
	position = origin + launch * _age + Vector3.DOWN * 0.5 * GRAVITY * _age * _age
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


func _exit_tree() -> void:
	if is_instance_valid(ring):
		ring.queue_free()
