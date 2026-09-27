extends Control

const CodexStyle := preload("res://src/presentation/codex_style.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")

# The discovery banner: the category icon, a kicker ("New synergy" or "Found"), the
# name and one line of what it does. Per the UI regions rule (CONTRACTS) it sits in
# the toasts band, beside the HUD's centred toast column on the right, never in the
# top band (objective, status) or the prompts band; on a screen too narrow for that
# it drops just under the toasts band into the middle view. It slides in from the
# right edge,
# holds, and slides away, about 3 s in all on the real clock, so neither hit-stop nor
# a paused screen can pin it. Discoveries in quick succession queue and play one at a
# time. dismiss() clears it at once (presentation calls it on flow changes, arena
# entry, death and run end).

const HOLD := 2.5
const IN_TIME := 0.22
const OUT_TIME := 0.3
const WIDTH := 360.0
const MARGIN := 18.0
# The HUD's toast column width (hud.gd TOAST_WIDTH), which the banner stays beside.
const TOAST_COLUMN := 800.0

var shown := 0
var last_title := ""
# The clock in milliseconds; tests swap it for a fake.
var now_ms: Callable = Callable(Time, "get_ticks_msec")

var _queue: Array = []
var _started_ms := -1
var _panel: PanelContainer
var _icon: TextureRect
var _kicker: Label
var _title: Label
var _body: Label
var _style: StyleBoxFlat


func _init() -> void:
	name = "CodexBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_TOP_LEFT)
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
	_style.content_margin_left = 14
	_style.content_margin_right = 16
	_style.content_margin_top = 10
	_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", _style)
	_panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(44, 44)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_kicker = Label.new()
	_kicker.add_theme_font_size_override("font_size", 13)
	column.add_child(_kicker)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 15)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(WIDTH - 90.0, 0.0)
	_body.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	column.add_child(_body)
	visible = false


# kicker: "New synergy", "Synergy", "Found" or similar. While one is showing the next
# waits its turn.
func show_discovery(title: String, category: String, detail := "", kicker := "New synergy") -> void:
	_queue.append([title, category, detail, kicker])
	if not showing():
		_next()


func showing() -> bool:
	return _started_ms >= 0


func queued() -> int:
	return _queue.size()


# Gone at once. clear_queue also drops the discoveries still waiting.
func dismiss(clear_queue := true) -> void:
	_started_ms = -1
	visible = false
	if clear_queue:
		_queue.clear()


func _next() -> void:
	if _queue.is_empty():
		return
	var item: Array = _queue.pop_front()
	var entry := CodexStyle.category(item[1])
	var color: Color = entry["color"]
	_icon.texture = entry["icon"]
	_kicker.text = "%s  ·  %s" % [String(item[3]).to_upper(), String(entry["label"]).to_upper()]
	_kicker.add_theme_color_override("font_color", color)
	_title.text = item[0]
	_body.text = item[2]
	_body.visible = item[2] != ""
	_style.border_color = color
	shown += 1
	last_title = item[0]
	_started_ms = int(now_ms.call())
	visible = true
	_place(0.0)


func _process(_delta: float) -> void:
	if _started_ms < 0:
		return
	var t := (int(now_ms.call()) - _started_ms) / 1000.0
	var total := IN_TIME + HOLD + OUT_TIME
	if t >= total:
		dismiss(false)
		_next()
		return
	var slide := 1.0
	if t < IN_TIME:
		var x := t / IN_TIME
		slide = 1.0 + 0.08 * sin(x * PI) if x > 0.6 else x / 0.6
	elif t > IN_TIME + HOLD:
		slide = 1.0 - (t - IN_TIME - HOLD) / OUT_TIME
	_place(slide)


func _place(slide: float) -> void:
	_panel.position = Vector2(lerpf(_screen().x + MARGIN, rest_position().x, slide), rest_position().y)
	_panel.modulate.a = clampf(slide * 1.4, 0.0, 1.0)


# Where the banner rests on this screen: the toasts band's right side, or just under
# the band when the side is too narrow or the banner too tall for it.
func rest_position() -> Vector2:
	var screen := _screen()
	var band := ScreenRegions.rect("toasts", screen)
	var panel := _panel.get_combined_minimum_size()
	var x := screen.x - MARGIN - panel.x
	var beside := x >= (screen.x + TOAST_COLUMN) * 0.5 + MARGIN and panel.y <= band.size.y
	if beside:
		return Vector2(x, band.position.y)
	return Vector2(x, band.end.y + MARGIN)


func _screen() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)
