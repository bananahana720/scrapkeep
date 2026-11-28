extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Roster := preload("res://src/combat/roster.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Palette := preload("res://src/core/palette.gd")
const Groups := preload("res://src/core/groups.gd")
const Relics := preload("res://src/build/relics.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Weapons := preload("res://src/combat/weapons.gd")

const ARC_CHORD_DURATION := 2.5
const ARC_CHORD_TICK := 0.25
const ARC_CHORD_WIDTH := 2.4
const ARC_CHORD_DAMAGE := 9.0
const ARC_CHORD_CAP := 3

const HALO_RANGE := 24.0
const HALO_LIFE := 0.85
const HALO_RADIUS_MIN := 1.2
const HALO_RADIUS_MAX := 3.6
const HALO_DAMAGE_MULT := 0.65
const HALO_CAP := 6

const FAN_STAGGER_S := 0.05
const FAN_SPREAD_DEG := 3.5
const FAN_FOLLOW_MULT := 0.55
const FAN_SIXTH_MULT := 1.4
const FAN_SIXTH_BOUNCES := 2
const FAN_CYLINDER_ROUNDS := 6

const AUGER_RADIUS := 4.5
const AUGER_DURATION := 1.6
const AUGER_TICK := 0.4
const AUGER_DAMAGE := 10.0
const AUGER_CAP := 2

const THERMITE_GLIDE_GRACE := 1.2
const THERMITE_DETONATE_RADIUS := 14.0
const THERMITE_SEAM_LENGTH := 14.0
const THERMITE_SEAM_WIDTH := 2.6
const THERMITE_SEAM_DURATION := 2.0
const THERMITE_SEAM_TICK := 0.4
const THERMITE_SEAM_DAMAGE := 9.0

const CLUSTER_COUNT := 3
const CLUSTER_DAMAGE_MULT := 0.75

const WHIRL_DURATION := 0.45
const WHIRL_ARC_RAD := PI
const WHIRL_RADIUS_MIN := 3.5
const WHIRL_RADIUS_MAX := 9.0
const WHIRL_BOWL_RADIUS := 2.4
const WHIRL_BOWL_DAMAGE := 18.0
const WHIRL_BOWL_KNOCK := 22.0

const TAPE_ECHO_DELAY := 0.3
const TAPE_ECHO_MULT := 0.65

const MORTAR_REACH_MIN := 10.0
const MORTAR_REACH_MAX := 26.0
const MORTAR_RADIUS := 6.5
const MORTAR_SHELLS := 3
const MORTAR_STAGGER_S := 0.22
const MORTAR_DAMAGE_MIN := 18.0
const MORTAR_DAMAGE_MAX := 32.0

const ORBIT_ORBS := 3
const ORBIT_RADIUS := 5.5
const ORBIT_SPEED := 3.6
const ORBIT_DURATION := 3.0
const ORBIT_HIT_RADIUS := 2.2
const ORBIT_HIT_CD := 0.45
const ORBIT_DAMAGE := 11.0

const RAIL_SPARK_COUNT := 4
const RAIL_SPARK_GAP := 0.15
const RAIL_SPARK_DAMAGE := 9.0
const RAIL_SPARK_RANGE := 22.0

const SNARE_APEX_LIFT := 5.5
const SNARE_DURATION := 1.4
const SNARE_APEX_DAMAGE := 10.0

var ctx
var combat
var _clock := 0.0
var _glide_left := 0.0
var _fan_shot_index := 0
var _thermite_detonating := false

var _arc_chords: Array = []
var _halos: Array = []
var _fan_queue: Array = []
var _augers: Array = []
var _seams: Array = []
var _whirls: Array = []
var _tape_echoes: Array = []
var _mortars: Array = []
var _orbit_halo := {}
var _rail_sparks: Array = []
var _snares: Array = []

var last_swap := {}
var swap_counts := {}


static func voltaic_follows(source: String, mutation: String, blazing: bool) -> bool:
	return source == "weapon" and mutation == "arc_ring" and blazing


static func fan_burst_follows(source: String, mutation: String) -> bool:
	return source == "weapon" and mutation == "fan_burst"


static func tape_echo_follows(source: String, mutation: String) -> bool:
	return source == "weapon" and mutation == "ledger_echo"


static func thermite_follows(source: String, mutation: String, from_glide: bool) -> bool:
	return source == "drop_or_slam" and mutation == "thermite_slam" and from_glide


static func auger_follows(source: String, mutation: String) -> bool:
	return source == "drop_or_slam" and mutation == "auger_slam"


static func player_color_safe(c: Color) -> bool:
	return not Color(c.r, c.g, c.b, 1.0).is_equal_approx(Color(Palette.HAZARD.r, Palette.HAZARD.g, Palette.HAZARD.b, 1.0))


func setup(ctx_ref, combat_ref) -> void:
	name = "RelicSwaps"
	ctx = ctx_ref
	combat = combat_ref
	_register_dispatches()
	ctx.events.skid_smashed.connect(_on_skid_smashed)
	ctx.events.demo_slammed.connect(_on_demo_slammed)
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool): reset())
	ctx.events.stage_content_cleared.connect(func(_reason: String): reset())
	ctx.events.player_died.connect(reset)
	ctx.events.run_ended.connect(func(_won: bool): reset())
	ctx.events.run_started.connect(func(_class_id: String): reset(true))


func _register_dispatches() -> void:
	combat.register_line_skill("bank_arc", {
		"on_body": _bank_arc_body,
		"on_world": _bank_arc_world,
		"geometry": func(f: float): return combat.bank_geometry(f),
	})
	combat.register_line_skill("cable_cluster", {
		"on_body": _cable_cluster_body,
		"on_world": _cable_cluster_world,
		"geometry": func(f: float): return combat.ultimate.cable_geometry(f),
	})
	combat.register_line_skill("claw_whirl", {
		"on_body": _claw_whirl_body,
		"on_world": _claw_whirl_world,
		"geometry": _claw_whirl_geometry,
	})
	combat.register_line_skill("rail_vault", {
		"on_body": _rail_vault_body,
		"on_world": _rail_vault_world,
		"geometry": _rail_vault_geometry,
	})
	combat.register_special("halo_discharge", {
		"geometry": func(f: float): return combat.discharge_geometry(f),
		"fire": _fire_halo_discharge,
	})
	combat.register_special("cannon_mortar", {
		"geometry": _mortar_geometry,
		"fire": _fire_cannon_mortar,
	})
	combat.register_special("snare_detonate", {
		"geometry": func(f: float): return combat.line_geometry(f),
		"fire": _fire_snare_detonate,
	})


func reset(clear_counts := false) -> void:
	_glide_left = 0.0
	_fan_shot_index = 0
	_thermite_detonating = false
	_arc_chords.clear()
	_halos.clear()
	_fan_queue.clear()
	_augers.clear()
	_seams.clear()
	_whirls.clear()
	_tape_echoes.clear()
	_mortars.clear()
	_orbit_halo.clear()
	_rail_sparks.clear()
	_snares.clear()
	if clear_counts:
		last_swap = {}
		swap_counts.clear()


func _record(id: String, detail: Dictionary) -> void:
	swap_counts[id] = int(swap_counts.get(id, 0)) + 1
	last_swap = detail.duplicate(true)
	last_swap["id"] = id


func overdrive_for(slot: String) -> float:
	if ctx == null or ctx.run == null:
		return 1.0
	var relic_id := String(Relics.held(ctx.run.parts).get(slot, ""))
	return Relics.overdrive_of(relic_id) if relic_id != "" else 1.0


func _alive(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and not DamageDoor.dead(enemy)


func _protected(enemy: Node3D) -> bool:
	return enemy.has_method("_apply_posture") or combat.target_class_of(enemy) == "boss"


func _is_blazing(shot_desc: Dictionary) -> bool:
	if bool(shot_desc.get("blazing", false)):
		return true
	var planar: float = ctx.player.planar_velocity().length()
	var cruise: float = ctx.player.tuning.f("cruise")
	return SpeedTier.of(planar, cruise) >= SpeedTier.BLAZING


func step(delta: float, enemies: Array) -> void:
	if ctx == null or combat == null or ctx.player == null:
		return
	_clock += delta
	_track_glide(delta)
	_step_arc_chords(delta, enemies)
	_step_halos(delta, enemies)
	_step_fan_queue(delta)
	_step_augers(delta, enemies)
	_step_seams(delta, enemies)
	_step_whirls(delta, enemies)
	_step_tape_echoes(delta)
	_step_mortars(delta)
	_step_orbit_halo(delta, enemies)
	_step_rail_sparks(delta)
	_step_snares(delta)


func _track_glide(delta: float) -> void:
	var kit = ctx.player.kit
	if kit.gliding or bool(ctx.player.air_draw_active):
		_glide_left = THERMITE_GLIDE_GRACE
	elif _glide_left > 0.0:
		_glide_left = maxf(0.0, _glide_left - delta)


func _bank_arc_body(target: Node3D, fraction: float, mult: float) -> void:
	if Augments.anchor_line(target):
		_bank_arc_world(ctx.player.kit.anchor, fraction, mult)
		return
	var exit_from: Vector3 = ctx.player.ball_position()
	var anchor: Vector3 = ctx.player.kit.anchor
	combat.bank_body(target, fraction, mult)
	_spawn_arc_chord(anchor, exit_from, mult)


func _bank_arc_world(anchor: Vector3, fraction: float, mult: float) -> void:
	var exit_from: Vector3 = ctx.player.ball_position()
	combat.bank_world(anchor, fraction, mult)
	_spawn_arc_chord(anchor, exit_from, mult)


func _spawn_arc_chord(from_pt: Vector3, to_pt: Vector3, mult: float) -> void:
	if from_pt.distance_to(to_pt) < 0.25:
		to_pt = from_pt + combat.aim_heading() * 6.0
	if _arc_chords.size() >= ARC_CHORD_CAP:
		_arc_chords.pop_front()
	var od := overdrive_for(AbilityState.LINE)
	var width := ARC_CHORD_WIDTH * (1.25 if od > 1.0 else 1.0)
	var dmg: float = ARC_CHORD_DAMAGE * mult * od * combat.damage_mod(Weapons.ARC_CASTER)
	var rec := {
		"from": from_pt,
		"to": to_pt,
		"width": width,
		"damage": dmg,
		"left": ARC_CHORD_DURATION,
		"tick": 0.0,
		"color": ClassDef.SABLE_COLOR,
		"hits": 0,
	}
	_arc_chords.append(rec)
	combat.effects.arc(from_pt + Vector3.UP * 0.5, to_pt + Vector3.UP * 0.5, ClassDef.SABLE_COLOR)
	_record("bank_arc", {"from": from_pt, "to": to_pt, "width": width, "overdrive": od, "color": ClassDef.SABLE_COLOR})


func _step_arc_chords(delta: float, enemies: Array) -> void:
	if _arc_chords.is_empty():
		return
	var kept := []
	for c in _arc_chords:
		c["left"] = float(c["left"]) - delta
		c["tick"] = float(c["tick"]) - delta
		if float(c["tick"]) <= 0.0:
			c["tick"] = ARC_CHORD_TICK
			var from_pt: Vector3 = c["from"]
			var to_pt: Vector3 = c["to"]
			combat.effects.arc(from_pt + Vector3.UP * 0.5, to_pt + Vector3.UP * 0.5, ClassDef.SABLE_COLOR)
			for enemy in enemies:
				if not _alive(enemy):
					continue
				if combat.in_line(from_pt, to_pt, float(c["width"]), enemy.global_position, combat.hull_radius(enemy)):
					combat.deal_hit(enemy, "arc", float(c["damage"]), to_pt - from_pt, EventKinds.IMPACT["proc"]["knock"], "", "item_proc", "bank_arc")
					c["hits"] = int(c["hits"]) + 1
		if float(c["left"]) > 0.0:
			kept.append(c)
	_arc_chords = kept


func on_weapon_fire(weapon: String, source: String, shot_desc: Dictionary, muzzle: Vector3, forward: Vector3, reach: float, damage: float) -> void:
	if source != "weapon" or ctx == null or ctx.player == null:
		return
	var mut: String = String(ctx.player.abilities.cap(AbilityState.WEAPON, "mutation", ""))
	if voltaic_follows(source, mut, _is_blazing(shot_desc)):
		_spawn_voltaic_halo(muzzle, forward, damage)
	elif fan_burst_follows(source, mut):
		_queue_fan_burst(weapon, shot_desc, muzzle, forward, reach, damage)


func _spawn_voltaic_halo(muzzle: Vector3, forward: Vector3, damage: float) -> void:
	if _halos.size() >= HALO_CAP:
		_halos.pop_front()
	var flat_dir := Vector3(forward.x, 0.0, forward.z)
	var dir: Vector3 = flat_dir.normalized() if flat_dir.length_squared() > 0.0001 else combat.aim_heading()
	var halo := {
		"pos": muzzle,
		"dir": dir,
		"speed": HALO_RANGE / HALO_LIFE,
		"age": 0.0,
		"life": HALO_LIFE,
		"radius": HALO_RADIUS_MIN,
		"damage": damage * HALO_DAMAGE_MULT,
		"color": Palette.BRASS,
		"struck": {},
	}
	_halos.append(halo)
	combat.effects.ring(muzzle, HALO_RADIUS_MIN, Palette.BRASS)
	_record("arc_ring", {"origin": muzzle, "dir": dir, "color": Palette.BRASS, "source": "item_proc"})


func _step_halos(delta: float, enemies: Array) -> void:
	if _halos.is_empty():
		return
	var kept := []
	for h in _halos:
		h["age"] = float(h["age"]) + delta
		var frac := clampf(float(h["age"]) / float(h["life"]), 0.0, 1.0)
		var pos: Vector3 = (h["pos"] as Vector3) + (h["dir"] as Vector3) * (float(h["speed"]) * delta)
		var radius := lerpf(HALO_RADIUS_MIN, HALO_RADIUS_MAX, frac)
		h["pos"] = pos
		h["radius"] = radius
		combat.effects.ring(pos, radius, Palette.BRASS)
		var struck: Dictionary = h["struck"]
		for enemy in enemies:
			if not _alive(enemy):
				continue
			var eid: int = enemy.get_instance_id()
			if struck.has(eid):
				continue
			if combat.in_ring(pos, radius, enemy):
				struck[eid] = true
				combat.deal_hit(enemy, "arc", float(h["damage"]), enemy.global_position - pos, EventKinds.IMPACT["proc"]["knock"], "", "item_proc", "arc_ring")
		if float(h["age"]) < float(h["life"]):
			kept.append(h)
	_halos = kept


func _queue_fan_burst(weapon: String, shot_desc: Dictionary, muzzle: Vector3, forward: Vector3, reach: float, damage: float) -> void:
	_fan_shot_index = (_fan_shot_index % FAN_CYLINDER_ROUNDS) + 1
	var is_sixth: bool = bool(shot_desc.get("sixth_hot", false)) or _fan_shot_index == FAN_CYLINDER_ROUNDS
	if is_sixth:
		_fan_shot_index = 0
	var od := overdrive_for(AbilityState.WEAPON)
	var up_hint := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var right := forward.cross(up_hint).normalized()
	for i in 2:
		var sign_dir := -1.0 if i == 0 else 1.0
		var dir := (forward + right * tan(deg_to_rad(FAN_SPREAD_DEG * sign_dir))).normalized()
		_fan_queue.append({
			"left": FAN_STAGGER_S * float(i + 1),
			"weapon": weapon,
			"dir": dir,
			"reach": reach,
			"damage": damage * FAN_FOLLOW_MULT * od,
			"ricochet": false,
			"bounces": 0,
			"color": ClassDef.RIVET_COLOR,
		})
	if is_sixth:
		_fan_queue.append({
			"left": FAN_STAGGER_S * 2.0,
			"weapon": weapon,
			"dir": forward,
			"reach": reach * 1.15,
			"damage": damage * FAN_SIXTH_MULT * od,
			"ricochet": true,
			"bounces": FAN_SIXTH_BOUNCES + (1 if od > 1.0 else 0),
			"color": Palette.COPPER,
		})
		combat.effects.beam(muzzle, muzzle + forward * minf(reach, 24.0), Palette.COPPER, 0.16)
	_record("fan_burst", {"round": FAN_CYLINDER_ROUNDS if is_sixth else _fan_shot_index, "sixth_ricochet": is_sixth, "queued": 3 if is_sixth else 2, "overdrive": od, "color": Palette.COPPER})


func _step_fan_queue(delta: float) -> void:
	if _fan_queue.is_empty():
		return
	var kept := []
	for item in _fan_queue:
		item["left"] = float(item["left"]) - delta
		if float(item["left"]) > 0.0:
			kept.append(item)
			continue
		var weapon: String = String(item["weapon"])
		var p: Resource = combat.live_pattern(weapon)
		if p == null:
			continue
		var muzzle: Vector3 = ctx.player.ball_position() + (item["dir"] as Vector3) * combat.MUZZLE
		var entry := {"dir": item["dir"], "centre": true, "phase": 0.0}
		var rec: Dictionary = combat.bolt_record(weapon, p, entry, muzzle, float(item["reach"]), float(item["damage"]), "item_proc", 0)
		rec["color"] = item["color"]
		if bool(item["ricochet"]):
			var bounces := int(item.get("bounces", FAN_SIXTH_BOUNCES))
			rec["extra_bounces"] = bounces
			rec["bounces_left"] = bounces
			rec["ricochet_home"] = true
		combat.bolts.fire(rec)
	_fan_queue = kept


func _on_skid_smashed(at: Vector3, _hits: int) -> void:
	if ctx == null or ctx.player == null or not ctx.flow.in_play():
		return
	var mut: String = String(ctx.player.abilities.cap(AbilityState.SMASH, "mutation", ""))
	if not auger_follows("drop_or_slam", mut):
		return
	if _augers.size() >= AUGER_CAP:
		_augers.pop_front()
	var dmg: float = AUGER_DAMAGE * combat.damage_mod(Weapons.RAPID_LASER)
	_augers.append({
		"at": at,
		"radius": AUGER_RADIUS,
		"damage": dmg,
		"left": AUGER_DURATION,
		"tick": 0.0,
		"ticks_fired": 0,
		"color": ClassDef.RIVET_COLOR,
	})
	ctx.break_props(at, AUGER_RADIUS, "auger_slam")
	combat.effects.ring(at, AUGER_RADIUS, ClassDef.RIVET_COLOR)
	combat.effects.ring(at, AUGER_RADIUS * 0.55, Palette.COPPER)
	_record("auger_slam", {"at": at, "radius": AUGER_RADIUS, "tier_bonus": 1, "color": ClassDef.RIVET_COLOR})


func _step_augers(delta: float, enemies: Array) -> void:
	if _augers.is_empty():
		return
	var kept := []
	for a in _augers:
		a["left"] = float(a["left"]) - delta
		a["tick"] = float(a["tick"]) - delta
		if float(a["tick"]) <= 0.0:
			a["tick"] = AUGER_TICK
			a["ticks_fired"] = int(a["ticks_fired"]) + 1
			var at: Vector3 = a["at"]
			var radius: float = float(a["radius"])
			combat.effects.ring(at, radius * (0.4 + 0.15 * float(int(a["ticks_fired"]) % 4)), Palette.COPPER)
			for enemy in enemies:
				if not _alive(enemy):
					continue
				if combat.in_ring(at, radius, enemy):
					combat.deal_hit(enemy, "runner", float(a["damage"]), enemy.global_position - at, EventKinds.IMPACT["proc"]["knock"], "", "item_proc", "auger_slam")
		if float(a["left"]) > 0.0:
			kept.append(a)
	_augers = kept


func _on_demo_slammed(at: Vector3) -> void:
	if ctx == null or ctx.player == null or not ctx.flow.in_play() or _thermite_detonating:
		return
	var mut: String = String(ctx.player.abilities.cap(AbilityState.SMASH, "mutation", ""))
	var from_glide: bool = _glide_left > 0.0 or ctx.player.kit.gliding or bool(ctx.player.air_draw_active)
	if not thermite_follows("drop_or_slam", mut, from_glide):
		return
	_glide_left = 0.0
	var vel: Vector3 = ctx.player.planar_velocity()
	var dir: Vector3 = vel.normalized() if vel.length() > 0.5 else combat.aim_heading()
	var to_pt: Vector3 = at + dir * THERMITE_SEAM_LENGTH
	var dmg: float = THERMITE_SEAM_DAMAGE * combat.damage_mod(Weapons.STICKY_CHARGE)
	_seams.append({
		"from": at,
		"to": to_pt,
		"width": THERMITE_SEAM_WIDTH,
		"damage": dmg,
		"left": THERMITE_SEAM_DURATION,
		"tick": 0.0,
		"color": ClassDef.KEST_COLOR,
	})
	combat.effects.beam(at + Vector3.UP * 0.25, to_pt + Vector3.UP * 0.25, ClassDef.KEST_COLOR, 0.35)
	combat.effects.ring(at, THERMITE_DETONATE_RADIUS, Palette.AMBER)
	_thermite_detonating = true
	var detonated := 0
	var candidates: Array = []
	for charge in combat.sticky.charges.duplicate():
		if charge.get("_inert", false):
			continue
		if String(charge.get("_source", "")) == "drop_or_slam" and absf(combat.clock_now() - float(charge.get("born", combat.clock_now()))) < 0.001:
			continue
		if (charge["pos"] as Vector3).distance_to(at) <= THERMITE_DETONATE_RADIUS:
			candidates.append(["sticky", charge])
	if combat.ultimate != null:
		for charge in combat.ultimate.caught_charges():
			if charge.get("_inert", false):
				continue
			if (charge["pos"] as Vector3).distance_to(at) <= THERMITE_DETONATE_RADIUS:
				candidates.append(["ult", charge])
	for pair in candidates:
		var kind: String = pair[0]
		var charge: Dictionary = pair[1]
		var taken: Dictionary = {}
		if kind == "sticky" and combat.sticky.charges.has(charge):
			taken = combat.sticky.take(charge)
		elif kind == "ult" and combat.ultimate.caught_charges().has(charge):
			taken = combat.ultimate.take_charge(charge)
		if not taken.is_empty():
			combat.detonate(taken, false)
			detonated += 1
	_thermite_detonating = false
	_record("thermite_slam", {"at": at, "to": to_pt, "detonated": detonated, "radius": THERMITE_DETONATE_RADIUS, "color": ClassDef.KEST_COLOR})


func _step_seams(delta: float, enemies: Array) -> void:
	if _seams.is_empty():
		return
	var kept := []
	for s in _seams:
		s["left"] = float(s["left"]) - delta
		s["tick"] = float(s["tick"]) - delta
		if float(s["tick"]) <= 0.0:
			s["tick"] = THERMITE_SEAM_TICK
			var from_pt: Vector3 = s["from"]
			var to_pt: Vector3 = s["to"]
			combat.effects.beam(from_pt + Vector3.UP * 0.2, to_pt + Vector3.UP * 0.2, ClassDef.KEST_COLOR, 0.16)
			for enemy in enemies:
				if not _alive(enemy):
					continue
				if combat.in_line(from_pt, to_pt, float(s["width"]), enemy.global_position, combat.hull_radius(enemy)):
					combat.deal_hit(enemy, "sticky", float(s["damage"]), to_pt - from_pt, EventKinds.IMPACT["proc"]["knock"], "", "item_proc", "thermite_slam")
		if float(s["left"]) > 0.0:
			kept.append(s)
	_seams = kept


func _cable_cluster_body(body: Node3D, fraction: float, mult: float) -> void:
	var start: Vector3 = ctx.player.ball_position()
	var anchor: Vector3 = ctx.player.kit.anchor
	combat.ultimate.cable_body(body, fraction, mult)
	_drop_wire_cluster(start, anchor, mult)


func _cable_cluster_world(at: Vector3, fraction: float, mult: float) -> void:
	var start: Vector3 = ctx.player.ball_position()
	combat.ultimate.cable_world(at, fraction, mult)
	_drop_wire_cluster(start, at, mult)


func _drop_wire_cluster(from_pt: Vector3, to_pt: Vector3, mult: float) -> void:
	var dropped := 0
	var od := overdrive_for(AbilityState.LINE)
	var count := CLUSTER_COUNT + (1 if od > 1.0 else 0)
	var dmg: float = Weapons.MINI_DAMAGE * CLUSTER_DAMAGE_MULT * mult * od * combat.damage_mod(Weapons.STICKY_CHARGE)
	for i in count:
		var t: float = float(i + 1) / float(count + 1)
		var spot: Vector3 = combat.floor_at(from_pt.lerp(to_pt, t) + Vector3.UP)
		var charge: Dictionary = combat.sticky.drop(spot, dmg, Weapons.MINI_RADIUS, Weapons.MINI_FUSE, Weapons.MINI_ARM, 0.0, combat.clock_now())
		charge["_source"] = "item_proc"
		charge["_cluster"] = true
		combat.effects.ring(spot, Weapons.MINI_RADIUS, ClassDef.KEST_COLOR)
		dropped += 1
	_record("cable_cluster", {"from": from_pt, "to": to_pt, "dropped": dropped, "overdrive": od, "color": ClassDef.KEST_COLOR})


func _tarn_claw():
	return combat.get_node_or_null("TarnClaw")


func _claw_whirl_geometry(fraction: float) -> Dictionary:
	var tc = _tarn_claw()
	if tc != null and tc.has_method("geometry"):
		return tc.geometry(fraction)
	return combat.line_reel_geometry(fraction)


func _claw_whirl_world(anchor: Vector3, fraction: float, mult: float) -> void:
	var tc = _tarn_claw()
	if tc != null and tc.has_method("on_world"):
		tc.on_world(anchor, fraction, mult)
	else:
		combat.reel_burst(anchor, fraction, mult)


func _claw_whirl_body(target: Node3D, _fraction: float, mult: float) -> void:
	if not _alive(target):
		return
	var movable: bool = not _protected(target) and Roster.heft_of(target) <= ctx.player.heft()
	if not movable:
		var tc = _tarn_claw()
		if tc != null and tc.has_method("on_body"):
			tc.on_body(target, _fraction, mult)
		else:
			combat.strike(target, "claw", WHIRL_BOWL_DAMAGE * mult, "", "special")
		_record("claw_whirl", {"whirled": false, "protected": true, "color": ClassDef.TARN_COLOR})
		return
	var centre: Vector3 = ctx.player.ball_position()
	var offset: Vector3 = target.global_position - centre
	offset.y = 0.0
	var radius: float = clampf(offset.length(), WHIRL_RADIUS_MIN, WHIRL_RADIUS_MAX)
	var start_angle: float = atan2(offset.z, offset.x) if offset.length() > 0.01 else 0.0
	var od := overdrive_for(AbilityState.LINE)
	var whirl := {
		"enemy": weakref(target),
		"eid": target.get_instance_id(),
		"centre": centre,
		"radius": radius,
		"y": target.global_position.y,
		"start_angle": start_angle,
		"elapsed": 0.0,
		"duration": WHIRL_DURATION,
		"damage": WHIRL_BOWL_DAMAGE * mult * od * combat.damage_mod(Weapons.CLAW_SWEEP),
		"struck": {target.get_instance_id(): true},
		"bowled": 0,
		"color": ClassDef.TARN_COLOR,
	}
	_whirls.append(whirl)
	combat.effects.arc(centre + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.5, ClassDef.TARN_COLOR)
	_record("claw_whirl", {"whirled": true, "arc_deg": 180.0, "radius": radius, "overdrive": od, "color": ClassDef.TARN_COLOR})


func _step_whirls(delta: float, enemies: Array) -> void:
	if _whirls.is_empty():
		return
	var kept := []
	for w in _whirls:
		var target = (w["enemy"] as WeakRef).get_ref()
		if not _alive(target):
			continue
		w["elapsed"] = float(w["elapsed"]) + delta
		var frac := clampf(float(w["elapsed"]) / float(w["duration"]), 0.0, 1.0)
		var angle: float = float(w["start_angle"]) + WHIRL_ARC_RAD * frac
		var centre: Vector3 = ctx.player.ball_position()
		var pos := Vector3(centre.x + cos(angle) * float(w["radius"]), float(w["y"]), centre.z + sin(angle) * float(w["radius"]))
		target.global_position = pos
		combat.effects.arc(centre + Vector3.UP * 0.4, pos + Vector3.UP * 0.4, ClassDef.TARN_COLOR)
		var struck: Dictionary = w["struck"]
		for enemy in enemies:
			if not _alive(enemy):
				continue
			var eid: int = enemy.get_instance_id()
			if struck.has(eid):
				continue
			var flat_gap := Vector2(enemy.global_position.x - pos.x, enemy.global_position.z - pos.z).length()
			if flat_gap <= WHIRL_BOWL_RADIUS + combat.hull_radius(enemy):
				struck[eid] = true
				w["bowled"] = int(w["bowled"]) + 1
				var tangent := Vector3(-sin(angle), 0.0, cos(angle))
				combat.deal_hit(enemy, "claw", float(w["damage"]), tangent, WHIRL_BOWL_KNOCK, "", "item_proc", "claw_whirl")
		if frac >= 1.0:
			var release_tan := Vector3(-sin(angle), 0.0, cos(angle))
			combat.deal_hit(target, "claw", float(w["damage"]) * 0.75, release_tan, WHIRL_BOWL_KNOCK, "", "item_proc", "claw_whirl")
		else:
			kept.append(w)
	_whirls = kept


func on_ledger_cast(point: Vector3, damage: float, _shot_desc: Dictionary) -> void:
	if ctx == null or ctx.player == null:
		return
	var mut: String = String(ctx.player.abilities.cap(AbilityState.WEAPON, "mutation", ""))
	if not tape_echo_follows("weapon", mut):
		return
	var od := overdrive_for(AbilityState.WEAPON)
	_tape_echoes.append({
		"point": point,
		"damage": damage * TAPE_ECHO_MULT * od,
		"left": TAPE_ECHO_DELAY,
		"color": ClassDef.TALLY_COLOR,
	})
	_record("ledger_echo", {"point": point, "delay": TAPE_ECHO_DELAY, "overdrive": od, "source": "item_proc", "color": ClassDef.TALLY_COLOR})


func _step_tape_echoes(delta: float) -> void:
	if _tape_echoes.is_empty():
		return
	var kept := []
	for e in _tape_echoes:
		e["left"] = float(e["left"]) - delta
		if float(e["left"]) > 0.0:
			kept.append(e)
			continue
		var pt: Vector3 = e["point"]
		var dmg: float = float(e["damage"])
		var hits := 0
		for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not _alive(enemy) or not combat.in_ring(pt, Weapons.BALANCE_RADIUS, enemy):
				continue
			combat.tally_kit.ledger_hit(enemy, dmg, pt, Weapons.LEDGER_KNOCK * 0.6, "item_proc")
			hits += 1
		combat.effects.ring(pt, Weapons.BALANCE_RADIUS, ClassDef.TALLY_COLOR)
		combat.effects.ring(pt, Weapons.BALANCE_RADIUS * 0.68, Palette.LEDGER_CREAM)
		_record("ledger_echo_landed", {"point": pt, "hits": hits, "damage": dmg, "source": "item_proc", "color": ClassDef.TALLY_COLOR})
	_tape_echoes = kept


func _mortar_geometry(f: float) -> Dictionary:
	var reach := AbilityState.Gauge.scaled(f, MORTAR_REACH_MIN, MORTAR_REACH_MAX)
	var centre: Vector3 = combat.floor_at(ctx.player.ball_position() + combat.aim_heading() * reach + Vector3.UP)
	return ctx.player.yours({"kind": "ring", "centre": centre, "radius": MORTAR_RADIUS, "full_radius": MORTAR_RADIUS, "fill": f})


func _fire_cannon_mortar(f: float, shape: Dictionary) -> void:
	var centre: Vector3 = shape["centre"]
	var damage := AbilityState.Gauge.scaled(f, MORTAR_DAMAGE_MIN, MORTAR_DAMAGE_MAX)
	for i in MORTAR_SHELLS:
		var angle := TAU * float(i) / float(MORTAR_SHELLS)
		var ring_at := centre + (Vector3(cos(angle), 0.0, sin(angle)) * 2.2 if i > 0 else Vector3.ZERO)
		var shell_source := "special" if i == 0 else "item_proc"
		var shell_dmg := damage if i == 0 else damage * 0.65
		if i == 0:
			_commit_mortar_shell(ring_at, shell_dmg, shell_source)
		else:
			_mortars.append({
				"at": ring_at,
				"damage": shell_dmg,
				"source": shell_source,
				"left": MORTAR_STAGGER_S * float(i),
			})
	combat.last_burst = {"at": centre, "radius": MORTAR_RADIUS, "damage": damage * combat.damage_mod(Weapons.CANNON_LANE),
		"kind": "cannon_mortar", "breaks_props": true}
	_record("cannon_mortar", {"at": centre, "shells": MORTAR_SHELLS, "radius": MORTAR_RADIUS, "color": ClassDef.CANNON_COLOR})


func _commit_mortar_shell(at: Vector3, damage: float, source: String) -> void:
	combat.cannon.commit_cannon("rush", at, at, MORTAR_RADIUS, damage, source, false,
		{"warn": maxf(Hazard.MIN_WARN, MindAttacks.LANE_WARN), "color": ClassDef.CANNON_COLOR})
	ctx.break_props(at, MORTAR_RADIUS, "cannon_mortar")
	combat.effects.ring(at, MORTAR_RADIUS, ClassDef.CANNON_COLOR)


func _step_mortars(delta: float) -> void:
	if _mortars.is_empty():
		return
	var kept := []
	for m in _mortars:
		m["left"] = float(m["left"]) - delta
		if float(m["left"]) > 0.0:
			kept.append(m)
			continue
		_commit_mortar_shell(m["at"], float(m["damage"]), String(m["source"]))
	_mortars = kept


func _fire_halo_discharge(f: float, shape: Dictionary) -> void:
	combat.fire_discharge(f, shape)
	var dmg: float = ORBIT_DAMAGE * combat.damage_mod(Weapons.PYLON_TURRET)
	_orbit_halo = {
		"left": ORBIT_DURATION,
		"angle": 0.0,
		"radius": ORBIT_RADIUS,
		"damage": dmg,
		"cd": {},
		"hits": 0,
		"color": ClassDef.SABLE_COLOR,
	}
	combat.effects.ring(ctx.player.ball_position(), ORBIT_RADIUS, ClassDef.SABLE_COLOR)
	_record("halo_discharge", {"orbs": ORBIT_ORBS, "radius": ORBIT_RADIUS, "duration": ORBIT_DURATION, "color": ClassDef.SABLE_COLOR})


func _step_orbit_halo(delta: float, enemies: Array) -> void:
	if _orbit_halo.is_empty():
		return
	_orbit_halo["left"] = float(_orbit_halo["left"]) - delta
	if float(_orbit_halo["left"]) <= 0.0:
		_orbit_halo.clear()
		return
	_orbit_halo["angle"] = float(_orbit_halo["angle"]) + ORBIT_SPEED * delta
	var ball: Vector3 = ctx.player.ball_position()
	var radius: float = float(_orbit_halo["radius"])
	var base_angle: float = float(_orbit_halo["angle"])
	var cd_map: Dictionary = _orbit_halo["cd"]
	for i in ORBIT_ORBS:
		var a := base_angle + TAU * float(i) / float(ORBIT_ORBS)
		var orb := ball + Vector3(cos(a) * radius, 0.5, sin(a) * radius)
		var next_a := base_angle + TAU * float((i + 1) % ORBIT_ORBS) / float(ORBIT_ORBS)
		var next_orb := ball + Vector3(cos(next_a) * radius, 0.5, sin(next_a) * radius)
		combat.effects.arc(orb, next_orb, ClassDef.SABLE_COLOR)
		for enemy in enemies:
			if not _alive(enemy):
				continue
			var eid: int = enemy.get_instance_id()
			if float(cd_map.get(eid, -INF)) > _clock:
				continue
			if combat.in_ring(orb, ORBIT_HIT_RADIUS, enemy):
				cd_map[eid] = _clock + ORBIT_HIT_CD
				combat.deal_hit(enemy, "arc", float(_orbit_halo["damage"]), enemy.global_position - ball, EventKinds.IMPACT["proc"]["knock"], "", "item_proc", "halo_discharge")
				_orbit_halo["hits"] = int(_orbit_halo["hits"]) + 1


func _rail_vault_geometry(fraction: float) -> Dictionary:
	var row: Dictionary = combat.line_skill("line_drive")
	if row.has("geometry"):
		return row["geometry"].call(fraction)
	return combat.line_reel_geometry(fraction)


func _rail_vault_body(target: Node3D, fraction: float, mult: float) -> void:
	var dir: Vector3 = (target.global_position - ctx.player.ball_position()).normalized() if _alive(target) else combat.aim_heading()
	var row: Dictionary = combat.line_skill("line_drive")
	if row.has("on_body"):
		row["on_body"].call(target, fraction, mult)
	_activate_rail_vault(dir, mult)


func _rail_vault_world(anchor: Vector3, fraction: float, mult: float) -> void:
	var dir: Vector3 = (anchor - ctx.player.ball_position()).normalized()
	var row: Dictionary = combat.line_skill("line_drive")
	if row.has("on_world"):
		row["on_world"].call(anchor, fraction, mult)
	_activate_rail_vault(dir, mult)


func _activate_rail_vault(dir: Vector3, mult: float) -> void:
	var drv = combat.weapon_driver
	var p: Resource = combat.live_pattern(Weapons.RAPID_LASER)
	var hot_rounds: int = drv.hot_reload_cylinder(Weapons.RAPID_LASER, p)
	var flat := Vector3(dir.x, 0.0, dir.z)
	var heading: Vector3 = flat.normalized() if flat.length_squared() > 0.0001 else combat.aim_heading()
	var dmg: float = RAIL_SPARK_DAMAGE * mult * combat.damage_mod(Weapons.RAPID_LASER)
	for i in RAIL_SPARK_COUNT:
		_rail_sparks.append({
			"left": RAIL_SPARK_GAP * float(i),
			"dir": heading,
			"damage": dmg,
			"side": -1.0 if i % 2 == 0 else 1.0,
		})
	combat.effects.ring(ctx.player.ball_position(), 2.6, ClassDef.RIVET_COLOR)
	_record("rail_vault", {"hot_rounds": hot_rounds, "sparks": RAIL_SPARK_COUNT, "color": ClassDef.RIVET_COLOR})


func _step_rail_sparks(delta: float) -> void:
	if _rail_sparks.is_empty():
		return
	var p: Resource = combat.live_pattern(Weapons.RAPID_LASER)
	var kept := []
	for s in _rail_sparks:
		s["left"] = float(s["left"]) - delta
		if float(s["left"]) > 0.0:
			kept.append(s)
			continue
		if p == null:
			continue
		var base_dir: Vector3 = s["dir"]
		var side_vec := base_dir.cross(Vector3.UP).normalized()
		var spark_dir := (base_dir + side_vec * (0.28 * float(s["side"]))).normalized()
		var muzzle: Vector3 = ctx.player.ball_position() + spark_dir * combat.MUZZLE
		var rec: Dictionary = combat.bolt_record(Weapons.RAPID_LASER, p, {"dir": spark_dir, "centre": true, "phase": 0.0},
			muzzle, RAIL_SPARK_RANGE, float(s["damage"]), "item_proc", 0)
		rec["color"] = ClassDef.RIVET_COLOR
		combat.bolts.fire(rec)
		combat.effects.spark(muzzle, ClassDef.RIVET_COLOR)
	_rail_sparks = kept


func _fire_snare_detonate(f: float, shape: Dictionary) -> void:
	combat.fire_line(f, shape)
	var from_pt: Vector3 = shape["from"]
	var to_pt: Vector3 = shape["to"]
	var width: float = float(shape["width"])
	var ball_heft: float = ctx.player.heft()
	var snared := 0
	var dmg: float = SNARE_APEX_DAMAGE * combat.damage_mod(Weapons.STICKY_CHARGE)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not _alive(enemy) or _protected(enemy):
			continue
		if Roster.heft_of(enemy) > ball_heft:
			continue
		if not combat.in_line(from_pt, to_pt, width, enemy.global_position, combat.hull_radius(enemy)):
			continue
		var apex: Vector3 = enemy.global_position + Vector3.UP * SNARE_APEX_LIFT
		enemy.global_position = apex
		_snares.append({
			"enemy": weakref(enemy),
			"apex": apex,
			"left": SNARE_DURATION,
			"color": ClassDef.KEST_COLOR,
		})
		combat.deal_hit(enemy, "line", dmg, Vector3.UP, 0.0, "", "item_proc", "snare_detonate")
		combat.effects.ring(apex, 2.0, ClassDef.KEST_COLOR)
		snared += 1
	if snared > 0:
		ctx.player.refresh_air_draw()
	_record("snare_detonate", {"snared": snared, "lift": SNARE_APEX_LIFT, "color": ClassDef.KEST_COLOR})


func _step_snares(delta: float) -> void:
	if _snares.is_empty():
		return
	var kept := []
	for s in _snares:
		var enemy = (s["enemy"] as WeakRef).get_ref()
		if not _alive(enemy):
			continue
		s["left"] = float(s["left"]) - delta
		if float(s["left"]) > 0.0:
			var apex: Vector3 = s["apex"]
			enemy.global_position = Vector3(apex.x, apex.y, apex.z)
			kept.append(s)
	_snares = kept
