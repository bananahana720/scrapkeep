extends Node

signal finished(id: String, skipped: bool)

const TitleIntros := preload("res://src/presentation/title_intros.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const PilotAntics := preload("res://src/presentation/pilot_antics.gd")
const Wordmark := preload("res://src/ui/wordmark.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")

const SET_AT := Vector3(600.0, 0.0, 0.0)
const LAYER := 6
const INK := Color("17141a")
const PAPER := Color("f3ecdc")
const CAPTION_FILL := Color("fff6c9")
const POINTER_DROP := 58.0
const POINTER_BOW := 7.0
const POINTER_HEAD := Vector2(10.0, 15.0)
const SFX_FILL := Color("ffd23f")
const BOSS_FILL := Color("ffe1dc")

const WORLDS := {
	1: {"ground": Color("2f6b62"), "sky": Color("f2b37a"), "landmark": "res://assets/models/world_one/dam.glb", "fit": 110.0, "behind": 80.0},
	2: {"ground": Color("3a2c22"), "sky": Color("2b2430"), "landmark": "res://assets/models/dig_mechanical/intake_throat.glb", "fit": 30.0, "behind": 34.0},
	3: {"ground": Color(), "sky": Color("78a7ea"), "landmark": "res://assets/models/highdraft/island_large.glb", "fit": 44.0, "behind": 50.0},
}
const BOSS_MODELS := {
	"brindle": "res://assets/models/bosses/boss_brindle.glb",
	"waking": "res://assets/models/bosses/boss_waking_base.glb",
	"mind": "res://assets/models/warden_mind.glb",
}
const SCOOTER := "res://assets/models/bosses/boss_brindle_scooter.glb"
const CHASER := "res://assets/models/world_one/enemy_chaser.glb"
const BARGE := "res://assets/models/moss_hover_barge.glb"
const DIG_PARTS := "res://assets/models/dig_mechanical/"
const DIG_SLOTS := ["stone", "steel", "enamel", "elastomer", "glass"]
const DAM_TINT := {"paint": Color.WHITE, "bare_metal": Color("7a7a70"), "rubber": Color("454943")}
const DAM_ROUGHNESS := {"paint": 0.8, "bare_metal": 0.45, "rubber": 0.95}
const ROLLCALL_AT := Vector3(-300.0, 0.0, 0.0)
const SKY_ENERGY := 0.5
const ROLLCALL := [["runner_gunner", "RIVET", "Never misses."], ["demolitions_caster", "KEST", "Still deciding."], ["tarn", "TARN", "Very gentle. Machine isn't."]]
const POSTCARD_SKY_CURVE := 0.45
const POSTCARD_WATER_COLORS := [Color("1a4d58"), Color("639294")]

var host: Node
var camera: Camera3D
var environment: Environment
var playing := false
var id := ""
var theme := ""
var reduced_motion := false
var clock := 0.0
var shot_index := -1

var _shots: Array = []
var _starts: Array[float] = []
var _row := {}
var _set: Node3D
var _subject: Node3D
var _subject_size := 1.0
var _postcard: Node3D
var _postcard_env: Environment
var _props := {}
var _layer: CanvasLayer
var _overlay: Control
var _lines: Control
var _saved := {}
var _tweens: Array[Tween] = []
# Shared session-wide: freeing per-opening material copies tripped Godot headless renderer.
static var _finishes := {}
var _catcher: Node
var _antics


func setup(stage_host: Node) -> void:
	name = "TitleIntroPlayer"
	host = stage_host
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func play(intro_id: String, picture: Texture2D) -> bool:
	_row = TitleIntros.row(intro_id)
	if _row.is_empty() or playing:
		return false
	id = intro_id
	theme = String(_row.theme)
	camera = host.camera
	environment = host._environment
	_shots = TitleIntros.shots(intro_id)
	_starts.clear()
	var at := 0.0
	for shot in _shots:
		_starts.append(at)
		at += float(shot.bars) * TitleIntros.BAR
	_saved = {"background": environment.background_color, "adjust": environment.adjustment_enabled,
		"saturation": environment.adjustment_saturation, "brightness": environment.adjustment_brightness, "fov": camera.fov,
		"energy": environment.background_energy_multiplier}
	_build_set()
	_build_layer(picture)
	_catcher = Catcher.new()
	_catcher.name = "TitleIntroCatcher"
	_catcher.player = self
	get_tree().root.add_child(_catcher)
	playing = true
	clock = 0.0
	shot_index = -1
	set_process(true)
	advance(0.0)
	return true


func length() -> float:
	return TitleIntros.length_seconds(id) if id != "" else 0.0


func shot_kind() -> String:
	return String(_shots[shot_index].kind) if shot_index >= 0 and shot_index < _shots.size() else ""


func skip() -> void:
	if playing:
		_finish(true)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not playing:
		return
	clock += delta
	if clock >= length():
		_finish(false)
		return
	var index := shot_index
	while index + 1 < _starts.size() and clock >= _starts[index + 1]:
		index += 1
	if index < 0:
		index = 0
	if index != shot_index:
		shot_index = index
		_enter_shot(_shots[index])
	var shot: Dictionary = _shots[shot_index]
	var t := clampf((clock - _starts[shot_index]) / (float(shot.bars) * TitleIntros.BAR), 0.0, 1.0)
	_frame_shot(String(shot.kind), t)
	if _lines != null:
		_lines.queue_redraw()


static func skips(event: InputEvent) -> bool:
	return (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)


func _finish(skipped: bool) -> void:
	playing = false
	set_process(false)
	if is_instance_valid(_catcher):
		_catcher.queue_free()
	_catcher = null
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	environment.background_color = _saved.background
	environment.adjustment_enabled = _saved.adjust
	environment.adjustment_saturation = _saved.saturation
	environment.adjustment_brightness = _saved.brightness
	camera.fov = _saved.fov
	camera.environment = environment
	environment.background_energy_multiplier = _saved.energy
	if is_instance_valid(_set):
		_set.queue_free()
	_set = null
	_subject = null
	_postcard = null
	_postcard_env = null
	_props.clear()
	_antics = null
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_overlay = null
	_lines = null
	shot_index = -1
	finished.emit(id, skipped)


func _build_set() -> void:
	_antics = null
	_set = Node3D.new()
	_set.name = "IntroSet"
	_set.position = SET_AT
	host.stage.add_child(_set)
	var world: int = int(_row.world)
	var look: Dictionary = WORLDS[world]
	if look.ground != Color():
		var ground := MeshInstance3D.new()
		ground.name = "IntroGround"
		var plane := PlaneMesh.new()
		plane.size = Vector2(900.0, 900.0)
		ground.mesh = plane
		ground.material_override = _flat(look.ground)
		_set.add_child(ground)
	var landmark := _model(String(look.landmark), "Landmark", float(look.fit))
	if landmark != null:
		landmark.position = Vector3(0.0, 0.0 if world != 3 else -24.0, -float(look.behind))
		if world == 3:
			var second := _model("res://assets/models/highdraft/island_medium.glb", "LandmarkSecond", 26.0)
			if second != null:
				second.position = Vector3(46.0, 10.0, -84.0)
	match String(_row.kind):
		"pilot":
			_subject = _shell(String(_row.pilot), "Subject")
		"boss":
			_subject = _model(BOSS_MODELS[String(_row.boss)], "Subject", 9.0)
			if _subject != null:
				_subject.rotation.y = PI
		"world":
			_subject = _shell("pylon_engineer", "Subject")
	if _subject == null:
		_subject = _fallback("Subject", ClassDef.by_id(String(_row.get("pilot", ""))).color if _row.kind == "pilot" and ClassDef.by_id(String(_row.get("pilot", ""))) != null else Palette.COPPER)
	_subject_size = maxf(1.0, _height(_subject) * 0.5)
	var up := _model("res://assets/models/highdraft/island_large.glb", "UpIsland", 40.0)
	if up != null:
		up.position = Vector3(8.0, 30.0, -60.0)
		up.visible = false
	for i in 3:
		var chaser := _model(ModelVariants.path(CHASER), "Chaser%d" % i, 2.4)
		if chaser != null:
			chaser.position = Vector3(-2.5 + i * 2.6, 0.9, 1.4 - i * 1.3) * _subject_size
			chaser.rotation = Vector3(0.4 * (i - 1), 0.7 + i, 0.6 * (i - 1))
			chaser.visible = false
	var barge := _model(BARGE, "Barge", 32.0)
	if barge != null:
		barge.position = Vector3(-6.0, 11.0, -34.0)
		barge.rotation.y = 0.6
		barge.visible = false
	if _row.has("cameo"):
		var machine := _model(BOSS_MODELS[String(_row.cameo)], "Cameo", 9.0)
		if machine != null:
			machine.position = Vector3(0.0, 0.0, -160.0)
			machine.rotation.y = PI + 0.4
		var scooter := _model(SCOOTER, "Scooter", 1.4)
		if scooter != null:
			scooter.position = Vector3(30.0, 0.7, -160.0)
			scooter.rotation.y = PI
		for i in ROLLCALL.size():
			var mate := _shell(String(ROLLCALL[i][0]), "Mate%d" % i)
			if mate != null:
				mate.position = ROLLCALL_AT + Vector3(-2.6 + i * 2.6, 1.04, -0.2 * absf(i - 1))
	if _row.has("postcard"):
		_build_postcard(_row.postcard)


func _build_postcard(spec: Dictionary) -> void:
	var set_model := _postcard_model(String(spec.set))
	if set_model == null:
		return
	_postcard = Node3D.new()
	_postcard.name = "Postcard"
	_postcard.position = spec.at
	_postcard.visible = false
	_set.add_child(_postcard)
	_postcard.add_child(set_model)
	for piece: Dictionary in spec.dressing:
		_postcard_piece(piece)
	var water_spec: Dictionary = spec.water
	var tailwater := MeshInstance3D.new()
	tailwater.name = "Tailwater"
	var plane := PlaneMesh.new()
	plane.size = water_spec.size
	tailwater.mesh = plane
	tailwater.position = water_spec.at
	var wave_noise := FastNoiseLite.new()
	wave_noise.frequency = 0.018
	var ripples := NoiseTexture2D.new()
	ripples.noise = wave_noise
	ripples.seamless = true
	ripples.as_normal_map = true
	var water_colors := Gradient.new()
	water_colors.colors = PackedColorArray(POSTCARD_WATER_COLORS)
	var wave_tint := NoiseTexture2D.new()
	wave_tint.noise = wave_noise
	wave_tint.seamless = true
	wave_tint.color_ramp = water_colors
	var water := _flat(Color.WHITE)
	water.albedo_texture = wave_tint
	water.normal_enabled = true
	water.normal_texture = ripples
	water.uv1_scale = Vector3(4.0, 9.0, 1.0)
	water.roughness = 0.38
	tailwater.material_override = water
	_postcard.add_child(tailwater)

	var dawn: Dictionary = WorldLook.TIME_ROWS[String(spec.sky)].grade
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = dawn.top
	sky_material.sky_horizon_color = dawn.horizon
	sky_material.sky_curve = POSTCARD_SKY_CURVE
	sky_material.ground_horizon_color = dawn.horizon
	var sky := Sky.new()
	sky.sky_material = sky_material
	_postcard_env = environment.duplicate()
	_postcard_env.background_mode = Environment.BG_SKY
	_postcard_env.background_energy_multiplier = dawn.energy
	_postcard_env.sky = sky


func _postcard_model(path: String) -> Node3D:
	var model: Node3D = host.visual_scene(path, true)
	if model == null:
		host._warn(path)
		return null
	host._freeze_visual(model)
	dress(model, path)
	return model


func _postcard_piece(piece: Dictionary) -> void:
	var model := _postcard_model(String(piece.model))
	if model == null:
		return
	model.position = piece.at
	model.scale = piece.scale
	model.rotation_degrees.y = float(piece.yaw_deg)
	_postcard.add_child(model)


func _shell(class_id: String, label: String) -> Node3D:
	var path: String = HeroAssets.SHELLS.get(class_id, "")
	var shell: Node3D = host.visual_scene(path) if path != "" else null
	var def = ClassDef.by_id(class_id)
	var color: Color = def.color if def != null else Palette.COPPER
	if shell == null:
		host._warn(path)
		return _fallback(label, color)
	var pod := shell.find_child("Pod", true, false) as Node3D
	var painter := HeroAssets.new()
	painter.paint(shell, {"class": color})
	var fitted := {}
	if pod != null:
		fitted = painter.fit_pilot_into(pod, class_id, color)
		if not fitted.is_empty() and fitted.animator != null:
			fitted.animator.stop()
	painter.free()
	var holder := Node3D.new()
	holder.name = label
	holder.position = Vector3(0.0, 1.04, 0.0)
	_set.add_child(holder)
	holder.add_child(shell)
	host._freeze_visual(shell)
	_props[label] = holder
	if label == "Subject" and not fitted.is_empty():
		_antics = PilotAntics.new({"holder": holder, "core": shell.find_child("Core", true, false), "pod": pod,
			"pilot": fitted.pilot, "animator": fitted.animator}, class_id)
	return holder


func _model(path: String, label: String, fit: float) -> Node3D:
	var model: Node3D = host.visual_scene(path)
	if model == null:
		host._warn(path)
		return null
	var holder := Node3D.new()
	holder.name = label
	_set.add_child(holder)
	holder.add_child(model)
	host._freeze_visual(model)
	dress(model, path)
	var box := _bounds(model)
	var side := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if side > 0.001:
		var s := fit / side
		model.scale = Vector3.ONE * s
		model.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
	_props[label] = holder
	return holder


static func dress(model: Node, path: String) -> void:
	for view: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null:
			continue
		for i in view.mesh.get_surface_count():
			var drawn := _finished(view.mesh.surface_get_material(i), path)
			if drawn != null:
				view.set_surface_override_material(i, drawn)


static func _finished(source: Material, path: String) -> Material:
	if not (source is BaseMaterial3D):
		return null
	var slot := String(source.resource_name)
	var key := "%d:%s" % [source.get_instance_id(), path.get_base_dir()]
	if _finishes.has(key):
		return _finishes[key]
	var drawn: Material = null
	if path.begins_with(DIG_PARTS) and slot in DIG_SLOTS:
		var library: String = MaterialSlots.row(slot).get("path", "")
		drawn = load(library) as Material if library != "" and ResourceLoader.exists(library) else null
	if drawn == null:
		var copy := source.duplicate() as BaseMaterial3D
		copy.vertex_color_use_as_albedo = true
		if path.ends_with("dam.glb"):
			copy.albedo_color = DAM_TINT.get(slot, Color.WHITE)
			copy.roughness = DAM_ROUGHNESS.get(slot, 1.0)
		drawn = copy
	_finishes[key] = drawn
	return drawn


func _fallback(label: String, color: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	holder.position = Vector3(0.0, 1.04, 0.0)
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.98
	mesh.height = 1.96
	ball.mesh = mesh
	ball.material_override = _flat(color)
	holder.add_child(ball)
	_set.add_child(holder)
	_props[label] = holder
	return holder


func _bounds(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var local: Transform3D = (root as Node3D).global_transform.affine_inverse() * mesh.global_transform if root.is_inside_tree() else _relative(root, mesh)
		var part: AABB = local * mesh.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _relative(root: Node, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != root:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


func _height(node: Node3D) -> float:
	return _bounds(node).size.y if node != null else 1.0


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _enter_shot(shot: Dictionary) -> void:
	var kind := String(shot.kind)
	var world: int = int(_row.world)
	if _antics != null and kind != "antics":
		_antics.seat()
	_clear_overlay()
	environment.adjustment_enabled = false
	environment.background_energy_multiplier = SKY_ENERGY
	environment.background_color = WORLDS[world].sky
	camera.fov = 48.0
	for label in ["Chaser0", "Chaser1", "Chaser2"]:
		_show_prop(label, kind == "action")
	_show_prop("Barge", kind == "wink")
	_show_prop("UpIsland", kind == "up" and world != 3)
	if _subject != null:
		_subject.position = Vector3(0.0, 0.0 if _row.kind == "boss" else 1.04, 0.0)
	if _postcard != null:
		_postcard.visible = kind == "postcard"
		camera.environment = _postcard_env if _postcard.visible else environment
		_subject.scale = Vector3.ONE
		if _postcard.visible:
			var stand: Dictionary = _row.postcard.subject
			_subject.scale *= float(stand.scale)
			_subject.position = _postcard.position + Vector3(stand.at) + Vector3.UP * 1.04 * float(stand.scale)
			camera.fov = float(_row.postcard.camera.fov)
	var card: Array = _row.card
	var lines: Array = _row.lines
	var sfx: Array = _row.sfx
	match kind:
		"postcard":
			_caption(String(lines[0]), Vector2(0.03, 0.05))
			_pointer(TitleIntros.pointer_line(_row.id), Vector2(0.47, 0.56))
		"hero":
			camera.fov = 62.0
			_speed_lines()
			_sfx(String(sfx[0]), Vector2(0.06, 0.12), -10.0, 1.0)
		"card":
			camera.fov = 38.0 if reduced_motion else 34.0
			_name_card(card, _row.kind == "boss", Vector2(0.56, 0.12), 3.0)
		"antics":
			camera.fov = 44.0
			var pilot := String(_row.get("pilot", ""))
			_sfx(PilotAntics.word(pilot), Vector2(0.6, 0.1), 6.0, 0.9)
			_caption(PilotAntics.line(pilot), Vector2(0.04, 0.82))
		"action":
			camera.fov = 70.0
			_sfx(String(sfx[1]), Vector2(0.62, 0.08), 8.0, 1.0)
			_sfx(String(sfx[2]), Vector2(0.06, 0.66), -6.0, 0.95, Palette.HAZARD)
		"rollcall":
			for i in ROLLCALL.size():
				_caption("%s\n%s" % [ROLLCALL[i][1], ROLLCALL[i][2]], Vector2(0.08 + i * 0.31, 0.78))
		"collision":
			environment.background_color = Color("5a1a1c")
			environment.adjustment_enabled = true
			environment.adjustment_saturation = 1.3
			environment.adjustment_brightness = 0.85
			camera.fov = 70.0
		"rival":
			environment.background_color = Color("e88a6e")
			_name_card(TitleIntros.row("brindle").card, true, Vector2(0.54, 0.1), -3.0)
		"crash":
			environment.background_color = Color("10131a")
			environment.adjustment_enabled = true
			environment.adjustment_saturation = 0.3
			environment.adjustment_brightness = 0.75
			_rain()
			_caption(String(lines[1]), Vector2(0.7, 0.05))
			if _row.has("inset"):
				_caption(String(_row.inset), Vector2(0.04, 0.8), Color("e2c99c"))
		"wink":
			environment.background_color = Color("2a3140")
			environment.adjustment_enabled = true
			environment.adjustment_saturation = 0.7
			_caption(String(lines[2]), Vector2(0.04, 0.82))
			_sfx("ping", Vector2(0.58, 0.18), 0.0, 0.6, Palette.ARC)
		"up":
			environment.background_color = WORLDS[3].sky if world != 3 else Color("9cc4f5")
			camera.fov = 75.0
			_speed_lines()
		"slam":
			environment.background_color = _saved.background
			environment.background_energy_multiplier = _saved.energy
			camera.fov = _saved.fov
			_logo()


func _frame_shot(kind: String, t: float) -> void:
	var s := _subject_size
	var push := 0.0 if reduced_motion else t
	var at := Vector3.ZERO
	var look := Vector3.ZERO
	var roll := 0.0
	match kind:
		"postcard":
			if _postcard != null:
				var shot_camera: Dictionary = _row.postcard.camera
				at = _postcard.position + Vector3(shot_camera.at) + Vector3(shot_camera.drift) * push
				look = _postcard.position + Vector3(shot_camera.look)
			else:
				var world: int = int(_row.world)
				var behind: float = WORLDS[world].behind
				at = Vector3(-behind * 0.35, 3.0 + behind * 0.05, behind * 1.1)
				look = Vector3(4.0, behind * 0.32, -behind)
				at = at.lerp(look, 0.08 * push)
		"hero":
			at = Vector3(0.8, 0.25, 3.6) * s
			look = Vector3(0.0, 1.7, 0.0) * s
			roll = -8.0
			at = at.lerp(look, 0.12 * push)
		"card":
			at = Vector3(1.0, 1.0, 3.1) * s
			look = Vector3(0.0, 0.85, 0.0) * s
			roll = 5.0
			if _row.kind == "boss":
				at = Vector3(0.7, 1.3, 1.9) * s
				look = Vector3(0.0, 1.15, 0.0) * s
				roll = -4.0
		"antics":
			at = Vector3(0.9, 1.5, 6.4) * s
			look = Vector3(0.0, 0.9, 0.0) * s
			at = at.lerp(look, 0.06 * push)
			if _antics != null:
				_antics.calm = reduced_motion
				_antics.apply(t)
		"action":
			at = Vector3(-4.0, 2.4, 9.0) * s
			look = Vector3(0.4, 1.8, 0.0) * s
			roll = -14.0
			if _subject != null and _row.kind != "boss":
				_subject.position.y = 1.04 + sin(t * PI) * 3.2
		"rollcall":
			at = ROLLCALL_AT + Vector3(0.0, 1.6, 6.2)
			look = ROLLCALL_AT + Vector3(0.0, 1.0, 0.0)
			at = at.lerp(look, 0.1 * push)
		"collision":
			at = Vector3(7.0, 0.6, -146.0)
			look = Vector3(-1.0, 7.0, -160.0)
			roll = 16.0
		"rival":
			at = Vector3(30.8, 1.6, -157.4)
			look = Vector3(30.0, 1.2, -160.0)
			roll = -7.0
		"crash":
			at = Vector3(0.6, 2.2, 5.2) * s
			look = Vector3(0.0, 0.9, 0.0) * s
			at = at.lerp(look, 0.2 * push)
		"wink":
			at = Vector3(3.5, 0.9, 13.0)
			look = Vector3(-4.0, 9.0, -30.0)
		"up":
			at = Vector3(-4.0, -1.0, 26.0)
			look = Vector3(3.0, 16.0, -36.0)
			roll = 8.0
			if _subject != null and _row.kind != "boss":
				_subject.position.y = 1.04 + t * 22.0
		"slam":
			host._frame()
			return
	camera.position = SET_AT + at
	camera.look_at(SET_AT + look, Vector3.UP)
	if roll != 0.0:
		camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(roll))
	_track_pointer()


func _track_pointer() -> void:
	var pointer: Control = _overlay.get_node_or_null("Pointer") if _overlay != null else null
	if pointer == null or _subject == null or not camera.is_inside_tree():
		return
	var spot: Vector3 = _subject.global_position + Vector3(0.0, _subject_size * 2.4 * _subject.scale.y, 0.0)
	if camera.is_position_behind(spot):
		return
	var pixels := Vector2(host.viewport.size)
	var at := camera.unproject_position(spot) / pixels * _screen()
	pointer.position = at - Vector2(pointer.size.x * 0.5, pointer.size.y)


func _show_prop(label: String, on: bool) -> void:
	var prop: Node3D = _props.get(label)
	if prop != null:
		prop.visible = on


func _build_layer(picture: Texture2D) -> void:
	_layer = CanvasLayer.new()
	_layer.name = "TitleIntro"
	_layer.layer = LAYER
	add_child(_layer)
	var stage_picture := TextureRect.new()
	stage_picture.name = "IntroPicture"
	stage_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_picture.mouse_filter = Control.MOUSE_FILTER_STOP
	stage_picture.texture = picture
	_layer.add_child(stage_picture)
	_lines = Lines.new()
	_lines.name = "IntroLines"
	_lines.player = self
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_lines)
	_overlay = Control.new()
	_overlay.name = "IntroOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_overlay)
	var hint := _label("Any key skips", 18, PAPER, 2)
	hint.name = "SkipHint"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position -= Vector2(40.0, 40.0)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.modulate.a = 0.7
	_layer.add_child(hint)


func _clear_overlay() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	if _lines != null:
		_lines.mode = ""
	if _overlay == null:
		return
	for child in _overlay.get_children():
		_overlay.remove_child(child)
		child.queue_free()


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


func _label(text: String, font_size: int, color: Color, outline := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", INK)
		label.add_theme_constant_override("outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel(fill: Color, border := 4) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = INK
	box.set_border_width_all(border)
	box.shadow_color = INK
	box.shadow_offset = Vector2(6.0, 6.0)
	box.shadow_size = 1
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _caption(text: String, at: Vector2, fill := CAPTION_FILL) -> PanelContainer:
	var panel := _panel(fill, 3)
	panel.name = "Caption"
	panel.add_child(_label(text, 26, INK))
	panel.position = at * _screen()
	_overlay.add_child(panel)
	_pop(panel, 1.06)
	return panel


func _pointer(text: String, at: Vector2) -> void:
	var column := VBoxContainer.new()
	column.name = "Pointer"
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := _label(text, 36, CAPTION_FILL, 12)
	words.name = "Words"
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(words)
	var arrow := Control.new()
	arrow.name = "Arrow"
	arrow.custom_minimum_size = Vector2(0.0, POINTER_DROP)
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(arrow)
	var shaft := POINTER_DROP - POINTER_HEAD.y - 7.0
	var rim := Line2D.new()
	rim.width = 10.0
	rim.default_color = CAPTION_FILL
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = INK
	for i in 9:
		var u := float(i) / 8.0
		var point := Vector2(-POINTER_BOW * sin(u * PI), 6.0 + u * shaft)
		rim.add_point(point)
		line.add_point(point)
	arrow.add_child(rim)
	arrow.add_child(line)
	var head_rim := Polygon2D.new()
	head_rim.color = CAPTION_FILL
	head_rim.polygon = PackedVector2Array([Vector2(-POINTER_HEAD.x - 5.0, shaft), Vector2(POINTER_HEAD.x + 5.0, shaft),
		Vector2(0.0, POINTER_DROP)])
	arrow.add_child(head_rim)
	var head := Polygon2D.new()
	head.color = INK
	head.polygon = PackedVector2Array([Vector2(-POINTER_HEAD.x, shaft + 3.0), Vector2(POINTER_HEAD.x, shaft + 3.0),
		Vector2(0.0, POINTER_DROP - 4.0)])
	arrow.add_child(head)
	column.position = at * _screen()
	_overlay.add_child(column)
	_pop(column, 1.2)


func _name_card(card: Array, boss: bool, at: Vector2, tilt: float) -> void:
	var panel := _panel(BOSS_FILL if boss else PAPER, 5)
	panel.name = "NameCard"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	column.add_child(_label(String(card[0]), 60, Palette.HAZARD if boss else INK, 3 if boss else 0))
	column.add_child(_label(String(card[1]).to_upper(), 18, Color("4a4250")))
	for i in range(2, card.size() - 1, 2):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_label(String(card[i]), 24, INK))
		row.add_child(_label(String(card[i + 1]), 24, Color("4a4250")))
		column.add_child(row)
	panel.position = at * _screen()
	panel.rotation_degrees = tilt
	_overlay.add_child(panel)
	_pop(panel, 1.3)


func _sfx(text: String, at: Vector2, tilt: float, scale_by: float, fill := SFX_FILL) -> void:
	var label := _label(text, int(120 * scale_by), fill, 14)
	label.name = "Sfx"
	label.position = at * _screen()
	label.rotation_degrees = tilt
	_overlay.add_child(label)
	_pop(label, 1.5)


func _logo() -> void:
	var label: Control = Wordmark.view(_screen().y * 0.24) if Wordmark.texture() != null else _label("SCRAPKEEP", 150, Palette.ARC, 18)
	label.name = "Logo"
	if label is Label:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position.y = _screen().y * 0.08
	label.rotation_degrees = -3.0
	_overlay.add_child(label)
	_pop(label, 1.4)


func _speed_lines() -> void:
	if _lines != null:
		_lines.mode = "speed"


func _rain() -> void:
	if _lines != null:
		_lines.mode = "rain"


func _pop(node: Control, from: float) -> void:
	if reduced_motion or not is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)


class Catcher extends Node:
	var player

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if not is_instance_valid(player) or not player.playing:
			queue_free()
			return
		get_viewport().set_input_as_handled()
		if player.skips(event):
			player.skip()


class Lines extends Control:
	var player
	var mode := ""

	func _draw() -> void:
		if mode == "" or player == null:
			return
		var area := size
		var clock: float = 0.0 if player.reduced_motion else player.clock
		if mode == "speed":
			var centre := area * 0.5
			var reach := area.length()
			for i in 48:
				var angle := TAU * i / 48.0 + clock * 0.4
				var inner := centre + Vector2.from_angle(angle) * area.y * (0.36 + 0.05 * sin(i * 7.0 + clock * 9.0))
				draw_line(inner, centre + Vector2.from_angle(angle) * reach, Color(1.0, 1.0, 1.0, 0.32), 3.0)
		elif mode == "rain":
			var left := area.x * 0.32
			var width := area.x * 0.36
			for i in 70:
				var x := left + fmod(i * 37.0, width)
				var y := fmod(i * 53.0 + clock * 900.0, area.y + 60.0) - 60.0
				draw_line(Vector2(x, y), Vector2(x - 8.0, y + 46.0), Color(0.75, 0.82, 1.0, 0.45), 2.0)
