extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const Icons := preload("res://src/core/icons.gd")
const Parts := preload("res://src/build/parts.gd")
const ScreenRegions := preload("res://src/core/screen_regions.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")


const RUN := 0.9
const COOLDOWN := 4.0
const NAME_USES := 3
const FIGHT_LIMIT := 1
const CALM_LIMIT := 2
const CALM_SECONDS := 3.0
const SIZE := Vector2(176.0, 62.0)
const RETICLE_CLEAR := 70.0
const BESIDE := 34.0
const GLYPH := 30.0
const NAME_FONT := UiTokens.CAPTION
const USE_PREFIX := "why:"


var game
var profile

var _pieces: Array = []
var _since := {}
var _calm_left := 0.0


static func callout_icons(id: String) -> Array:
	var call := Synergies.callout(id)
	if call.is_empty():
		return []
	var out: Array = []
	for part_id in [call.get("a", ""), call.get("b", "")]:
		var icon := Parts.icon_of(String(part_id))
		if not Icons.has(icon):
			return []
		out.append(icon)
	return out


static func place(anchor: Vector2, part: Vector2, screen: Vector2) -> Vector2:
	var area := Rect2(screen.x * ScreenRegions.SIDE_MARGIN, ScreenRegions.rect("toasts", screen).end.y,
		screen.x * (1.0 - 2.0 * ScreenRegions.SIDE_MARGIN), 0.0)
	area.size.y = ScreenRegions.rect("prompts", screen).position.y - area.position.y
	var spot := _clamp(anchor + Vector2(BESIDE, -part.y * 0.5), part, area)
	var zone := Rect2(screen * 0.5 - Vector2.ONE * RETICLE_CLEAR, Vector2.ONE * RETICLE_CLEAR * 2.0)
	if Rect2(spot, part).intersects(zone):
		var right := _clamp(Vector2(zone.end.x + 8.0, spot.y), part, area)
		var left := _clamp(Vector2(zone.position.x - 8.0 - part.x, spot.y), part, area)
		if not Rect2(right, part).intersects(zone):
			spot = right
		elif not Rect2(left, part).intersects(zone):
			spot = left
		else:
			spot = _clamp(Vector2(spot.x, zone.position.y - 8.0 - part.y), part, area)
	return spot


static func _clamp(spot: Vector2, part: Vector2, area: Rect2) -> Vector2:
	return Vector2(clampf(spot.x, area.position.x, maxf(area.position.x, area.end.x - part.x)),
		clampf(spot.y, area.position.y, maxf(area.position.y, area.end.y - part.y)))


func setup(game_ref, profile_ref) -> void:
	game = game_ref
	profile = profile_ref
	name = "WhyCallout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	game.events.cause_fired.connect(_on_fired)
	game.events.player_hit.connect(func(_amount: float, _source: String): _calm_left = CALM_SECONDS)
	game.events.stage_entered.connect(func(_stage: int, _retry: bool): clear())


func callouts() -> Array:
	return _pieces.duplicate()


func clear() -> void:
	for piece in _pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	_pieces.clear()
	_since.clear()


static func threat_live(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for node in tree.get_nodes_in_group(Threat.GROUP):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return true
	return false


static func calm_left_after(left: float, delta: float, tree: SceneTree) -> float:
	if threat_live(tree):
		return CALM_SECONDS
	return maxf(0.0, left - delta)


static func is_calm(left: float, tree: SceneTree) -> bool:
	return left <= 0.0 and not threat_live(tree) and not (tree != null and tree.paused)


func fight() -> bool:
	return not is_calm(_calm_left, get_tree() if is_inside_tree() else null)


func _on_fired(id: String, target: Node3D, at: Vector3) -> void:
	var icons := callout_icons(id)
	if icons.is_empty() or EventKinds.cause_row(id).is_empty():
		return
	if float(_since.get(id, COOLDOWN)) < COOLDOWN:
		return
	if _pieces.size() >= (FIGHT_LIMIT if fight() else CALM_LIMIT):
		return
	_since[id] = 0.0
	var piece := Piece.new()
	piece.id = id
	piece.shape = String(EventKinds.cause_row(id)["shape"])
	piece.color = EventKinds.cause_color(id)
	piece.part_icons = icons
	piece.target = target
	piece.at = at
	var key := USE_PREFIX + id
	if profile != null and profile.uses(key) < NAME_USES:
		piece.label = String(Synergies.ROWS[id]["name"])
		profile.add_use(key)
	else:
		piece.label = String(Synergies.callout(id).get("words", ""))
	piece.size = SIZE
	piece.custom_minimum_size = SIZE
	add_child(piece)
	_pieces.append(piece)
	_place(piece)


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_calm_left = calm_left_after(_calm_left, delta, get_tree() if is_inside_tree() else null)
	for id in _since:
		_since[id] += delta
	for piece in _pieces.duplicate():
		piece.age += delta
		if piece.age >= RUN:
			_pieces.erase(piece)
			piece.queue_free()
		else:
			_place(piece)
			piece.queue_redraw()


func _place(piece: Control) -> void:
	var screen := get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)
	var world: Vector3 = piece.at
	if piece.target != null and is_instance_valid(piece.target):
		world = piece.target.global_position + Vector3.UP
	var anchor := screen * 0.5
	var cam: Camera3D = game.camera.cam if game != null and game.camera != null else null
	if cam != null and cam.is_inside_tree() and not cam.is_position_behind(world):
		anchor = cam.unproject_position(world)
	piece.position = place(anchor, piece.size, screen)


class Piece extends Control:
	var id := ""
	var shape := ""
	var color := Color.WHITE
	var part_icons: Array = []
	var label := ""
	var age := 0.0
	var target: Node3D
	var at := Vector3.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		name = "Callout"

	func drawn_words() -> PackedStringArray:
		return PackedStringArray([label]) if label != "" else PackedStringArray()

	func _draw() -> void:
		var p := clampf(age / RUN, 0.0, 1.0)
		var fade := clampf((1.0 - p) / 0.2, 0.0, 1.0)
		var snap := ease(clampf(p / 0.3, 0.0, 1.0), 0.4)
		var y := GLYPH * 0.5 + 2.0
		var first := Vector2(GLYPH * 0.5 + 2.0, y)
		var second := first + Vector2(lerpf(GLYPH * 2.4, GLYPH * 1.15, snap), 0.0)
		_icon(first, part_icons[0], fade)
		_icon(second, part_icons[1], fade)
		var from := second + Vector2(GLYPH * 0.7, 0.0)
		var reach := clampf((p - 0.3) / 0.25, 0.0, 1.0)
		var to := from + Vector2(GLYPH * 1.1 * reach, 0.0)
		if reach > 0.0:
			draw_line(from, to, Color(color, fade), 3.0)
			draw_colored_polygon(PackedVector2Array([to + Vector2(7.0, 0.0), to + Vector2(-2.0, -6.0), to + Vector2(-2.0, 6.0)]), Color(color, fade))
		var pop := clampf((p - 0.55) / 0.2, 0.0, 1.0)
		if pop > 0.0:
			_glyph(to + Vector2(GLYPH * 0.9, 0.0), shape, lerpf(0.6, 1.0, pop), fade * pop)
		if label != "":
			draw_string(get_theme_default_font(), Vector2(2.0, GLYPH + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_FONT, Color(color, fade))

	func _glyph(centre: Vector2, silhouette: String, scale_by: float, alpha: float) -> void:
		var side := GLYPH * scale_by
		draw_circle(centre, side * 0.62, Color(color.darkened(0.85), 0.7 * alpha))
		draw_texture_rect(Icons.shape(silhouette), Rect2(centre - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color(color, alpha))

	func _icon(centre: Vector2, icon: String, alpha: float) -> void:
		draw_circle(centre, GLYPH * 0.62, Color(color.darkened(0.85), 0.7 * alpha))
		draw_texture_rect(Icons.texture(icon), Rect2(centre - Vector2.ONE * GLYPH * 0.5, Vector2.ONE * GLYPH), false, Icons.tint(icon, Color(color, alpha)))
