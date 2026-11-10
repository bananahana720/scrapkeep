extends Control

# One run's comic page (the run-end thread's page dictionary; see scrapbook_store.gd for
# the keys) drawn as a page: the issue line as the title card, then 4 to 6 inked panels
# laid out from each panel's size hint, each with a deadpan caption box and, when the panel
# has a word, an onomatopoeia burst. A panel with a screenshot draws it; without one (a
# headless run, an old page) the panel is drawn from Palette in the world's colour. A page
# with no panels still draws: the title and one dry blank panel. A lost run closes on one
# deliberately melodramatic card that knows it is corny. Palette and UiFonts only.
#
#   var cp := ComicPage.new()
#   cp.custom_minimum_size = Vector2(540, 720)   # 3:4; any size draws, the page letterboxes
#   parent.add_child(cp)
#   cp.show_page(page)
#
# Pure helpers (layout, words) are static so a test can read them without a tree.

const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScrapbookStore := preload("res://src/core/scrapbook_store.gd")
const ASPECT := 0.75
const MAX_PANELS := 6
const INK_COLOR := Color("242a28")
const BURST_POINTS := 11
const WIDE_WEIGHT := 0.8
const TALL_WEIGHT := 1.3

# No caption draws under this many px: at the summary's page size the scaled 15 px read as 9 px
# (the project's floor for bold small type is 18 px, VISUAL-LANGUAGE.md).
const CAPTION_MIN_FONT := 18
const EMPTY_CAPTION := "Page left blank. The pen is in the log, under the kettle."

const LOSS_CARDS := [
	"And so the hull fell, in a panel far too grand for the occasion.",
	"If this were a better comic, this is where the rain would start. It is just the pump.",
	"Our pilot stares at the ground, dramatically. Somebody off-panel sighs, on cue.",
	"The camera pulls back slowly. This is the corny bit. We are aware.",
]

var page := {}
var panels: Array = []
var _textures := {}


func _init() -> void:
	name = "ComicPage"
	custom_minimum_size = Vector2(360.0, 480.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_page(next: Dictionary) -> void:
	page = next
	panels = rows_of(next)
	_textures.clear()
	for i in panels.size():
		var shot = panels[i].get("shot")
		if shot is Image and not (shot as Image).is_empty():
			_textures[i] = ImageTexture.create_from_image(shot)
	queue_redraw()


# --- Structure and words (static) ---

# The panel rows to draw: at most MAX_PANELS well-typed dictionaries; the lone blank panel
# stands in for a page with none.
static func rows_of(p: Dictionary) -> Array:
	var out: Array = []
	var raw = p.get("panels", [])
	if raw is Array:
		for row in raw:
			if row is Dictionary and out.size() < MAX_PANELS:
				out.append(row)
	if out.is_empty():
		out.append({"kind": "opening", "caption": EMPTY_CAPTION, "sfx": "", "size": "wide", "world": int(p.get("world", 1))})
	return out


static func size_of(row: Dictionary) -> String:
	var hint := String(row.get("size", "square"))
	return hint if hint in ["wide", "tall", "square"] else "square"


# Rectangles inside `area`, one per row, from the size hints. Panels fill rows in order:
# a wide panel takes a row alone; two others share one (a tall beside a square is the
# narrower of the pair); a lone one left over takes its row whole. A row with a tall is
# taller, one with a wide is shorter. No holes, no overlap, `gutter` between.
static func layout(rows: Array, area: Rect2, gutter: float) -> Array:
	var groups: Array = []
	var i := 0
	while i < rows.size():
		var hint := size_of(rows[i])
		if hint == "wide" or i + 1 >= rows.size() or size_of(rows[i + 1]) == "wide":
			groups.append([i])
			i += 1
		else:
			groups.append([i, i + 1])
			i += 2
	var weights: Array = []
	var total := 0.0
	for g in groups:
		var w := 1.0
		if size_of(rows[g[0]]) == "wide" and g.size() == 1:
			w = WIDE_WEIGHT
		for idx in g:
			if size_of(rows[idx]) == "tall":
				w = TALL_WEIGHT
		weights.append(w)
		total += w
	var out: Array = []
	out.resize(rows.size())
	var free_h := area.size.y - gutter * (groups.size() - 1)
	var y := area.position.y
	for gi in groups.size():
		var g: Array = groups[gi]
		var h: float = free_h * weights[gi] / total
		if g.size() == 1:
			out[g[0]] = Rect2(area.position.x, y, area.size.x, h)
		else:
			var usable := area.size.x - gutter
			var a_tall := size_of(rows[g[0]]) == "tall"
			var b_tall := size_of(rows[g[1]]) == "tall"
			var left := usable * (0.5 if a_tall == b_tall else (0.42 if a_tall else 0.58))
			out[g[0]] = Rect2(area.position.x, y, left, h)
			out[g[1]] = Rect2(area.position.x + left + gutter, y, usable - left, h)
		y += h + gutter
	return out


# The melodramatic card for a lost run, "" for a win. Same run, same card.
static func melodrama(p: Dictionary) -> String:
	if ScrapbookStore.is_won(p):
		return ""
	return String(LOSS_CARDS[posmod(String(p.get("run_id", "")).hash(), LOSS_CARDS.size())])


static func title_text(p: Dictionary) -> String:
	var title := String(p.get("title", ""))
	if title != "":
		return title.to_upper()
	var who := String(p.get("pilot_name", ""))
	return ("SCRAPKEEP: %s" % who).to_upper() if who != "" else "SCRAPKEEP"


static func subtitle_text(p: Dictionary) -> String:
	var parts: Array = []
	if String(p.get("pilot_name", "")) != "":
		parts.append(String(p["pilot_name"]).to_upper())
	if String(p.get("world_name", "")) != "":
		parts.append(String(p["world_name"]).to_upper())
	parts.append("RETURN ENTERED" if ScrapbookStore.is_won(p) else "HULL NOT RETURNED")
	return "  |  ".join(parts)


static func world_color(world: int) -> Color:
	match world:
		2:
			return Palette.RUST.lerp(Palette.SANDSTONE, 0.35)
		3:
			return Palette.SLATE.lerp(Palette.ARC, 0.18)
	return Palette.VERDIGRIS


# --- Drawing ---

func _draw() -> void:
	var p: Dictionary = page
	var list: Array = panels if not panels.is_empty() else rows_of(p)
	var box := _page_rect()
	var k := box.size.x / 720.0
	draw_rect(box, Palette.LEDGER)
	draw_rect(box, INK_COLOR, false, 6.0 * k)
	var margin := 22.0 * k
	var title_h := 118.0 * k
	_draw_title(Rect2(box.position + Vector2(margin, margin), Vector2(box.size.x - margin * 2.0, title_h)), p, k)
	var area := Rect2(box.position.x + margin, box.position.y + margin * 2.0 + title_h,
		box.size.x - margin * 2.0, box.size.y - margin * 3.0 - title_h)
	var rects := layout(list, area, 12.0 * k)
	for i in list.size():
		_draw_panel(rects[i], list[i], i, k)
	var card := melodrama(p)
	if card != "" and not rects.is_empty():
		_card(rects[list.size() - 1], card, k)


func _page_rect() -> Rect2:
	var s := minf(size.x, size.y * ASPECT)
	var sz := Vector2(s, s / ASPECT)
	return Rect2((size - sz) * 0.5, sz)


func _draw_title(r: Rect2, p: Dictionary, k: float) -> void:
	var skew := 26.0 * k
	var poly := PackedVector2Array([r.position + Vector2(skew, 0.0), r.position + Vector2(r.size.x, 0.0),
		r.position + Vector2(r.size.x - skew, r.size.y), r.position + Vector2(0.0, r.size.y)])
	draw_colored_polygon(poly, INK_COLOR)
	var edge := PackedVector2Array(poly)
	edge.append(poly[0])
	draw_polyline(edge, Palette.AMBER, 4.0 * k)
	var font := UiFonts.bold()
	var fs := int(46.0 * k)
	var title := title_text(p)
	var room := r.size.x - skew * 2.0 - 12.0 * k
	while fs > 12 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 2
	draw_string(font, r.position + Vector2(skew + 12.0 * k, r.size.y * 0.55), title, HORIZONTAL_ALIGNMENT_LEFT, room, fs, Palette.AMBER)
	draw_string(font, r.position + Vector2(skew + 12.0 * k, r.size.y * 0.86), subtitle_text(p), HORIZONTAL_ALIGNMENT_LEFT, room, maxi(9, int(19.0 * k)), Palette.SAND)


func _draw_panel(r: Rect2, row: Dictionary, index: int, k: float) -> void:
	var tex = _textures.get(index)
	if tex != null:
		draw_texture_rect_region(tex, r, _cover(tex.get_size(), r.size))
	else:
		var fill := world_color(int(row.get("world", 1)))
		draw_rect(r, fill)
		_hatch(r, Color(fill.darkened(0.25), 0.6), 18.0 * k, index)
		_silhouette(r)
	draw_rect(r, INK_COLOR, false, 6.0 * k)
	var sfx := String(row.get("sfx", ""))
	if sfx != "":
		_burst(r, sfx, index, k)
	var caption := String(row.get("caption", ""))
	if caption != "":
		_caption(r, caption, k)


# The source rectangle that fills `into` from a texture without stretching.
static func _cover(src: Vector2, into: Vector2) -> Rect2:
	var want := into.x / maxf(1.0, into.y)
	var have := src.x / maxf(1.0, src.y)
	if have > want:
		var w := src.y * want
		return Rect2((src.x - w) * 0.5, 0.0, w, src.y)
	var h := src.x / want
	return Rect2(0.0, (src.y - h) * 0.5, src.x, h)


func _hatch(r: Rect2, color: Color, step: float, index: int) -> void:
	var lean := 0.6 if index % 2 == 0 else -0.6
	var x := r.position.x - r.size.y * absf(lean)
	while x < r.end.x:
		var seg := _clip(Vector2(x, r.end.y), Vector2(x + r.size.y * lean, r.position.y), r)
		if seg.size() == 2:
			draw_line(seg[0], seg[1], color, 2.0)
		x += step


static func _clip(a: Vector2, b: Vector2, r: Rect2) -> PackedVector2Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for edge in [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]:
		var pp: float = edge[0]
		var qq: float = edge[1]
		if is_zero_approx(pp):
			if qq < 0.0:
				return PackedVector2Array()
		else:
			var t := qq / pp
			if pp < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
	if t0 >= t1:
		return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])


# A hull ball in ink, so a drawn panel is never empty.
func _silhouette(r: Rect2) -> void:
	var c := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.68)
	var radius := minf(r.size.x, r.size.y) * 0.15
	draw_circle(c, radius, Color(INK_COLOR, 0.85))
	draw_circle(c + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.28, Color(Palette.SAND, 0.5))


func _burst(r: Rect2, text: String, index: int, k: float) -> void:
	var c := r.position + Vector2(r.size.x * (0.66 if index % 2 == 1 else 0.34), r.size.y * 0.52)
	var radius := minf(r.size.x * 0.34, r.size.y * 0.3)
	var pts := PackedVector2Array()
	for i in BURST_POINTS * 2:
		var angle := TAU * i / (BURST_POINTS * 2.0) + 0.2 * index
		pts.append(c + Vector2.from_angle(angle) * radius * (1.0 if i % 2 == 0 else 0.62))
	draw_colored_polygon(pts, Palette.HAZARD)
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	draw_polyline(ring, INK_COLOR, 5.0 * k)
	var font := UiFonts.bold()
	var fs := maxi(8, int(radius * 0.7))
	while fs > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > radius * 1.5:
		fs -= 2
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := c + Vector2(-w * 0.5, fs * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(6.0 * k), INK_COLOR)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.LEDGER)


static func caption_font(k: float) -> int:
	return maxi(CAPTION_MIN_FONT, int(15.0 * k))


func _caption(r: Rect2, text: String, k: float) -> void:
	var font := UiFonts.bold()
	var fs := caption_font(k)
	var pad := 6.0 * k
	var width := r.size.x - 20.0 * k
	var inner := maxf(10.0, width - pad * 2.0)
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, fs)
	var box := Rect2(r.position + Vector2(8.0 * k, 8.0 * k), Vector2(minf(width, sz.x + pad * 2.0), sz.y + pad * 2.0))
	draw_rect(box, Palette.BRASS.lerp(Palette.LEDGER, 0.55))
	draw_rect(box, INK_COLOR, false, 3.0 * k)
	draw_multiline_string(font, box.position + Vector2(pad, pad + fs), text, HORIZONTAL_ALIGNMENT_LEFT, inner, fs, -1, INK_COLOR)


# The loss card: ink box on the finale's bottom edge, amber type.
func _card(r: Rect2, text: String, k: float) -> void:
	var font := UiFonts.bold()
	var fs := maxi(9, int(14.0 * k))
	var pad := 6.0 * k
	var width := r.size.x - 20.0 * k
	var inner := maxf(10.0, width - pad * 2.0)
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, fs)
	var box := Rect2(Vector2(r.position.x + 8.0 * k, r.end.y - sz.y - pad * 2.0 - 8.0 * k), Vector2(minf(width, sz.x + pad * 2.0), sz.y + pad * 2.0))
	draw_rect(box, INK_COLOR)
	draw_rect(box, Palette.AMBER, false, 2.0 * k)
	draw_multiline_string(font, box.position + Vector2(pad, pad + fs), text, HORIZONTAL_ALIGNMENT_LEFT, inner, fs, -1, Palette.AMBER)
