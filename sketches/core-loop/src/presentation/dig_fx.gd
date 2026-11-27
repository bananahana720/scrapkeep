extends Node3D

const FxLibrary := preload("res://src/presentation/fx_library.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const RUPTURE_SECONDS := 0.45
const BURST_SECONDS := 0.85
const GRIT_REACH := 22.0
const GRIT_INTERVAL := 0.2
const LAMP_SHADER_PATH := "res://assets/materials/dig_mechanical/lamp_motion.gdshader"
static var lamp_shader_path := LAMP_SHADER_PATH


static func reset_for_tests() -> void:
	lamp_shader_path = LAMP_SHADER_PATH

var available := false
var lamp_views: Array[MultiMeshInstance3D] = []
var faces: Array[Vector3] = []
var cable_pulses: Array = []
var skylight_shafts: Array = []
var card_colours := {}
var ruptures: Array = []
var bursts: Array = []
var grit: Array[GPUParticles3D] = []
var warning_count := 0
var active := true
var _stage_root: Node3D
var _map: RefCounted
var _shader: Shader
var _lamp_materials := {}
var _player
var _ctx
var _stage := 0
var _clock := 0.0
var _grit_wait := 0.0
var _ambient := true
var _grit_on := true
var _frozen := false
var _played := {}
var _cold_open_shown := false
var _card_layer: CanvasLayer
var _card_root: Control
var _card_title: Label
var _card_line: Label
var _card_queue: Array = []
var _card_left := 0.0


func prepare(stage_root: Node3D, map: RefCounted) -> void:
	_stage_root = stage_root
	_map = map
	if ResourceLoader.exists(lamp_shader_path):
		_shader = load(lamp_shader_path) as Shader
	if _shader != null:
		var uniforms := _shader.get_shader_uniform_list().map(func(row): return row["name"])
		available = uniforms.has("lens") and uniforms.has("spent") and _shader.code.contains("instance uniform float fx_time") \
			and _shader.code.contains("instance uniform bool motion_enabled")
	if not available:
		_warn_once("effect shader missing or malformed; breach covers keep the instant swap")


func finish_build() -> void:
	if available:
		for i in 2:
			var p := FxLibrary.build("dig_grit")
			p.name = "CutFaceGrit%d" % i
			p.set_instance_shader_parameter("tint", FxLibrary.colour("dig_grit", "breach_opened"))
			p.emitting = false
			add_child(p)
			grit.append(p)
	Kit.follow_quality(self)


func bind_context(ctx, stage: int) -> void:
	if _ctx == null:
		_ctx = ctx
		_stage = stage
		_player = ctx.player
		ctx.events.world_fact.connect(_on_world_fact)
		ctx.events.stage_entered.connect(_on_stage_entered)
		ctx.events.stage_content_cleared.connect(_on_content_cleared)
		if ctx.events.has_signal("boss_arena_entered"):
			ctx.events.boss_arena_entered.connect(_dismiss_cards)
		if ctx.events.has_signal("flow_changed"):
			ctx.events.flow_changed.connect(_on_flow_changed)
		if ctx.events.has_signal("rescue_completed"):
			ctx.events.rescue_completed.connect(_on_rescue_completed)
		ctx.terrain.stage_freed.connect(_on_stage_freed)
	_on_stage_entered(stage, false)


func _on_flow_changed(flow_state: String) -> void:
	if flow_state not in ["stage", "beacon", "gates"]:
		_dismiss_cards()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_dismiss_cards()


func _exit_tree() -> void:
	_dismiss_cards()


func _on_stage_freed(stage: int) -> void:
	if stage != _stage:
		return
	for row in [[_ctx.events.world_fact, _on_world_fact], [_ctx.events.stage_entered, _on_stage_entered],
			[_ctx.events.stage_content_cleared, _on_content_cleared], [_ctx.terrain.stage_freed, _on_stage_freed]]:
		if row[0].is_connected(row[1]):
			row[0].disconnect(row[1])
	if _ctx.events.has_signal("boss_arena_entered") and _ctx.events.boss_arena_entered.is_connected(_dismiss_cards):
		_ctx.events.boss_arena_entered.disconnect(_dismiss_cards)
	if _ctx.events.has_signal("flow_changed") and _ctx.events.flow_changed.is_connected(_on_flow_changed):
		_ctx.events.flow_changed.disconnect(_on_flow_changed)
	if _ctx.events.has_signal("rescue_completed") and _ctx.events.rescue_completed.is_connected(_on_rescue_completed):
		_ctx.events.rescue_completed.disconnect(_on_rescue_completed)
	_dismiss_cards()
	active = false
	set_process(false)


func _on_content_cleared(_reason: String) -> void:
	_deactivate()


func _on_stage_entered(stage: int, _retry: bool) -> void:
	clear()
	active = stage == _stage
	_sync_dressing()
	if active and not _cold_open_shown and _map != null and "park" in _map:
		var landmark_kind := String(_map.park.get("landmark", {}).get("kind", ""))
		var card := LoreRows.world_two_cold_open(landmark_kind)
		if not card.is_empty():
			_cold_open_shown = true
			_enqueue_card(String(card["title"]), "%s: %s" % [String(card["speaker"]), String(card["line"])], float(card["duration_s"]))


func _on_rescue_completed(quest_id: String) -> void:
	if not active or _map == null or not ("park" in _map):
		return
	var matched := false
	for row in _map.park.get("rescue_rows", []):
		if String(row.get("quest", "")) == quest_id:
			matched = true
			break
	if not matched:
		return
	for beat in LoreRows.kest_rescue_banter():
		_enqueue_card(String(beat["speaker"]).to_upper(), String(beat["line"]), float(beat["duration_s"]))


func _deactivate() -> void:
	clear()
	active = false
	_sync_dressing()


func _sync_dressing() -> void:
	var low := Kit.low_preset()
	_ambient = available and active and Kit.dressing_share("dig_lamp_motion", low) > 0.0
	_grit_on = available and active and Kit.dressing_share("dig_cut_grit", low) > 0.0
	lamp_views = lamp_views.filter(is_instance_valid)
	grit = grit.filter(is_instance_valid)
	for view in lamp_views:
		view.set_instance_shader_parameter("motion_enabled", _ambient)
	for p in grit:
		p.emitting = false
		p.visible = _grit_on
	for burst in bursts:
		for p: GPUParticles3D in burst["node"].get_children():
			p.amount_ratio = _burst_count(String(p.get_meta("kind"))) / float(p.amount)
	set_process(available and active)


func lamp_material(slot: String, fallback: Material) -> Material:
	if not available or slot not in ["steel", "glass"]:
		return fallback
	if not _lamp_materials.has(slot):
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("lens", slot == "glass")
		_lamp_materials[slot] = material
	return _lamp_materials[slot]


func _on_world_fact(kind: String, at: Vector3) -> void:
	if kind == "piece_shattered" and active and available:
		_spawn_strut_dust(at)
		return
	if kind != "breach_opened" or not active or not available or not "breach_plates" in _map:
		return
	for plate in _map.breach_plates:
		var rect: Rect2 = plate["rect"]
		if at.x >= rect.position.x and at.x <= rect.end.x and at.z >= rect.position.y and at.z <= rect.end.y:
			var id: String = plate["id"]
			var cover := _stage_root.get_node_or_null("BreachPlate_" + id) as Node3D
			if cover != null and not cover.visible and not _played.has(id):
				_rupture(id, cover, at)


func _rupture(id: String, cover: Node3D, at: Vector3) -> void:
	var skin := cover.get_node_or_null("BreachSkin") as Node3D
	if skin == null:
		return
	var wedges := skin.get_children().filter(func(n): return n is MeshInstance3D and n.get_meta("wedge", false))
	if wedges.size() != 3 or wedges.any(func(n): return n.mesh == null or n.material_override == null):
		_warn_once("breach skin missing or malformed; breach covers keep the instant swap")
		return
	_played[id] = true
	var ghost := skin.duplicate(0) as Node3D
	ghost.name = "DigRupture_" + id
	add_child(ghost)
	ghost.global_transform = _stage_root.global_transform * Transform3D(cover.basis, cover.get_meta("home")) * skin.transform
	var moving := []
	for view: MeshInstance3D in ghost.get_children():
		view.set_instance_shader_parameter("state_tint", Kit.dressing_colour("dig_spent"))
		if not view.get_meta("wedge", false):
			view.material_override = _spent_material()
			view.set_instance_shader_parameter("motion_enabled", false)
		if String(view.name).begins_with("tab_"):
			view.visible = false
		if view.get_meta("wedge", false):
			var outward := Vector3(view.position.x, 0, view.position.z).normalized()
			moving.append({"node": view, "rest": view.transform, "outward": outward})
	ruptures.append({"node": ghost, "wedges": moving, "age": 0.0})
	var burst := Node3D.new()
	burst.name = "DigBurst_" + id
	add_child(burst)
	burst.global_position = Vector3(at.x, ghost.global_position.y, at.z)
	for kind: String in ["debris", "dust"]:
		var fx_id: String = "dig_" + kind
		var p := FxLibrary.build(fx_id)
		p.name = kind.capitalize()
		p.set_meta("kind", kind)
		burst.add_child(p)
		FxLibrary.fire(p, fx_id, "breach_opened", _burst_count(kind), burst.global_position + p.position)
		p.amount_ratio = _burst_count(kind) / float(p.amount)
	bursts.append({"node": burst, "age": 0.0})


func _spent_material() -> ShaderMaterial:
	if not _lamp_materials.has("spent"):
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("spent", true)
		material.set_shader_parameter("spent_tint", Kit.dressing_colour("dig_spent"))
		_lamp_materials["spent"] = material
	return _lamp_materials["spent"]


static func _burst_count(kind: String) -> int:
	return int(FxLibrary.effects("breach_opened", "low" if Kit.low_preset() else "")["dig_" + kind])


func _process(delta: float) -> void:
	if _frozen or not active:
		return
	_clock += delta
	_tick_cards(delta)
	_tick_wayfinding_fx()
	if not available:
		return
	if _ambient:
		for view in lamp_views:
			view.set_instance_shader_parameter("fx_time", _clock)
	if _grit_on:
		_grit_wait -= delta
		if _grit_wait <= 0:
			_grit_wait = GRIT_INTERVAL
			_nearby_grit()
	for rupture in ruptures.duplicate():
		rupture["age"] += delta
		_pose(rupture, rupture["age"])
		if rupture["age"] >= RUPTURE_SECONDS:
			rupture["node"].queue_free()
			ruptures.erase(rupture)
	for burst in bursts.duplicate():
		burst["age"] += delta
		if burst["age"] >= BURST_SECONDS:
			burst["node"].queue_free()
			bursts.erase(burst)


func _tick_wayfinding_fx() -> void:
	var calm := UiTokens.reduced_motion or FlashGuard.on
	for row in cable_pulses:
		var node: MeshInstance3D = row["node"]
		if not is_instance_valid(node):
			continue
		var s := float(row["base_scale"])
		if not calm:
			var wave := 0.5 + 0.5 * sin(_clock * 3.8 - float(row["phase"]))
			s *= (0.86 + 0.28 * wave)
		node.scale = Vector3(s, s, s)
	for row in skylight_shafts:
		var node: MeshInstance3D = row["node"]
		if not is_instance_valid(node):
			continue
		var shimmer := 1.0 if calm else (0.85 + 0.15 * sin(_clock * 1.4 + float(row["phase"])))
		if node.material_override is ShaderMaterial:
			(node.material_override as ShaderMaterial).set_shader_parameter("alpha_scale", float(row["base_alpha"]) * shimmer)
		elif node.material_override is StandardMaterial3D:
			(node.material_override as StandardMaterial3D).albedo_color.a = float(row["base_alpha"]) * shimmer


func _spawn_strut_dust(at: Vector3) -> void:
	var burst := Node3D.new()
	burst.name = "DigStrutDust_%d" % bursts.size()
	add_child(burst)
	burst.global_position = at
	var p := FxLibrary.build("dig_dust")
	p.name = "Dust"
	p.set_meta("kind", "dust")
	burst.add_child(p)
	FxLibrary.fire(p, "dig_dust", "breach_opened", _burst_count("dust"), burst.global_position + p.position)
	p.amount_ratio = _burst_count("dust") / float(p.amount)
	bursts.append({"node": burst, "age": 0.0})


func _enqueue_card(title: String, line: String, duration_s: float) -> void:
	_card_queue.append({"title": title, "line": line, "duration_s": duration_s})
	if _card_left <= 0.0:
		_advance_card()


func _advance_card() -> void:
	if _card_queue.is_empty():
		_dismiss_cards()
		return
	var next: Dictionary = _card_queue.pop_front()
	_ensure_card_ui()
	_card_title.text = String(next["title"])
	_card_line.text = String(next["line"])
	_card_left = float(next["duration_s"])
	if is_instance_valid(_card_root):
		_card_root.visible = true
		_card_root.modulate.a = 1.0


func _ensure_card_ui() -> void:
	if is_instance_valid(_card_layer):
		return
	_card_layer = CanvasLayer.new()
	_card_layer.name = "DigStoryCard"
	_card_layer.layer = 35
	add_child(_card_layer)

	_card_root = Control.new()
	_card_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_layer.add_child(_card_root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 28.0
	panel.offset_right = 520.0
	panel.offset_top = -268.0
	panel.offset_bottom = -172.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_col: Color = card_colours.get("bg", Color(0.14, 0.16, 0.16, 1.0))
	var border_col: Color = card_colours.get("border", Kit.dressing_colour("dig_spent"))
	var title_col: Color = card_colours.get("title", Color(0.90, 0.63, 0.27, 1.0))
	var line_col: Color = card_colours.get("line", Color(0.82, 0.77, 0.65, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg_col, 0.86)
	style.border_color = border_col
	style.border_width_left = 5
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	_card_root.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 18)
	_card_title.add_theme_color_override("font_color", title_col)
	box.add_child(_card_title)

	_card_line = Label.new()
	_card_line.add_theme_font_size_override("font_size", 15)
	_card_line.add_theme_color_override("font_color", line_col)
	_card_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_card_line)


func _tick_cards(delta: float) -> void:
	if _card_left <= 0.0:
		return
	_card_left -= delta
	if _card_left <= 0.0:
		_advance_card()
	elif is_instance_valid(_card_root) and _card_left < 0.4:
		_card_root.modulate.a = clampf(_card_left / 0.4, 0.0, 1.0)


func _dismiss_cards() -> void:
	_card_queue.clear()
	_card_left = 0.0
	if is_instance_valid(_card_layer):
		_card_layer.free()
	_card_layer = null
	_card_root = null
	_card_title = null
	_card_line = null


func _input(event: InputEvent) -> void:
	if _card_left <= 0.0:
		return
	var accept := InputMap.has_action("ui_accept") and event.is_action_pressed("ui_accept")
	var cancel := InputMap.has_action("ui_cancel") and event.is_action_pressed("ui_cancel")
	var jump := InputMap.has_action("cl_jump") and event.is_action_pressed("cl_jump")
	if accept or cancel or jump:
		_advance_card()


static func _pose(rupture: Dictionary, seconds: float) -> void:
	var t := clampf(seconds / RUPTURE_SECONDS, 0, 1)
	var early := seconds <= 0.18
	var k := clampf(seconds / 0.18 if early else (seconds - 0.18) / 0.27, 0, 1)
	var drop := lerpf(0, 1.8, k) if early else lerpf(1.8, 7, k)
	var pitch := deg_to_rad(lerpf(0, 55, k) if early else lerpf(55, 105, k))
	for wedge in rupture["wedges"]:
		var rest: Transform3D = wedge["rest"]
		var outward: Vector3 = wedge["outward"]
		var axis := Vector3(-outward.z, 0, outward.x)
		wedge["node"].transform = Transform3D(Basis(axis, pitch) * rest.basis,
			rest.origin + outward * 0.8 * t + Vector3.DOWN * drop)


func _nearby_grit() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var ball: Vector3 = _player.shown_position()
	var local_ball := to_local(ball)
	var nearest: Array[Vector3] = []
	for face in faces:
		if face.distance_squared_to(local_ball) <= GRIT_REACH * GRIT_REACH:
			nearest.append(face)
	nearest.sort_custom(func(a, b): return a.distance_squared_to(local_ball) < b.distance_squared_to(local_ball))
	for i in grit.size():
		var p := grit[i]
		var emit := i < nearest.size()
		if emit and (not p.emitting or p.position != nearest[i]):
			p.position = nearest[i]
			p.restart()
		p.emitting = emit


func freeze_rupture(seconds: float = 0.18) -> void:
	_frozen = true
	for rupture in ruptures:
		rupture["age"] = seconds
		_pose(rupture, seconds)
	for burst in bursts:
		burst["age"] = seconds
		for p: GPUParticles3D in burst["node"].get_children():
			p.speed_scale = 0.0
	for p in grit:
		p.speed_scale = 0.0


func clear() -> void:
	_dismiss_cards()
	for row in ruptures + bursts:
		if is_instance_valid(row["node"]):
			row["node"].free()
	ruptures.clear()
	bursts.clear()
	_played.clear()
	_frozen = false
	grit = grit.filter(is_instance_valid)
	for p in grit:
		p.emitting = false
		p.speed_scale = 1.0


func _warn_once(message: String) -> void:
	if warning_count == 0:
		warning_count += 1
		push_warning("dig_fx: " + message)
