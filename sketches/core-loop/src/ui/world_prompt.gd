extends Label

const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Keycap := preload("res://src/ui/keycap.gd")

# A screen-space prompt attached to a point in the world, such as a reward gate's
# offer or a fabricator's price. At range it shows an icon and a title of at most three
# words; within its detail_range of the ball (DETAIL_RANGE unless its owner says otherwise) it
# adds the detail lines. The HUD places every prompt each frame (ScreenRegions): inside the
# prompts band, or on its anchor when it is a sign, and tells it whether the ball is near.
#
# Owners pass structured parts with set_parts(title, detail, icon). Until they do, the
# text they set is parsed (parse()): the first line is the title, the rest the detail.
# The Label keeps that text as the owner wrote it and draws nothing itself; this script
# draws the icon, title and detail.

const DETAIL_RANGE := 12.0
const TITLE_WORDS := 3
const TITLE_SIZE := UiTokens.BODY
const DETAIL_SIZE := UiTokens.CAPTION
# A sign reads a type step larger: it is chosen from across the yard (PF-22, "small blue text").
const SIGN_TITLE_SIZE := UiTokens.LABEL
const SIGN_DETAIL_SIZE := UiTokens.BODY
const ICON := 24.0
const ICON_GAP := 6.0
const LINE_GAP := 2.0
# A parsed prompt's icon: the vault by its title, a fabricator by its price in cogs,
# and anything else is a reward gate's offer.
const TITLE_ICONS := {"vault": "obj_vault", "fabricating...": "obj_fabricator"}
const PRICE_WORD := " cogs"
const DEFAULT_ICON := "obj_gate"
# A leader shorter than this, or one whose anchor is not above the prompt, is not drawn: the
# column already says whose name it is.
const LEADER_MIN := 24.0
const LEADER_WIDTH := 2.0
const LEADER_DOT := 3.5

# The node the prompt follows, the offset above it, and how far away it still shows.
var anchor: Node3D
var offset := Vector3.ZERO
var reach := 60.0
# How close the ball must be for the detail lines. An owner whose detail is what the player
# chooses by (a reward gate, picked by steering at it from across the yard) sets it to its reach.
var detail_range := DETAIL_RANGE
# Set by the HUD each frame: the ball is within detail_range of the anchor.
var near := false
# A sign (on_anchor) names the thing it hangs on (a reward gate's offer): the HUD hangs it from its
# anchor in the gate's own slot of the sign room, not in the prompts band, so each gate wears its own
# part (PF-22). The HUD gives it the slot's width (fit_sign) and it chooses how much to show (below).
# When the ball or the reticle's ring is in the way it hangs lower, and then draws a leader from its
# name up to the anchor. aim_at sets `aim`, where that line ends on screen, and `aim_cut`, true when the
# line stops short of the anchor at the play view's top edge or the reticle ring's edge.
var on_anchor := false
var aim := Vector2.INF
var aim_cut := false
var _aim_full := Vector2.INF

# What a sign shows, best first: 0 the name and the detail wrapped to the slot (at most
# SIGN_DETAIL_LINES lines), 1 the name alone, 2 the name alone at the floor size (BODY, the band
# prompts' own size), 3 nothing. -1 before the HUD has fitted it. A sign showing a level keeps it until
# the slot is narrower than that level's fit width less SIGN_HYSTERESIS, and takes a better level only
# when the slot is wider than its fit width plus SIGN_HYSTERESIS, where the fit width is the width the
# level needs plus SIGN_HYSTERESIS, so a column crossing the screen does not flicker between them.
const SIGN_LEVELS := 3
const SIGN_DETAIL_LINES := 2
const SIGN_HYSTERESIS := 16.0
const SIGN_FLOOR_SIZE := UiTokens.BODY
var _level := -1
var _sign_lines := PackedStringArray()
var _sign_extent := Vector2.ZERO
var _needs := {}

var _structured := false
var _parts := {"title": "", "detail": "", "icon": DEFAULT_ICON}
var _parsed_from := ""
# v3 interact (world/device.gd): the key drawn before the icon ("" for none), a
# not-ready device's gauge round the icon (-1 for none), and whether the icon alone
# is a prompt, so the family glyph shows at range with no words.
var keycap := ""
var gauge := -1.0
var _glyph := false


func _init() -> void:
	add_to_group(ScreenRegions.PROMPT_GROUP)
	visible = false
	visible_characters = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", TITLE_SIZE)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	add_theme_constant_override("outline_size", 6)


func attach(anchor_node: Node3D, anchor_offset: Vector3, show_within: float) -> void:
	anchor = anchor_node
	offset = anchor_offset
	reach = show_within


func anchor_point() -> Vector3:
	return anchor.global_position + offset if is_instance_valid(anchor) and anchor.is_inside_tree() else Vector3.INF


func set_parts(title_text: String, detail_text := "", icon_id := DEFAULT_ICON) -> void:
	_structured = true
	_parts = {"title": title_text, "detail": detail_text, "icon": icon_id}
	_needs.clear()
	queue_redraw()


# An interactable's prompt: icon "" hides it; words "" is the glyph alone.
func set_interact(icon_id: String, words: String, key: String, fill: float) -> void:
	assert(key == "" or words != "", "a key prompt needs a word beside its icon (PF-03)")
	_structured = true
	_glyph = icon_id != ""
	keycap = key
	gauge = fill
	_parts = {"title": words, "detail": "", "icon": icon_id if icon_id != "" else DEFAULT_ICON}


# The first line is the title and the rest the detail. A title with a colon keeps what
# comes before it; past three words the rest moves to the front of the detail.
static func parse(source: String) -> Dictionary:
	var lines := Array(source.strip_edges().split("\n", false))
	if lines.is_empty():
		return {"title": "", "detail": "", "icon": DEFAULT_ICON}
	var title := String(lines.pop_front()).strip_edges()
	var colon := title.find(":")
	if colon > 0:
		var after := title.substr(colon + 1).strip_edges()
		title = title.left(colon).strip_edges()
		if after != "":
			lines.push_front(after)
	var words := title.split(" ", false)
	if words.size() > TITLE_WORDS:
		title = " ".join(words.slice(0, TITLE_WORDS))
		lines.push_front(" ".join(words.slice(TITLE_WORDS)))
	var first := title.split(" ", false)[0].to_lower() if title != "" else ""
	var detail := "\n".join(PackedStringArray(lines))
	var icon: String = TITLE_ICONS.get(first, "obj_fabricator" if detail.contains(PRICE_WORD) else DEFAULT_ICON)
	return {"title": title, "detail": detail, "icon": icon}


func parts() -> Dictionary:
	if not _structured and text != _parsed_from:
		_parsed_from = text
		_parts = parse(text)
		_needs.clear()
	return _parts


func is_empty() -> bool:
	return String(parts()["title"]) == "" and not _glyph


func shown_lines() -> PackedStringArray:
	var p := parts()
	var lines := PackedStringArray([p["title"]])
	if on_anchor and _level >= 0:
		if _level == 0:
			lines.append_array(_sign_lines)
		return lines
	if near and p["detail"] != "":
		lines.append_array(String(p["detail"]).split("\n", false))
	return lines


func drawn_words() -> PackedStringArray:
	if not visible or is_empty():
		return PackedStringArray()
	var out := Keycap.words(keycap) if keycap != "" else PackedStringArray()
	out.append_array(shown_lines())
	return out


func title_size() -> int:
	if not on_anchor:
		return TITLE_SIZE
	return SIGN_FLOOR_SIZE if _level == 2 else SIGN_TITLE_SIZE


func detail_size() -> int:
	return SIGN_DETAIL_SIZE if on_anchor else DETAIL_SIZE


func _cap_width() -> float:
	return Keycap.size_of(keycap, ICON).x + ICON_GAP if keycap != "" else 0.0


# The width of the icon and title row at a title size: what the draw lays out.
func _title_row_width(size: int) -> float:
	return _cap_width() + ICON + ICON_GAP + UiFonts.bold().get_string_size(String(parts()["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _line_width(line: String, size: int) -> float:
	return UiFonts.bold().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# The rows the draw lays out, as {line, size, width}: the title row (its width includes the key cap
# and icon) and the detail lines. The rectangle's words, text_width and _draw all read these.
func drawn_rows() -> Array:
	var lines := shown_lines()
	var rows: Array = [{"line": lines[0], "size": title_size(), "width": _title_row_width(title_size())}]
	for i in range(1, lines.size()):
		rows.append({"line": lines[i], "size": detail_size(), "width": _line_width(lines[i], detail_size())})
	return rows


func _extent_of(title_size_px: int, lines: PackedStringArray, width: float) -> Vector2:
	var font := UiFonts.bold()
	var height := maxf(ICON, font.get_height(title_size_px))
	for i in range(1, lines.size()):
		height += LINE_GAP + font.get_height(detail_size())
	return Vector2(width, height)


func shown_extent() -> Vector2:
	if on_anchor and _level >= 0 and _level < SIGN_LEVELS:
		return _sign_extent
	return _extent_of(title_size(), shown_lines(), minf(text_width() + 8.0, ScreenRegions.PROMPT_WIDTH))


# The widest row the draw lays out, for a reader that checks the words stay inside the rectangle.
func text_width() -> float:
	var width := 0.0
	for row in drawn_rows():
		width = maxf(width, row["width"])
	return width


# Wraps `source` (its own lines kept apart) to `inner` px at the detail size, greedily by words. An
# empty result when it needs more than SIGN_DETAIL_LINES lines or a word is wider than `inner`.
func _wrap_detail(source: String, inner: float) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in source.split("\n", false):
		var row := ""
		for word in raw.split(" ", false):
			var trial := word if row == "" else row + " " + word
			if row != "" and _line_width(trial, detail_size()) > inner:
				out.append(row)
				row = word
			else:
				row = trial
			if _line_width(word, detail_size()) > inner:
				return PackedStringArray()
		if row != "":
			out.append(row)
	return out if out.size() <= SIGN_DETAIL_LINES else PackedStringArray()


func _natural_width() -> float:
	var width := _title_row_width(SIGN_TITLE_SIZE)
	for raw in String(parts()["detail"]).split("\n", false):
		width = maxf(width, _line_width(raw, detail_size()))
	return width


# The width a sign needs at a level (INF when the level cannot show). Level 0's is the narrowest
# rectangle its detail wraps into in SIGN_DETAIL_LINES lines.
func sign_need(level: int) -> float:
	if not _needs.has(level):
		_needs[level] = _measure_need(level)
	return _needs[level]


func _measure_need(level: int) -> float:
	var size := SIGN_TITLE_SIZE if level < 2 else SIGN_FLOOR_SIZE
	var title := _title_row_width(size)
	if level > 0:
		return title + 8.0
	if String(parts()["detail"]) == "":
		return INF
	var detail := String(parts()["detail"])
	var hi := _natural_width()
	if _wrap_detail(detail, hi).is_empty():
		return INF
	var lo := title
	for _i in 12:
		var mid := (lo + hi) * 0.5
		if _wrap_detail(detail, mid).is_empty() or mid < title:
			lo = mid
		else:
			hi = mid
	hi = maxf(hi, title)
	return hi + 8.0 if hi + 8.0 <= ScreenRegions.PROMPT_WIDTH else INF


# Chooses what the sign shows for a slot `slot_width` wide, with the hysteresis above, and fits it.
# Returns the level, SIGN_LEVELS when nothing fits.
func fit_sign(slot_width: float) -> int:
	var held := _level
	for k in SIGN_LEVELS:
		if k == 0 and not near:
			continue
		var need := sign_need(k)
		if need == INF:
			continue
		var better := held >= 0 and held < SIGN_LEVELS and k < held
		var fits: bool = slot_width > need + 2.0 * SIGN_HYSTERESIS if better else slot_width >= need
		if fits:
			if apply_level(k, slot_width):
				return k
	_level = SIGN_LEVELS
	return SIGN_LEVELS


# Fits the sign at `level` for a slot `slot_width` wide; false, and nothing changed, when it needs
# more width. The rectangle at level 0 is as wide as the slot allows up to its text's own width, so it
# changes smoothly as the slot does and the words only re-wrap inside it.
func apply_level(level: int, slot_width: float) -> bool:
	var need := sign_need(level)
	if need == INF or need > slot_width + 0.001:
		return false
	_level = level
	var size := SIGN_TITLE_SIZE if level < 2 else SIGN_FLOOR_SIZE
	if level == 0:
		var width := minf(minf(slot_width, ScreenRegions.PROMPT_WIDTH), _natural_width() + 8.0)
		_sign_lines = _wrap_detail(String(parts()["detail"]), width - 8.0)
		_sign_extent = _extent_of(size, PackedStringArray(["x"]) + _sign_lines, width)
	else:
		_sign_lines = PackedStringArray()
		_sign_extent = _extent_of(size, PackedStringArray(["x"]), need)
	return true


func sign_level() -> int:
	return _level


# Points the leader at `point` (where the anchor projects). The line stops where it would leave `room`
# through the top (nothing drawn in one band reaches another, CONTRACTS.md, UI regions) and at the
# edge of `ring` (the reticle's ring) when it would run through it. Whether it is drawn at all is
# leader_end's rule. Vector2.INF clears it.
func aim_at(point: Vector2, room: Rect2, ring := Rect2()) -> void:
	aim_cut = false
	aim = point
	_aim_full = point
	if not on_anchor or not point.is_finite():
		return
	var start := position + _leader_start()
	if point.y < room.position.y and start.y >= room.position.y:
		aim = start.lerp(point, (start.y - room.position.y) / (start.y - point.y))
		aim_cut = true
		_aim_full = aim
	if ring.has_area() and not ring.has_point(start):
		var corners := [ring.position, Vector2(ring.end.x, ring.position.y), ring.end, Vector2(ring.position.x, ring.end.y)]
		var best := Vector2.INF
		for i in 4:
			var hit = Geometry2D.segment_intersects_segment(start, aim, corners[i], corners[(i + 1) % 4])
			if hit != null and (not best.is_finite() or start.distance_to(hit) < start.distance_to(best)):
				best = hit
		if best.is_finite():
			aim = best
			aim_cut = true


# The leader's far end in the prompt's own space, or Vector2.INF when it draws none: the gate must stand
# LEADER_MIN or more above the name (up to the view's top edge when it is above the view), measured
# before the ring takes its share, so a name pushed down under the ring still has its tie.
func leader_end() -> Vector2:
	if not on_anchor or not aim.is_finite():
		return Vector2.INF
	var full := _aim_full if _aim_full.is_finite() else aim
	var start := _leader_start()
	var end := aim - position
	return end if end.y < start.y and start.y - (full.y - position.y) >= LEADER_MIN else Vector2.INF


# The leader leaves from the top of the name, over its middle.
func _leader_start() -> Vector2:
	return Vector2(shown_extent().x * 0.5, 0.0)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if is_empty():
		return
	var font := UiFonts.bold()
	var color := get_theme_color("font_color")
	var outline := get_theme_color("font_outline_color")
	var lines := shown_lines()
	var extent := shown_extent()
	var end := leader_end()
	if end.is_finite():
		var start := _leader_start()
		draw_line(start, end, Color(outline, 0.6), LEADER_WIDTH + 3.0, true)
		draw_line(start, end, Color(color, 0.85), LEADER_WIDTH, true)
		if not aim_cut:
			draw_circle(end, LEADER_DOT + 1.5, Color(outline, 0.6))
			draw_circle(end, LEADER_DOT, color)
	var rows := drawn_rows()
	var row_h := maxf(ICON, font.get_height(title_size()))
	var x := (extent.x - float(rows[0]["width"])) * 0.5
	if keycap != "":
		var cap := Keycap.size_of(keycap, ICON)
		Keycap.draw(self, Vector2(x + cap.x * 0.5, row_h * 0.5), keycap, color, ICON)
		x += cap.x + ICON_GAP
	var icon: String = parts()["icon"]
	draw_texture_rect(Icons.texture(icon), Rect2(Vector2(x, (row_h - ICON) * 0.5), Vector2(ICON, ICON)), false, Icons.tint(icon, color))
	if gauge >= 0.0:
		var centre := Vector2(x + ICON * 0.5, row_h * 0.5)
		draw_arc(centre, ICON * 0.72, 0.0, TAU, 32, Color(outline, 0.6), 3.0)
		draw_arc(centre, ICON * 0.72, -PI * 0.5, -PI * 0.5 + TAU * clampf(gauge, 0.0, 1.0), 32, color, 3.0)
	var baseline := (row_h + font.get_ascent(title_size()) - font.get_descent(title_size())) * 0.5
	var at := Vector2(x + ICON + ICON_GAP, baseline)
	draw_string_outline(font, at, lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size(), 6, outline)
	draw_string(font, at, lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size(), color)
	var y := row_h
	for i in range(1, lines.size()):
		y += LINE_GAP + font.get_ascent(detail_size())
		var w: float = rows[i]["width"]
		var line_at := Vector2((extent.x - w) * 0.5, y)
		draw_string_outline(font, line_at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, detail_size(), 5, outline)
		draw_string(font, line_at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, detail_size(), Color(color, 0.9))
		y += font.get_descent(detail_size())
