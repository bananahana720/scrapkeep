extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const Groups := preload("res://src/core/groups.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const Palette := preload("res://src/core/palette.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const Weapons := preload("res://src/combat/weapons.gd")

var ctx
var combat
var bay := 0
var plate := {}
var link_group := {}
var last_card := {}
var _cards := {}
var _arcing := false
var _gather_tick := 0.0
var _roll_clock := 0.0
var _restored_frame := {}
const TALLY_PIECES := ["plate_return", "plate_audit", "plate_flywheel"]
const PUNCH_TAPE_CASTS := 10
const BOOKS_SETTLES := 6
const EYESHADE_SETTLES := 20
var clip_post := {}
var tally_piece := ""
var ride_clips := {}
var tally_last_settle := {}
var _fly_plates: Array = []
var _fly_pulled := false
var _run_settles := 0
var _stage_clip_casts := 0
var _tally_cards := {}
var _tally_card_frame := -1
const CLIP_IDS := ["link_clips", "link_double"]
const INK_SECONDS := 3.0
const INK_HEIGHT := 2.2
var _ink := {}
var _ink_mesh: ArrayMesh


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "TallyKit"


func reset() -> void:
	bay = 0
	plate = {}
	link_group = {}
	last_card = {}
	_arcing = false
	_gather_tick = 0.0
	_roll_clock = 0.0
	_restored_frame = {}
	_clear_clip_post()
	_clear_tally_piece()
	_clear_ink()
	tally_last_settle = {}
	_tally_cards = {}
	if combat.ally_husks != null:
		combat.ally_husks.reset()


func wire() -> void:
	_cards = {"balance_due": run_balance}
	ctx.events.enemy_struck.connect(_on_card_struck)
	ctx.events.harpoon_smashed.connect(func(_enemy: Node3D, _at: Vector3, _speed: float): grant_pressure(1))
	ctx.events.slammed.connect(func(at: Vector3, _strength: float, _flatness: float):
		var smash = ctx.player.abilities
		if smash.cap(AbilityState.SMASH, "flavour", "") != "stamp":
			grant_pressure(1)
		else:
			if smash.cap(AbilityState.SMASH, "mutation", "") == "stamp_ink":
				_book_ink(at)
			if combat.ally_husks != null and combat.ghost_shift_unlocked():
				combat.ally_husks.refresh_all_shifts())
	var ev = ctx.events
	ev.dashed.connect(func(_dir: Vector3):
		if ctx.player.abilities.id_of(AbilityState.MOVEMENT) == "flywheel_surge":
			grant_pressure(Weapons.SURGE_PRESSURE)
			if combat.ally_husks != null and combat.ghost_shift_unlocked():
				combat.ally_husks.start_surge_overclock())
	ev.line_skill_fired.connect(func(id: String, _target: Node3D, at: Vector3, _on: String):
		if not id in CLIP_IDS:
			return
		_stage_clip_casts += 1
		if _stage_clip_casts >= PUNCH_TAPE_CASTS:
			_tally_discover("tally_punch_tape", "loaded_line", at))
	ev.stage_entered.connect(func(_stage: int, _retry: bool):
		_stage_clip_casts = 0
		_clear_clip_post())
	ev.stage_content_cleared.connect(func(_reason: String): _clear_ink())
	ev.player_died.connect(_clear_ink)
	ev.run_started.connect(func(_class_id: String):
		_run_settles = 0
		_stage_clip_casts = 0)
	ev.ultimate_started.connect(func(id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		_clear_tally_piece()
		if id in TALLY_PIECES:
			tally_piece = id)
	ev.ultimate_cancelled.connect(func(_id: String, _reason: String, _refunded: bool): _clear_tally_piece())
	ev.synergy_discovered.connect(func(_id: String, _category: String, _first: bool):
		_tally_card_frame = Engine.get_physics_frames())


func step(delta: float, shots: Array) -> void:
	var abilities = ctx.player.abilities
	var cards: Array = abilities.cap(AbilityState.WEAPON, "cards", [])
	bay = clampi(bay, 0, cards.size() - 1)
	abilities.slot(AbilityState.WEAPON).icon = String(Weapons.CARDS.get(cards[bay], {}).get("icon", ""))
	_step_plate(delta)
	if not link_group.is_empty() and float(link_group["until"]) <= combat.clock_now():
		link_group = {}
	_step_roll_restore(delta)
	_step_clip_post()
	_step_clip_preview()
	_step_tally_piece(delta)
	_step_tally_cards()
	_step_ink()
	if shots.is_empty():
		return
	var card: String = cards[bay]
	if not _cards.has(card):
		return
	var aim := card_aim()
	var shot: Dictionary = shots[0]
	var ok: bool = run_balance(aim["point"], aim["valid"], shot, "weapon") if card == "balance_due" \
		else bool(_cards[card].call(aim["point"], aim["valid"]))
	if not ok:
		return
	var p: Resource = combat.live_pattern(Weapons.LEDGER_READER)
	if p != null and String(p.trigger) == Pattern.TRIGGER_STAMP:
		var paid: bool = bool(shot.get("paid", false))
		combat.weapon_driver.commit_stamp(paid, 1.0)
		if paid:
			var safe_cost: float = maxf(float(shot.get("cast_cost", p.cast_cost)), Pattern.MIN_CAST_COST)
			var safe_refund: float = clampf(float(shot.get("refund", 0.0)), 0.0, safe_cost)
			if safe_refund > 0.0:
				_grant_pressure_amount(safe_refund)
				last_card["refund"] = safe_refund
	else:
		combat.weapon_driver.commit_recovery(Weapons.CARD_RECOVERY)
	ctx.events.shot_fired.emit(card, ctx.player.ball_position(), aim["point"])


func card_aim() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, Weapons.CARD_REACH + combat.AIM_SLACK)
	var point: Vector3 = aim["point"]
	return {"point": point, "valid": not aim["blocked"] and ball.distance_to(point) <= Weapons.CARD_REACH}


func tap_gather(aim := {}) -> bool:
	if aim.is_empty():
		aim = card_aim()
	if not _run_gather(aim["point"], aim["valid"]):
		return false
	ctx.events.shot_fired.emit("gather_plate", ctx.player.ball_position(), aim["point"])
	return true


func _step_plate(delta: float) -> void:
	if plate.is_empty():
		return
	if float(plate["until"]) <= combat.clock_now():
		plate = {}
		return
	_gather_tick += delta
	while _gather_tick >= Weapons.GATHER_TICK:
		_gather_tick -= Weapons.GATHER_TICK
		combat.gather_pull(plate["at"], float(plate.get("radius", Weapons.GATHER_RADIUS)))


func _step_roll_restore(delta: float) -> void:
	var abilities = ctx.player.abilities
	var s = abilities.slot(AbilityState.WEAPON)
	var p: Resource = combat.live_pattern(Weapons.LEDGER_READER)
	var fractional: bool = p != null and String(p.trigger) == Pattern.TRIGGER_STAMP
	if fractional:
		if abilities.pressure_of(AbilityState.WEAPON) + AbilityState.PRESSURE_EPS >= float(s.max_charges):
			_roll_clock = 0.0
			return
		var planar: float = ctx.player.planar_velocity().length()
		if not ctx.player.state.on_floor() or SpeedTier.of(planar, ctx.player.tuning.f("cruise")) < SpeedTier.CRUISE:
			return
		_grant_pressure_amount(delta / Weapons.PRESSURE_ROLL_S)
		return
	if s.charges >= s.max_charges:
		_roll_clock = 0.0
		return
	var planar: float = ctx.player.planar_velocity().length()
	if not ctx.player.state.on_floor() or SpeedTier.of(planar, ctx.player.tuning.f("cruise")) < SpeedTier.CRUISE:
		return
	_roll_clock += delta
	while _roll_clock >= Weapons.PRESSURE_ROLL_S:
		_roll_clock -= Weapons.PRESSURE_ROLL_S
		grant_pressure(1)


func grant_pressure(count: int) -> void:
	var abilities = ctx.player.abilities
	if count > 0 and abilities.cap(AbilityState.WEAPON, "pressure", null) != null:
		abilities.grant(AbilityState.WEAPON, count)


func _grant_pressure_amount(amount: float) -> void:
	var abilities = ctx.player.abilities
	if amount > 0.0 and abilities.cap(AbilityState.WEAPON, "pressure", null) != null:
		abilities.grant_amount(AbilityState.WEAPON, amount)


func _spend_card(card: String, at: Vector3, cost := 1.0) -> bool:
	if not ctx.player.abilities.spend(AbilityState.WEAPON, cost):
		return false
	last_card = {"card": card, "at": at, "hits": 0, "spent": true, "cost": cost, "paid": false, "refund": 0.0}
	return true


func _run_gather(point: Vector3, valid: bool) -> bool:
	if not valid:
		return false
	last_card = {"card": "gather_plate", "at": point, "hits": 0, "spent": false}
	var at: Vector3 = combat.floor_at(point + Vector3.UP)
	plate = {"at": at, "until": combat.clock_now() + Weapons.GATHER_SECONDS}
	_gather_tick = 0.0
	combat.effects.ring(at, Weapons.GATHER_RADIUS, Palette.COPPER)
	if combat.ally_husks != null and combat.ghost_shift_unlocked():
		combat.ally_husks.raise_in_radius(at, Weapons.GATHER_RADIUS)
	return true


func run_balance(point: Vector3, valid: bool, shot_desc := {}, source := "weapon") -> bool:
	if not valid:
		return false
	var p: Resource = combat.live_pattern(Weapons.LEDGER_READER)
	var is_stamp_mode: bool = p != null and String(p.trigger) == Pattern.TRIGGER_STAMP
	var is_proc: bool = source != "weapon"
	var cost: float = maxf(float(shot_desc.get("cast_cost", p.cast_cost if p != null else 1.0)), Pattern.MIN_CAST_COST)
	if not is_proc:
		if not _spend_card("balance_due", point, cost):
			combat.refuse_cast(AbilityState.WEAPON, "cooling")
			return false
	var speed: float = ctx.player.planar_velocity().length()
	var paid: bool = is_stamp_mode and not is_proc and bool(shot_desc.get("paid", false))
	var damage: float
	if is_stamp_mode:
		var weight := clampf((Weapons.STAMP_BASE + Weapons.STAMP_PER_SPEED * speed) / Weapons.STAMP_MAX, 0.0, 1.0)
		var raw: float = float(p.damage) * weight
		if paid:
			raw *= float(shot_desc.get("damage_mult", 1.0))
			var bonus: float = float(shot_desc.get("streak_bonus", 0.0))
			if bonus > 0.0:
				raw += bonus * weight
				var cap: float = float(shot_desc.get("streak_cap", 0.0))
				if cap > 0.0:
					raw = minf(raw, cap * weight)
		damage = raw * combat.damage_mod(Weapons.LEDGER_READER)
	else:
		damage = minf(Weapons.BALANCE_MAX, Weapons.BALANCE_BASE + Weapons.BALANCE_PER_SPEED * speed) * combat.damage_mod(Weapons.LEDGER_READER)
	var hits := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead() or not combat.in_ring(point, Weapons.BALANCE_RADIUS, enemy):
			continue
		ledger_hit(enemy, damage, point, Weapons.LEDGER_KNOCK, source)
		hits += 1
		if paid:
			combat.effects.ring(enemy.global_position, 1.35, Palette.AMBER)
			combat.effects.spark(enemy.global_position + Vector3.UP * 1.1, Palette.AMBER)
		if not is_proc:
			_settle_ink(enemy)
	var cue_color: Color = Palette.LEDGER_CREAM if paid else Palette.COPPER
	combat.effects.ring(point, Weapons.BALANCE_RADIUS, cue_color)
	if paid:
		combat.effects.ring(point, Weapons.BALANCE_RADIUS * 0.72, Palette.AMBER)
		combat.effects.shockwave(point, Weapons.BALANCE_RADIUS, Palette.LEDGER_CREAM)
	if not is_proc:
		last_card["hits"] = hits
		last_card["damage"] = damage
		last_card["paid"] = paid
		last_card["stamp_color"] = cue_color
		if combat.relic_swaps != null: combat.relic_swaps.on_ledger_cast(point, damage, shot_desc)
	return true


func clip_geometry(_f: float) -> Dictionary:
	var kit = ctx.player.kit
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		return _clip_ring(kit.anchor_body.global_position, Weapons.LINK_NEIGHBOUR_REACH)
	var at: Vector3 = kit.anchor if kit.hooked else ctx.player.ball_position() + combat.aim_heading() * ctx.player.grapple_range()
	return _clip_ring(at, Weapons.CLIP_POST_RADIUS)


func _clip_ring(centre: Vector3, radius: float) -> Dictionary:
	return ctx.player.yours({"kind": "ring", "centre": centre, "radius": radius, "full_radius": radius, "fill": 1.0, "ticks": "square"})


func _step_clip_preview() -> void:
	var abilities = ctx.player.abilities
	if abilities.selected == AbilityState.LINE and abilities.id_of(AbilityState.LINE) in CLIP_IDS and ctx.player.kit.hooked:
		ctx.player.indicator.set_shape("tally_clip", clip_geometry(1.0))
	else:
		ctx.player.indicator.clear("tally_clip")


func link_clips_body(target: Node3D, _fraction: float, mult: float) -> void:
	_clear_clip_post()
	_link_from(target, mult, _clip_ring(target.global_position, Weapons.LINK_NEIGHBOUR_REACH))
	if combat.ally_husks != null and combat.ghost_shift_unlocked() and is_instance_valid(target):
		combat.ally_husks.raise_drive_by(target.global_position)


func link_clips_world(anchor: Vector3, fraction: float, mult: float) -> void:
	combat.reel_burst(anchor, fraction, mult)
	link_group = _new_link_group(Weapons.CLIP_POST_SECONDS, mult)
	clip_post = {"at": anchor, "until": combat.clock_now() + Weapons.CLIP_POST_SECONDS, "shape": _clip_ring(anchor, Weapons.CLIP_POST_RADIUS)}
	ctx.player.indicator.set_shape("tally_post", clip_post["shape"])
	combat.effects.ring(anchor, Weapons.CLIP_POST_RADIUS, Palette.COPPER)
	last_card = {"card": "link_clips", "at": anchor, "hits": 0, "spent": false}
	if combat.ally_husks != null and combat.ghost_shift_unlocked():
		combat.ally_husks.raise_drive_by(anchor)


func _link_from(first: Node3D, mult := 1.0, shape := {}) -> int:
	var centre: Vector3 = shape.get("centre", first.global_position)
	var radius: float = shape.get("radius", Weapons.LINK_NEIGHBOUR_REACH)
	var clips := [first]
	for enemy in combat.nearest_enemies(centre, radius * 2.0, 16):
		if clips.size() > Weapons.LINK_NEIGHBOURS:
			break
		if enemy != first and combat.in_ring(centre, radius, enemy):
			clips.append(enemy)
	link_group = _new_link_group(Weapons.LINK_SECONDS, mult)
	for clip in clips:
		_add_clip(clip)
	last_card = {"card": "link_clips", "at": first.global_position, "hits": clips.size(), "spent": false}
	if clips.size() > Weapons.LINK_NEIGHBOURS:
		_tally_discover("tally_skim", "loaded_line", first.global_position)
	return clips.size()


func _new_link_group(seconds: float, mult: float) -> Dictionary:
	return {"ids": [], "until": combat.clock_now() + seconds, "spent": false, "mult": mult, "jumped": false,
		"double": ctx.player.abilities.cap(AbilityState.LINE, "mutation", "") == "link_double"}


func _add_clip(enemy: Node3D) -> void:
	(link_group["ids"] as Array).append(enemy.get_instance_id())
	link_group["until"] = maxf(float(link_group["until"]), combat.clock_now() + Weapons.LINK_SECONDS)
	combat.effects.arc(ctx.player.ball_position(), enemy.global_position, Palette.AMBER)
	grant_pressure(Weapons.CLIP_PRESSURE)


func _step_clip_post() -> void:
	if clip_post.is_empty():
		return
	if float(clip_post["until"]) <= combat.clock_now() or link_group.is_empty():
		_clear_clip_post()
		return
	var ids: Array = link_group["ids"]
	var at: Vector3 = clip_post["at"]
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if ids.size() >= Weapons.CLIP_POST_MAX:
			break
		if not is_instance_valid(enemy) or enemy.is_dead() or ids.has(enemy.get_instance_id()):
			continue
		if combat.in_ring(at, Weapons.CLIP_POST_RADIUS, enemy):
			_add_clip(enemy)
			last_card["hits"] = ids.size()
	if ids.size() >= Weapons.CLIP_POST_MAX:
		_tally_discover("tally_skim", "loaded_line", at)
		_clear_clip_post()


func _clear_clip_post() -> void:
	clip_post = {}
	if ctx != null and ctx.player != null:
		ctx.player.indicator.clear("tally_post")


func _on_card_struck(enemy: Node3D, kind: String, force: float) -> void:
	if kind == "ram" or kind == "stomp":
		var frame := Engine.get_physics_frames()
		if int(_restored_frame.get(kind, -1)) != frame:
			_restored_frame[kind] = frame
			grant_pressure(1)
	if _arcing or link_group.is_empty() or link_group["spent"] or float(link_group["until"]) <= combat.clock_now():
		return
	var ids: Array = link_group["ids"]
	if not is_instance_valid(enemy) or not ids.has(enemy.get_instance_id()):
		return
	link_group["spent"] = true
	var from: Vector3 = enemy.global_position
	var damage := maxf(Weapons.LINK_ARC_MIN, force * Weapons.LINK_ARC_SHARE) * float(link_group.get("mult", 1.0))
	_arcing = true
	for id in ids:
		if id == enemy.get_instance_id():
			continue
		var other = instance_from_id(id)
		if other == null or not is_instance_valid(other) or other.is_dead():
			continue
		var to: Vector3 = other.global_position
		combat.effects.arc(from, to, Palette.AMBER)
		ledger_hit(other, damage, from, Weapons.LEDGER_KNOCK, "weapon")
	if bool(link_group.get("double", false)) and not bool(link_group.get("jumped", false)):
		link_group["jumped"] = true
		_clip_jump(from, damage)
	_arcing = false


func _clip_jump(from: Vector3, damage: float) -> void:
	var ids: Array = link_group["ids"]
	var best: Node3D = null
	var best_gap := INF
	for other in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(other) or DamageDoor.dead(other) or ids.has(other.get_instance_id()):
			continue
		var gap: float = other.global_position.distance_to(from)
		if gap <= Weapons.LINK_NEIGHBOUR_REACH and gap < best_gap:
			best = other
			best_gap = gap
	if best == null:
		return
	link_group["jump_to"] = best.get_instance_id()
	combat.effects.arc(from, best.global_position, Palette.AMBER)
	ledger_hit(best, damage, from, Weapons.LEDGER_KNOCK, "item_proc")


func _book_ink(at: Vector3) -> void:
	var reach: float = ctx.player.slam_radius()
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or DamageDoor.dead(enemy) or (enemy.global_position - at).length() > reach:
			continue
		var id: int = enemy.get_instance_id()
		var row: Dictionary = _ink.get(id, {})
		if row.is_empty() or not is_instance_valid(row["mark"]):
			row = {"mark": _ink_mark(enemy)}
		row["until"] = combat.clock_now() + INK_SECONDS
		_ink[id] = row


func _settle_ink(enemy: Node3D) -> void:
	var id := enemy.get_instance_id()
	if not _ink.has(id):
		return
	var live: bool = float(_ink[id]["until"]) > combat.clock_now()
	_drop_ink(id)
	if live:
		grant_pressure(1)
		last_card["ink"] = int(last_card.get("ink", 0)) + 1


func _step_ink() -> void:
	for id in _ink.keys():
		var row: Dictionary = _ink[id]
		var enemy = instance_from_id(id)
		var left: float = float(row["until"]) - combat.clock_now()
		if enemy == null or not is_instance_valid(enemy) or DamageDoor.dead(enemy) or left <= 0.0:
			_drop_ink(id)
		elif is_instance_valid(row["mark"]):
			row["mark"].visible = left > 0.75 or int(left * 8.0) % 2 == 0


func _drop_ink(id: int) -> void:
	var mark = _ink.get(id, {}).get("mark")
	if is_instance_valid(mark):
		if mark.get_parent() != null:
			mark.get_parent().remove_child(mark)
		mark.queue_free()
	_ink.erase(id)


func _clear_ink() -> void:
	for id in _ink.keys():
		_drop_ink(id)


func _ink_mark(enemy: Node3D) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.name = "InkTick"
	mark.mesh = _ink_tick()
	enemy.add_child(mark)
	var parent_scale: Vector3 = enemy.global_basis.get_scale()
	mark.scale = Vector3(1.0 / maxf(parent_scale.x, 0.0001), 1.0 / maxf(parent_scale.y, 0.0001), 1.0 / maxf(parent_scale.z, 0.0001))
	mark.position = Vector3(0.0, INK_HEIGHT / maxf(parent_scale.y, 0.0001), 0.0)
	return mark


func _ink_tick() -> ArrayMesh:
	if _ink_mesh != null:
		return _ink_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bar in [[Vector2(-0.30, 0.02), Vector2(-0.10, -0.24)], [Vector2(-0.10, -0.24), Vector2(0.34, 0.34)]]:
		var a: Vector2 = bar[0]
		var b: Vector2 = bar[1]
		var side := (b - a).orthogonal().normalized() * 0.06
		for p in [a - side, a + side, b - side, a + side, b + side, b - side]:
			surface.add_vertex(Vector3(p.x, p.y, 0.0))
	_ink_mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_color = Palette.AMBER
	_ink_mesh.surface_set_material(0, material)
	return _ink_mesh


func ledger_hit(enemy: Node3D, damage: float, from: Vector3, knock: float, source: String) -> float:
	if combat.target_class_of(enemy) == "boss":
		damage *= Ultimate.BOSS_MULT
		knock = 0.0
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		combat.strike(enemy, "ledger", damage, "", source)
		return damage
	combat.deal_hit(enemy, "ledger", damage, enemy.global_position - from, knock, "", source)
	return damage


func _clear_tally_piece() -> void:
	tally_piece = ""
	ride_clips = {}
	_fly_plates = []
	_fly_pulled = false


func _tally_enemies() -> Array:
	return get_tree().get_nodes_in_group(Groups.ENEMY).filter(func(e): return not DamageDoor.dead(e))


static func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func tally_target(id: String, ball: Vector3, aim: Dictionary) -> Dictionary:
	if plate.is_empty():
		return {}
	var at: Vector3 = plate["at"]
	var reach: float = Ultimate.ARC_REACH[combat.ultimate.heft_index()] if id == "plate_flywheel" else ctx.player.grapple_range()
	var forward: Vector3 = aim.get("forward", Vector3.ZERO)
	var flat_aim := Vector3(forward.x, 0.0, forward.z)
	var to := Vector3(at.x - ball.x, 0.0, at.z - ball.z)
	if ball.distance_to(at) > reach or flat_aim.length() < 0.01 or to.length() < 0.01:
		return {}
	if rad_to_deg(flat_aim.angle_to(to)) > Weapons.ULT_PLATE_AIM_DEG:
		return {}
	return {"path": "arc" if id == "plate_flywheel" else "line", "to": at, "target": null}


func tally_tech(id: String, _beat: int, ball: Vector3, aim: Vector3, heft: float) -> int:
	var cap: int = Weapons.CLIP_CAP[combat.ultimate.heft_index()]
	var made := 0
	if id == "plate_audit":
		var ground = _audit_ground(ball)
		if ground == null:
			return 0
		var radius: float = Weapons.AUDIT_STAMP_RADIUS + float(combat.ultimate.knob("ult_volley", 0))
		combat.effects.ring(ground, radius, Palette.COPPER)
		for enemy in _tally_enemies():
			if combat.in_ring(ground, radius, enemy):
				_piece_hit(enemy, Ultimate.VOLLEY_DAMAGE * heft, ground, Weapons.AUDIT_STAMP_KNOCK)
				made += _ride_clip(enemy, cap)
	elif id == "plate_flywheel":
		var knot = _densest_knot(ball)
		if knot == null:
			return 0
		_fly_plates.append({"at": knot, "until": combat.clock_now() + Weapons.FLY_PLATE_SECONDS, "tick": 0.0})
		combat.effects.ring(knot, Weapons.GATHER_RADIUS, Palette.COPPER)
		var near: Array = []
		for enemy in _tally_enemies():
			var gap := _flat_gap(enemy.global_position, knot)
			if gap <= Weapons.GATHER_RADIUS:
				near.append([gap, enemy])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for entry in near.slice(0, Weapons.FLY_KNOT_CLIPS + int(combat.ultimate.knob("ult_volley", 0))):
			made += _ride_clip(entry[1], cap)
	else:
		for enemy in _volley_picks(ball, aim, combat.ultimate.volley_targets()):
			combat.effects.arc(ball + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, Palette.AMBER)
			_piece_hit(enemy, Ultimate.VOLLEY_DAMAGE * heft, ball, Weapons.LEDGER_KNOCK)
			made += _ride_clip(enemy, cap)
	if combat.ally_husks != null and combat.ghost_shift_unlocked():
		combat.ally_husks.raise_in_radius(ball, Ultimate.VOLLEY_RADIUS)
	return made


func _volley_picks(ball: Vector3, aim: Vector3, count: int) -> Array:
	var picks: Array = []
	var bias := deg_to_rad(Ultimate.VOLLEY_BIAS_DEG)
	for enemy in _tally_enemies():
		var to: Vector3 = enemy.global_position - ball
		if to.length() > Ultimate.VOLLEY_RADIUS:
			continue
		var biased: bool = aim.length() > 0.01 and to.length() > 0.01 and aim.angle_to(to) <= bias
		var owed: bool = ride_clips.has(enemy.get_instance_id())
		picks.append([(1000.0 if owed else 0.0) + (0.0 if biased else 100.0) + to.length(), enemy])
	picks.sort_custom(func(a, b): return a[0] < b[0])
	return picks.slice(0, count).map(func(entry): return entry[1])


func _ride_clip(enemy: Node3D, cap: int) -> int:
	var id := enemy.get_instance_id()
	if ride_clips.has(id) or ride_clips.size() >= cap:
		return 0
	ride_clips[id] = true
	return 1


func _piece_hit(enemy: Node3D, damage: float, from: Vector3, knock: float) -> float:
	if (enemy.has_method("_apply_posture") and enemy.has_method("staggered")) or combat.target_class_of(enemy) == "boss":
		return combat.ult_hit(enemy, "ledger", damage, from, false)
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		combat.strike(enemy, "ledger", damage, "", "special")
		return damage
	combat.deal_hit(enemy, "ledger", damage, enemy.global_position - from, knock, "", "special")
	return damage


func _audit_ground(ball: Vector3):
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ball, ball + Vector3.DOWN * Weapons.AUDIT_GROUND_REACH, PhysicsLayers.WORLD_MASK))
	return hit["position"] if not hit.is_empty() else null


func _densest_knot(ball: Vector3):
	var enemies := _tally_enemies()
	var best = null
	var best_score := -1.0
	for enemy in enemies:
		var gap := _flat_gap(enemy.global_position, ball)
		if gap > Weapons.FLY_KNOT_SEARCH:
			continue
		var count := 0
		for other in enemies:
			if _flat_gap(other.global_position, enemy.global_position) <= Weapons.GATHER_RADIUS:
				count += 1
		var score := count * 100.0 - gap
		if score > best_score:
			best_score = score
			best = enemy.global_position
	return combat.floor_at(best + Vector3.UP) if best != null else null


func tally_peak(id: String, at: Vector3) -> void:
	var state: Dictionary = combat.ultimate.leg_state()
	var b: Vector3 = state["final_to"] if state["final_to"] != null else at
	var left := float(state["total_remaining"])
	if plate.is_empty() or _flat_gap(plate["at"], b) > 1.0:
		plate = {"at": combat.floor_at(b + Vector3.UP), "until": 0.0}
		_gather_tick = 0.0
	plate["radius"] = combat.ultimate.landing_radius() + (Weapons.FLY_LANDING_BONUS if id == "plate_flywheel" else 0.0)
	plate["until"] = combat.clock_now() + maxf(left, 0.0) + Weapons.GATHER_TICK
	combat.effects.ring(plate["at"], float(plate["radius"]), Palette.COPPER)


func tally_landing(id: String, at: Vector3, heft: float, chain: float) -> Array:
	var radius: float = combat.ultimate.landing_radius() + (Weapons.FLY_LANDING_BONUS if id == "plate_flywheel" else 0.0)
	var amount: float = Ultimate.LANDING_DAMAGE * heft * chain
	combat.effects.ring(at, radius, Palette.COPPER)
	ctx.break_props(at, radius, "ultimate")
	if not link_group.is_empty():
		link_group["spent"] = true
	var struck := {}
	var hits := 0
	var dealt := 0.0
	for enemy in _tally_enemies():
		if enemy.global_position.distance_to(at) > radius:
			continue
		struck[enemy.get_instance_id()] = true
		dealt += combat.ult_hit(enemy, "ultimate", amount, at, true)
		hits += 1
	var share: float = float(combat.ultimate.knob("ult_settle", Weapons.SETTLE_SHARE))
	var debts: Array = ride_clips.keys()
	if not link_group.is_empty() and float(link_group["until"]) > combat.clock_now():
		for cid in link_group["ids"]:
			if not debts.has(cid):
				debts.append(cid)
	var settled: Array = []
	for cid in debts:
		if struck.has(cid):
			continue
		var enemy = instance_from_id(cid)
		if DamageDoor.dead(enemy):
			continue
		combat.effects.arc(at + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, Palette.AMBER)
		dealt += _piece_hit(enemy, amount * share, at, Weapons.LEDGER_KNOCK)
		settled.append(cid)
	grant_pressure(ctx.player.abilities.slot(AbilityState.WEAPON).max_charges)
	if combat.ally_husks != null and combat.ghost_shift_unlocked():
		combat.ally_husks.command_charge(at)
	_fly_plates = []
	_fly_pulled = false
	tally_last_settle = {"at": at, "hits": hits, "settles": settled.size(), "ids": settled}
	_run_settles += settled.size()
	if settled.size() >= BOOKS_SETTLES:
		_tally_discover("tally_books_balanced", "set_piece", at)
	if _run_settles >= EYESHADE_SETTLES:
		_tally_discover("tally_eyeshade", "set_piece", at)
	return [hits + settled.size(), dealt]


func _step_tally_piece(delta: float) -> void:
	for p in _fly_plates.duplicate():
		if float(p["until"]) <= combat.clock_now():
			_fly_plates.erase(p)
			continue
		p["tick"] = float(p["tick"]) + delta
		while float(p["tick"]) >= Weapons.GATHER_TICK:
			p["tick"] = float(p["tick"]) - Weapons.GATHER_TICK
			combat.gather_pull(p["at"], Weapons.GATHER_RADIUS)
	if tally_piece != "plate_flywheel" or _fly_pulled or combat.ultimate == null or combat.ultimate.phase() != Ultimate.FLIGHT:
		return
	var state: Dictionary = combat.ultimate.leg_state()
	if not bool(state["is_last"]):
		return
	if float(state["remaining"]) > Weapons.FLY_PULL_LEAD:
		return
	_fly_pulled = true
	var b: Vector3 = state["to"]
	var reach: float = combat.ultimate.landing_radius() + Weapons.FLY_LANDING_BONUS + Weapons.FLY_PULL
	for enemy in _tally_enemies():
		if not combat.is_ordinary(enemy):
			continue
		var inward: Vector3 = b - enemy.global_position
		inward.y = 0.0
		if inward.length() > reach or inward.length() < 0.01:
			continue
		var weight = enemy.get("weight")
		enemy.knock(inward, Weapons.FLY_PULL / Weapons.FLY_PULL_LEAD * (float(weight) if weight != null else 1.0))


func _tally_discover(id: String, after: String, at: Vector3) -> void:
	if combat.discovered.has(id):
		return
	_tally_cards[id] = {"after": after, "at": at, "queued": Engine.get_physics_frames()}


func _step_tally_cards() -> void:
	var codex = combat.run_codex()
	var frame := Engine.get_physics_frames()
	if codex == null or frame <= _tally_card_frame:
		return
	for id in _tally_cards.keys():
		var entry: Dictionary = _tally_cards[id]
		if frame > int(entry["queued"]) and codex.known(entry["after"]):
			_tally_cards.erase(id)
			_tally_card_frame = frame
			combat.discover(id, entry["at"])
			return
