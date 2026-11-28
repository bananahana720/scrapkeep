extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const Bindings := preload("res://src/core/bindings.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const EnemyBase := preload("res://src/combat/enemy.gd")
const Groups := preload("res://src/core/groups.gd")
const Palette := preload("res://src/core/palette.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")

var ctx
var combat
var _nitro_left := 0.0
var _overclock_left := 0.0
var _memo_left := 0.0
var _memo_frozen := {}
var _balloons: Array = []
var _consumable_drops: Array = []
var _consumable_rng := RandomNumberGenerator.new()
var consumable_uses := 0
var overclock_skilled_shots := 0
var last_consumable := {}


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "ConsumableRuntime"


func seed_attempt() -> void:
	if ctx != null and ctx.run != null:
		_consumable_rng.seed = hash(["consumable_drops", ctx.run.run_seed, ctx.run.stage])


func on_enemy_died(id: int, kind: String, where: Vector3, source: String) -> void:
	if source != "fuse" and source != "hazard" and ctx.flow != null and ctx.flow.in_stage() and Consumables.is_secondary_counter(kind):
		var drop_id := Consumables.roll_for_counter_kill(_consumable_rng, kind)
		if drop_id != "":
			drop_consumable(drop_id, where)
	_memo_frozen.erase(id)


func nitro_siphon_left() -> float:
	return _nitro_left


func overclock_card_left() -> float:
	return _overclock_left


func foreman_memo_left() -> float:
	return _memo_left


func active_balloons() -> Array:
	return _balloons.filter(func(b): return is_instance_valid(b) and not b.expired)


func live_consumable_drops() -> Array:
	return _consumable_drops.filter(func(d): return is_instance_valid(d) and not d.collected)


func memo_exposed(enemy: Node3D) -> bool:
	return _memo_left > 0.0 and enemy != null and _memo_frozen.has(enemy.get_instance_id())


func drop_consumable(consumable_id: String, at: Vector3) -> Node3D:
	if ctx == null or ctx.root == null or not Consumables.is_valid(consumable_id):
		return null
	var pos := at
	if combat.ground != null and combat.ground.has_method("height"):
		pos.y = maxf(pos.y, float(combat.ground.height(at.x, at.z)))
	var cradle := Consumables.spawn_cradle(consumable_id, pos)
	ctx.root.add_child(cradle)
	_consumable_drops.append(cradle)
	return cradle


func _consumable_tap_pressed() -> bool:
	return Bindings.consumable_just_pressed()


func step(delta: float, enemies: Array) -> void:
	if ctx == null or ctx.run == null or ctx.player == null:
		return
	var ball_pos: Vector3 = ctx.player.ball_position()
	var kept_drops: Array = []
	for d in _consumable_drops:
		if not is_instance_valid(d):
			continue
		if d.step(delta, ball_pos, ctx.run):
			Consumables.try_clone_pickup(ctx, combat, "consumable", d.consumable_id, ball_pos)
			d.remove_from_group(Consumables.DROP_GROUP)
			d.queue_free()
			continue
		kept_drops.append(d)
	_consumable_drops = kept_drops
	Consumables.step_w50(ctx, delta)

	if ctx.run.has_consumable() and _consumable_tap_pressed():
		use_consumable()

	if _nitro_left > 0.0:
		_nitro_left = maxf(0.0, _nitro_left - delta)
		_step_nitro_siphon(enemies)
		if _nitro_left <= 0.0:
			combat.clear_buff("consumable_nitro_siphon")

	if _overclock_left > 0.0:
		_overclock_left = maxf(0.0, _overclock_left - delta)
		_refresh_overclock_cooldowns()
		if _overclock_left <= 0.0:
			combat.clear_buff("consumable_overclock_card")

	if _memo_left > 0.0:
		_memo_left = maxf(0.0, _memo_left - delta)
		_hold_memo_formation()
		if _memo_left <= 0.0:
			_release_memo_formation()
			combat.clear_buff("consumable_foreman_memo")

	if not _balloons.is_empty():
		var kept_balloons: Array = []
		for b in _balloons:
			if not is_instance_valid(b):
				continue
			if b.step(delta):
				kept_balloons.append(b)
				continue
			if ctx.player.kit != null and ctx.player.kit.hooked and ctx.player.kit.anchor_body == b:
				ctx.player.kit.drop_line("expired")
			b.remove_from_group(Augments.STAKE_GROUP)
			b.remove_from_group(Augments.ANCHOR_GROUP)
			b.remove_from_group(Consumables.BALLOON_GROUP)
			b.queue_free()
		_balloons = kept_balloons
		if _balloons.is_empty():
			combat.clear_buff("consumable_anchor_flare")


func use_consumable(override_id := "") -> Dictionary:
	if ctx == null or ctx.flow == null or not ctx.flow.in_play() or ctx.run == null or ctx.player == null:
		return {}
	var cid: String = override_id if override_id != "" and Consumables.is_valid(override_id) else String(ctx.run.pop_consumable())
	if cid == "":
		return {}
	var at: Vector3 = ctx.player.ball_position()
	var result := {"id": cid, "at": at}
	match cid:
		Consumables.CAP_CHARGE:
			result.merge(_fire_cap_charge(at), true)
		Consumables.NITRO_SIPHON:
			result.merge(_fire_nitro_siphon(at), true)
		Consumables.ANCHOR_FLARE:
			result.merge(_fire_anchor_flare(at), true)
		Consumables.OVERCLOCK_CARD:
			result.merge(_fire_overclock_card(at), true)
		Consumables.FOREMAN_MEMO:
			result.merge(_fire_foreman_memo(at), true)
		Consumables.MOSS_PATCH:
			result.merge(_fire_moss_patch(at), true)
		Consumables.SCRAP_DICE, Consumables.DUPLICATOR_SPOOL, Consumables.OVERLOAD_FUSE:
			result.merge(Consumables.fire_w50(cid, ctx, combat, at), true)
	consumable_uses += 1
	last_consumable = result
	if ctx.events != null and ctx.events.has_signal("consumable_used"):
		ctx.events.consumable_used.emit(cid, at)
	return result


func _fire_cap_charge(at: Vector3) -> Dictionary:
	var row := Consumables.row_of(Consumables.CAP_CHARGE)
	var radius := float(row.get("radius_m", 6.0))
	var dmg: float = float(row.get("blast_damage", 38.0)) * combat.heft()
	var warden_posture := float(row.get("warden_posture", 45.0))
	if ctx.destructibles != null and is_instance_valid(ctx.destructibles) and ctx.destructibles.has_method("on_blast"):
		ctx.destructibles.on_blast(at, radius, Consumables.CAP_CHARGE, 0, Destructibles.TIER_MAX)
	var stripped := 0
	var hits := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.global_position.distance_to(at) > radius + combat.hull_radius(enemy):
			continue
		var kind := String(enemy.get("kind")) if enemy.get("kind") != null else ""
		if kind == "plated_brute" and enemy.has_method("strip_plate") and enemy.strip_plate():
			stripped += 1
		elif kind == "warden":
			if enemy.has_method("apply_posture_hit"):
				enemy.apply_posture_hit({"gain": warden_posture, "full": true, "crack": false, "shatter": false, "dealt": 0.0})
			elif enemy.has_method("take_damage"):
				combat.strike(enemy, "blast", dmg, enemy.family_point() if enemy.has_method("family_point") else "", "consumable")
			stripped += 1
		if enemy.has_method("plating_now") and float(enemy.plating_now()) > 0.0 and kind != "warden":
			combat.add_shred(enemy, float(enemy.plating_now()) / maxf(combat.SHRED_PER_PUNCH, 0.01))
		if kind != "warden":
			combat.deal_hit(enemy, "blast", dmg, enemy.global_position - at, 12.0, "", "consumable")
		hits += 1
	combat.effects.shockwave(at, radius, row.get("color", Palette.AMBER))
	return {"radius": radius, "stripped": stripped, "hits": hits}


func _fire_nitro_siphon(at: Vector3) -> Dictionary:
	var row := Consumables.row_of(Consumables.NITRO_SIPHON)
	var dur := float(row.get("duration_s", 6.0))
	_nitro_left = maxf(_nitro_left, dur)
	post_consumable_buff("consumable_nitro_siphon", String(row["icon"]), row["color"], _nitro_left)
	var ripped := _step_nitro_siphon(get_tree().get_nodes_in_group(Groups.ENEMY))
	combat.effects.ring(at, 4.5, row.get("color", Palette.COPPER))
	return {"duration_s": dur, "ripped": ripped}


func _step_nitro_siphon(enemies: Array) -> int:
	var row := Consumables.row_of(Consumables.NITRO_SIPHON)
	var cruise: float = ctx.player.tuning.f("cruise")
	var blazing_floor: float = cruise * float(SpeedTier.MULTIPLES[SpeedTier.BLAZING])
	if not Augments.holding(ctx.player.kit):
		var v: Vector3 = ctx.player.state.velocity
		var flat := Vector3(v.x, 0.0, v.z)
		if flat.length() < blazing_floor:
			var dir: Vector3 = flat.normalized() if flat.length_squared() > 0.01 else ctx.heading()
			dir.y = 0.0
			dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
			ctx.player.set_velocity_now(Vector3(dir.x * blazing_floor, v.y, dir.z * blazing_floor), "nitro_siphon")
	if ctx.player.state.carving:
		var grip_bonus := float(row.get("grip_bonus", 0.50))
		ctx.player.state.grip_hold = maxf(ctx.player.state.grip_hold, 0.25)
		var n: Vector3 = ctx.player.state.contact_normal
		if n.length_squared() > 0.01:
			ctx.player.add_external_accel(-n.normalized() * ctx.player.tuning.f("drive_accel") * grip_bonus)
	var rip_r := float(row.get("rip_radius_m", 14.0))
	var ball: Vector3 = ctx.player.ball_position()
	var ripped := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var kind := String(enemy.get("kind")) if enemy.get("kind") != null else ""
		if kind == "boom_tender":
			if enemy.global_position.distance_to(ball) <= rip_r + 12.0:
				if enemy.has_method("pop_all_floats"):
					ripped += enemy.pop_all_floats(false)
				if enemy.has_method("cancel_attack"):
					enemy.cancel_attack()
		elif kind == "jolt_layer":
			if enemy.get("field") != null and enemy.global_position.distance_to(ball) <= rip_r + 10.0:
				enemy.field = null
				if enemy.has_method("cancel_attack"):
					enemy.cancel_attack()
				ripped += 1
		elif kind == "gap_net":
			var nets = enemy.get("nets")
			if nets is Array:
				for net in nets:
					if net is Dictionary and bool(net.get("live", false)):
						var origin: Vector3 = net.get("origin", enemy.global_position)
						if origin.distance_to(ball) <= rip_r + 6.0 and enemy.has_method("_tear"):
							enemy._tear(net)
							ripped += 1
		elif kind == "netcaster":
			if enemy.global_position.distance_to(ball) <= rip_r + 8.0 and enemy.has_method("cancel_attack"):
				enemy.cancel_attack()
				ripped += 1
	return ripped


func _fire_anchor_flare(at: Vector3) -> Dictionary:
	var row := Consumables.row_of(Consumables.ANCHOR_FLARE)
	var height := float(row.get("height_m", 18.0))
	var dur := float(row.get("duration_s", 15.0))
	var radius := float(row.get("bite_radius_m", 2.8))
	var sky_at := at + Vector3.UP * height
	var balloon := Consumables.spawn_balloon(sky_at, dur, radius)
	ctx.root.add_child(balloon)
	_balloons.append(balloon)
	post_consumable_buff("consumable_anchor_flare", String(row["icon"]), row["color"], dur)
	combat.effects.arc(at, sky_at, row.get("color", Palette.ARC))
	return {"balloon": balloon, "at_sky": sky_at, "duration_s": dur}


func _fire_overclock_card(at: Vector3) -> Dictionary:
	var row := Consumables.row_of(Consumables.OVERCLOCK_CARD)
	var dur := float(row.get("duration_s", 8.0))
	_overclock_left = maxf(_overclock_left, dur)
	_refresh_overclock_cooldowns()
	post_consumable_buff("consumable_overclock_card", String(row["icon"]), row["color"], _overclock_left)
	combat.effects.ring(at, 4.0, row.get("color", Palette.SAND))
	return {"duration_s": dur}


func _refresh_overclock_cooldowns() -> void:
	if ctx == null or ctx.player == null:
		return
	ctx.player.state.boost_cooldown = 0.0
	var abilities = ctx.player.abilities
	if abilities == null:
		return
	for slot_name in [AbilityState.MOVEMENT, AbilityState.SPECIAL]:
		var s = abilities.slot(slot_name)
		if s != null:
			s.charges = s.max_charges
			s.recharge = 0.0
			s.cycle_refunded = 0.0


func apply_overclock_shots(shots: Array, p: Resource) -> Array:
	var row := Consumables.row_of(Consumables.OVERCLOCK_CARD)
	var mult := float(row.get("skilled_damage_mult", 1.5))
	var out: Array = []
	for shot in shots:
		var s: Dictionary = (shot as Dictionary).duplicate(true)
		s["overclock_skilled"] = true
		s["damage_mult"] = maxf(float(s.get("damage_mult", 1.0)), mult)
		if p != null:
			match String(p.trigger):
				Pattern.TRIGGER_STAMP:
					s["paid"] = true
					s["kind"] = WeaponDriver.SHOT_STAMP
					s["refund"] = maxf(float(s.get("refund", 0.0)), float(p.cast_cost) * 0.5)
				Pattern.TRIGGER_LOCK:
					s["kind"] = WeaponDriver.SHOT_RAIL
				Pattern.TRIGGER_BEATS:
					s["kind"] = WeaponDriver.SHOT_BEAT_3
				Pattern.TRIGGER_PRESS:
					s["pierce"] = true
				Pattern.TRIGGER_TAP_CHARGE:
					s["pierce"] = true
		overclock_skilled_shots += 1
		out.append(s)
	return out


func _fire_foreman_memo(at: Vector3) -> Dictionary:
	var row := Consumables.row_of(Consumables.FOREMAN_MEMO)
	var dur := float(row.get("duration_s", 5.0))
	var radius := float(row.get("radius_m", 24.0))
	var spacing := float(row.get("formation_spacing_m", 2.6))
	var paid_cost := ""
	if ctx.run.bonus_cores >= int(row.get("core_cost", 1)) and ctx.run.lose_core():
		paid_cost = "core"
	else:
		var hull_cost: float = float(ctx.run.max_hp) * float(row.get("hull_cost_share", 0.10))
		ctx.run.hp = maxf(1.0, float(ctx.run.hp) - hull_cost)
		ctx.run.since_damage = 0.0
		paid_cost = "hull"
	_memo_left = maxf(_memo_left, dur)
	var forward: Vector3 = ctx.heading()
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.01 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP).normalized()
	var targets: Array = []
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var kind := String(enemy.get("kind")) if enemy.get("kind") != null else ""
		if not EnemyBase.is_ordinary_kind(kind):
			continue
		if enemy.global_position.distance_to(at) <= radius:
			targets.append(enemy)
	targets.sort_custom(func(a, b): return a.global_position.distance_to(at) < b.global_position.distance_to(at))
	var anchor := at + forward * 8.0
	for i in targets.size():
		var enemy: Node3D = targets[i]
		var offset := (float(i) - float(targets.size() - 1) * 0.5) * spacing
		var slot_pos := anchor + right * offset
		if combat.ground != null and combat.ground.has_method("height"):
			var hh: float = float(enemy.get("half_height")) if enemy.get("half_height") != null else 0.7
			slot_pos.y = float(combat.ground.height(slot_pos.x, slot_pos.z)) + hh
		else:
			slot_pos.y = enemy.global_position.y
		if enemy.has_method("cancel_attack"):
			enemy.cancel_attack()
		var id := enemy.get_instance_id()
		if not _memo_frozen.has(id):
			_memo_frozen[id] = {
				"enemy": enemy,
				"pos": slot_pos,
				"prev_mode": enemy.process_mode,
			}
		else:
			_memo_frozen[id]["pos"] = slot_pos
		enemy.global_position = slot_pos
		if enemy is CharacterBody3D:
			(enemy as CharacterBody3D).velocity = Vector3.ZERO
		if enemy.has_method("plating_now") and float(enemy.plating_now()) > 0.0:
			combat.add_shred(enemy, float(enemy.plating_now()) / maxf(combat.SHRED_PER_PUNCH, 0.01))
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	post_consumable_buff("consumable_foreman_memo", String(row["icon"]), Palette.SAND, _memo_left)
	return {"duration_s": dur, "frozen": targets.size(), "cost": paid_cost}


func _hold_memo_formation() -> void:
	for id in _memo_frozen.keys():
		var entry: Dictionary = _memo_frozen[id]
		var enemy = entry["enemy"]
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			_memo_frozen.erase(id)
			continue
		enemy.global_position = entry["pos"]
		if enemy is CharacterBody3D:
			(enemy as CharacterBody3D).velocity = Vector3.ZERO


func _release_memo_formation() -> void:
	for id in _memo_frozen.keys():
		var entry: Dictionary = _memo_frozen[id]
		var enemy = entry["enemy"]
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			enemy.process_mode = int(entry.get("prev_mode", Node.PROCESS_MODE_INHERIT))
	_memo_frozen.clear()


func _fire_moss_patch(at: Vector3) -> Dictionary:
	var row := Consumables.row_of(Consumables.MOSS_PATCH)
	var heal_amt: float = float(ctx.run.max_hp) * float(row.get("heal_share", 0.35))
	var hp_before: float = float(ctx.run.hp)
	ctx.run.heal(heal_amt)
	var grace_s := float(row.get("grace_s", 1.5))
	ctx.run.grant_consumable_grace(grace_s)
	var radius := float(row.get("knock_radius_m", 12.0))
	var force := float(row.get("knock_force", 18.0))
	var knocked := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.global_position.distance_to(at) > radius:
			continue
		var away: Vector3 = enemy.global_position - at
		away.y = 0.0
		var dir := away.normalized() if away.length_squared() > 0.01 else Vector3.FORWARD
		if enemy.has_method("knock"):
			enemy.knock(dir + Vector3.UP * 0.25, force)
			knocked += 1
	combat.effects.shockwave(at, radius, row.get("color", Palette.VERDIGRIS))
	return {"healed": ctx.run.hp - hp_before, "knocked": knocked, "grace_s": grace_s}


func post_consumable_buff(buff_id: String, icon: String, tone: Color, duration_s: float) -> void:
	if ctx == null or ctx.buffs == null or duration_s < 3.0:
		return
	ctx.buffs.post(buff_id, {
		"icon": icon,
		"tone": tone,
		"duration_s": duration_s,
		"kind": BuffLedger.KIND_TIMER,
		"stacks": 1,
		"max_stacks": 1,
	})


func reset() -> void:
	_nitro_left = 0.0
	_overclock_left = 0.0
	_memo_left = 0.0
	_release_memo_formation()
	for b in _balloons:
		if is_instance_valid(b):
			if ctx != null and ctx.player != null and ctx.player.kit != null and ctx.player.kit.hooked and ctx.player.kit.anchor_body == b:
				ctx.player.kit.drop_line("reset")
			b.remove_from_group(Augments.STAKE_GROUP)
			b.remove_from_group(Augments.ANCHOR_GROUP)
			b.remove_from_group(Consumables.BALLOON_GROUP)
			b.queue_free()
	_balloons.clear()
	for d in _consumable_drops:
		if is_instance_valid(d):
			d.remove_from_group(Consumables.DROP_GROUP)
			d.queue_free()
	_consumable_drops.clear()
	for id in ["consumable_nitro_siphon", "consumable_anchor_flare", "consumable_overclock_card", "consumable_foreman_memo", "consumable_duplicator_spool"]:
		combat.clear_buff(id)
	Consumables.clear_w50(ctx.run if ctx != null else null)
