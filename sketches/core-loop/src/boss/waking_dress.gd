extends Node3D

const BossModel := preload("res://src/boss/boss_model.gd")
const Warden := preload("res://src/combat/warden.gd")
const Palette := preload("res://src/core/palette.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")

# The Waking's body: the hanging architecture (boss_waking_base.glb) and the combat seat's
# kit (boss_waking_kit.glb). Visual only. waking.gd still owns the floors, the drop timing
# and the Warden's seat; this node reads that state every physics frame and cues the clip
# that matches it, never a timer of its own. The architecture stays at the pit's centre;
# the kit rides under the Warden, so the core sits exactly at the Warden's family point.
# When either GLB is missing attach() returns null and the stub's Warden body is untouched.

const BASE := "res://assets/models/bosses/boss_waking_base.glb"
const KIT := "res://assets/models/bosses/boss_waking_kit.glb"
const CROWN := "res://assets/models/bosses/waking_drill_crown.glb"
const COLLARS := ["CollarSpoil", "CollarSeam", "CollarBedrock"]
# Floor k's collar and the clips that warn of its drop and show it.
const FLOOR_CLIPS := [["floor_warn", "floor_drop"], ["floor_warn_seam", "floor_drop_seam"], ["floor_warn_bedrock", "floor_drop_bedrock"]]
# The pulse clips key only these parts; they ride their own players so a charge beside a floor
# warn neither cuts the collar's rise nor leaves floor_drop starting from a half-raised collar.
const PULSE_KIT := ["PressureLip0", "PressureLip1", "PressureLip2"]
const PULSE_BASE := ["IntakeVane0", "IntakeVane1", "IntakeVane2"]
const PULSE_CLIPS := ["pulse_warn", "pulse"]
# The vanes also move in these base clips, so their tracks ride the vane player with the pulse.
const VANE_CLIPS := PULSE_CLIPS + ["sleeping", "wake", "pit_defeat"]
const CORE := ["CoreShutter0", "CoreShutter1", "CoreShutter2", "CoreLive", "CoreUnready", "ReactorCore"]
# Test seam: a test points these at a missing file to prove the stub body stays.
static var base_path := BASE
static var kit_path := KIT
static var crown_path := CROWN


static func reset_for_tests() -> void:
	base_path = BASE
	kit_path = KIT
	crown_path = CROWN
const BASE_PARTS := ["CombatSeat", "SpineInner", "IntakeVane0", "IntakeVane1", "IntakeVane2"]
const KIT_PARTS := ["CombatSeatAnchor", "CoreShutter0", "CoreLive", "CoreUnready", "PressureLip0", "CollarSpoil"]

var module
var base: Node3D
var kit: Node3D
var _base_anim: AnimationPlayer
var _kit_anim: AnimationPlayer
var _core_anim: AnimationPlayer
var _pulse_kit_anim: AnimationPlayer
var _pulse_base_anim: AnimationPlayer
var _seat: Node3D
var _crown: Node3D
var _intro_layer: CanvasLayer
var _intro_root: Control
var _intro_left := 0.0
var _open := false
var _charging := false
var _dropping := 0
var _defeated := false


# Builds the dress for a Waking module that has entered its arena; null leaves the stub body.
static func attach(owner_module):
	var base_scene := BossModel.load_scene(base_path)
	var kit_scene := BossModel.load_scene(kit_path)
	if base_scene == null or kit_scene == null or not _has_parts(base_scene, BASE_PARTS) or not _has_parts(kit_scene, KIT_PARTS):
		if base_scene != null:
			base_scene.free()
		if kit_scene != null:
			kit_scene.free()
		return null
	var dress = new()
	dress.name = "WakingDress"
	dress.module = owner_module
	owner_module.add_child(dress)
	dress.global_position = owner_module._center
	dress.setup(base_scene, kit_scene)
	return dress


static func _has_parts(scene: Node, parts: Array) -> bool:
	for part in parts:
		if scene.find_child(part, true, false) == null:
			return false
	return true


func setup(base_scene: Node3D, kit_scene: Node3D) -> void:
	base = base_scene
	kit = kit_scene
	base.name = "WakingBase"
	kit.name = "WakingKit"
	add_child(base)
	# The kit's root is the floor under the seat: the Warden stands HALF_HEIGHT above it.
	module.warden.add_child(kit)
	kit.position = Vector3.DOWN * Warden.HALF_HEIGHT
	_seat = base.find_child("CombatSeat", true, false)
	_enforce_guard1_materials(base)
	_enforce_guard1_materials(kit)
	_attach_drill_crown()
	_base_anim = BossModel.player_of(base)
	_kit_anim = BossModel.player_of(kit)
	BossModel.own_clips(_base_anim)
	BossModel.own_clips(_kit_anim)
	# Each collar keeps the pose its own floor clips leave; the spine keeps the length the last
	# floor drop gave it, instead of every other clip resetting it.
	for i in COLLARS.size():
		BossModel.strip_except(_kit_anim, COLLARS[i], FLOOR_CLIPS[i])
	BossModel.strip_except(_base_anim, "SpineInner", FLOOR_CLIPS[0] + FLOOR_CLIPS[1] + FLOOR_CLIPS[2] + ["pit_defeat"])
	# The core opens on its own player so a floor or pulse clip never closes it mid-stagger.
	_core_anim = BossModel.split_player(_kit_anim, ["core_open"], CORE)
	_pulse_kit_anim = BossModel.split_player(_kit_anim, PULSE_CLIPS, PULSE_KIT)
	_pulse_base_anim = BossModel.split_player(_base_anim, VANE_CLIPS, PULSE_BASE)
	BossModel.hide_warden_body(module.warden)
	_both("wake")
	_show_intro_card()


# Guard 1: Old Works petrol enamel (#365754) + uranium-glass green (#9DFF3C) seams only;
# replace any legacy blue vane inlay or warm brass highlight on the boss body.
static func _enforce_guard1_materials(root: Node) -> void:
	for view: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null:
			continue
		var count := view.mesh.get_surface_count()
		for s in count:
			var src := view.get_active_material(s)
			if not (src is StandardMaterial3D):
				continue
			var mat := src as StandardMaterial3D
			var mat_name := String(mat.resource_name).to_lower()
			var blue_emit := mat.emission_enabled and mat.emission.b > mat.emission.g * 1.15 and mat.emission.b > mat.emission.r * 1.15
			var blue_albedo := mat.albedo_color.b > mat.albedo_color.g * 1.2 and mat.albedo_color.b > mat.albedo_color.r * 1.2
			var brass_like := mat_name.contains("brass") or (mat.metallic > 0.35 and mat.albedo_color.r > 0.72 and mat.albedo_color.g > 0.55 and mat.albedo_color.b < 0.42)
			if blue_emit or blue_albedo or mat_name == "ancient_light":
				var updated := mat.duplicate() as StandardMaterial3D
				updated.albedo_color = Palette.ANCIENT
				updated.emission_enabled = true
				updated.emission = Palette.ANCIENT
				updated.emission_energy_multiplier = maxf(mat.emission_energy_multiplier, 2.4)
				view.set_surface_override_material(s, updated)
			elif brass_like or mat_name == "ancient_enamel":
				var updated := mat.duplicate() as StandardMaterial3D
				if brass_like:
					updated.albedo_color = Palette.VERDIGRIS
					updated.metallic = 0.16
					updated.roughness = 0.64
				else:
					updated.roughness = 0.60
				view.set_surface_override_material(s, updated)


# Cast petrol-enamel excavator drill crown with uranium-green seams (w2-boss-the-waking.png & g08).
# Attached to CombatSeat (under WakingBase, zero primitives) so it rides with the boss seat.
func _attach_drill_crown() -> void:
	if _seat == null or not ResourceLoader.exists(crown_path):
		return
	var scene := BossModel.load_scene(crown_path)
	if scene == null:
		return
	scene.name = "WakingDrillCrown"
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null:
			continue
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in view.mesh.get_surface_count():
			var src := view.mesh.surface_get_material(s)
			var slot := String(src.resource_name) if src != null else ""
			if slot == "ancient_light":
				view.set_surface_override_material(s, Palette.solid(Palette.ANCIENT, 2.8, false))
			else:
				var enamel := StandardMaterial3D.new()
				enamel.vertex_color_use_as_albedo = true
				enamel.roughness = 0.62
				enamel.metallic = 0.14
				view.set_surface_override_material(s, enamel)
	_seat.add_child(scene)
	scene.position = Vector3(0.0, -Warden.HALF_HEIGHT, 0.0)
	_crown = scene


# Guard 4: non-blocking, skippable freeze-frame intro card for The Waking (never pauses gameplay).
func _show_intro_card() -> void:
	var card := LoreRows.WAKING_INTRO_CARD
	var pilot_id := ""
	if module != null and module.ctx != null and module.ctx.get("pilot_id") != null:
		pilot_id = String(module.ctx.pilot_id)
	var threat := LoreRows.waking_intro_line(pilot_id)
	_intro_layer = CanvasLayer.new()
	_intro_layer.name = "WakingIntroCard"
	_intro_layer.layer = 40
	add_child(_intro_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(root)
	_intro_root = root

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 48.0
	panel.offset_right = -48.0
	panel.offset_top = -152.0
	panel.offset_bottom = -32.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.CHARCOAL, 0.88)
	style.border_color = Palette.ANCIENT
	style.border_width_left = 6
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var title := Label.new()
	title.text = "%s  —  %s" % [String(card["title"]), String(card["subtitle"])]
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Palette.ANCIENT)
	box.add_child(title)

	var line := Label.new()
	line.text = threat
	line.add_theme_font_size_override("font_size", 17)
	line.add_theme_color_override("font_color", Palette.SAND)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)

	_intro_left = float(card["duration_s"])


func dismiss_intro_card() -> void:
	_intro_left = 0.0
	if is_instance_valid(_intro_layer):
		_intro_layer.queue_free()
	_intro_layer = null
	_intro_root = null


func _input(event: InputEvent) -> void:
	if _intro_left <= 0.0:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("jump"):
		dismiss_intro_card()


func _physics_process(delta: float) -> void:
	if module == null or not is_instance_valid(module):
		queue_free()
		return
	if _intro_left > 0.0:
		_intro_left -= delta
		if _intro_left <= 0.0:
			dismiss_intro_card()
		elif is_instance_valid(_intro_root) and _intro_left < 0.45:
			_intro_root.modulate.a = clampf(_intro_left / 0.45, 0.0, 1.0)
	var warden = module.warden
	if is_instance_valid(warden):
		BossModel.hide_warden_body(warden)
		_seat.global_position = warden.global_position
		var open: bool = warden.staggered()
		if open != _open:
			_open = open
			BossModel.play(_core_anim, "core_open", not open)
		var charging: bool = warden._charging
		if charging != _charging:
			_charging = charging
			var pulse := "pulse_warn" if charging else "pulse"
			BossModel.play(_pulse_base_anim, pulse)
			BossModel.play(_pulse_kit_anim, pulse)
	var dropping: int = module._dropping
	if dropping != _dropping:
		if dropping != 0:
			_both(FLOOR_CLIPS[dropping - 1][0])
		else:
			_both(FLOOR_CLIPS[_dropping - 1][1])
		_dropping = dropping
	if module.state == module.DEFEATED and not _defeated:
		_defeated = true
		BossModel.play(_base_anim, "pit_defeat")
		BossModel.play(_pulse_base_anim, "pit_defeat")


func _both(clip: String) -> void:
	BossModel.play(_base_anim, clip)
	BossModel.play(_kit_anim, clip)
	if clip in VANE_CLIPS:
		BossModel.play(_pulse_base_anim, clip)
