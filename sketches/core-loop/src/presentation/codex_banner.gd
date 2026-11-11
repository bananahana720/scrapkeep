extends Control

const CodexStyle := preload("res://src/presentation/codex_style.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const WhyCallout := preload("res://src/ui/why_callout.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")

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
#
# A first-discovery card raised in a fight waits at the head of the queue and shows at the
# next time the screen's one gate says so (screen_busy.gd): quiet for the finds' hold. One
# raised when the gate is already open shows at once. Whatever is showing closes when a
# Warden fight goes live. In cards mode at most MAX_HELD wait and a repeat shows nothing; in
# banner mode presentation drops a repeat synergy before it reaches the queue. The banner
# finds the bus and the flow through its presentation ancestor, or a test hands it a bus
# with watch().
#
# `--discovery=cards` (cards = true, profile set by the owner): the first time an id is
# discovered a picture card lands in the same slot: a larger panel with a looping
# animated glyph drawn from the discovery's EventKinds shape and colour, the name and
# its one line. Every later time shows nothing: the part's name at the ball is enough. The
# card never pauses the game or touches Engine.time_scale; any input dismisses it at
# once and is left unhandled, so play never notices. It uses the banner's slot in the
# toasts band, so the calm-screen word budget is unchanged. Off, none of this runs.

const HOLD := 2.5
const IN_TIME := 0.22
const OUT_TIME := 0.3
const WIDTH := 360.0
const MARGIN := 18.0
# The HUD's toast column width (hud.gd TOAST_WIDTH), which the banner stays beside.
const TOAST_COLUMN := 800.0
# The first-discovery card (cards mode) and the most that wait for the gate. A card holds
# CARD_HOLD for a line of up to CARD_WORDS words and CARD_WORD_HOLD more for each word past
# that, up to CARD_HOLD_MAX, so a long line stays up long enough to read to its end.
const CARD_HOLD := 4.0
const CARD_WORDS := 18
const CARD_WORD_HOLD := 0.2
const CARD_HOLD_MAX := 8.0
const MAX_HELD := 3
const GLYPH_CARD := 132.0
# A card is this tall (250 at 900p: from just under the toasts band, y 279, to 529, above
# the prompts band at 558) so it reads as the bigger ceremony, and its line takes at
# most CARD_LINES lines, so it stays clear of the play area whatever the text. Seven lines
# is what the card holds beside its title without growing; a longer line is trimmed.
const CARD_HEIGHT := 250.0
const CARD_LINES := 7
const GLYPH_PERIOD := 1.2
const DEFAULT_KIND := "synergy_discovered"
const TINT_KICKER_LIFT := 0.35

var shown := 0
var last_title := ""
# Cards mode: set by the owner from the discovery option, with a UiProfile that
# persists discoveries_seen. Without a profile the ids seen this session stand in.
var cards := false
var profile = null
# Where the profile lives when the banner opens it itself (--discovery=cards on the
# command line); empty means the owner supplies one.
var storage_dir := ""
# "banner" or "card": how the current item is shown, and how many cards.
var last_style := ""
var cards_shown := 0
# The clock in milliseconds; tests swap it for a fake.
var now_ms: Callable = Callable(Time, "get_ticks_msec")

# An item is on screen now (key is its show_discovery id): the calm moment it waited for.
signal came_up(key: String)

var _queue: Array = []
var _events = null
var _flow = null
# The screen_busy gate (src/ui/screen_busy.gd) and the key of the card up: it queues behind a fight.
var _busy = null
var _slot := ""
var _session_seen := {}
var _style_name := "banner"
var _hold := HOLD
var _in_time := IN_TIME
var _out_time := OUT_TIME
var _glyph: Control
var _glyph_shape := "star"
var _glyph_color := Color.WHITE
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
	_glyph = Control.new()
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.custom_minimum_size = Vector2(GLYPH_CARD, GLYPH_CARD)
	_glyph.visible = false
	_glyph.draw.connect(_draw_glyph)
	row.add_child(_glyph)
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


func _ready() -> void:
	var node := get_parent()
	while node != null and _events == null:
		var ctx = node.get("ctx")
		if ctx != null and ctx.get("events") != null:
			_flow = ctx.get("flow")
			_busy = ctx.get("screen_busy")
			watch(ctx.events)
		node = node.get_parent()


# Hands the banner the bus: a retry drops what it holds.
func watch(events) -> void:
	if _events == events or not events.has_signal("player_hit"):
		return
	_events = events
	# A retry rewinds the stage and clears the codex record: a held card goes unseen.
	if events.has_signal("stage_entered"):
		events.stage_entered.connect(func(_stage: int, retry: bool):
			if retry:
				dismiss(true))


# Whether a find may show its card now: the screen is quiet (screen_busy.gd) for the finds' hold.
func calm() -> bool:
	return _busy == null or _busy.settled(ScreenBusy.FIND_HOLD)


# A card is waiting for a calm moment.
func held() -> bool:
	return not showing() and not _queue.is_empty()


# kicker: "New synergy", "Synergy", "Found" or similar. While one is showing the next
# waits its turn.
# id names the discovery for the first-time test in cards mode (default: category and
# title); kind is the EventKinds row whose shape and colour the glyph wears.
# tint, when set, replaces the category colour on the edge, the kicker and the glyph, so a
# banner can wear the colour of the thing it names (a part set's studs on the ball).
# every_time is for a moment of the run, not a codex first (a completed set): in cards mode its
# first showing ever is still the card, and each later one is the small banner instead of
# nothing. It is never dropped for a full queue, and it does not wait behind first-find cards.
func show_discovery(title: String, category: String, detail := "", kicker := "New synergy", id := "", kind := DEFAULT_KIND,
		tint = null, every_time := false) -> void:
	var style := "banner"
	var key := id if id != "" else "%s:%s" % [category, title]
	if cards:
		style = "auto"
		if profile == null and storage_dir != "":
			profile = UiProfile.new(storage_dir)
		if _queue.any(func(item: Array): return item[6] == key):
			return
		if every_time:
			style = "banner" if _was_seen(key) else "auto"
		# Seen means shown: the record is written when the card comes up (_next), so a
		# discovery that is queued and then dropped stays unseen. A repeat, one already
		# held, or one past MAX_HELD shows nothing.
		elif _was_seen(key) or _queue.size() >= MAX_HELD:
			return
	var item := [title, category, detail, kicker, style, kind, key, tint, every_time]
	# A moment of the run goes ahead of the first-find cards still waiting (and behind an earlier
	# moment), so it lands in the next calm moment after the pickup that earned it.
	var at := _queue.size()
	if every_time:
		at = 0
		while at < _queue.size() and _queue[at][8]:
			at += 1
	_queue.insert(at, item)
	if _busy != null:
		_busy.request(key, every_time)
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
	if _busy != null:
		_busy.done(_slot)
		_slot = ""
	if clear_queue:
		if _busy != null:
			for item in _queue:
				_busy.done(item[6])
		_queue.clear()


func _was_seen(key: String) -> bool:
	return profile.discovered(key) if profile != null else _session_seen.has(key)


func _mark_seen(key: String) -> void:
	if profile != null:
		profile.mark_discovered(key)
	else:
		_session_seen[key] = true


# Any key, mouse button or pad button press (or a hard stick push) dismisses a card at
# once. The event is not consumed: the press still reaches the game.
func _input(event: InputEvent) -> void:
	if not showing() or _style_name == "banner":
		return
	var pressed := false
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.is_pressed() and not (event is InputEventKey and event.echo)
	elif event is InputEventJoypadMotion:
		pressed = absf(event.axis_value) > 0.6
	if pressed:
		dismiss(false)
		_next()


# How long a card with this line stays up between its slide in and its slide out.
static func card_hold(line: String) -> float:
	var extra := maxi(line.split(" ", false).size() - CARD_WORDS, 0)
	return minf(CARD_HOLD + CARD_WORD_HOLD * extra, CARD_HOLD_MAX)


func _apply_style(style: String, entry: Dictionary, kind: String) -> void:
	_style_name = style
	var card := style == "card"
	_icon.visible = not card
	_glyph.visible = card
	_kicker.visible = true
	_hold = HOLD
	_in_time = IN_TIME
	_out_time = OUT_TIME
	_panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	_body.custom_minimum_size = Vector2(WIDTH - 90.0, 0.0)
	_body.max_lines_visible = -1
	# A card trims its line; a banner after a card must not keep the trim (it hid the whole line).
	_body.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_title.add_theme_font_size_override("font_size", 24)
	_body.add_theme_font_size_override("font_size", 15)
	if card:
		var side := GLYPH_CARD
		_glyph.custom_minimum_size = Vector2(side, side)
		_body.custom_minimum_size = Vector2(WIDTH - side - 12.0 - 30.0, 0.0)
		_title.add_theme_font_size_override("font_size", 26)
		_body.add_theme_font_size_override("font_size", 14)
		_body.max_lines_visible = CARD_LINES
		_body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_panel.custom_minimum_size = Vector2(WIDTH, CARD_HEIGHT)
		_hold = CARD_HOLD
	if card:
		var row := EventKinds.row(kind) if EventKinds.has(kind) else EventKinds.row(DEFAULT_KIND)
		_glyph_shape = String(row["shape"])
		_glyph_color = row["color"]


func _next() -> void:
	if _queue.is_empty():
		return
	var head: Array = _queue[0]
	if head[4] == "auto" and _was_seen(head[6]):
		if _busy != null:
			_busy.done(head[6])
		_queue.pop_front()
		_next()
		return
	# Every head asks the shared gate, whatever its style.
	if _busy != null and not _busy.may_show(head[6], ScreenBusy.FIND_HOLD):
		return
	_slot = head[6]
	var item: Array = _queue.pop_front()
	var entry := CodexStyle.category(item[1])
	var color: Color = item[7] if item[7] is Color else entry["color"]
	var style: String = item[4]
	if style == "auto":
		style = "card"
		_mark_seen(item[6])
	_apply_style(style, entry, item[5])
	if item[7] is Color:
		_glyph_color = color
	_icon.texture = CodexStyle.icon(item[1], item[7])
	# The glyph, the colour and the name say what it is; the kicker is only the category, not a sentence.
	# A moment of the run (a finished set) wears the synergy card's glyph, so its word stays until a
	# mark of its own carries it (reported, wave 36 round 4).
	_kicker.text = String(entry["label"]).to_upper()
	if item[8]:
		_kicker.text = "%s  ·  %s" % [String(item[3]).to_upper(), _kicker.text]
	# The edge, icon and glyph wear a tint as given; the small kicker text is lifted so a dark
	# tint (rust, slate) still reads on the panel.
	_kicker.add_theme_color_override("font_color", color.lightened(TINT_KICKER_LIFT) if item[7] is Color else color)
	_title.text = item[0]
	_body.text = item[2]
	_body.visible = item[2] != ""
	if _style_name == "card":
		_hold = card_hold(item[2])
	_panel.reset_size()
	_style.border_color = color
	last_style = _style_name
	if _style_name == "card":
		cards_shown += 1
	shown += 1
	last_title = item[0]
	_started_ms = int(now_ms.call())
	visible = true
	_place(0.0)
	came_up.emit(item[6])


func _process(delta: float) -> void:
	if _started_ms < 0:
		_next()
		return
	# A fight going live closes what is up; the discovery stays seen and the queue waits.
	if WhyCallout.warden_fight_live(_flow):
		dismiss(false)
		return
	var t := (int(now_ms.call()) - _started_ms) / 1000.0
	var total := _in_time + _hold + _out_time
	if t >= total:
		dismiss(false)
		_next()
		return
	var slide := 1.0
	if t < _in_time:
		var x := t / _in_time
		slide = 1.0 + 0.08 * sin(x * PI) if x > 0.6 else x / 0.6
	elif t > _in_time + _hold:
		slide = 1.0 - (t - _in_time - _hold) / _out_time
	_place(slide)
	if _glyph.visible:
		_glyph.queue_redraw()


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


# The looping glyph: the EventKinds shape in its colour, pulsing with an echo ring on a
# GLYPH_PERIOD loop. Shapes that mean motion (chevron, arrow) travel, the rest turn or
# swell, so the picture is never only a static icon.
func _draw_glyph() -> void:
	if _started_ms < 0:
		return
	var side := _glyph.size.x
	var c := Vector2(side, _glyph.size.y) * 0.5
	var r := minf(side, _glyph.size.y) * 0.32
	var t := (int(now_ms.call()) - _started_ms) / 1000.0
	var ph := fmod(t / GLYPH_PERIOD, 1.0)
	var pulse := 1.0 + 0.1 * sin(ph * TAU)
	var col := _glyph_color
	_glyph.draw_circle(c, minf(side, _glyph.size.y) * 0.48, Color(0.05, 0.06, 0.06, 0.55))
	_glyph.draw_arc(c, r * (1.0 + 0.55 * ph), 0.0, TAU, 40, Color(col, 1.0 - ph), 2.0)
	var lw := maxf(2.0, r * 0.14)
	match _glyph_shape:
		"ring":
			_glyph.draw_arc(c, r * pulse, 0.0, TAU, 40, col, lw)
			_glyph.draw_circle(c, r * 0.22, col)
		"diamond":
			_glyph.draw_colored_polygon(_poly(c, r * pulse, 4, ph * PI * 0.5), col)
		"square":
			_glyph.draw_colored_polygon(_poly(c, r * pulse * 1.15, 4, PI * 0.25 + 0.25 * sin(ph * TAU)), col)
		"chevron", "arrow":
			for i in 3:
				var o := fmod(ph + i / 3.0, 1.0)
				var x := lerpf(-r, r, o)
				var a := sin(o * PI)
				var pts := PackedVector2Array([c + Vector2(x - r * 0.35, -r * 0.6), c + Vector2(x + r * 0.25, 0.0), c + Vector2(x - r * 0.35, r * 0.6)])
				_glyph.draw_polyline(pts, Color(col, a), lw)
			if _glyph_shape == "arrow":
				_glyph.draw_line(c + Vector2(-r, 0.0), c + Vector2(r * 0.6, 0.0), Color(col, 0.6), lw)
		"burst":
			for i in 8:
				var ang := i * TAU / 8.0 + ph * 0.5
				var d := Vector2.from_angle(ang)
				_glyph.draw_line(c + d * r * 0.35, c + d * r * (0.7 + 0.5 * ph), col, lw)
		"bar":
			var w := r * 2.0
			_glyph.draw_rect(Rect2(c + Vector2(-r, -r * 0.25), Vector2(w, r * 0.5)), Color(col, 0.35), true)
			_glyph.draw_rect(Rect2(c + Vector2(-r, -r * 0.25), Vector2(w * ph, r * 0.5)), col, true)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0 + ph * TAU * 0.25) * r * pulse * (1.0 if i % 2 == 0 else 0.45))
			_glyph.draw_colored_polygon(pts, col)
		"cross":
			var d := Vector2.from_angle(PI * 0.25 + ph * TAU * 0.25) * r * pulse
			var e := Vector2(-d.y, d.x)
			_glyph.draw_line(c - d, c + d, col, lw)
			_glyph.draw_line(c - e, c + e, col, lw)
		"wave":
			for i in 3:
				var o := fmod(ph + i / 3.0, 1.0)
				_glyph.draw_arc(c, r * (0.3 + 0.9 * o), 0.0, TAU, 40, Color(col, 1.0 - o), lw)
		"core":
			_glyph.draw_circle(c, r * 0.6 * pulse, col)
			_glyph.draw_arc(c, r, ph * TAU, ph * TAU + TAU * 0.7, 32, col, lw)
		_:
			_glyph.draw_circle(c, r * 0.5 * pulse, col)


static func _poly(c: Vector2, radius: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(rot + i * TAU / n) * radius)
	return pts
