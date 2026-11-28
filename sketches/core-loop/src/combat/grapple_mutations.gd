extends Node

const Augments := preload("res://src/movement/augments.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Groups := preload("res://src/core/groups.gd")
const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

var ctx
var combat
var gravity_ledger: Callable
var _hot_wire_cd := {}
var _det_cord_queue: Array = []
var _tether_live := {}
var _live_bus_charged_until := -1.0
var _live_bus_charges := 0
var _tether_slam_armed := {}
var _grapple_mut_counts := {}
var last_grapple_mut := {}
var _active_grapple_slots := {}


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "GrappleMutations"


func on_enemy_died(id: int) -> void:
	_hot_wire_cd.erase(id)


func reset_grapple_muts_state(clear_counts := false) -> void:
	_hot_wire_cd.clear()
	_det_cord_queue.clear()
	_tether_live.clear()
	_live_bus_charged_until = -1.0
	_live_bus_charges = 0
	_tether_slam_armed.clear()
	combat.clear_buff("grapple_mut_live_bus")
	if ctx != null and ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
		ctx.destructibles.set_swing_heft_bonus(0)
	if clear_counts:
		_grapple_mut_counts.clear()
		last_grapple_mut = {}
	assert(_det_cord_queue.is_empty() and _tether_live.is_empty() and _tether_slam_armed.is_empty())


func sync_grapple_mutations() -> void:
	if ctx == null:
		return
	var slots := {}
	var build_mod = ctx.build
	var fx = build_mod.get("effects") if build_mod != null else null
	if fx != null and fx.has_method("active_grapple_mutations") and ctx.run != null:
		if fx.get("_held_parts") != ctx.run.parts:
			fx.refresh(ctx.run.parts)
		slots = fx.active_grapple_mutations()
	elif ctx.run != null:
		slots = Parts.active_grapple_mutations(ctx.run.parts)
	_active_grapple_slots = slots
	if ctx.player != null and ctx.player.get("chain") != null and ctx.player.chain.has_method("set_mutations"):
		ctx.player.chain.set_mutations(slots)


func active_grapple_mutations() -> Dictionary:
	sync_grapple_mutations()
	return _active_grapple_slots.duplicate(true)


func has_grapple_mutation(mut_id: String) -> bool:
	var mid := Parts.grapple_mutation_id_of(mut_id)
	if mid == "":
		return false
	for slot in _active_grapple_slots:
		var row: Variant = _active_grapple_slots[slot]
		if row is Dictionary and String((row as Dictionary).get("id", "")) == mid:
			return true
	return false


func _grapple_mut_row(mut_id: String) -> Dictionary:
	var mid := Parts.grapple_mutation_id_of(mut_id)
	for slot in _active_grapple_slots:
		var row: Variant = _active_grapple_slots[slot]
		if row is Dictionary and String((row as Dictionary).get("id", "")) == mid:
			return row as Dictionary
	return {}


func grapple_mut_count(mut_id: String) -> int:
	return int(_grapple_mut_counts.get(Parts.grapple_mutation_id_of(mut_id), 0))


func live_bus_charged() -> bool:
	return _live_bus_charges > 0 and combat.clock_now() < _live_bus_charged_until


func det_cord_pending() -> int:
	return _det_cord_queue.size()


func wrecking_flail_taut_active() -> bool:
	if not has_grapple_mutation("wrecking_flail") or ctx == null or ctx.player == null:
		return false
	var kit = ctx.player.kit
	if kit == null or not kit.hooked:
		return false
	return _tether_is_taut(kit, ctx.player.ball_position(), kit.anchor)


func _note_grapple_mut(mut_id: String, details := {}) -> void:
	_grapple_mut_counts[mut_id] = int(_grapple_mut_counts.get(mut_id, 0)) + 1
	var entry := details.duplicate()
	entry["id"] = mut_id
	entry["at_clock"] = combat.clock_now()
	last_grapple_mut = entry


func _tether_is_taut(kit, ball: Vector3, anchor: Vector3) -> bool:
	if kit == null or not kit.hooked:
		return false
	var dist := ball.distance_to(anchor)
	if dist < 1.0:
		return false
	return dist >= kit.rope * 0.80 or kit.winching or kit.line_state == Augments.LINE_SMASH \
		or ctx.player.state.velocity.length() >= 4.0


static func is_pendulum_apex(ball: Vector3, anchor: Vector3, vel: Vector3, min_y: float, hook_time: float, crossed_bottom: bool) -> bool:
	if hook_time < 0.05:
		return false
	if ball.y >= anchor.y - 0.5:
		return false
	var planar := Vector2(vel.x, vel.z).length()
	if planar < 4.0:
		return false
	return crossed_bottom or (absf(vel.y) <= 6.5 and ball.y <= min_y + 1.8)


func on_grapple_fired_muts(anchor: Vector3) -> void:
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return
	sync_grapple_mutations()
	_hot_wire_cd.clear()
	var ball: Vector3 = ctx.player.ball_position()
	var vel: Vector3 = ctx.player.state.velocity
	var kit = ctx.player.kit
	var body: Node3D = kit.anchor_body if kit != null and is_instance_valid(kit.anchor_body) else null
	_tether_live = {
		"from": ball,
		"to": anchor,
		"body": body,
		"hook_time": 0.0,
		"min_y": ball.y,
		"prev_vy": vel.y,
		"crossed_bottom": false,
		"prev_smash": kit != null and kit.line_state == Augments.LINE_SMASH,
		"prev_winch": kit != null and kit.winching,
		"live_bus_checked": false,
	}
	_try_charge_live_bus(body, anchor, ball)


func _try_charge_live_bus(body: Node3D, anchor: Vector3, ball: Vector3) -> void:
	if not has_grapple_mutation("live_bus"):
		return
	if bool(_tether_live.get("live_bus_checked", false)):
		return
	_tether_live["live_bus_checked"] = true
	if not _is_powered_world_prop(body, anchor):
		return
	var row := _grapple_mut_row("live_bus")
	var dur := float(row.get("charge_duration_s", 8.0))
	_live_bus_charges = 1
	_live_bus_charged_until = combat.clock_now() + dur
	combat.post_buff("grapple_mut_live_bus", {
		"icon": "cat_damage",
		"tone": Palette.AMBER,
		"duration_s": dur,
		"left_s": dur,
		"kind": BuffLedger.KIND_TIMER,
		"stacks": 1,
		"max_stacks": 1,
	})
	combat.effects.arc(anchor, ball, Palette.AMBER)
	combat.effects.spark(ball, Palette.AMBER)
	_note_grapple_mut("live_bus", {"stage": "charge", "anchor": anchor, "color": Palette.AMBER})


func _is_powered_world_prop(body: Node3D, anchor: Vector3) -> bool:
	if is_instance_valid(body):
		if body.is_in_group("sluice_valve_bite") or body.has_meta("sluice_valve_id"):
			return true
		if body.is_in_group("powered_prop") or bool(body.get_meta("powered", false)):
			return true
		if body.is_in_group(Augments.ANCHOR_GROUP) or body.is_in_group(Augments.WORLD_ANCHOR_GROUP) \
				or body.is_in_group(Augments.STAKE_GROUP) or body.is_in_group(Consumables.BALLOON_GROUP):
			return true
		var bname := body.name.to_lower()
		for kw in ["sluice", "valve", "relay", "mast", "pylon", "conduit", "warden"]:
			if kw in bname:
				return true
	if ctx != null and ctx.root != null:
		for grp in ["sluice_valve_bite", "powered_prop", Augments.STAKE_GROUP, Augments.WORLD_ANCHOR_GROUP]:
			for node in get_tree().get_nodes_in_group(grp):
				if node is Node3D and is_instance_valid(node) and (node as Node3D).global_position.distance_to(anchor) <= 4.0:
					return true
	return false


func on_grapple_released_muts() -> void:
	_hot_wire_cd.clear()
	if ctx != null and ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
		ctx.destructibles.set_swing_heft_bonus(0)
	if _tether_live.is_empty():
		return
	var snap := _tether_live
	_tether_live = {}
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return
	sync_grapple_mutations()
	var from: Vector3 = snap.get("from", ctx.player.ball_position())
	var to: Vector3 = snap.get("to", from)
	if has_grapple_mutation("det_cord"):
		_enqueue_det_cord(from, to)
	if has_grapple_mutation("sonic_snap_sling"):
		var ball: Vector3 = ctx.player.ball_position()
		var vel: Vector3 = ctx.player.state.velocity
		if is_pendulum_apex(ball, to, vel, float(snap.get("min_y", ball.y)),
				float(snap.get("hook_time", 0.0)), bool(snap.get("crossed_bottom", false))):
			_fire_sonic_snap_sling(ball, vel)


func _enqueue_det_cord(from: Vector3, to: Vector3) -> void:
	var span := from.distance_to(to)
	if span < 1.5:
		return
	var row := _grapple_mut_row("det_cord")
	var spacing := maxf(1.0, float(row.get("spacing_m", 3.5)))
	var max_nodes := clampi(int(row.get("max_nodes", 6)), 2, 8)
	var count := clampi(int(ceil(span / spacing)), 2, max_nodes)
	var step_delay := float(row.get("step_delay_s", 0.06))
	var radius := float(row.get("blast_radius_m", 4.2))
	var dmg: float = maxf(float(row.get("damage_base", 22.0)), combat.weapon_hit() * 0.9) * combat.heft()
	var knock := float(row.get("knock", 9.0))
	for i in count:
		var frac := float(i + 1) / float(count + 1)
		_det_cord_queue.append({
			"at": from.lerp(to, frac),
			"due": combat.clock_now() + float(i) * step_delay,
			"radius": radius,
			"damage": dmg,
			"knock": knock,
			"index": i,
		})
	_note_grapple_mut("det_cord", {"stage": "queued", "nodes": count, "from": from, "to": to})


func _step_det_cord(enemies: Array) -> void:
	if _det_cord_queue.is_empty():
		return
	var i := 0
	while i < _det_cord_queue.size():
		var entry: Dictionary = _det_cord_queue[i]
		if combat.clock_now() < float(entry["due"]):
			i += 1
			continue
		_det_cord_queue.remove_at(i)
		assert(not _det_cord_queue.has(entry))
		var at: Vector3 = entry["at"]
		var radius := float(entry["radius"])
		var dmg := float(entry["damage"])
		var knock := float(entry["knock"])
		combat.effects.shockwave(at, radius, Palette.BRASS)
		combat.effects.spark(at, Palette.AMBER)
		var hits := 0
		for enemy in enemies:
			if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			if enemy.global_position.distance_to(at) > radius + combat.hull_radius(enemy):
				continue
			combat.deal_hit(enemy, combat.SYNERGY, dmg, enemy.global_position - at, knock, "", "item_proc", "proc")
			hits += 1
		if ctx.destructibles != null and ctx.destructibles.has_method("on_blast"):
			var hc: int = ctx.run.heft_class() if ctx.run != null and ctx.run.has_method("heft_class") else 1
			ctx.destructibles.on_blast(at, radius, "det_cord", 1, hc)
		_note_grapple_mut("det_cord", {"stage": "detonate", "at": at, "hits": hits, "index": int(entry["index"])})


func _fire_sonic_snap_sling(ball: Vector3, vel: Vector3) -> void:
	var row := _grapple_mut_row("sonic_snap_sling")
	var burst := float(row.get("burst_speed", 12.0))
	var flat := Vector3(vel.x, 0.0, vel.z)
	var cur_speed := flat.length()
	var dir: Vector3 = flat.normalized() if cur_speed > 0.1 else combat.aim_heading()
	var cruise: float = ctx.player.tuning.f("cruise")
	var blazing_floor: float = cruise * float(SpeedTier.MULTIPLES[SpeedTier.BLAZING])
	var target_speed := minf(Augments.POLE_EXIT_CAP, maxf(cur_speed + burst, blazing_floor))
	target_speed = maxf(target_speed, cur_speed + burst)
	ctx.player.set_velocity_now(Vector3(dir.x * target_speed, maxf(vel.y, 2.0), dir.z * target_speed), "sonic_snap_sling")
	ctx.player.refresh_air()
	combat.effects.ring(ball, 4.0, Palette.COPPER)
	combat.effects.spark(ball, Palette.AMBER)
	_note_grapple_mut("sonic_snap_sling", {
		"before_speed": cur_speed,
		"after_speed": target_speed,
		"delta_speed": target_speed - cur_speed,
		"air_refreshed": true,
	})


func step_grapple_mutations(delta: float, enemies: Array, heated: Dictionary) -> void:
	sync_grapple_mutations()
	_step_det_cord(enemies)
	if _live_bus_charges > 0 and combat.clock_now() >= _live_bus_charged_until:
		_live_bus_charges = 0
		_live_bus_charged_until = -1.0
		combat.clear_buff("grapple_mut_live_bus")
	if not _tether_slam_armed.is_empty() and combat.clock_now() >= float(_tether_slam_armed.get("until", -1.0)):
		_tether_slam_armed.clear()
	var kit = ctx.player.kit
	if kit == null or not kit.hooked:
		if ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
			ctx.destructibles.set_swing_heft_bonus(0)
		if not _tether_live.is_empty():
			on_grapple_released_muts()
		return
	var ball: Vector3 = ctx.player.ball_position()
	var anchor: Vector3 = kit.anchor
	var vel: Vector3 = ctx.player.state.velocity
	var body: Node3D = kit.anchor_body if is_instance_valid(kit.anchor_body) else null
	if _tether_live.is_empty():
		_tether_live = {
			"from": ball,
			"to": anchor,
			"body": body,
			"hook_time": 0.0,
			"min_y": ball.y,
			"prev_vy": vel.y,
			"crossed_bottom": false,
			"prev_smash": false,
			"prev_winch": false,
			"live_bus_checked": false,
		}
	var prev_vy := float(_tether_live.get("prev_vy", vel.y))
	_tether_live["from"] = ball
	_tether_live["to"] = anchor
	_tether_live["body"] = body
	_tether_live["hook_time"] = float(_tether_live.get("hook_time", 0.0)) + delta
	_tether_live["min_y"] = minf(float(_tether_live.get("min_y", ball.y)), ball.y)
	if prev_vy < -0.5 and vel.y >= -6.5:
		_tether_live["crossed_bottom"] = true
	_tether_live["prev_vy"] = vel.y
	_try_charge_live_bus(body, anchor, ball)

	var taut := _tether_is_taut(kit, ball, anchor)
	if has_grapple_mutation("hot_wire") and taut:
		_step_hot_wire(ball, anchor, enemies, heated)
	if has_grapple_mutation("dragnet_siphon"):
		_step_dragnet_siphon(delta, ball, anchor)
	if has_grapple_mutation("tether_slam"):
		_step_tether_slam(ball, anchor, kit, enemies)
	if has_grapple_mutation("wrecking_flail"):
		_step_wrecking_flail(delta, ball, anchor, kit, taut, enemies)
	elif ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
		ctx.destructibles.set_swing_heft_bonus(0)


func _step_hot_wire(ball: Vector3, anchor: Vector3, enemies: Array, heated: Dictionary) -> void:
	var row := _grapple_mut_row("hot_wire")
	var width := float(row.get("line_width_m", 1.6))
	var float_reach := float(row.get("float_reach_m", 2.2))
	var cd := float(row.get("hit_cooldown_s", 0.35))
	var dmg: float = maxf(float(row.get("damage_base", 24.0)), combat.weapon_hit() * 1.15) * combat.heft()
	var sliced_enemies := 0
	var popped_floats := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var kind: String = combat.spawn_kind_of(enemy)
		if kind == "boom_tender":
			var popped_arr = enemy.get("popped")
			if popped_arr is Array and enemy.has_method("float_position") and enemy.has_method("pop_float_at"):
				for fi in popped_arr.size():
					if bool(popped_arr[fi]):
						continue
					var fpos: Vector3 = enemy.float_position(fi)
					var c_pt := Geometry3D.get_closest_point_to_segment(fpos, ball, anchor)
					if c_pt.distance_to(fpos) <= float_reach and enemy.pop_float_at(fi, true):
						combat.effects.spark(fpos + Vector3.UP * 0.5, Palette.AMBER)
						popped_floats += 1
		if combat.fights_posture(enemy) or combat.target_class_of(enemy) in ["Warden", "boss"]:
			continue
		var eid: int = enemy.get_instance_id()
		if combat.clock_now() < float(_hot_wire_cd.get(eid, -INF)):
			continue
		var closest := Geometry3D.get_closest_point_to_segment(enemy.global_position, ball, anchor)
		if closest.distance_to(enemy.global_position) > width + combat.hull_radius(enemy):
			continue
		_hot_wire_cd[eid] = combat.clock_now() + cd
		combat.effects.arc(closest, enemy.global_position + Vector3.UP * 0.5, Palette.AMBER)
		combat.effects.spark(closest, Palette.AMBER)
		combat.deal_hit(enemy, combat.SYNERGY, dmg, enemy.global_position - closest, 6.0, "", "item_proc", "proc")
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			heated[eid] = {"glow": combat.clock_now() + combat.HEAT_GLOW, "ready": float(heated.get(eid, {}).get("ready", -INF))}
		sliced_enemies += 1
	var cut_props: Array[String] = []
	if ctx.destructibles != null and ctx.destructibles.has_method("on_segment_cut"):
		cut_props = ctx.destructibles.on_segment_cut(ball, anchor, int(row.get("max_destructible_tier", 2)), width, "hot_wire")
		for pid in cut_props:
			var b: AABB = ctx.destructibles.bounds_of(pid)
			combat.effects.spark(b.get_center(), Palette.AMBER)
	if sliced_enemies > 0 or popped_floats > 0 or not cut_props.is_empty():
		_note_grapple_mut("hot_wire", {
			"enemies": sliced_enemies,
			"floats": popped_floats,
			"props": cut_props,
			"color": Palette.AMBER,
		})


func _step_dragnet_siphon(delta: float, ball: Vector3, anchor: Vector3) -> void:
	var row := _grapple_mut_row("dragnet_siphon")
	var radius := float(row.get("vacuum_radius_m", 5.0))
	var pull_speed := float(row.get("pull_speed", 26.0))
	var pulled_scrap := 0
	var pulled_consumables := 0
	var scrap = ctx.build.get("scrap") if ctx.build != null else null
	if scrap != null and scrap.has_method("pull_along_segment"):
		pulled_scrap = scrap.pull_along_segment(ball, anchor, radius, pull_speed * delta)
	if ctx.run != null and ctx.run.has_method("can_hold_consumable") and ctx.run.can_hold_consumable():
		for cradle in combat.consumables.live_consumable_drops():
			if not is_instance_valid(cradle) or cradle.collected:
				continue
			var closest := Geometry3D.get_closest_point_to_segment(cradle.global_position, ball, anchor)
			if closest.distance_to(cradle.global_position) <= radius:
				cradle.global_position = cradle.global_position.move_toward(ball, pull_speed * delta)
				pulled_consumables += 1
	if pulled_scrap > 0 or pulled_consumables > 0:
		_note_grapple_mut("dragnet_siphon", {"scrap_pulled": pulled_scrap, "consumables_pulled": pulled_consumables})


func _step_tether_slam(ball: Vector3, anchor: Vector3, kit, enemies: Array) -> void:
	var is_smash: bool = kit.line_state == Augments.LINE_SMASH
	var is_winch: bool = bool(kit.winching)
	var prev_smash := bool(_tether_live.get("prev_smash", false))
	var prev_winch := bool(_tether_live.get("prev_winch", false))
	_tether_live["prev_smash"] = is_smash
	_tether_live["prev_winch"] = is_winch
	if (is_smash and not prev_smash) or (is_winch and not prev_winch):
		trigger_tether_slam()
	elif not _tether_slam_armed.is_empty():
		var mid: Vector3 = _tether_slam_armed.get("mid", anchor)
		var target = _tether_slam_armed.get("target")
		var meet_at: Vector3 = target.global_position if is_instance_valid(target) else mid
		if ball.distance_to(meet_at) <= 3.2:
			_detonate_tether_slam_midpoint(meet_at, enemies)


func trigger_tether_slam() -> Dictionary:
	if ctx == null or ctx.player == null or ctx.player.kit == null or not ctx.player.kit.hooked:
		return {}
	if not has_grapple_mutation("tether_slam"):
		return {}
	var kit = ctx.player.kit
	var row := _grapple_mut_row("tether_slam")
	var ball: Vector3 = ctx.player.ball_position()
	var target: Node3D = kit.anchor_body if is_instance_valid(kit.anchor_body) else null
	var target_pos: Vector3 = target.global_position if target != null else kit.anchor
	var mid := (ball + target_pos) * 0.5
	var yank_speed := float(row.get("yank_speed", 24.0))
	var to_mid := mid - ball
	if to_mid.length_squared() > 0.01:
		var spd := maxf(ctx.player.state.velocity.length(), yank_speed)
		var dv: Vector3 = to_mid.normalized() * spd - ctx.player.state.velocity
		ctx.player.add_external_accel(dv * 60.0)
	var yanked_target := false
	if target != null and target.is_in_group(Groups.ENEMY) and not combat.fights_posture(target) and combat.target_class_of(target) != "boss":
		var pull_dir := mid - target.global_position
		if pull_dir.length_squared() > 0.01:
			var weight = target.get("weight")
			if target.has_method("knock"):
				target.knock(pull_dir.normalized() + Vector3.UP * 0.2, yank_speed * (float(weight) if weight != null else 1.0))
			target.global_position = target.global_position.lerp(mid, 0.5)
			yanked_target = true
			gravity_ledger.call(mid, [target])
	var armed_window := float(row.get("armed_window_s", 1.2))
	_tether_slam_armed = {
		"target": target,
		"mid": mid,
		"until": combat.clock_now() + armed_window,
		"mult": float(row.get("crush_mult", 2.0)),
	}
	combat.effects.ring(mid, 3.0, Palette.COPPER)
	var result := {"mid": mid, "yanked_target": yanked_target, "mult": float(_tether_slam_armed["mult"])}
	_note_grapple_mut("tether_slam", {"stage": "yank", "mid": mid, "yanked_target": yanked_target})
	return result


func _detonate_tether_slam_midpoint(at: Vector3, enemies: Array) -> void:
	var row := _grapple_mut_row("tether_slam")
	var mult := float(_tether_slam_armed.get("mult", row.get("crush_mult", 2.0)))
	var radius := float(row.get("slam_radius_m", 8.0))
	var base_dmg := maxf(float(row.get("damage_base", 32.0)), combat.punch_of("slam", Augments.SLAM_KNOCK))
	var dmg := base_dmg * mult
	var knock := float(row.get("knock", 16.0))
	_tether_slam_armed.clear()
	combat.effects.shockwave(at, radius, Palette.COPPER)
	var hits := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.global_position.distance_to(at) > radius + combat.hull_radius(enemy):
			continue
		combat.deal_hit(enemy, combat.SYNERGY, dmg, enemy.global_position - at, knock, "", "item_proc", "proc")
		hits += 1
	if ctx.destructibles != null and ctx.destructibles.has_method("on_blast"):
		var hc: int = ctx.run.heft_class() if ctx.run != null and ctx.run.has_method("heft_class") else 1
		ctx.destructibles.on_blast(at, radius, "tether_slam", 1, hc)
	_note_grapple_mut("tether_slam", {"stage": "crush", "at": at, "mult": mult, "hits": hits})


func tether_slam_matches(enemy: Node3D, kind: String) -> bool:
	if _tether_slam_armed.is_empty() or combat.clock_now() >= float(_tether_slam_armed.get("until", -1.0)):
		return false
	if not (kind in combat.CONTACT_KINDS):
		return false
	var target = _tether_slam_armed.get("target")
	return target == null or target == enemy


func _step_wrecking_flail(delta: float, ball: Vector3, _anchor: Vector3, _kit, taut: bool, enemies: Array) -> void:
	var row := _grapple_mut_row("wrecking_flail")
	var bonus := clampi(int(row.get("heft_bonus", 1)), 0, 1) if taut else 0
	if ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
		ctx.destructibles.set_swing_heft_bonus(bonus)
	if not taut:
		return
	var vel: Vector3 = ctx.player.state.velocity
	var reach := float(row.get("swing_reach_m", 3.2))
	var hc: int = ctx.run.heft_class() if ctx.run != null and ctx.run.has_method("heft_class") else 1
	var broken: Array[String] = []
	if ctx.destructibles != null and ctx.destructibles.has_method("on_taut_swing"):
		broken = ctx.destructibles.on_taut_swing(ball, vel, hc, bonus, reach, delta)
		for pid in broken:
			var b: AABB = ctx.destructibles.bounds_of(pid)
			combat.effects.ring(b.get_center(), 3.2, Palette.STEEL)
			combat.effects.spark(b.get_center(), Palette.AMBER)
	var shredded := 0
	var flat_speed := Vector2(vel.x, vel.z).length()
	if flat_speed >= float(row.get("min_speed", 8.0)):
		var shred_amt := float(row.get("armor_shred_bonus", 25.0))
		for enemy in enemies:
			if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			if enemy.global_position.distance_to(ball) > reach + combat.hull_radius(enemy):
				continue
			var had_armor := false
			if "plates" in enemy and int(enemy.plates) > 0:
				enemy.plates = maxi(0, int(enemy.plates) - 1)
				had_armor = true
			if enemy.has_method("plating_for") and float(enemy.plating_for("ram", "")) > 0.0:
				combat.add_shred(enemy, shred_amt)
				had_armor = true
			if had_armor:
				combat.effects.spark(enemy.global_position + Vector3.UP * 0.5, Palette.AMBER)
				shredded += 1
	if not broken.is_empty() or shredded > 0:
		_note_grapple_mut("wrecking_flail", {"broken": broken, "shredded": shredded, "effective_heft": mini(Destructibles.TIER_MAX, hc + bonus)})


func consume_grapple_mut_strike(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var kind: String = hit["kind"]
	var cls: String = hit["cls"]
	var dealt := float(hit["result"].get("dealt", 0.0))
	if live_bus_charged() and cls != "debris" and kind != "live_bus" and dealt > 0.0:
		var row := _grapple_mut_row("live_bus")
		var bonus_flat := float(row.get("bonus_flat", 24.0))
		var arc_r := float(row.get("arc_radius_m", 8.0))
		_live_bus_charges = 0
		_live_bus_charged_until = -1.0
		combat.clear_buff("grapple_mut_live_bus")
		var at: Vector3 = hit["at"]
		combat.effects.arc(ctx.player.ball_position() + Vector3.UP * 0.5, at + Vector3.UP * 0.5, Palette.AMBER)
		combat.effects.ring(at, 4.5, Palette.AMBER)
		var arced_to: Node3D = null
		for other in get_tree().get_nodes_in_group(Groups.ENEMY):
			if other == enemy or not is_instance_valid(other) or (other.has_method("is_dead") and other.is_dead()):
				continue
			if combat.fights_posture(other):
				continue
			if other.global_position.distance_to(at) <= arc_r:
				arced_to = other
				break
		if arced_to != null:
			combat.effects.arc(at + Vector3.UP * 0.5, arced_to.global_position + Vector3.UP * 0.5, Palette.AMBER)
			combat.trail_deal(arced_to, bonus_flat, "live_bus", "item_proc")
		_note_grapple_mut("live_bus", {"stage": "discharge", "at": at, "dealt": dealt, "arced": arced_to != null, "color": Palette.AMBER})
	if tether_slam_matches(enemy, kind) and dealt > 0.0:
		var mult := float(_tether_slam_armed.get("mult", 2.0))
		_tether_slam_armed.clear()
		combat.effects.shockwave(hit["at"], 6.0, Palette.COPPER)
		_note_grapple_mut("tether_slam", {"stage": "contact_crush", "at": hit["at"], "mult": mult, "dealt": dealt})
	if wrecking_flail_taut_active() and kind in combat.CONTACT_KINDS and is_instance_valid(enemy):
		combat.add_shred(enemy, float(_grapple_mut_row("wrecking_flail").get("armor_shred_bonus", 25.0)))
		if "plates" in enemy and int(enemy.plates) > 0:
			enemy.plates = maxi(0, int(enemy.plates) - 1)
