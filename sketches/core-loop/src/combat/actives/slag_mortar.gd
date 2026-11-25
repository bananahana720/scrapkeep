extends RefCounted

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# Slag Mortar (Redjaw Workshops): a heavy kiln shell lobbed onto a committed ground ring.
# On impact it breaks soft destructibles (Destructibles.on_blast with +1 heft tier bonus),
# applies the heat element to trigger Steam Cloud / Flash Melt / heat fusions, and leaves
# a committed molten heat zone that ticks heat damage inside its shown radius.
# Note: keep every draw call strictly routed through ActiveFx.peak().

const RADIUS := 4.8
const BONUS_RADIUS := 0.45
const BASE_DAMAGE := 28.0
const ZONE_DAMAGE := 8.0
const ZONE_SECONDS := 3.5
const ZONE_INTERVAL := 0.5
const REACH_UP := 3.0
const LOCK_REACH := 24.0
const AHEAD := 10.0
const KNOCK := 10.0
const BLAST_TIER_BONUS := 1
const COLOR := Color("ff7a29")
const KIND := "slag_mortar"
const IMPACT := "cannon"
const SOURCE := "special"
const PROC_SOURCE := "item_proc"
const ELEMENT := "heat"

var ctx
var combat
# Committed wind-up ring waiting for fire(): {"ring": telegraph, "at": Vector3, "radius": float, "warn": float, "age": float}
var pending := {}
# Live lingering slag heat zones: {"ring": telegraph, "at": Vector3, "radius": float, "left": float, "tick": float, "damage": float, "source": String}
var zones: Array = []
var blasts := 0
var last_at := Vector3.ZERO


func setup(context, owner_combat) -> void:
	ctx = context
	combat = owner_combat


func clear() -> void:
	_free_pending()
	for z in zones:
		if is_instance_valid(z.get("ring")):
			z["ring"].queue_free()
	zones.clear()


func cancel() -> void:
	_free_pending()


func _free_pending() -> void:
	if not pending.is_empty() and is_instance_valid(pending.get("ring")):
		pending["ring"].queue_free()
	pending = {}


func radius_for(bonus: int) -> float:
	return RADIUS + BONUS_RADIUS * float(maxi(bonus, 0))


func impact_damage(scale := 1.0) -> float:
	var punch := 0.0
	if ctx != null and ctx.build != null and ctx.build.has_method("punch_bonus"):
		punch = float(ctx.build.punch_bonus())
	var mult := float(ctx.tuning.mod("weapon_damage")) if ctx != null and ctx.tuning != null else 1.0
	return (BASE_DAMAGE + punch) * mult * scale


func zone_damage(scale := 1.0) -> float:
	var mult := float(ctx.tuning.mod("weapon_damage")) if ctx != null and ctx.tuning != null else 1.0
	return ZONE_DAMAGE * mult * scale


func _target_spot() -> Vector3:
	var ball: Vector3 = ctx.player.ball_position()
	var near: Array = combat.nearest_enemies(ball, LOCK_REACH, 1)
	if not near.is_empty() and is_instance_valid(near[0]):
		return (near[0] as Node3D).global_position
	var forward: Vector3 = ctx.aim_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	return ball + forward * AHEAD


func begin(rack, row: Dictionary) -> void:
	_free_pending()
	var at := _target_spot()
	var r := radius_for(int(rack.bonus))
	var ring: Node3D = Telegraph.ring(ctx.root, combat.ground, Threat.Type.INSTANT, at, r, REACH_UP, COLOR)
	ring.set_progress(0.0)
	pending = {"ring": ring, "at": ring.center, "radius": r, "warn": maxf(float(row.get("windup", 0.35)), 0.05), "age": 0.0}
	combat.effects.spark(ring.center + Vector3.UP * 1.2, ActiveFx.peak(COLOR))


func fire(rack, row: Dictionary, bonus: int) -> int:
	return _launch(rack, row, bonus, 1.0, SOURCE)


func fire_echo(rack, row: Dictionary, bonus: int, scale := 0.75) -> int:
	return _launch(rack, row, bonus, scale, PROC_SOURCE)


func _launch(rack, row: Dictionary, bonus: int, scale: float, source_tag: String) -> int:
	var at := Vector3.ZERO
	var r := radius_for(bonus)
	var ring: Node3D = null
	if source_tag == SOURCE and not pending.is_empty() and is_instance_valid(pending.get("ring")):
		ring = pending["ring"]
		at = pending["at"]
		r = float(pending["radius"])
		pending = {}
	else:
		at = _target_spot()
		ring = Telegraph.ring(ctx.root, combat.ground, Threat.Type.INSTANT, at, r, REACH_UP, COLOR)
	ring.set_progress(1.0)
	blasts += 1
	last_at = at
	combat.effects.ring(at, r, ActiveFx.peak(COLOR))
	combat.effects.spark(at + Vector3.UP * 1.6, ActiveFx.peak(COLOR))
	if ctx.destructibles != null and is_instance_valid(ctx.destructibles) and ctx.destructibles.has_method("on_blast"):
		ctx.destructibles.on_blast(at, r, KIND, BLAST_TIER_BONUS)
	if ctx.has_method("break_props"):
		ctx.break_props(at, r, KIND)
	if ctx.build != null and ctx.build.has_method("apply_element"):
		ctx.build.apply_element(ELEMENT, at, PROC_SOURCE)
	elif ctx.build != null and ctx.build.get("field") != null:
		ctx.build.field.apply(ELEMENT, at, PROC_SOURCE)
	var dmg := impact_damage(scale)
	for enemy in combat.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not enemy.is_dead() and ring.contains(enemy.global_position):
			combat.deal_proc_hit(enemy, KIND, dmg, enemy.global_position - at, KNOCK, "", source_tag, IMPACT)
	zones.append({
		"ring": ring,
		"at": at,
		"radius": r,
		"left": ZONE_SECONDS,
		"tick": ZONE_INTERVAL,
		"damage": zone_damage(scale),
		"source": PROC_SOURCE,
	})
	return 1


func step(delta: float) -> void:
	if not pending.is_empty():
		var ring = pending.get("ring")
		if is_instance_valid(ring):
			pending["age"] = float(pending["age"]) + delta
			ring.set_progress(clampf(float(pending["age"]) / float(pending["warn"]), 0.0, 1.0))
		else:
			pending = {}
	if zones.is_empty():
		return
	var kept: Array = []
	for z in zones:
		var ring = z.get("ring")
		if not is_instance_valid(ring):
			continue
		z["left"] = float(z["left"]) - delta
		z["tick"] = float(z["tick"]) - delta
		if float(z["tick"]) <= 0.0:
			z["tick"] = ZONE_INTERVAL
			var at: Vector3 = z["at"]
			var r: float = float(z["radius"])
			combat.effects.ring(at, r, ActiveFx.peak(COLOR))
			if ctx.build != null and ctx.build.get("field") != null:
				ctx.build.field.apply(ELEMENT, at, PROC_SOURCE)
			for enemy in combat.get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(enemy) and not enemy.is_dead() and ring.contains(enemy.global_position):
					combat.deal_proc_hit(enemy, KIND, float(z["damage"]), enemy.global_position - at, 0.0, "", PROC_SOURCE, IMPACT)
		if float(z["left"]) > 0.0:
			kept.append(z)
		else:
			ring.queue_free()
	zones = kept
