extends "res://src/combat/actives/active_base.gd"

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Elements := preload("res://src/build/elements.gd")

const RADIUS := 8.0
const BONUS_RADIUS := 0.65
const PULL_SECONDS := 0.55
const PULL_SPEED := 11.0
const BASE_DAMAGE := 26.0
const REACH_UP := 3.5
const LOCK_REACH := 24.0
const AHEAD := 9.0
const KNOCK := 6.0
const COLOR := Palette.ARC
const KIND := "magnet_sling"
const IMPACT := "ram"
const SOURCE := "item_proc"

var buoys: Array = []
var snaps := 0
var total_pulled := 0


func clear() -> void:
	for b in buoys:
		if is_instance_valid(b.get("ring")):
			b["ring"].queue_free()
	buoys.clear()


func cancel() -> void:
	clear()


func radius_for(bonus: int) -> float:
	return RADIUS + BONUS_RADIUS * float(maxi(bonus, 0))


func snap_damage(scale := 1.0) -> float:
	return scaled_damage(BASE_DAMAGE) * scale


func _anchor_spot() -> Vector3:
	var ball: Vector3 = ctx.player.ball_position()
	var near: Array = combat.nearest_enemies(ball, LOCK_REACH, 1)
	if not near.is_empty() and is_instance_valid(near[0]):
		return (near[0] as Node3D).global_position
	return ball + flat_aim() * AHEAD


func fire(rack, row: Dictionary, bonus: int) -> int:
	return _deploy(bonus, 1.0)


func fire_echo(_rack, _row: Dictionary, bonus: int, scale := 0.75) -> int:
	return _deploy(bonus, scale)


func _deploy(bonus: int, scale: float) -> int:
	var at := _anchor_spot()
	var r := radius_for(bonus)
	var ring: Node3D = Telegraph.ring(ctx.root, combat.ground, Threat.Type.INSTANT, at, r, REACH_UP, COLOR)
	ring.set_progress(0.0)
	combat.effects.ring(ring.center, r, ActiveFx.peak(COLOR))
	combat.effects.spark(ring.center + Vector3.UP * 1.4, ActiveFx.peak(COLOR))
	buoys.append({
		"ring": ring,
		"at": ring.center,
		"radius": r,
		"left": PULL_SECONDS,
		"damage": snap_damage(scale),
		"pulled": 0,
	})
	return 1


func step(delta: float) -> void:
	if buoys.is_empty():
		return
	var kept: Array = []
	for b in buoys:
		var ring = b.get("ring")
		if not is_instance_valid(ring):
			continue
		b["left"] = float(b["left"]) - delta
		var progress := clampf(1.0 - maxf(0.0, float(b["left"])) / PULL_SECONDS, 0.0, 1.0)
		ring.set_progress(progress)
		var at: Vector3 = b["at"]
		var r: float = float(b["radius"])
		for enemy in combat.get_tree().get_nodes_in_group(Groups.ENEMY):
			if not is_instance_valid(enemy) or enemy.is_dead():
				continue
			if not ring.contains(enemy.global_position):
				continue
			var enemy_kind := String(enemy.get("kind")) if enemy.get("kind") != null else ""
			if enemy_kind in Elements.BOSS_KINDS:
				continue
			var to_center := Vector3(at.x - enemy.global_position.x, 0.0, at.z - enemy.global_position.z)
			var dist := to_center.length()
			if dist > 0.6:
				var move := minf(dist - 0.5, PULL_SPEED * delta)
				enemy.global_position += to_center.normalized() * move
				b["pulled"] = int(b["pulled"]) + 1
				total_pulled += 1
				combat.effects.arc(at + Vector3.UP * 0.8, enemy.global_position + Vector3.UP * 0.6, ActiveFx.peak(COLOR))
		if float(b["left"]) <= 0.0:
			_snap(b)
			ring.queue_free()
		else:
			kept.append(b)
	buoys = kept


func _snap(b: Dictionary) -> void:
	snaps += 1
	var ring = b["ring"]
	var at: Vector3 = b["at"]
	var r: float = float(b["radius"])
	var dmg: float = float(b["damage"])
	combat.effects.ring(at, r, ActiveFx.peak(COLOR))
	combat.effects.spark(at + Vector3.UP * 1.2, ActiveFx.peak(COLOR))
	for enemy in combat.get_tree().get_nodes_in_group(Groups.ENEMY):
		if is_instance_valid(enemy) and not enemy.is_dead() and ring.contains((enemy as Node3D).global_position):
			var inward: Vector3 = at - (enemy as Node3D).global_position
			inward.y = 0.0
			combat.deal_proc_hit(enemy, KIND, dmg, inward, KNOCK, "", SOURCE, IMPACT)
