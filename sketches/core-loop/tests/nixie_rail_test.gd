extends SceneTree

const Game := preload("res://src/game.gd")
const NixieRail := preload("res://src/ui/nixie_rail.gd")
const ScreenRegions := preload("res://src/core/screen_regions.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

# E1-04, the tube rail (ruling ek; OPUS-3D-UI-BLUEPRINT section 4; Fable's calls D, E, H and L):
#   - with no row, or only rows under 3 s with no count, the rail is hidden and has no rectangle;
#   - 1, 2 and 4 tubes sit in the bottom band's right end (right edge at the margin, x no further in
#     than four sockets, 84 px tall on its floor) on the 1600x900 canvas that 1280x720, 1920x1080 and
#     2560x1440 windows draw, and on raw layouts of those sizes, with no overlap against any other
#     bottom piece, the cog wallet and the chain counter included; a fifth row never widens it;
#   - the lit numeral is 2.5% of the window height or more at each size, and the cathode stack shows
#     only where the glass is 45 px or taller on screen;
#   - a numeral lights for a count and only in a timer's last 9 s, and steps 100/80/60% over the last 3 s;
#   - the buff ledger's own rows (buff_ledger.gd _to_row) read right: a lone timer has no numeral until
#     its last 9 s, a count shows its stacks, a timed count shows both numeral and drain, icons and ids
#     map onto filaments, and a row's tone (mint here) is never drawn;
#   - every filament has its own topology, and no ink the rail draws is mint, hazard red, brass or purple;
#   - new tubes join at the inner end, a gone row retracts and the rail hides after the last;
#   - reduced motion keeps the needle steady and skips the slide and the rise;
#   - at rest a count-only rail stops redrawing; the test leaves reduced motion as it found it.

const WINDOWS := [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0), Vector2(2560.0, 1440.0)]
const CANVAS := Vector2(1600.0, 900.0)
const FORBIDDEN := {"mint": Palette.ARC, "hazard": Palette.HAZARD, "brass": Palette.BRASS, "kindness": Palette.KINDNESS}
const FORBIDDEN_NAMES := ["Palette.ARC", "Palette.HAZARD", "Palette.BRASS", "Palette.KINDNESS", "Palette.DAWN_VIOLET", "8bf0d3", "ff5a3c", "d9b44a", "d936b0"]

var _t := T.new("nixie_rail_test")
var _game
var _hud
var _phase := "boot"
var _wait := 0
var _was_reduced := false


func _initialize() -> void:
	_was_reduced = Comfort.reduced_motion
	Comfort.reduced_motion = false
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


static func _rows(n: int, timed := true) -> Array:
	var shapes := ["frost", "heat", "overdrive", "chain", "plain"]
	var out := []
	for i in n:
		if timed:
			out.append({"id": "fx%d" % i, "filament": shapes[i % shapes.size()], "seconds_left": 6.0 + i, "seconds_total": 12.0})
		else:
			out.append({"id": "n%d" % i, "filament": shapes[i % shapes.size()], "count": i + 2, "seconds_total": 0.0})
	return out


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_hud = _game.get_node("Hud")
			_phase = "units"
			_wait = 0
		"units":
			if _wait == 4:
				_hidden_when_empty()
				_digits()
				_shapes_and_inks()
				_ledger_rows()
				_order_and_retract()
				_reduced_motion()
				_hud_geometry()
				_redraw_at_rest()
				_phase = "rest"
				_wait = 0
		"rest":
			if _wait == 2:
				_draws_settled = _draws
			if _wait == 8:
				_rest_counted()
				Comfort.reduced_motion = _was_reduced
				_hud.nixie_rail.clear()
				quit(_t.verdict())
				return true
	return false


func _hidden_when_empty() -> void:
	var rail := NixieRail.new()
	root.add_child(rail)
	rail.place(Vector2(1582.0, 888.0))
	rail.set_rows([])
	_t.check("no rows: hidden, no rectangle", not rail.showing() and not rail.piece_rect().has_area() and rail.shown_filaments().size() == 0,
		"showing %s, rect %s" % [rail.showing(), rail.piece_rect()])
	rail.set_rows([{"id": "cloak", "filament": "plain", "seconds_left": 1.5, "seconds_total": 1.5},
		{"id": "jam", "filament": "chain", "seconds_left": 2.0, "seconds_total": 2.0}])
	_t.check("rows under 3 s with no count get no tube", not rail.showing() and rail.shown_filaments().size() == 0, "%d tubes" % rail.shown_filaments().size())
	_t.eq("the HUD reads no rows while the game has no buff ledger", _hud.buff_rows(), [])
	rail.free()


func _digits() -> void:
	for window in WINDOWS:
		var px := NixieRail.digit_px(window.y)
		_t.check("lit numeral at %dx%d" % [window.x, window.y], px >= 0.025 * window.y,
			"%.1f px of %d (%.2f%%, floor 2.5%%)" % [px, window.y, 100.0 * px / window.y])
	_t.check("cathode stack off at 720p, on at 1080p and up",
		not NixieRail.cathodes_shown(720.0 / 900.0) and NixieRail.cathodes_shown(1080.0 / 900.0) and NixieRail.cathodes_shown(1440.0 / 900.0),
		"glass %.0f, %.0f, %.0f px" % [NixieRail.GLASS.size.y * 0.8, NixieRail.GLASS.size.y * 1.2, NixieRail.GLASS.size.y * 1.6])
	var got := [NixieRail.digit_of(12.0, 20.0, -1), NixieRail.digit_of(9.0, 20.0, -1), NixieRail.digit_of(8.2, 20.0, -1),
		NixieRail.digit_of(0.4, 20.0, -1), NixieRail.digit_of(0.0, 20.0, -1), NixieRail.digit_of(0.0, 0.0, 3), NixieRail.digit_of(0.0, 0.0, 14),
		NixieRail.digit_of(30.0, 40.0, 5)]
	_t.eq("numerals: dark above 9 s, ceil in the last 9 s, counts always (9 at most)", got, [-1, 9, 9, 1, -1, 3, 9, 5])
	_t.eq("last 3 s step 100/80/60%, no blink", [NixieRail.brightness_of(5.0, -1), NixieRail.brightness_of(2.5, -1),
		NixieRail.brightness_of(1.5, -1), NixieRail.brightness_of(0.5, -1), NixieRail.brightness_of(0.5, 4)], [1.0, 1.0, 0.8, 0.6, 1.0])
	_t.eq("the needle sweeps linearly, right when full to left when spent", [NixieRail.needle_deg(1.0), NixieRail.needle_deg(0.5),
		NixieRail.needle_deg(0.0)], [0.0, 90.0, 180.0])
	_t.eq("a count has no drain", NixieRail.fill_of(0.0, 0.0), -1.0)


func _shapes_and_inks() -> void:
	var seen := {}
	var dupes := []
	for shape in NixieRail.FILAMENTS:
		var sig := str(NixieRail.topology(shape))
		if seen.has(sig):
			dupes.append([seen[sig], shape])
		seen[sig] = shape
	_t.check("every filament has its own topology", dupes.is_empty() and seen.size() == NixieRail.FILAMENTS.size(), "%s; shared %s" % [seen, dupes])
	_t.check("frost is ICE, heat warm, overdrive copper, chain steel with bone",
		NixieRail.FILAMENTS["frost"]["ink"] == Palette.ICE and NixieRail.FILAMENTS["heat"]["ink"] == Palette.AMBER
			and NixieRail.FILAMENTS["overdrive"]["ink"] == Palette.COPPER and NixieRail.FILAMENTS["chain"]["ink"] == Palette.STEEL
			and NixieRail.FILAMENTS["chain"]["core"] == NixieRail.BONE and NixieRail.filament_of({"filament": "arc"}) == "chain", "")
	# Brass is held to the separation the palette already keeps between AMBER (the relic, the lit
	# numeral) and BRASS (Brindle); every other forbidden colour to 0.2 in RGB.
	var bad := []
	for ink in NixieRail.inks():
		for name in FORBIDDEN:
			var other: Color = FORBIDDEN[name]
			var d := _rgb(ink, other)
			if d < (_rgb(Palette.AMBER, Palette.BRASS) - 0.001 if name == "brass" else 0.2):
				bad.append("%s near %s (%.2f)" % [ink.to_html(false), name, d])
		if ink.s > 0.25 and ink.h * 360.0 >= 250.0 and ink.h * 360.0 <= 335.0:
			bad.append("%s purple (hue %.0f)" % [ink.to_html(false), ink.h * 360.0])
	_t.eq("no rail ink is mint, hazard red, brass or purple", bad, [])
	var source := FileAccess.get_file_as_string("res://src/ui/nixie_rail.gd")
	var named := FORBIDDEN_NAMES.filter(func(word): return source.contains(word))
	_t.eq("the rail source names no forbidden colour", named, [])
	var code := "\n".join(Array(source.split("\n")).filter(func(line: String): return not line.strip_edges().begins_with("#")))
	var heavy := ["SubViewport", "Texture", "draw_string", "Font", "Label"].filter(func(word): return code.contains(word))
	_t.check("one Control drawn in _draw: no SubViewport, texture, font or label", source.begins_with("extends Control") and heavy.is_empty(), "%s" % [heavy])


static func _rgb(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# Rows exactly as BuffLedger._to_row() writes them, each with a mint tone the rail must not draw.
static func _ledger_row(id: String, icon: String, kind: String, left: float, duration: float, stacks: int, show_digit: bool) -> Dictionary:
	return {"id": id, "icon": icon, "tone": Palette.ARC, "kind": kind, "left_s": left, "duration_s": duration,
		"frac": clampf(left / duration, 0.0, 1.0) if duration > 0.0 else 1.0, "stacks": stacks, "max_stacks": maxi(stacks, 3),
		"show_digit": show_digit}


func _ledger_rows() -> void:
	var drone := _ledger_row("item_drone", "cat_utility", "timer", 12.0, 15.0, 1, false)
	var brace := _ledger_row("item_brace", "cat_defense", "timer", 4.0, 6.0, 1, false)
	var armed := _ledger_row("item_armed_hit", "cat_damage", "count", 0.0, 0.0, 3, true)
	var rebound := _ledger_row("item_rebound_crit", "cat_damage", "count", 3.0, 4.0, 2, true)
	var sprint := _ledger_row("ability_overdrive_sprint", "ab_rivet_move", "timer", 5.0, 5.0, 1, false)
	var stacked := _ledger_row("item_frost_pin", "cat_frost", "timer", 20.0, 30.0, 2, true)
	var seen := [drone, brace, armed, rebound, sprint, stacked].map(func(r): return NixieRail.read_row(r))
	_t.eq("ledger rows read: numeral only where show_digit says, time from left_s and duration_s",
		seen.map(func(r): return [r["count"], r["left"], r["total"]]),
		[[-1, 12.0, 15.0], [-1, 4.0, 6.0], [3, 0.0, 0.0], [2, 3.0, 4.0], [-1, 5.0, 5.0], [2, 20.0, 30.0]])
	_t.eq("a lone 12 s timer is dark, at 4 s it counts down; a count shows its stacks", [
		NixieRail.digit_of(seen[0]["left"], seen[0]["total"], seen[0]["count"]), NixieRail.digit_of(seen[1]["left"], seen[1]["total"], seen[1]["count"]),
		NixieRail.digit_of(seen[2]["left"], seen[2]["total"], seen[2]["count"])], [-1, 4, 3])
	_t.check("a timed count keeps both its numeral and its drain",
		NixieRail.digit_of(seen[3]["left"], seen[3]["total"], seen[3]["count"]) == 2 and is_equal_approx(NixieRail.fill_of(seen[3]["left"], seen[3]["total"]), 0.75),
		"digit %d, fill %.2f" % [NixieRail.digit_of(seen[3]["left"], seen[3]["total"], seen[3]["count"]), NixieRail.fill_of(seen[3]["left"], seen[3]["total"])])
	_t.eq("icons and ids map onto filaments", seen.map(func(r): return r["filament"]),
		["utility", "guard", "overdrive", "overdrive", "overdrive", "frost"])
	_t.eq("a row under 3 s with no numeral gets no tube; a count with no timer does",
		[NixieRail.wants_tube(_ledger_row("ability_cloak", "ab_kest_move", "timer", 1.5, 1.5, 1, false)), NixieRail.wants_tube(armed)], [false, true])
	var rail := NixieRail.new()
	root.add_child(rail)
	rail.place(Vector2(1582.0, 888.0))
	rail.set_rows([drone, brace, armed, rebound])
	var drawn: Array = rail.shown_filaments().map(func(shape): return NixieRail.FILAMENTS[shape]["ink"])
	_t.check("the rail draws its own filament inks, never a row's mint tone", rail.shown_filaments().size() == 4 and not drawn.has(Palette.ARC),
		"%s" % [rail.shown_filaments()])
	var source := FileAccess.get_file_as_string("res://src/ui/nixie_rail.gd")
	_t.check("the rail source never reads a row's tone", not source.contains("\"tone\""), "")
	rail.free()


func _order_and_retract() -> void:
	var rail := NixieRail.new()
	root.add_child(rail)
	rail.place(Vector2(1582.0, 888.0))
	rail.set_rows(_rows(2))
	rail.set_rows(_rows(3))
	_t.eq("a new tube joins at the inner end", rail.shown_filaments(), ["overdrive", "heat", "frost"])
	rail.set_rows(_rows(6))
	_t.check("a fifth and sixth row never widen the rail", rail.shown_filaments().size() == 4 and rail.piece_rect().size.x <= NixieRail.PITCH * 4,
		"%d tubes, %.0f px" % [rail.shown_filaments().size(), rail.piece_rect().size.x])
	var rows := _rows(4)
	rows.remove_at(1)
	rail.set_rows(rows)
	rail.set_rows(rows + [{"id": "late", "filament": "plain", "count": 2}])
	_t.check("a new row takes a retracting tube's socket, four at most", rail.shown_filaments().size() == 4 and rail.piece_rect().size.x <= NixieRail.PITCH * 4,
		"%d tubes, %s" % [rail.shown_filaments().size(), rail.shown_filaments()])
	rail.set_rows([])
	for i in 60:
		rail.advance(1.0 / 60.0)
	_t.check("after the last row ends the rail retracts and hides", not rail.showing() and rail.shown_filaments().size() == 0 and not rail.piece_rect().has_area(),
		"showing %s, %d tubes" % [rail.showing(), rail.shown_filaments().size()])
	rail.free()


func _reduced_motion() -> void:
	var rail := NixieRail.new()
	root.add_child(rail)
	rail.place(Vector2(1582.0, 888.0))
	Comfort.reduced_motion = false
	rail.set_rows(_rows(1))
	rail.advance(1.0 / 120.0)
	_t.check("with motion the rail slides in and the housing rises", rail._slide_x() > 0.0 and rail._rise(rail._tubes[0]) > 0.0,
		"slide %.0f px, rise %.1f px" % [rail._slide_x(), rail._rise(rail._tubes[0])])
	var moving := []
	for i in 6:
		rail.advance(1.0 / 60.0)
		moving.append(rail.shown_needles()[0])
	var steady_want := NixieRail.needle_deg(6.0 / 12.0)
	_t.check("with motion the needle quivers within 1.5 degrees", moving.any(func(d): return not is_equal_approx(d, steady_want))
		and moving.all(func(d): return absf(d - steady_want) <= NixieRail.QUIVER_DEG + 0.01), "%s around %.1f" % [moving, steady_want])
	rail.clear()
	Comfort.reduced_motion = true
	rail.set_rows(_rows(2))
	var still := []
	for i in 6:
		rail.advance(1.0 / 60.0)
		still.append(rail.shown_needles()[0])
	_t.check("reduced motion: the needle holds still", still.all(func(d): return is_equal_approx(d, NixieRail.needle_deg(7.0 / 12.0))), "%s" % [still])
	var tubes: Array = rail._tubes
	_t.check("reduced motion: no slide, no rise", rail._slide_x() == 0.0 and tubes.all(func(t): return rail._rise(t) == 0.0), "")
	rail.set_rows([])
	rail.advance(NixieRail.FADE_DIGIT + NixieRail.COOL + 0.01)
	rail.advance(0.0)
	_t.check("reduced motion: the numeral fades, then the rail closes up at once", not rail.showing(), "showing %s" % rail.showing())
	Comfort.reduced_motion = false
	rail.free()


# Every bottom piece against every other, at the canvas the window draws and at the raw window size.
func _hud_geometry() -> void:
	var rail = _hud.nixie_rail
	Comfort.reduced_motion = true
	for window in WINDOWS:
		for size: Vector2 in [CANVAS, window]:
			for n in [1, 2, 4]:
				_hud.layout(size)
				rail.set_rows(_rows(n))
				var pieces: Array = _hud.piece_rects()["bottom"]
				var band: Rect2 = ScreenRegions.rect("bottom", size)
				var r: Rect2 = rail.piece_rect()
				var tag := "%d tube%s, %dx%d window, layout %dx%d" % [n, "" if n == 1 else "s", window.x, window.y, size.x, size.y]
				var at_edge: bool = is_equal_approx(r.end.x, size.x - 18.0) and is_equal_approx(r.end.y, size.y - NixieRail.FLOOR)
				var in_reach: bool = r.position.x >= size.x - 18.0 - NixieRail.PITCH * 4 - 0.5 and is_equal_approx(r.size.x, NixieRail.PITCH * n)
				_t.check("rail placed, " + tag, pieces.has(r) and band.grow(0.5).encloses(r) and at_edge and in_reach and is_equal_approx(r.size.y, 84.0),
					"rail %s in band %s" % [r, band])
				# The canvas is the only layout a window draws (stretch keep): there every pair must part. A raw
				# window-sized layout is checked for the rail against its neighbours only.
				var clash := []
				for i in pieces.size():
					for j in range(i + 1, pieces.size()):
						var both: bool = size == CANVAS or pieces[i] == r or pieces[j] == r
						if both and (pieces[i] as Rect2).intersects(pieces[j]):
							clash.append([pieces[i], pieces[j]])
				_t.check("no bottom overlap, " + tag, clash.is_empty() and pieces.size() >= 6, "%d pieces; overlaps %s" % [pieces.size(), clash])
				var housings: Array = rail.housing_rects()
				_t.check("housings 48x76 inside the rail, " + tag, housings.size() == n and housings.all(func(h): return r.encloses(h) and h.size == NixieRail.HOUSING), "")
				rail.clear()
	_t.check("the cog wallet and chain counter are listed for the layout test",
		_hud.piece_rects()["bottom"].has(_rect_like(_hud._cogs)) and _hud.piece_rects()["bottom"].has(_rect_like(_hud.chain_counter)), "")
	Comfort.reduced_motion = false
	_hud.layout(_hud._screen_size())


static func _rect_like(control: Control) -> Rect2:
	var s := control.get_combined_minimum_size()
	return Rect2(control.position, Vector2(maxf(s.x, control.size.x), maxf(s.y, control.size.y)))


var _rest_rail
var _draws := 0
var _draws_settled := -1


# A count-only rail, settled by hand; the frames of the "rest" phase then show whether it still draws.
func _redraw_at_rest() -> void:
	_rest_rail = NixieRail.new()
	root.add_child(_rest_rail)
	_rest_rail.place(Vector2(1582.0, 888.0))
	_rest_rail.draw.connect(func(): _draws += 1)
	_rest_rail.set_rows(_rows(3, false))
	for i in 60:
		_rest_rail.advance(1.0 / 60.0)


func _rest_counted() -> void:
	var before: Array = _rest_rail._drawn.duplicate(true)
	for i in 30:
		_rest_rail.set_rows(_rows(3, false))
		_rest_rail.advance(1.0 / 60.0)
	_t.check("the same count rows, frame after frame, change nothing drawn", _rest_rail._drawn == before and _rest_rail.shown_digits() == [4, 3, 2],
		"digits %s" % [_rest_rail.shown_digits()])
	_t.check("a settled count-only rail stops redrawing", _draws_settled > 0 and _draws == _draws_settled,
		"%d draws when settled, %d after 6 more frames" % [_draws_settled, _draws])
	_rest_rail.free()
