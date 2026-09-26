extends CanvasLayer

const SpeedTier := preload("res://src/speed_tier.gd")
const Augments := preload("res://src/augments.gd")
const AimReticle := preload("res://src/aim_reticle.gd")
const FieldNotes := preload("res://src/field_notes.gd")

const ON_COLOR := Color(0.75, 0.95, 0.80)
const OFF_COLOR := Color(0.55, 0.55, 0.58)
const PLACEHOLDER_COLOR := Color(1.0, 0.55, 0.85)

var player
var tuning
var reticle

var _readout: Label
var _tier: Label
var _augments := {}
var _mounted: Label
var _toast: Label
var _toast_left := 0.0


func setup(player_ref, tuning_ref, camera: Camera3D = null) -> void:
	player = player_ref
	tuning = tuning_ref

	var box := VBoxContainer.new()
	box.position = Vector2(18.0, 14.0)
	add_child(box)

	_readout = _make_label(28)
	box.add_child(_readout)
	_tier = _make_label(22)
	box.add_child(_tier)

	var list := VBoxContainer.new()
	list.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	list.position = Vector2(-330.0, 14.0)
	list.add_theme_constant_override("separation", 1)
	add_child(list)
	var list_title := _make_label(16)
	list_title.text = "augments (1-5 toggle)"
	list.add_child(list_title)
	for i in Augments.SPECS.size():
		var spec: Dictionary = Augments.SPECS[i]
		var row := _make_label(15)
		list.add_child(row)
		_augments[spec["key"]] = {"row": row, "spec": spec, "index": i + 1}

	reticle = AimReticle.new()
	add_child(reticle)
	reticle.setup(player, camera)

	_mounted = _make_label(18)
	_mounted.text = "MOUNTED  ·  LMB zap (PLACEHOLDER weapon)  ·  Space jump off  ·  E drop"
	_mounted.add_theme_color_override("font_color", PLACEHOLDER_COLOR)
	_mounted.set_anchors_preset(Control.PRESET_CENTER)
	_mounted.position = Vector2(-300.0, 150.0)
	_mounted.visible = false
	add_child(_mounted)

	_toast = _make_label(16)
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast.position = Vector2(18.0, -92.0)
	add_child(_toast)

	var hint := _make_label(16)
	hint.text = FieldNotes.hint_rows()
	hint.position = Vector2(18.0, 0.0)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(18.0, -58.0)
	bottom.add_child(hint)
	add_child(bottom)


func _make_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	return label


func toast(text: String) -> void:
	_toast.text = text
	_toast_left = 4.0


func _process(delta: float) -> void:
	if player == null:
		return
	_toast_left = maxf(0.0, _toast_left - delta)
	_toast.visible = _toast_left > 0.0
	var state = player.state
	var speed: float = state.velocity.length()
	_readout.text = "%s  ·  interp %s  ·  %.1f m/s  ·  %.0f km/h" % [player.mode_name(),
		"ON" if get_tree().physics_interpolation else "off", speed, speed * 3.6]
	var tier: int = state.tier
	_tier.text = "%s%s%s" % [
		SpeedTier.label(tier),
		"  ·  airborne" if not state.grounded else "  ·  grounded",
		"  ·  air jump ready" if state.air_actions > 0 else "",
	]
	_tier.add_theme_color_override("font_color", SpeedTier.COLORS[tier])
	_refresh_augments()


func _refresh_augments() -> void:
	var kit = player.kit
	for key in _augments:
		var row: Dictionary = _augments[key]
		var label: Label = row["row"]
		var live := _live_note(kit, key)
		label.text = "%d  %s  %s%s" % [row["index"], row["spec"]["label"],
			"ON" if kit.on(key) else "off", live]
		label.add_theme_color_override("font_color", ON_COLOR if kit.on(key) else OFF_COLOR)
	_mounted.visible = kit.mounted


func _live_note(kit, key: String) -> String:
	match key:
		Augments.GRAPPLE:
			if not kit.hooked:
				return ""
			return "  ·  hooked %.0f m%s" % [kit.rope, "  ·  winching" if player.intent.reel_held else ""]
		Augments.DASH:
			return "  ·  ready" if kit.dash_ready and not player.state.grounded else ""
		Augments.GLIDE:
			return "  ·  gliding" if kit.gliding else ""
		Augments.SLAM:
			if kit.plant_time > 0.0:
				return "  ·  planted"
			return "  ·  slamming" if kit.slamming else ""
		Augments.PYLON:
			return "  ·  mounted" if kit.mounted else ""
	return ""
