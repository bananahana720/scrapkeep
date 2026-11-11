extends Label

const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Keycap := preload("res://src/ui/keycap.gd")

# A screen-space prompt attached to a point in the world, such as a reward gate's
# offer or a fabricator's price. At range it shows an icon and a title of at most three
# words; within its detail_range of the ball (DETAIL_RANGE unless its owner says otherwise) it
# adds the detail lines. The HUD places every prompt inside the prompts band each frame
# (ScreenRegions) and tells it whether the ball is near.
#
# Owners pass structured parts with set_parts(title, detail, icon). Until they do, the
# text they set is parsed (parse()): the first line is the title, the rest the detail.
# The Label keeps that text as the owner wrote it and draws nothing itself; this script
# draws the icon, title and detail.

const DETAIL_RANGE := 12.0
const TITLE_WORDS := 3
const TITLE_SIZE := UiTokens.BODY
const DETAIL_SIZE := UiTokens.CAPTION
const ICON := 24.0
const ICON_GAP := 6.0
const LINE_GAP := 2.0
# A parsed prompt's icon: the vault by its title, a fabricator by its price in cogs,
# and anything else is a reward gate's offer.
const TITLE_ICONS := {"vault": "obj_vault", "fabricating...": "obj_fabricator"}
const PRICE_WORD := " cogs"
const DEFAULT_ICON := "obj_gate"

# The node the prompt follows, the offset above it, and how far away it still shows.
var anchor: Node3D
var offset := Vector3.ZERO
var reach := 60.0
# How close the ball must be for the detail lines. An owner whose detail is what the player
# chooses by (a reward gate, picked by steering at it from across the yard) sets it to its reach.
var detail_range := DETAIL_RANGE
# Set by the HUD each frame: the ball is within detail_range of the anchor.
var near := false

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
	return _parts


func is_empty() -> bool:
	return String(parts()["title"]) == "" and not _glyph


func shown_lines() -> PackedStringArray:
	var p := parts()
	var lines := PackedStringArray([p["title"]])
	if near and p["detail"] != "":
		lines.append_array(String(p["detail"]).split("\n", false))
	return lines


func drawn_words() -> PackedStringArray:
	if not visible or is_empty():
		return PackedStringArray()
	var out := Keycap.words(keycap) if keycap != "" else PackedStringArray()
	out.append_array(shown_lines())
	return out


func _cap_width() -> float:
	return Keycap.size_of(keycap, ICON).x + ICON_GAP if keycap != "" else 0.0


func shown_extent() -> Vector2:
	var font := UiFonts.bold()
	var lines := shown_lines()
	var width := _cap_width() + ICON + ICON_GAP + font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var height := maxf(ICON, font.get_height(TITLE_SIZE))
	for i in range(1, lines.size()):
		width = maxf(width, font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_SIZE).x)
		height += LINE_GAP + font.get_height(DETAIL_SIZE)
	return Vector2(minf(width + 8.0, ScreenRegions.PROMPT_WIDTH), height)


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
	var title_w := font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var row_h := maxf(ICON, font.get_height(TITLE_SIZE))
	var x := (extent.x - (_cap_width() + ICON + ICON_GAP + title_w)) * 0.5
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
	var baseline := (row_h + font.get_ascent(TITLE_SIZE) - font.get_descent(TITLE_SIZE)) * 0.5
	var at := Vector2(x + ICON + ICON_GAP, baseline)
	draw_string_outline(font, at, lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 6, outline)
	draw_string(font, at, lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, color)
	var y := row_h
	for i in range(1, lines.size()):
		y += LINE_GAP + font.get_ascent(DETAIL_SIZE)
		var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_SIZE).x
		var line_at := Vector2((extent.x - w) * 0.5, y)
		draw_string_outline(font, line_at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_SIZE, 5, outline)
		draw_string(font, line_at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_SIZE, Color(color, 0.9))
		y += font.get_descent(DETAIL_SIZE)
