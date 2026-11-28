extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const Effects := preload("res://src/combat/effects.gd")
const Groups := preload("res://src/core/groups.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Palette := preload("res://src/core/palette.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const CannonAugments := preload("res://src/movement/augments.gd")

const WALK_WINDOW := 2.0
const WALK_REACH := 6.0
const WAKE_DAMAGE := 0.5
const WAKE_MIN_TRAVEL := 1.0
const WAKE_GRACE := 0.5

var ctx
var combat
var _cannon := []
var cannon_count := 0
var _walk := {}
var _wake := {}
var last_cannon_paint := {}
var _recital_index := 0
var _recital_at := -INF
var _cannon_recoil_airborne := false
var _cannon_recoil_air_grace := 0.0
var _cannon_piton := {}
var last_cannon_piton := {}
var last_cannon_recoil_reset := {}


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "CannonKit"


func _cannon_phase() -> int:
	return clampi(ctx.stages.world_of(ctx.run.stage), 1, 3) if ctx.stages != null else 1


func _cannon_ground(p: Vector3) -> float:
	return combat.floor_at(p + Vector3.UP).y


func commit_cannon(family: String, target: Vector3, centre: Vector3, radius: float, damage: float, source: String,
		expose := false, overrides := {}) -> Dictionary:
	cannon_count += 1
	var seed: int = cannon_count * 7919 + ctx.run.stage
	var phase := _cannon_phase()
	var descriptors: Array = MindAttacks.commit(family, seed, target, centre, phase, radius)
	var entry := {"family": family, "hazards": [], "damage": damage, "source": source, "struck": {}, "expose": expose,
		"verb": "", "window": 0.0, "seed": seed, "target": target, "centre": centre, "radius": radius, "phase": phase, "options": overrides, "noted": false, "born": combat.clock_now()}
	for d in descriptors:
		d["id"] = "cannon_%s_%d" % [String(d["id"]).trim_prefix("mind_"), cannon_count]
		for key in ["warn", "live", "from", "dir", "ahead", "half", "band"]:
			if overrides.has(key):
				d[key] = overrides[key]
		var h = Hazard.from_def(d)
		if overrides.has("warn"):
			h.warn_seconds = maxf(0.0, float(overrides["warn"]))
		h.color = overrides["color"] if overrides.has("color") else ClassDef.CANNON_COLOR
		h.ground = _cannon_ground
		ctx.root.add_child(h)
		entry["hazards"].append(h)
		if d.has("verb"):
			entry["verb"] = String(d["verb"])
			entry["window"] = float(d["weak_window"])
	_cannon.append(entry)
	return entry


func step_cannon(delta: float) -> void:
	combat.step_cannon_exposure()
	_step_cannon_recoil_airborne(delta)
	_step_cannon_piton()
	_track_wake()
	_step_cannon_paint()
	if ctx.player.abilities.selected == AbilityState.LINE and ctx.player.abilities.id_of(AbilityState.LINE) == "cannon_lane_charge" and ctx.player.kit.hooked:
		ctx.player.indicator.set_shape(AbilityState.LINE, cannon_line_geometry(1.0))
	elif ctx.player.abilities.id_of(AbilityState.LINE) == "cannon_lane_charge":
		ctx.player.indicator.clear(AbilityState.LINE)
	if _cannon.is_empty():
		return
	var enemies := get_tree().get_nodes_in_group(Groups.ENEMY)
	var kept := []
	for entry in _cannon:
		var done := true
		for h in entry["hazards"]:
			if not is_instance_valid(h):
				continue
			var options: Dictionary = entry["options"]
			if options.has("live_at"):
				h.age = maxf(0.0, h.warn_seconds + combat.clock_now() - float(options["live_at"]))
				h.step(0.0)
			else:
				h.step(delta)
			if h.is_live() and not entry["noted"]:
				entry["noted"] = true
				entry["live_clock"] = combat.clock_now()
				_cannon_note(entry)
			if not h.is_done():
				done = false
			if h.is_live():
				_cannon_strike(entry, h, enemies)
		if done:
			for h in entry["hazards"]:
				if is_instance_valid(h):
					h.queue_free()
		else:
			kept.append(entry)
	_cannon = kept


func _cannon_strike(entry: Dictionary, h: Node3D, enemies: Array) -> void:
	for enemy in enemies:
		if DamageDoor.dead(enemy):
			continue
		var id: int = enemy.get_instance_id()
		if entry["struck"].has(id) or (enemy != entry["options"].get("forced") and not h.contains(enemy.global_position)):
			continue
		entry["struck"][id] = true
		var push: Vector3 = h.heading if h.shape == Hazard.Shape.LANE else enemy.global_position - h.centre
		var options: Dictionary = entry["options"]
		if options.has("budget"):
			var dealt: float = combat.cannon_set_piece_hit(enemy, float(entry["damage"]), h.centre, false, false, options["budget"])
			var record: Dictionary = options["record"]
			if entry["struck"].size() == 1:
				record["zone_hits"] = int(record.get("zone_hits", 0)) + 1
			record["volley_hits"] = int(record.get("volley_hits", 0)) + 1
			record["damage"] = float(record.get("damage", 0.0)) + dealt
		else:
			var chip: float = Weapons.CANNON_AIR_RAIL_CHIP if bool(options.get("overpenetrate", false)) \
				else (Weapons.PIERCE_CHIP if bool(options.get("pierce_chip", false)) else combat.CHIP)
			combat.deal_hit(enemy, "cannon", float(entry["damage"]) * combat.damage_mod(Weapons.CANNON_LANE), push, Weapons.CANNON_KNOCK, "", entry["source"], "", chip)
		if not entry.get("recital_checked", false):
			entry["recital_checked"] = true
			if entry["source"] != "item_proc":
				_cannon_recital(entry["family"], enemy.global_position)
			if options.has("discovery"):
				combat.discover("cannon_lane_charge", enemy.global_position)
		if entry["expose"] and is_instance_valid(enemy) and not enemy.is_dead():
			combat.cannon_expose(enemy, float(entry["window"]), entry["verb"])


func reset_run() -> void:
	free_cannon()
	cannon_count = 0


func free_cannon() -> void:
	_recital_index = 0
	_recital_at = -INF
	combat.clear_exposed()
	for entry in _cannon:
		for h in entry["hazards"]:
			if is_instance_valid(h):
				if h.get_parent() != null:
					h.get_parent().remove_child(h)
				h.queue_free()
	_cannon = []
	_walk = {}
	_wake = {}
	_cannon_recoil_airborne = false
	_cannon_recoil_air_grace = 0.0
	_cannon_piton = {}
	clear_cannon_paint()


func clear_cannon_paint() -> void:
	last_cannon_paint = {}
	if ctx != null and ctx.player != null and ctx.player.get("indicator") != null:
		ctx.player.indicator.clear("cannon_paint")
		ctx.player.indicator.clear("cannon_bracket_l")
		ctx.player.indicator.clear("cannon_bracket_r")


func _cannon_lane_plan(reach_base: float, width_mult: float, allow_walk := true) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var reach: float = reach_base * ctx.tuning.mod("weapon_range")
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, reach + combat.AIM_SLACK)
	var point: Vector3 = aim["point"]
	var centre: Vector3 = combat.ground_under(ball)
	var target := point
	if Vector2(point.x - centre.x, point.z - centre.z).length() < 1.5:
		target = centre + combat.aim_heading() * 10.0
	var mutation: String = ctx.player.abilities.cap(AbilityState.WEAPON, "mutation", "")
	var walked := allow_walk and walk_extends(mutation, _walk, combat.clock_now())
	var half: float = MindAttacks.LANE_HALF * maxf(width_mult, Pattern.MIN_LOCK_WIDTH_MULT)
	var radius := reach
	var ahead: float = maxf(1.0, reach - half)
	var walk_od := 1.0
	if walked:
		walk_od = combat.relic_swaps.overdrive_for(AbilityState.WEAPON) if combat.relic_swaps != null else 1.0
		var walk_reach := WALK_REACH * walk_od
		var flat := Vector3(target.x - centre.x, 0.0, target.z - centre.z)
		var dir_w: Vector3 = flat.normalized() if flat.length_squared() > 0.0001 else combat.aim_heading()
		var end_at: Vector3 = _walk["end"]
		centre = combat.floor_at(end_at + Vector3.UP)
		target = centre + dir_w * 10.0
		radius = walk_reach + half
		ahead = walk_reach
	var flat_dir := Vector3(target.x - centre.x, 0.0, target.z - centre.z)
	var heading: Vector3 = flat_dir.normalized() if flat_dir.length_squared() > 0.0001 else combat.aim_heading()
	return {
		"aim": aim, "point": point, "centre": centre, "target": target, "heading": heading,
		"radius": radius, "ahead": ahead, "half": half, "to": centre + heading * ahead,
		"walked": walked, "overdrive": walk_od, "mutation": mutation, "ball": ball,
	}


func _step_cannon_paint() -> void:
	var is_lane: bool = ctx.player.abilities.cap(AbilityState.WEAPON, "family", "") == "lane"
	var snap: Dictionary = combat.weapon_driver.state_snapshot()
	if not is_lane or not bool(snap.get("painted", false)):
		if not last_cannon_paint.is_empty():
			clear_cannon_paint()
		return
	var weapon: String = combat.active_weapon()
	var p: Resource = combat.live_pattern(weapon)
	if p == null:
		clear_cannon_paint()
		return
	var stage: String = String(snap.get("lock_stage", WeaponDriver.SHOT_PULSE))
	var reach_base: float = float(p.lock_pulse_reach) if float(p.lock_pulse_reach) > 0.0 else float(p.range_m)
	var width_mult: float = float(p.lock_pulse_width_mult)
	var color: Color = ClassDef.CANNON_COLOR
	var air_overpen := false
	if stage == WeaponDriver.SHOT_RAIL:
		reach_base = float(p.lock_rail_reach) if float(p.lock_rail_reach) > 0.0 else float(p.range_m)
		width_mult = float(p.lock_rail_width_mult)
		if cannon_recoil_airborne():
			width_mult *= Weapons.CANNON_AIR_RAIL_WIDTH_MULT
			air_overpen = true
		color = Palette.ARC
	elif stage == WeaponDriver.SHOT_BARRAGE:
		reach_base = float(p.range_m)
		width_mult = float(p.lock_barrage_width_mult)
		color = Palette.SLATE
	var plan := _cannon_lane_plan(reach_base, width_mult, true)
	var from: Vector3 = plan["centre"]
	var to: Vector3 = plan["to"]
	var half: float = float(plan["half"])
	var heading: Vector3 = plan["heading"]
	var side := Vector3.UP.cross(heading).normalized()
	var bracket_norm: float = float(snap.get("lock_bracket", 0.0))
	var bracket_gap: float = bracket_norm * 1.6
	var lane_shape := {"kind": "line", "from": from, "to": to, "full_to": to, "width": half * 2.0,
		"color": color, "ticks": "lane", "fill": 1.0 if stage == WeaponDriver.SHOT_RAIL else 0.5}
	var offset := side * (half + bracket_gap)
	var left_bracket := {"kind": "line", "from": from + offset, "to": to + offset, "width": 0.24, "color": color, "fill": 1.0}
	var right_bracket := {"kind": "line", "from": from - offset, "to": to - offset, "width": 0.24, "color": color, "fill": 1.0}
	ctx.player.indicator.set_shape("cannon_paint", lane_shape)
	ctx.player.indicator.set_shape("cannon_bracket_l", left_bracket)
	ctx.player.indicator.set_shape("cannon_bracket_r", right_bracket)
	last_cannon_paint = {"stage": stage, "from": from, "to": to, "ahead": float(plan["ahead"]),
		"half": half, "width": half * 2.0, "color": color, "bracket_gap": bracket_gap,
		"air_lock_overpen": air_overpen}


func fire_cannon_lane(weapon: String, shot_desc := {}, source := "weapon") -> void:
	var p: Resource = combat.live_pattern(weapon)
	var shot_kind := String(shot_desc.get("kind", "plain"))
	var has_lock_desc := shot_desc.has("damage")
	var damage: float = float(shot_desc["damage"]) if has_lock_desc else (float(p.damage) if (p != null and String(p.trigger) == Pattern.TRIGGER_HOLD_AUTO) else Weapons.LANE_DAMAGE)
	var reach_base: float = float(shot_desc.get("reach", Weapons.CANNON_LANE_REACH)) if has_lock_desc else Weapons.CANNON_LANE_REACH
	var width_mult: float = float(shot_desc.get("width_mult", 1.0)) if has_lock_desc else 1.0
	var pierce: bool = source == "weapon" and bool(shot_desc.get("pierce", false))
	var air_lock_overpen: bool = source == "weapon" and bool(shot_desc.get("air_lock_overpen", false))
	var overpenetrate: bool = source == "weapon" and (bool(shot_desc.get("overpenetrate", false)) or air_lock_overpen)
	var breaks_props: bool = source == "weapon" and (bool(shot_desc.get("breaks_props", false)) or air_lock_overpen)
	var plan := _cannon_lane_plan(reach_base, width_mult, source == "weapon")
	var walk_od: float = float(plan["overdrive"])
	if bool(plan["walked"]):
		damage *= walk_od
	var aim: Dictionary = plan["aim"]
	var point: Vector3 = plan["point"]
	var ball: Vector3 = plan["ball"]
	var overrides := {"ahead": plan["ahead"], "half": plan["half"], "pierce_chip": pierce, "overpenetrate": overpenetrate}
	if shot_kind == WeaponDriver.SHOT_RAIL:
		overrides["color"] = Palette.SAND
	var entry := commit_cannon("lane", plan["target"], plan["centre"], plan["radius"], damage, source, false, overrides)
	var h = entry["hazards"][0]
	var kit = ctx.player.kit
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		var held: Vector3 = kit.anchor_body.global_position
		if h.contains(Vector3(held.x, h.ground_at(held) + 1.0, held.z)) and not h.contains(held):
			(entry["options"] as Dictionary)["forced"] = kit.anchor_body
	var end: Vector3 = (h.centre as Vector3) + (h.heading as Vector3) * float(h.length)
	if shot_kind == WeaponDriver.SHOT_RAIL:
		var side: Vector3 = Vector3.UP.cross(h.heading as Vector3).normalized() * float(h.half_width)
		combat.effects.beam((h.centre as Vector3) + side, end + side, ClassDef.CANNON_COLOR, Effects.RING_LIFE)
		combat.effects.beam((h.centre as Vector3) - side, end - side, ClassDef.CANNON_COLOR, Effects.RING_LIFE)
		if air_lock_overpen:
			combat.effects.beam(h.centre as Vector3, end, Palette.SAND, Effects.RING_LIFE)
	var breached_props: Array[String] = []
	if air_lock_overpen:
		if ctx.destructibles != null and is_instance_valid(ctx.destructibles) and ctx.destructibles.has_method("on_rail_breach"):
			breached_props = ctx.destructibles.on_rail_breach(
				h.centre as Vector3, end, float(h.half_width), Weapons.CANNON_AIR_RAIL_MAX_TIER, "cannon_air_rail")
	elif breaks_props:
		for blast in combat.shape_blasts({"kind": "line", "from": h.centre, "to": end, "width": h.half_width * 2.0}):
			ctx.break_props(blast[0], float(blast[1]), "cannon_rail")
	if source == "weapon" and String(plan["mutation"]) == "cannon_lane_walk":
		_walk = {} if bool(plan["walked"]) else {"end": end, "at": combat.clock_now()}
	if source == "weapon":
		clear_cannon_paint()
	var muzzle: Vector3 = ball + h.heading * combat.MUZZLE
	combat.volleys += 1
	combat.last_shot = {"weapon_id": weapon, "from": muzzle, "to": end, "point": point, "blocked": aim["blocked"], "bolts": 0,
		"volley": combat.volleys, "sprung": false, "kind": shot_kind, "pierce_chip": pierce,
		"damage": damage, "overdrive": walk_od, "width_mult": width_mult, "reach": reach_base, "breaks_props": breaks_props,
		"air_lock_overpen": air_lock_overpen, "overpenetrate": overpenetrate, "breached_props": breached_props}
	ctx.events.shot_fired.emit(weapon, muzzle, end)


static func walk_extends(mutation: String, walk: Dictionary, clock: float) -> bool:
	return mutation == "cannon_lane_walk" and not walk.is_empty() and clock - float(walk["at"]) <= WALK_WINDOW


func on_cannon_dashed(dir: Vector3) -> void:
	if ctx.player.abilities.cap(AbilityState.MOVEMENT, "family", "") != "split_lane":
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length() > 0.01 else combat.aim_heading()
	var centre: Vector3 = combat.ground_under(ctx.player.ball_position())
	commit_cannon("split_lane", centre - flat * 10.0, centre, Weapons.RECOIL_REACH, Weapons.RECOIL_DAMAGE, "special")
	if cannon_piton_staked():
		ctx.player.set_velocity_now(Vector3.ZERO, "piton_stake")
		_cannon_piton["recoil_cancelled"] = true
		_cannon_recoil_airborne = false
		_cannon_recoil_air_grace = 0.0
		last_cannon_piton = {
			"mode": "stake",
			"at": _cannon_piton["anchor"],
			"recoil_cancelled": true,
			"hits": 0,
			"walls_broken": [],
		}
	else:
		_cannon_recoil_airborne = true
		_cannon_recoil_air_grace = Weapons.CANNON_RECOIL_AIR_GRACE_S


func plate_geometry(f: float) -> Dictionary:
	return ctx.player.yours({"kind": "cone", "apex": combat.ground_under(ctx.player.ball_position()), "dir": combat.aim_heading(),
		"length": 2.0 * MindAttacks.PLATE_HALF_BAND, "half_angle": MindAttacks.PLATE_HALF_SPAN, "fill": f})


func fire_plate(f: float, shape: Dictionary) -> void:
	var apex: Vector3 = shape["apex"]
	var dir: Vector3 = shape["dir"]
	var damage := AbilityState.Gauge.scaled(f, Weapons.PLATE_DAMAGE_MIN, Weapons.PLATE_DAMAGE_MAX)
	commit_cannon("plate", apex + dir * MindAttacks.PLATE_HALF_BAND, apex, shape["length"], damage, "special", true)
	combat.last_burst = {"at": apex, "damage": damage * combat.damage_mod(Weapons.CANNON_LANE), "kind": "cannon_plate", "breaks_props": false}


func on_cannon_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05 or ctx.player.abilities.cap(AbilityState.SMASH, "family", "") != "rush":
		return
	var landing: Vector3 = combat.floor_at(at + Vector3.UP)
	var target: Vector3 = landing + combat.aim_heading() * 6.0
	var best := Weapons.RUSH_REACH
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var d := Vector2(enemy.global_position.x - landing.x, enemy.global_position.z - landing.z).length()
		if d <= best:
			best = d
			target = enemy.global_position
	commit_cannon("rush", target, landing, Weapons.RUSH_REACH, Weapons.RUSH_DAMAGE * clampf(strength, 0.5, 1.5),
		"drop_or_slam")
	var from_recoil_surf := _cannon_recoil_airborne or _cannon_recoil_air_grace > 0.0
	_cannon_recoil_airborne = false
	_cannon_recoil_air_grace = 0.0
	if from_recoil_surf and ctx.player.abilities.cap(AbilityState.MOVEMENT, "family", "") == "split_lane":
		ctx.player.abilities.grant(AbilityState.MOVEMENT)
		combat.effects.ring(landing, 3.0, Palette.ANCIENT)
		last_cannon_recoil_reset = {"at": landing, "clock": combat.clock_now()}
	if wake_follows("drop_or_slam", ctx.player.abilities.cap(AbilityState.SMASH, "mutation", "")):
		_lay_wake(landing)


static func wake_follows(source: String, mutation: String) -> bool:
	return source == "drop_or_slam" and mutation == "cannon_rush_wake"


func _track_wake() -> void:
	if ctx.player.abilities.cap(AbilityState.SMASH, "mutation", "") != "cannon_rush_wake":
		if not _wake.is_empty():
			_wake.clear()
		return
	if ctx.player.kit.slamming:
		if _wake.is_empty() or float(_wake["until"]) < INF:
			_wake = {"from": ctx.player.ball_position(), "until": INF}
	elif not _wake.is_empty() and float(_wake["until"]) == INF:
		_wake["until"] = combat.clock_now() + WAKE_GRACE


func _lay_wake(landing: Vector3) -> void:
	var wake := _wake
	_wake = {}
	if wake.is_empty() or combat.clock_now() > float(wake["until"]):
		return
	var from: Vector3 = wake["from"]
	var back := Vector3(from.x - landing.x, 0.0, from.z - landing.z)
	back = back.normalized() if back.length() >= WAKE_MIN_TRAVEL else -combat.aim_heading()
	var reach: float = Weapons.CANNON_LANE_REACH * ctx.tuning.mod("weapon_range")
	commit_cannon("lane", landing + back * 10.0, landing, reach, Weapons.LANE_DAMAGE * WAKE_DAMAGE, "item_proc")


func cannon_audio():
	var presentation = ctx.root.get("presentation")
	return presentation.audio if presentation != null else null


func _cannon_note(entry: Dictionary) -> void:
	var audio = cannon_audio()
	if audio != null:
		var kind: String = {"weapon": "cannon_weapon", "line": "cannon_line_live", "drop_or_slam": "cannon_smash"}.get(entry["source"], "cannon_live")
		if entry["family"] == "split_lane" and entry["source"] == "special" and not entry["options"].has("budget"):
			kind = "cannon_recoil"
		audio.cannon_family(entry["family"], false, kind)


func cannon_line_geometry(fraction: float) -> Dictionary:
	var kit = ctx.player.kit
	var ball: Vector3 = ctx.player.ball_position()
	var from: Vector3 = combat.ground_under(ball)
	var dir: Vector3 = combat.aim_heading()
	var ahead := Weapons.CANNON_LANE_REACH - MindAttacks.LANE_HALF
	if kit.hooked and kit.on_body:
		dir = Vector3(kit.anchor.x - ball.x, 0.0, kit.anchor.z - ball.z).normalized()
		if dir.length() < 0.01:
			dir = combat.aim_heading()
		ahead = Vector2(kit.anchor.x - ball.x, kit.anchor.z - ball.z).length() + Weapons.LANE_CHARGE_PAST
	elif kit.hooked:
		var floor = cannon_floor(kit.anchor)
		if floor != null:
			from = floor
			var normal: Vector3 = kit.anchor_normal
			if absf(normal.y) < 0.7 and Vector2(normal.x, normal.z).length() > 0.01:
				dir = Vector3(normal.x, 0.0, normal.z).normalized()
		else:
			dir = Vector3(kit.anchor.x - ball.x, 0.0, kit.anchor.z - ball.z).normalized()
			if dir.length() < 0.01:
				dir = combat.aim_heading()
	return ctx.player.yours({"kind": "line", "from": from, "to": from + dir * ahead,
		"full_to": from + dir * ahead, "width": MindAttacks.LANE_HALF * 2.0, "fill": fraction})


func cannon_line_body(target: Node3D, fraction: float, mult: float) -> void:
	_cannon_line_fire(fraction, mult, target)


func cannon_line_world(anchor: Vector3, fraction: float, mult: float) -> void:
	_cannon_line_fire(fraction, mult, null)
	_arm_cannon_piton(anchor, ctx.player.kit.anchor_normal, mult)


func _cannon_line_fire(fraction: float, mult: float, target: Node3D) -> void:
	var shape := cannon_line_geometry(fraction)
	var from: Vector3 = shape["from"]
	var to: Vector3 = shape["to"]
	commit_cannon("lane", to, from, from.distance_to(to) + MindAttacks.LANE_HALF,
		Weapons.LANE_CHARGE_DAMAGE * mult, "line", false,
		{"warn": Weapons.LANE_CHARGE_WARN, "live": Weapons.LANE_CHARGE_LIVE,
		"from": from, "dir": (to - from).normalized(), "ahead": from.distance_to(to), "forced": target,
		"discovery": "cannon_lane_charge"})
	var audio = cannon_audio()
	if audio != null:
		audio.cannon_line(ctx.player.chain.combo)


func cannon_floor(at: Vector3):
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1,
		at - Vector3.UP * Weapons.VOID_DROP, CannonAugments.WORLD_MASK))
	return hit["position"] if not hit.is_empty() and (hit["normal"] as Vector3).y >= 0.7 else null


func _cannon_recital(family: String, at: Vector3) -> void:
	if combat.clock_now() - _recital_at > Weapons.RECITAL_SECONDS:
		_recital_index = 0
	if family == MindAttacks.FAMILIES[_recital_index]:
		if _recital_index == 0:
			_recital_at = combat.clock_now()
		_recital_index += 1
	elif family == "lane":
		_recital_at = combat.clock_now()
		_recital_index = 1
	else:
		_recital_index = 0
	if _recital_index == MindAttacks.FAMILIES.size():
		_recital_index = 0
		combat.discover("cannon_recital", at)
		var audio = cannon_audio()
		if audio != null:
			audio.cannon_motif("cannon_recital", true)


func reset_w47_h2_state() -> void:
	_cannon_recoil_airborne = false
	_cannon_recoil_air_grace = 0.0
	_cannon_piton = {}
	last_cannon_piton = {}
	last_cannon_recoil_reset = {}


func cannon_recoil_airborne() -> bool:
	if not _cannon_recoil_airborne or ctx == null or ctx.player == null:
		return false
	return not ctx.player.state.grounded or _cannon_recoil_air_grace > 0.0


func _step_cannon_recoil_airborne(delta: float) -> void:
	if _cannon_recoil_air_grace > 0.0:
		_cannon_recoil_air_grace = maxf(0.0, _cannon_recoil_air_grace - delta)
	if _cannon_recoil_airborne and _cannon_recoil_air_grace <= 0.0 and ctx != null and ctx.player != null and ctx.player.state.grounded and not ctx.player.kit.slamming:
		_cannon_recoil_airborne = false


func on_cannon_grapple_fired(anchor: Vector3) -> void:
	if ctx == null or ctx.player == null or ctx.player.abilities == null:
		return
	if ctx.player.abilities.id_of(AbilityState.LINE) != "cannon_lane_charge":
		return
	var kit = ctx.player.kit
	if kit.hooked and not kit.on_body:
		_arm_cannon_piton(anchor, kit.anchor_normal, float(ctx.player.chain.multiplier()))


func _arm_cannon_piton(anchor: Vector3, normal: Vector3, mult := 1.0) -> void:
	_cannon_piton = {
		"anchor": anchor,
		"normal": normal,
		"staked": true,
		"mult": maxf(mult, 1.0),
		"recoil_cancelled": false,
		"armed_at": combat.clock_now(),
	}
	last_cannon_piton = {
		"mode": "stake",
		"at": anchor,
		"recoil_cancelled": false,
		"hits": 0,
		"walls_broken": [],
	}


func cannon_piton_staked() -> bool:
	return not _cannon_piton.is_empty() and bool(_cannon_piton.get("staked", false)) \
		and ctx != null and ctx.player != null and ctx.player.kit.hooked and not ctx.player.kit.on_body


func cannon_piton_state() -> Dictionary:
	return _cannon_piton.duplicate()


func _step_cannon_piton() -> void:
	if _cannon_piton.is_empty():
		return
	var kit = ctx.player.kit
	if not kit.hooked or kit.on_body:
		if String(kit.line_end) == "reset":
			_cannon_piton = {}
		else:
			detonate_cannon_piton()


func detonate_cannon_piton() -> Dictionary:
	if _cannon_piton.is_empty():
		return {}
	var piton := _cannon_piton
	_cannon_piton = {}
	var anchor: Vector3 = piton["anchor"]
	var mult: float = float(piton.get("mult", 1.0))
	var radius := Weapons.CANNON_PITON_BREACH_RADIUS
	var broken: Array[String] = []
	if ctx.destructibles != null and is_instance_valid(ctx.destructibles) and ctx.destructibles.has_method("on_piton_breach"):
		broken = ctx.destructibles.on_piton_breach(anchor, radius, Weapons.CANNON_PITON_MAX_TIER, "cannon_piton_breach")
	var dmg: float = Weapons.CANNON_PITON_BREACH_DAMAGE * mult * combat.damage_mod(Weapons.CANNON_LANE)
	var hits := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if DamageDoor.dead(enemy) or not combat.in_ring(anchor, radius, enemy):
			continue
		var push: Vector3 = enemy.global_position - anchor
		combat.deal_hit(enemy, "cannon", dmg, push, Weapons.CANNON_PITON_BREACH_KNOCK, "", "special")
		hits += 1
	combat.effects.ring(anchor, radius, Palette.ANCIENT)
	combat.effects.spark(anchor + Vector3.UP * 0.4, Palette.SAND)
	last_cannon_piton = {
		"mode": "breach",
		"at": anchor,
		"radius": radius,
		"hits": hits,
		"damage": dmg,
		"walls_broken": broken,
		"recoil_cancelled": bool(piton.get("recoil_cancelled", false)),
	}
	return last_cannon_piton
