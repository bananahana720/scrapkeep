extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")


const FONT := UiTokens.HEADING
const PULSE := 0.14
const SWELL := 0.35
const FALL := 0.3
const DROP := 18.0
const BOX := Vector2(104.0, 48.0)
const LINK := 9.0
const LINK_W := 2.5
const TIMES := "×"
const FAST_CHAIN_S := 0.55
const TIER_COMBOS := [2, 4, 6, 8]
const TIER_SWELL := [0.35, 0.44, 0.52, 0.62]
const FAST_BONUS_SWELL := 0.12
const BEAT_HZ := [0.0, 2.2, 3.2, 4.4]
const BEAT_AMP := [0.0, 0.035, 0.055, 0.075]
const TIER_FLASH_S := 0.22
const KICK_TILT_RAD := 0.055

var shown := 0
var _combo := 0
var _pulse := -1.0
var _fall := -1.0
var _clock := 0.0
var _since_bump := 999.0
var _fast_links := 0
var _tier := 0
var _tier_flash := -1.0
var _punch_peak := SWELL


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BOX
	size = BOX
	visible = false


static func momentum_tier(combo: int, fast := 0) -> int:
	var rung := 0
	for i in TIER_COMBOS.size():
		if combo >= int(TIER_COMBOS[i]):
			rung = i
	if combo >= 3 and fast >= 2:
		rung = mini(rung + 1, TIER_COMBOS.size() - 1)
	return rung


static func tier_color(tier: int) -> Color:
	match clampi(tier, 0, TIER_COMBOS.size() - 1):
		1:
			return Palette.AMBER
		2:
			return Palette.SODIUM
		3:
			return Palette.BRASS
	return EventKinds.line_color("chain_link")


func showing() -> bool:
	return _combo >= 2 or _fall >= 0.0


func text() -> String:
	return str(shown) if showing() else ""


func current_tier() -> int:
	return _tier


func fast_links() -> int:
	return _fast_links


func reset() -> void:
	shown = 0
	_combo = 0
	_pulse = -1.0
	_fall = -1.0
	_clock = 0.0
	_since_bump = 999.0
	_fast_links = 0
	_tier = 0
	_tier_flash = -1.0
	_punch_peak = SWELL
	visible = false
	queue_redraw()


func draw_scale() -> float:
	if UiTokens.reduced_motion or _fall >= 0.0:
		return 1.0
	var scale := 1.0
	if _pulse >= 0.0:
		var u := clampf(_pulse / PULSE, 0.0, 1.0)
		var peak := _punch_peak
		scale += peak * (ease(u / 0.3, 0.35) if u < 0.3 else (1.0 - ease((u - 0.3) / 0.7, 0.55)))
	var hz := float(BEAT_HZ[_tier])
	if hz > 0.0 and _combo >= 2:
		scale += float(BEAT_AMP[_tier]) * (0.5 + 0.5 * sin(_clock * TAU * hz))
	return scale


func step(delta: float, combo: int) -> void:
	var was := showing()
	_since_bump += delta
	if combo >= 2:
		_clock += delta
		if combo > _combo:
			var was_fast := _combo >= 2 and _since_bump <= FAST_CHAIN_S
			_fast_links = _fast_links + 1 if was_fast else 0
			var prev_tier := _tier
			_tier = momentum_tier(combo, _fast_links)
			if _tier > prev_tier:
				_tier_flash = 0.0
			_punch_peak = float(TIER_SWELL[_tier]) + (FAST_BONUS_SWELL if was_fast else 0.0)
			_pulse = 0.0
			_since_bump = 0.0
		_fall = -1.0
		shown = combo
	elif _combo >= 2 and _fall < 0.0:
		_fall = 0.0
		_pulse = -1.0
		_fast_links = 0
		_tier_flash = -1.0
	_combo = combo
	if _pulse >= 0.0:
		_pulse += delta
		if _pulse >= PULSE:
			_pulse = -1.0
	if _tier_flash >= 0.0:
		_tier_flash += delta
		if _tier_flash >= TIER_FLASH_S:
			_tier_flash = -1.0
	if _fall >= 0.0:
		_fall += delta
		if _fall >= FALL:
			_fall = -1.0
			_tier = 0
			_clock = 0.0
	visible = showing()
	if visible or was:
		queue_redraw()


func _draw() -> void:
	if not showing():
		return
	var color := tier_color(_tier)
	if _tier_flash >= 0.0:
		color = color.lerp(Palette.LEDGER_CREAM, 0.55 * (1.0 - _tier_flash / TIER_FLASH_S))
	var scale := draw_scale()
	var drop := 0.0
	var tilt := 0.0
	if _pulse >= 0.0 and not UiTokens.reduced_motion and _tier >= 1:
		var kick := 1.0 - _pulse / PULSE
		tilt = -KICK_TILT_RAD * kick * (1.0 if shown % 2 == 0 else -1.0)
	if _fall >= 0.0:
		var t := _fall / FALL
		drop = DROP * t
		color.a = 1.0 - t
	draw_set_transform(Vector2(0.0, size.y * 0.5 + drop), tilt, Vector2(scale, scale))
	_draw_links(color)
	var x := LINK * 3.4
	x += UiDraw.text(self, x, 0.0, TIMES, UiTokens.LABEL, color)
	UiDraw.text(self, x + 1.0, 0.0, str(shown), FONT, color, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_links(color: Color) -> void:
	var outline := Color(UiDraw.OUTLINE, UiDraw.OUTLINE.a * color.a)
	for at in [Vector2(LINK, 0.0), Vector2(LINK * 2.2, 0.0)]:
		draw_arc(at, LINK * 0.8, 0.0, TAU, 24, outline, LINK_W + 2.0)
	for at in [Vector2(LINK, 0.0), Vector2(LINK * 2.2, 0.0)]:
		draw_arc(at, LINK * 0.8, 0.0, TAU, 24, color, LINK_W)
	if _tier >= 1:
		var accent := Color(Palette.LEDGER_CREAM, color.a * 0.9)
		for i in _tier:
			var pip_at := Vector2(LINK * 0.7 + float(i) * 6.5, LINK * 1.45)
			draw_circle(pip_at, 3.0, outline)
			draw_circle(pip_at, 1.9, accent)
