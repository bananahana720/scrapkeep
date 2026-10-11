extends Control

const StartPicks := preload("res://src/core/start_picks.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Palette := preload("res://src/core/palette.gd")

# SG9's run-start card: the three options on offer as three tiles, each its key, its icon and
# a name of at most three words, with one pip per reroll left. Like the stage card it only
# draws: it takes no input and never pauses, so the first drop keeps every bit of its speed
# and the pick costs one key press at most (memo 3, SG9 FORBIDDEN). The caller routes keys to
# RunState.take_start_pick and reroll_start_pick and calls show_picks again; once a pick is
# taken, or a run offers nothing, the card hides. The tiles take the pilot's colour.

const ICON := 40.0
const KEY := 26.0
const FONT := 24
const GAP := 10.0
const TILE_GAP := 18.0
const PAD := 10.0
const PIP := 5.0
const KEYS := ["key_1", "key_2", "key_3"]

var _tiles: Array = []
var _rerolls := 0
var _color := Palette.SAND


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process_input(false)
	set_process_unhandled_input(false)


func show_picks(run) -> void:
	_tiles = []
	var taken := String(run.start_pick.get("taken", ""))
	var pilot: String = run.class_id()
	if taken == "":
		var options: Array = run.start_pick_options()
		for i in mini(options.size(), KEYS.size()):
			var row := StartPicks.row(pilot, String(options[i]))
			if row.is_empty():
				continue
			_tiles.append({"key": KEYS[i], "icon": row["icon"], "name": row["name"], "id": row["id"]})
	_rerolls = int(run.start_pick.get("rerolls_left", 0))
	if run.class_def != null:
		_color = run.class_def.color
	visible = _tiles.size() == StartPicks.OFFERED
	custom_minimum_size = extent()
	queue_redraw()


func hide_card() -> void:
	visible = false


func showing() -> bool:
	return visible


func tiles() -> Array:
	return _tiles.duplicate(true)


func rerolls_left() -> int:
	return _rerolls


func _tile_width(tile: Dictionary) -> float:
	return PAD + KEY + GAP + ICON + GAP + UiDraw.width(String(tile["name"]), FONT) + PAD


func extent() -> Vector2:
	var w := 0.0
	for tile in _tiles:
		w += _tile_width(tile)
	w += TILE_GAP * maxf(0.0, _tiles.size() - 1)
	return Vector2(w, ICON + PAD * 2.0 + PIP * 3.0)


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if visible:
		for tile in _tiles:
			out.append(String(tile["name"]))
	return out


func _draw() -> void:
	var w := extent().x
	var x := (size.x - w) * 0.5
	var h := ICON + PAD * 2.0
	for tile in _tiles:
		var tw := _tile_width(tile)
		UiDraw.panel(self, Rect2(Vector2(x, 0.0), Vector2(tw, h)))
		var mid := h * 0.5
		var cx := x + PAD
		draw_texture_rect(Icons.texture(tile["key"]), Rect2(Vector2(cx, mid - KEY * 0.5), Vector2(KEY, KEY)), false, Palette.SAND)
		cx += KEY + GAP
		draw_texture_rect(Icons.texture(tile["icon"]), Rect2(Vector2(cx, mid - ICON * 0.5), Vector2(ICON, ICON)), false,
			Icons.tint(tile["icon"], _color))
		cx += ICON + GAP
		UiDraw.text(self, cx, mid, String(tile["name"]), FONT, _color)
		x += tw + TILE_GAP
	# One pip per reroll left, centred under the tiles: a spent reroll leaves an outline.
	for i in StartPicks.REROLLS:
		var at := Vector2(size.x * 0.5 + (i - (StartPicks.REROLLS - 1) * 0.5) * PIP * 3.0, h + PIP * 1.5)
		if i < _rerolls:
			draw_circle(at, PIP, _color)
		else:
			draw_arc(at, PIP, 0.0, TAU, 16, Color(_color, 0.5), 1.5)
