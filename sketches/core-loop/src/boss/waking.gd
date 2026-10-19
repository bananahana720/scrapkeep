extends "res://src/boss/stub_boss.gd"

const Worlds := preload("res://src/core/worlds.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const WakingFloors := preload("res://src/boss/waking_floors.gd")
const WakingDress := preload("res://src/boss/waking_dress.gd")
const ArenaWakingDress := preload("res://src/presentation/arena_waking_dress.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const FloorRule := preload("res://src/combat/floor_rule.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The Waking's module: the stub's posture Warden, fought floor by floor. Three floors stand
# stacked above the stub's pad, which is the pit; each shattered chunk telegraphs the highest
# live floor and drops it FLOOR_WARN seconds later, so the fight sinks a tier per phase and the
# last chunk, fought in the pit, is the win. waking_floors.gd owns the rule; this file owns
# the bodies, the drop timing and the Warden's seat.
#
# The Waking's own attacks (waking_attacks.gd): after Rules.INTRO_SECONDS it commits one
# telegraphed Dig family every ATTACK_PERIOD (PIT_PERIOD in the pit), and each floor adds
# one: burrow lanes on the Spoil, cave-ins on the Seam, bore breaches from Bedrock. Every
# family is a floor threat and lands once, only on a ball FloorRule calls on the floor. Each
# floor and the pit carry a rim bank steep enough to carve, the safe lane. A bore jams the
# drill for BORE_JAM seconds, and a ball that left a carve LIP_WINDOW ago or less is a lip
# drop; either cuts the Warden's plating (EXPOSED_SCALE, LIP_SCALE, both multiply). Every
# warning this fight makes, floor drops included, starts at least GAP after the last.
const BOSS_ID := "waking"
# Floor k carries FLOOR_NAMES[k - 1], top down. Phases are capped at Rules.PHASE_NAMES.size().
const FLOOR_NAMES := ["Spoil", "Seam", "Bedrock"]
# Seconds between a floor's telegraph and its drop.
const FLOOR_WARN := 1.0
# A slam on the Warden this soon after a floor drops is a breach slam.
const BREACH_WINDOW := 2.0
const ATTACK_PERIOD := 3.4
const PIT_PERIOD := 2.6
const GAP := WakingAttacks.GAP
# The rim bank: a quarter pipe from BANK_IN to a vertical wall at the floor's edge.
const BANK_IN := 30.0
const BANK_RISE := PAD_RADIUS - BANK_IN
const BANK_PROFILE_STEPS := 8
const BANK_SEGMENTS := 48
const BANK_COLOR := Color(0.56, 0.50, 0.40)
const BORE_JAM := 3.0
const EXPOSED_SCALE := 0.5
const LIP_WINDOW := 1.5
const LIP_SCALE := 0.6
# A new floor opens on its teaching attack this soon after the drop, so every floor shows its
# family even to a pilot who shatters the next chunk inside one period.
const LANDING_ATTACK := 1.2
# The Warden's posture gains, scaled so the first stagger lands in the 45 to 70 s band
# (Andrew, 19:42Z 17 Oct). Before the attacks, bots staggered it at 23 to 36 s.
const POSTURE_GAIN := 0.565
const FAMILY_NAMES := {"burrow": "burrow lane", "cave_in": "cave-in", "bore": "bore breach"}

var floors: WakingFloors
# Floor number to its body, while the body stands.
var _floor_bodies := {}
var _center := Vector3.ZERO
# Floors queued to drop, highest first, and the one being telegraphed now.
var _drops: Array[int] = []
var _queued := 0
var _dropping := 0
var _drop_left := 0.0
# Fight clock at the last floor drop, and the floors a breach slam landed on.
var _dropped_at := -INF
var _breach_floors := {}
# The hanging architecture and the seat's kit (waking_dress.gd); null keeps the stub body.
var _dress
var _arena_dress
# Committed attacks: [{hazards, family, landed, descs}]; laid hazards age, and pending
# descriptors wait for their warning slot: [{desc, at, attack}].
var attacks: Array = []
var landings: Array = []
var attack_count := 0
var phase := 1
var _pending: Array = []
var _attack_clock := 0.0
# Challenge dial waking.combo: follow-up attacks still owed after the lead; -1 when none is open.
var _combo_left := -1
var _family := ""
# Fight clock of the last warning this fight started, for the GAP rule.
var _last_warn := -INF
# Every warning this fight started: [{id, at}], at on the fight clock.
var warnings: Array = []
var _taught := {}
var _jammed_until := -INF
var _carved_at := -INF
var _base_plating := 0.0
# Families ridden out while carving, for the Wall Is Home find.
var _banked := {}
var _pulse_charging := false
# A beat's cue waits for a free warning slot (the GAP rule), and is dropped if the beat ends first.
var _beat_announce := false


func setup(ctx_ref) -> void:
	super(ctx_ref)
	name = "WakingBoss"
	ctx.events.enemy_struck.connect(_on_enemy_struck)


func enter_arena(entry_velocity: Vector3) -> void:
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
	_attack_clock = 0.0
	_combo_left = -1
	_dress = WakingDress.attach(self)
	_arena_dress = ArenaWakingDress.attach(self)


func exit_arena() -> void:
	if is_instance_valid(_arena_dress):
		_arena_dress.release_lights()
		remove_child(_arena_dress)
		_arena_dress.queue_free()
	_arena_dress = null
	# Out of the tree now, not at frame end, so it cannot dress the next fight's Warden.
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
	_banked.clear()
	_pulse_charging = false
	_beat_announce = false
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if not active() or not is_instance_valid(warden) or floors == null:
		return
	floors.on_posture(warden.chunks_left())
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
			_dropping = 0
			_seat_warden()
			_dropped_at = clock
			_discover(CodexEntries.WAKING_FLOOR_DROP, ctx.player.ball_position())
			# The floor the attacks were drawn on is gone: they go with it, and the new
			# floor opens on a full period.
			_clear_attacks()
			_attack_clock = LANDING_ATTACK
			_combo_left = -1
	if _beat_announce:
		if not warden.beat_immune():
			_beat_announce = false
		elif _warn_open():
			# The cue counts as a warning slot for spacing but is not an attack: it never reaches
			# boss_attack_telegraphed or the warnings ledger.
			_last_warn = clock
			_beat_announce = false
			ctx.events.boss_beat.emit(BOSS_ID, warden.beat_left)
	phase = clampi(floors.shattered + 1, 1, WakingAttacks.PIT_PHASE)
	_read_pulse()
	_read_ball()
	_step_attacks(delta)
	_lay_pending()
	_set_plating()
	if clock < Rules.INTRO_SECONDS or _dropping != 0 or not _drops.is_empty():
		return
	_attack_clock -= delta
	if _attack_clock > 0.0:
		return
	# A combo follow-up is queued GAP after the lead; the _warn_open() gap still spaces every warning.
	_combo_left = ChallengeDials.combo_step("waking", _combo_left)
	if _combo_left > 0:
		_attack_clock = GAP
	else:
		_combo_left = -1
		_attack_clock = ChallengeDials.period("waking", PIT_PERIOD if phase >= WakingAttacks.PIT_PHASE else ATTACK_PERIOD, phase)
	_commit_attack()


# A punish window cancels owed follow-ups and pushes the attack clock back to the normal period,
# once: with none owed (combo 0, always) this changes nothing.
func _end_combo() -> void:
	if _combo_left > 0:
		_attack_clock = ChallengeDials.period("waking", PIT_PERIOD if phase >= WakingAttacks.PIT_PHASE else ATTACK_PERIOD, phase)
	_combo_left = -1


# A warning may start now: none started in the last GAP seconds, and the Warden's own pulse
# ring is not due within GAP (warden.gd commits it PULSE_TELEGRAPH before each PULSE_CYCLE).
func _warn_open() -> bool:
	return clock - _last_warn >= GAP - 0.0001 and not _pulse_due()


func _pulse_due() -> bool:
	if not is_instance_valid(warden) or warden.staggered() or warden.state_name() == "charging":
		return false
	# A charge a driver holds back past its due time stops holding warnings after GAP more.
	var due: float = Warden.pulse_cycle(warden.stage) - Warden.pulse_telegraph(warden.stage)
	return warden._pulse_clock >= due - GAP and warden._pulse_clock < due + GAP and warden.flat_to_ball().length() <= warden.reach


# The Warden's pulse ring is a warning too: its start holds the next one off for GAP.
func _read_pulse() -> void:
	var charging: bool = is_instance_valid(warden) and warden.state_name() == "charging"
	if charging and not _pulse_charging:
		_last_warn = clock
		warnings.append({"id": "warden_pulse", "at": clock})
	_pulse_charging = charging


func _beat_plan() -> Array:
	return [ChallengeDials.beat(BOSS_ID, 1), ChallengeDials.beat(BOSS_ID, 2), ChallengeDials.beat(BOSS_ID, 3)]


func _on_beat_started(_seconds: float) -> void:
	_beat_announce = true


func _warned(id: String, seconds: float) -> void:
	_last_warn = clock
	warnings.append({"id": id, "at": clock})
	ctx.events.boss_attack_telegraphed.emit(id, seconds)


# family names one family to commit; empty teaches the floor's new family first, then
# picks among the floor's families.
func _commit_attack(family := "") -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var center := Vector3(_center.x, _top(), _center.z)
	attack_count += 1
	var seed: int = attack_count * 7919 + ctx.run.stage
	if family == "":
		family = WakingAttacks.newest(phase)
		if _taught.has(phase):
			family = WakingAttacks.choose(seed, phase)
		_taught[phase] = true
	var safe := WakingAttacks.commit_safe(family, seed, ball, ctx.player.body().linear_velocity, center, phase, ctx.tuning.f("cruise"),
			PAD_RADIUS)
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


# Lays the oldest due descriptor when a warning slot is open; one warning per slot.
func _lay_pending() -> void:
	if _pending.is_empty() or _dropping != 0 or _pending[0]["at"] > clock + 0.0001 or not _warn_open():
		return
	var item: Dictionary = _pending.pop_front()
	var d: Dictionary = item["desc"]
	var h = MindAttacks.build(d)
	h.ground = Callable(self, "ground_height_at")
	ctx.root.add_child(h)
	(item["attack"]["hazards"] as Array).append(h)
	_warned(String(d["id"]), h.warn_seconds)


# Ages every laid hazard; a live one lands its attack once on a ball on the floor. A ball
# carving through a live region counts toward the Wall Is Home find.
func _step_attacks(delta: float) -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var state = ctx.player.state
	var on_floor := FloorRule.on_floor(state)
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
				if on_floor and not carving and not attack["landed"]:
					attack["landed"] = true
					landings.append({"id": h.attack_id, "frame": Engine.get_physics_frames()})
					ctx.run.damage(ChallengeDials.damage("waking", float(WakingAttacks.DAMAGE[attack["family"]]), phase), "waking_%s" % attack["family"])
				elif carving:
					_bank_ride(attack["family"], ball)
			if h.is_live() and attack["family"] == "bore" and h.attack_id.begins_with("waking_bore_0"):
				_end_combo()  # a punish window ends any combo
				_jammed_until = clock + (h.warn_seconds + h.live_seconds - h.age) + ChallengeDials.punish("waking", BORE_JAM)
			if not (h.is_done() and h.age >= h.warn_seconds + h.live_seconds + 0.5):
				done = false
		if done:
			_free_hazards(attack)
		else:
			kept.append(attack)
	attacks = kept


func _bank_ride(family: String, at: Vector3) -> void:
	_banked[family] = true
	if _banked.size() >= WakingAttacks.FAMILIES.size():
		_discover(CodexEntries.WAKING_WALL_HOME, at)


func _read_ball() -> void:
	if carving_now():
		_carved_at = clock


# The ball's own carving flag once wall grip (PR #61) lands. Until then, the same reading
# from what the ball already reports: grounded at the fast tier on a face steeper than the
# floor rule's floor, which on this arena is only the rim bank.
func carving_now() -> bool:
	var state = ctx.player.state
	if "carving" in state:
		return bool(state.carving)
	return state.grounded and state.tier >= SpeedTier.FAST and not FloorRule.on_floor(state)


func jammed() -> bool:
	return clock < _jammed_until


# A ball in the air that was carving LIP_WINDOW ago or less.
func lip_drop() -> bool:
	return not ctx.player.state.grounded and clock - _carved_at <= LIP_WINDOW


func plating_scale() -> float:
	return (EXPOSED_SCALE if jammed() else 1.0) * (LIP_SCALE if lip_drop() else 1.0)


func _set_plating() -> void:
	if _base_plating > 0.0:
		warden.plating = _base_plating * plating_scale()


func _clear_attacks() -> void:
	for attack in attacks:
		_free_hazards(attack)
	attacks.clear()
	_pending.clear()


func _free_hazards(attack: Dictionary) -> void:
	for h in attack["hazards"]:
		if is_instance_valid(h):
			h.queue_free()


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if state != FIGHT or enemy != warden or kind != "slam":
		return
	var at: Vector3 = ctx.player.ball_position()
	if jammed() and clock - _carved_at <= LIP_WINDOW:
		_discover(CodexEntries.WAKING_LIP_DROP, at)
	if clock - _dropped_at >= ChallengeDials.punish("waking", BREACH_WINDOW):
		return
	_end_combo()  # a punish window ends any combo
	_discover(CodexEntries.WAKING_BREACH_SLAM, at)
	_breach_floors[floors.current_floor()] = true
	if _breach_floors.size() >= 2:
		_discover(CodexEntries.WAKING_FLOOR_CHAIN, at)


# Every natural death is in the pit: the chunk before the last has already dropped the
# lowest floor (waking_floors.gd live()), so the final-floor row is the kill itself.
func _on_warden_died(at: Vector3, scrap: int) -> void:
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


# The rim bank on a floor body: a quarter pipe from BANK_IN at the floor's top, curving to
# a vertical wall BANK_RISE high at the floor's edge, so a fast ball can carve round it.
# It is on the body itself, so it goes when the floor drops. A lower floor's bank sits
# behind the face of the one above (same profile, lower), so it is hidden until then.
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
			for v in [lo0, hi1, hi0, lo0, lo1, hi1]:
				faces.append(v)
				surface.add_vertex(v)
	var shape := CollisionShape3D.new()
	shape.name = "RimBank"
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.set_faces(faces)
	trimesh.backface_collision = true
	shape.shape = trimesh
	body.add_child(shape)
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = BANK_COLOR
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


# The highest standing floor's top, else the pit's. floor_y and rescue_point follow it.
func _top() -> float:
	if not is_instance_valid(pad):
		return -INF
	for k in range(1, floors.floor_count() + 1 if floors != null else 1):
		if _floor_bodies.has(k):
			return _center.y + floors.floor_height(k)
	return super()


func ground_height_at(point: Vector3) -> float:
	if is_instance_valid(pad) and Vector2(point.x - _center.x, point.z - _center.z).length() > PAD_RADIUS:
		return super._top()
	return super(point)


func _row() -> Dictionary:
	return Worlds.BOSSES[BOSS_ID]


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
	spec["posture"] = numbers
	return spec


func music_state() -> Dictionary:
	var state := super()
	if not state.is_empty():
		state["id"] = String(_row().get("music", BOSS_ID))
		# Bedrock and the pit share the top phase: the final act, where the hype version plays.
		state["phase"] = clampi(floors.shattered + 1, 1, Rules.PHASE_NAMES.size())
	return state


func objective_text() -> String:
	if state == FIGHT and floors != null:
		var text := "%s, %s" % [String(_row().get("name", "The Waking")), floors.objective()]
		if is_instance_valid(warden) and warden.beat_immune():
			text += ". It's bracing: wait"
		elif jammed():
			text += ". Its drill is jammed: hit it now"
		elif _family != "":
			text += ". Incoming: %s" % FAMILY_NAMES.get(_family, _family)
		return text
	return super()
