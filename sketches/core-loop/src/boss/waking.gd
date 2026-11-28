extends "res://src/boss/stub_boss.gd"

const MonsterHeft := preload("res://src/combat/monster_heft.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const WakingFloors := preload("res://src/boss/waking_floors.gd")
const WakingDress := preload("res://src/boss/waking_dress.gd")
const ArenaWakingDress := preload("res://src/presentation/arena_waking_dress.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const FloorRule := preload("res://src/combat/floor_rule.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

const BOSS_ID := "waking"
const FLOOR_NAMES := ["Spoil", "Seam", "Bedrock"]
const FLOOR_WARN := 1.0
const BREACH_WINDOW := 2.0
const ATTACK_PERIOD := 3.4
const PIT_PERIOD := 2.6
const GAP := WakingAttacks.GAP
const BANK_IN := 30.0
const BANK_RISE := PAD_RADIUS - BANK_IN
const BANK_PROFILE_STEPS := 8
const BANK_SEGMENTS := 48
const BANK_COLOR := Color(0.56, 0.50, 0.40)
const BORE_JAM := 3.0
const EXPOSED_SCALE := 0.5
const LIP_WINDOW := 1.5
const LIP_SCALE := 0.6
const LANDING_ATTACK := 1.2
const POSTURE_GAIN := 0.565
const HIT_CAP := 15.0
const PHASE_MIN_SECONDS := [21.0, 21.0, 21.0, 21.0]
const SEAL_HP := 60.0
const FAMILY_NAMES := {"burrow": "burrow lane", "cave_in": "cave-in", "bore": "bore breach"}
const HATCH_BEARINGS := [0.0, TAU / 3.0, TAU * 2.0 / 3.0]
const HATCH_LIFT := 1.2
const HATCH_INSET := 0.5
const BORE_HEAD_RADIUS := 20.0
const BORE_HEAD_BEARING := PI * 0.25

const CREW_WAVE := 3
const CREW_CAP := 6
const CREW_WAVES_PER_PHASE := 3
const CREW_SPAWN_ARC := TAU * 110.0 / 360.0
const CREW_SPAWN_RADIUS := 30.0
const CREW_SPAWN_SPACING := 1.8
const CREW_SLOT_SPACING := 2.4
const CREW_SLOT_INSET := 2.0
const PLATE_HELD_CLEAR := 1.6
const PLATE_FITTED_CLEAR := 0.7
const PLATE_FALL_SPEED := 9.0
const PLATE_FALL_SECONDS := 1.2
const PLATE_REST_TILT := 0.35
const STALL_SPEED_SHARE := 0.75
const STALL_GRACE := 1.5
const STALL_RAMP := 2.0
const STALL_DECAY := 2.0
const STALL_ATTACK_PERIOD := 2.4
const STALL_PIT_PERIOD := 2.0
const SEAL_CUE_KIND := "weak_point_opened"
const SEAL_SOUND := "seal_ratchet"
const SEAL_GAP_SLOW := 0.55
const SEAL_GAP_FAST := 0.14
const SEAL_PITCH_LOW := 0.85
const SEAL_PITCH_HIGH := 1.6

var floors: WakingFloors
var _floor_bodies := {}
var _center := Vector3.ZERO
var _drops: Array[int] = []
var _queued := 0
var _dropping := 0
var _drop_left := 0.0
var _dropped_at := -INF
var _breach_floors := {}
var _dress
var _arena_dress
var landings: Array = []
var attack_count := 0
var phase := 1
var _music_phase_emitted := 1
var _pending: Array = []
var _attack_clock := 0.0
var _combo_left := -1
var _family := ""
var _last_warn := -INF
var warnings: Array = []
var _taught := {}
var _jammed_until := -INF
var _carved_at := -INF
var _lip_seen := false
var _base_plating := 0.0
var _banked := {}
var _pulse_charging := false
var _crew: Array = []
var _crew_waves := 0
var _crew_phase := 0
var _plates := {}
var _plate_latch := {}
var _fallen: Array = []
var seal_cue_log: Array = []
var _seal_cue_left := 0.0
var weak_sealed: Array = []
var weak_stats := {"opened": {}, "sealed": {}, "timed_out": {}, "broken": {}, "crew_waves": {}, "open_at_end": {}}
var weak_open_at_end: Dictionary = weak_stats["open_at_end"]
var _weak_open_phase := {}
var _seals_seen := {}
var _weak_last := {}
var _stall_s := 0.0
var _stall_clock_seen := 0.0


func setup(ctx_ref) -> void:
	super(ctx_ref)
	name = "WakingBoss"
	ctx.events.enemy_struck.connect(_on_enemy_struck)


func enter_arena(entry_velocity: Vector3) -> void:
	_reset_weak_record()
	super(entry_velocity)
	_center = pad.global_position + Vector3.UP * PAD_THICK * 0.5
	_add_bank(pad)
	floors = WakingFloors.new(FLOOR_NAMES.slice(0, Rules.PHASE_NAMES.size()))
	for k in range(1, floors.floor_count() + 1):
		_floor_bodies[k] = _build_floor(k)
	_place_ball(_center + Vector3.UP * floors.floor_height(1), entry_velocity)
	_seat_warden()
	_base_plating = warden.plating
	phase = 1
	_music_phase_emitted = 1
	_attack_clock = 0.0
	_combo_left = -1
	_stall_s = 0.0
	_stall_clock_seen = 0.0
	_dress = WakingDress.attach(self)
	_arena_dress = ArenaWakingDress.attach(self)
	if weak.active():
		_build_parts()


func exit_arena() -> void:
	if is_instance_valid(_arena_dress):
		_arena_dress.release_lights()
		remove_child(_arena_dress)
		_arena_dress.queue_free()
	_arena_dress = null
	if is_instance_valid(_dress):
		remove_child(_dress)
		_dress.queue_free()
	_dress = null
	for body in _floor_bodies.values():
		_free_body(body)
	_floor_bodies.clear()
	_drops.clear()
	_queued = 0
	_dropping = 0
	_drop_left = 0.0
	_dropped_at = -INF
	_breach_floors.clear()
	_clear_attacks()
	landings.clear()
	_family = ""
	_last_warn = -INF
	warnings.clear()
	_taught.clear()
	_jammed_until = -INF
	_carved_at = -INF
	_lip_seen = false
	_banked.clear()
	_pulse_charging = false
	_music_phase_emitted = 1
	_stall_s = 0.0
	_stall_clock_seen = 0.0
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if not active() or not is_instance_valid(warden) or floors == null:
		return
	floors.on_posture(shown_chunks_left())
	while _queued < mini(floors.shattered, floors.floor_count()):
		_queued += 1
		_drops.append(_queued)
	if _dropping == 0 and not _drops.is_empty() and _warn_open():
		_dropping = _drops.pop_front()
		_drop_left = FLOOR_WARN
		_warned(floors.floor_id(_dropping), FLOOR_WARN)
	if _dropping != 0:
		_drop_left -= delta
		if _drop_left <= 0.0:
			_free_body(_floor_bodies.get(_dropping))
			_floor_bodies.erase(_dropping)
			if weak.active():
				_free_part("hatch_%d" % _dropping)
			_dropping = 0
			_seat_warden()
			_dropped_at = clock
			_discover(CodexEntries.WAKING_FLOOR_DROP, ctx.player.ball_position())
			_clear_attacks()
			_attack_clock = LANDING_ATTACK
			_combo_left = -1
	phase = clampi(floors.shattered + 1, 1, WakingAttacks.PIT_PHASE)
	var next_music_phase := floors.music_phase()
	if next_music_phase > _music_phase_emitted:
		_music_phase_emitted = next_music_phase
		ctx.events.emit_signal("boss_phase_changed", next_music_phase, floors.phase_name())
	if weak.active():
		_note_weak()
		_step_crew()
		_step_plates(delta)
		_step_seal_cue(delta)
	_read_pulse()
	_read_ball()
	_step_stall(delta)
	_open_by_lip()
	_step_attacks(delta)
	_lay_pending()
	_set_plating()
	if clock < Rules.INTRO_SECONDS or _dropping != 0 or not _drops.is_empty():
		return
	_attack_clock -= delta
	if _attack_clock > 0.0:
		return
	_combo_left = ChallengeDials.combo_step("waking", _combo_left)
	if _combo_left > 0:
		_attack_clock = GAP
	else:
		_combo_left = -1
		_attack_clock = current_attack_period()
	_commit_attack()


func _end_combo() -> void:
	if _combo_left > 0:
		_attack_clock = current_attack_period()
	_combo_left = -1


func arena_center() -> Vector3:
	return _center


func is_dropping() -> int:
	return _dropping


func _planar_speed() -> float:
	if ctx == null or ctx.player == null:
		return 0.0
	if ctx.player.has_method("planar_velocity"):
		return float(ctx.player.planar_velocity().length())
	var body = ctx.player.body() if ctx.player.has_method("body") else null
	if body == null:
		return 0.0
	var v: Vector3 = body.linear_velocity
	return Vector2(v.x, v.z).length()


func _step_stall(delta: float) -> void:
	if clock < _stall_clock_seen:
		_stall_s = 0.0
	_stall_clock_seen = clock
	if clock < Rules.INTRO_SECONDS:
		return
	var cruise := maxf(1.0, float(ctx.tuning.f("cruise")))
	var speed := _planar_speed()
	if carving_now() or speed >= cruise:
		_stall_s = maxf(0.0, _stall_s - delta * STALL_DECAY)
	elif speed < cruise * STALL_SPEED_SHARE:
		_stall_s = minf(STALL_GRACE + STALL_RAMP, _stall_s + delta)


func stall_pressure() -> float:
	if _stall_s <= STALL_GRACE:
		return 0.0
	return clampf((_stall_s - STALL_GRACE) / STALL_RAMP, 0.0, 1.0)


func current_attack_period() -> float:
	var base := PIT_PERIOD if phase >= WakingAttacks.PIT_PHASE else ATTACK_PERIOD
	var tight := STALL_PIT_PERIOD if phase >= WakingAttacks.PIT_PHASE else STALL_ATTACK_PERIOD
	return ChallengeDials.period("waking", lerpf(base, tight, stall_pressure()), phase)


func _warn_open() -> bool:
	return clock - _last_warn >= GAP - 0.0001 and not _pulse_due()


func _pulse_due() -> bool:
	if not is_instance_valid(warden) or warden.staggered() or warden.state_name() == "charging":
		return false
	var due: float = Warden.pulse_cycle(warden.stage) - Warden.pulse_telegraph(warden.stage)
	var pc: float = warden.pulse_clock()
	return pc >= due - GAP and pc < due + GAP and warden.flat_to_ball().length() <= warden.reach


func _read_pulse() -> void:
	var charging: bool = is_instance_valid(warden) and warden.state_name() == "charging"
	if charging and not _pulse_charging:
		_last_warn = clock
		warnings.append({"id": "warden_pulse", "at": clock})
	_pulse_charging = charging


func _warned(id: String, seconds: float) -> void:
	_last_warn = clock
	warnings.append({"id": id, "at": clock})
	ctx.events.boss_attack_telegraphed.emit(id, seconds)


func _commit_attack(family := "") -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var center := Vector3(_center.x, _top(), _center.z)
	attack_count += 1
	var seed: int = attack_count * 7919 + ctx.run.stage
	if family == "":
		family = WakingAttacks.newest(phase, weak.removed_families())
		if _taught.has(phase):
			family = WakingAttacks.choose(seed, phase, weak.removed_families())
		_taught[phase] = true
	var safe := WakingAttacks.commit_safe(family, seed, ball, ctx.player.body().linear_velocity, center, phase, ctx.tuning.f("cruise"),
			PAD_RADIUS, weak.removed_families())
	if WakingAttacks.FALLBACK_PATHS.has(safe["path"]):
		push_warning("waking: attack %d had no escape; fell back to %s" % [attack_count, safe["path"]])
	var descriptors: Array = safe["descriptors"]
	if descriptors.is_empty():
		return
	_family = family
	var attack := {"hazards": [], "family": family, "landed": false, "descs": descriptors}
	attacks.append(attack)
	var start := maxf(clock, _last_warn + GAP)
	for d in descriptors:
		_pending.append({"desc": d, "at": start + float(d.get("delay", 0.0)), "attack": attack})
	var ledger: Dictionary = ctx.run.get_meta("boss_attacks", {})
	ledger[family] = int(ledger.get(family, 0)) + 1
	ctx.run.set_meta("boss_attacks", ledger)


func _lay_pending() -> void:
	if _pending.is_empty() or _dropping != 0 or _pending[0]["at"] > clock + 0.0001 or not _warn_open():
		return
	var item: Dictionary = _pending.pop_front()
	var d: Dictionary = item["desc"]
	var h = Hazard.from_def(d)
	h.ground = Callable(self, "ground_height_at")
	ctx.root.add_child(h)
	(item["attack"]["hazards"] as Array).append(h)
	_warned(String(d["id"]), h.warn_seconds)


func _step_attacks(delta: float) -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var state = ctx.player.state
	var carving := carving_now()
	var kept: Array = []
	for attack in attacks:
		var waiting := false
		for item in _pending:
			waiting = waiting or item["attack"] == attack
		var done := not waiting
		for h in attack["hazards"]:
			if not is_instance_valid(h):
				continue
			h.step(delta)
			if h.is_live() and h.contains(ball):
				if state.grounded and not carving and not attack["landed"]:
					attack["landed"] = true
					landings.append({"id": h.attack_id, "frame": Engine.get_physics_frames()})
					ctx.run.damage(ChallengeDials.damage("waking", float(WakingAttacks.DAMAGE[attack["family"]]), phase), "waking_%s" % attack["family"])
				elif carving:
					_bank_ride(attack["family"], ball)
			if h.is_live() and attack["family"] == "bore" and h.attack_id.begins_with("waking_bore_0"):
				_end_combo()
				if weak.active() and not attack.get("opened", false) and _open_bore_part():
					attack["opened"] = true
				_jammed_until = clock + (h.warn_seconds + h.live_seconds - h.age) + ChallengeDials.punish("waking", BORE_JAM)
			if not (h.is_done() and h.age >= h.warn_seconds + h.live_seconds + 0.5):
				done = false
		if weak.active() and not waiting and attack["family"] != "bore" and not attack.get("opened", false) \
				and not (attack["hazards"] as Array).is_empty() and _attack_ended(attack):
			attack["opened"] = true
			_open_hatch(WakingAttacks.FAMILIES.find(attack["family"]) + 1)
		if done:
			_free_hazards(attack)
		else:
			kept.append(attack)
	attacks = kept


func _attack_ended(attack: Dictionary) -> bool:
	for h in attack["hazards"]:
		if is_instance_valid(h) and not h.is_done():
			return false
	return true


func part_reachable(id: String) -> bool:
	if id == "override":
		return phase >= WakingAttacks.PIT_PHASE and _floor_bodies.is_empty() and _drops.is_empty() and _dropping == 0
	if not id.begins_with("hatch_"):
		return true
	var k := int(id.substr(6))
	if not _floor_bodies.has(k) or _dropping == k or _drops.has(k):
		return false
	for j in range(1, k):
		if _floor_bodies.has(j):
			return false
	return true


func _part_reachable(id: String) -> bool:
	return part_reachable(id)


func _open_hatch(k: int) -> void:
	if part_reachable("hatch_%d" % k):
		_open_point("hatch_%d" % k)


func _open_point(id: String) -> void:
	if _open_weak(id):
		_weak_open_phase[id] = phase
		_tally("opened", phase)
		_weak_last[id] = WeakPoints.OPEN
		_call_crew(id)


func _open_override() -> void:
	if part_reachable("override"):
		_open_point("override")


func _open_bore_part() -> bool:
	var id := "override" if phase >= WakingAttacks.PIT_PHASE else "hatch_3"
	if not part_reachable(id):
		return false
	_open_point(id)
	return true


func _bank_ride(family: String, at: Vector3) -> void:
	_banked[family] = true
	if _banked.size() >= WakingAttacks.FAMILIES.size():
		_discover(CodexEntries.WAKING_WALL_HOME, at)


func _read_ball() -> void:
	if carving_now():
		_carved_at = clock


func carving_now() -> bool:
	var state = ctx.player.state
	if "carving" in state:
		return bool(state.carving)
	return state.grounded and state.tier >= SpeedTier.FAST and not FloorRule.on_floor(state)


func _open_by_lip() -> void:
	var lip := lip_drop()
	if lip and not _lip_seen and phase < WakingAttacks.PIT_PHASE:
		_open_hatch(phase)
	_lip_seen = lip


func _weak_parts() -> Array:
	var parts := []
	for k in WakingAttacks.FAMILIES.size():
		parts.append({"id": "hatch_%d" % (k + 1), "seal_hp": SEAL_HP, "removes": WakingAttacks.FAMILIES[k]})
	parts.append({"id": "override", "seal_hp": SEAL_HP, "removes": "pit_spray"})
	return parts


func _build_parts() -> void:
	for k in range(1, floors.floor_count() + 1):
		var way := Vector3(cos(HATCH_BEARINGS[k - 1]), 0.0, sin(HATCH_BEARINGS[k - 1]))
		var at := _center + way * (PAD_RADIUS - HATCH_INSET) + Vector3.UP * (floors.floor_height(k) + BANK_RISE + HATCH_LIFT)
		_add_part("hatch_%d" % k, at, -way)
	var head := Vector3(cos(BORE_HEAD_BEARING), 0.0, sin(BORE_HEAD_BEARING))
	_add_part("override", _center + head * BORE_HEAD_RADIUS + Vector3.UP * HATCH_LIFT, -head)


func jammed() -> bool:
	return clock < _jammed_until


func lip_drop() -> bool:
	return not ctx.player.state.grounded and clock - _carved_at <= LIP_WINDOW


func plating_scale() -> float:
	return (EXPOSED_SCALE if jammed() else 1.0) * (LIP_SCALE if lip_drop() else 1.0)


func _set_plating() -> void:
	if _base_plating > 0.0:
		warden.plating = _base_plating * plating_scale()


func _clear_attacks() -> void:
	super()
	_pending.clear()


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if not _crew.is_empty():
		_crew_struck(enemy, kind)
	if state != FIGHT or enemy != warden or kind != "slam":
		return
	var at: Vector3 = ctx.player.ball_position()
	if jammed() and clock - _carved_at <= LIP_WINDOW:
		_discover(CodexEntries.WAKING_LIP_DROP, at)
	if clock - _dropped_at >= ChallengeDials.punish("waking", BREACH_WINDOW):
		return
	_end_combo()
	_discover(CodexEntries.WAKING_BREACH_SLAM, at)
	_breach_floors[floors.current_floor()] = true
	if _breach_floors.size() >= 2:
		_discover(CodexEntries.WAKING_FLOOR_CHAIN, at)


func _on_warden_died(at: Vector3, scrap: int) -> void:
	if weak.active():
		_note_weak()
	if state == FIGHT:
		_discover(CodexEntries.WAKING_FINAL_FLOOR, ctx.player.ball_position())
	_clear_attacks()
	super(at, scrap)


func _build_floor(k: int) -> StaticBody3D:
	var saved := pad
	_build_pad(_center + Vector3.UP * floors.floor_height(k))
	var body := pad
	pad = saved
	body.name = "WakingFloor%d" % k
	_add_bank(body)
	return body


func _add_bank(body: StaticBody3D) -> void:
	var top := PAD_THICK * 0.5
	var profile: Array[Vector2] = []
	for j in BANK_PROFILE_STEPS + 1:
		var a := PI * 0.5 * j / BANK_PROFILE_STEPS
		profile.append(Vector2(BANK_IN + BANK_RISE * sin(a), top + BANK_RISE * (1.0 - cos(a))))
	var faces := PackedVector3Array()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BANK_SEGMENTS:
		var a0 := TAU * i / BANK_SEGMENTS
		var a1 := TAU * (i + 1) / BANK_SEGMENTS
		for j in BANK_PROFILE_STEPS:
			var p := profile[j]
			var q := profile[j + 1]
			var lo0 := Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x)
			var lo1 := Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)
			var hi0 := Vector3(cos(a0) * q.x, q.y, sin(a0) * q.x)
			var hi1 := Vector3(cos(a1) * q.x, q.y, sin(a1) * q.x)
			var u0 := float(i) / float(BANK_SEGMENTS) * 16.0
			var u1 := float(i + 1) / float(BANK_SEGMENTS) * 16.0
			var v0 := float(j) / float(BANK_PROFILE_STEPS) * 2.0
			var v1 := float(j + 1) / float(BANK_PROFILE_STEPS) * 2.0
			var tri_verts := [lo0, hi1, hi0, lo0, lo1, hi1]
			var tri_uvs := [Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1)]
			for idx in 6:
				faces.append(tri_verts[idx])
				surface.set_uv(tri_uvs[idx])
				surface.add_vertex(tri_verts[idx])
	var shape := CollisionShape3D.new()
	shape.name = "RimBank"
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.set_faces(faces)
	trimesh.backface_collision = true
	shape.shape = trimesh
	body.add_child(shape)
	surface.generate_normals()
	surface.generate_tangents()
	var material := StandardMaterial3D.new()
	material.albedo_color = BANK_COLOR
	material.roughness = 0.64
	material.metallic = 0.22
	Palette.surface_grain(material)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	var mesh := MeshInstance3D.new()
	mesh.name = "RimBankMesh"
	mesh.mesh = surface.commit()
	body.add_child(mesh)


func _free_body(body) -> void:
	if is_instance_valid(body):
		body.collision_layer = 0
		body.queue_free()


func _seat_warden() -> void:
	if is_instance_valid(warden):
		var at: Vector3 = warden.global_position
		warden.global_position = Vector3(at.x, ground_height_at(at) + Warden.HALF_HEIGHT, at.z)


func _top() -> float:
	if not is_instance_valid(pad):
		return -INF
	for k in range(1, floors.floor_count() + 1 if floors != null else 1):
		if _floor_bodies.has(k):
			return _center.y + floors.floor_height(k)
	return super()


func _bank_rise_at(point: Vector3) -> float:
	var r := Vector2(point.x - _center.x, point.z - _center.z).length()
	if r <= BANK_IN or r > PAD_RADIUS:
		return 0.0
	var s := clampf((r - BANK_IN) / BANK_RISE, 0.0, 1.0)
	return BANK_RISE * (1.0 - sqrt(maxf(0.0, 1.0 - s * s)))


func ground_height_at(point: Vector3) -> float:
	if is_instance_valid(pad):
		if Vector2(point.x - _center.x, point.z - _center.z).length() > PAD_RADIUS:
			return super._top()
		return _top() + _bank_rise_at(point)
	return super(point)


func _row() -> Dictionary:
	return Worlds.BOSSES[BOSS_ID]


func _hold_boss() -> String:
	return BOSS_ID


func _hold_minimums() -> Array:
	return PHASE_MIN_SECONDS


func _warden_spec() -> Dictionary:
	var spec := super()
	var numbers: Dictionary = spec.get("posture", {}).duplicate()
	var base: Dictionary = BossPosture.BASE.duplicate()
	base.merge(numbers.get("base", {}), true)
	for kind in base:
		base[kind] = float(base[kind]) * POSTURE_GAIN
	numbers["base"] = base
	numbers["smash_base"] = float(numbers.get("smash_base", BossPosture.SMASH_BASE)) * POSTURE_GAIN
	numbers["other_base"] = float(numbers.get("other_base", BossPosture.OTHER_BASE)) * POSTURE_GAIN
	numbers["other_base_charging"] = float(numbers.get("other_base_charging", BossPosture.OTHER_BASE_CHARGING)) * POSTURE_GAIN
	numbers["hit_cap"] = HIT_CAP
	numbers["hit_cap_until_stagger"] = true
	if _weak_wanted():
		numbers["contact_gain_scale"] = 0.0
	spec["posture"] = numbers
	spec["monster_heft"] = MonsterHeft.waking_threshold()
	return spec


func music_state() -> Dictionary:
	var state := super()
	if not state.is_empty():
		state["id"] = String(_row().get("music", BOSS_ID))
		if hold_active():
			state["held"] = true
			state["in_phase"] = 1.0
		state["phase"] = floors.music_phase()
		state["anthem_bpm_delta"] = floors.anthem_bpm_delta()
	return state


func objective_text() -> String:
	if state == FIGHT and floors != null:
		var text := "%s, %s" % [String(_row().get("name", "The Waking")), floors.objective()]
		if hold_capped():
			text = "%s's bar is full. It breaks in %d s: keep the pressure on" % [String(_row().get("name", "The Waking")), ceili(hold_left())]
		if jammed():
			text += ". Its drill is jammed: hit it now"
		elif _family != "":
			text += ". Incoming: %s" % FAMILY_NAMES.get(_family, _family)
		var open := weak_open()
		if not open.is_empty():
			text += ". Its %s is open: hook it and haul in" % ("override button" if open[-1] == "override" else "hatch")
		return text
	return super()


func crew() -> Array:
	return _crew.filter(func(c): return is_instance_valid(c["node"])).map(func(c): return c["node"])


func _crew_alive() -> int:
	var n := 0
	for c in _crew:
		if is_instance_valid(c["node"]) and not c["node"].is_dead():
			n += 1
	return n


func _call_crew(id: String) -> void:
	if not weak.active() or not ctx.can_spawn():
		return
	if phase != _crew_phase:
		_crew_phase = phase
		_crew_waves = 0
	var count := mini(CREW_WAVE, CREW_CAP - _crew_alive())
	if count <= 0 or _crew_waves >= CREW_WAVES_PER_PHASE:
		return
	_crew_waves += 1
	_tally("crew_waves")
	var part = weak_part(id)
	var hatch: Vector3 = part.global_position if part != null else _weak_position(id)
	var out := Vector3(hatch.x - _center.x, 0.0, hatch.z - _center.z)
	var bearing := atan2(out.z, out.x) + CREW_SPAWN_ARC * (1.0 if _crew_waves % 2 == 1 else -1.0)
	var way := Vector3(cos(bearing), 0.0, sin(bearing))
	var side := Vector3.UP.cross(way)
	var base := Vector3(_center.x, _top() + 1.0, _center.z) + way * CREW_SPAWN_RADIUS
	for i in count:
		var at := base + side * (float(i) - float(count - 1) * 0.5) * CREW_SPAWN_SPACING
		var fitter = ctx.spawner.spawn_enemy("crew_fitter", at)
		if fitter == null:
			continue
		var slot_index := _free_slot(id)
		fitter.assign(id, _slot_at(id, hatch, slot_index), _plate_at(id, 0.0))
		var entry := {"node": fitter, "id": id, "counted": false, "slot": slot_index}
		_crew.append(entry)
		fitter.died.connect(func(_at: Vector3, _scrap: int): _uncount(entry))


func _free_slot(id: String) -> int:
	var held := []
	for c in _crew:
		if c["id"] == id and is_instance_valid(c["node"]):
			held.append(int(c["slot"]))
	var k := 0
	while held.has(k):
		k += 1
	return k


func _slot_at(_id: String, hatch: Vector3, k: int) -> Vector3:
	var in_way := Vector3(_center.x - hatch.x, 0.0, _center.z - hatch.z).normalized()
	var side := Vector3.UP.cross(in_way)
	return hatch + in_way * (CREW_SLOT_INSET + float(k / 3) * CREW_SLOT_INSET) + side * (float(k % 3) - 1.0) * CREW_SLOT_SPACING


func _step_crew() -> void:
	var kept: Array = []
	for c in _crew:
		var f = c["node"]
		if not is_instance_valid(f):
			_uncount(c)
			continue
		var id: String = c["id"]
		if f.is_dead():
			_uncount(c)
			continue
		if weak.state(id) != WeakPoints.OPEN or not part_reachable(id):
			_uncount(c)
			f.retire()
			continue
		if f.fit_state == f.State.INBOUND and f.arrived():
			f.start_fit()
			weak.begin_fit(id, clock)
			c["counted"] = true
		f.seal_progress = weak.fit_progress(id, clock)
		kept.append(c)
	_crew = kept


func _note_weak() -> void:
	for p in _weak_parts():
		var id: String = p["id"]
		var n: int = weak.fit_seals(id)
		var sealed: int = n - int(_seals_seen.get(id, 0))
		var opened_in: int = int(_weak_open_phase.get(id, phase))
		for i in sealed:
			weak_sealed.append({"id": id, "phase": opened_in, "at": clock})
			_tally("sealed", opened_in)
		_seals_seen[id] = n
		var now: int = weak.state(id)
		if int(_weak_last.get(id, WeakPoints.SHUT)) == WeakPoints.OPEN and now != WeakPoints.OPEN:
			if now == WeakPoints.BROKEN:
				_tally("broken", opened_in)
			elif sealed <= 0:
				_tally("timed_out", opened_in)
		if now != WeakPoints.OPEN:
			_weak_open_phase.erase(id)
		_weak_last[id] = now
	weak_open_at_end.clear()
	for id in _weak_open_phase:
		if weak.state(id) == WeakPoints.OPEN:
			var key := str(_weak_open_phase[id])
			weak_open_at_end[key] = int(weak_open_at_end.get(key, 0)) + 1


func _tally(key: String, at_phase := -1) -> void:
	var by_phase: Dictionary = weak_stats[key]
	var k := str(at_phase if at_phase >= 0 else phase)
	by_phase[k] = int(by_phase.get(k, 0)) + 1


func _reset_weak_record() -> void:
	weak_sealed.clear()
	_seals_seen.clear()
	_weak_last.clear()
	_weak_open_phase.clear()
	for key in weak_stats:
		(weak_stats[key] as Dictionary).clear()


func _uncount(c: Dictionary) -> void:
	if c["counted"]:
		weak.knock_fit(c["id"])
		c["counted"] = false
		if weak.state(c["id"]) == WeakPoints.OPEN and weak_part(c["id"]) != null:
			_plate_knocked(c["id"])


func _crew_struck(f: Node3D, kind: String) -> void:
	for c in _crew:
		if c["node"] != f:
			continue
		if state != FIGHT or f.fit_state != f.State.FITTING or not kind in Rules.CONTACT_KINDS:
			return
		if not _is_reel_impact(f, kind):
			return
		_uncount(c)
		f.dislodge(f.global_position - ctx.player.ball_position())
		_discover("plate_drop", f.global_position)
		return


func _plate_at(id: String, clear: float) -> Vector3:
	var part = weak_part(id)
	if part == null:
		return _weak_position(id)
	return part.global_position - part.global_transform.basis.z * (WeakPart.SIZE.z * 0.5 + clear)


func _fitting_count(id: String) -> int:
	var n := 0
	for c in _crew:
		if c["id"] == id and c["counted"] and is_instance_valid(c["node"]) and c["node"].fit_state == c["node"].State.FITTING:
			n += 1
	return n


func _step_plates(delta: float) -> void:
	for id in _plates.keys():
		if weak.state(id) != WeakPoints.OPEN or weak_part(id) == null:
			_free_plate(id)
	for id in _plate_latch.keys():
		if weak.state(id) != WeakPoints.OPEN:
			_plate_latch.erase(id)
	for c in _crew:
		var id: String = c["id"]
		var f = c["node"]
		if not is_instance_valid(f) or f.fit_state != f.State.FITTING or weak.state(id) != WeakPoints.OPEN:
			continue
		if _fitting_count(id) >= weak.fit_min:
			_plate_latch.erase(id)
		var part = weak_part(id)
		if _plate_latch.has(id) or part == null:
			continue
		if not _plates.has(id):
			var made := WeakPart.make_plate()
			made.name = "SeamPlate_%s" % id
			ctx.root.add_child(made)
			_plates[id] = made
		var node: Node3D = _plates[id]
		node.global_transform = Transform3D(part.global_transform.basis,
				_plate_at(id, lerpf(PLATE_HELD_CLEAR, PLATE_FITTED_CLEAR, f.seal_progress)))
	var rest: Array = []
	for fall in _fallen:
		var node: Node3D = fall["node"]
		if not is_instance_valid(node):
			continue
		if fall["fall_left"] > 0.0:
			fall["fall_left"] = float(fall["fall_left"]) - delta
			var p := node.global_position
			var ground := ground_height_at(p)
			p.y -= PLATE_FALL_SPEED * delta
			if is_finite(ground) and p.y <= ground + 0.1:
				p.y = ground + 0.1
				fall["fall_left"] = 0.0
			node.global_position = p
			if fall["fall_left"] <= 0.0:
				node.rotation.x += PLATE_REST_TILT
		rest.append(fall)
	_fallen = rest


func _plate_knocked(id: String) -> void:
	if _fitting_count(id) >= weak.fit_min:
		return
	_plate_latch[id] = true
	var node = _plates.get(id)
	_plates.erase(id)
	if node == null or not is_instance_valid(node):
		return
	_fallen = _fallen.filter(func(fall):
		var keep: bool = fall["id"] != id
		if not keep and is_instance_valid(fall["node"]):
			fall["node"].queue_free()
		return keep)
	_fallen.append({"node": node, "id": id, "fall_left": PLATE_FALL_SECONDS})


func _free_plate(id: String) -> void:
	var node = _plates.get(id)
	if node != null and is_instance_valid(node):
		node.queue_free()
	_plates.erase(id)


func _step_seal_cue(delta: float) -> void:
	var progress := -1.0
	for c in _crew:
		var id: String = c["id"]
		if is_instance_valid(c["node"]) and c["node"].fit_state == c["node"].State.FITTING \
				and _fitting_count(id) >= weak.fit_min and weak.state(id) == WeakPoints.OPEN:
			progress = maxf(progress, float(c["node"].seal_progress))
	if progress < 0.0:
		_seal_cue_left = 0.0
		return
	_seal_cue_left -= delta
	if _seal_cue_left > 0.0:
		return
	_seal_cue_left = lerpf(SEAL_GAP_SLOW, SEAL_GAP_FAST, progress)
	var pitch := lerpf(SEAL_PITCH_LOW, SEAL_PITCH_HIGH, progress)
	seal_cue_log.append([progress, pitch])
	var presentation = ctx.root.get("presentation") if ctx != null and ctx.root != null else null
	var audio = presentation.audio if presentation != null else null
	if audio != null:
		audio.play(SEAL_CUE_KIND, -6.0, pitch, "SFX", SEAL_SOUND)


func _retire_crew() -> void:
	for c in _crew:
		if is_instance_valid(c["node"]):
			_uncount(c)
			c["node"].retire()
	_crew.clear()
	for id in _plates.keys():
		_free_plate(id)
	for fall in _fallen:
		if is_instance_valid(fall["node"]):
			fall["node"].queue_free()
	_fallen.clear()
	_plate_latch.clear()
	_seal_cue_left = 0.0
	seal_cue_log.clear()
	_crew_waves = 0
	_crew_phase = 0


func _free_parts() -> void:
	_retire_crew()
	super()
