extends CanvasLayer

const Tuning := preload("res://src/tuning.gd")

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
	box.add_theme_constant_override("separation", 1)
	_root.add_child(box)

	var title := Label.new()
	title.text = "Tuning (F1)"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	for spec in Tuning.SPECS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 14)
		box.add_child(label)
		var slider := HSlider.new()
		slider.min_value = spec["min"]
		slider.max_value = spec["max"]
		slider.step = spec["step"]
		slider.value = tuning.f(spec["key"])
		slider.focus_mode = Control.FOCUS_NONE
		slider.custom_minimum_size = Vector2(300.0, 14.0)
		slider.value_changed.connect(_on_changed.bind(spec["key"]))
		box.add_child(slider)
		_rows[spec["key"]] = {"label": label, "slider": slider, "spec": spec}

	var reset := Button.new()
	reset.text = "Reset defaults"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_on_reset)
	box.add_child(reset)

	visible = false
	_refresh()


func _on_changed(value: float, key: String) -> void:
	tuning.set_value(key, value)
	_refresh()


func _on_reset() -> void:
	tuning.reset()
	for key in _rows:
		_rows[key]["slider"].set_value_no_signal(tuning.f(key))
	_refresh()


func _refresh() -> void:
	for key in _rows:
		var spec: Dictionary = _rows[key]["spec"]
		_rows[key]["label"].text = "%s: %.2f" % [spec["label"], tuning.f(key)]
