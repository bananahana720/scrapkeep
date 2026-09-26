extends CanvasLayer

const SpeedTier := preload("res://src/speed_tier.gd")
const Augments := preload("res://src/augments.gd")

const ON_COLOR := Color(0.75, 0.95, 0.80)
const OFF_COLOR := Color(0.55, 0.55, 0.58)
const AIM_READY := Color(1.0, 0.72, 0.30)
const AIM_IDLE := Color(0.85, 0.88, 0.92, 0.55)

var player
var tuning

var _readout: Label
var _tier: Label
var _augments := {}
var _crosshair: Label


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

	_crosshair = _make_label(26)
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-8.0, -18.0)
	add_child(_crosshair)

	var hint := _make_label(16)
	hint.text = "WASD move  ·  mouse look  ·  Space jump/double jump/hold to glide  ·  Shift boost or air dash  ·  Ctrl brake or slam\nRMB grapple (Q or wheel reels)  ·  E mag-cling  ·  1-5 augments  ·  Tab physics mode  ·  F1 tuning  ·  R respawn  ·  Esc free mouse (again to quit)"
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
	var aiming: bool = kit.on(Augments.GRAPPLE) and kit.aim_point != null
	_crosshair.add_theme_color_override("font_color", AIM_READY if aiming else AIM_IDLE)


func _live_note(kit, key: String) -> String:
	match key:
		Augments.GRAPPLE:
			return "  ·  hooked %.0f m" % kit.rope if kit.hooked else ""
		Augments.DASH:
			return "  ·  ready" if kit.dash_ready and not player.state.grounded else ""
		Augments.GLIDE:
			return "  ·  gliding" if kit.gliding else ""
		Augments.SLAM:
			return "  ·  slamming" if kit.slamming else ""
		Augments.CLING:
			return "  ·  clinging" if kit.clinging else ""
	return ""
