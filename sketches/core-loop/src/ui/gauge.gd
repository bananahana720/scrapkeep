extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# One HUD readout: an icon, an optional short label (a count, in mono digits) and an
# optional bar. Health is a tank gauge (a tick every quarter) and scrap a count. Below
# its warning share the gauge's edge turns iron oxide and pulses at 1 Hz. A drop in the bar
# leaves the lost slice standing in the hit colour for LOSS_HOLD seconds and then drains it
# over LOSS_DRAIN, so a hit shows which bar took it and how much went.
#
# A bar can carry a caption: one small word under its left end, in the bar's own colour,
# saying what the bar holds. Of 24 blind readers of one still (10 Nov 2026), none of the 12
# shown the armour bar without its word took it for armour and all 12 shown the word did. The caption is part of the gauge's extent, and
# bar_mid() is the line the icon and bar sit on, so a caller centres on the bar, not the box.
#
# A capped bar (set_cap) has lost the top of its range for the run: the stretch past the cap is
# a welded ink plate the fill can never reach, held by a brass bracket at the cap, so a bar full
# to the cap reads short of whole.

const ICON := 26.0
const BAR_H := 12.0
const FONT := UiTokens.LABEL
const GAP := 8.0
const PULSE_HZ := 1.0
const TICKS := 4
const LOSS_HOLD := 0.35
const LOSS_DRAIN := 0.45
const CAPTION_FONT := UiTokens.CAPTION
const CAPTION_LINE := 13.0

var icon_id := ""
var color := Color.WHITE
var fraction := -1.0
var label := ""
var bar_width := 0.0
var ticks := false
var caption := ""
var warn := false
var warn_color := Color.WHITE
# The share of the bar the reading can reach; 1.0 when nothing is welded off.
var cap := 1.0
var _clock := 0.0
# The share the bar stood at before its last drop, and the seconds its slice has left.
var _lost_from := -1.0
var _lost_left := 0.0


func _init(icon := "", width_of_bar := 0.0, quarter_ticks := false, word := "") -> void:
	icon_id = icon
	bar_width = width_of_bar
	ticks = quarter_ticks
	caption = word if width_of_bar > 0.0 else ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = extent()
	size = custom_minimum_size


func set_reading(value: float, tint: Color, text := "", warning := false, warning_color := Color.WHITE) -> void:
	# Called every frame by the HUD: shape and redraw only when a shown value changed.
	if value == fraction and tint == color and text == label and warning == warn and warning_color == warn_color:
		return
	if bar_width > 0.0 and fraction >= 0.0 and value >= 0.0 and value < fraction:
		_lost_from = lost_edge()
		_lost_left = LOSS_HOLD + LOSS_DRAIN
	fraction = value
	color = tint
	label = text
	warn = warning
	warn_color = warning_color
	custom_minimum_size = extent()
	size = custom_minimum_size
	queue_redraw()


func set_cap(share: float) -> void:
	share = clampf(share, 0.0, 1.0)
	if share == cap:
		return
	cap = share
	queue_redraw()


func extent() -> Vector2:
	var w := ICON + GAP
	if label != "":
		w += UiDraw.width(label, FONT, true) + GAP
	if bar_width > 0.0:
		w += bar_width
	return Vector2(w, ICON + (CAPTION_LINE if caption != "" else 0.0))


# The line the icon and the bar are centred on, from the gauge's top.
func bar_mid() -> float:
	return ICON * 0.5


# A new run's first reading is no loss from the last run's: forget the bar and its slice.
func clear() -> void:
	fraction = -1.0
	_lost_from = -1.0
	_lost_left = 0.0
	queue_redraw()


# Where the lost slice ends, as a share of the bar: the bar's own share once it has drained.
func lost_edge() -> float:
	if _lost_left <= 0.0 or _lost_from <= fraction:
		return fraction
	return lerpf(fraction, _lost_from, clampf(_lost_left / LOSS_DRAIN, 0.0, 1.0))


func drawn_words() -> PackedStringArray:
	var words := PackedStringArray()
	if label != "":
		words.append(label)
	# The caption is drawn with the bar, so it is a word only once the bar has a reading.
	if caption != "" and fraction >= 0.0:
		words.append(caption)
	return words


func _process(delta: float) -> void:
	_clock += delta
	var draining := _lost_left > 0.0
	_lost_left = maxf(0.0, _lost_left - delta)
	if warn or draining:
		queue_redraw()


func _draw() -> void:
	var mid := bar_mid()
	# Outlined: on flat pale sand the PC saw the health and armour icons vanish beside their words.
	UiDraw.icon(self, Icons.texture(icon_id), Rect2(Vector2(0.0, mid - ICON * 0.5), Vector2(ICON, ICON)), Icons.tint(icon_id, color))
	var x := ICON + GAP
	if label != "":
		x += UiDraw.text(self, x, mid, label, FONT, color, true) + GAP
	if bar_width <= 0.0 or fraction < 0.0:
		return
	var bar := Rect2(Vector2(x, mid - BAR_H * 0.5), Vector2(bar_width, BAR_H))
	UiDraw.bar(self, bar, fraction, color)
	if caption != "":
		UiDraw.text(self, bar.position.x, ICON + CAPTION_LINE * 0.5, caption, CAPTION_FONT, color)
	var lost := lost_edge() - fraction
	if lost > 0.0:
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * fraction, 0.0), Vector2(bar.size.x * lost, BAR_H)), EventKinds.color("player_hit"))
	if ticks:
		for i in range(1, TICKS):
			var tx := bar.position.x + bar.size.x * i / TICKS
			draw_line(Vector2(tx, bar.position.y), Vector2(tx, bar.position.y + BAR_H * 0.45), UiDraw.OUTLINE, 2.0)
	if cap < 1.0:
		_draw_weld(bar)
	if warn:
		var beat := 0.5 + 0.5 * cos(_clock * TAU * PULSE_HZ)
		draw_rect(bar.grow(2.5), Color(warn_color, 0.35 + 0.65 * beat), false, 2.5)


# The welded stretch: an ink plate from the cap to the bar's end, edged in the plate line, and a
# brass bracket standing proud of the bar at the cap.
func _draw_weld(bar: Rect2) -> void:
	var at := bar.position.x + bar.size.x * cap
	var plate := Rect2(Vector2(at, bar.position.y), Vector2(bar.end.x - at, BAR_H))
	draw_rect(plate, UiTokens.INK)
	draw_rect(plate, UiTokens.LINE, false, 1.5)
	var reach := 3.0
	draw_rect(Rect2(Vector2(at - 2.0, bar.position.y - reach), Vector2(4.0, BAR_H + reach * 2.0)), UiTokens.ACCENT)
