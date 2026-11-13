extends SceneTree

const UiTokens := preload("res://src/ui/ui_tokens.gd")
const T := preload("res://tests/support/t.gd")

# The UI's tokens (src/ui/ui_tokens.gd): one spacing scale, five type sizes and five colours.
#   - the project theme file matches the tokens it is written from (tools/ui_theme_build.gd);
#   - every literal font size and container gap a UI script writes in src/ui is a step of the scale
#     (a size computed at run time is not read here);
#   - no UI script draws a gradient;
#   - every literal corner radius in src/ui is RADIUS, and no plate is charcoal at a hand-set alpha (W1-27);
#   - the HUD in play (HUD_FILES) sets every gap const on the spacing scale, and its marks draw the
#     five colours by their token names, never the palette's sand, charcoal or amber or a literal colour;
#   - the plate edge holds 3:1 on the plate and every word colour holds 4.5:1 (WCAG 2.2 AA, pass 4);
#   - planted bad cases (a literal 13 px, a gap of 10, a Gradient, radius 8, a 0.94 plate, a 14 px gap
#     const, a palette sand mark) are caught by the same scans.

const FONT_LITERAL := "font_size\", (\\d+)\\)|\\blabel\\((\\d+)[,)]|HORIZONTAL_ALIGNMENT_\\w+, [^,]+, (\\d+), |\\b_label\\((?:[^,()\\n]|\\([^()]*\\))+, (\\d+)[,)]"
const GAP_LITERAL := "constant_override\\(\"(?:separation|h_separation|v_separation)\", (\\d+)\\)"
const RADIUS_LITERAL := "set_corner_radius_all\\((\\d+)\\)"
# A plate filled by hand: a StyleBox or frame whose fill is charcoal at its own alpha.
const PLATE_LITERAL := "bg_color :?= Color\\(Palette\\.CHARCOAL, \\d*\\.\\d+\\)"
const GAP_CONST := "const \\w*GAP\\w* := (\\d+(?:\\.\\d+)?)\\b"
# Hazard stays: on the danger mark it is the world's warning colour, a meaning.
const MARK_COLOR := "Palette\\.(?:SAND|CHARCOAL|AMBER)\\b|Color\\(\\d"
# The HUD a player reads in play (W1-27): the skill bar, aim reticle, speed glyph, danger mark,
# restart meter, the HUD's own layout and the pause menu's build read.
const HUD_FILES := ["ability_bar.gd", "aim_reticle.gd", "speed_glyph.gd", "danger_mark.gd", "restart_meter.gd", "hud.gd", "build_read.gd"]
# Of those, the ones drawn as marks; their colours are the tokens by name.
const MARK_FILES := ["ability_bar.gd", "aim_reticle.gd", "speed_glyph.gd", "danger_mark.gd", "restart_meter.gd"]

var _t := T.new("ui_tokens_test")


func _initialize() -> void:
	_theme_matches()
	_scans()
	_contrast()
	quit(_t.verdict())


func _theme_matches() -> void:
	_t.eq("the project theme is the tokens' file", ProjectSettings.get_setting("gui/theme/custom", ""), UiTokens.THEME_PATH)
	var saved: Theme = load(UiTokens.THEME_PATH)
	var made := UiTokens.theme()
	_t.check("the theme file loads", saved != null)
	if saved == null:
		return
	_t.eq("default size is the body step", saved.default_font_size, made.default_font_size)
	for kind in ["Label", "Button"]:
		for color in made.get_color_list(kind):
			_t.eq("%s %s matches the token" % [kind, color], saved.get_color(color, kind), made.get_color(color, kind))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var a: StyleBoxFlat = saved.get_stylebox(state, "Button")
		var b: StyleBoxFlat = made.get_stylebox(state, "Button")
		_t.check("Button %s plate matches the tokens" % state, a.border_color == b.border_color and a.bg_color == b.bg_color
			and a.border_width_top == b.border_width_top and a.draw_center == b.draw_center, "%s vs %s" % [a.border_color, b.border_color])


func _scans() -> void:
	var fonts := RegEx.create_from_string(FONT_LITERAL)
	var gaps := RegEx.create_from_string(GAP_LITERAL)
	_t.eq("planted: a literal 13 px size is found", _font_misses(fonts, 'x.add_theme_font_size_override("font_size", 13)'), ["13"])
	_t.eq("planted: a word label at 24 px is found", _font_misses(fonts, 'x.add_child(_label(read["name"], 24, c))'), ["24"])
	_t.eq("planted: a gap of 10 is found", _gap_misses(gaps, 'x.add_theme_constant_override("separation", 10)'), ["10"])
	_t.check("planted: a Gradient is found", _gradient("var g := Gradient.new()"))
	var radii := RegEx.create_from_string(RADIUS_LITERAL)
	var plates := RegEx.create_from_string(PLATE_LITERAL)
	var gap_consts := RegEx.create_from_string(GAP_CONST)
	var marks := RegEx.create_from_string(MARK_COLOR)
	_t.eq("planted: a radius of 8 is found", _radius_misses(radii, "box.set_corner_radius_all(8)"), ["8"])
	_t.check("planted: a 0.94 charcoal plate is found", plates.search("x.bg_color = Color(Palette.CHARCOAL, 0.94)") != null)
	_t.eq("planted: a 14 px gap const is found", _gap_misses(gap_consts, "const GAP := 14.0"), ["14.0"])
	_t.eq("planted: a token gap const passes", _gap_misses(gap_consts, "const GAP := float(UiTokens.GAP_M)"), [])
	_t.check("planted: a palette sand mark is found", marks.search("draw_circle(c, 3.0, Palette.SAND)") != null)
	_t.check("planted: a literal colour mark is found", marks.search("Color(0.8, 0.82, 0.85, 0.22)") != null)
	var radius_bad := []
	var plate_bad := []
	var hud_gap_bad := []
	var mark_bad := []
	var font_bad := []
	var gap_bad := []
	var gradient_bad := []
	for file in DirAccess.get_files_at("res://src/ui/"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://src/ui/" + file)
		for size in _font_misses(fonts, text):
			font_bad.append("%s %s" % [file, size])
		for gap in _gap_misses(gaps, text):
			gap_bad.append("%s %s" % [file, gap])
		if _gradient(text):
			gradient_bad.append(file)
		for radius in _radius_misses(radii, text):
			radius_bad.append("%s %s" % [file, radius])
		for found in plates.search_all(text):
			plate_bad.append("%s %s" % [file, found.get_string()])
		if file in HUD_FILES:
			for gap in _gap_misses(gap_consts, text):
				hud_gap_bad.append("%s %s" % [file, gap])
		if file in MARK_FILES:
			for found in marks.search_all(text):
				mark_bad.append("%s %s" % [file, found.get_string()])
	_t.eq("every literal font size in src/ui is a type step", font_bad, [])
	_t.eq("every literal gap in src/ui is a step of the spacing scale", gap_bad, [])
	_t.eq("no UI script draws a gradient", gradient_bad, [])
	_t.eq("every literal corner radius in src/ui is RADIUS", radius_bad, [])
	_t.eq("no StyleBox or frame fill in src/ui is charcoal at a hand-set alpha", plate_bad, [])
	_t.eq("every gap const in the HUD is a step of the spacing scale", hud_gap_bad, [])
	_t.eq("the HUD's marks name the token colours", mark_bad, [])


func _font_misses(regex: RegEx, text: String) -> Array:
	var out := []
	for found in regex.search_all(text):
		for i in range(1, 5):
			var size := found.get_string(i)
			if size != "" and not int(size) in UiTokens.TYPE:
				out.append(size)
	return out


func _gap_misses(regex: RegEx, text: String) -> Array:
	var out := []
	for found in regex.search_all(text):
		var value := float(found.get_string(1))
		if value != floorf(value) or not int(value) in UiTokens.SPACE:
			out.append(found.get_string(1))
	return out


func _radius_misses(regex: RegEx, text: String) -> Array:
	var out := []
	for found in regex.search_all(text):
		if int(found.get_string(1)) != UiTokens.RADIUS:
			out.append(found.get_string(1))
	return out


func _gradient(text: String) -> bool:
	return text.contains("Gradient.new()") or text.contains("GradientTexture")


func _contrast() -> void:
	_t.check("the plate's edge holds 3:1 on the plate", UiTokens.contrast(UiTokens.LINE, UiTokens.INK) >= 3.0, "%.2f" % UiTokens.contrast(UiTokens.LINE, UiTokens.INK))
	for pair in [["text", UiTokens.TEXT], ["accent", UiTokens.ACCENT], ["alert", UiTokens.ALERT]]:
		var ratio := UiTokens.contrast(pair[1], UiTokens.INK)
		_t.check("%s words hold 4.5:1 on the plate" % pair[0], ratio >= 4.5, "%.2f" % ratio)
	_t.check("the primary plate's words (ink on accent) hold 4.5:1", UiTokens.contrast(UiTokens.INK, UiTokens.ACCENT) >= 4.5, "%.2f" % UiTokens.contrast(UiTokens.INK, UiTokens.ACCENT))
	_t.check("planted: slate words on the plate fail 4.5:1", UiTokens.contrast(Color("6f7f8f"), UiTokens.INK) < 4.5)
