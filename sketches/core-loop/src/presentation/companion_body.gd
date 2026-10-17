extends Node3D

# SPIL-9's body in the world: the assembled chassis-plus-two-modules model, hovering beside
# the ball and following it. Visual only: no collision, no damage, no timers of its own.
# It reads the seated pieces from run.companion and plays each module's beat from state
# combat already commits (primed, prow_staggered, spring_armed); it never decides any of it.
# The escape piece wears a lamp read from combat.escape_phase(): lit while ready, a flare (vent)
# or a rail flick (rail) for the act's seconds with the escape_acted chirp, dimmed once spent.
# A missing model leaves a plain hull box so the companion is still seen, and warns once.
# SR7: every beat goes through cue(), which plays the clip and asks audio.chirp() for the
# sound from one Companion.CUES row, and state() reports the cue shown. With no leader (the
# run not alive) Companion.leash_step stalls it at the leader's last live spot; a respawn
# or a long stretch past the leash recalls it beside the ball.

const Companion := preload("res://src/core/companion.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# One GLB per ordered socket pair, named <socket 0>__<socket 1> in table order.
const MODEL_DIR := "res://assets/models/companion/assembled/"
# Root height: the belly floats 0.30 m over the floor and the hull is 0.21 m deep below it.
const HULL_LIFT := 0.51
const SIDE := 2.0
const BEHIND := 0.8
const FOLLOW_RATE := 8.0
const TURN_RATE := 6.0
const MOVING_SPEED := 1.0
# The escape lamp: radius, height over the hull root, emission per cue, and each act's shape.
const LAMP_RADIUS := 0.09
const LAMP_LIFT := 0.48
const LAMP_ENERGY := {"ready": 1.0, "flare": 4.0, "flick": 3.0, "spent": 0.12}
const LAMP_SCALE := {"ready": Vector3.ONE, "flare": Vector3.ONE * 1.8, "flick": Vector3(0.6, 0.6, 3.5), "spent": Vector3.ONE}
const ESCAPE_CUES := {"shove": "flare", "lane": "flick"}
# Renderer updates can outlive a retired mesh during a socket swap.
static var _painted_materials := {}
static var _warned_empty_mesh := false

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
var _lamp: MeshInstance3D
var _escape_cue := "none"
var _leash := {}
var _state := "idle"


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


# Imported enamel is white without COLOR. Keep private overrides so a tableau never
# repaints the cached GLB or a live companion's equipped cosmetic.
static func dress_model(model: Node) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			if not _warned_empty_mesh:
				_warned_empty_mesh = true
				push_warning("companion_body: empty mesh; skipping piece")
			continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null or original.resource_name != "paint" or original.vertex_color_use_as_albedo:
				continue
			if not _painted_materials.has(original):
				var painted := original.duplicate() as BaseMaterial3D
				painted.vertex_color_use_as_albedo = true
				_painted_materials[original] = painted
			mesh.set_surface_override_material(surface, _painted_materials[original])


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
	var lead := Companion.leash_step(_leash, delta, _leader_alive(), ctx.player.shown_position(), global_position)
	_leash = lead
	if lead["recall"]:
		_snap = true
	if lead["event"] != "":
		cue(lead["event"])
	if lead["state"] == "stalled":
		_hold(delta, lead["safe"])
		return
	_follow(delta)
	_escape_beat()
	_beats()


# The leader is the ball while the run is alive; a dead or finished run leaves none.
func _leader_alive() -> bool:
	var run = ctx.get("run")
	return run == null or not run.has_method("alive") or run.alive()


# Stalled: hover beside the leader's last live spot and wait there, idle.
func _hold(delta: float, safe: Vector3) -> void:
	var target := safe + _heading.cross(Vector3.UP).normalized() * SIDE
	target.y = safe.y - Tuning.RADIUS + HULL_LIFT
	if _snap:
		global_position = target
		_snap = false
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
	_moving = false
	_state = "stalled"
	if _anim != null and not _is_beat():
		_play("idle")


# The cue the body shows now: a CUES key while its beat is the latest, else idle, follow
# or stalled.
func state() -> String:
	return _state


# The one place a companion cue is shown: the clip and the chirp both read
# Companion.CUES[event], so the gesture, the sound and the motif cannot disagree.
func cue(event: String) -> void:
	var row: Dictionary = Companion.CUES.get(event, {})
	if row.is_empty():
		return
	_state = event
	_beat(String(row["clip"]))
	var audio = get_parent().get("audio") if get_parent() != null else null
	if audio != null and audio.has_method("chirp"):
		audio.chirp(event)


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
	_lamp = null
	_escape_cue = "none"
	_leash = {}
	_state = "idle"
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
		var hull := _fallback()
		add_child(hull)
		_add_lamp(hull, key)
		return
	dress_model(_model)
	add_child(_model)
	_add_lamp(_model, key)
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


# The lamp rides the model (or the plain hull) so the body keeps one child.
func _add_lamp(host: Node3D, key: String) -> void:
	if not key.contains("escape_"):
		return
	_lamp = MeshInstance3D.new()
	_lamp.name = "EscapeLamp"
	var ball := SphereMesh.new()
	ball.radius = LAMP_RADIUS
	ball.height = LAMP_RADIUS * 2.0
	_lamp.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	_lamp.material_override = mat
	_lamp.position = Vector3(0.0, LAMP_LIFT, 0.0)
	host.add_child(_lamp)
	_light("ready")


# The cue the escape lamp shows: none, ready, flare, flick or spent.
func escape_cue() -> String:
	return _escape_cue


func _light(lamp: String) -> void:
	_escape_cue = lamp
	var row: Dictionary = EventKinds.UI_ROWS["companion_spent" if lamp == "spent" else ("companion_ready" if lamp == "ready" else "escape_acted")]
	var mat := _lamp.material_override as StandardMaterial3D
	mat.albedo_color = row["color"].darkened(0.6) if lamp == "spent" else row["color"]
	mat.emission = row["color"]
	mat.emission_energy_multiplier = FlashGuard.spike(LAMP_ENERGY["ready"], LAMP_ENERGY[lamp]) if lamp != "spent" else LAMP_ENERGY[lamp]
	_lamp.scale = LAMP_SCALE[lamp]


func _escape_beat() -> void:
	if _lamp == null or combat == null or not combat.has_method("escape_phase"):
		return
	var phase: String = combat.escape_phase()
	var lamp := "ready" if phase == "ready" else ("spent" if phase == "spent" else String(ESCAPE_CUES.get(combat.escape_style(), "flare")))
	if lamp == _escape_cue:
		return
	if lamp == "flare" or lamp == "flick":
		cue("escape_acted")
	elif lamp == "ready" and _escape_cue == "spent":
		cue("escape_rearm")
	_light(lamp)


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
	if not _is_beat():
		_state = "follow" if _moving else "idle"
		if _anim != null:
			_play(_state)


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
			cue("primer_set")
		elif _primed and not any:
			var expired := true
			for id in _primed_ids:
				if not combat.primer_expired(id):
					expired = false
					break
			cue("primer_expire" if expired else "primer_consume")
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
			cue("prow_response")
	if key.contains("ram_spring"):
		var armed: bool = combat.spring_armed()
		if armed and not _armed:
			cue("spring_arm")
		elif _armed and not armed:
			cue("spring_spend")
		_armed = armed
