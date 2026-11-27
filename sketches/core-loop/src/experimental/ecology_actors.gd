extends RefCounted


const EnvTags := preload("res://src/experimental/env_tags.gd")

signal prop_ruptured(event: Dictionary)
signal courier_spilled(event: Dictionary)
signal aggro_ping_broadcast(event: Dictionary)
signal enemy_state_changed(enemy_id: String, old_state: StringName, new_state: StringName)

const PROP_COOLANT_TANK: StringName = &"coolant_tank"
const PROP_SLAG_DRUM: StringName = &"slag_drum"
const PROP_SCRAP_PILE: StringName = &"scrap_pile"
const PROP_POWER_CONDUIT: StringName = &"power_conduit"

const COURIER_HAULER_DRONE: StringName = &"hauler_drone"
const COURIER_SKITTER_CART: StringName = &"audit_skitter_cart"

const ROLE_SWARMER: StringName = &"swarmer"
const ROLE_SHIELDED_BULWARK: StringName = &"shielded_bulwark"
const ROLE_ARC_SNIPER: StringName = &"arc_sniper"
const ROLE_WELD_HEALER: StringName = &"weld_healer"

const ST_IDLE: StringName = &"idle"
const ST_PATROL: StringName = &"patrol"
const ST_ADVANCE: StringName = &"advance"
const ST_ALERT_TELEGRAPH: StringName = &"alert_telegraph"
const ST_WINDUP: StringName = &"windup"
const ST_STRIKE: StringName = &"strike"
const ST_RECOVER: StringName = &"recover"
const ST_DISRUPTED: StringName = &"disrupted"
const ST_TETHER_HEAL: StringName = &"tether_heal"
const ST_SHIELD_BRACE: StringName = &"shield_brace"
const ST_REPOSITION: StringName = &"reposition"
const ST_FLEEING: StringName = &"fleeing"
const ST_DISABLED: StringName = &"disabled"
const ST_ESCAPED: StringName = &"escaped"

const PUNT_MIN_SPEED_MPS := 12.0
const BOWL_MIN_SPEED_MPS := 14.0
const CONDUIT_COOLDOWN_S := 8.0
const AGGRO_TELEGRAPH_S := 0.65
const ELITE_SLOW_FLOOR := 0.85


class InteractiveProp extends RefCounted:
	var id: String = ""
	var kind: StringName = PROP_COOLANT_TANK
	var pos: Vector3 = Vector3.ZERO
	var vel: Vector3 = Vector3.ZERO
	var radius_m: float = 1.2
	var intact: bool = true
	var punted: bool = false
	var cooldown_s: float = 0.0
	var scrap_yield: int = 2
	var cog_yield: int = 0
	var hits_bowled: Array[String] = []


class NeutralCourier extends RefCounted:
	var id: String = ""
	var kind: StringName = COURIER_HAULER_DRONE
	var pos: Vector3 = Vector3.ZERO
	var vel: Vector3 = Vector3.ZERO
	var patrol_a: Vector3 = Vector3.ZERO
	var patrol_b: Vector3 = Vector3(12.0, 0.0, 0.0)
	var patrol_to_b: bool = true
	var escape_point: Vector3 = Vector3(60.0, 0.0, 0.0)
	var hp: float = 60.0
	var max_hp: float = 60.0
	var speed_mps: float = 11.5
	var state: StringName = ST_PATROL
	var stalled_s: float = 0.0
	var cores_carried: int = 1
	var scrap_carried: int = 6
	var cogs_carried: int = 3
	var aggro_radius_m: float = 26.0
	var spill_count: int = 0
	var faction: StringName = &"fleet_machine"


class EcologyEnemy extends RefCounted:
	var id: String = ""
	var role: StringName = ROLE_SWARMER
	var faction: StringName = &"fleet"
	var pos: Vector3 = Vector3.ZERO
	var facing: Vector3 = Vector3.FORWARD
	var hp: float = 50.0
	var max_hp: float = 50.0
	var speed_mps: float = 9.0
	var state: StringName = ST_IDLE
	var state_timer_s: float = 0.0
	var alerted: bool = false
	var alert_target: Vector3 = Vector3.ZERO
	var alert_telegraph_s: float = 0.0
	var shield_intact: bool = false
	var shield_block_ratio: float = 0.0
	var heal_target_id: String = ""
	var windup_duration_s: float = 0.9
	var aim_deflected_rad: float = 0.0
	var slow_mult: float = 1.0
	var slow_left_s: float = 0.0
	var panic_s: float = 0.0
	var disrupted_s: float = 0.0
	var elite: bool = false

	func is_dead() -> bool:
		return hp <= 0.0


var env_tags: RefCounted = null
var _props: Dictionary = {}
var _couriers: Dictionary = {}
var _enemies: Dictionary = {}
var _consumed_serials: Dictionary = {}
var _event_log: Array[Dictionary] = []
var _clock := 0.0
var _reaction_callable: Callable = Callable()


static func reset() -> void:
	pass


func _init(env_tags_ref: RefCounted = null) -> void:
	env_tags = env_tags_ref if env_tags_ref != null else EnvTags.new()
	var self_ref: WeakRef = weakref(self)
	_reaction_callable = func(ev: Dictionary) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null:
			inst._on_env_reaction(ev)
	env_tags.reaction_triggered.connect(_reaction_callable)


func dispose() -> void:
	if env_tags != null and _reaction_callable.is_valid() and env_tags.reaction_triggered.is_connected(_reaction_callable):
		env_tags.reaction_triggered.disconnect(_reaction_callable)
	clear()


func clear() -> void:
	_props.clear()
	_couriers.clear()
	_enemies.clear()
	_consumed_serials.clear()
	_event_log.clear()
	_clock = 0.0


func prop(prop_id: String) -> InteractiveProp:
	return _props.get(prop_id, null)


func courier(courier_id: String) -> NeutralCourier:
	return _couriers.get(courier_id, null)


func enemy(enemy_id: String) -> EcologyEnemy:
	return _enemies.get(enemy_id, null)


func event_log() -> Array[Dictionary]:
	return _event_log.duplicate(true)


func spawn_prop(prop_id: String, kind: StringName, pos: Vector3) -> InteractiveProp:
	var p := InteractiveProp.new()
	p.id = prop_id
	p.kind = kind
	p.pos = pos
	match kind:
		PROP_COOLANT_TANK:
			p.radius_m = 1.25
			p.scrap_yield = 2
			p.cog_yield = 0
		PROP_SLAG_DRUM:
			p.radius_m = 1.15
			p.scrap_yield = 2
			p.cog_yield = 1
		PROP_SCRAP_PILE:
			p.radius_m = 1.4
			p.scrap_yield = 4
			p.cog_yield = 1
		PROP_POWER_CONDUIT:
			p.radius_m = 1.3
			p.scrap_yield = 1
			p.cog_yield = 1
	_props[prop_id] = p
	env_tags.register_actor("prop:" + prop_id, pos, p.radius_m, {"kind": kind, "type": &"prop"})
	return p


func spawn_courier(courier_id: String, kind: StringName, pos: Vector3,
		escape_point: Vector3 = Vector3(60.0, 0.0, 0.0)) -> NeutralCourier:
	var c := NeutralCourier.new()
	c.id = courier_id
	c.kind = kind
	c.pos = pos
	c.patrol_a = pos
	c.patrol_b = pos + Vector3(12.0, 0.0, 0.0)
	c.escape_point = escape_point
	match kind:
		COURIER_HAULER_DRONE:
			c.hp = 65.0
			c.max_hp = 65.0
			c.speed_mps = 11.5
			c.cores_carried = 1
			c.scrap_carried = 6
			c.cogs_carried = 3
			c.aggro_radius_m = 26.0
		COURIER_SKITTER_CART:
			c.hp = 40.0
			c.max_hp = 40.0
			c.speed_mps = 12.5
			c.cores_carried = 0
			c.scrap_carried = 5
			c.cogs_carried = 5
			c.aggro_radius_m = 22.0
	_couriers[courier_id] = c
	env_tags.register_actor("courier:" + courier_id, pos, 1.1, {"kind": kind, "type": &"courier"})
	return c


func spawn_enemy(enemy_id: String, role: StringName, pos: Vector3, elite: bool = false) -> EcologyEnemy:
	var e := EcologyEnemy.new()
	e.id = enemy_id
	e.role = role
	e.pos = pos
	e.elite = elite
	match role:
		ROLE_SWARMER:
			e.hp = 36.0
			e.max_hp = 36.0
			e.speed_mps = 9.0
			e.windup_duration_s = 0.65
		ROLE_SHIELDED_BULWARK:
			e.hp = 95.0
			e.max_hp = 95.0
			e.speed_mps = 5.2
			e.shield_intact = true
			e.shield_block_ratio = 0.75
			e.state = ST_SHIELD_BRACE
			e.windup_duration_s = 1.0
		ROLE_ARC_SNIPER:
			e.hp = 45.0
			e.max_hp = 45.0
			e.speed_mps = 6.5
			e.windup_duration_s = 1.1
		ROLE_WELD_HEALER:
			e.hp = 55.0
			e.max_hp = 55.0
			e.speed_mps = 7.0
			e.windup_duration_s = 0.8
	_enemies[enemy_id] = e
	env_tags.register_actor("enemy:" + enemy_id, pos, 1.1, {"role": role, "type": &"enemy", "elite": elite})
	return e



func _on_env_reaction(ev: Dictionary) -> void:
	var origin: Vector3 = ev["origin"]
	var radius_m: float = float(ev["radius_m"])
	var dmg: float = float(ev["damage"])
	var shred: float = float(ev.get("armor_shred", 0.0))
	var slow: float = float(ev.get("slow_factor", 1.0))
	var drops_shield: bool = bool(ev.get("drops_shield", false))
	var interrupts_tether: bool = bool(ev.get("interrupts_tether", false))

	var targets: Array[EcologyEnemy] = []
	var actor_id := String(ev.get("actor_id", ""))
	if actor_id != "":
		if actor_id.begins_with("enemy:"):
			var single: EcologyEnemy = _enemies.get(actor_id.trim_prefix("enemy:"), null)
			if single != null and not single.is_dead():
				targets.append(single)
	else:
		targets = _enemies_in_radius(origin, radius_m)

	for e in targets:
		if dmg > 0.0:
			damage_enemy(e.id, dmg * 0.5, origin, &"reaction")
		if e.is_dead():
			continue
		if shred > 0.0 and e.shield_intact:
			e.shield_block_ratio = maxf(0.15, e.shield_block_ratio - shred)
		if drops_shield and e.role == ROLE_SHIELDED_BULWARK and e.shield_intact:
			e.shield_intact = false
			if not e.elite:
				_enter_disrupted(e, 1.5)
		if interrupts_tether and e.role == ROLE_WELD_HEALER and e.state == ST_TETHER_HEAL:
			_sever_healer_tether(e, StringName(ev["reaction_id"]))
		if slow < 1.0:
			var applied_slow := maxf(slow, ELITE_SLOW_FLOOR) if e.elite else slow
			e.slow_mult = minf(e.slow_mult, applied_slow)
			e.slow_left_s = maxf(e.slow_left_s, 2.5)



func interact_prop_with_ball(prop_id: String, ball_vel: Vector3, is_slam: bool = false) -> Dictionary:
	var p: InteractiveProp = _props.get(prop_id, null)
	if p == null or not p.intact:
		return {"ok": false, "reason": "missing_or_spent"}
	var speed := ball_vel.length()
	var dir := ball_vel.normalized() if speed > 0.01 else Vector3.FORWARD

	match p.kind:
		PROP_COOLANT_TANK:
			return rupture_prop(prop_id, "ball_impact")
		PROP_SLAG_DRUM:
			if speed >= PUNT_MIN_SPEED_MPS and not is_slam:
				p.punted = true
				p.vel = dir * maxf(speed * 1.15, 16.0)
				return {"ok": true, "action": &"punted", "prop_id": prop_id, "vel": p.vel}
			return rupture_prop(prop_id, "ball_slam" if is_slam else "ball_hit")
		PROP_SCRAP_PILE:
			if is_slam or speed >= BOWL_MIN_SPEED_MPS:
				p.punted = true
				p.vel = dir * maxf(speed * 1.1, 18.0)
				return {"ok": true, "action": &"bowling_launched", "prop_id": prop_id, "vel": p.vel}
			p.intact = false
			env_tags.unregister_actor("prop:" + p.id)
			var harvest := {
				"ok": true,
				"action": &"harvested",
				"prop_id": prop_id,
				"scrap": p.scrap_yield,
				"cogs": p.cog_yield,
			}
			_event_log.append(harvest)
			return harvest
		PROP_POWER_CONDUIT:
			return trigger_conduit(prop_id, "ball_strike")
	return {"ok": false, "reason": "unknown_kind"}


func rupture_prop(prop_id: String, source_id: String = "hit") -> Dictionary:
	var p: InteractiveProp = _props.get(prop_id, null)
	if p == null or not p.intact:
		return {"ok": false, "reason": "missing_or_spent"}
	if p.kind == PROP_POWER_CONDUIT:
		return trigger_conduit(prop_id, source_id)

	p.intact = false
	p.punted = false
	p.vel = Vector3.ZERO
	env_tags.unregister_actor("prop:" + p.id)

	var reactions: Array[Dictionary] = []
	var quench_cool := 0.0
	var blast_damage := 0.0
	var bonus_scrap := 0

	match p.kind:
		PROP_COOLANT_TANK:
			var r1: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, p.pos, 6.5, "coolant_tank:" + p.id, 1.2, 6.0)
			)
			var r2: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_SOAKED_CONDUCTIVE, p.pos, 5.5, "coolant_tank:" + p.id + "#wet", 1.0, 5.0)
			)
			reactions.append_array(r1["reactions"])
			reactions.append_array(r2["reactions"])
			quench_cool = 30.0
		PROP_SLAG_DRUM:
			var r_burn: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_BURNING, p.pos, 6.0, "slag_drum:" + p.id, 1.3, 5.0)
			)
			var r_slag: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, p.pos, 5.5, "slag_drum:" + p.id + "#pool", 1.2, 6.5)
			)
			reactions.append_array(r_burn["reactions"])
			reactions.append_array(r_slag["reactions"])
			blast_damage = 32.0
			for e in _enemies_in_radius(p.pos, 6.0):
				damage_enemy(e.id, blast_damage, p.pos, &"blast")
		PROP_SCRAP_PILE:
			bonus_scrap = 1

	var receipt := {
		"ok": true,
		"action": &"ruptured",
		"prop_id": p.id,
		"kind": p.kind,
		"origin": p.pos,
		"source_id": source_id,
		"scrap": p.scrap_yield + bonus_scrap,
		"cogs": p.cog_yield,
		"quench_cool": quench_cool,
		"blast_damage": blast_damage,
		"reactions": reactions,
	}
	_event_log.append(receipt)
	prop_ruptured.emit(receipt)
	return receipt


func trigger_conduit(prop_id: String, source_id: String = "pulse") -> Dictionary:
	var p: InteractiveProp = _props.get(prop_id, null)
	if p == null or p.kind != PROP_POWER_CONDUIT:
		return {"ok": false, "reason": "not_conduit"}
	if p.cooldown_s > 0.0:
		return {"ok": false, "reason": "on_cooldown", "cooldown_s": p.cooldown_s}
	p.cooldown_s = CONDUIT_COOLDOWN_S
	var res: Dictionary = env_tags.apply_tag(
		EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, p.pos, 5.0, "conduit:" + p.id + "#" + source_id, 1.35, 3.5)
	)
	var receipt := {
		"ok": true,
		"action": &"conduit_discharge",
		"prop_id": p.id,
		"origin": p.pos,
		"cooldown_s": p.cooldown_s,
		"reactions": res["reactions"],
	}
	_event_log.append(receipt)
	prop_ruptured.emit(receipt)
	return receipt



func strike_courier(courier_id: String, damage: float, attacker_pos: Vector3,
		is_harpoon: bool = false) -> Dictionary:
	var c: NeutralCourier = _couriers.get(courier_id, null)
	if c == null or c.state == ST_DISABLED or c.state == ST_ESCAPED:
		return {"ok": false, "reason": "inactive"}

	c.hp = maxf(0.0, c.hp - damage)
	c.spill_count += 1
	var spilled_scrap := mini(2 if not is_harpoon else 3, c.scrap_carried)
	var spilled_cogs := mini(1, c.cogs_carried)
	var spilled_cores := 0
	c.scrap_carried -= spilled_scrap
	c.cogs_carried -= spilled_cogs

	if c.hp <= 0.0:
		c.state = ST_DISABLED
		spilled_scrap += c.scrap_carried
		spilled_cogs += c.cogs_carried
		spilled_cores = c.cores_carried
		c.scrap_carried = 0
		c.cogs_carried = 0
		c.cores_carried = 0
		env_tags.unregister_actor("courier:" + c.id)
	else:
		c.state = ST_FLEEING
		if is_harpoon:
			c.stalled_s = maxf(c.stalled_s, 1.0)

	var alerted_ids := broadcast_aggro_ping(c.pos, c.aggro_radius_m, attacker_pos, "courier:" + c.id)
	var receipt := {
		"ok": true,
		"courier_id": c.id,
		"kind": c.kind,
		"state": c.state,
		"hp_left": c.hp,
		"spilled_scrap": spilled_scrap,
		"spilled_cogs": spilled_cogs,
		"spilled_cores": spilled_cores,
		"alerted_enemies": alerted_ids,
	}
	_event_log.append(receipt)
	courier_spilled.emit(receipt)
	return receipt


func broadcast_aggro_ping(origin: Vector3, radius_m: float, threat_pos: Vector3,
		source_id: String = "requisition_ping") -> Array[String]:
	var alerted_ids: Array[String] = []
	for e in _enemies_in_radius(origin, radius_m):
		if e.faction == &"fleet":
			e.alerted = true
			e.alert_target = threat_pos
			e.alert_telegraph_s = AGGRO_TELEGRAPH_S
			if e.state != ST_DISRUPTED and e.state != ST_TETHER_HEAL:
				_set_enemy_state(e, ST_ALERT_TELEGRAPH)
			alerted_ids.append(e.id)
	var ping := {
		"action": &"requisition_aggro_ping",
		"origin": origin,
		"radius_m": radius_m,
		"source_id": source_id,
		"telegraph_s": AGGRO_TELEGRAPH_S,
		"alerted_enemies": alerted_ids,
	}
	_event_log.append(ping)
	aggro_ping_broadcast.emit(ping)
	return alerted_ids



func damage_enemy(enemy_id: String, raw_damage: float, hit_origin: Vector3,
		damage_kind: StringName = &"kinetic") -> Dictionary:
	var e: EcologyEnemy = _enemies.get(enemy_id, null)
	if e == null or e.is_dead():
		return {"ok": false, "damage_dealt": 0.0}

	var mult := 1.0
	var blocked := false
	var tags: Array[StringName] = env_tags.actor_tags("enemy:" + e.id)

	if e.role == ROLE_SHIELDED_BULWARK and e.shield_intact and e.state == ST_SHIELD_BRACE:
		var incoming := hit_origin - e.pos
		incoming.y = 0.0
		if incoming.length_squared() > 0.001 and incoming.normalized().dot(e.facing.normalized()) > 0.35:
			var block_ratio := 0.20 if tags.has(EnvTags.TAG_COOLANT_BRITTLE) else e.shield_block_ratio
			mult *= (1.0 - block_ratio)
			blocked = true
			if tags.has(EnvTags.TAG_COOLANT_BRITTLE) and (damage_kind == &"slam" or damage_kind == &"ram"):
				e.shield_intact = false
				if not e.elite:
					_enter_disrupted(e, 2.0)

	if tags.has(EnvTags.TAG_COOLANT_BRITTLE) and damage_kind in [&"kinetic", &"slam", &"ram", &"bowling"]:
		mult *= 1.6
	if tags.has(EnvTags.TAG_SOAKED_CONDUCTIVE) and damage_kind == &"arc":
		mult *= 1.5

	var dealt := raw_damage * mult
	e.hp = maxf(0.0, e.hp - dealt)
	if e.is_dead():
		env_tags.unregister_actor("enemy:" + e.id)
	return {
		"ok": true,
		"enemy_id": e.id,
		"damage_dealt": dealt,
		"blocked": blocked,
		"shield_intact": e.shield_intact,
		"hp_left": e.hp,
		"dead": e.is_dead(),
	}


func apply_harpoon_snap(target_id: String, attacker_pos: Vector3) -> Dictionary:
	if _couriers.has(target_id):
		return strike_courier(target_id, 18.0, attacker_pos, true)
	var e: EcologyEnemy = _enemies.get(target_id, null)
	if e == null or e.is_dead():
		return {"ok": false, "reason": "missing_or_dead"}
	if e.role == ROLE_WELD_HEALER and e.state == ST_TETHER_HEAL:
		return _sever_healer_tether(e, &"harpoon_snap")
	if e.role == ROLE_SHIELDED_BULWARK:
		if not e.elite:
			_enter_disrupted(e, 1.8)
		return {"ok": true, "action": &"bulwark_pulled_open", "enemy_id": e.id}
	return {"ok": true, "action": &"harpoon_tug", "enemy_id": e.id}



func step(dt: float, ball_pos: Vector3, ball_vel: Vector3) -> Dictionary:
	if dt <= 0.0:
		return {"tether_severs": [], "heals": [], "bowling_hits": []}
	_clock += dt
	env_tags.step(dt)

	var bowling_hits: Array[Dictionary] = []
	var tether_severs: Array[Dictionary] = []
	var heals: Array[Dictionary] = []

	_step_props(dt, bowling_hits)
	_step_couriers(dt, ball_pos)
	_step_enemies(dt, ball_pos, ball_vel, tether_severs, heals)

	return {
		"tether_severs": tether_severs,
		"heals": heals,
		"bowling_hits": bowling_hits,
	}


func _consume_tag_once(actor_key: String, tag: StringName) -> bool:
	var serial: int = env_tags.actor_tag_serial(actor_key, tag)
	if serial <= 0:
		return false
	var ck := "%s|%s" % [actor_key, String(tag)]
	if int(_consumed_serials.get(ck, 0)) == serial:
		return false
	_consumed_serials[ck] = serial
	return true


func _step_props(dt: float, bowling_hits: Array[Dictionary]) -> void:
	for pid in _sorted_keys(_props):
		var p: InteractiveProp = _props[pid]
		if p.cooldown_s > 0.0:
			p.cooldown_s = maxf(0.0, p.cooldown_s - dt)
		if not p.intact:
			continue
		var tags: Array[StringName] = env_tags.actor_tags("prop:" + p.id)

		if p.kind == PROP_COOLANT_TANK and tags.has(EnvTags.TAG_BURNING):
			rupture_prop(p.id, "tag:burning")
			continue
		if p.kind == PROP_SLAG_DRUM and (tags.has(EnvTags.TAG_BURNING) or tags.has(EnvTags.TAG_ELECTRIFIED)):
			rupture_prop(p.id, "tag:ignite")
			continue
		if p.kind == PROP_POWER_CONDUIT and p.cooldown_s <= 0.0:
			var nearby: Array[StringName] = env_tags.tags_at(p.pos, 5.0)
			if nearby.has(EnvTags.TAG_SOAKED_CONDUCTIVE) or nearby.has(EnvTags.TAG_SLAG_COATED):
				trigger_conduit(p.id, "auto_arc_ground")

		if (p.kind == PROP_SCRAP_PILE or p.kind == PROP_SLAG_DRUM) and not p.punted:
			var mag_zones: Array[Dictionary] = env_tags.zones_at(p.pos, 6.0, EnvTags.TAG_MAGNETIC)
			if not mag_zones.is_empty():
				var pull_to: Vector3 = mag_zones[0]["origin"]
				var diff := pull_to - p.pos
				diff.y = 0.0
				if diff.length() > 0.3:
					p.pos += diff.normalized() * minf(diff.length(), 7.0 * dt)
					env_tags.update_actor("prop:" + p.id, p.pos)

		if p.punted:
			p.pos += p.vel * dt
			p.vel = p.vel.move_toward(Vector3.ZERO, 9.0 * dt)
			env_tags.update_actor("prop:" + p.id, p.pos)
			for e in _enemies_in_radius(p.pos, p.radius_m + 1.1):
				if p.kind == PROP_SLAG_DRUM:
					rupture_prop(p.id, "punted_drum_impact")
					bowling_hits.append({"prop_id": p.id, "enemy_id": e.id, "kind": &"drum_detonate"})
					break
				elif p.kind == PROP_SCRAP_PILE and not p.hits_bowled.has(e.id):
					p.hits_bowled.append(e.id)
					var dmg := damage_enemy(e.id, 24.0, p.pos, &"bowling")
					bowling_hits.append({"prop_id": p.id, "enemy_id": e.id, "kind": &"scrap_bowl", "damage": dmg["damage_dealt"]})
					if p.hits_bowled.size() >= 4:
						rupture_prop(p.id, "bowling_shatter")
						break
			if p.intact and p.vel.length() < 1.5:
				if p.kind == PROP_SCRAP_PILE and not p.hits_bowled.is_empty():
					rupture_prop(p.id, "bowling_finish")
				else:
					p.punted = false


func _step_couriers(dt: float, ball_pos: Vector3) -> void:
	for cid in _sorted_keys(_couriers):
		var c: NeutralCourier = _couriers[cid]
		if c.state == ST_DISABLED or c.state == ST_ESCAPED:
			continue
		var ckey := "courier:" + c.id
		var tags: Array[StringName] = env_tags.actor_tags(ckey)
		if _consume_tag_once(ckey, EnvTags.TAG_ELECTRIFIED):
			c.stalled_s = maxf(c.stalled_s, 1.5)
		var speed_mult := 0.4 if tags.has(EnvTags.TAG_COOLANT_BRITTLE) else 1.0
		if c.stalled_s > 0.0:
			c.stalled_s = maxf(0.0, c.stalled_s - dt)
			c.vel = Vector3.ZERO
			continue

		if c.state == ST_PATROL:
			if c.pos.distance_to(ball_pos) < 8.0:
				c.state = ST_FLEEING
			else:
				var wp := c.patrol_b if c.patrol_to_b else c.patrol_a
				var to_wp := wp - c.pos
				to_wp.y = 0.0
				if to_wp.length() < 0.5:
					c.patrol_to_b = not c.patrol_to_b
				else:
					c.vel = to_wp.normalized() * (c.speed_mps * 0.55 * speed_mult)
					c.pos += c.vel * dt
					env_tags.update_actor(ckey, c.pos)
				continue

		if c.state == ST_FLEEING:
			var away := c.escape_point - c.pos
			away.y = 0.0
			if away.length() < 1.5:
				c.state = ST_ESCAPED
				env_tags.unregister_actor(ckey)
				continue
			c.vel = away.normalized() * (c.speed_mps * speed_mult)
			var mag_zones: Array[Dictionary] = env_tags.zones_at(c.pos, 7.0, EnvTags.TAG_MAGNETIC)
			if not mag_zones.is_empty():
				var tug: Vector3 = (mag_zones[0]["origin"] as Vector3) - c.pos
				tug.y = 0.0
				if tug.length() > 0.1:
					c.vel += tug.normalized() * 5.0
			c.pos += c.vel * dt
			env_tags.update_actor(ckey, c.pos)


func _step_enemies(dt: float, ball_pos: Vector3, ball_vel: Vector3,
		tether_severs: Array[Dictionary], heals: Array[Dictionary]) -> void:
	for eid in _sorted_keys(_enemies):
		var e: EcologyEnemy = _enemies[eid]
		if e.is_dead():
			continue
		var ekey := "enemy:" + e.id
		var tags: Array[StringName] = env_tags.actor_tags(ekey)

		if e.slow_left_s > 0.0:
			e.slow_left_s = maxf(0.0, e.slow_left_s - dt)
			if e.slow_left_s <= 0.0:
				e.slow_mult = 1.0

		if e.disrupted_s > 0.0:
			_consume_disruption_tags(e)
			e.disrupted_s = maxf(0.0, e.disrupted_s - dt)
			if e.disrupted_s <= 0.0:
				_set_enemy_state(e, ST_SHIELD_BRACE if e.role == ROLE_SHIELDED_BULWARK and e.shield_intact else ST_ADVANCE)
			else:
				continue

		if e.alert_telegraph_s > 0.0:
			e.alert_telegraph_s = maxf(0.0, e.alert_telegraph_s - dt)
			if e.alert_telegraph_s > 0.0:
				continue
			_set_enemy_state(e, ST_SHIELD_BRACE if e.role == ROLE_SHIELDED_BULWARK and e.shield_intact else ST_ADVANCE)

		var eff_speed := e.speed_mps * e.slow_mult * (1.2 if e.alerted else 1.0)
		var pursue_pos := e.alert_target if (e.alerted and e.pos.distance_to(e.alert_target) > 4.0) else ball_pos

		match e.role:
			ROLE_SWARMER:
				if _consume_tag_once(ekey, EnvTags.TAG_ELECTRIFIED) and not e.elite:
					_set_enemy_state(e, ST_DISRUPTED)
					e.disrupted_s = 0.8
					continue
				if tags.has(EnvTags.TAG_BURNING) and not e.elite:
					e.panic_s = 1.5
					_set_enemy_state(e, ST_REPOSITION)
					var away := (e.pos - ball_pos)
					away.y = 0.0
					var dir := away.normalized() if away.length() > 0.01 else Vector3.RIGHT
					e.pos += dir * (eff_speed * 0.85 * dt)
					env_tags.update_actor(ekey, e.pos)
					continue
				var lead := pursue_pos + ball_vel * 0.35
				var to_lead := lead - e.pos
				to_lead.y = 0.0
				if to_lead.length() > 1.8:
					_set_enemy_state(e, ST_ADVANCE)
					e.facing = to_lead.normalized()
					var chill := (ELITE_SLOW_FLOOR if e.elite else 0.55) if tags.has(EnvTags.TAG_COOLANT_BRITTLE) else 1.0
					e.pos += e.facing * (eff_speed * chill * dt)
					env_tags.update_actor(ekey, e.pos)
				else:
					_set_enemy_state(e, ST_WINDUP)

			ROLE_SHIELDED_BULWARK:
				if _consume_tag_once(ekey, EnvTags.TAG_MAGNETIC) and not e.elite:
					_set_enemy_state(e, ST_DISRUPTED)
					e.disrupted_s = 2.0
					e.facing = e.facing.rotated(Vector3.UP, PI * 0.5)
					continue
				var to_ball := pursue_pos - e.pos
				to_ball.y = 0.0
				if to_ball.length() > 0.1:
					e.facing = to_ball.normalized()
				_set_enemy_state(e, ST_SHIELD_BRACE if e.shield_intact else ST_ADVANCE)
				if to_ball.length() > 3.0:
					e.pos += e.facing * (eff_speed * 0.5 * dt)
					env_tags.update_actor(ekey, e.pos)

			ROLE_ARC_SNIPER:
				if _consume_tag_once(ekey, EnvTags.TAG_ELECTRIFIED):
					damage_enemy(e.id, 14.0, e.pos, &"arc")
					if e.is_dead():
						continue
					if not e.elite:
						_enter_disrupted(e, 2.0)
						e.state_timer_s = 0.0
					continue
				e.aim_deflected_rad = (0.15 if e.elite else 0.45) if tags.has(EnvTags.TAG_MAGNETIC) else 0.0
				var dist := e.pos.distance_to(ball_pos)
				var effective_range := 14.0 if tags.has(EnvTags.TAG_SOAKED_CONDUCTIVE) else 28.0
				if dist < 8.0:
					_set_enemy_state(e, ST_REPOSITION)
					var back := (e.pos - ball_pos)
					back.y = 0.0
					if back.length() > 0.01:
						e.pos += back.normalized() * (eff_speed * dt)
						env_tags.update_actor(ekey, e.pos)
				elif dist <= effective_range:
					if e.state == ST_RECOVER:
						e.state_timer_s -= dt
						if e.state_timer_s <= 0.0:
							_set_enemy_state(e, ST_WINDUP)
							e.state_timer_s = e.windup_duration_s
					elif e.state != ST_WINDUP and e.state != ST_STRIKE:
						_set_enemy_state(e, ST_WINDUP)
						e.state_timer_s = e.windup_duration_s
					elif e.state == ST_WINDUP:
						e.state_timer_s -= dt
						if e.state_timer_s <= 0.0:
							_set_enemy_state(e, ST_STRIKE)
							e.state_timer_s = 0.2
					elif e.state == ST_STRIKE:
						e.state_timer_s -= dt
						if e.state_timer_s <= 0.0:
							_set_enemy_state(e, ST_RECOVER)
							e.state_timer_s = 0.6

			ROLE_WELD_HEALER:
				if _consume_tag_once(ekey, EnvTags.TAG_ELECTRIFIED):
					if e.state == ST_TETHER_HEAL:
						tether_severs.append(_sever_healer_tether(e, &"tag_electrified"))
					elif not e.elite:
						_set_enemy_state(e, ST_DISRUPTED)
						e.disrupted_s = 2.0
					continue
				var patient := _find_wounded_ally(e, 14.0)
				if patient != null:
					e.heal_target_id = patient.id
					_set_enemy_state(e, ST_TETHER_HEAL)
					var rate := 4.0 if tags.has(EnvTags.TAG_COOLANT_BRITTLE) else 8.0
					var before := patient.hp
					patient.hp = minf(patient.max_hp, patient.hp + rate * dt)
					if patient.hp > before:
						heals.append({"healer_id": e.id, "target_id": patient.id, "healed": patient.hp - before})
				else:
					e.heal_target_id = ""
					_set_enemy_state(e, ST_ADVANCE)


func _enter_disrupted(e: EcologyEnemy, duration_s: float) -> void:
	_set_enemy_state(e, ST_DISRUPTED)
	e.disrupted_s = maxf(e.disrupted_s, duration_s)
	_consume_disruption_tags(e)


func _consume_disruption_tags(e: EcologyEnemy) -> void:
	var ekey := "enemy:" + e.id
	_consume_tag_once(ekey, EnvTags.TAG_ELECTRIFIED)
	_consume_tag_once(ekey, EnvTags.TAG_MAGNETIC)


func _sever_healer_tether(healer: EcologyEnemy, cause: StringName) -> Dictionary:
	var target_id := healer.heal_target_id
	healer.heal_target_id = ""
	_enter_disrupted(healer, 1.2 if healer.elite else 2.5)
	var feedback_dmg := 0.0
	if target_id != "" and _enemies.has(target_id):
		var res := damage_enemy(target_id, 15.0, healer.pos, &"arc")
		feedback_dmg = float(res.get("damage_dealt", 0.0))
	var sever := {
		"ok": true,
		"action": &"tether_severed",
		"healer_id": healer.id,
		"target_id": target_id,
		"cause": cause,
		"feedback_damage": feedback_dmg,
	}
	_event_log.append(sever)
	return sever


func _find_wounded_ally(healer: EcologyEnemy, max_range: float) -> EcologyEnemy:
	var best: EcologyEnemy = null
	var best_missing := 0.0
	for eid in _sorted_keys(_enemies):
		var cand: EcologyEnemy = _enemies[eid]
		if cand.id == healer.id or cand.is_dead() or cand.faction != healer.faction:
			continue
		if cand.pos.distance_to(healer.pos) > max_range:
			continue
		var missing := cand.max_hp - cand.hp
		if missing > best_missing:
			best_missing = missing
			best = cand
	return best


func _enemies_in_radius(origin: Vector3, radius_m: float) -> Array[EcologyEnemy]:
	var found: Array[EcologyEnemy] = []
	var r_sq := radius_m * radius_m
	for eid in _sorted_keys(_enemies):
		var e: EcologyEnemy = _enemies[eid]
		if not e.is_dead() and e.pos.distance_squared_to(origin) <= r_sq:
			found.append(e)
	return found


func _set_enemy_state(e: EcologyEnemy, next_state: StringName) -> void:
	if e.state == next_state:
		return
	var prev := e.state
	e.state = next_state
	enemy_state_changed.emit(e.id, prev, next_state)


static func _sorted_keys(dict: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for k in dict.keys():
		keys.append(String(k))
	keys.sort()
	return keys
