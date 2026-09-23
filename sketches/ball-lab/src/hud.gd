extends CanvasLayer

const SpeedTier := preload("res://src/speed_tier.gd")

var player
var tuning

var _readout: Label
var _tier: Label


func setup(player_ref, tuning_ref) -> void:
	player = player_ref
	tuning = tuning_ref

	var box := VBoxContainer.new()
	box.position = Vector2(18.0, 14.0)
	add_child(box)

	_readout = _make_label(28)
	box.add_child(_readout)
	_tier = _make_label(22)
	box.add_child(_tier)

	var hint := _make_label(16)
	hint.text = "WASD move  ·  mouse look  ·  Space jump/double jump  ·  Shift boost  ·  Ctrl brake\nTab physics mode  ·  F1 tuning  ·  R respawn  ·  Esc free mouse (again to quit)"
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


func _process(_delta: float) -> void:
	if player == null:
		return
	var state = player.state
	var speed: float = state.velocity.length()
	_readout.text = "%s  ·  %.1f m/s  ·  %.0f km/h" % [player.mode_name(), speed, speed * 3.6]
	var tier: int = state.tier
	_tier.text = "%s%s%s" % [
		SpeedTier.label(tier),
		"  ·  airborne" if not state.grounded else "  ·  grounded",
		"  ·  air jump ready" if state.air_actions > 0 else "",
	]
	_tier.add_theme_color_override("font_color", SpeedTier.COLORS[tier])
