extends Node

# A stand-in for combat's spawner that follows its enemy protocol and plating rule
# (src/combat/README.md on proto/core-loop-combat), so the boss tests run on any base.
# strike() resolves through the target's contact_part, plating_for and hit_mult: a punch
# at or above the plating lands in full times the multiplier, below it chips 20% and
# publishes strike_deflected. It spawns lobbers as inert markers and nothing else.

const STRIKE_DAMAGE := {
	"stomp": [30.0, 1.1],
	"ram": [14.0, 1.3],
	"slam": [0.0, 1.2],
}
const CONTACT_KINDS := ["stomp", "ram", "slam"]
const CHIP := 0.2
const CRUISE_TIER := 1

var ctx
# A test sets this to fix punch_now(); below zero it is the ram punch at the ball's speed.
var punch_override := -1.0
var strikes: Array[Dictionary] = []
var spawned: Array[Node3D] = []


class Marker:
	extends Node3D

	var kind := "lobber"
	var hp := 26.0
	var max_hp := 26.0
	var plating := 0.0
	var radius := 1.0
	var half_height := 1.0
	# The ground combat's lobbers aim at, as combat's enemy.gd has it.
	var terrain

	func is_dead() -> bool:
		return false

	func knock(_direction: Vector3, _force: float) -> void:
		pass

	func flash() -> void:
		pass

	func take_damage(amount: float) -> float:
		hp -= amount
		return amount


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "BossSpawnerDouble"


func spawn_enemy(kind: String, at: Vector3, _affix_id := "") -> Node3D:
	if kind != "lobber":
		return null
	var marker := Marker.new()
	marker.add_to_group("enemy")
	ctx.root.add_child(marker)
	marker.global_position = at
	spawned.append(marker)
	ctx.events.enemy_spawned.emit(marker, kind)
	return marker


func punch_of(kind: String, force: float) -> float:
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		return (row[0] + force * row[1]) * ctx.run.heft()
	return force


# The force a contact of this kind needs to punch exactly `punch` at the current heft.
func force_for(kind: String, punch: float) -> float:
	var row: Array = STRIKE_DAMAGE[kind]
	return (punch / ctx.run.heft() - row[0]) / row[1]


func resolve(enemy: Node3D, kind: String, force: float, part := "") -> Dictionary:
	if part == "" and kind in CONTACT_KINDS and enemy.has_method("contact_part"):
		part = enemy.contact_part(ctx.player.ball_position(), kind)
	var punch := punch_of(kind, force)
	var plating: float = enemy.plating_for(kind, part) if enemy.has_method("plating_for") else 0.0
	var full := punch >= plating
	var mult: float = enemy.hit_mult(kind, part) if full and enemy.has_method("hit_mult") else 1.0
	return {"punch": punch, "plating": plating, "full": full, "dealt": punch * mult if full else punch * CHIP, "part": part}


func strike(enemy: Node3D, kind: String, force: float, part := "") -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	var result := resolve(enemy, kind, force, part)
	strikes.append({"enemy": enemy, "kind": kind, "force": force, "result": result})
	ctx.events.enemy_struck.emit(enemy, kind, force)
	if not result["full"]:
		ctx.events.strike_deflected.emit(enemy, kind, result["punch"], result["plating"])
	if enemy.has_method("on_struck"):
		enemy.on_struck(kind, result["part"], result)
	enemy.take_damage(result["dealt"])


func punch_now() -> float:
	if punch_override >= 0.0:
		return punch_override
	if ctx.player.speed_tier() < CRUISE_TIER:
		return 0.0
	return punch_of("ram", ctx.player.planar_velocity().length())


func plating_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy) or not enemy.has_method("plating_now"):
		return 0.0
	return enemy.plating_now()


func integrity_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 1.0
	return clampf(float(enemy.get("hp")) / maxf(0.001, float(enemy.get("max_hp"))), 0.0, 1.0)


func would_crush(enemy: Node3D, kind: String, force: float) -> bool:
	if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
		return false
	var result := resolve(enemy, kind, force)
	return result["plating"] <= 0.0 and result["dealt"] >= float(enemy.get("hp"))
