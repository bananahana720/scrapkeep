extends Node3D

const Companion := preload("res://src/core/companion.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

const MODEL_DIR := "res://assets/models/companion/assembled/"
const PART_DIR := "res://assets/models/companion/"
const BARE := "bare"
const CHASSIS_PATH := "res://assets/models/companion/spil9.glb"
const MARKS_PATH := "res://assets/models/companion/spil9_marks.glb"
const MARK_PARTS := ["Mk1Halo", "Mk2Fins", "Mk3Halo", "Mk4Exhaust", "Mk5CoreCrest"]
const SOCKET_AT := Vector3(-0.29, 0.225, 0.0)
const HALO_LIFT := 0.62
const HALO_RADIUS := 0.36
const HALO_ENERGY := {"empty": 0.15, "full": 3.0}
const WORD_LIFE := 0.7
const WORD_SIZE := 0.012
const HULL_LIFT := 0.51
const SIDE := 2.0
const BEHIND := 0.8
const FOLLOW_RATE := 8.0
const TURN_RATE := 6.0
const MOVING_SPEED := 1.0
const STOPPED_SPEED := 0.6
const LOOP_BLEND := 0.2
const BEAT_BLEND := 0.12
const LAMP_RADIUS := 0.09
const LAMP_LIFT := 0.48
const LAMP_ENERGY := {"ready": 1.0, "flare": 4.0, "flick": 3.0, "spent": 0.12}
const LAMP_SCALE := {"ready": Vector3.ONE, "flare": Vector3.ONE * 1.8, "flick": Vector3(0.6, 0.6, 3.5), "spent": Vector3.ONE}
const ESCAPE_CUES := {"shove": "flare", "lane": "flick"}
static var _painted_materials := {}
static var _warned_empty_mesh := false

var ctx
var model_dir := MODEL_DIR
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
var _mark := 0
var _grown := 1.0
var _kit: Node3D
var _mark_parts := {}
var _halo: MeshInstance3D
var _words: Array = []
var _wired := false
var assists_shown := 0


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "CompanionBody"
	top_level = true
	visible = false
	combat = ctx.get("spawner")


static func model_path(sockets: Array, dir := MODEL_DIR) -> String:
	if sockets.size() != Companion.SOCKETS:
		return ""
	return dir + "%s__%s.glb" % [sockets[0], sockets[1]]


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


static func key_of(sockets: Array, has_companion := true) -> String:
	if not has_companion:
		return ""
	if sockets.is_empty():
		return BARE
	return "__".join(sockets)


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


func _has_companion() -> bool:
	var run = ctx.get("run") if ctx != null else null
	return run != null and String(run.companion.get("chassis", "")) == Companion.CHASSIS


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
	return found if found.size() <= Companion.SOCKETS else []


func _process(delta: float) -> void:
	if ctx == null or ctx.player == null:
		return
	_wire()
	_age_words(delta)
	var seats := _seats()
	var key := key_of(seats, _has_companion())
	if key != _key:
		_rebuild(seats, key)
	if key == "":
		return
	_grow()
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


func _leader_alive() -> bool:
	var run = ctx.get("run")
	return run == null or not run.has_method("alive") or run.alive()


func _hold(delta: float, safe: Vector3) -> void:
	var target := safe + _heading.cross(Vector3.UP).normalized() * SIDE * _grown
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


func state() -> String:
	return _state


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
	_kit = null
	_halo = null
	_mark_parts = {}
	_mark = 0
	visible = key != ""
	_snap = true
	if key == "":
		return
	var path := model_path(seats, model_dir) if seats.size() == Companion.SOCKETS else CHASSIS_PATH
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed != null:
		_model = packed.instantiate() as Node3D
	if _model != null and seats.size() == 1:
		_seat_part(_model, String(seats[0]))
	if _model == null:
		if not _warned:
			_warned = true
			push_warning("companion_body: model '%s' unavailable; keeping the plain hull" % path)
		var hull := _fallback()
		add_child(hull)
		_add_lamp(hull, key)
		_add_halo(hull)
		return
	dress_model(_model)
	add_child(_model)
	_add_lamp(_model, key)
	_add_halo(_model)
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


func _seat_part(chassis: Node3D, id: String) -> void:
	var path := PART_DIR + id + ".glb"
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		return
	var part := packed.instantiate() as Node3D
	part.name = "SeatedPart"
	var skeletons := chassis.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeletons.front() as Skeleton3D if not skeletons.is_empty() else null
	var bone := -1
	if skeleton != null:
		for name in ["Socket.01", "Socket_01"]:
			bone = skeleton.find_bone(name)
			if bone >= 0:
				break
	if bone >= 0:
		var mount := BoneAttachment3D.new()
		skeleton.add_child(mount)
		mount.bone_name = skeleton.get_bone_name(bone)
		mount.add_child(part)
	else:
		part.position = SOCKET_AT
		chassis.add_child(part)


func _add_halo(host: Node3D) -> void:
	_mark_parts = _mount_marks(host)
	_kit = Node3D.new()
	_kit.name = "MarkKit"
	host.add_child(_kit)
	if _mark_parts.has("Mk1Halo"):
		_halo = _mark_parts["Mk1Halo"]
		_halo.material_override = _halo_material()
		return
	_halo = MeshInstance3D.new()
	_halo.name = "AssistHalo"
	var ring := TorusMesh.new()
	ring.inner_radius = HALO_RADIUS - 0.03
	ring.outer_radius = HALO_RADIUS
	_halo.mesh = ring
	_halo.material_override = _halo_material()
	_halo.position = Vector3(0.0, HALO_LIFT, 0.0)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(_halo)


func _halo_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.albedo_color = EventKinds.UI_ROWS["companion_ready"]["color"]
	mat.emission = mat.albedo_color
	return mat


func _mount_marks(host: Node3D) -> Dictionary:
	if not ResourceLoader.exists(MARKS_PATH):
		return {}
	var skeletons := host.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeletons.front() as Skeleton3D if not skeletons.is_empty() else null
	if skeleton == null or skeleton.find_bone("Hull") < 0:
		return {}
	var scene := (load(MARKS_PATH) as PackedScene).instantiate()
	var hull := scene.find_child("Hull", false, false) as Node3D
	if hull == null:
		hull = scene as Node3D if scene.name == "Hull" else null
	if hull == null:
		scene.free()
		return {}
	if hull != scene:
		scene.remove_child(hull)
		scene.free()
	dress_model(hull)
	var mount := BoneAttachment3D.new()
	mount.name = "MarksMount"
	skeleton.add_child(mount)
	mount.bone_name = "Hull"
	mount.add_child(hull)
	var parts := {}
	for name in MARK_PARTS:
		var part := hull.find_child(name, true, false) as Node3D
		if part != null:
			part.visible = false
			parts[name] = part
	return parts


func _grow() -> void:
	var run = ctx.get("run")
	var heft: int = run.heft_class() if run != null and run.has_method("heft_class") else 1
	var row := Companion.mark_of(heft)
	if int(row["mark"]) != _mark:
		_mark = int(row["mark"])
		_grown = float(row["scale"])
		global_basis = global_basis.orthonormalized() * Basis.from_scale(Vector3.ONE * _grown)
		_build_kit(Companion.adds_of(heft))
	if _halo != null:
		var fill: float = combat.assist_fill() if combat != null and combat.has_method("assist_fill") else 0.0
		var mat := _halo.material_override as StandardMaterial3D
		var blink := not FlashGuard.on and fill >= 1.0 and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
		mat.emission_energy_multiplier = lerpf(HALO_ENERGY["empty"], HALO_ENERGY["full"], fill) * (1.6 if blink else 1.0)


func mark() -> int:
	return _mark


func grown() -> float:
	return _grown


func kit_parts() -> Array:
	var out := []
	for name in _mark_parts:
		if (_mark_parts[name] as Node3D).visible and name != "Mk1Halo":
			out.append(name)
	if _kit != null:
		for c in _kit.get_children():
			out.append(String(c.name))
	return out


func _build_kit(adds: Array) -> void:
	if _kit == null:
		return
	if not _mark_parts.is_empty():
		_show_marks()
		return
	for c in _kit.get_children():
		_kit.remove_child(c)
		c.queue_free()
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.55, 0.55, 0.6)
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.albedo_color = Color(1.0, 0.62, 0.15)
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 2.0
	for add in adds:
		match add:
			"fins":
				for x in [-1.0, 1.0]:
					_kit_part("Fin", PrismMesh.new(), grey, Vector3(x * 0.62, 0.18, -0.05), Vector3(0.1, 0.28, 0.64), Vector3(0.0, 0.0, -x * 0.5))
			"double_halo":
				var outer := TorusMesh.new()
				outer.inner_radius = HALO_RADIUS + 0.06
				outer.outer_radius = HALO_RADIUS + 0.09
				_kit_part("OuterHalo", outer, glow, Vector3(0.0, HALO_LIFT, 0.0), Vector3.ONE, Vector3.ZERO)
			"exhaust":
				for x in [-1.0, 1.0]:
					var cone := CylinderMesh.new()
					cone.top_radius = 0.0
					cone.bottom_radius = 0.09
					cone.height = 0.6
					_kit_part("Exhaust", cone, glow, Vector3(x * 0.25, 0.05, 0.62), Vector3.ONE, Vector3(PI / 2.0, 0.0, 0.0))
			"core_crest":
				var core := SphereMesh.new()
				core.radius = 0.16
				core.height = 0.32
				_kit_part("Core", core, glow, Vector3(0.0, 0.3, 0.05), Vector3.ONE, Vector3.ZERO)
				_kit_part("Crest", PrismMesh.new(), grey, Vector3(0.0, 0.62, -0.05), Vector3(0.06, 0.4, 0.3), Vector3.ZERO)


func _show_marks() -> void:
	for i in MARK_PARTS.size():
		var part = _mark_parts.get(MARK_PARTS[i])
		if part != null:
			part.visible = i == 0 or i < _mark


func _kit_part(part_name: String, mesh: Mesh, mat: Material, at: Vector3, size: Vector3, rot: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = mat
	part.position = at
	part.scale = size
	part.rotation = rot
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kit.add_child(part)


func _wire() -> void:
	if _wired or combat == null or not combat.has_signal("companion_assisted"):
		return
	_wired = true
	combat.companion_assisted.connect(_on_assisted)
	combat.companion_assist_full.connect(func(): cue("assist_full"))


func _on_assisted(assist: Dictionary) -> void:
	cue(String(assist.get("cue", "")))
	if _anim != null and _anim.current_animation == "assist_rise":
		for clip in ["assist_drop", "assist_return"]:
			if _anim.has_animation(clip):
				_anim.queue(clip)
	assists_shown += 1
	var host := get_parent()
	if host == null:
		return
	var word := Label3D.new()
	word.name = "AssistWord"
	word.text = String(assist.get("word", ""))
	word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	word.pixel_size = WORD_SIZE
	word.font_size = 96
	word.outline_size = 24
	word.modulate = Color(1.0, 0.62, 0.15)
	word.outline_modulate = Color(0.08, 0.09, 0.11)
	word.top_level = true
	host.add_child(word)
	var at: Vector3 = assist.get("at", global_position)
	word.global_position = at + Vector3.UP * 2.2 + _heading.cross(Vector3.UP).normalized() * 1.5
	_words.append([word, WORD_LIFE])


func _age_words(delta: float) -> void:
	var keep: Array = []
	for entry in _words:
		var word: Label3D = entry[0]
		entry[1] = float(entry[1]) - delta
		if not is_instance_valid(word):
			continue
		if float(entry[1]) <= 0.0:
			word.queue_free()
			continue
		var t := 1.0 - float(entry[1]) / WORD_LIFE
		word.scale = Vector3.ONE * (1.0 + 0.3 * maxf(0.0, 1.0 - t * 6.0))
		word.modulate.a = clampf(float(entry[1]) / (WORD_LIFE * 0.4), 0.0, 1.0)
		keep.append(entry)
	_words = keep


func _exit_tree() -> void:
	for entry in _words:
		if is_instance_valid(entry[0]):
			entry[0].queue_free()
	_words.clear()


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
	var speed := velocity.length()
	_moving = speed > (STOPPED_SPEED if _moving else MOVING_SPEED)
	if _moving:
		var want := velocity.normalized()
		var blended := _heading.lerp(want, 1.0 - exp(-TURN_RATE * delta))
		if blended.length() > 0.01:
			_heading = blended.normalized()
	var ball: Vector3 = player.shown_position()
	var right := _heading.cross(Vector3.UP).normalized()
	var target := ball - _heading * BEHIND + right * SIDE * _grown
	target.y = ball.y - Tuning.RADIUS + HULL_LIFT
	if _snap:
		global_position = target
		_snap = false
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
	global_basis = Basis.looking_at(_heading, Vector3.UP) * Basis.from_scale(Vector3.ONE * _grown)
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
	_anim.play(clip, LOOP_BLEND)


func _beat(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip, BEAT_BLEND)


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
