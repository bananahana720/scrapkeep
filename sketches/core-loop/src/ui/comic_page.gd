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
# The finale carries a lost run's loss card under its caption, both at the 18 px floor.
const FINALE_WEIGHT := 1.3
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
			w = FINALE_WEIGHT if rows[g[0]].get("kind", "") == "finale" else WIDE_WEIGHT
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
	return "SCRAPKEEP"


static func subtitle_text(p: Dictionary) -> String:
	# One plain sentence that always fits: who, where and, for a loss, how it ended. The loss card is
	# dropped on a small page and the title shows the pilot only when it has no title of its own, so this
	# line is where a small page says how the run went.
	var who := String(p.get("pilot_name", ""))
	var where := String(p.get("world_name", ""))
	var line := who
	if who != "" and where != "":
		line = "%s in %s" % [who, where]
	elif where != "":
		line = where
	line = line + "." if line != "" else ""
	if not ScrapbookStore.is_won(p):
		line = (line + " Hull not returned.").strip_edges()
	return line


# The subtitle's font size: its sentence shrinks until it fits `room`, never under 9 px.
static func subtitle_font(p: Dictionary, room: float, k: float) -> int:
	var font := UiFonts.bold()
	var fs := maxi(9, int(19.0 * k))
	var line := subtitle_text(p)
	while fs > 9 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	return fs


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
	var card := melodrama(p)
	var kept := fit_rows(box, list, card)
	var rects := panel_rects(box, kept.map(func(i): return list[i]))
	for j in kept.size():
		_draw_panel(rects[j], list[kept[j]], kept[j], k)
	if card != "" and not rects.is_empty() and card_fits(box, list, kept, card):
		_card(rects[rects.size() - 1], card, k)


# The indexes of the rows the page draws. A small page cannot hold six panels' captions at the
# caption floor, so while any caption (or the finale's loss card) would spill out of its panel the
# last middle panel is left off, down to the opening, one middle panel and the finale.
static func fit_rows(box: Rect2, list: Array, card := "") -> Array:
	var kept: Array = range(list.size())
	while kept.size() > 3:
		if captions_fit(box, list, kept) and (card == "" or card_fits(box, list, kept, card)):
			break
		kept.remove_at(kept.size() - 2)
	return kept


static func captions_fit(box: Rect2, list: Array, kept: Array) -> bool:
	var rects := panel_rects(box, kept.map(func(i): return list[i]))
	for j in kept.size():
		var said := String(list[kept[j]].get("caption", ""))
		if said != "" and not rects[j].encloses(caption_rect(rects[j], said, box.size.x / 720.0)):
			return false
	return true


# Whether the loss card sits in the finale clear of the finale's own caption. A page too small for
# both draws the caption alone: the card is the joke, the caption is the story.
static func card_fits(box: Rect2, list: Array, kept: Array, card: String) -> bool:
	var rects := panel_rects(box, kept.map(func(i): return list[i]))
	var last: Rect2 = rects[rects.size() - 1]
	var k := box.size.x / 720.0
	var plate := card_rect(last, card, k)
	var said := String(list[kept[kept.size() - 1]].get("caption", ""))
	return last.encloses(plate) and (said == "" or not plate.intersects(caption_rect(last, said, k)))


# Where each panel sits on a page drawn into `box` (the page's own rectangle).
static func panel_rects(box: Rect2, list: Array) -> Array:
	var k := box.size.x / 720.0
	var margin := 22.0 * k
	var title_h := 118.0 * k
	var area := Rect2(box.position.x + margin, box.position.y + margin * 2.0 + title_h,
		box.size.x - margin * 2.0, box.size.y - margin * 3.0 - title_h)
	return layout(list, area, 12.0 * k)


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
	draw_string(font, r.position + Vector2(skew + 12.0 * k, r.size.y * 0.86), subtitle_text(p), HORIZONTAL_ALIGNMENT_LEFT, room, subtitle_font(p, room, k), Palette.SAND)


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
	if caption_shown(r, caption, k):
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


# The narrator box inside panel `r`: top left, as wide as its words need up to the panel's width
# less the 8 k margins, and as tall as the wrapped words. Drawing and the fit test share it.
static func caption_rect(r: Rect2, text: String, k: float) -> Rect2:
	var pad := 6.0 * k
	var width := r.size.x - 16.0 * k
	var inner := maxf(10.0, width - pad * 2.0)
	var sz := UiFonts.bold().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, caption_font(k))
	return Rect2(r.position + Vector2(8.0 * k, 8.0 * k), Vector2(minf(width, sz.x + pad * 2.0), sz.y + pad * 2.0))


# A page squeezed under what fit_rows can rescue (a long summary body) shows the picture alone:
# a caption is drawn only where it lies inside its panel.
static func caption_shown(r: Rect2, text: String, k: float) -> bool:
	return text != "" and r.encloses(caption_rect(r, text, k))


func _caption(r: Rect2, text: String, k: float) -> void:
	var fs := caption_font(k)
	var pad := 6.0 * k
	var box := caption_rect(r, text, k)
	draw_rect(box, Palette.BRASS.lerp(Palette.LEDGER, 0.55))
	draw_rect(box, INK_COLOR, false, 3.0 * k)
	draw_multiline_string(UiFonts.bold(), box.position + Vector2(pad, pad + fs), text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - pad * 2.0, fs, -1, INK_COLOR)


# The loss card: ink box on the finale's bottom edge, amber type.
# The same box on the finale's bottom edge.
static func card_rect(r: Rect2, text: String, k: float) -> Rect2:
	var pad := 6.0 * k
	var width := r.size.x - 16.0 * k
	var inner := maxf(10.0, width - pad * 2.0)
	var sz := UiFonts.bold().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, caption_font(k))
	return Rect2(Vector2(r.position.x + 8.0 * k, r.end.y - sz.y - pad * 2.0 - 8.0 * k), Vector2(minf(width, sz.x + pad * 2.0), sz.y + pad * 2.0))


func _card(r: Rect2, text: String, k: float) -> void:
	var fs := caption_font(k)
	var pad := 6.0 * k
	var box := card_rect(r, text, k)
	draw_rect(box, INK_COLOR)
	draw_rect(box, Palette.AMBER, false, 2.0 * k)
	draw_multiline_string(UiFonts.bold(), box.position + Vector2(pad, pad + fs), text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - pad * 2.0, fs, -1, Palette.AMBER)
