extends Node3D

const Augments := preload("res://src/movement/augments.gd")
const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# Called Shot (docs/design/loops.md Spec 3; Andrew approved the top three loops on 11 Nov 2026
# 18:42Z and asked for them before the sitting): call the finisher that breaks this Warden.
# Behind `--called-shot=on` (off by default). Owned by build.gd, which asks it one thing: the
# gate's rarities (gate_rarities), where the call is settled.
#
# - The window. For CALL_WINDOW_S after the Warden wakes, holding haul with no line out while the
#   camera looks at the Warden shows a stamp over it after CYCLE_S, and turns to the next every
#   CYCLE_S: DUNK, CHAIN, BOWL. Letting go calls the one showing; a tap shorter than CYCLE_S calls
#   nothing. One call a Warden.
# - The break. DUNK is met by a dunk spent on the Warden; CHAIN by a hit on it while the chain
#   stands at CHAIN_COMBO or more; BOWL by a ram at blazing or a flung body. A cause counts for
#   CAUSE_S, so the hit that breaks it and the cause it carries need not land in the same frame.
# - The pay. Met: both gate cards cobalt or better (no common rung). Missed: one of this stage's
#   bonus cores burns, so the gate drops a rung (assumption: with none held it costs nothing more;
#   the cobalt floor stays). No call: the game as it was.

const VERBS := ["DUNK", "CHAIN", "BOWL"]
const CALL_WINDOW_S := 4.0
const CYCLE_S := 0.5
const AIM_DOT := 0.8
const CHAIN_COMBO := 4
const CAUSE_S := 0.4
const STAMP_UP_M := 7.0

var ctx
var state := ""
var called := ""
var verdict := ""
var window_left := 0.0
var held_s := 0.0
var _clock := 0.0
var _causes := {}
var _stamp: Label3D
var _warden: Node3D

signal changed(state: String, call: String)


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "CalledShot"
	ctx.events.warden_engaged.connect(_on_engaged)
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool): clear())
	ctx.events.enemy_struck.connect(_on_struck)
	ctx.player.dunk.spent.connect(func(_record: Dictionary, enemy: Node3D): _note(enemy, "DUNK"))


func enabled() -> bool:
	return ctx != null and ctx.player != null and ctx.player.tuning.option("called_shot") == "on"


func clear() -> void:
	state = ""
	called = ""
	verdict = ""
	window_left = 0.0
	held_s = 0.0
	_causes.clear()
	_warden = null
	if _stamp != null:
		_stamp.queue_free()
	_stamp = null


# The verb a hold of `seconds` shows, or "" before the first CYCLE_S.
static func showing(seconds: float) -> String:
	if seconds < CYCLE_S:
		return ""
	return VERBS[int(floor(seconds / CYCLE_S) - 1.0) % VERBS.size()]


# The gate's rarities for this stage's cores, after the call is settled: a met call lifts both
# cards off the common rung; a missed one burns a core first. build.gd's gate roll asks this.
func gate_rarities() -> Array:
	settle()
	var rarities: Array = Parts.gate_rarities(ctx.run.gate_tier_bonus())
	if verdict != "met":
		return rarities
	var lifted: Array = rarities.filter(func(r): return r != "common")
	return lifted if not lifted.is_empty() else ["rare"]


# Judges the call once, at the gate: met when the call's cause touched the Warden in the last
# CAUSE_S before it broke.
func settle() -> void:
	if state != "called" or verdict != "":
		return
	var at := float(_causes.get(called, -INF))
	verdict = "met" if _clock - at <= CAUSE_S else "missed"
	state = "settled"
	var where: Vector3 = _stamp.global_position if _stamp != null else ctx.player.ball_position()
	if verdict == "missed":
		ctx.run.lose_core()
		ctx.events.world_fact.emit("call_missed", where)
		_crack_stamp()
	else:
		ctx.events.world_fact.emit("call_met", where)
		_slam_stamp()
	changed.emit(state, called)


func _on_engaged(_stage: int) -> void:
	if not enabled() or state != "":
		return
	_warden = ctx.flow.warden
	if not is_instance_valid(_warden):
		return
	state = "window"
	window_left = CALL_WINDOW_S
	held_s = 0.0
	ctx.events.world_fact.emit("call_window", _warden.global_position)
	changed.emit(state, called)


func _physics_process(delta: float) -> void:
	if ctx == null or state == "":
		return
	_clock += delta
	if state == "window":
		_step_window(delta)
	_follow()


func _step_window(delta: float) -> void:
	window_left -= delta
	var holding: bool = ctx.player.intent.brake_held and _line_free() and _aiming()
	if holding:
		held_s += delta
	elif held_s > 0.0:
		_release()
		return
	_show(showing(held_s), false)
	if window_left <= 0.0 and held_s <= 0.0:
		state = "closed"
		_show("", false)
		changed.emit(state, called)


# Letting go in the window calls what shows; a held stamp at the window's end still calls on release.
func _release() -> void:
	var verb := showing(held_s)
	held_s = 0.0
	if verb == "":
		_show("", false)
		return
	called = verb
	state = "called"
	_show(called, true)
	ctx.events.world_fact.emit("shot_called", _stamp.global_position)
	changed.emit(state, called)


func _line_free() -> bool:
	var kit = ctx.player.kit
	return not kit.hooked and kit.line_state == Augments.LINE_IDLE


func _aiming() -> bool:
	if not is_instance_valid(_warden) or ctx.camera == null:
		return is_instance_valid(_warden)
	# On the ground plane: the chase lens looks down at the ball, so its pitch is not the aim.
	var to: Vector3 = _warden.global_position - ctx.aim_origin()
	var look: Vector3 = ctx.aim_forward()
	var to_flat := Vector2(to.x, to.z)
	var look_flat := Vector2(look.x, look.z)
	return to_flat.length() > 0.01 and look_flat.length() > 0.01 and to_flat.normalized().dot(look_flat.normalized()) >= AIM_DOT


func _on_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if state != "called" or enemy != _warden:
		return
	if ctx.player.chain.combo >= CHAIN_COMBO:
		_note(enemy, "CHAIN")
	if kind == "flail" or (kind == "ram" and int(ctx.player.state.tier) >= SpeedTier.BLAZING):
		_note(enemy, "BOWL")


func _note(enemy: Node3D, verb: String) -> void:
	if state == "called" and enemy == _warden:
		_causes[verb] = _clock


# --- The stamp over the Warden ------------------------------------------------------------

func _show(verb: String, inked: bool) -> void:
	if verb == "":
		if _stamp != null:
			_stamp.visible = false
		return
	if _stamp == null:
		_stamp = Label3D.new()
		_stamp.name = "CalledStamp"
		_stamp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_stamp.shaded = false
		_stamp.no_depth_test = true
		_stamp.font_size = 128
		_stamp.outline_size = 36
		_stamp.pixel_size = 0.012
		_stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_stamp)
		_follow()
	_stamp.visible = true
	_stamp.text = verb
	# An outline while it turns; ink once called.
	_stamp.modulate = Palette.HAZARD if inked else Color(1.0, 1.0, 1.0, 0.0)
	_stamp.outline_modulate = Color(0.08, 0.08, 0.08, 1.0) if inked else Color(1.0, 1.0, 1.0, 0.9)


func _follow() -> void:
	if _stamp != null and is_instance_valid(_warden):
		_stamp.global_position = _warden.global_position + Vector3.UP * STAMP_UP_M


func _slam_stamp() -> void:
	if _stamp == null:
		return
	_stamp.text = "CALLED"
	_stamp.modulate = Palette.BRASS
	_stamp.scale = Vector3.ONE * 1.6
	create_tween().tween_property(_stamp, "scale", Vector3.ONE, 0.18)


func _crack_stamp() -> void:
	if _stamp == null:
		return
	var tween := create_tween()
	tween.tween_property(_stamp, "rotation:z", 0.5, 0.25)
	tween.parallel().tween_property(_stamp, "global_position:y", _stamp.global_position.y - 6.0, 0.6)
	tween.tween_callback(func(): if _stamp != null: _stamp.visible = false)
