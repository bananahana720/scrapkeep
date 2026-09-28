extends Node

const Harmony := preload("res://src/presentation/harmony.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")

# The class shell's life: idle breath and the pilot's small habits, lean and brace in
# motion, the ability devices lit only while they work, and reactions to landing, hits
# and a Warden break. It reads state only (the ball's velocity and kit flags, the
# ability slots, the bus) and writes transforms and emission on the shell's own nodes.
#
# It drives roles, not a particular model. ROLES names the nodes each role may use, and
# every accent device is found by its name: Accent_<slot>[_<slot>...] lights while any of
# those ability slots works. Ring* nodes, if a shell has them, spin with speed and pulse
# with the motif. A shell that lacks a node simply skips that behaviour, so a redesigned
# shell keeps every effect it has parts for.
#
# The idle pulse is the class leitmotif as light (SOUND-STORY section 2), phase-locked to
# the band's sixteenth grid when the music engine runs, so look and sound share a beat.
# Under reduced motion (VISUAL-LANGUAGE section 8) the idle loops, fidgets and cheer hops
# stop; lit devices, the gauge glow and the ready step stay, because they carry state.

# The motif as light: [sixteenth in a two-bar loop, brightness]. Sable climbs the Dm9,
# Rivet hammers three times then lifts a fourth on the beat, Kest falls a triad and
# doubles the last thump.
const MOTIFS := {
	"pylon_engineer": [[0, 0.3], [1, 0.45], [2, 0.62], [3, 0.8], [4, 1.0]],
	"runner_gunner": [[0, 0.7], [1, 0.7], [2, 0.7], [4, 1.0]],
	"demolitions_caster": [[0, 1.0], [2, 0.78], [4, 0.58], [6, 0.8], [7, 1.0]],
}
const LOOP_STEPS := 32.0
const NOTE_DECAY := 2.4
const FIDGETS := {
	"pylon_engineer": "ear_flick",
	"runner_gunner": "visor_wipe",
	"demolitions_caster": "crest_ruffle",
}

const ROLES := {
	"body": ["Pod"],
	"core": ["Core"],
	"pilot": ["Pilot"],
	"head": ["Head"],
	"eyes": ["Eyes"],
	"brace": ["EarL", "EarR", "Crest", "Visor"],
	"paws": ["PawL", "PawR"],
	"tap": ["Mast"],
	"spin": ["Spool"],
	"puff": ["StackL", "StackR"],
	"recoil": ["Mortar"],
	"swing": ["Satchel0", "Satchel1", "Satchel2"],
	"vane": ["VaneL", "VaneR"],
	"glass": ["Dome"],
}
# How far each braced part folds at top speed, about its own X (radians).
const BRACE := {"EarL": 0.8, "EarR": 0.8, "Crest": 0.7, "Visor": -0.15}
const ACCENT_PREFIX := "Accent"
const RING_PREFIX := "Ring"
const GLOWING := ["class_accent", "field"]
const SHIMMER_ROLES := ["body", "core"]

const TURN_RATE := 10.0
const TURN_SPEED := 1.5
const LEAN_PER_ACCEL := 0.012
const LEAN_MAX := 0.2
const BREATH_SECONDS := 2.6
const BRACE_FROM := 0.55
const LOOK_RANGE := 30.0
const LOOK_EVERY := 0.25
const LOOK_MAX := 1.0
const BLINK_SECONDS := 0.12
const FIDGET_SECONDS := 0.9
const FIDGET_AFTER := 3.0
const FLINCH_SECONDS := 0.35
const CHEER_SECONDS := 1.4
const FLASH_SECONDS := 0.15
const PUFF_SECONDS := 0.3
const IDLE_FLOOR := 0.4
const IDLE_SWING := 0.8
const ACTIVE_GLOW := 2.0
const GAUGE_GLOW := 2.4
const PULSE_GLOW := 2.6
const FLASH_GLOW := 2.4
const CRACKLE_GLOW := 1.2

var class_id := ""
var player
var reduced_motion := false
# () -> float: the band's position in sixteenths, or a negative number when silent.
var clock := Callable()

var _nodes := {}
var _rest := {}
var _devices: Array = []
var _rings: Array = []
var _glass_mats: Array = []
var _motif: Array = []
var _time := 0.0
var _last_velocity := Vector3.ZERO
var _lean := Vector2.ZERO
var _swing := Vector2.ZERO
var _swing_velocity := Vector2.ZERO
var _look_yaw := 0.0
var _look_target := Vector3.ZERO
var _has_target := false
var _look_timer := 0.0
var _blink_left := 0.0
var _next_blink := 2.0
var _blinks := 0
var _still_for := 0.0
var _fidget_left := 0.0
var _next_fidget := 7.0
var _flinch_left := 0.0
var _cheer_left := 0.0
var _land := 0.0
var _land_velocity := 0.0
var _puff_left := 0.0
var _recoil := 0.0
var _spin_rate := 0.0
var _vane_open := 0.0
var _slot_states: Array[String] = ["", "", "", ""]
var _pulse_left: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flash_left: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _gauges: Array[float] = [0.0, 0.0, 0.0, 0.0]


# roots: the nodes that hold the shell's parts (the rolling core and the upright pod).
func bind(roots: Array, id: String, player_ref, events = null) -> void:
	class_id = id
	player = player_ref
	_motif = MOTIFS.get(id, [])
	for role in ROLES:
		var found: Array[Node3D] = []
		for node_name in ROLES[role]:
			var node := _find(roots, node_name)
			if node != null:
				found.append(node)
				_rest[node] = node.transform
		_nodes[role] = found
	for root in roots:
		_collect(root)
	for dome in _nodes["glass"]:
		_glass_mats.append_array(_own_materials(dome, ["glass"]))
	for mat in _glass_mats:
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 0.0
	if events != null:
		events.landed.connect(_on_landed)
		events.player_hit.connect(_on_hit)
		events.shot_fired.connect(_on_shot)
		events.special_used.connect(_on_special)
		events.boosted.connect(_on_boosted)
		events.sprint_started.connect(_on_boosted)
		events.beacon_unsealed.connect(_on_warden_broken)
		events.boss_defeated.connect(_cheer)


static func _find(roots: Array, node_name: String) -> Node3D:
	for root in roots:
		if root.name == node_name:
			return root
		var hit := (root as Node).find_child(node_name, true, false) as Node3D
		if hit != null:
			return hit
	return null


func _collect(node: Node) -> void:
	var node_name := String(node.name)
	if node_name.begins_with(ACCENT_PREFIX) and node is Node3D:
		var slots := PackedInt32Array()
		for token in node_name.split("_"):
			var index := AbilityState.SLOTS.find(token)
			if index >= 0:
				slots.append(index)
		_devices.append({"node": node, "rest": (node as Node3D).transform, "slots": slots,
			"mats": _own_materials(node, GLOWING), "level": 0.0})
	elif node_name.begins_with(RING_PREFIX) and node is Node3D:
		_rings.append({"node": node, "rest": (node as Node3D).transform, "mats": _own_materials(node, GLOWING),
			"spin": 0.0})
	for child in node.get_children():
		_collect(child)


# The node's own mesh surfaces in these slots get a private copy of their material, so
# one shell's glow never lights another's. Returns [material, base energy] pairs.
func _own_materials(node: Node, slots: Array) -> Array:
	var out := []
	var mi := node as MeshInstance3D
	if mi == null or mi.mesh == null:
		return out
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i)
		if mat == null or not (mat.resource_name in slots):
			continue
		var current := mi.get_surface_override_material(i)
		var own := ((current if current != null else mat) as StandardMaterial3D).duplicate() as StandardMaterial3D
		mi.set_surface_override_material(i, own)
		if "glass" in slots:
			out.append(own)
		else:
			out.append([own, own.emission_energy_multiplier if own.emission_enabled else 0.0])
			own.emission_enabled = true
	return out


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_time += delta
	var v: Vector3 = player.state.velocity
	var flat := Vector3(v.x, 0.0, v.z)
	var speed := flat.length()
	var speed_frac := clampf(speed / 30.0, 0.0, 1.0)
	var calm := 1.0 - clampf(speed / 6.0, 0.0, 1.0)
	var accel := (v - _last_velocity) / maxf(delta, 1e-4)
	_last_velocity = v
	_still_for = _still_for + delta if calm > 0.8 else 0.0
	_tick_timers(delta)
	_steer_body(delta, flat, speed, accel, calm)
	_steer_pilot(delta, speed_frac, calm)
	_steer_kit(delta, speed_frac)
	_light(delta, speed_frac)


func _tick_timers(delta: float) -> void:
	_blink_left = maxf(0.0, _blink_left - delta)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_left = BLINK_SECONDS
		_blinks += 1
		_next_blink = 2.4 + 2.2 * _hash(_blinks)
	_fidget_left = maxf(0.0, _fidget_left - delta)
	if _still_for > FIDGET_AFTER and not reduced_motion:
		_next_fidget -= delta
		if _next_fidget <= 0.0:
			_fidget_left = FIDGET_SECONDS
			_next_fidget = 6.0 + 4.0 * _hash(_blinks + 7)
	_flinch_left = maxf(0.0, _flinch_left - delta)
	_cheer_left = maxf(0.0, _cheer_left - delta)
	_puff_left = maxf(0.0, _puff_left - delta)
	_recoil *= exp(-12.0 * delta)
	var land_accel := -180.0 * _land - 16.0 * _land_velocity
	_land_velocity += land_accel * delta
	_land += _land_velocity * delta
	for i in 4:
		_pulse_left[i] = maxf(0.0, _pulse_left[i] - delta)
		_flash_left[i] = maxf(0.0, _flash_left[i] - delta)


func _steer_body(delta: float, flat: Vector3, speed: float, accel: Vector3, calm: float) -> void:
	var breath := 0.0 if reduced_motion else sin(TAU * _time / BREATH_SECONDS) * calm
	for body: Node3D in _nodes["body"]:
		if speed > TURN_SPEED:
			var want := atan2(-flat.x, -flat.z)
			body.rotation.y = lerp_angle(body.rotation.y, want, 1.0 - exp(-TURN_RATE * delta))
		var yaw := Basis(Vector3.UP, body.rotation.y)
		var local := yaw.inverse() * Vector3(accel.x, 0.0, accel.z)
		var want_lean := Vector2(clampf(local.z * LEAN_PER_ACCEL, -LEAN_MAX, LEAN_MAX),
			clampf(-local.x * LEAN_PER_ACCEL, -LEAN_MAX, LEAN_MAX))
		_lean = _lean.lerp(want_lean, 1.0 - exp(-8.0 * delta))
		body.rotation.x = _lean.x
		body.rotation.z = _lean.y
		var rest: Transform3D = _rest[body]
		body.position = rest.origin + Vector3.UP * (0.015 * breath - 0.1 * _land)
		body.scale = rest.basis.get_scale() * Vector3(1.0 + 0.12 * _land, 1.0 - 0.25 * _land, 1.0 + 0.12 * _land)
	for core: Node3D in _nodes["core"]:
		var rest: Transform3D = _rest[core]
		core.scale = rest.basis.get_scale() * (1.0 + 0.012 * breath)
	var swing_accel := (-_lean * 1.8 - _swing) * 60.0 - _swing_velocity * 6.0
	_swing_velocity += swing_accel * delta
	_swing += _swing_velocity * delta
	for bag: Node3D in _nodes["swing"]:
		var rest: Transform3D = _rest[bag]
		bag.transform = rest * Transform3D(Basis.from_euler(Vector3(_swing.x, 0.0, _swing.y)), Vector3.ZERO)


func _steer_pilot(delta: float, speed_frac: float, calm: float) -> void:
	var brace := clampf((speed_frac - BRACE_FROM) / (1.0 - BRACE_FROM), 0.0, 1.0)
	var flinch := sin(PI * _flinch_left / FLINCH_SECONDS) if _flinch_left > 0.0 else 0.0
	var cheer_t := 1.0 - _cheer_left / CHEER_SECONDS if _cheer_left > 0.0 else 1.0
	var cheer := sin(PI * cheer_t) if _cheer_left > 0.0 else 0.0
	var hop := absf(sin(cheer_t * TAU * 2.0)) * cheer if not reduced_motion else 0.0
	var fidget_t := 1.0 - _fidget_left / FIDGET_SECONDS if _fidget_left > 0.0 else 1.0
	var fidget := sin(PI * fidget_t) if _fidget_left > 0.0 else 0.0
	var kind: String = FIDGETS.get(class_id, "")
	for pilot_node: Node3D in _nodes["pilot"]:
		var rest: Transform3D = _rest[pilot_node]
		var breath := 0.0 if reduced_motion else 0.02 * sin(TAU * _time / BREATH_SECONDS + 0.6) * calm
		pilot_node.position = rest.origin + Vector3.UP * (0.07 * hop - 0.25 * _land)
		pilot_node.scale = rest.basis.get_scale() * Vector3(1.0, 1.0 + breath, 1.0)
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = LOOK_EVERY
		_pick_look_target()
	for head: Node3D in _nodes["head"]:
		var want := 0.0
		var parent_basis := (head.get_parent() as Node3D).global_basis if head.is_inside_tree() else Basis.IDENTITY
		var look_dir := _look_direction(head)
		if look_dir != Vector3.ZERO:
			var local := parent_basis.inverse() * look_dir
			want = clampf(atan2(-local.x, -local.z), -LOOK_MAX, LOOK_MAX)
		if kind == "crest_ruffle" and fidget > 0.0:
			want = lerpf(want, 0.9, fidget)
		_look_yaw = lerp_angle(_look_yaw, want, 1.0 - exp(-6.0 * delta))
		var nod := -0.12 * brace + 0.3 * flinch + 0.25 * cheer + 0.1 * _land
		var rest: Transform3D = _rest[head]
		head.transform = Transform3D(rest.basis * Basis.from_euler(Vector3(nod, _look_yaw, 0.0)),
			rest.origin + Vector3.UP * (-0.03 * brace))
	for eyes: Node3D in _nodes["eyes"]:
		var rest: Transform3D = _rest[eyes]
		var shut := 0.9 if _blink_left > 0.0 else 0.0
		shut = maxf(shut, 0.85 * flinch)
		eyes.scale = rest.basis.get_scale() * Vector3(1.0, 1.0 - shut, 1.0)
	for part: Node3D in _nodes["brace"]:
		var rest: Transform3D = _rest[part]
		var fold: float = BRACE.get(String(part.name), 0.0) * brace - 0.3 * cheer * signf(BRACE.get(String(part.name), 0.0))
		var extra := Vector3.ZERO
		if kind == "ear_flick" and String(part.name) == "EarL":
			extra.z = 0.6 * sin(fidget_t * TAU * 2.0) * fidget
		if kind == "crest_ruffle" and String(part.name) == "Crest":
			extra.x = 0.18 * sin(_time * 40.0) * fidget
		part.transform = Transform3D(rest.basis * Basis.from_euler(Vector3(fold, 0.0, 0.0) + extra), rest.origin)
		if kind == "crest_ruffle" and String(part.name) == "Crest":
			part.scale = rest.basis.get_scale() * (1.0 + 0.15 * fidget + 0.15 * cheer)
	for paw: Node3D in _nodes["paws"]:
		var rest: Transform3D = _rest[paw]
		var offset := Vector3.UP * (0.1 * cheer)
		var right := String(paw.name) == "PawR"
		if right and kind == "ear_flick":
			offset.y += 0.03 * absf(sin(fidget_t * TAU * 3.0)) * fidget
		if right and kind == "visor_wipe":
			offset += Vector3(0.1 * sin(fidget_t * TAU * 2.0), 0.16, -0.05) * fidget
		paw.position = rest.origin + offset
	for mast: Node3D in _nodes["tap"]:
		var rest: Transform3D = _rest[mast]
		var wobble := 0.08 * sin(fidget_t * TAU * 3.0) * fidget if kind == "ear_flick" else 0.0
		mast.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, wobble), rest.origin)


func _pick_look_target() -> void:
	_has_target = false
	if not (player is Node) or not (player as Node).is_inside_tree():
		return
	var at: Vector3 = (player as Node3D).global_position
	if player.has_method("ball_position"):
		at = player.ball_position()
	var best := LOOK_RANGE * LOOK_RANGE
	for enemy in (player as Node).get_tree().get_nodes_in_group("enemy"):
		var d := (enemy as Node3D).global_position.distance_squared_to(at)
		if d < best:
			best = d
			_look_target = (enemy as Node3D).global_position
			_has_target = true


func _look_direction(head: Node3D) -> Vector3:
	if _has_target and head.is_inside_tree():
		var d := _look_target - head.global_position
		d.y = 0.0
		return d.normalized() if d.length_squared() > 0.01 else Vector3.ZERO
	var drive = player.get("drive_basis")
	if drive is Basis:
		var f := -(drive as Basis).z
		f.y = 0.0
		return f.normalized() if f.length_squared() > 0.01 else Vector3.ZERO
	return Vector3.ZERO


func _steer_kit(delta: float, speed_frac: float) -> void:
	var kit = player.get("kit")
	var hooked: bool = kit != null and kit.get("hooked") == true
	var gliding: bool = kit != null and kit.get("gliding") == true
	_spin_rate = lerpf(_spin_rate, 14.0 if hooked else 0.0, 1.0 - exp(-(10.0 if hooked else 2.0) * delta))
	for spool: Node3D in _nodes["spin"]:
		spool.rotate_object_local(Vector3.RIGHT, _spin_rate * delta)
	var sprinting := _slot_states[1] == AbilityState.ACTIVE and class_id == "runner_gunner"
	var puff := sin(PI * _puff_left / PUFF_SECONDS) if _puff_left > 0.0 else 0.0
	for stack: Node3D in _nodes["puff"]:
		var rest: Transform3D = _rest[stack]
		var shimmer := 0.05 * sin(_time * 50.0) if sprinting else 0.0
		stack.scale = rest.basis.get_scale() * (1.0 + 0.35 * puff + shimmer)
	for mortar: Node3D in _nodes["recoil"]:
		var rest: Transform3D = _rest[mortar]
		var axis := Vector3.UP
		for child in mortar.get_children():
			if child is Node3D and (child as Node3D).position.length_squared() > 1e-4:
				axis = (child as Node3D).position.normalized()
				break
		mortar.position = rest.origin - rest.basis * axis * 0.1 * _recoil
	_vane_open = lerpf(_vane_open, 1.0 if gliding else 0.0, 1.0 - exp(-8.0 * delta))
	for vane: Node3D in _nodes["vane"]:
		var side := -1.0 if String(vane.name) == "VaneL" else 1.0
		var flutter := 0.07 * sin(_time * 31.0 + side) * speed_frac * _vane_open
		vane.rotation.z = -side * (_vane_open * PI * 0.5 + flutter)
	for ring: Dictionary in _rings:
		var node: Node3D = ring["node"]
		ring["spin"] = fmod(ring["spin"] + delta * (0.6 + 9.0 * speed_frac), TAU)
		var rest: Transform3D = ring["rest"]
		node.transform = Transform3D(rest.basis * Basis.from_euler(Vector3(_lean.x, ring["spin"], _lean.y)), rest.origin)


func _light(_delta: float, speed_frac: float) -> void:
	var abilities = player.get("abilities")
	var kit = player.get("kit")
	var mounted: bool = kit != null and kit.get("mounted") == true
	var cloaked: bool = kit != null and kit.get("cloaked") == true
	if abilities != null:
		for i in 4:
			var slot_name: String = AbilityState.SLOTS[i]
			var state: String = abilities.state_of(slot_name)
			if state == AbilityState.READY and _slot_states[i] == AbilityState.COOLING:
				_pulse_left[i] = AbilityBar.PULSE_SECONDS
			_slot_states[i] = state
			var gauge = abilities.gauge(slot_name)
			_gauges[i] = gauge.fraction() if gauge != null else 0.0
	var env := motif_level() if not reduced_motion else 0.5
	var cheer := sin(PI * (1.0 - _cheer_left / CHEER_SECONDS)) if _cheer_left > 0.0 else 0.0
	var crackle := CRACKLE_GLOW * (0.5 + 0.5 * sin(_time * 37.0) * sin(_time * 23.0)) if mounted else 0.0
	for device: Dictionary in _devices:
		var boost := crackle + cheer * FLASH_GLOW * env
		var pulse := 0.0
		for i: int in device["slots"]:
			if _slot_states[i] == AbilityState.ACTIVE:
				boost += ACTIVE_GLOW
			boost += GAUGE_GLOW * _gauges[i]
			if _flash_left[i] > 0.0:
				boost += FLASH_GLOW * _flash_left[i] / FLASH_SECONDS
			if _pulse_left[i] > 0.0:
				pulse = maxf(pulse, sin(PI * (1.0 - _pulse_left[i] / AbilityBar.PULSE_SECONDS)))
		device["level"] = boost + PULSE_GLOW * pulse
		for pair: Array in device["mats"]:
			(pair[0] as StandardMaterial3D).emission_energy_multiplier = (pair[1] as float) * (IDLE_FLOOR + IDLE_SWING * env) + device["level"]
		var node: Node3D = device["node"]
		var rest: Transform3D = device["rest"]
		var swell := 1.0 + (0.0 if reduced_motion else AbilityBar.PULSE_SCALE * pulse)
		node.scale = rest.basis.get_scale() * swell
	var ready_flash := 0.0
	for i in 4:
		if _pulse_left[i] > 0.0:
			ready_flash = maxf(ready_flash, sin(PI * (1.0 - _pulse_left[i] / AbilityBar.PULSE_SECONDS)))
	for ring: Dictionary in _rings:
		for pair: Array in ring["mats"]:
			(pair[0] as StandardMaterial3D).emission_energy_multiplier = (pair[1] as float) * (IDLE_FLOOR + IDLE_SWING * env) + PULSE_GLOW * ready_flash
	var glint := sin(PI * _flinch_left / FLINCH_SECONDS) if _flinch_left > 0.0 else 0.0
	for mat in _glass_mats:
		mat.emission_energy_multiplier = 1.8 * glint
	var shimmer := 0.35 + 0.15 * sin(_time * 18.0) if cloaked else 0.0
	for role in SHIMMER_ROLES:
		for node: Node3D in _nodes[role]:
			if node is GeometryInstance3D:
				(node as GeometryInstance3D).transparency = shimmer


# The motif's brightness now, 0 to 1: the latest note's level, decaying.
func motif_level() -> float:
	if _motif.is_empty():
		return 0.5
	var s := sixteenths()
	var pos := fposmod(s, LOOP_STEPS)
	var level := 0.0
	for note: Array in _motif:
		var since := pos - float(note[0])
		if since >= 0.0:
			level = maxf(level, float(note[1]) * exp(-since / NOTE_DECAY))
	return level


func sixteenths() -> float:
	if clock.is_valid():
		var s: float = clock.call()
		if s >= 0.0:
			return s
	return _time * Harmony.BPM / 60.0 * Harmony.STEPS_PER_BEAT


func device_level(node_name: String) -> float:
	for device: Dictionary in _devices:
		if String((device["node"] as Node).name) == node_name:
			return device["level"]
	return -1.0


func device_names() -> PackedStringArray:
	var out := PackedStringArray()
	for device: Dictionary in _devices:
		out.append(String((device["node"] as Node).name))
	return out


func role_nodes(role: String) -> Array:
	return _nodes.get(role, [])


static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)


func _on_landed(impact: float) -> void:
	_land_velocity += clampf(impact / 20.0, 0.0, 1.0) * 4.0


func _on_hit(_amount: float, _source: String) -> void:
	_flinch_left = FLINCH_SECONDS


func _on_shot(_weapon_id: String, _from: Vector3, _to: Vector3) -> void:
	_flash_left[0] = FLASH_SECONDS
	_recoil = 1.0


func _on_special(_special_id: String, _at: Vector3) -> void:
	_flash_left[2] = FLASH_SECONDS


func _on_boosted(_direction: Vector3) -> void:
	_puff_left = PUFF_SECONDS


func _on_warden_broken(_stage: int) -> void:
	_cheer()


func _cheer() -> void:
	_cheer_left = CHEER_SECONDS
