extends "res://src/boss/stub_boss.gd"

const MonsterHeft := preload("res://src/combat/monster_heft.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const ArenaMindDress := preload("res://src/presentation/arena_mind_dress.gd")
const AllyHusk := preload("res://src/combat/ally_husk.gd")

const BOSS_ID := "mind"
const ATTACK_PERIOD := 3.5
const ATTACK_DAMAGE := 10.0
const HAND_CAP := 2
const SEAL_HP := 60.0
const SEAT_REMOVES := ["split_lane", "rush"]
const PHASE_MIN_SECONDS := [22.0, 22.0, 22.0, 22.0]
const HAND_PHASE := 2
const HAND_OFFSET := 10.0
const HAND_EDGE := 4.0
const SEAT_REACH := Warden.FAMILY_REACH
const TAKEOVER_COOLDOWN := 9.0
const TAKEOVER_RANGE := 42.0
const TAKEOVER_POSTURE_BONUS := 18.0
const STALL_SPEED_SHARE := 0.75
const CAMP_PERIOD_MIN := 2.4
const STALL_RAMP_SECONDS := 1.5
const CAMP_RADIUS := 6.0
const CAMP_DELAY := 1.5
const WARN_STALL_SCALE := 0.85
const HAND_STALL_SUMMON_PERIOD := 2.4
const HAND_REST_DEFAULT := 3.0
const HAND_REST_STALL := 1.8

var landings: Array = []
var hands: Array = []
var phase := 1
var _music_phase_emitted := 1
var attack_count := 0
var takeovers_started := 0
var takeovers_interrupted := 0
var takeovers_completed := 0
var _takeover_husk: AllyHusk.HuskUnit = null
var _takeover_cd := 3.0
var _attack_clock := 0.0
var _combo_left := -1
var _family := ""
var _plate_verb := ""
var _plate_desc := {}
var _hand_slots := {}
var _hand_braced := {}
var _brace_due := false
var _plate_until := -INF
var _dress
var _arena_dress
var _hidden_stage_nodes: Array = []
var _paused_viewports: Array = []
var _stall_seconds := 0.0
var _camp_seconds := 0.0
var _camp_anchor := Vector3.ZERO
var _hand_summon_clock := 0.0


func setup(ctx_ref) -> void:
	super(ctx_ref)
	name = "MindBoss"
	ctx.events.enemy_struck.connect(_on_enemy_struck)


func _row() -> Dictionary:
	return Worlds.BOSSES[BOSS_ID]


func _hold_boss() -> String:
	return BOSS_ID


func _hold_minimums() -> Array:
	return PHASE_MIN_SECONDS


func _warden_spec() -> Dictionary:
	var spec := super()
	spec["family"] = Roster.MIND
	spec["variant"] = "choir"
	spec["monster_heft"] = MonsterHeft.mind_threshold()
	if _weak_wanted():
		var numbers: Dictionary = spec.get("posture", {}).duplicate()
		numbers["contact_gain_scale"] = 0.0
		spec["posture"] = numbers
	spec["fleet"] = ctx.spawner.fleet if ctx.spawner != null and "fleet" in ctx.spawner else null
	return spec


static func prepare_arena() -> void:
	ArenaMindDress.prepare()
	MindDress.prepare()


static func settle_arena() -> void:
	ArenaMindDress.settle()
	MindDress.settle()


static func warm_arena() -> bool:
	return ArenaMindDress.warm_kit()


func enter_arena(entry_velocity: Vector3) -> void:
	super(entry_velocity)
	phase = 1
	_music_phase_emitted = 1
	_attack_clock = 0.0
	_combo_left = -1
	_family = ""
	_plate_verb = ""
	_plate_desc = {}
	_brace_due = false
	_plate_until = -INF
	_takeover_husk = null
	_takeover_cd = 3.0
	_stall_seconds = 0.0
	_camp_seconds = 0.0
	_camp_anchor = ctx.player.ball_position()
	_hand_summon_clock = 0.0
	_arena_dress = ArenaMindDress.attach(self)
	_dress = MindDress.attach(self)
	_hide_stage_behind_arena()


func _hide_stage_behind_arena() -> void:
	_restore_stage_behind_arena()
	if _arena_dress == null or ctx == null or ctx.terrain == null:
		return
	var stage_root: Node3D = ctx.terrain.geometry_root(ctx.terrain.stage)
	if stage_root != null and is_instance_valid(stage_root) and stage_root != pad and stage_root.visible:
		_hidden_stage_nodes.append(stage_root)
		stage_root.visible = false
	if ctx.root != null and is_instance_valid(ctx.root):
		for child in ctx.root.get_children():
			var cname := String(child.name)
			if cname.begins_with("ParkRender"):
				if child is Node3D and (child as Node3D).visible:
					_hidden_stage_nodes.append(child)
					(child as Node3D).visible = false
				for sv: SubViewport in child.find_children("*", "SubViewport", true, false):
					_paused_viewports.append({"vp": sv, "mode": sv.render_target_update_mode})
					sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		for sv: SubViewport in ctx.root.find_children("*", "SubViewport", true, false):
			if sv.render_target_update_mode == SubViewport.UPDATE_DISABLED:
				continue
			var parent := sv.get_parent()
			if parent is CanvasItem and not (parent as CanvasItem).is_visible_in_tree():
				_paused_viewports.append({"vp": sv, "mode": sv.render_target_update_mode})
				sv.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _restore_stage_behind_arena() -> void:
	for node in _hidden_stage_nodes:
		if is_instance_valid(node):
			(node as Node3D).visible = true
	_hidden_stage_nodes.clear()
	for entry in _paused_viewports:
		var vp: SubViewport = entry["vp"]
		if is_instance_valid(vp):
			vp.render_target_update_mode = int(entry["mode"])
	_paused_viewports.clear()


func exit_arena() -> void:
	_restore_stage_behind_arena()
	if is_instance_valid(_arena_dress):
		_arena_dress.release()
		_arena_dress.get_parent().remove_child(_arena_dress)
		_arena_dress.queue_free()
	_arena_dress = null
	if is_instance_valid(_dress):
		remove_child(_dress)
		_dress.queue_free()
	_dress = null
	_music_phase_emitted = 1
	if is_instance_valid(_takeover_husk):
		_takeover_husk.clear_takeover()
	_takeover_husk = null
	_clear_attacks()
	_free_hands()
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if not active() or not is_instance_valid(warden):
		return
	var next := clampi(1 + BossPosture.CHUNKS - shown_chunks_left(), 1, MindAttacks.phase_cap())
	if next == MindAttacks.phase_cap() and next > phase:
		_brace_due = true
		_attack_clock = minf(_attack_clock, 0.0)
	phase = next
	var next_music_phase := MindAttacks.anthem_phase(phase)
	if next_music_phase > _music_phase_emitted:
		_music_phase_emitted = next_music_phase
		ctx.events.emit_signal("boss_phase_changed", next_music_phase, MindAttacks.anthem_phase_name(phase))
	for hand in hands:
		if is_instance_valid(hand):
			hand.boss_phase = phase
	if weak.active():
		_step_hands()
	_step_attacks(delta)
	if clock < Rules.INTRO_SECONDS:
		return
	_step_movement_pressure(delta)
	var base_period := ChallengeDials.period("mind", ATTACK_PERIOD, phase)
	var eff_period := effective_attack_period()
	var accel := base_period / maxf(eff_period, 0.1)
	_step_husk_takeover(delta * accel)
	_step_hand_timers(delta, accel)
	var clock_rate := 1.0 if (_combo_left > 0 or (_family == "plate" and clock <= _plate_until) or warden.staggered()) else accel
	_attack_clock -= delta * clock_rate
	if _attack_clock > 0.0:
		return
	_combo_left = ChallengeDials.combo_step("mind", _combo_left)
	if _combo_left > 0:
		_attack_clock = ChallengeDials.WARN_GAP
	else:
		_combo_left = -1
		_attack_clock = base_period
	_commit_attack("plate" if _brace_due else "")
	_brace_due = false
	_send_hand()


func _player_speed() -> float:
	if ctx == null or ctx.player == null:
		return 0.0
	var vel: float = (ctx.player.state.velocity as Vector3).length() if ctx.player.get("state") != null else 0.0
	return maxf(float(ctx.player.planar_velocity().length()), vel)


func ball_slow_or_camping() -> bool:
	if ctx == null or ctx.player == null or ctx.tuning == null:
		return false
	var cruise := float(ctx.tuning.f("cruise"))
	var speed := _player_speed()
	if speed >= cruise:
		return false
	return speed < STALL_SPEED_SHARE * cruise or _camp_seconds >= CAMP_DELAY


func stall_pressure() -> float:
	if not ball_slow_or_camping():
		return 0.0
	return lerpf(0.35, 1.0, clampf(_stall_seconds / STALL_RAMP_SECONDS, 0.0, 1.0))


func effective_attack_period() -> float:
	var base := ChallengeDials.period("mind", ATTACK_PERIOD, phase)
	var p := stall_pressure()
	if p <= 0.0:
		return base
	return minf(base, lerpf(base, CAMP_PERIOD_MIN, p))


func effective_warn_scale() -> float:
	return lerpf(1.0, WARN_STALL_SCALE, stall_pressure())


func _step_movement_pressure(delta: float) -> void:
	if ctx == null or ctx.player == null or ctx.tuning == null:
		return
	var cruise := float(ctx.tuning.f("cruise"))
	var speed := _player_speed()
	var ball: Vector3 = ctx.player.ball_position()
	if speed >= cruise:
		_stall_seconds = 0.0
		_camp_seconds = 0.0
		_camp_anchor = ball
		return
	if Vector2(ball.x - _camp_anchor.x, ball.z - _camp_anchor.z).length() <= CAMP_RADIUS:
		_camp_seconds += delta
	else:
		_camp_seconds = 0.0
		_camp_anchor = ball
	if speed < STALL_SPEED_SHARE * cruise or _camp_seconds >= CAMP_DELAY:
		_stall_seconds = minf(STALL_RAMP_SECONDS, _stall_seconds + delta)
	else:
		_stall_seconds = maxf(0.0, _stall_seconds - delta)


func _step_hand_timers(delta: float, accel: float) -> void:
	var p := stall_pressure()
	if p <= 0.0:
		_hand_summon_clock = 0.0
		for hand in hands:
			if is_instance_valid(hand) and not hand.is_dead() and "rest_seconds" in hand:
				hand.rest_seconds = HAND_REST_DEFAULT
		return
	_hand_summon_clock += delta * accel
	if phase >= HAND_PHASE and _hand_summon_clock >= HAND_STALL_SUMMON_PERIOD:
		_hand_summon_clock = 0.0
		_send_hand()
	var bonus := delta * maxf(0.0, accel - 1.0)
	for hand in hands:
		if not is_instance_valid(hand) or hand.is_dead():
			continue
		if "rest_seconds" in hand:
			hand.rest_seconds = lerpf(HAND_REST_DEFAULT, HAND_REST_STALL, p)
		if "_rest" in hand and float(hand._rest) > 0.0:
			hand._rest = maxf(0.0, float(hand._rest) - bonus)
		if "_takeover_cd" in hand and float(hand._takeover_cd) > 0.0:
			hand._takeover_cd = maxf(0.0, float(hand._takeover_cd) - bonus)
	if is_instance_valid(warden):
		warden.advance_choir_clock(bonus)


func _end_combo() -> void:
	if _combo_left > 0:
		_attack_clock = ChallengeDials.period("mind", ATTACK_PERIOD, phase)
	_combo_left = -1


func _publish_posture() -> void:
	if is_instance_valid(warden) and warden.fleet != null:
		return
	super()


func _on_warden_died(at: Vector3, scrap: int) -> void:
	if state == FIGHT:
		_discover("mind_quiet_gun", at)
		if ctx.run.class_def != null and ctx.run.class_def.id == "remembered_cannon":
			_discover("cannon_old_tune", at)
	_clear_attacks()
	_free_hands()
	super(at, scrap)


static func nearest_seat(bearing: float) -> int:
	var best := 0
	var gap := INF
	for k in 3:
		var d := absf(angle_difference(-k * TAU / 3.0, bearing))
		if d < gap - 0.0001:
			gap = d
			best = k
	return best


func _weak_parts() -> Array:
	var parts := []
	for k in 3:
		parts.append({"id": "seat_%d" % k, "seal_hp": SEAL_HP, "removes": ""})
	for k in HAND_CAP:
		parts.append({"id": "hand_%d" % k, "seal_hp": SEAL_HP, "removes": ""})
	return parts


func weak_open() -> Array:
	return super().filter(func(id): return not String(id).begins_with("hand_"))


func seat_position(k: int) -> Vector3:
	var lens: Vector3 = warden.family_point_at()
	var ring := Vector3.RIGHT * Warden.CHOIR_RADIUS
	return lens - ring.rotated(Vector3.UP, warden.open_lens * TAU / 3.0) + ring.rotated(Vector3.UP, k * TAU / 3.0)


func _weak_position(id: String) -> Vector3:
	if id.begins_with("seat_") and is_instance_valid(warden):
		return seat_position(int(id.substr(5)))
	return super(id)


func _weak_point_for(part: String, kind: String) -> String:
	if not is_instance_valid(warden) or (kind != "" and not kind in Rules.CONTACT_KINDS):
		return ""
	var ball: Vector3 = ctx.player.ball_position()
	var best := ""
	var gap := INF
	for id in weak_open():
		if not String(id).begins_with("seat_"):
			continue
		var at := seat_position(int(String(id).substr(5)))
		var d := Vector2(ball.x - at.x, ball.z - at.z).length()
		if d <= SEAT_REACH and d < gap:
			gap = d
			best = id
	return best


func _brace_scale(kind: String) -> float:
	if _plate_desc.is_empty() or clock > _plate_until:
		return 1.0
	return MindAttacks.hit_mult(_plate_desc, kind)


func _step_hands() -> void:
	for hand in hands:
		if not is_instance_valid(hand) or hand.is_dead():
			continue
		var key: int = hand.get_instance_id()
		if not _hand_slots.has(key):
			continue
		var braced: bool = hand.braced()
		if braced and not bool(_hand_braced.get(key, false)):
			_open_weak("hand_%d" % int(_hand_slots[key]), true)
		_hand_braced[key] = braced


func _hand_cap() -> int:
	var cap := HAND_CAP
	for k in HAND_CAP:
		cap -= 1 if weak.state("hand_%d" % k) == WeakPoints.BROKEN else 0
	return cap


func _assign_slot(hand: Node3D) -> void:
	var held := []
	for other in hands:
		if other != hand and is_instance_valid(other):
			held.append(int(_hand_slots.get(other.get_instance_id(), -1)))
	for k in HAND_CAP:
		if weak.state("hand_%d" % k) != WeakPoints.BROKEN and not held.has(k):
			_hand_slots[hand.get_instance_id()] = k
			return


func _hand_struck(hand: Node3D, kind: String, force: float) -> void:
	var key: int = hand.get_instance_id()
	var id := "hand_%d" % int(_hand_slots[key])
	if state != FIGHT or not hand.braced() or not kind in Rules.CONTACT_KINDS:
		return
	var frame := Engine.get_physics_frames()
	var reel := _is_reel_impact(hand, kind)
	if reel and int(_reel_frame.get(id, -1)) == frame:
		reel = false
	var punch: float = ctx.spawner.punch_of(kind, force) if ctx.spawner != null and ctx.spawner.has_method("punch_of") else force
	var answer: Dictionary = weak.judge({"point": id, "reel": reel, "punch": punch, "gain": 0.0})
	weak.apply(answer, clock)
	if float(answer["gain_scale"]) >= 1.0 and reel:
		_reel_frame[id] = frame
	if float(answer["damage"]) > 0.0 or bool(answer["broke"]):
		ctx.events.boss_weak_point_hit.emit(id)
	if bool(answer["broke"]):
		hands.erase(hand)
		hand.take_damage(hand.hp + 1.0)


func _removed_families() -> Array:
	var broken := 0
	for k in 3:
		broken += 1 if weak.state("seat_%d" % k) == WeakPoints.BROKEN else 0
	return SEAT_REMOVES.slice(0, mini(broken, SEAT_REMOVES.size()))


func _commit_attack(family := "") -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var center := pad.global_position if is_instance_valid(pad) else warden.global_position
	center.y = _top()
	attack_count += 1
	var seed: int = attack_count * 7919 + ctx.run.stage
	var safe := MindAttacks.commit_safe(family, seed, ball, center, phase, ctx.tuning.f("cruise"), PAD_RADIUS, _removed_families(), effective_warn_scale())
	var descriptors: Array = safe["descriptors"]
	if MindAttacks.FALLBACK_PATHS.has(safe["path"]):
		push_warning("mind: attack %d had no escape; fell back to %s" % [attack_count, safe["path"]])
	if descriptors.is_empty():
		return
	var laid: Array = []
	var aimed := false
	for d in descriptors:
		aimed = aimed or BossAttacks.covers(d, ball)
		var h = Hazard.from_def(d)
		h.ground = Callable(self, "ground_height_at")
		ctx.root.add_child(h)
		laid.append(h)
		_family = String(d["family"])
		if d.has("verb"):
			_plate_verb = String(d["verb"])
			_plate_desc = d
			_end_combo()
			_plate_until = clock + h.warn_seconds + h.live_seconds + ChallengeDials.punish("mind", MindAttacks.PLATE_WINDOW)
			_open_weak("seat_%d" % nearest_seat((float(d["from_angle"]) + float(d["to_angle"])) * 0.5))
		ctx.events.boss_attack_telegraphed.emit(String(d["id"]), h.warn_seconds)
	var ledger: Dictionary = ctx.run.get_meta("boss_attacks", {})
	ledger[_family] = int(ledger.get(_family, 0)) + 1
	ctx.run.set_meta("boss_attacks", ledger)
	attacks.append({"hazards": laid, "family": _family, "landed": false, "aimed": aimed})


func _step_attacks(delta: float) -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var kept: Array = []
	for attack in attacks:
		var done := true
		for h in attack["hazards"]:
			if not is_instance_valid(h):
				continue
			h.step(delta)
			if h.is_live() and not attack["landed"] and h.contains(ball):
				attack["landed"] = true
				landings.append({"id": h.attack_id, "frame": Engine.get_physics_frames()})
				ctx.run.damage(ChallengeDials.damage("mind", ATTACK_DAMAGE, phase), "mind_%s" % attack["family"])
			if not (h.is_done() and h.age >= h.warn_seconds + h.live_seconds + 0.5):
				done = false
		if done:
			_free_hazards(attack)
			if attack["aimed"] and not attack["landed"] and attack["family"] in ["lane", "split_lane", "rush"]:
				_discover("mind_" + String(attack["family"]), ball)
		else:
			kept.append(attack)
	attacks = kept


func _on_enemy_struck(enemy: Node3D, kind: String, force: float) -> void:
	if weak.active() and _hand_slots.has(enemy.get_instance_id()):
		_hand_struck(enemy, kind, force)
		return
	if state != FIGHT or enemy != warden or not warden.staggered() or clock > _plate_until:
		return
	if kind in Rules.CONTACT_KINDS and kind != _plate_verb:
		_discover(CodexEntries.MIND_PLATE, ctx.player.ball_position())


func _free_hands() -> void:
	_hand_slots.clear()
	_hand_braced.clear()
	for hand in hands:
		if is_instance_valid(hand):
			hand.queue_free()
	hands.clear()


func _send_hand() -> void:
	hands = hands.filter(func(hand): return is_instance_valid(hand) and not hand.is_dead())
	if phase < HAND_PHASE or hands.size() >= _hand_cap() or not ctx.can_spawn():
		return
	var center := pad.global_position if is_instance_valid(pad) else warden.global_position
	var ball: Vector3 = ctx.player.ball_position()
	var out := Vector3(ball.x - center.x, 0.0, ball.z - center.z)
	var side := Vector3.UP.cross(out.normalized() if out.length() > 0.1 else Vector3.FORWARD)
	if attack_count % 2 == 0:
		side = -side
	var flat := Vector3(ball.x, 0.0, ball.z) + side * HAND_OFFSET - Vector3(center.x, 0.0, center.z)
	flat = flat.limit_length(PAD_RADIUS - HAND_EDGE)
	var hand = ctx.spawner.spawn_enemy("mind_hand", drop_point(center.x + flat.x, center.z + flat.z))
	if hand != null:
		hand.boss_phase = phase
		hands.append(hand)
		if weak.active():
			_assign_slot(hand)


func _step_husk_takeover(delta: float) -> void:
	_takeover_cd = maxf(0.0, _takeover_cd - delta)
	if is_instance_valid(_takeover_husk):
		if not _takeover_husk.takeover_active:
			_takeover_husk = null
		return
	if _takeover_cd > 0.0 or ctx == null or ctx.spawner == null:
		return
	var mgr = ctx.spawner.get("ally_husks")
	if mgr == null or not mgr.has_method("first_takeover_target"):
		return
	var origin: Vector3 = warden.global_position if is_instance_valid(warden) else Vector3.ZERO
	var husk: AllyHusk.HuskUnit = mgr.first_takeover_target(origin, TAKEOVER_RANGE)
	if husk != null:
		attempt_husk_takeover(husk)


func attempt_husk_takeover(husk: AllyHusk.HuskUnit) -> bool:
	if ctx == null or ctx.spawner == null or husk == null or not is_instance_valid(husk):
		return false
	var mgr = ctx.spawner.get("ally_husks")
	if mgr == null or not mgr.begin_takeover(husk, self, AllyHusk.TAKEOVER_WARN_SECONDS):
		return false
	_takeover_husk = husk
	takeovers_started += 1
	return true


func on_takeover_interrupted(_husk) -> void:
	_takeover_husk = null
	_takeover_cd = TAKEOVER_COOLDOWN
	takeovers_interrupted += 1
	_end_combo()
	_attack_clock = maxf(_attack_clock, 1.5)
	if is_instance_valid(warden) and warden.has_method("apply_posture_hit"):
		warden.apply_posture_hit({"gain": TAKEOVER_POSTURE_BONUS, "full": true, "crack": false, "shatter": false, "dealt": 0.0})


func on_takeover_completed(_husk) -> void:
	_takeover_husk = null
	_takeover_cd = TAKEOVER_COOLDOWN
	takeovers_completed += 1


func music_state() -> Dictionary:
	var state := super()
	if not state.is_empty():
		state["id"] = String(_row().get("music", BOSS_ID))
		state["phase"] = MindAttacks.anthem_phase(phase)
		state["anthem_bpm_delta"] = MindAttacks.anthem_bpm_delta(phase)
		state["finale_lift_semitones"] = MindAttacks.finale_lift_semitones(phase)
		if hold_active():
			state["held"] = true
			state["in_phase"] = 1.0
	return state


func objective_text() -> String:
	if state != FIGHT or not is_instance_valid(warden):
		return super()
	var who := String(_row().get("name", "the boss"))
	if warden.staggered():
		var braced := "nothing" if warden.braced_kinds.is_empty() else "/".join(warden.braced_kinds)
		return "%s is staggered: hit its open lens. It braces against %s." % [who, braced]
	var text := "Fill %s's bar to stagger it. %d chunks left." % [who, warden.chunks_left()]
	if hold_capped():
		text = "%s's bar is full. It breaks in %d s: keep the pressure on." % [who, ceili(hold_left())]
	if _family != "":
		text += " Incoming: %s." % _family.replace("_", " ")
	if _family == "plate" and _plate_verb != "":
		text += " Its plate braces %s." % _plate_verb
	if not weak_open().is_empty():
		text += " Its lens seat is open: hook it and haul in."
	return text
