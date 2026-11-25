extends Node3D

const EventKinds := preload("res://src/core/event_kinds.gd")
const Augments := preload("res://src/movement/augments.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")


const MIN_PX := 5.0
const REF_HEIGHT := 1080.0
const SLACK_RADIUS := 0.09
const TAUT_RADIUS := 0.14
const TAUT_LIGHTEN := 0.4
const SLACK_DIM := 0.35
const SEGMENTS := 20
const MAX_SAG := 3.0
const SAG_PER_SLACK := 0.3
const TAUT_MARGIN := 0.4

const LOCK_CLOSE := 0.1
const LOCK_FROM_SCALE := 1.8
const BRACKET_BASE := 0.9
const BRACKET_PER_METRE := 0.015
const BRACKET_TICK := 0.45
const POLE_RING := 0.7
const HOOK_DROP := 1.15
const HOOK_SIZE := 0.5
const MARK_PX := 3.0
const PULSE_HZ := 2.0
const PULSE_DEPTH := 0.14

const FAIRLEAD_RADIUS := 1.06
const FAIRLEAD_TURN_RATE := 15.0
const ANCHOR_JUMP := 2.0
const COLLAR_MIN := 0.9
const COLLAR_MAX := 3.2
const COLLAR_PER_METRE := 0.07
const POST_RING := 1.1
const RING_CAP := 6
const RING_STEP := 0.22
const BARB_SIZE := 0.55

const CLAMP_HALF := 0.35
const CLAMP_RADIUS := 0.3
const CABLE_RADIUS := 0.18

const DRY_DART := 8.0
const DRY_TIME := 0.25
const DRY_REACH_AT := 0.08
const DRY_SAG := 1.6
const LET_GO_TIME := 0.15
const BROKE_TIME := 0.3
const SMASH_FLASH := 0.12
const POP_TIME := 0.1

var player
var camera: Camera3D
var events

var cable: MeshInstance3D
var cable_taut := false
var cable_radius := SLACK_RADIUS
var cable_origin := Vector3.ZERO
var _fairlead_yaw := 0.0
var hanger: MeshInstance3D
var hanger_from := Vector3.ZERO
var hanger_to := Vector3.ZERO
var _hanger_yaw := 0.0
var _hanger_was_on := false
var hanger_fresh := false
var _ride
var _hanger_material: StandardMaterial3D
var _was_hooked := false
var _last_anchor := Vector3.ZERO
var brackets: MeshInstance3D
var lock_scale := 1.0
var barb: MeshInstance3D
var collar: MeshInstance3D
var collar_radius := 0.0
var collar_scale := 1.0
var collar_rings := 0
var post_ring: MeshInstance3D
var pop: MeshInstance3D

var _clock := 0.0
var _state := "searching"
var _lock_age := 0.0
var _lock_target: Node3D
var _smash_age := 0.0
var _dry_age := -1.0
var _dry_dir := Vector3.FORWARD
var _let_go_age := -1.0
var _broke_age := -1.0
var _gone_anchor := Vector3.ZERO
var _pop_age := -1.0
var _pop_at := Vector3.ZERO
var _cable_material: StandardMaterial3D
var _bracket_material: StandardMaterial3D
var _collar_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _barb_material: StandardMaterial3D
var _pop_material: StandardMaterial3D


func setup(player_ref, camera_ref: Camera3D, events_ref) -> void:
	player = player_ref
	camera = camera_ref
	events = events_ref
	name = "LineView"
	_cable_material = _material()
	cable = _node("Cable", _cable_material)
	_bracket_material = _material(true)
	brackets = _node("LockBrackets", _bracket_material)
	_ring_material = _material(true)
	post_ring = _node("PostRing", _ring_material)
	_pop_material = _material(true)
	pop = _node("SmashPop", _pop_material)
	_hanger_material = _material()
	hanger = _node("Hanger", _hanger_material)
	events.line_state_changed.connect(_on_line_state)


func _node(label: String, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = ImmediateMesh.new()
	node.material_override = material
	node.visible = false
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 4096.0
	add_child(node)
	return node


static func _material(over := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = over
	if over:
		mat.render_priority = 10
	return mat


func _process(delta: float) -> void:
	step(delta)


static func fairlead_yaw(yaw: float, centre: Vector3, anchor: Vector3, delta: float) -> float:
	var flat := Vector2(anchor.x - centre.x, anchor.z - centre.z)
	if flat.length_squared() < 0.0001:
		return yaw
	var gap := wrapf(atan2(-flat.x, -flat.y) - yaw, -PI, PI)
	var most := FAIRLEAD_TURN_RATE * delta
	return wrapf(yaw + clampf(gap, -most, most), -PI, PI)


static func fairlead_point(centre: Vector3, yaw: float, bank := Basis.IDENTITY) -> Vector3:
	return centre + bank * (Vector3(-sin(yaw), 0.0, -cos(yaw)) * FAIRLEAD_RADIUS)


func step(delta: float) -> void:
	if player == null or camera == null:
		return
	_clock += delta
	var kit = player.kit
	var ball: Vector3 = player.shown_position()
	_advance(delta)
	var smash: bool = kit.hooked and kit.line_state == Augments.LINE_SMASH
	_smash_age = _smash_age + delta if smash else 0.0
	_draw_cable(kit, ball, smash, delta)
	_draw_lock(kit)
	_draw_latch(kit, ball)
	_draw_pop()
	_draw_hanger(ball, delta)


func _advance(delta: float) -> void:
	if _dry_age >= 0.0:
		_dry_age += delta
		if _dry_age >= DRY_TIME:
			_dry_age = -1.0
	if _let_go_age >= 0.0:
		_let_go_age += delta
		if _let_go_age >= LET_GO_TIME:
			_let_go_age = -1.0
	if _broke_age >= 0.0:
		_broke_age += delta
		if _broke_age >= BROKE_TIME:
			_broke_age = -1.0
	if _pop_age >= 0.0:
		_pop_age += delta
		if _pop_age >= POP_TIME:
			_pop_age = -1.0
	if _state == "locked":
		_lock_age += delta


func _on_line_state(state: String, target: Node3D, at: Vector3, _cause: String) -> void:
	if state.begins_with("chain_"):
		if state == "chain_link":
			_set_rings(player.chain.links)
		elif state == "chain_end":
			_set_rings(0)
		return
	if state == "locked" and (_state != "locked" or target != _lock_target):
		_lock_age = 0.0
	if state == "locked":
		_lock_target = target
	_state = state
	match state:
		"dry_fire":
			_dry_age = 0.0
			_dry_dir = _aim_direction(at)
		"let_go":
			_let_go_age = 0.0
			_gone_anchor = at
		"broke":
			_broke_age = 0.0
			_gone_anchor = at
		"smash_lands":
			_pop_age = 0.0
			_pop_at = at


func _set_rings(links: int) -> void:
	collar_rings = mini(links, RING_CAP) if links >= 2 else 0


func _aim_direction(from: Vector3) -> Vector3:
	var aim: Dictionary = player.kit.aim
	if aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE:
		var to: Vector3 = (aim["point"] as Vector3) - from
		if to.length() > 0.1:
			return to.normalized()
	return -camera.global_basis.z


func motion_factor(state: String) -> float:
	if String(EventKinds.line_row(state).get("motion", "none")) == "pulse":
		return 1.0 + PULSE_DEPTH * sin(TAU * PULSE_HZ * _clock)
	return 1.0


func half_width(radius: float, depth: float) -> float:
	return maxf(radius, MIN_PX * depth * 0.5 / focal_px())


func focal_px() -> float:
	return camera.get_camera_projection()[1][1] * REF_HEIGHT * 0.5


func projected_px(radius: float, depth: float) -> float:
	return half_width(radius, depth) * 2.0 * focal_px() / depth


func _draw_cable(kit, centre: Vector3, smash: bool, delta: float) -> void:
	var toward: Vector3 = kit.anchor if kit.hooked else (_gone_anchor if _broke_age >= 0.0 or _let_go_age >= 0.0 else centre + _dry_dir)
	var fresh: bool = not cable.visible or (kit.hooked and (not _was_hooked or kit.anchor.distance_to(_last_anchor) > ANCHOR_JUMP))
	_was_hooked = kit.hooked
	if kit.hooked:
		_last_anchor = kit.anchor
	_fairlead_yaw = fairlead_yaw(_fairlead_yaw, centre, toward, INF if fresh else delta)
	var ball := fairlead_point(centre, _fairlead_yaw, player.get_meta("carrier_bank", Basis.IDENTITY) if player != null else Basis.IDENTITY)
	cable_origin = ball
	var mesh: ImmediateMesh = cable.mesh
	mesh.clear_surfaces()
	var live := EventKinds.line_color("latched_world")
	if kit.hooked:
		_dry_age = -1.0
		_let_go_age = -1.0
		_broke_age = -1.0
		var gap: float = centre.distance_to(kit.anchor)
		var taut: bool = smash or kit.on_body or kit.winching or gap >= kit.rope - TAUT_MARGIN
		cable_taut = taut
		cable_radius = TAUT_RADIUS if taut else SLACK_RADIUS
		var color := live.lightened(TAUT_LIGHTEN) if taut else live.darkened(SLACK_DIM)
		if smash:
			color = EventKinds.line_color("smash_committed").lightened(FlashGuard.whiten(1.0 - clampf(_smash_age / SMASH_FLASH, 0.0, 1.0)))
		var sag: float = 0.0 if taut else minf(maxf(kit.rope - gap, 0.0) * SAG_PER_SLACK, MAX_SAG)
		_cable_material.albedo_color = color
		_ribbon(mesh, ball, kit.anchor, sag, cable_radius)
	elif _broke_age >= 0.0:
		var t := _broke_age / BROKE_TIME
		cable_radius = TAUT_RADIUS
		_cable_material.albedo_color = Color(EventKinds.line_color("broke"), 1.0 - t * 0.5)
		var mid := ball.lerp(_gone_anchor, 0.5)
		var near := ball.lerp(mid, 1.0 - t * 0.35)
		var far := _gone_anchor.lerp(mid, 1.0 - t * 0.35)
		_ribbon(mesh, ball, near, t * DRY_SAG, cable_radius)
		_ribbon(mesh, _gone_anchor, far, t * DRY_SAG, cable_radius)
	elif _let_go_age >= 0.0:
		var t := _let_go_age / LET_GO_TIME
		cable_radius = SLACK_RADIUS
		cable_taut = false
		_cable_material.albedo_color = live
		_ribbon(mesh, ball, _gone_anchor.lerp(ball, t), 0.0, cable_radius)
	elif _dry_age >= 0.0:
		var reach := DRY_DART * clampf(_dry_age / DRY_REACH_AT, 0.0, 1.0)
		var slack := clampf((_dry_age - DRY_REACH_AT) / (DRY_TIME - DRY_REACH_AT), 0.0, 1.0)
		cable_radius = SLACK_RADIUS
		cable_taut = false
		_cable_material.albedo_color = Color(EventKinds.line_color("dry_fire"), 1.0 - slack * 0.6)
		_ribbon(mesh, ball, ball + _dry_dir * reach, slack * DRY_SAG, cable_radius)
	cable.visible = mesh.get_surface_count() > 0


func _ribbon(mesh: ImmediateMesh, from: Vector3, to: Vector3, sag: float, radius: float) -> void:
	var eye := camera.global_position
	var points: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var f := float(i) / float(SEGMENTS)
		points.append(from.lerp(to, f) + Vector3.DOWN * sag * 4.0 * f * (1.0 - f))
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		var tangent := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		var side := tangent.cross(eye - points[i])
		side = side.normalized() if side.length_squared() > 0.000001 else camera.global_basis.x
		var half := half_width(radius, maxf(eye.distance_to(points[i]), 0.5))
		mesh.surface_add_vertex(points[i] + side * half)
		mesh.surface_add_vertex(points[i] - side * half)
	mesh.surface_end()


func set_ride(ride) -> void:
	_ride = ride


static func clamp_on_cable(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return a
	return a + ab * clampf((p - a).dot(ab) / len2, 0.0, 1.0)


func _draw_hanger(centre: Vector3, delta: float) -> void:
	var mesh: ImmediateMesh = hanger.mesh
	mesh.clear_surfaces()
	var on: bool = _ride != null and _ride.active and _ride.cable_from != _ride.cable_to
	var fresh := on and not _hanger_was_on
	hanger_fresh = fresh
	_hanger_was_on = on
	hanger.visible = on
	if not on:
		return
	var clamp_at := clamp_on_cable(_ride.cable_from, _ride.cable_to, centre)
	_hanger_yaw = fairlead_yaw(_hanger_yaw, centre, clamp_at, INF if fresh else delta)
	hanger_from = fairlead_point(centre, _hanger_yaw, player.get_meta("carrier_bank", Basis.IDENTITY) if player != null else Basis.IDENTITY)
	hanger_to = clamp_at
	_hanger_material.albedo_color = EventKinds.line_color("latched_world").lightened(TAUT_LIGHTEN)
	_ribbon(mesh, hanger_from, hanger_to, 0.0, TAUT_RADIUS)
	var along: Vector3 = (_ride.cable_to - _ride.cable_from).normalized() * CLAMP_HALF
	var grip := Vector3.DOWN * (CLAMP_RADIUS - CABLE_RADIUS)
	_ribbon(mesh, clamp_at - along + grip, clamp_at + along + grip, 0.0, CLAMP_RADIUS)


func _draw_lock(kit) -> void:
	var mesh: ImmediateMesh = brackets.mesh
	mesh.clear_surfaces()
	var locked: bool = _state == "locked" and not kit.hooked
	brackets.visible = locked
	if not locked:
		lock_scale = 1.0
		return
	var at: Vector3 = kit.aim.get("point", Vector3.ZERO)
	var closing := LOCK_FROM_SCALE - (LOCK_FROM_SCALE - 1.0) * clampf(_lock_age / LOCK_CLOSE, 0.0, 1.0)
	lock_scale = closing * motion_factor("locked")
	var depth := maxf(camera.global_position.distance_to(at), 0.5)
	var half := (BRACKET_BASE + depth * BRACKET_PER_METRE) * lock_scale
	_bracket_material.albedo_color = EventKinds.line_color("locked")
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var width := MARK_PX * depth / focal_px()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner in [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, -1.0)]:
		var tip: Vector3 = at + (right * corner.x + up * corner.y) * half
		var reach := half * BRACKET_TICK * 2.0
		_bar(mesh, tip, tip - right * corner.x * reach, up, width)
		_bar(mesh, tip, tip - up * corner.y * reach, right, width)
	if kit.aim.get("grip", "") == "flail":
		_hook_mark(mesh, at - up * half * HOOK_DROP, right, up, half * HOOK_SIZE, width)
	mesh.surface_end()
	if kit.aim.get("grip", "") == "pole":
		_circle(mesh, at, half * POLE_RING, camera.global_position)


func _hook_mark(mesh: ImmediateMesh, top: Vector3, right: Vector3, up: Vector3, size: float, width: float) -> void:
	var bottom := top - up * size
	_bar(mesh, top, bottom, right, width)
	_bar(mesh, bottom, bottom - right * size * 0.6, up, width)
	_bar(mesh, bottom - right * size * 0.6, bottom - right * size * 0.6 + up * size * 0.4, right, width)


func _draw_latch(kit, ball: Vector3) -> void:
	var on_body: bool = kit.hooked and kit.on_body
	var on_world: bool = kit.hooked and not kit.on_body
	if on_body:
		_seat_barb(kit, ball)
	else:
		_free_barb()
	post_ring.visible = on_world
	var ring: ImmediateMesh = post_ring.mesh
	ring.clear_surfaces()
	if on_world:
		_ring_material.albedo_color = EventKinds.line_color("latched_world")
		_circle(ring, kit.anchor, POST_RING * motion_factor("latched_world"), ball)


func _seat_barb(kit, ball: Vector3) -> void:
	if barb == null:
		_barb_material = _material(true)
		barb = _node("Barb", _barb_material)
		var box := BoxMesh.new()
		box.size = Vector3.ONE * BARB_SIZE
		barb.mesh = box
		barb.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
		_collar_material = _material(true)
		collar = _node("Collar", _collar_material)
	var color := EventKinds.line_color("latched_body")
	_barb_material.albedo_color = color
	_collar_material.albedo_color = color
	barb.visible = true
	barb.global_position = kit.anchor
	var gap: float = ball.distance_to(kit.anchor)
	collar_radius = clampf(COLLAR_MIN + gap * COLLAR_PER_METRE, COLLAR_MIN, COLLAR_MAX)
	collar_scale = motion_factor("latched_body")
	collar.visible = true
	var mesh: ImmediateMesh = collar.mesh
	mesh.clear_surfaces()
	_circle(mesh, kit.anchor, collar_radius * collar_scale, ball)
	for i in collar_rings:
		_circle(mesh, kit.anchor, collar_radius * collar_scale * (1.0 + RING_STEP * float(i + 1)), ball)


func _free_barb() -> void:
	if barb != null:
		barb.free()
		barb = null
	if collar != null:
		collar.free()
		collar = null
	collar_radius = 0.0
	collar_scale = 1.0


func _draw_pop() -> void:
	var mesh: ImmediateMesh = pop.mesh
	mesh.clear_surfaces()
	pop.visible = _pop_age >= 0.0
	if _pop_age < 0.0:
		return
	var t := _pop_age / POP_TIME
	_pop_material.albedo_color = Color(EventKinds.line_color("smash_lands"), 1.0 - t)
	_circle(mesh, _pop_at, COLLAR_MIN * (1.0 + t * 2.0), camera.global_position)


func _circle(mesh: ImmediateMesh, centre: Vector3, radius: float, toward: Vector3) -> void:
	var axis := (toward - centre).normalized()
	if axis.length_squared() < 0.5:
		axis = Vector3.UP
	var basis := Basis.looking_at(axis, Vector3.UP if absf(axis.y) < 0.99 else Vector3.RIGHT)
	var depth := maxf(camera.global_position.distance_to(centre), 0.5)
	var half := MARK_PX * depth * 0.5 / focal_px()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 33:
		var angle := TAU * float(i) / 32.0
		var out: Vector3 = basis * Vector3(cos(angle), sin(angle), 0.0)
		mesh.surface_add_vertex(centre + out * (radius + half))
		mesh.surface_add_vertex(centre + out * (radius - half))
	mesh.surface_end()


func _bar(mesh: ImmediateMesh, a: Vector3, b: Vector3, across: Vector3, width: float) -> void:
	var side := across * width * 0.5
	mesh.surface_add_vertex(a + side)
	mesh.surface_add_vertex(a - side)
	mesh.surface_add_vertex(b + side)
	mesh.surface_add_vertex(a - side)
	mesh.surface_add_vertex(b - side)
	mesh.surface_add_vertex(b + side)
