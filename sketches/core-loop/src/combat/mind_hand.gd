extends "res://src/combat/counter.gd"

const Habits := preload("res://src/combat/habits.gd")
const Icons := preload("res://src/ui/icons.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const AllyHusk := preload("res://src/combat/ally_husk.gd")

const LANE_LENGTH := 18.0
const LANE_WIDTH := 2.6
const STRIKE_DAMAGE := 10.0
const STRIKE_SHOVE := 6.0
const WARN := 1.4
const BRACE := 5.0
const BRACE_MULT := 1.6
const PLATING_SCALE := 0.5
const HP := 90.0
const ARM_HEIGHT := 4.2
const LENS_RADIUS := 0.7
const TAKEOVER_RANGE := 24.0
const TAKEOVER_COOLDOWN := 8.0
const HIT_FLASH_SECONDS := 0.08
const FLASH_DECAY := 2.5
const HIT_FLASH_SPEEDUP := 1.0 / (FLASH_DECAY * HIT_FLASH_SECONDS)
const MODEL := "res://assets/models/bosses/mind_hand.glb"

static var model_path := MODEL
static var _warned_models := {}
static var _rim_masks := {}


static func reset_for_tests() -> void:
	model_path = MODEL

var habit := ""
var braced_kinds: Array = []
var adaptations := 0
var strikes_landed := 0
var takeovers_started := 0
var takeovers_interrupted := 0
var takeovers_completed := 0
var boss_phase := 1
var _takeover_husk: AllyHusk.HuskUnit = null
var _takeover_cd := 2.0
var _lens: Node3D
var _lens_glass: MeshInstance3D
var _icon: Sprite3D
var _joints: Array = []
var _model: Node3D
var _anim: AnimationPlayer
var _seen_phase := -1
var _skin_rim: StandardMaterial3D
var _skin_rim_albedo := Color.WHITE


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	plating = float(spec.get("plating", 20.0))
	scrap_value = 10
	weight = 2.5
	walk_speed = 2.2
	keep_near = 11.0
	keep_far = 24.0
	attack_range = 17.0
	warn_seconds = WARN
	live_seconds = BRACE
	rest_seconds = 3.0
	interruptible = false


func _update_flash(delta: float) -> void:
	super._update_flash(delta * HIT_FLASH_SPEEDUP)


func braced() -> bool:
	return phase == Phase.LIVE and habit != ""


func lens_point() -> Vector3:
	return _lens.global_position if _lens != null else global_position + Vector3.UP * ARM_HEIGHT


func plating_for(hit_kind: String, part: String) -> float:
	if part == "takeover_node" and is_instance_valid(_takeover_husk) and _takeover_husk.takeover_active:
		return 0.0
	if part == "lens" and braced():
		return 0.0
	if braced() and hit_kind in braced_kinds:
		return plating * BRACE_MULT
	return plating


func weak_points() -> Array:
	var out: Array = []
	if is_instance_valid(_takeover_husk) and _takeover_husk.takeover_active:
		out.append({"id": "takeover_node", "at": _takeover_husk.takeover_node_pos, "radius": AllyHusk.TAKEOVER_NODE_RADIUS})
	if braced():
		out.append({"id": "lens", "at": lens_point(), "radius": LENS_RADIUS})
	return out


func _physics_process(delta: float) -> void:
	super(delta)
	if _dead or not _in_play():
		return
	_takeover_cd = maxf(0.0, _takeover_cd - delta)
	if is_instance_valid(_takeover_husk):
		if not _takeover_husk.takeover_active:
			_takeover_husk = null
		return
	if phase == Phase.ROAM and not stunned() and _takeover_cd <= 0.0:
		_try_husk_takeover()


func _ally_husks():
	if world_root == null:
		return null
	var combat = world_root.get_node_or_null("Combat")
	return combat.get("ally_husks") if combat != null else null


func _try_husk_takeover() -> bool:
	var mgr = _ally_husks()
	if mgr == null or not mgr.has_method("first_takeover_target"):
		return false
	var husk: AllyHusk.HuskUnit = mgr.first_takeover_target(global_position, TAKEOVER_RANGE)
	if husk == null:
		return false
	return attempt_husk_takeover(husk)


func attempt_husk_takeover(husk: AllyHusk.HuskUnit) -> bool:
	var mgr = _ally_husks()
	if mgr == null or husk == null or not is_instance_valid(husk):
		return false
	if not mgr.begin_takeover(husk, self, AllyHusk.TAKEOVER_WARN_SECONDS):
		return false
	_takeover_husk = husk
	takeovers_started += 1
	_facing(husk.global_position - global_position)
	return true


func on_struck(hit_kind: String, part: String, _result: Dictionary) -> void:
	if is_instance_valid(_takeover_husk) and _takeover_husk.takeover_active:
		var mgr = _ally_husks()
		if mgr != null and (part == "takeover_node" or hit_kind != ""):
			mgr.interrupt_takeover(_takeover_husk, "shot" if part == "takeover_node" else hit_kind)


func on_takeover_interrupted(_husk) -> void:
	_takeover_husk = null
	_takeover_cd = TAKEOVER_COOLDOWN
	takeovers_interrupted += 1
	_end()
	staggers += 1
	stun_left = maxf(stun_left, AllyHusk.TAKEOVER_STUN_SECONDS)


func on_takeover_completed(_husk) -> void:
	_takeover_husk = null
	_takeover_cd = TAKEOVER_COOLDOWN
	takeovers_completed += 1


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range and fleet != null and fleet.habits.top() != ""


func _commit(to_ball: Vector3) -> Node3D:
	habit = fleet.habits.top()
	if habit == "":
		return null
	var brace: Dictionary = Habits.BRACES[habit]
	braced_kinds = brace["kinds"]
	_facing(to_ball)
	var lane := _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)
	adaptations += 1
	fleet.mind_adapt(habit, String(brace["icon"]), lens_point())
	_show_icon(String(brace["icon"]))
	return lane


func _go_live() -> void:
	var lane := telegraph()
	if lane != null and lane.contains(_real_ball()):
		strikes_landed += 1
		hit_player.emit(ChallengeDials.damage("mind", STRIKE_DAMAGE, boss_phase), lane.dir * STRIKE_SHOVE)
	if fleet != null:
		fleet.events().weak_point_opened.emit("lens", lens_point(), BRACE)


func _live(_delta: float) -> bool:
	return true


func _on_end() -> void:
	habit = ""
	braced_kinds = []
	if _icon != null:
		_icon.visible = false


func _show_icon(id: String) -> void:
	if _icon == null:
		return
	_icon.texture = Icons.texture(id)
	_icon.modulate = Palette.HAZARD
	_icon.visible = true


func _build_crew() -> void:
	radius = 0.7
	half_height = 1.8
	_crew = _add_capsule(0.7, 3.6, Roster.ANCIENT_ENAMEL)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.5
	foot.bottom_radius = 1.1
	foot.height = 0.5
	var base := MeshInstance3D.new()
	base.mesh = foot
	base.material_override = _enamel()
	base.position = Vector3(0.0, -1.55, 0.0)
	_visual_parent().add_child(base)
	var at := Vector3(0.0, -1.3, 0.0)
	for i in 3:
		var joint := Node3D.new()
		joint.position = at
		_visual_parent().add_child(joint)
		_joints.append(joint)
		var bone := MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = 0.14
		rod.bottom_radius = 0.18
		rod.height = 1.6
		bone.mesh = rod
		bone.material_override = _plate_material() if i == 1 else _enamel()
		bone.position = Vector3(0.0, 0.8, 0.0)
		joint.add_child(bone)
		if i == 1:
			_add_crack(bone, Vector3(0.0, 0.0, 0.2), 0.7)
		_seam(Vector3(0.4, 0.06, 0.4), Vector3.ZERO, joint)
		at += Vector3.UP * 1.6
	_lens = Node3D.new()
	_lens.position = Vector3(0.0, ARM_HEIGHT - 0.8, 0.0)
	add_child(_lens)
	var glass := SphereMesh.new()
	glass.radius = LENS_RADIUS
	glass.height = LENS_RADIUS * 2.0
	_lens_glass = MeshInstance3D.new()
	_lens_glass.mesh = glass
	_lens_glass.material_override = Palette.solid(Roster.ANCIENT_LIGHT, 1.2)
	_lens.add_child(_lens_glass)
	for side in [-1.0, 1.0]:
		var small := SphereMesh.new()
		small.radius = 0.25
		small.height = 0.5
		var eye := MeshInstance3D.new()
		eye.mesh = small
		eye.material_override = Palette.solid(Roster.ANCIENT_LIGHT, 0.8)
		eye.position = Vector3(side * 0.75, -0.2, 0.2)
		_lens.add_child(eye)
	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.pixel_size = 0.02
	_icon.position = Vector3(0.0, 1.3, 0.0)
	_icon.visible = false
	_lens.add_child(_icon)
	_dress_model()


func _dress_model() -> void:
	var loaded := BossModel.load_scene(model_path)
	if loaded == null:
		_warn_model("model unavailable")
		return
	var player := BossModel.player_of(loaded)
	var skin := loaded.find_child("MindHandSkin", true, false) as MeshInstance3D
	if skin == null or skin.mesh == null or player == null or not player.has_animation("still_track"):
		loaded.free()
		_warn_model("malformed skin")
		return
	var body_surface := -1
	var rim_surface := -1
	for i in skin.mesh.get_surface_count():
		var mat := skin.mesh.surface_get_material(i) as StandardMaterial3D
		if mat == null:
			continue
		if mat.resource_name.begins_with("M1"):
			body_surface = i
		elif mat.resource_name.begins_with("M4") and mat.albedo_texture != null:
			rim_surface = i
	if body_surface < 0 or rim_surface < 0:
		loaded.free()
		_warn_model("skin lacks body or signal material")
		return
	var rim_source := skin.mesh.surface_get_material(rim_surface) as StandardMaterial3D
	var rim_mask := _skin_rim_mask(rim_source.albedo_texture)
	if rim_mask == null:
		loaded.free()
		_warn_model("signal texture unavailable")
		return
	_material = skin.mesh.surface_get_material(body_surface).duplicate() as StandardMaterial3D
	_base_color = _material.albedo_color
	skin.set_surface_override_material(body_surface, _material)
	_skin_rim = rim_source.duplicate() as StandardMaterial3D
	_skin_rim_albedo = _skin_rim.albedo_color
	_skin_rim.emission_texture = rim_mask
	_skin_rim.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_tint_materials.append(_skin_rim)
	skin.set_surface_override_material(rim_surface, _skin_rim)
	_paint_plate(_skin_rim, tint_state)
	_skin_rim.albedo_color = _skin_rim_albedo
	for mesh in _visual_parent().find_children("*", "MeshInstance3D", true, false):
		BossModel.hide_primitive(mesh)
	for mesh in _lens.find_children("*", "MeshInstance3D", true, false):
		BossModel.hide_primitive(mesh)
	loaded.name = "MindHandModel"
	_visual_parent().add_child(loaded)
	_model = loaded
	_anim = player
	BossModel.own_clips(_anim)
	BossModel.loop_clip(_anim, "still_track")
	_anim.set_blend_time("exact_strike", "brace", BossModel.blend_for("brace"))
	_anim.set_blend_time("recover", "still_track", BossModel.blend_for("still_track"))
	BossModel.play(_anim, "still_track")


func _skin_rim_mask(texture: Texture2D) -> ImageTexture:
	if _rim_masks.has(texture):
		return _rim_masks[texture]
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	var mask := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var seam := color.b > 0.75 and color.r < 0.35 and color.g < 0.65
			mask.set_pixel(x, y, Color.WHITE if seam else Color.BLACK)
	var result := ImageTexture.create_from_image(mask)
	_rim_masks[texture] = result
	return result


func _warn_model(reason: String) -> void:
	if not _warned_models.has(model_path):
		_warned_models[model_path] = true
		push_warning("mind_hand: %s '%s'; keeping the primitive hand" % [reason, model_path])


func set_tint(state: String) -> void:
	super.set_tint(state)
	if _skin_rim != null:
		_skin_rim.albedo_color = _skin_rim_albedo


func _cue_model() -> void:
	if _anim == null or phase == _seen_phase:
		return
	var from := _seen_phase
	_seen_phase = phase
	match phase:
		Phase.WARN:
			BossModel.play(_anim, "quote_warn")
		Phase.LIVE:
			BossModel.play(_anim, "exact_strike")
			_anim.queue("brace")
		Phase.ROAM:
			if from != -1:
				BossModel.play(_anim, "recover")
				_anim.queue("still_track")


func _pose() -> void:
	_cue_model()
	if _lens == null or target == null:
		return
	var to := _ball() - _lens.global_position
	if to.length() > 0.5:
		_lens.global_basis = Basis.looking_at(to.normalized(), Vector3.UP if absf(to.normalized().y) < 0.95 else Vector3.FORWARD)
	var open := 1.5 if braced() else (1.0 + 0.3 * clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 1.0)
	_lens_glass.scale = Vector3.ONE * open
	(_lens_glass.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if braced() else 1.2
	if phase == Phase.WARN and not _joints.is_empty():
		(_joints[1] as Node3D).rotation.x = -0.5 * clampf(_t / warn_seconds, 0.0, 1.0)
	elif not _joints.is_empty():
		(_joints[1] as Node3D).rotation.x = 0.0
