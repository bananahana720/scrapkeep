extends "res://src/boss/stub_boss.gd"

const MonsterHeft := preload("res://src/combat/monster_heft.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const ArenaMindDress := preload("res://src/presentation/arena_mind_dress.gd")
const AllyHusk := preload("res://src/combat/ally_husk.gd")

# The Mind's fight on the stub's flat pad. Its Warden is a MIND choir Warden with the
# fleet, so the Warden publishes its own posture and opens its lens on a stagger, bracing
# against the ball's top habit. The Mind has four phases, one per posture chunk. After
# Rules.INTRO_SECONDS it commits one of mind_attacks.gd's telegraphed families every
# ATTACK_PERIOD, more families as chunks fall; the last chunk opens with the plate. From
# phase 2 it sends up to HAND_CAP mind_hand roster enemies off the ball's side.
# Every attack is announced on boss_attack_telegraphed and leaves an escape point; an
# attack lands at most once.
const BOSS_ID := "mind"
const ATTACK_PERIOD := 3.5
const ATTACK_DAMAGE := 10.0
const HAND_CAP := 2
# Seal hp of each lens seat: start value; the step 2 sweep owns it.
const SEAL_HP := 60.0
# What the first and second broken seats remove; the third removes nothing (#241 6332176012 option (a)).
const SEAT_REMOVES := ["split_lane", "rush"]
# Seconds each phase lasts before a chunk lost in it opens the next (Brindle's PHASE_MIN_SECONDS); the
# last entry is unused. DECISIONS:178 (50 to 90 s through pattern, not by cutting the build); Expert ordinary 8-seed sweeps on
# scratch/challenge-tune-btC-1/-2.
const PHASE_MIN_SECONDS := [22.0, 22.0, 22.0, 22.0]
const HAND_PHASE := 2
# How far off the ball's side a hand lands, and how far inside the pad edge it stays.
const HAND_OFFSET := 10.0
const HAND_EDGE := 4.0
# Dial 1: a contact within this flat distance of an open lens seat counts on the seat. It is the Warden's own contact
# reach (Warden.FAMILY_REACH, which contact_part measures from the point above the body) measured from the seat, which
# sits CHOIR_RADIUS off the axis: a ball touching the body beside the seat (centre about 3.8 out) is inside it for
# about 55 degrees either side of the seat, and a ball on the far side of the body is not.
const SEAT_REACH := Warden.FAMILY_REACH
const TAKEOVER_COOLDOWN := 9.0
const TAKEOVER_RANGE := 42.0
const TAKEOVER_POSTURE_BONUS := 18.0

# Committed attacks: [{hazards, family, landed, aimed}], oldest first; aimed is whether the
# ball stood inside the attack when it committed.
var attacks: Array = []
# Every attack that landed: [{id, frame}].
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
# Challenge dial mind.combo: follow-up attacks still owed after the lead; -1 when none is open.
var _combo_left := -1
var _family := ""
var _plate_verb := ""
# The last plate's descriptor (its verb and hit_mult_floor), for the dial-1 brace.
var _plate_desc := {}
# Dial 1: hand instance id to its button slot (hand_<slot> in the rule), and whether it was braced last tick.
var _hand_slots := {}
var _hand_braced := {}
var _brace_due := false
# Fight clock until which the last plate's weak window stays open.
var _plate_until := -INF
# The crown and the seat's kit (mind_dress.gd); null keeps the stub body.
var _dress
var _arena_dress


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
	# The Mind is the stage 6 Warden: a monster build is heft above the library's top bucket at its own entrance, stage 6.
	spec["monster_heft"] = MonsterHeft.mind_threshold()
	# Dial 1: a contact pays the bar through the weak rule (a seat, or the chip), not through the row's contact gain.
	if _weak_wanted():
		var numbers: Dictionary = spec.get("posture", {}).duplicate()
		numbers["contact_gain_scale"] = 0.0
		spec["posture"] = numbers
	spec["fleet"] = ctx.spawner.fleet if ctx.spawner != null and "fleet" in ctx.spawner else null
	return spec


# Flow calls this on the script while stage 6's beacon, gates and launch run, before it makes the
# module, so the arena's dress is read and painted off the boss-entry frame.
static func prepare_arena() -> void:
	ArenaMindDress.prepare()
	MindDress.prepare()


# Flow calls this on teardown when it read the script ahead: waits for what prepare_arena started.
static func settle_arena() -> void:
	ArenaMindDress.settle()
	MindDress.settle()


# A step of the arena's main-thread work ahead of the entry, a frame at a time; true once done.
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
	_arena_dress = ArenaMindDress.attach(self)
	_dress = MindDress.attach(self)


func exit_arena() -> void:
	if is_instance_valid(_arena_dress):
		_arena_dress.release()
		_arena_dress.get_parent().remove_child(_arena_dress)
		_arena_dress.queue_free()
	_arena_dress = null
	# Out of the tree now, not at frame end, so it cannot dress the next fight's Warden.
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
	_step_husk_takeover(delta)
	_attack_clock -= delta
	if _attack_clock > 0.0:
		return
	_combo_left = ChallengeDials.combo_step("mind", _combo_left)
	if _combo_left > 0:
		_attack_clock = ChallengeDials.WARN_GAP
	else:
		_combo_left = -1
		_attack_clock = ChallengeDials.period("mind", ATTACK_PERIOD, phase)
	_commit_attack("plate" if _brace_due else "")
	_brace_due = false
	_send_hand()


# A punish window cancels owed follow-ups and pushes the attack clock back to the normal period,
# once: with none owed (combo 0, always) this changes nothing.
func _end_combo() -> void:
	if _combo_left > 0:
		_attack_clock = ChallengeDials.period("mind", ATTACK_PERIOD, phase)
	_combo_left = -1


# The Warden has the fleet and publishes its own posture; only a fleetless Warden needs
# the stub to do it.
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


# The lens seat whose bearing is nearest a plate's centre bearing: seat k sits at angle k * TAU / 3 around the Warden
# (warden.gd family_point_at), which reads as bearing -k * TAU / 3 in the attacks' (cos, sin of x, z) convention.
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
	# Each hand's button, one slot per hand the fight can field: breaking one takes that hand away for good.
	for k in HAND_CAP:
		parts.append({"id": "hand_%d" % k, "seal_hp": SEAL_HP, "removes": ""})
	return parts


# The seats' and the Warden's points; a hand's button is the hand's own, so the bot and the objective skip it.
func weak_open() -> Array:
	return super().filter(func(id): return not String(id).begins_with("hand_"))


# Seat k in the world (warden.gd family_point_at, which puts the lens on the seat that is open_lens now).
func seat_position(k: int) -> Vector3:
	var lens: Vector3 = warden.family_point_at()
	var ring := Vector3.RIGHT * Warden.CHOIR_RADIUS
	return lens - ring.rotated(Vector3.UP, warden.open_lens * TAU / 3.0) + ring.rotated(Vector3.UP, k * TAU / 3.0)


func _weak_position(id: String) -> Vector3:
	if id.begins_with("seat_") and is_instance_valid(warden):
		return seat_position(int(id.substr(5)))
	return super(id)


# A contact on the Warden counts on an open seat when the ball is within SEAT_REACH of it (flat); the nearest wins.
# Anything else, or a hit that is not a ball contact, is the body.
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


# The plate's brace: while its window stands, the verb it braced meets 1 / BRACE_MULT of a full hit on the seat.
func _brace_scale(kind: String) -> float:
	if _plate_desc.is_empty() or clock > _plate_until:
		return 1.0
	return MindAttacks.hit_mult(_plate_desc, kind)


# Hands that are alive, with a slot each; a hand that braces opens its button, once per brace.
func _step_hands() -> void:
	for hand in hands:
		if not is_instance_valid(hand) or hand.is_dead():
			continue
		var key: int = hand.get_instance_id()
		if not _hand_slots.has(key):
			continue
		var braced: bool = hand.braced()
		if braced and not bool(_hand_braced.get(key, false)):
			# The hand's own go-live already sounds weak_point_opened for its lens.
			_open_weak("hand_%d" % int(_hand_slots[key]), true)
		_hand_braced[key] = braced


# The hands the fight may field: HAND_CAP less one for every button a reel impact has broken.
func _hand_cap() -> int:
	var cap := HAND_CAP
	for k in HAND_CAP:
		cap -= 1 if weak.state("hand_%d" % k) == WeakPoints.BROKEN else 0
	return cap


# The first slot no live hand holds and no break has taken.
func _assign_slot(hand: Node3D) -> void:
	var held := []
	for other in hands:
		if other != hand and is_instance_valid(other):
			held.append(int(_hand_slots.get(other.get_instance_id(), -1)))
	for k in HAND_CAP:
		if weak.state("hand_%d" % k) != WeakPoints.BROKEN and not held.has(k):
			_hand_slots[hand.get_instance_id()] = k
			return


# A reel impact on a braced hand lands on its button (the lens): the rule judges it like a seat. A break takes the hand
# off the field through the normal boss-add death (enemy.gd take_damage -> _die -> died, which combat.gd's spawn_enemy
# handler books as a boss add) and, since its slot stays BROKEN, lowers _hand_cap for the rest of the fight.
func _hand_struck(hand: Node3D, kind: String, force: float) -> void:
	var key: int = hand.get_instance_id()
	var id := "hand_%d" % int(_hand_slots[key])
	if state != FIGHT or not hand.braced() or not kind in Rules.CONTACT_KINDS:
		return
	var frame := Engine.get_physics_frames()
	var smash: bool = ctx.player.smash_landing == hand
	var reel: bool = ctx.spawner.is_reel_impact(kind, smash) if ctx.spawner != null and ctx.spawner.has_method("is_reel_impact") \
			else smash or (ctx.player.kit.hooked and ctx.player.kit.winching)
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


# The first broken seat removes the first of SEAT_REMOVES, the second the next; further seats remove nothing.
func _removed_families() -> Array:
	var broken := 0
	for k in 3:
		broken += 1 if weak.state("seat_%d" % k) == WeakPoints.BROKEN else 0
	return SEAT_REMOVES.slice(0, mini(broken, SEAT_REMOVES.size()))


# family names one family to commit; empty lets the phase choose.
func _commit_attack(family := "") -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var center := pad.global_position if is_instance_valid(pad) else warden.global_position
	center.y = _top()
	attack_count += 1
	var seed: int = attack_count * 7919 + ctx.run.stage
	var safe := MindAttacks.commit_safe(family, seed, ball, center, phase, ctx.tuning.f("cruise"), PAD_RADIUS, _removed_families())
	var descriptors: Array = safe["descriptors"]
	if MindAttacks.FALLBACK_PATHS.has(safe["path"]):
		push_warning("mind: attack %d had no escape; fell back to %s" % [attack_count, safe["path"]])
	if descriptors.is_empty():
		return
	var laid: Array = []
	var aimed := false
	for d in descriptors:
		aimed = aimed or MindAttacks.covers(d, ball)
		var h = MindAttacks.build(d)
		h.ground = Callable(self, "ground_height_at")
		ctx.root.add_child(h)
		laid.append(h)
		_family = String(d["family"])
		if d.has("verb"):
			_plate_verb = String(d["verb"])
			_plate_desc = d
			_end_combo()  # the plate's weak window ends any combo
			_plate_until = clock + h.warn_seconds + h.live_seconds + ChallengeDials.punish("mind", MindAttacks.PLATE_WINDOW)
			_open_weak("seat_%d" % nearest_seat((float(d["from_angle"]) + float(d["to_angle"])) * 0.5))
		ctx.events.boss_attack_telegraphed.emit(String(d["id"]), h.warn_seconds)
	var ledger: Dictionary = ctx.run.get_meta("boss_attacks", {})
	ledger[_family] = int(ledger.get(_family, 0)) + 1
	ctx.run.set_meta("boss_attacks", ledger)
	attacks.append({"hazards": laid, "family": _family, "landed": false, "aimed": aimed})


# Ages every hazard like Brindle's loop; a live hazard holding the ball lands its attack
# once, and a finished attack is freed.
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


# A contact on the staggered Warden inside the plate's weak window, with a verb other than
# the one the plate braced.
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


func _clear_attacks() -> void:
	for attack in attacks:
		_free_hazards(attack)
	attacks.clear()


func _free_hazards(attack: Dictionary) -> void:
	for h in attack["hazards"]:
		if is_instance_valid(h):
			h.queue_free()


# From HAND_PHASE on, one hand per attack off the ball's side while fewer than HAND_CAP live.
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
