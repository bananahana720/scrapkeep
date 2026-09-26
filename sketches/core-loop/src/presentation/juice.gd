extends Node

const Tuning := preload("res://src/movement/tuning.gd")

# Feel: squash and stretch, camera punches and kicks, hit-stop and the pylon's plant
# and eject. Every effect answers something the player did, reads the committed fact
# off the bus and never decides an outcome (TADR-008). Punches are short and the
# camera never leaves the ball, so juice never hides the next threat.

# Hit-stop: 30-50 ms, only when a hit breaks through plating (plating > 0 and punch at
# or above it) and when a Warden breaks (beacon_unsealed), at least 0.4 s apart. Never
# on a crush, a plating-0 kill or a deflected hit: the Katamari roll-up never stalls.
# The spine caps a stop at 60 ms and refuses to stack.
const HIT_STOP_MIN := 0.03
const HIT_STOP_MAX := 0.05
const HIT_STOP_GAP_MS := 400
const BREAK_STOP := 0.04
const UNSEAL_STOP := 0.05
# Fallback until combat publishes plating: big contact hits by strike kind.
const BIG_HIT := {"ram": 20.0, "stomp": 12.0, "slam": 14.0}
const HIT_STOP_FOR := {"ram": 0.04, "stomp": 0.035, "slam": 0.045}
# The shell grows a tenth per heft class above I (visual only; the collider never
# changes), and springs there with a little overshoot.
const SHELL_PER_CLASS := 0.1
const SHELL_RATE := 9.0

# The squash spring: underdamped, so a landing squashes, overshoots into a stretch and
# settles in about a quarter second. Snappy on the hit, fluid on the way out.
const SPRING := 420.0
const DAMPING := 17.0
const MAX_SQUASH := 0.45

var ctx
var player
var camera
# [hook, fact] for every camera or time effect fired, for the tests and the notes.
var hook_log: Array = []
# [requested_seconds, sent_seconds or 0 when gated, fact, msec] for every hit-stop asked for.
var hit_stop_log: Array = []
# Swap for a recorder in tests; defaults to the spine's ctx.hit_stop.
var hit_stop_sink: Callable
# Reads an enemy's plating. Defaults to ctx.spawner.plating_of when combat has it;
# tests inject one. Empty means the fallback thresholds apply.
var plating_of: Callable
var shell := 1.0

var _squash := 0.0
var _squash_velocity := 0.0
var _axis := Vector3.UP
var _last_stop_ms := -100000
var _plant_t := -1.0
var _pylon_parts := {}
var _pylon_transform := Transform3D.IDENTITY
var _ghosts: Array = []
var _strikes: Array = []
var _deflected := {}
var _resolve_queued := false
var _shell_velocity := 0.0
var _heft_class := 1


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Juice"
	player = ctx.player
	camera = ctx.camera
	player.builtin_squash = false
	hit_stop_sink = ctx.hit_stop
	var events = ctx.events
	events.landed.connect(_on_landed)
	events.slammed.connect(_on_slammed)
	events.jumped.connect(_on_jumped)
	events.dashed.connect(_on_dashed)
	events.boosted.connect(_on_boosted)
	events.launched.connect(_on_launched)
	events.mounted.connect(_on_mounted)
	events.dismounted.connect(_on_dismounted)
	events.enemy_struck.connect(_on_enemy_struck)
	events.stage_entered.connect(func(_stage: int, _retry: bool): _reset())
	events.run_started.connect(func(_class_id: String): _heft_class = 1)
	if ctx.spawner != null and ctx.spawner.has_method("plating_of"):
		plating_of = Callable(ctx.spawner, "plating_of")
	wire_optional()


func wire_optional() -> void:
	var events = ctx.events
	if events.has_signal("strike_deflected") and not events.is_connected("strike_deflected", _on_deflected):
		events.connect("strike_deflected", _on_deflected)
	if events.has_signal("beacon_unsealed") and not events.is_connected("beacon_unsealed", _on_unsealed):
		events.connect("beacon_unsealed", _on_unsealed)
	if events.has_signal("heft_class_changed") and not events.is_connected("heft_class_changed", _on_heft_class):
		events.connect("heft_class_changed", _on_heft_class)
	if events.has_signal("heft_class_dropped") and not events.is_connected("heft_class_dropped", _on_heft_class):
		events.connect("heft_class_dropped", _on_heft_class)
	if events.has_signal("boss_weak_point_hit") and not events.is_connected("boss_weak_point_hit", _on_weak_point):
		events.connect("boss_weak_point_hit", _on_weak_point)


func _reset() -> void:
	# A retry restores mass, so the shell follows the restored class.
	if ctx.run.has_method("heft_class"):
		_heft_class = int(ctx.run.heft_class())
	_squash = 0.0
	_squash_velocity = 0.0
	_plant_t = -1.0
	for ghost in _ghosts:
		if is_instance_valid(ghost["node"]):
			ghost["node"].queue_free()
	_ghosts.clear()


# --- Squash and stretch -------------------------------------------------------------

func squash(amount: float, axis: Vector3) -> void:
	_squash = clampf(amount, -MAX_SQUASH, MAX_SQUASH)
	_squash_velocity = 0.0
	if axis.length_squared() > 0.01:
		_axis = axis.normalized()


func _on_landed(impact: float) -> void:
	squash(clampf(impact / 26.0, 0.0, 0.42), player.state.contact_normal)
	if impact > 18.0:
		_camera("kick", "landed", Vector3.DOWN, impact * 0.012)


func _on_jumped(air: bool) -> void:
	squash(-0.22 if air else -0.28, Vector3.UP)


func _on_slammed(_at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05:
		return
	squash(0.3 + 0.2 * minf(strength, 1.0), player.state.contact_normal)
	_camera("kick", "slammed", Vector3.DOWN, 0.35 + 0.35 * minf(strength, 1.5))
	# A zoom-in thump: the world leans toward the impact for a beat.
	_camera("punch_fov", "slammed", Vector3.ZERO, -4.0 * minf(strength, 1.5), 0.25)


func _process(delta: float) -> void:
	if player == null:
		return
	# The spring runs on scaled time, so a hit-stop freezes the squash mid-frame too.
	var accel := -SPRING * _squash - DAMPING * _squash_velocity
	_squash_velocity += accel * delta
	_squash += _squash_velocity * delta
	var juice: Node3D = player.juice_node()
	var basis := _axis_scale(_axis, _squash)
	# A gentle stretch along the travel line, scaled by speed.
	var flat: Vector3 = player.planar_velocity()
	if flat.length() > 1.0:
		basis = _axis_scale(flat.normalized(), -0.1 * player.speed_fraction()) * basis
	# The shell: an underdamped spring toward the heft class's size.
	var shell_accel := SHELL_RATE * SHELL_RATE * (shell_target() - shell) - 2.0 * 0.45 * SHELL_RATE * _shell_velocity
	_shell_velocity += shell_accel * delta
	shell += _shell_velocity * delta
	juice.basis = basis.scaled(Vector3.ONE * shell)
	# Keep the contact point planted while squashed, and a grown shell resting on the
	# ground rather than sunk into it.
	var ground: Vector3 = player.state.contact_normal if player.state.grounded else Vector3.UP
	juice.position = -_axis * Tuning.RADIUS * clampf(_squash, -0.3, MAX_SQUASH) * 0.9 * shell + ground * Tuning.RADIUS * (shell - 1.0)
	_animate_pylon(delta)


# Squashes by amount along axis and bulges the other two to keep the volume.
static func _axis_scale(axis: Vector3, amount: float) -> Basis:
	var up := axis.normalized()
	var right := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	right = (right - up * right.dot(up)).normalized()
	var align := Basis(right, up, right.cross(up))
	var side := 1.0 + amount * 0.5
	return align * Basis.from_scale(Vector3(side, 1.0 - amount, side)) * align.transposed()


func squash_amount() -> float:
	return _squash


# --- Camera -------------------------------------------------------------------------

func _on_dashed(direction: Vector3) -> void:
	_camera("punch_fov", "dashed", direction, 7.0, 0.3)
	squash(-0.18, direction)


func _on_boosted(direction: Vector3) -> void:
	_camera("punch_fov", "boosted", direction, 5.0, 0.3)
	squash(-0.14, direction)


func _on_launched(velocity: Vector3) -> void:
	_camera("punch_fov", "launched", velocity, 16.0, 1.0)
	_camera("kick", "launched", -velocity, 0.6)
	squash(-0.3, velocity)


func _on_dismounted(velocity: Vector3) -> void:
	_eject_ghost()
	if velocity.length() < 1.0:
		return
	_camera("punch_fov", "dismounted", velocity, clampf(4.0 + velocity.length() * 0.2, 4.0, 10.0), 0.35)
	squash(-0.25, velocity)


# A strike is judged at the end of the frame, once combat has had its say: a hit on
# plating that was not deflected in the same frame broke through.
func _on_enemy_struck(enemy: Node3D, kind: String, force: float) -> void:
	var direction := Vector3.FORWARD
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		direction = enemy.global_position - player.ball_position()
	if plating_of.is_valid():
		var plating := 0.0
		if is_instance_valid(enemy):
			plating = float(plating_of.call(enemy))
		if plating <= 0.0:
			return
		_strikes.append({"id": enemy.get_instance_id() if is_instance_valid(enemy) else 0, "direction": direction})
		if not _resolve_queued:
			_resolve_queued = true
			_resolve_strikes.call_deferred()
		return
	if not BIG_HIT.has(kind) or force < BIG_HIT[kind]:
		return
	_break_through(direction, HIT_STOP_FOR[kind])


func _on_deflected(enemy: Node3D, _kind: String, _punch: float, _plating: float) -> void:
	if is_instance_valid(enemy):
		_deflected[enemy.get_instance_id()] = true


func _resolve_strikes() -> void:
	_resolve_queued = false
	for strike in _strikes:
		if not _deflected.has(strike["id"]):
			_break_through(strike["direction"], BREAK_STOP)
	_strikes.clear()
	_deflected.clear()


func _break_through(direction: Vector3, seconds: float) -> void:
	_camera("kick", "enemy_struck", direction, 0.3)
	if camera != null:
		camera.shake(0.35, 0.2)
	request_hit_stop(seconds, "enemy_struck")


func _on_unsealed(_stage: int) -> void:
	_camera("punch_fov", "beacon_unsealed", Vector3.ZERO, 9.0, 0.6)
	request_hit_stop(UNSEAL_STOP, "beacon_unsealed")


# A new heft class: the shell swells to its new size and the ball pops.
func _on_heft_class(heft_class: int, _heft: float) -> void:
	if heft_class > _heft_class:
		squash(0.32, Vector3.UP)
		_shell_velocity += 1.2
		hook_log.append(["class_up", "heft_class_changed"])
	_heft_class = heft_class


# A weak point cracked: a small kick, no freeze (hit-stop stays for plated breaks).
func _on_weak_point(_point_id: String) -> void:
	_camera("kick", "boss_weak_point_hit", Vector3.DOWN, 0.25)


func shell_target() -> float:
	return 1.0 + SHELL_PER_CLASS * (_heft_class - 1)


func _camera(hook: String, fact: String, direction: Vector3, amount: float, time := 0.3) -> void:
	hook_log.append([hook, fact])
	if camera == null:
		return
	match hook:
		"punch_fov":
			camera.punch_fov(amount, time)
		"kick":
			camera.kick(direction, amount)


# The one way presentation asks for a freeze.
func request_hit_stop(seconds: float, fact: String) -> void:
	var now := Time.get_ticks_msec()
	var sent := clampf(seconds, HIT_STOP_MIN, HIT_STOP_MAX)
	if now - _last_stop_ms < HIT_STOP_GAP_MS or not ctx.flow.in_play():
		hit_stop_log.append([seconds, 0.0, fact, now])
		return
	_last_stop_ms = now
	hit_stop_log.append([seconds, sent, fact, now])
	hook_log.append(["hit_stop", fact])
	if hit_stop_sink.is_valid():
		hit_stop_sink.call(sent)


# --- The pylon ------------------------------------------------------------------------
# The spine draws the pylon and places it every frame; presentation animates its two
# parts: the post drives into the face with an overshoot and the plate flashes out.

func _on_mounted(_at: Vector3, banked_speed: float) -> void:
	_plant_t = 0.0
	_camera("punch_fov", "mounted", Vector3.ZERO, -3.0, 0.2)
	squash(0.25 + minf(banked_speed / 60.0, 0.15), player.kit.mount_normal)


func _pylon() -> Dictionary:
	if not _pylon_parts.is_empty():
		return _pylon_parts
	var pylon: Node3D = player.pylon_node()
	if pylon == null:
		return {}
	for child in pylon.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			var part := "post" if (child.mesh as CylinderMesh).height > 0.5 else "plate"
			_pylon_parts[part] = {"node": child, "rest": child.transform, "height": (child.mesh as CylinderMesh).height}
	return _pylon_parts


func _animate_pylon(delta: float) -> void:
	var parts := _pylon()
	if parts.is_empty():
		return
	var pylon: Node3D = player.pylon_node()
	if pylon.visible:
		_pylon_transform = pylon.global_transform
	for ghost in _ghosts.duplicate():
		ghost["t"] += delta / 0.16
		var node: Node3D = ghost["node"]
		if ghost["t"] >= 1.0:
			node.queue_free()
			_ghosts.erase(ghost)
			continue
		var s := 1.0 - ease(ghost["t"], 0.4)
		node.scale = Vector3(1.0, maxf(0.01, s), 1.0)
	if _plant_t < 0.0:
		return
	_plant_t += delta
	var t := clampf(_plant_t / 0.16, 0.0, 1.0)
	# Out of the face with a 12% overshoot, then home.
	var drive := 1.0 + 0.12 * sin(t * PI) if t > 0.45 else lerpf(0.15, 1.12, t / 0.45)
	if parts.has("post"):
		var post: Dictionary = parts["post"]
		var node: MeshInstance3D = post["node"]
		var rest: Transform3D = post["rest"]
		node.transform = Transform3D(rest.basis.scaled(Vector3(1.0, drive, 1.0)), Vector3(rest.origin.x, post["height"] * 0.5 * drive, rest.origin.z))
	if parts.has("plate"):
		var plate: Dictionary = parts["plate"]
		var flare := lerpf(1.7, 1.0, ease(t, 0.3))
		(plate["node"] as MeshInstance3D).transform = Transform3D(plate["rest"].basis.scaled(Vector3(flare, 1.0, flare)), plate["rest"].origin)
	if t >= 1.0:
		_plant_t = -1.0
		_restore_pylon()


func _restore_pylon() -> void:
	for part in _pylon_parts.values():
		(part["node"] as Node3D).transform = part["rest"]


# The eject: the spine hides the pylon the moment you leave it, so a ghost of the post
# snaps back into the face behind you.
func _eject_ghost() -> void:
	var parts := _pylon()
	_plant_t = -1.0
	_restore_pylon()
	if not parts.has("post") or ctx.root == null:
		return
	var source: MeshInstance3D = parts["post"]["node"]
	var holder := Node3D.new()
	holder.name = "PylonEject"
	ctx.root.add_child(holder)
	holder.global_transform = _pylon_transform
	var ghost := MeshInstance3D.new()
	ghost.mesh = source.mesh
	ghost.material_override = source.material_override
	ghost.transform = parts["post"]["rest"]
	holder.add_child(ghost)
	_ghosts.append({"node": holder, "t": 0.0})
