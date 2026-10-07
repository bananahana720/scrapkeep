extends Node3D

# SPIL-9's body in the world: the assembled chassis-plus-two-modules model, hovering beside
# the ball and following it. Visual only: no collision, no damage, no timers of its own.
# It reads the seated pieces from run.companion and plays each module's beat from state
# combat already commits (primed, prow_staggered, spring_armed); it never decides any of it.
# The escape pieces sit on the chassis with no cue (ruling P-R7: no escape-window visual).
# A missing model leaves a plain hull box so the companion is still seen, and warns once.

const Companion := preload("res://src/core/companion.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# One GLB per ordered socket pair, named <socket 0>__<socket 1> in table order.
const MODEL_DIR := "res://assets/models/companion/assembled/"
# Root height: the belly floats 0.30 m over the floor and the hull is 0.21 m deep below it.
const HULL_LIFT := 0.51
const SIDE := 2.0
const BEHIND := 0.8
const FOLLOW_RATE := 8.0
const TURN_RATE := 6.0
const MOVING_SPEED := 1.0

var ctx
var model_dir := MODEL_DIR
# Combat's read-only state; tests may stand a fake in.
var combat

var _key := ""
var _model: Node3D
var _anim: AnimationPlayer
var _heading := Vector3.FORWARD
var _snap := true
var _moving := false
var _primed := false
var _primed_ids := {}
var _primed_next := {}
var _staggered := {}
var _staggered_next := {}
var _armed := false
var _warned := false


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "CompanionBody"
	top_level = true
	visible = false
	combat = ctx.get("spawner")


# The model path for a socket pair, "" when the pair is not two ids.
static func model_path(sockets: Array, dir := MODEL_DIR) -> String:
	if sockets.size() != Companion.SOCKETS:
		return ""
	return dir + "%s__%s.glb" % [sockets[0], sockets[1]]


# Capture hook (tools/asset_capture.gd --call): seats two owned pieces into the run's
# companion so a staged run shows the body. Returns "" or the refusal reason.
func seat_for_capture(a: String, b: String) -> String:
	var model := Companion.new()
	model.acquire(a)
	model.acquire(b)
	var refusal := model.assemble([a, b])
	if refusal == "":
		ctx.run.companion = model.to_dict()
	return refusal


func is_real() -> bool:
	return _model != null


func _seats() -> Array:
	var run = ctx.get("run") if ctx != null else null
	if run == null:
		return []
	var doc: Dictionary = run.companion
	var found: Array = []
	var sockets_v = doc.get("sockets")
	if typeof(sockets_v) == TYPE_ARRAY:
		for id in sockets_v:
			if typeof(id) == TYPE_STRING and Companion.family_of(id) != "":
				found.append(id)
	return found if found.size() == Companion.SOCKETS else []


func _process(delta: float) -> void:
	if ctx == null or ctx.player == null:
		return
	var seats := _seats()
	var key := "" if seats.is_empty() else "%s__%s" % [seats[0], seats[1]]
	if key != _key:
		_rebuild(seats, key)
	if key == "":
		return
	_follow(delta)
	_beats()


func _rebuild(seats: Array, key: String) -> void:
	_key = key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_model = null
	_anim = null
	_staggered.clear()
	_primed = false
	_primed_ids.clear()
	_armed = false
	visible = key != ""
	_snap = true
	if key == "":
		return
	var path := model_path(seats, model_dir)
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed != null:
		_model = packed.instantiate() as Node3D
	if _model == null:
		if not _warned:
			_warned = true
			push_warning("companion_body: model '%s' unavailable; keeping the plain hull" % path)
		add_child(_fallback())
		return
	add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	_play("idle")


func _fallback() -> Node3D:
	var hull := MeshInstance3D.new()
	hull.name = "CompanionHullFallback"
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 0.42, 0.72)
	hull.mesh = box
	for x in [-0.29, 0.29]:
		var module := MeshInstance3D.new()
		var stub := BoxMesh.new()
		stub.size = Vector3(0.2, 0.3, 0.2)
		module.mesh = stub
		module.position = Vector3(x, 0.38, 0.0)
		hull.add_child(module)
	return hull


func _follow(delta: float) -> void:
	var player = ctx.player
	var velocity: Vector3 = player.planar_velocity()
	_moving = velocity.length() > MOVING_SPEED
	if _moving:
		var want := velocity.normalized()
		var blended := _heading.lerp(want, 1.0 - exp(-TURN_RATE * delta))
		if blended.length() > 0.01:
			_heading = blended.normalized()
	var ball: Vector3 = player.shown_position()
	var right := _heading.cross(Vector3.UP).normalized()
	var target := ball - _heading * BEHIND + right * SIDE
	target.y = ball.y - Tuning.RADIUS + HULL_LIFT
	if _snap:
		global_position = target
		_snap = false
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
	global_basis = Basis.looking_at(_heading, Vector3.UP)
	if _anim != null and not _is_beat():
		_play("follow" if _moving else "idle")


func _is_beat() -> bool:
	if _anim == null:
		return false
	var current := String(_anim.current_animation)
	return _anim.is_playing() and current != "idle" and current != "follow"


func _play(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation == clip and _anim.is_playing():
		return
	_anim.play(clip)


# A one-shot beat; the next frame's idle or follow resumes when it ends.
func _beat(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip)


func _beats() -> void:
	if combat == null or _anim == null:
		return
	var key := _key
	var enemies := get_tree().get_nodes_in_group("enemy")
	if key.contains("primer_"):
		var any := false
		var live := _primed_next
		live.clear()
		for enemy in enemies:
			if combat.primed(enemy):
				any = true
				live[enemy.get_instance_id()] = true
		if any and not _primed:
			_beat("primer_set")
		elif _primed and not any:
			var expired := true
			for id in _primed_ids:
				if not combat.primer_expired(id):
					expired = false
					break
			_beat("primer_expire" if expired else "primer_consume")
		_primed = any
		_primed_next = _primed_ids
		_primed_ids = live
	if key.contains("ram_prow"):
		var fresh := false
		var live := _staggered_next
		live.clear()
		for enemy in enemies:
			if combat.prow_staggered(enemy):
				var id: int = enemy.get_instance_id()
				live[id] = true
				if not _staggered.has(id):
					fresh = true
		_staggered_next = _staggered
		_staggered = live
		if fresh:
			_beat("prow_response")
	if key.contains("ram_spring"):
		var armed: bool = combat.spring_armed()
		if armed and not _armed:
			_beat("spring_arm")
		elif _armed and not armed:
			_beat("spring_spend")
		_armed = armed
