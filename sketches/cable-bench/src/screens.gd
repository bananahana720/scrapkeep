extends CanvasLayer

const Palette := preload("res://src/palette.gd")
const RunState := preload("res://src/run_state.gd")

var _panel: ColorRect
var _title: Label
var _body: Label


func setup() -> void:
	layer = 2
	_panel = ColorRect.new()
	_panel.color = Color(Palette.CHARCOAL.r, Palette.CHARCOAL.g, Palette.CHARCOAL.b, 0.82)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-380.0, -120.0)
	box.custom_minimum_size = Vector2(760.0, 240.0)
	_panel.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 58)
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 24)
	box.add_child(_body)
	visible = false


func show_result(run, loadout) -> void:
	var cleared: bool = run.phase == RunState.Phase.CLEAR
	_title.text = "STAGE CLEAR" if cleared else "SCRAPPED"
	_title.add_theme_color_override("font_color", Palette.ARC if cleared else Palette.RUST)
	_body.text = "\n".join([
		"time        %02d:%05.2f" % [int(run.stage_time / 60.0), fmod(run.stage_time, 60.0)],
		"difficulty  tier %d" % run.tier(),
		"scrap       %d held, %d collected" % [run.scrap, run.scrap_taken],
		"caches      %d opened" % run.caches_opened,
		"buffs       %s" % loadout.summary(),
		"",
		"R to run it again",
	])
	visible = true
