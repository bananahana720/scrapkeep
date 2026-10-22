extends "res://src/boss/stub_boss.gd"

const MonsterHeft := preload("res://src/combat/monster_heft.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const ArenaMindDress := preload("res://src/presentation/arena_mind_dress.gd")

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
# Seconds each phase lasts before a chunk lost in it opens the next (Brindle's PHASE_MIN_SECONDS); the
# last entry is unused. DECISIONS:178 (50 to 90 s through pattern, not by cutting the build); Expert ordinary 8-seed sweeps scratch/challenge-tune-btT-1/-2 (66699e63, 08b0923b).
const PHASE_MIN_SECONDS := [22.0, 22.0, 22.0, 22.0]
const HAND_PHASE := 2
# How far off the ball's side a hand lands, and how far inside the pad edge it stays.
const HAND_OFFSET := 10.0
const HAND_EDGE := 4.0

# Committed attacks: [{hazards, family, landed, aimed}], oldest first; aimed is whether the
# ball stood inside the attack when it committed.
var attacks: Array = []
# Every attack that landed: [{id, frame}].
var landings: Array = []
var hands: Array = []
var phase := 1
var attack_count := 0
var _attack_clock := 0.0
# Challenge dial mind.combo: follow-up attacks still owed after the lead; -1 when none is open.
var _combo_left := -1
var _family := ""
var _plate_verb := ""
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
	spec["fleet"] = ctx.spawner.fleet if ctx.spawner != null and "fleet" in ctx.spawner else null
	return spec


func enter_arena(entry_velocity: Vector3) -> void:
	super(entry_velocity)
	phase = 1
	_attack_clock = 0.0
	_combo_left = -1
	_family = ""
	_plate_verb = ""
	_brace_due = false
	_plate_until = -INF
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
	for hand in hands:
		if is_instance_valid(hand):
			hand.boss_phase = phase
	_step_attacks(delta)
	if clock < Rules.INTRO_SECONDS:
		return
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


# family names one family to commit; empty lets the phase choose.
func _commit_attack(family := "") -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var center := pad.global_position if is_instance_valid(pad) else warden.global_position
	center.y = _top()
	attack_count += 1
	var seed: int = attack_count * 7919 + ctx.run.stage
	var safe := MindAttacks.commit_safe(family, seed, ball, center, phase, ctx.tuning.f("cruise"), PAD_RADIUS)
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
			_end_combo()  # the plate's weak window ends any combo
			_plate_until = clock + h.warn_seconds + h.live_seconds + ChallengeDials.punish("mind", MindAttacks.PLATE_WINDOW)
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
func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if state != FIGHT or enemy != warden or not warden.staggered() or clock > _plate_until:
		return
	if kind in Rules.CONTACT_KINDS and kind != _plate_verb:
		_discover(CodexEntries.MIND_PLATE, ctx.player.ball_position())


func _free_hands() -> void:
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
	if phase < HAND_PHASE or hands.size() >= HAND_CAP or ctx.spawner == null or not ctx.spawner.has_method("spawn_enemy"):
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


func music_state() -> Dictionary:
	var state := super()
	if not state.is_empty():
		state["id"] = String(_row().get("music", BOSS_ID))
		state["phase"] = phase
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
	if hold_capped():
		return "%s's bar is full. It breaks in %d s: keep the pressure on." % [who, ceili(hold_left())]
	var text := "Fill %s's bar to stagger it. %d chunks left." % [who, shown_chunks_left()]
	if _family != "":
		text += " Incoming: %s." % _family.replace("_", " ")
	if _family == "plate" and _plate_verb != "":
		text += " Its plate braces %s." % _plate_verb
	return text
