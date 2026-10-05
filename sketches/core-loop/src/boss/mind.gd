extends "res://src/boss/stub_boss.gd"

const Worlds := preload("res://src/core/worlds.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")

# The Mind's fight on the stub's flat pad. Its Warden is a MIND choir Warden with the
# fleet, so the Warden publishes its own posture and opens its lens on a stagger, bracing
# against the ball's top habit. After Rules.INTRO_SECONDS the Mind commits one of
# mind_attacks.gd's telegraphed families every ATTACK_PERIOD, more families as chunks
# fall; from phase 2 it sends up to HAND_CAP mind_hand roster enemies off the ball's side.
# Every attack is announced on boss_attack_telegraphed and leaves an escape point; an
# attack lands at most once.
const BOSS_ID := "mind"
const ATTACK_PERIOD := 3.5
const ATTACK_DAMAGE := 10.0
const HAND_CAP := 2
const HAND_PHASE := 2
# How far off the ball's side a hand lands, and how far inside the pad edge it stays.
const HAND_OFFSET := 10.0
const HAND_EDGE := 4.0

# Committed attacks: [{hazards, family, landed}], oldest first.
var attacks: Array = []
# Every attack that landed: [{id, frame}].
var landings: Array = []
var hands: Array = []
var phase := 1
var attack_count := 0
var _attack_clock := 0.0
var _family := ""
var _plate_verb := ""


func setup(ctx_ref) -> void:
	super(ctx_ref)
	name = "MindBoss"


func _row() -> Dictionary:
	return Worlds.BOSSES[BOSS_ID]


func _warden_spec() -> Dictionary:
	var spec := super()
	spec["family"] = Roster.MIND
	spec["variant"] = "choir"
	spec["fleet"] = ctx.spawner.fleet if ctx.spawner != null and "fleet" in ctx.spawner else null
	return spec


func enter_arena(entry_velocity: Vector3) -> void:
	super(entry_velocity)
	phase = 1
	_attack_clock = 0.0
	_family = ""
	_plate_verb = ""


func exit_arena() -> void:
	_clear_attacks()
	_free_hands()
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if not active() or not is_instance_valid(warden):
		return
	phase = clampi(1 + BossPosture.CHUNKS - warden.chunks_left(), 1, MindAttacks.phase_cap())
	_step_attacks(delta)
	if clock < Rules.INTRO_SECONDS:
		return
	_attack_clock -= delta
	if _attack_clock > 0.0:
		return
	_attack_clock = ATTACK_PERIOD
	_commit_attack()
	_send_hand()


# The Warden has the fleet and publishes its own posture; only a fleetless Warden needs
# the stub to do it.
func _publish_posture() -> void:
	if is_instance_valid(warden) and warden.fleet != null:
		return
	super()


func _on_warden_died(at: Vector3, scrap: int) -> void:
	_clear_attacks()
	_free_hands()
	super(at, scrap)


func _commit_attack() -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var center := pad.global_position if is_instance_valid(pad) else warden.global_position
	center.y = _top()
	attack_count += 1
	var descriptors: Array = MindAttacks.commit_any(attack_count * 7919 + ctx.run.stage, ball, center, phase, PAD_RADIUS)
	if MindAttacks.escape_point(descriptors, ball, ctx.tuning.f("cruise"), center, PAD_RADIUS) == null:
		push_warning("mind: attack %d leaves no escape point" % attack_count)
	var laid: Array = []
	for d in descriptors:
		var h = MindAttacks.build(d)
		h.ground = Callable(self, "ground_height_at")
		ctx.root.add_child(h)
		laid.append(h)
		_family = String(d["family"])
		if d.has("verb"):
			_plate_verb = String(d["verb"])
		ctx.events.boss_attack_telegraphed.emit(String(d["id"]), h.warn_seconds)
	attacks.append({"hazards": laid, "family": _family, "landed": false})


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
				ctx.run.damage(ATTACK_DAMAGE, "mind_%s" % attack["family"])
			if not (h.is_done() and h.age >= h.warn_seconds + h.live_seconds + 0.5):
				done = false
		if done:
			_free_hazards(attack)
		else:
			kept.append(attack)
	attacks = kept


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
		hands.append(hand)


func music_state() -> Dictionary:
	var state := super()
	if not state.is_empty():
		state["id"] = String(_row().get("music", BOSS_ID))
		state["phase"] = phase
	return state


func objective_text() -> String:
	if state != FIGHT or not is_instance_valid(warden):
		return super()
	var who := String(_row().get("name", "the boss"))
	if warden.staggered():
		var braced := "nothing" if warden.braced_kinds.is_empty() else "/".join(warden.braced_kinds)
		return "%s is staggered: hit its open lens. It braces against %s." % [who, braced]
	var text := "Fill %s's bar to stagger it. %d chunks left." % [who, warden.chunks_left()]
	if _family != "":
		text += " Incoming: %s." % _family.replace("_", " ")
	if _family == "plate" and _plate_verb != "":
		text += " Its plate braces %s." % _plate_verb
	return text
