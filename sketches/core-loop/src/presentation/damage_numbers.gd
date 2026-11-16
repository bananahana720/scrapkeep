extends Control

const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# Damage numbers (SR6, W13-INTEGRATION-3). One table gives a number and a hit effect the same
# colour for a damage type and a team, so the layers cannot drift apart: effect_colour() is what
# the number draws and what juice.gd tints the burst (a hit dealt) and the edge flash (a hit
# taken) with. A crit takes the enemy_struck crit row's colour (brass), the burst's own. Every colour is a Palette row; none is
# new. A number on one target merges with the next of the same type and team inside
# MERGE_WINDOW_S, and the layer never shows more than MAX_VISIBLE.
# Comps note: ror2/characters-and-feel (damage numbers coloured by type and team; the merge
# window is not in the code searched, so the window and the cap are this unit's start values).
# The numerals are drawn glyphs, not Labels, so the HUD word budget counts none: digits are not
# the words the budget exists to limit, and the cap bounds how many can be on screen.

const TYPES := ["kinetic", "frost", "arc"]
const TEAMS := ["player", "monster", "neutral"]

# Team "player" is damage the player's side deals, so the type colour reads (the element
# colours of part_gained; kinetic is the enemy_struck burst's own copper). "monster" is damage
# the player takes; "neutral" is the world's. Both keep the player_hit juice row's HAZARD.
const PLAYER_COLOURS := {"kinetic": Palette.COPPER, "frost": Palette.ANCIENT, "arc": Palette.ARC}

# A strike kind that is not kinetic names its element; everything else is the ball's weight.
const KIND_TYPES := {"arc": "arc", "frost": "frost"}

# player_fx finds the layer by this group to keep its words off the rising numbers (path_rects).
const GROUP := "damage_numbers"
const MERGE_WINDOW_S := 0.25
const LIFE_S := 0.9
const MAX_VISIBLE := 4
const FONT := 22
const CRIT_FONT := 30
# Overpowered pays (17 Oct): a bigger hit draws a bigger number. From BIG_FROM up, every
# doubling of the figure adds BIG_STEP points, so a merged burst keeps swelling as it grows,
# until MEGA_FONT keeps the biggest one on screen.
const BIG_FROM := 40.0
const BIG_STEP := 6.0
const MEGA_FONT := 60
const RISE := 46.0
const OUTLINE_MIN := 6
const FADE_FROM := 0.6

var project: Callable
# The screen rects a new number starts clear of (the reticle's ring and the target tags); the HUD sets it.
var keep_off: Callable

var _numbers: Array = []


static func type_of_kind(kind: String) -> String:
	return KIND_TYPES.get(kind, "kinetic")


static func team_colours() -> Dictionary:
	var colour: Color = EventKinds.juice("player_hit")["color"]
	return {"monster": colour, "neutral": colour}


static func effect_colour(type: String, team: String, crit := false) -> Color:
	if team == "player":
		if crit:
			return EventKinds.juice("enemy_struck")["crit"]["color"]
		return PLAYER_COLOURS.get(type, Palette.COPPER)
	return team_colours().get(team, EventKinds.juice("player_hit")["color"])


# The team of a hit the player takes: the world's when nothing dealt it.
static func team_of_source(source: String) -> String:
	return "neutral" if source == "" else "monster"


# The one crit rule, read by juice.gd for the stop, shake and burst and by the number: a
# part softer than the body plating (a weak point) or a dealt figure above the punch, read
# before the strike and armour multipliers (base_dealt), which are not crits on their own.
static func is_crit(result: Dictionary, body_plating: float) -> bool:
	var dealt := float(result.get("base_dealt", result.get("dealt", 0.0)))
	var weak := String(result.get("part", "")) != "" and float(result.get("plating", 0.0)) < body_plating
	return weak or dealt > float(result.get("punch", dealt)) * 1.01


# The ink outline's width for a figure of `size` points: three tenths of the size, never under OUTLINE_MIN.
static func outline_px(size: int) -> int:
	return maxi(OUTLINE_MIN, roundi(size * 0.3))


static func font_size(value: float, crit := false) -> int:
	var size := float(CRIT_FONT if crit else FONT)
	if value > BIG_FROM:
		size += BIG_STEP * log(value / BIG_FROM) / log(2.0)
	return mini(MEGA_FONT, roundi(size))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(GROUP)


# One hit. `at` is a screen point (Vector2) or a world point (Vector3, through `project`).
func add(key: String, value: float, at, type: String, team: String, crit := false) -> void:
	for number in _numbers:
		if number["key"] == key and number["type"] == type and number["team"] == team and number["since"] <= MERGE_WINDOW_S:
			number["value"] += value
			number["age"] = 0.0
			number["since"] = 0.0
			number["at"] = at
			number["crit"] = number["crit"] or crit
			number["color"] = effect_colour(type, team, number["crit"])
			return
	var fresh := {"key": key, "value": value, "at": at, "type": type, "team": team, "crit": crit,
		"color": effect_colour(type, team, crit), "age": 0.0, "since": 0.0, "shift": Vector2.ZERO}
	_numbers.append(fresh)
	# Over the cap the smallest figure goes (the oldest of equals), so a run of small hits never
	# evicts a big one early.
	while _numbers.size() > MAX_VISIBLE:
		var least := 0
		for i in _numbers.size():
			if _numbers[i]["value"] < _numbers[least]["value"] \
					or (_numbers[i]["value"] == _numbers[least]["value"] and _numbers[i]["age"] > _numbers[least]["age"]):
				least = i
		_numbers.remove_at(least)
	if _numbers.has(fresh):
		_make_room(fresh)


# Where a new number starts, so it never lands on another, on the reticle, the ball or a tag (PF-26).
# keep_off answers {"ring": rects its start must clear (the reticle's ring, the ball), "tags": rects
# its whole rise must clear}, read once per add. The reticle's ring pushes it out to the right edge;
# the ball's rect pushes it right too, and a tag pushes it to its nearer side. At most MAX_PUSHES sideways pushes, then at most MAX_LINES
# lifts of one line each while its start rect meets a live number's path. The anchor stays on the hit;
# only the drawn figure shifts, by at most MAX_PUSHES rect widths sideways and MAX_LINES lines up.
func _make_room(fresh: Dictionary) -> void:
	if _screen(fresh) == null:
		return
	var off: Dictionary = keep_off.call() if keep_off.is_valid() else {}
	var ring: Array = off.get("ring", [])
	var tags: Array = off.get("tags", [])
	var pushes := 0
	var lines := 0
	for pass_no in MAX_PUSHES + MAX_LINES:
		var start := start_rect(fresh)
		var rise := Rect2(start.position - Vector2(0.0, RISE), start.size + Vector2(0.0, RISE))
		var moved := false
		if pushes < MAX_PUSHES:
			for i in ring.size() + tags.size():
				var r: Rect2 = ring[i] if i < ring.size() else tags[i - ring.size()]
				var hit := (start if i < ring.size() else rise).intersects(r)
				if r.has_area() and hit:
					var right := r.end.x - start.position.x
					var left := r.position.x - start.end.x
					fresh["shift"].x += right if i < ring.size() or absf(right) <= absf(left) else left
					pushes += 1
					moved = true
					break
		if not moved and lines < MAX_LINES:
			if path_rects(fresh).any(func(r): return r.intersects(start)):
				fresh["shift"].y -= start.size.y
				lines += 1
				moved = true
		if not moved:
			return


const MAX_LINES := 4
const MAX_PUSHES := 3


# The rect a figure covers the frame it is stamped: its width and one line, at its anchor plus its shift.
func start_rect(number: Dictionary) -> Rect2:
	var p = _screen(number)
	if p == null:
		return Rect2()
	var size := font_size(number["value"], number["crit"])
	var pad := float(outline_px(size))
	var wide := _text_width(number, size) + pad * 2.0
	return Rect2(Vector2(p.x - wide * 0.5, p.y - size - pad), Vector2(wide, size + pad * 2.0))


func step(delta: float) -> void:
	for number in _numbers:
		number["age"] += delta
		number["since"] += delta
	_numbers = _numbers.filter(func(n): return n["age"] < LIFE_S)
	queue_redraw()


# The screen rect each live number sweeps from where it is stamped to where it fades: the figure's
# width, and its height plus RISE. player_fx keeps its words off these (PF-26). Numbers whose world
# point is behind the camera are skipped.
func path_rects(except: Dictionary = {}) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for number in _numbers:
		if is_same(number, except):
			continue
		var p = _screen(number)
		if p == null:
			continue
		var size := font_size(number["value"], number["crit"])
		var pad := float(outline_px(size))
		var wide := _text_width(number, size) + pad * 2.0
		out.append(Rect2(Vector2(p.x - wide * 0.5, p.y - RISE - size - pad), Vector2(wide, RISE + size + pad * 2.0)))
	return out


# The width _draw gives the figure: the same string, font and size, so the two cannot drift.
func _text_width(number: Dictionary, size: int) -> float:
	return UiFonts.mono().get_string_size(str(maxi(1, roundi(number["value"]))), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func visible_count() -> int:
	return _numbers.size()


func shown() -> Array:
	var out: Array = []
	for number in _numbers:
		out.append({"key": number["key"], "value": number["value"], "color": number["color"],
			"type": number["type"], "team": number["team"], "crit": number["crit"], "age": number["age"]})
	return out


func clear() -> void:
	_numbers.clear()
	queue_redraw()


func _screen(number: Dictionary) -> Variant:
	var at = number["at"]
	if at is Vector3:
		if not project.is_valid():
			return null
		at = project.call(at)
	return at + number.get("shift", Vector2.ZERO) if at != null else null


func _draw() -> void:
	for number in _numbers:
		var p = _screen(number)
		if p == null:
			continue
		var t: float = number["age"] / LIFE_S
		var colour: Color = number["color"]
		colour.a = 1.0 if t < FADE_FROM else 1.0 - (t - FADE_FROM) / (1.0 - FADE_FROM)
		var size := font_size(number["value"], number["crit"])
		var text := str(maxi(1, roundi(number["value"])))
		var font := UiFonts.mono()
		var spot: Vector2 = p + Vector2(-_text_width(number, size) * 0.5, -RISE * t)
		# An ink outline under the figure (FX-02), so a copper number reads on pale sand as on charcoal.
		var ink := Palette.CHARCOAL
		ink.a = colour.a
		draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_px(size), ink)
		draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
