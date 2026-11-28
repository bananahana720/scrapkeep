extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const Groups := preload("res://src/core/groups.gd")
const HeroFx := preload("res://src/presentation/hero_fx.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const Palette := preload("res://src/core/palette.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Weapons := preload("res://src/combat/weapons.gd")

var ctx
var combat
var _beachhead_pylon := {}
var last_kinetic_arc := {}
var last_ricochet := {}
var _kest_trace_left := 0.0
var last_kest_trace := {}


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "HeroHooks"


func step(delta: float, enemies: Array) -> void:
	_step_kinetic_pylon(delta, enemies)
	_step_kest_fuse_trace(delta, enemies)


func reset() -> void:
	_beachhead_pylon = {}
	last_kinetic_arc = {}
	last_ricochet = {}
	_kest_trace_left = 0.0
	last_kest_trace = {}
	var hfx = hero_fx()
	if hfx != null:
		hfx.clear()


func hero_fx():
	var pres = ctx.root.get("presentation") if ctx != null and ctx.root != null else null
	var vfx_node = pres.get("vfx") if pres != null else null
	return vfx_node.get("hero_fx") if vfx_node != null else null


func _h1_audio():
	var pres = ctx.root.get("presentation") if ctx != null and ctx.root != null else null
	return pres.get("audio") if pres != null else null


func plant_beachhead_pylon(at: Vector3) -> void:
	_beachhead_pylon = {
		"at": at,
		"life": Weapons.KINETIC_PYLON_LIFE_S,
		"overcharge_left": 0.0,
		"arc_cd": 0.0,
		"orbit_accum": 0.0,
		"prev_angle": INF,
		"arcs_fired": 0,
		"reason": "",
	}
	var hfx = hero_fx()
	if hfx != null:
		hfx.set_sable_pylon_ring(at, Weapons.KINETIC_PYLON_ORBIT_RADIUS, false, true)


func on_dismounted_kinetic_pylon(velocity: Vector3) -> void:
	if ctx == null or ctx.run == null or ctx.run.class_def == null or ctx.run.class_def.id != ClassDef.SABLE_ID:
		return
	if _beachhead_pylon.is_empty():
		return
	var cruise := float(ctx.player.tuning.f("cruise"))
	if velocity.length() >= cruise:
		_overcharge_kinetic_pylon("vault_kick")


func on_vault_kicked(at: Vector3, _speed: float) -> void:
	if ctx == null or ctx.run == null or ctx.run.class_def == null or not ctx.flow.in_play():
		return
	if ctx.run.class_def.id != ClassDef.SABLE_ID:
		return
	combat.weapon_driver.arm_instant_max_charge(Weapons.VAULT_INSTANT_CHARGE_S)
	combat.effects.ring(at, 2.2, Palette.ARC)
	if not _beachhead_pylon.is_empty():
		var pylon_at: Vector3 = _beachhead_pylon["at"]
		if at.distance_to(pylon_at) <= Weapons.KINETIC_PYLON_VAULT_RADIUS:
			_overcharge_kinetic_pylon("vault_kick")
			return
	if combat.ultimate != null and combat.ultimate.stakes != null:
		for stake in combat.ultimate.stakes.nodes:
			if is_instance_valid(stake) and at.distance_to(stake.global_position) <= Weapons.KINETIC_PYLON_VAULT_RADIUS:
				plant_beachhead_pylon(stake.global_position)
				_overcharge_kinetic_pylon("vault_kick")
				return


func _overcharge_kinetic_pylon(reason: String) -> void:
	if _beachhead_pylon.is_empty():
		return
	_beachhead_pylon["overcharge_left"] = maxf(float(_beachhead_pylon.get("overcharge_left", 0.0)), Weapons.KINETIC_PYLON_OVERCHARGE_S)
	_beachhead_pylon["life"] = maxf(float(_beachhead_pylon.get("life", 0.0)), Weapons.KINETIC_PYLON_OVERCHARGE_S + 2.0)
	_beachhead_pylon["reason"] = reason
	_beachhead_pylon["orbit_accum"] = 0.0
	var at: Vector3 = _beachhead_pylon["at"]
	combat.effects.ring(at, 4.0, Palette.ARC)
	var hfx = hero_fx()
	if hfx != null:
		hfx.set_sable_pylon_ring(at, Weapons.KINETIC_PYLON_ORBIT_RADIUS, true, true)


func _step_kinetic_pylon(delta: float, enemies: Array) -> void:
	if ctx == null or ctx.run == null or ctx.run.class_def == null or ctx.run.class_def.id != ClassDef.SABLE_ID:
		if not _beachhead_pylon.is_empty():
			_beachhead_pylon = {}
			var hfx_off = hero_fx()
			if hfx_off != null:
				hfx_off.set_sable_pylon_ring(Vector3.ZERO, 0.0, false, false)
		return
	if _beachhead_pylon.is_empty():
		return
	_beachhead_pylon["life"] = float(_beachhead_pylon["life"]) - delta
	if float(_beachhead_pylon["life"]) <= 0.0:
		_beachhead_pylon = {}
		var hfx_end = hero_fx()
		if hfx_end != null:
			hfx_end.set_sable_pylon_ring(Vector3.ZERO, 0.0, false, false)
		return
	var at: Vector3 = _beachhead_pylon["at"]
	var player = ctx.player
	var cruise := float(player.tuning.f("cruise"))
	var speed: float = player.state.velocity.length()
	var moving_at_speed: bool = not player.kit.mounted and speed >= cruise
	var hfx = hero_fx()
	if not moving_at_speed:
		_beachhead_pylon["overcharge_left"] = maxf(0.0, float(_beachhead_pylon["overcharge_left"]) - delta)
		_beachhead_pylon["prev_angle"] = INF
		if hfx != null:
			hfx.set_sable_pylon_ring(at, Weapons.KINETIC_PYLON_ORBIT_RADIUS, false, true)
		return
	var offset: Vector3 = player.ball_position() - at
	var planar_dist := Vector2(offset.x, offset.z).length()
	if planar_dist <= Weapons.KINETIC_PYLON_ORBIT_RADIUS and planar_dist >= 0.5:
		var ang := atan2(offset.z, offset.x)
		var prev_ang := float(_beachhead_pylon.get("prev_angle", INF))
		if is_finite(prev_ang):
			var sweep := absf(angle_difference(prev_ang, ang))
			_beachhead_pylon["orbit_accum"] = float(_beachhead_pylon.get("orbit_accum", 0.0)) + sweep
			if float(_beachhead_pylon["orbit_accum"]) >= Weapons.KINETIC_PYLON_ORBIT_RAD \
					or (player.kit.hooked and sweep > 0.05):
				_overcharge_kinetic_pylon("orbit")
		_beachhead_pylon["prev_angle"] = ang
	else:
		_beachhead_pylon["prev_angle"] = INF
	var over_left := float(_beachhead_pylon["overcharge_left"])
	if hfx != null:
		hfx.set_sable_pylon_ring(at, Weapons.KINETIC_PYLON_ORBIT_RADIUS, over_left > 0.0, true)
	if over_left <= 0.0:
		return
	_beachhead_pylon["overcharge_left"] = maxf(0.0, over_left - delta)
	_beachhead_pylon["arc_cd"] = float(_beachhead_pylon.get("arc_cd", 0.0)) - delta
	if float(_beachhead_pylon["arc_cd"]) > 0.0:
		return
	var tier := int(player.speed_tier())
	var cadence := Weapons.KINETIC_PYLON_BLAZING_CADENCE if tier >= SpeedTier.BLAZING \
		else (Weapons.KINETIC_PYLON_FAST_CADENCE if tier >= SpeedTier.FAST else Weapons.KINETIC_PYLON_ARC_CADENCE)
	var tier_scale := 1.45 if tier >= SpeedTier.BLAZING else (1.20 if tier >= SpeedTier.FAST else 1.0)
	var dmg: float = Weapons.KINETIC_PYLON_ARC_DAMAGE * tier_scale * combat.damage_mod(Weapons.ARC_CASTER)
	var picks: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or DamageDoor.dead(enemy):
			continue
		var d: float = enemy.global_position.distance_to(at)
		if d <= Weapons.KINETIC_PYLON_ARC_RADIUS:
			picks.append([d, enemy])
	picks.sort_custom(func(a, b): return a[0] < b[0])
	if picks.is_empty():
		return
	_beachhead_pylon["arc_cd"] = cadence
	var hit_enemies: Array = []
	var dealt_total := 0.0
	for pair in picks.slice(0, Weapons.KINETIC_PYLON_ARC_TARGETS):
		var target: Node3D = pair[1]
		combat.effects.arc(at + Vector3.UP * 0.6, target.global_position + Vector3.UP * 0.6, Palette.ARC)
		combat.deal_hit(target, "arc", dmg, target.global_position - at, 4.0, "", "persistent_actor")
		hit_enemies.append(target)
		dealt_total += dmg
		var chain_next: Node3D = combat.nearest_enemy(target.global_position, Weapons.BASE[Weapons.ARC_CASTER]["chain_range"], hit_enemies)
		if chain_next != null:
			combat.effects.arc(target.global_position + Vector3.UP * 0.6, chain_next.global_position + Vector3.UP * 0.6, Palette.ARC)
			combat.deal_hit(chain_next, "arc", dmg * 0.6, chain_next.global_position - target.global_position, 2.0, "", "persistent_actor")
			hit_enemies.append(chain_next)
			dealt_total += dmg * 0.6
	_beachhead_pylon["arcs_fired"] = int(_beachhead_pylon.get("arcs_fired", 0)) + hit_enemies.size()
	last_kinetic_arc = {
		"at": at,
		"hits": hit_enemies.size(),
		"damage": dealt_total,
		"color": Palette.ARC,
		"reason": String(_beachhead_pylon.get("reason", "")),
	}


func kinetic_pylon_state() -> Dictionary:
	return _beachhead_pylon.duplicate()


func stamp_rivet_sixth_hot(rec: Dictionary) -> void:
	rec["sixth_hot"] = true
	rec["sixth_hot_ricocheted"] = false
	rec["extra_bounces"] = mini(int(rec.get("extra_bounces", 0)) + 1, Bolts.MAX_EXTRA_BOUNCES)
	rec["ricochet_home"] = true
	rec["ricochet_home_reach"] = Weapons.RIVET_RICOCHET_REACH
	rec["ricochet_home_turn"] = 1.0
	rec["color"] = Palette.AMBER.lerp(Palette.COPPER, 0.35)
	rec["width_scale"] = maxf(float(rec.get("width_scale", 1.0)), 1.45)


func resolve_rivet_wall_ricochet(bolt: Dictionary, at: Vector3) -> void:
	bolt["sixth_hot_ricocheted"] = true
	bolt["extra_bounces"] = 0
	var origin: Vector3 = bolt.get("origin", at)
	var target := _pick_ricochet_target(origin, bolt.get("exclude", []))
	var target_end: Vector3 = origin + (bolt["dir"] as Vector3) * minf(float(bolt.get("max_dist", 20.0)), 14.0)
	if not target.is_empty():
		var to_pt: Vector3 = (target["point"] as Vector3) - origin
		if to_pt.length_squared() > 0.0001:
			var dir := to_pt.normalized()
			bolt["dir"] = dir
			var up_hint := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
			bolt["right"] = dir.cross(up_hint).normalized()
			bolt["up"] = (bolt["right"] as Vector3).cross(dir).normalized()
			target_end = target["point"]
	bolt["color"] = Palette.AMBER
	var hfx = hero_fx()
	if hfx != null:
		hfx.add_rivet_hot_tracer(bolt.get("fired_from", at), at, target_end)
	combat.effects.beam(at, target_end, Palette.AMBER, 0.22)
	combat.effects.spark(at, Palette.COPPER)
	_play_rivet_klang_ping(at)
	last_ricochet = {
		"surface": "rock",
		"at": at,
		"to": target_end,
		"target": target.get("enemy", null),
		"part": String(target.get("part", "")),
		"color": Palette.COPPER,
		"accent": Palette.AMBER,
		"sound": "klang_ping",
	}


func resolve_rivet_armor_ricochet(bolt: Dictionary, enemy: Node3D, point: Vector3, _part: String) -> void:
	bolt["sixth_hot_ricocheted"] = true
	var exclude: Array = (bolt.get("exclude", []) as Array).duplicate()
	exclude.append(enemy.get_instance_id())
	var target := _pick_ricochet_target(point, exclude)
	if target.is_empty():
		return
	var target_pt: Vector3 = target["point"]
	var to_target := target_pt - point
	if to_target.length_squared() < 0.0001:
		return
	var dir := to_target.normalized()
	var kid := Bolts.child(bolt, {
		"origin": point + dir * 0.2,
		"dir": dir,
		"speed": Weapons.RIVET_RICOCHET_SPEED,
		"max_dist": minf(Weapons.RIVET_RICOCHET_REACH, to_target.length() + 4.0),
		"damage": float(bolt["damage"]) * Weapons.RIVET_RICOCHET_DAMAGE_MULT,
		"pierce": 0,
		"source": "item_proc",
		"color": Palette.AMBER,
		"width_scale": 1.45,
	})
	kid["bits"] = 0
	kid["spent"] = 0
	kid["extra_bounces"] = 0
	kid["sixth_hot"] = true
	kid["sixth_hot_ricocheted"] = true
	kid["exclude"] = exclude
	combat.bolts.fire(kid)
	var hfx = hero_fx()
	if hfx != null:
		hfx.add_rivet_hot_tracer(bolt.get("fired_from", point), point, target_pt)
	combat.effects.beam(point, target_pt, Palette.AMBER, 0.22)
	combat.effects.spark(point, Palette.COPPER)
	_play_rivet_klang_ping(point)
	last_ricochet = {
		"surface": "armor",
		"at": point,
		"to": target_pt,
		"target": target.get("enemy", null),
		"part": String(target.get("part", "")),
		"color": Palette.COPPER,
		"accent": Palette.AMBER,
		"sound": "klang_ping",
	}


func _pick_ricochet_target(origin: Vector3, exclude: Array) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state if ctx != null and ctx.root != null and ctx.root.is_inside_tree() else null
	var best := {}
	var best_score := INF
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or DamageDoor.dead(enemy):
			continue
		if enemy.get_instance_id() in exclude:
			continue
		var weaks: Array = enemy.weak_points() if enemy.has_method("weak_points") else []
		var target_pt: Vector3 = weaks[0]["at"] if not weaks.is_empty() else enemy.global_position + Vector3.UP * 0.6
		var part_id := String(weaks[0].get("id", "weak")) if not weaks.is_empty() else ""
		var dist := origin.distance_to(target_pt)
		if dist > Weapons.RIVET_RICOCHET_REACH or dist < 0.1:
			continue
		var los := true
		if space != null:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, target_pt, Hitscan.WORLD))
			if not hit.is_empty() and origin.distance_to(hit["position"]) < dist - 0.5:
				los = false
		var score := dist + (0.0 if los else 100.0) - (2.0 if part_id != "" else 0.0)
		if score < best_score:
			best_score = score
			best = {"enemy": enemy, "point": target_pt, "part": part_id, "los": los}
	return best


func _play_rivet_klang_ping(at: Vector3) -> void:
	var audio = _h1_audio()
	if audio == null:
		return
	audio.play_at("ricochet_klang", at, -1.0, 1.05, "SFX", "clank")
	audio.play_at("ricochet_ping", at, -2.0, 1.25, "SFX", "crit_ping")


func refresh_kest_fuse_trace(seconds := Weapons.KEST_FUSE_TRACE_HOLD_S) -> void:
	if ctx == null or ctx.run == null or ctx.run.class_def == null or ctx.run.class_def.id != ClassDef.KEST_ID:
		return
	_kest_trace_left = maxf(_kest_trace_left, maxf(seconds, 0.0))


func _step_kest_fuse_trace(delta: float, enemies: Array) -> void:
	var hfx = hero_fx()
	if ctx == null or ctx.run == null or ctx.run.class_def == null or ctx.run.class_def.id != ClassDef.KEST_ID:
		_kest_trace_left = 0.0
		last_kest_trace = {}
		if hfx != null:
			hfx.clear_kest_fuse_trace()
		return
	_kest_trace_left = maxf(0.0, _kest_trace_left - delta)
	var wg = ctx.player.abilities.gauge(AbilityState.WEAPON)
	var drawing: bool = (wg != null and wg.charging) or bool(ctx.player.air_draw_active)
	if not drawing and _kest_trace_left <= 0.0:
		if hfx != null:
			hfx.clear_kest_fuse_trace()
		return
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var eye: Vector3 = ctx.player.ball_position() + Vector3.UP * 0.65
	var forward: Vector3 = ctx.aim_forward()
	last_kest_trace = HeroFx.scan_kest_sightline(space, eye, forward, enemies, ctx.destructibles, Weapons.KEST_FUSE_TRACE_RANGE)
	if hfx != null:
		hfx.set_kest_fuse_trace(last_kest_trace)
