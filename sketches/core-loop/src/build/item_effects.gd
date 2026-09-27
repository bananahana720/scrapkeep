extends RefCounted

const Triggers := preload("res://src/build/triggers.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Palette := preload("res://src/core/palette.gd")
const ElementField := preload("res://src/build/element_field.gd")

# What held items do (v2 W4 loot). refresh() folds the part list into two tables: the
# passive numbers (charges, cooldowns, damage taken, prices, perks) and, per trigger
# kind, the items that answer it. resolve() answers one commitment inside a trigger
# pass (triggers.gd); it only strikes, knocks, grants and heals through the seams the
# build already uses, so an item can never do what a part could not.
#
# The effect ids are a closed table (EFFECTS). Each names the number its copies stack
# (STACK_KEY) under the part's stack rule; a row naming an id outside the table fails
# the catalogue test, never the run.

# A slot's hard ceiling on stocked charges, items and Moss's cells together.
const MAX_CHARGES := 4
const SLOTS := ["weapon", "movement", "special", "smash"]
# The weapon's per-hit damage items scale from (build_sheet.BASE_HIT).
const BASE_HIT := 14.0
const EFFECTS := {
	"zap": "chance", "burst": "chance", "extra_hit": "chance", "speed": "gain", "air_jump": "",
	"grant_charge": "", "pin_bonus": "bonus", "pin_chain": "count", "ballast": "", "rebound_crit": "",
	"relaunch_pin": "", "scrap_burst": "chance", "echo_release": "chance", "cloak_extend": "seconds",
	"domino": "chance", "arm_hit": "bonus", "rebound_strike": "mult", "last_word": "bonus",
	"vault_cooldown": "per", "vault_charges": "count", "dash": "speed", "return_arc": "share",
	"damage_reduction": "per", "heal_back": "chance", "brace": "share", "hp_per_mass": "per", "floor_hp": "",
	"bonus_scrap": "chance", "ping": "", "price_scale": "per", "perk": "", "drone": "chance",
	"slot_cooldown": "per", "overcharge": "damage",
}
const PASSIVE_EFFECTS := ["slot_cooldown", "damage_reduction", "price_scale", "hp_per_mass", "perk", "ballast",
	"vault_cooldown", "vault_charges"]
const DOMINO_MAX_PER_WINDOW := 3
const PING_RADIUS := 9.0

var build
# id -> copies held.
var copies := {}
# kind -> [{id, def, copies, index}], in the order the items were first taken.
var by_kind := {}
var timed: Array = []
var charges := {}
var cooldown_scale := {}
var damage_reduction := 0.0
var price_scale := 1.0
var hp_per_mass := 0.0
var hp_mass_step := 50.0
var hp_mass_cap := 0.0
var perks := {}
var vault_cooldown_scale := 1.0
var vault_charges := 0
# Numbers the fuzzer and the tests read.
var procs := {}

var _clock := 0.0
var _ready_at := {}
var _timers := {}
var _armed_hit := 0.0
var _pin_until := {}
var _pins: Array = []
var _recent_pins: Array = []
var _rebounds: Array[float] = []
var _last_word_used := false
var _ward_used := false
var _brace_until := 0.0
var _brace_share := 0.0
var _brace_source := ""
var _drone_until := 0.0
var _drone_magnet := 1.0
var _domino_marks := {}
var _domino_count := 0


func _init(build_ref) -> void:
	build = build_ref


static func stack_key(effect_id: String) -> String:
	return EFFECTS.get(effect_id, "")


# The effect's stacked number for this many copies under the part's rule.
static func stacked(d: Resource, key: String, n: int) -> float:
	if key == "" or not d.effect.has(key):
		return 0.0
	return PartDef.Stacking.value(d.stack_rule, float(d.effect[key]), n, d.stack_cap)


func refresh(held: Array) -> void:
	copies = {}
	var order: Array = []
	for part_id in held:
		if not copies.has(part_id):
			order.append(part_id)
		copies[part_id] = copies.get(part_id, 0) + 1
	by_kind = {}
	timed = []
	charges = {}
	cooldown_scale = {}
	damage_reduction = 0.0
	price_scale = 1.0
	hp_per_mass = 0.0
	hp_mass_cap = 0.0
	perks = {}
	vault_cooldown_scale = 1.0
	vault_charges = 0
	var index := 0
	for part_id in order:
		var d: Resource = Parts.def(part_id)
		if d == null:
			continue
		var n: int = copies[part_id]
		for slot in d.charges:
			var add: float = PartDef.Stacking.value(d.stack_rule, float(d.charges[slot]), n, d.stack_cap)
			charges[slot] = charges.get(slot, 0) + int(add)
		var effect_id: String = d.effect.get("do", "")
		match effect_id:
			"slot_cooldown":
				var slot: String = d.effect.get("slot", "special")
				cooldown_scale[slot] = cooldown_scale.get(slot, 1.0) * (1.0 - stacked(d, "per", n))
			"damage_reduction":
				damage_reduction = 1.0 - (1.0 - damage_reduction) * (1.0 - stacked(d, "per", n))
			"price_scale":
				price_scale *= maxf(0.5, 1.0 - stacked(d, "per", n))
			"hp_per_mass":
				hp_per_mass += stacked(d, "per", n)
				hp_mass_step = d.effect.get("mass", 50.0)
				hp_mass_cap = maxf(hp_mass_cap, d.effect.get("cap_hp", 40.0))
			"perk":
				perks[d.effect.get("perk", "")] = true
			"vault_cooldown":
				vault_cooldown_scale *= maxf(0.2, 1.0 - stacked(d, "per", n))
			"vault_charges":
				vault_charges += int(stacked(d, "count", n))
		if d.trigger == "":
			continue
		var entry := {"id": part_id, "def": d, "copies": n, "index": index}
		index += 1
		if d.trigger == "timed":
			timed.append(entry)
			_timers[part_id] = _timers.get(part_id, 0.0)
		var kind := Triggers.kind_of(d.trigger)
		var list: Array = by_kind.get(kind, [])
		list.append(entry)
		by_kind[kind] = list


# Charges and cooldowns onto the ball's ability state. A raised cap arrives stocked:
# Moss's "second cell's in" means a charge you can spend now. The vault kick is not a
# slot; its two items reach it only through the ball's seams, when they exist.
func apply_abilities(player) -> void:
	if player == null or player.get("abilities") == null:
		return
	var abilities = player.abilities
	if player.has_method("set_vault_cooldown_scale"):
		player.set_vault_cooldown_scale(vault_cooldown_scale)
	if player.has_method("set_vault_charges"):
		player.set_vault_charges(1 + vault_charges)
	for slot in SLOTS:
		var s = abilities.slot(slot)
		var want: int = clampi(1 + int(charges.get(slot, 0)), 1, MAX_CHARGES)
		var before: int = s.max_charges
		abilities.set_max_charges(slot, want)
		if want > before:
			abilities.grant(slot, want - before)
		abilities.set_cooldown_scale(slot, cooldown_scale.get(slot, 1.0))


# Extra health from scrap_armor for this much mass.
func mass_health(mass: float) -> float:
	if hp_per_mass <= 0.0:
		return 0.0
	return minf(hp_mass_cap, floorf(mass / hp_mass_step) * hp_per_mass)


func reset_stage() -> void:
	_ready_at = {}
	_armed_hit = 0.0
	_pin_until = {}
	_pins.clear()
	_recent_pins.clear()
	_rebounds.clear()
	_ward_used = false
	_brace_until = 0.0
	_drone_until = 0.0
	_domino_marks = {}
	_domino_count = 0
	for key in _timers:
		_timers[key] = 0.0


func reset_run() -> void:
	reset_stage()
	_last_word_used = false
	procs = {}


func magnet_boost() -> float:
	return _drone_magnet if _clock < _drone_until else 1.0


# Timed items post a TIMED commitment on their own clock; the pass then answers only
# that item (the commitment's source is its id).
func tick(delta: float, bus) -> void:
	_clock += delta
	for entry in timed:
		var every: float = entry["def"].effect.get("every", 10.0)
		var t: float = _timers.get(entry["id"], 0.0) + delta
		if t >= every:
			t -= every
			bus.post(Triggers.Commitment.new(Triggers.Kind.TIMED, entry["id"], Triggers.DISCRETE_PROC,
				build.ctx.player.ball_position()))
		_timers[entry["id"]] = t
	_step_pins()


# A pin combat resolved (enemy_pinned). The smash-armed items answer it in the next
# step, never inside the handler.
func note_pin(victim: Node3D, damage: float) -> void:
	if is_instance_valid(victim):
		_pins.append({"victim": victim, "damage": damage, "at": victim.global_position})
		_recent_pins.append({"victim": victim, "t": _clock})


func resolve(c, draw: float) -> void:
	if c.kind == Triggers.Kind.ON_DAMAGE_TAKEN:
		_soften(c)
	if c.kind == Triggers.Kind.ON_HIT and _armed_hit > 0.0 and c.enemy != null and c.base_proc > 0.0:
		var bonus: float = _armed_hit
		_armed_hit = 0.0
		build.item_hit(c.enemy, c.amount * bonus, "")
		_count("armed_hit")
	for entry in by_kind.get(c.kind, []):
		if c.kind == Triggers.Kind.TIMED and entry["id"] != c.source:
			continue
		var d: Resource = entry["def"]
		var id: String = entry["id"]
		if _clock < _ready_at.get(id, -1.0):
			continue
		var fx: Dictionary = d.effect
		var key: String = stack_key(fx.get("do", ""))
		if fx.has("chance"):
			var chance: float = stacked(d, "chance", entry["copies"]) * c.base_proc * d.proc_coeff
			if Triggers.roll(draw, c.index, entry["index"]) >= chance:
				continue
		elif c.base_proc * d.proc_coeff <= 0.0:
			continue
		var power: float = stacked(d, key, entry["copies"]) if key != "" and key != "chance" else 0.0
		if _apply(id, d, fx, c, power, draw, entry["index"]):
			_count(id)
			if fx.has("every") and d.trigger != "timed":
				_ready_at[id] = _clock + float(fx["every"])


func _count(id: String) -> void:
	procs[id] = procs.get(id, 0) + 1


# One effect. Returns true when it did something.
func _apply(id: String, d: Resource, fx: Dictionary, c, power: float, draw: float, item_index: int) -> bool:
	var ctx = build.ctx
	var element: String = fx.get("element", d.element)
	match fx.get("do", ""):
		"zap":
			var from: Vector3 = c.enemy.global_position if is_instance_valid(c.enemy) else c.at
			var near: Array = build.enemies_near(from, fx.get("reach", 10.0), 2)
			for enemy in near:
				if enemy != c.enemy:
					build.field.zap_line(from, enemy.global_position)
					build.item_hit(enemy, fx.get("damage", 6.0), element)
					return true
			return false
		"burst":
			var at: Vector3 = c.enemy.global_position if is_instance_valid(c.enemy) else c.at
			var damage: float = power if not fx.has("chance") and power > 0.0 else fx.get("damage", 8.0)
			return _burst(at, fx.get("radius", 5.0), damage, element, fx.get("min_impact", 0.0), c)
		"extra_hit":
			if not is_instance_valid(c.enemy):
				return false
			build.item_hit(c.enemy, c.amount * fx.get("mult", 1.0), element)
			return true
		"arm_hit":
			_armed_hit = maxf(_armed_hit, power)
			return true
		"last_word":
			if _last_word_used or ctx.run.hp > ctx.run.max_hp * fx.get("below", 0.25) or not ctx.run.alive():
				return false
			_last_word_used = true
			_armed_hit = maxf(_armed_hit, power)
			return true
		"speed":
			return _surge(power, fx.get("max_speed", 45.0), c)
		"dash":
			var dir: Vector3 = ctx.player.planar_velocity()
			if dir.length() < 0.5:
				dir = ctx.aim_forward()
			dir.y = 0.0
			ctx.player.add_external_accel(dir.normalized() * power / _step())
			return true
		"air_jump":
			ctx.player.refresh_air()
			return true
		"grant_charge":
			ctx.player.abilities.grant(fx.get("slot", "movement"))
			return true
		"overcharge":
			_burst(ctx.player.ball_position(), fx.get("radius", 9.0), power * maxf(0.3, c.amount), element, 0.0, c)
			if Triggers.roll(draw, c.index + 3, item_index) < fx.get("refund", 0.0):
				ctx.player.abilities.grant("special")
			return true
		"echo_release":
			return _burst(ctx.player.ball_position(), fx.get("radius", 8.0), fx.get("damage", 16.0) * maxf(0.3, c.amount), element, 0.0, c)
		"pin_bonus", "pin_chain", "domino":
			_pin_until[id] = _clock + fx.get("window", 1.5)
			if fx.get("do") == "domino":
				_domino_count = 0
			return true
		"rebound_crit":
			_rebounds.append(_clock)
			while not _rebounds.is_empty() and _clock - _rebounds[0] > fx.get("window", 4.0):
				_rebounds.pop_front()
			if _rebounds.size() < int(fx.get("count", 3)) or not is_instance_valid(c.enemy):
				return false
			_rebounds.clear()
			build.item_hit(c.enemy, c.amount * fx.get("mult", 2.0), element)
			return true
		"rebound_strike":
			if not is_instance_valid(c.enemy):
				return false
			build.item_hit(c.enemy, (BASE_HIT + build.punch_bonus()) * power * build.sheet.mod("weapon_damage"), element)
			return true
		"relaunch_pin":
			var any := false
			var ball: Vector3 = ctx.player.ball_position()
			for pin in _recent_pins:
				var victim = pin["victim"]
				if _clock - pin["t"] <= fx.get("window", 2.0) and _pinnable(victim) \
						and victim.global_position.distance_to(ball) <= fx.get("radius", 7.0):
					var away: Vector3 = victim.global_position - ball
					away.y = 0.0
					victim.knock(away.normalized() + Vector3.UP * 0.6, fx.get("speed", 10.0) * float(victim.weight))
					any = true
			return any
		"scrap_burst":
			return _scatter(ctx.player.ball_position(), fx.get("radius", 7.0), fx.get("speed", 11.0))
		"return_arc":
			var near: Array = build.enemies_near(ctx.player.ball_position(), fx.get("reach", 12.0), 1)
			if near.is_empty():
				return false
			build.field.zap_line(ctx.player.ball_position(), near[0].global_position)
			build.item_hit(near[0], c.amount * power, "arc")
			return true
		"heal_back":
			ctx.run.heal(c.amount * fx.get("share", 1.0))
			return true
		"brace":
			if c.kind == Triggers.Kind.ON_LAND and c.amount < fx.get("min_impact", 0.0):
				return false
			_brace_until = _clock + fx.get("window", 1.0)
			_brace_share = maxf(_brace_share if _clock < _brace_until else 0.0, power)
			_brace_source = c.enemy.get("kind") if c.kind == Triggers.Kind.ON_REBOUND and is_instance_valid(c.enemy) else ""
			return true
		"floor_hp":
			var floor_hp: float = ctx.run.max_hp * fx.get("floor", 0.2)
			if _ward_used or not ctx.run.alive() or ctx.run.hp >= floor_hp:
				return false
			_ward_used = true
			ctx.run.heal(floor_hp - ctx.run.hp)
			return true
		"bonus_scrap":
			if not ctx.flow.in_stage():
				return false
			build.scrap.drop(c.at, int(fx.get("amount", 12)), build.loot_rng)
			return true
		"drone":
			_drone_until = _clock + fx.get("seconds", 4.0)
			_drone_magnet = fx.get("magnet", 3.0)
			return true
		"ping":
			return _ping(fx.get("target", "beacon"))
		"cloak_extend":
			if ctx.spawner != null and ctx.spawner.has_method("extend_cloak"):
				ctx.spawner.extend_cloak(power)
				return true
			return false
	return false


# Blunts damage taken: the passive reduction, then a brace window. Both heal back part
# of a hit already applied, so they never undo a killing blow.
func _soften(c) -> void:
	var ctx = build.ctx
	if not ctx.run.alive():
		return
	var share: float = damage_reduction
	if _clock < _brace_until and (_brace_source == "" or c.source == _brace_source):
		share = 1.0 - (1.0 - share) * (1.0 - _brace_share)
	if share > 0.0:
		ctx.run.heal(c.amount * share)


func _burst(at: Vector3, radius: float, damage: float, element: String, min_impact: float, c) -> bool:
	if c.kind == Triggers.Kind.ON_LAND and c.amount < min_impact:
		return false
	var color: Color = Palette.ARC if element == "arc" else (ElementField.ICE if element == "frost" else Palette.AMBER)
	build.field.flash_ring(at, radius, color)
	for enemy in build.enemies_near(at, radius, 6):
		build.item_hit(enemy, damage, "")
	if element != "":
		build.field.apply(element, at, "item")
	return true


func _surge(gain: float, cap_speed: float, c) -> bool:
	var ctx = build.ctx
	var v: Vector3 = ctx.player.planar_velocity()
	var speed: float = v.length()
	if speed < 1.0 or speed >= cap_speed:
		return false
	var target: float = minf(cap_speed, speed * (1.0 + gain))
	ctx.player.add_external_accel(v.normalized() * (target - speed) / _step())
	return true


# Knocks every pinnable enemy near at outward and a little up, fast enough to pin.
func _scatter(at: Vector3, radius: float, speed: float) -> bool:
	var any := false
	for enemy in build.enemies_near(at, radius, 6):
		if not _pinnable(enemy):
			continue
		var away: Vector3 = enemy.global_position - at
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3.FORWARD
		enemy.knock(away.normalized() + Vector3.UP * 0.3, speed * float(enemy.weight))
		any = true
	return any


func _ping(target: String) -> bool:
	var ctx = build.ctx
	var at := Vector3.INF
	if target == "vault":
		var best := INF
		for node in build.get_tree().get_nodes_in_group("enemy"):
			if node is Node3D and is_instance_valid(node) and node.get("kind") == "vault":
				var dist: float = node.global_position.distance_to(ctx.player.ball_position())
				if dist < best:
					best = dist
					at = node.global_position
	elif ctx.flow.in_stage():
		at = ctx.terrain.beacon_point(ctx.flow.stage())
	if at == Vector3.INF:
		return false
	build.field.flash_ring(at + Vector3.UP * 0.5, PING_RADIUS, Palette.ARC)
	return true


# The smash-armed items answer each pin combat resolved while their window is open.
func _step_pins() -> void:
	if _pins.is_empty():
		return
	var pins := _pins
	_pins = []
	while not _recent_pins.is_empty() and _clock - _recent_pins[0]["t"] > 3.0:
		_recent_pins.pop_front()
	for pin in pins:
		var victim = pin["victim"]
		if not is_instance_valid(victim):
			continue
		for id in _pin_until:
			if _clock > _pin_until[id]:
				continue
			var d: Resource = Parts.def(id)
			var n: int = copies.get(id, 0)
			if d == null or n == 0:
				continue
			match d.effect.get("do", ""):
				"pin_bonus":
					build.item_hit(victim, pin["damage"] * stacked(d, "bonus", n), "")
					_count(id)
				"pin_chain":
					var pushed := 0
					var limit: int = int(stacked(d, "count", n))
					for other in build.enemies_near(pin["at"], 5.0, limit + 1):
						if other == victim or not _pinnable(other) or pushed >= limit:
							continue
						var away: Vector3 = other.global_position - pin["at"]
						away.y = 0.0
						other.knock(away.normalized() + Vector3.UP * 0.2, d.effect.get("speed", 9.0) * float(other.weight))
						pushed += 1
					if pushed > 0:
						_count(id)
				"domino":
					_domino(id, d, n, victim)


# A pin hitting a pin may chain once more: the victim is flung at its nearest
# neighbour. The pin that fling causes has chain_depth 1, so it may not domino again
# (Triggers.MAX_CHAIN_DEPTH), and a window allows at most DOMINO_MAX_PER_WINDOW. The
# roll is the pin's own deterministic draw, from the clock and the victim.
func _domino(id: String, d: Resource, n: int, victim: Node3D) -> void:
	var key: int = victim.get_instance_id()
	var mark: Dictionary = _domino_marks.get(key, {})
	var depth: int = mark.get("depth", 0) if _clock - float(mark.get("t", -9.0)) < 1.0 else 0
	if depth + 1 > Triggers.MAX_CHAIN_DEPTH:
		return
	if _domino_count >= DOMINO_MAX_PER_WINDOW:
		return
	var roll: float = fposmod(_clock * 7.31 + float(key % 997) * Triggers.SPREAD, 1.0)
	if roll >= stacked(d, "chance", n):
		return
	var near: Array = build.enemies_near(victim.global_position, 8.0, 2)
	for other in near:
		if other == victim or not _pinnable(other):
			continue
		var to: Vector3 = other.global_position - victim.global_position
		to.y = 0.0
		victim.knock(to.normalized() + Vector3.UP * 0.2, d.effect.get("speed", 10.0) * float(victim.weight))
		_domino_marks[other.get_instance_id()] = {"depth": depth + 1, "t": _clock}
		_domino_count += 1
		_count(id)
		return


static func _pinnable(enemy) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("knock") and enemy.has_method("is_dead") and not enemy.is_dead()


func _step() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)
