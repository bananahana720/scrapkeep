extends Node

# A stand-in for combat's spawner, so the spine tests can check the Warden gate, the
# objective and the crush pass-through without depending on writer A's module. It
# follows A's plating rule from DEMO-SPEC: ball contacts punch for heft times their
# force, weapons punch for their damage, a hit below plating chips 20%. It lives in a
# subfolder so the smoke runner does not run it as a test.

const STRIKE_DAMAGE := {
	"stomp": [30.0, 1.1],
	"ram": [14.0, 1.3],
	"slam": [0.0, 1.2],
}
const CRUISE_TIER := 1
const CHASER_HP := 80.0

var ctx
var strikes: Array[Dictionary] = []
# A test can hold deaths back to model a spawner that records the kill late; the
# contract says the kill is recorded on the tick HP reaches 0, and flow must not open
# the gates early if one does not.
var delay_deaths := false
var _pending: Array[Node3D] = []


class DoubleEnemy:
	extends CharacterBody3D

	var kind := ""
	var hp := 1.0
	var max_hp := 1.0
	var plating := 0.0
	var dead := false
	var knocks := 0

	func knock(_direction: Vector3, _force: float) -> void:
		knocks += 1

	func flash() -> void:
		pass


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "SpawnerDouble"


func spawn_enemy(kind: String, at: Vector3, _affix_id := "") -> Node3D:
	var enemy := DoubleEnemy.new()
	enemy.kind = kind
	var def: Dictionary = ctx.flow.stage_def()
	match kind:
		"warden":
			enemy.max_hp = def["warden_hp"]
			enemy.plating = def["warden_plating"]
		_:
			enemy.max_hp = CHASER_HP
	enemy.hp = enemy.max_hp
	enemy.add_to_group("enemy")
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.set_collision_layer_value(3, true)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 3.0
	shape.shape = capsule
	enemy.add_child(shape)
	ctx.root.add_child(enemy)
	enemy.global_position = at + Vector3.UP * 1.5
	ctx.events.enemy_spawned.emit(enemy, kind)
	return enemy


func punch_of(kind: String, force: float) -> float:
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		return (row[0] + force * row[1]) * ctx.run.heft()
	return force


func strike(enemy: Node3D, kind: String, force: float) -> void:
	if not is_instance_valid(enemy) or enemy.dead:
		return
	var punch := punch_of(kind, force)
	var plating := plating_of(enemy)
	strikes.append({"kind": kind, "force": force, "punch": punch, "plating": plating})
	ctx.events.enemy_struck.emit(enemy, kind, force)
	var amount := punch
	if punch < plating:
		amount = 0.2 * punch
		ctx.events.strike_deflected.emit(enemy, kind, punch, plating)
	enemy.hp -= amount
	if enemy.hp <= 0.0:
		enemy.dead = true
		if delay_deaths:
			_pending.append(enemy)
		else:
			_die(enemy)


func finish_pending() -> void:
	for enemy in _pending:
		if is_instance_valid(enemy):
			_die(enemy)
	_pending.clear()


func _die(enemy: Node3D) -> void:
	ctx.run.record_kill(enemy.kind, enemy.global_position, 0)
	enemy.queue_free()


func punch_now() -> float:
	var speed: float = ctx.player.planar_velocity().length()
	return punch_of("ram", speed) if ctx.player.speed_tier() >= CRUISE_TIER else 0.0


func plating_of(enemy: Node3D) -> float:
	return enemy.plating if is_instance_valid(enemy) else 0.0


func integrity_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 1.0
	return clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)


func would_crush(enemy: Node3D, kind: String, force: float) -> bool:
	if not is_instance_valid(enemy) or enemy.dead:
		return false
	return plating_of(enemy) == 0.0 and punch_of(kind, force) >= enemy.hp
