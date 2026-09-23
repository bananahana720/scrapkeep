extends CanvasLayer

const Materials := preload("res://src/materials.gd")
const RunState := preload("res://src/run_state.gd")

var _veil: ColorRect
var _title: Label
var _body: Label


func setup() -> void:
	layer = 2
	_veil = ColorRect.new()
	_veil.color = Color(Materials.CHARCOAL.r, Materials.CHARCOAL.g, Materials.CHARCOAL.b, 0.82)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-320.0, -110.0)
	box.custom_minimum_size = Vector2(640.0, 0.0)
	_veil.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 64)
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 26)
	box.add_child(_body)

	visible = false


func show_result(run_state) -> void:
	var cleared: bool = run_state.phase == RunState.CLEARED
	_title.text = "Stage clear" if cleared else "Scrapped"
	_title.add_theme_color_override("font_color", Materials.ARC if cleared else Materials.RUST)
	var minutes := int(run_state.stage_time) / 60
	var seconds := int(run_state.stage_time) % 60
	_body.text = "time %d:%02d\nscrap %d\ncaches %d%s\n%s\n\nR to restart" % [
		minutes, seconds, run_state.scrap, run_state.caches_opened,
		"  (secret found)" if run_state.secret_found else "",
		run_state.buff_summary(),
	]
	visible = true


func hide_result() -> void:
	visible = false
