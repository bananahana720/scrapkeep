extends Button

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# One stamped plate on Moss's counter. A tile is icons first: the part's family (cat_)
# inside its rarity frame, its element (el_) and trigger (trg_) glyphs on the frame's
# lower corners, and the price as the cog icon and a number. The name and what it does
# show in the counter's detail line for the tile under the mouse or the keys.
#
# kind   shelf | top | cell | reroll | sell | pick | weigh | stow | brew
# A brew plate is Moss's last-call kettle (shop.brew_offer): the pilot's ultimate glyph with a
# pip per pour, each pour a third of the meter at the boss fight's start.
# A shelf plate with set_pieces is the last call's set piece: a pip per piece of its maker's set
# under the frame, the held ones filled and the one this plate adds outlined in amber.
# A stow plate is a core carried in SPIL-9 (shop.stow_core): the core glyph in a socket ring,
# and under it the piece it unseats (seat_icon), struck through; nothing when a socket is free.
# A weigh plate is Moss's scale (shop.gd weigh): the mass glyph with the mass one press
# takes under it, and the cogs it pays as the price.
# state  ok | poor (too few cogs) | sold | locked (heft) | capped | welded | spent
# A poor tile keeps its price but dims and strikes it; a locked hook wears the heft
# dial with a notch at the class it needs; a sold slot is an empty dashed plate.

const ICON := 56.0
const GLYPH := 20.0
const PRICE_FONT := UiTokens.BODY
const COG := 16.0
const RARITY := {
	"common": {"color": Palette.ARC, "width": 2.0, "double": false, "notches": false},
	"rare": {"color": Palette.COBALT, "width": 3.0, "double": true, "notches": false},
	"relic": {"color": Palette.AMBER, "width": 3.0, "double": true, "notches": true},
	"evolved": {"color": Palette.ANCIENT, "width": 4.0, "double": true, "notches": true},
}

var rec := {}
var index := -1
var _lift := 0.0


func _init(record := {}, tile_size := Vector2(112.0, 124.0)) -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = tile_size
	var plain := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, plain)
	mouse_entered.connect(func():
		if not disabled:
			grab_focus())
	set_record(record)


func set_record(record: Dictionary) -> void:
	rec = record
	accessibility_name = String(rec.get("name", rec.get("id", "")))
	queue_redraw()


func state() -> String:
	return String(rec.get("state", "ok"))


func price_shown() -> bool:
	return int(rec.get("price", -1)) >= 0 and not state() in ["sold", "welded", "spent", "capped"]


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if String(rec.get("kind", "")) == "weigh":
		out.append(str(int(rec.get("mass", 0))))
	if price_shown():
		out.append(str(int(rec["price"])))
	if rec.has("key"):
		out.append_array(Keycap.words(String(rec["key"])))
	return out


func _process(delta: float) -> void:
	_lift = move_toward(_lift, 1.0 if has_focus() or is_hovered() else 0.0, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var s := state()
	if s == "sold" or s == "spent":
		_dashed(rect.grow(-3.0), Color(Palette.SAND, 0.35))
		return
	UiDraw.panel(self, rect)
	if has_focus() or is_hovered():
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = UiTokens.TEXT if has_focus() else Palette.SAND
		ring.set_border_width_all(3 if has_focus() else 2)
		ring.set_corner_radius_all(6)
		draw_style_box(ring, rect.grow(2.0))
	var dim := 0.45 if s in ["poor", "capped", "welded"] else 1.0
	var centre := Vector2(size.x * 0.5, 12.0 + ICON * 0.5 - 4.0 * _lift)
	var icon_rect := Rect2(centre - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON))
	match String(rec.get("kind", "shelf")):
		"reroll":
			_cycle(centre, ICON * 0.36, Color(Palette.SAND, dim))
		"pick":
			var icons: Array = rec.get("icons", [])
			for i in icons.size():
				var r := Rect2(centre + Vector2((i - 0.5) * ICON * 0.62 - ICON * 0.28, -ICON * 0.28), Vector2(ICON * 0.56, ICON * 0.56))
				draw_texture_rect(Icons.texture(icons[i]), r, false, Icons.tint(icons[i], rec.get("color", Palette.SAND)))
			draw_texture_rect(Icons.shape("diamond"), Rect2(centre + Vector2(-7.0, ICON * 0.3), Vector2(14.0, 14.0)), false, Palette.SAND)
		"weigh":
			draw_texture_rect(Icons.texture("res_mass"), icon_rect.grow(-10.0), false, Icons.tint("res_mass", Color(rec.get("color", Palette.SAND), dim)))
			var mass := str(int(rec.get("mass", 0)))
			UiDraw.text(self, centre.x - UiDraw.width(mass, PRICE_FONT, true) * 0.5, icon_rect.end.y + 6.0, mass, PRICE_FONT, Color(Palette.SAND, dim), true)
		"stow":
			draw_arc(centre, ICON * 0.42, 0.0, TAU, 32, Color(Palette.SAND, dim), 3.0)
			draw_texture_rect(Icons.texture("res_core"), icon_rect.grow(-14.0), false, Icons.tint("res_core", Color(rec.get("color", Palette.SAND), dim)))
			# The cost: the piece the core unseats, struck through, under the socket ring.
			var seat := String(rec.get("seat_icon", ""))
			if seat != "":
				var side := 24.0
				var at := Rect2(Vector2(centre.x - side * 0.5, icon_rect.end.y + 6.0), Vector2(side, side))
				draw_texture_rect(Icons.texture(seat), at, false, Icons.tint(seat, Color(Palette.SAND, dim)))
				draw_line(at.position + Vector2(0.0, side), at.position + Vector2(side, 0.0), Color(Palette.HAZARD, dim), 3.0, true)
		"cell", "brew":
			var icon_id := String(rec.get("icon", ""))
			draw_texture_rect(Icons.texture(icon_id), icon_rect.grow(-8.0), false, Icons.tint(icon_id, Color(rec.get("color", Palette.SAND), dim)))
			_pips(Vector2(centre.x, icon_rect.end.y + 2.0), int(rec.get("cells", 0)), int(rec.get("cap", 2)), dim)
		_:
			_framed(icon_rect, dim)
			if int(rec.get("set_pieces", 0)) > 0:
				_set_pips(Vector2(centre.x, icon_rect.end.y + 20.0), int(rec.get("set_held", 0)), int(rec["set_pieces"]), dim)
	if rec.has("key"):
		Keycap.draw(self, Vector2(Keycap.size_of(String(rec["key"]), 20.0).x * 0.5 + 6.0, 16.0), String(rec["key"]), Palette.SAND, 20.0)
	if s == "locked":
		_lock_dial(Vector2(icon_rect.end.x - 2.0, icon_rect.end.y - 6.0))
	if price_shown():
		_price(Vector2(size.x * 0.5, size.y - 16.0), int(rec["price"]), s == "poor")
	elif s == "welded":
		draw_texture_rect(Icons.shape("cross"), Rect2(Vector2(size.x * 0.5 - 9.0, size.y - 25.0), Vector2(18.0, 18.0)), false, Color(Palette.SAND, 0.6))


# The part's family glyph inside its rarity frame, element and trigger on the corners.
func _framed(icon_rect: Rect2, dim: float) -> void:
	var frame: Dictionary = RARITY.get(String(rec.get("rarity", "common")), RARITY["common"])
	var tint := Color(frame["color"], dim)
	var outer := icon_rect.grow(4.0)
	draw_rect(outer, tint, false, frame["width"])
	if frame["double"]:
		draw_rect(outer.grow(-6.0), Color(Palette.ARC, dim) if frame["notches"] else tint, false, frame["width"])
	if frame["notches"]:
		for corner in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
			draw_circle(corner, 4.0, tint)
	var icon_id := String(rec.get("icon", ""))
	draw_texture_rect(Icons.texture(icon_id), icon_rect.grow(-10.0), false, Icons.tint(icon_id, Color(Palette.SAND, dim)))
	var corners := [[String(rec.get("element_icon", "")), Vector2(outer.position.x, outer.end.y)],
		[String(rec.get("trigger_icon", "")), outer.end]]
	for c in corners:
		if c[0] == "":
			continue
		var r := Rect2(c[1] - Vector2(GLYPH, GLYPH) * 0.5, Vector2(GLYPH, GLYPH))
		draw_circle(r.get_center(), GLYPH * 0.62, Palette.CHARCOAL)
		draw_texture_rect(Icons.texture(c[0]), r, false, Icons.tint(c[0], Color(Palette.SAND, dim)))


# The cog icon and the price in mono digits; too poor dims it and strikes it through.
func _price(at: Vector2, amount: int, poor: bool) -> void:
	var digits := str(amount)
	var w := COG + 5.0 + UiDraw.width(digits, PRICE_FONT, true)
	var x := at.x - w * 0.5
	var tint := Color(Palette.SAND, 0.45) if poor else Palette.SAND
	draw_texture_rect(Icons.texture("res_scrap"), Rect2(Vector2(x, at.y - COG * 0.5), Vector2(COG, COG)), false, Icons.tint("res_scrap", Color(Palette.ARC, 0.45 if poor else 1.0)))
	UiDraw.text(self, x + COG + 5.0, at.y, digits, PRICE_FONT, tint, true)
	if poor:
		draw_line(Vector2(x - 3.0, at.y + 1.0), Vector2(x + w + 3.0, at.y - 1.0), Palette.SAND, 2.0)


# The hook's lock: the heft dial with a notch at the class Moss wants and the needle at
# the ball's class now (DESIGN-V2 section 12).
func _lock_dial(hub: Vector2) -> void:
	var radius := 15.0
	var classes := maxi(2, int(rec.get("classes", 5)))
	var needs := int(rec.get("needs_class", 2))
	var now := int(rec.get("heft_class", 1))
	draw_circle(hub + Vector2(0.0, -radius * 0.4), radius + 5.0, Palette.CHARCOAL)
	draw_arc(hub, radius, PI, TAU, 20, Color(Palette.AMBER, 0.6), 2.5)
	for i in classes:
		var a := PI + PI * i / float(classes - 1)
		var dir := Vector2(cos(a), sin(a))
		var mark := i + 1 == needs
		draw_line(hub + dir * (radius - (7.0 if mark else 4.0)), hub + dir * (radius + (4.0 if mark else 1.0)), Palette.AMBER if mark else Palette.SAND, 3.0 if mark else 1.5)
	var angle := PI + PI * clampf((now - 1) / float(classes - 1), 0.0, 1.0)
	draw_line(hub, hub + Vector2(cos(angle), sin(angle)) * (radius - 2.0), Palette.SAND, 2.0)
	draw_circle(hub, 2.5, Palette.SAND)


# The maker set this piece belongs to: held pieces filled, this piece's place ringed in amber.
func _set_pips(at: Vector2, held: int, pieces: int, dim: float) -> void:
	_pips(at, held, pieces, dim)
	if held < pieces:
		var x := at.x + (float(held) - (pieces - 1) * 0.5) * 14.0
		draw_arc(Vector2(x, at.y), 8.0, 0.0, TAU, 16, Color(Palette.AMBER, dim), 2.0)


func _pips(at: Vector2, filled: int, cap: int, dim: float) -> void:
	for i in cap:
		var x := at.x + (float(i) - (cap - 1) * 0.5) * 14.0
		var diamond := PackedVector2Array([Vector2(x, at.y - 5.0), Vector2(x + 5.0, at.y), Vector2(x, at.y + 5.0), Vector2(x - 5.0, at.y)])
		if i < filled:
			draw_colored_polygon(diamond, Color(Palette.ARC, dim))
		else:
			diamond.append(diamond[0])
			draw_polyline(diamond, Color(Palette.SAND, 0.5 * dim), 1.5)


# Reroll: two arrows chasing each other round a circle.
func _cycle(centre: Vector2, r: float, tint: Color) -> void:
	for half in 2:
		var start := PI * half + 0.35
		var end := start + PI - 0.7
		draw_arc(centre, r, start, end, 14, tint, 5.0)
		var tip := centre + Vector2(cos(end), sin(end)) * r
		var along := Vector2(-sin(end), cos(end))
		var out := Vector2(cos(end), sin(end))
		draw_colored_polygon(PackedVector2Array([tip + along * 9.0, tip + out * 7.0, tip - out * 7.0]), tint)


func _dashed(rect: Rect2, tint: Color) -> void:
	var points := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for i in 4:
		draw_dashed_line(points[i], points[i + 1], tint, 2.0, 8.0)
