extends CanvasLayer

const Tuning := preload("res://src/movement/tuning.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")

var tuning

var _rows := {}
var _root: PanelContainer


func setup(tuning_ref) -> void:
	tuning = tuning_ref
	_root = PanelContainer.new()
	_root.position = Vector2(18.0, 96.0)
	_root.custom_minimum_size = Vector2(340.0, 0.0)
	add_child(_root)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_root.add_child(box)

	var title := Label.new()
	title.text = "Tuning (F1)"
	title.add_theme_font_size_override("font_size", UiTokens.BODY)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 0)
	box.add_child(grid)

	for spec in Tuning.SPECS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		grid.add_child(cell)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		cell.add_child(label)
		var slider := HSlider.new()
		slider.min_value = spec["min"]
		slider.max_value = spec["max"]
		slider.step = spec["step"]
		slider.value = tuning.base(spec["key"])
		slider.focus_mode = Control.FOCUS_NONE
		slider.custom_minimum_size = Vector2(300.0, 14.0)
		slider.value_changed.connect(_on_changed.bind(spec["key"]))
		cell.add_child(slider)
		_rows[spec["key"]] = {"label": label, "slider": slider, "spec": spec}

	var reset := Button.new()
	reset.text = "Reset defaults"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_on_reset)
	box.add_child(reset)

	visible = false
	_refresh()


func _process(_delta: float) -> void:
	if not visible or tuning == null:
		return
	for key in _rows:
		_rows[key]["slider"].set_value_no_signal(tuning.base(key))
	_refresh()


func _on_changed(value: float, key: String) -> void:
	tuning.set_value(key, value)
	_refresh()


func _on_reset() -> void:
	tuning.reset()
	for key in _rows:
		_rows[key]["slider"].set_value_no_signal(tuning.base(key))
	_refresh()


func _refresh() -> void:
	for key in _rows:
		var spec: Dictionary = _rows[key]["spec"]
		if spec.has("options"):
			_rows[key]["label"].text = "%s: %s (hold R to apply)" % [spec["label"], tuning.option(key)]
		elif spec.get("toggle", false):
			_rows[key]["label"].text = "%s: %s" % [spec["label"], "on" if tuning.on(key) else "off"]
		else:
			_rows[key]["label"].text = "%s: %.2f" % [spec["label"], tuning.base(key)]
