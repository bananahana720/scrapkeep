extends "res://src/combat/actives/active_base.gd"

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")

const RINGS := 3
const RADIUS := 3.0
const BASE_DAMAGE := 30.0
const FALL := 0.45
const LOCK_REACH := 30.0
const AHEAD := 9.0
const SPREAD := 6.5
const KNOCK := 12.0
const CHAIN_RANGE := 8.0
const CHAIN_FALLOFF := 0.7
const COLOR := Palette.AMBER
const KIND := "silo"
const IMPACT := "cannon"
const SOURCE := "special"

var rings: Array = []
var falling := -1.0
var strikes := 0
var _bonus_at_begin := 0
var _age := 0.0
var _warn := 0.0


func clear() -> void:
	for entry in rings:
		if is_instance_valid(entry["ring"]):
			entry["ring"].queue_free()
	rings.clear()
	falling = -1.0


func cancel() -> void:
	clear()


func heft_class() -> int:
	if ctx.run == null:
		return 1
	if combat.heft_override >= 0.0:
		return ctx.run.raw_heft_class(combat.heft())
	return ctx.run.heft_class()


func count_for(bonus: int) -> int:
	return RINGS + maxi(0, heft_class() - 1) + pattern_level("cross_split") + bonus


func damage() -> float:
	return scaled_damage(BASE_DAMAGE)


func begin(rack, row: Dictionary) -> void:
	if falling >= 0.0:
		_land()
	clear()
	_bonus_at_begin = int(rack.bonus)
	_warn = float(row.get("windup", 0.0)) + FALL
	_age = 0.0
	for at in _centres(count_for(_bonus_at_begin)):
		var ring: Node3D = Telegraph.ring(ctx.root, combat.ground, Threat.Type.INSTANT, at, RADIUS, 3.5, COLOR)
		rings.append({"ring": ring, "at": ring.center, "shells": 1})


func fire(rack, row: Dictionary, bonus: int) -> int:
	if rings.is_empty():
		begin(rack, row)
	for i in maxi(0, bonus - _bonus_at_begin):
		rings[i % rings.size()]["shells"] += 1
	falling = FALL
	var shells := 0
	for entry in rings:
		shells += int(entry["shells"])
		combat.effects.spark(entry["at"] + Vector3.UP * 6.0, ActiveFx.peak(COLOR))
	return shells


func step(delta: float) -> void:
	if rings.is_empty():
		return
	_age += delta
	for entry in rings:
		if is_instance_valid(entry["ring"]):
			entry["ring"].set_progress(_age / maxf(_warn, 0.001))
	if falling < 0.0:
		return
	falling -= delta
	if falling <= 0.0:
		_land()


func _land() -> void:
	var dmg := damage()
	var jumps := pattern_level("chain_arc")
	for entry in rings:
		var ring = entry["ring"]
		if not is_instance_valid(ring):
			continue
		var at: Vector3 = entry["at"]
		combat.effects.ring(at, RADIUS, ActiveFx.peak(COLOR))
		ctx.break_props(at, RADIUS, "silo_battery")
		var inside: Array = []
		for enemy in combat.get_tree().get_nodes_in_group("enemy"):
			if not enemy.is_dead() and ring.contains(enemy.global_position):
				inside.append(enemy)
		for shell in int(entry["shells"]):
			strikes += 1
			for enemy in inside:
				if enemy.is_dead():
					continue
				combat._hit(enemy, KIND, dmg, enemy.global_position - at, KNOCK, "", SOURCE, IMPACT)
				if jumps > 0:
					combat._chain(enemy, enemy.global_position, {"damage": dmg, "chain_jumps": jumps, "chain_range": CHAIN_RANGE,
						"chain_falloff": CHAIN_FALLOFF, "color": ActiveFx.peak(COLOR), "kind": KIND, "knock": KNOCK, "source": SOURCE})
	clear()


func _centres(count: int) -> Array:
	var ball: Vector3 = ctx.player.ball_position()
	var out: Array = []
	for target in combat._nearest_list(ball, LOCK_REACH, count):
		out.append(target.global_position)
	var forward := flat_aim()
	var side := forward.cross(Vector3.UP).normalized()
	for i in count - out.size():
		var across := float(i % 3 - 1) * SPREAD
		var out_by := AHEAD + float(i / 3) * SPREAD
		out.append(ball + forward * out_by + side * across)
	return out
