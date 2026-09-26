extends Control

const CodexStyle := preload("res://src/presentation/codex_style.gd")

# The discovery banner: the category icon, a kicker ("New synergy" or "Found"), the
# name and one line of what it does. It drops in from the top edge with an
# overshoot, holds, and slides away. Anchored high and centred, clear of the
# crosshair, so it never covers the next threat. Usable anywhere: the HUD, the codex
# page, or presentation's own layer.

const HOLD := 2.6
const IN_TIME := 0.22
const OUT_TIME := 0.3

var shown := 0
var last_title := ""

var _panel: PanelContainer
var _icon: TextureRect
var _kicker: Label
var _title: Label
var _body: Label
var _style: StyleBoxFlat
var _t := -1.0
var _rest_y := 64.0


func _init() -> void:
	name = "CodexBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.09, 0.1, 0.1, 0.88)
	_style.border_width_bottom = 4
	_style.border_width_top = 1
	_style.corner_radius_top_left = 6
	_style.corner_radius_top_right = 6
	_style.corner_radius_bottom_left = 6
	_style.corner_radius_bottom_right = 6
	_style.content_margin_left = 18
	_style.content_margin_right = 22
	_style.content_margin_top = 10
	_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", _style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(56, 56)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	_kicker = Label.new()
	_kicker.add_theme_font_size_override("font_size", 14)
	column.add_child(_kicker)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	column.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	column.add_child(_body)
	visible = false


# kicker: "New synergy", "Synergy", "Found" or similar.
func show_discovery(title: String, category: String, detail := "", kicker := "New synergy") -> void:
	var entry := CodexStyle.category(category)
	var color: Color = entry["color"]
	_icon.texture = entry["icon"]
	_kicker.text = "%s  ·  %s" % [kicker.to_upper(), String(entry["label"]).to_upper()]
	_kicker.add_theme_color_override("font_color", color)
	_title.text = title
	_body.text = detail
	_body.visible = detail != ""
	_style.border_color = color
	shown += 1
	last_title = title
	_t = 0.0
	visible = true
	_place(0.0)


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	# Real time, so a hit-stop never freezes the banner.
	_t += delta / maxf(Engine.time_scale, 0.05)
	var total := IN_TIME + HOLD + OUT_TIME
	if _t >= total:
		_t = -1.0
		visible = false
		return
	var slide := 1.0
	if _t < IN_TIME:
		var x := _t / IN_TIME
		slide = 1.0 + 0.12 * sin(x * PI) if x > 0.6 else x / 0.6
	elif _t > IN_TIME + HOLD:
		slide = 1.0 - (_t - IN_TIME - HOLD) / OUT_TIME
	_place(slide)


func _place(slide: float) -> void:
	var size := _panel.get_combined_minimum_size()
	_panel.position = Vector2(-size.x * 0.5, lerpf(-size.y - 8.0, _rest_y, slide))
	_panel.modulate.a = clampf(slide * 1.4, 0.0, 1.0)
