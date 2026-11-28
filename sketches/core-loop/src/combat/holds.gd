extends Node3D

const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Groups := preload("res://src/core/groups.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")

signal released(source_id: int, kind: String, reason: String)

const TENACITY_HOLD := 1.8
const TENACITY_WINDOW := 4.0
const TENACITY_IMMUNE := 2.5
const PLAYER_BREAKS := ["jump", "boost", "smash", "glide", "speed", "ultimate", "hook"]
const BREAK_KICK := 4.0
const SNAP_KICK := 7.0
const BREAK_REFUND := 0.6
const BINDING_WIDTH := 0.12
const BRACKET_RADIUS := 2.1
const FLICKER_HZ := 9.0
const DRAW_PRIORITY := 43
const BOUNDED := ["mag_pit", "winch_pull"]
const TURN_RATE := PI / 3.0
const HEADING_SPEED := 1.0

var ctx
var player
var active := {}
var immune_left := 0.0
var catches := 0
var breaks_by_player := 0
var tenacity_grants := 0
var ignored := 0
var last_release := {}

var _clock := 0.0
var _granted := Vector3.ZERO
var _granted_frame := -1
var _samples: Array = []
var _lines: MeshInstance3D
var _bracket: MeshInstance3D
var _bracket_material: StandardMaterial3D


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	player = ctx.player
	name = "Holds"
	top_level = true
	var events = ctx.events
	events.jumped.connect(func(_air: bool): _player_action("jump"))
	events.vault_kicked.connect(func(_at: Vector3, _speed: float): _player_action("jump"))
	events.boosted.connect(func(_dir: Vector3): _player_action("boost"))
	events.dashed.connect(func(_dir: Vector3): _player_action("boost"))
	events.blink_used.connect(func(_from: Vector3, _to: Vector3): _player_action("boost"))
	events.sprint_started.connect(func(_dir: Vector3): _player_action("boost"))
	events.slammed.connect(func(_at: Vector3, _strength: float, _flatness: float): _player_action("smash"))
	events.grapple_fired.connect(_on_grapple_fired)
	events.stage_entered.connect(func(_stage: int, _retry: bool): clear())
	events.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		break_all("ultimate"))
	events.stage_content_cleared.connect(func(_reason: String): clear())
	_lines = MeshInstance3D.new()
	_lines.mesh = ImmediateMesh.new()
	var line_material := PaletteMaterials.unshaded(Palette.HAZARD)
	line_material.no_depth_test = true
	line_material.render_priority = DRAW_PRIORITY
	_lines.material_override = line_material
	add_child(_lines)
	_bracket = MeshInstance3D.new()
	_bracket.mesh = ImmediateMesh.new()
	_bracket_material = PaletteMaterials.unshaded(Palette.ARC)
	_bracket_material.no_depth_test = true
	_bracket_material.render_priority = DRAW_PRIORITY
	_bracket.material_override = _bracket_material
	_bracket.visible = false
	add_child(_bracket)


func immune() -> bool:
	return immune_left > 0.0


func held(source: Node) -> bool:
	return source != null and active.has(source.get_instance_id())


func holding() -> bool:
	return not active.is_empty()


func held_kinds() -> Array:
	return active.values().map(func(h): return h["kind"])


func accumulated() -> float:
	var total := 0.0
	for sample in _samples:
		if _clock - float(sample[0]) <= TENACITY_WINDOW:
			total += float(sample[1])
	return total


func catch(source: Node3D, kind: String, breaks: Array, max_seconds := 0.0, shove := Vector3.ZERO, anchor = null) -> bool:
	if source == null or immune():
		return false
	if player.has_method("in_set_piece") and player.in_set_piece():
		ignored += 1
		return false
	var id := source.get_instance_id()
	if active.has(id):
		return true
	if kind in BOUNDED:
		shove = _bounded(shove)
	if not player.crowd_control(kind, shove, true):
		ignored += 1
		return false
	active[id] = {"kind": kind, "source": weakref(source), "breaks": breaks.duplicate(), "since": _clock,
		"left": max_seconds, "anchor": anchor}
	catches += 1
	player.cut_line()
	ctx.events.hold_started.emit(kind, player.ball_position())
	return true


func pull(source: Node3D, accel: Vector3) -> bool:
	if not held(source):
		return false
	var hold: Dictionary = active[source.get_instance_id()]
	if hold["kind"] in BOUNDED:
		accel = _bounded(accel)
	if not player.crowd_control(hold["kind"], accel, false):
		ignored += 1
		release(source, "ignored")
		return false
	return true


func _bounded(accel: Vector3) -> Vector3:
	var frame := Engine.get_physics_frames()
	if frame != _granted_frame:
		_granted_frame = frame
		_granted = Vector3.ZERO
	var out := bound(player.planar_velocity(), accel, _granted)
	_granted += out
	return out


static func bound(velocity: Vector3, accel: Vector3, granted := Vector3.ZERO) -> Vector3:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed < HEADING_SPEED:
		return accel
	var heading := flat / speed
	var planar := Vector3(accel.x, 0.0, accel.z)
	var along := maxf(0.0, planar.dot(heading))
	var across := planar - heading * planar.dot(heading)
	var limit := speed * TURN_RATE
	var gplanar := Vector3(granted.x, 0.0, granted.z)
	var gacross := gplanar - heading * gplanar.dot(heading)
	var total := across + gacross
	if total.length() > limit:
		across = total.normalized() * limit - gacross
	return heading * along + across + Vector3(0.0, accel.y, 0.0)


func release(source: Node, reason: String) -> void:
	if source == null:
		return
	_release_id(source.get_instance_id(), reason)


func snap(source: Node3D, method: String) -> void:
	if held(source) and method in active[source.get_instance_id()]["breaks"]:
		_release_id(source.get_instance_id(), method)


func clear() -> void:
	for id in active.keys():
		_release_id(id, "cleared")
	_samples.clear()
	immune_left = 0.0


func break_all(method: String) -> void:
	for id in active.keys():
		_release_id(id, method)


func _player_action(method: String, line := Vector3.ZERO) -> void:
	for id in active.keys():
		if active.has(id) and method in active[id]["breaks"]:
			_release_id(id, method, line)


func _on_grapple_fired(anchor: Vector3) -> void:
	if active.is_empty():
		return
	var body = player.kit.anchor_body
	if body != null and is_instance_valid(body) and body.is_in_group(Groups.ENEMY):
		return
	_player_action("hook", anchor - player.ball_position())


func _release_id(id: int, reason: String, line := Vector3.ZERO) -> void:
	if not active.has(id):
		return
	var hold: Dictionary = active[id]
	active.erase(id)
	last_release = {"kind": hold["kind"], "reason": reason, "held": _clock - float(hold["since"])}
	if reason in PLAYER_BREAKS:
		breaks_by_player += 1
		_refund(SNAP_KICK if reason == "speed" or reason == "hook" else BREAK_KICK, line if reason == "hook" else Vector3.ZERO)
		ctx.events.hold_broken.emit(hold["kind"], reason)
	else:
		ctx.events.hold_ended.emit(hold["kind"], reason)
	released.emit(id, hold["kind"], reason)


func gift_refund() -> void:
	breaks_by_player += 1
	player.abilities.refund(AbilityState.MOVEMENT, BREAK_REFUND)


func _refund(kick: float, line := Vector3.ZERO) -> void:
	var dir: Vector3 = Vector3(line.x, 0.0, line.z)
	if dir.length() < 0.1:
		dir = player.planar_velocity()
	if dir.length() < 0.5:
		dir = ctx.heading()
		dir.y = 0.0
	var step := get_physics_process_delta_time()
	if step > 0.0 and dir.length() > 0.01:
		player.add_external_accel(dir.normalized() * kick / step)
	player.abilities.refund(AbilityState.MOVEMENT, BREAK_REFUND)


func _physics_process(delta: float) -> void:
	if ctx == null:
		return
	_clock += delta
	immune_left = maxf(0.0, immune_left - delta)
	_expire(delta)
	_state_breaks()
	if not active.is_empty():
		_samples.append([_clock, delta])
	while not _samples.is_empty() and _clock - float(_samples[0][0]) > TENACITY_WINDOW:
		_samples.pop_front()
	if not active.is_empty() and accumulated() >= TENACITY_HOLD:
		_grant_tenacity()


func _state_breaks() -> void:
	if active.is_empty():
		return
	if player.kit.gliding:
		_player_action("glide")
	if player.kit.slamming:
		_player_action("smash")


func _expire(delta: float) -> void:
	for id in active.keys():
		var hold: Dictionary = active[id]
		var source = hold["source"].get_ref()
		if DamageDoor.dead(source):
			_release_id(id, "source_gone")
			continue
		if float(hold["left"]) > 0.0:
			hold["left"] = float(hold["left"]) - delta
			if float(hold["left"]) <= 0.0:
				_release_id(id, "expired")


func _grant_tenacity() -> void:
	for id in active.keys():
		_release_id(id, "tenacity")
	_samples.clear()
	immune_left = TENACITY_IMMUNE
	tenacity_grants += 1
	ctx.events.tenacity_gained.emit(TENACITY_IMMUNE)


func _process(_delta: float) -> void:
	if player == null:
		return
	var ball: Vector3 = player.shown_position()
	var mesh: ImmediateMesh = _lines.mesh
	mesh.clear_surfaces()
	var drew := false
	for hold in active.values():
		var source = hold["source"].get_ref()
		if source == null or not is_instance_valid(source):
			continue
		var from: Vector3 = hold["anchor"] if hold["anchor"] is Vector3 else source.global_position
		if not drew:
			mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			drew = true
		_stripes(mesh, from, ball)
	if drew:
		mesh.surface_end()
	_draw_bracket(ball)


static func _stripes(mesh: ImmediateMesh, from: Vector3, to: Vector3) -> void:
	var span := to - from
	var length := span.length()
	if length < 0.1:
		return
	var step := span / length
	var t := 0.0
	while t < length:
		var a := from + step * t
		var b := from + step * minf(t + 0.5, length)
		for lift in [0.0, BINDING_WIDTH]:
			mesh.surface_add_vertex(a + Vector3.UP * lift)
			mesh.surface_add_vertex(b + Vector3.UP * lift)
		t += 0.9


func _draw_bracket(ball: Vector3) -> void:
	var on := immune() and FlashGuard.blink(fmod(_clock * FLICKER_HZ, 1.0) < 0.7)
	_bracket.visible = on
	if not on:
		return
	_bracket_material.albedo_color = EventKinds.role_color("neutral")
	var mesh: ImmediateMesh = _bracket.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for corner in 4:
		var mid := PI * 0.25 + PI * 0.5 * corner
		for i in 4:
			var a0 := mid - 0.35 + 0.175 * i
			var a1 := a0 + 0.175
			mesh.surface_add_vertex(ball + Vector3(cos(a0), 0.2, sin(a0)) * BRACKET_RADIUS)
			mesh.surface_add_vertex(ball + Vector3(cos(a1), 0.2, sin(a1)) * BRACKET_RADIUS)
	mesh.surface_end()
