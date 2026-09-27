extends CanvasLayer

const EventKinds := preload("res://src/core/event_kinds.gd")

# The one copy of the field notes: the Tab overlay prints these, the HUD hint line is
# built from CONTROLS, and README.md mirrors them by hand. The legend is generated
# from event_kinds.gd, so it always shows the colours and wording the game uses.
const TITLE := "Scrapkeep: First Run · field notes"
# What the run asks of you, in one line: the title screen shows it too.
const OBJECTIVE := "Break each stage's Warden at its beacon; grow your punch through its plating. Three stages, then rout Admiral Brindle."

const TESTING := [
	"One run: title, class, three stages, each sealed by a Warden at its beacon. Grow until your punch beats its plating, break it, roll through a reward gate and launch into the next stage. Stage 3's launch drops you into the arena against Admiral Brindle; beat him for the summary.",
	"Growth is heft: scrap you roll up becomes mass, parts add more, and heft multiplies your punch. The objective line shows your punch against the Warden's plating.",
	"Outweigh fodder and you roll straight through it with no speed lost. Events and vaults drop bonus cores (the pips beside the objective) that raise the gate tiers.",
	"The pylon banks the speed you plant with. Space slingshots you off along the face with it plus a boost; E drops off where you are. The camera goes to the shoulder while mounted.",
	"Death is one key: R retries the stage from its start with the scrap, health and parts you entered with; N starts a new run as the same class. Hold R in play to retry the stage. In the arena, R retries the fight from its entry and T replays stage 3.",
]

const QUESTIONS := [
	"Was the Warden a goal or a chore? Did growth feel like enough growth?",
	"Does the loop read without instructions: where to go, what the beacon wants, what a gate gives?",
	"Does the launch into the next stage feel like momentum carried, or like a load screen?",
	"Is the shoulder view while mounted enough to see what you are shooting?",
	"Is retry fast enough that dying costs you nothing but the stage?",
]

const TRY_FIRST := [
	"Pick either class with 1 or 2. You drop in already rolling; the Warden is at the beacon you can see from the drop.",
	"Roll the scrap lines on the way down: watch Heft climb beside your speed, and your punch climb in the objective line.",
	"Break the Warden (the stage hint says how); the gates open wherever you are. Roll through one to take its part.",
	"Hit a steep face at speed, press E, fire with left mouse, then Space to slingshot off.",
	"Get scrapped on purpose, then press R: you are back at the stage start in under a second.",
	"Against Brindle, read the ship's plating line: hit what glows amber, slam the vent caps in phase 2, and ram or stomp the scooter when he runs.",
]

const CONTROLS := [
	{"keys": "W A S D", "does": "drive, relative to where the camera looks", "hint": "WASD move"},
	{"keys": "mouse", "does": "look", "hint": "mouse look"},
	{"keys": "Space", "does": "jump, double jump, hold falling to glide; slingshots off a pylon", "hint": "Space jump/glide"},
	{"keys": "Shift", "does": "boost; airborne it is the air dash", "hint": "Shift boost/dash"},
	{"keys": "Ctrl", "does": "brake; airborne it is the slam", "hint": "Ctrl brake/slam"},
	{"keys": "left mouse", "does": "fire the class weapon (hold); both classes", "hint": "LMB fire"},
	{"keys": "F", "does": "runner overdrive blast; engineer pylon discharge (planting fires it free)", "hint": "F special"},
	{"keys": "right mouse", "does": "fire the grapple at the reticle's target; release to let go", "hint": "RMB grapple"},
	{"keys": "Q (hold)", "does": "winch: haul toward the hook", "hint": "Q winch"},
	{"keys": "E", "does": "plant a pylon on a steep face or a close wall hook; again to drop off", "hint": "E pylon"},
	{"keys": "mouse wheel", "does": "down pays rope out, up notches it in", "hint": "wheel rope"},
	{"keys": "Tab (hold)", "does": "field notes and the codex; the game pauses while held; Q / E switch pages", "hint": "Tab notes/codex"},
	{"keys": "- / =", "does": "music volume down / up", "hint": "-/= music"},
	{"keys": "[ / ]", "does": "effects volume down / up", "hint": "[/] effects"},
	{"keys": "M", "does": "mute or unmute", "hint": "M mute"},
	{"keys": "F6", "does": "boss tempo: 129, or 172 while held", "hint": "F6 boss tempo"},
	{"keys": "P", "does": "pause / resume", "hint": "P pause"},
	{"keys": "R (hold)", "does": "retry the stage from its start (in the arena, the fight); release before holding again", "hint": "hold R retry"},
	{"keys": "F1", "does": "tuning panel (frees the mouse)", "hint": "F1 tuning"},
	{"keys": "F3", "does": "physics interpolation on/off (off by default)", "hint": "F3 interp"},
	{"keys": "F4", "does": "save every tuning value to user://tuning-<time>.json", "hint": "F4 save tuning"},
	{"keys": "Esc", "does": "free the mouse; again to quit", "hint": "Esc mouse/quit"},
]

const SCREEN_KEYS := [
	{"keys": "Space", "does": "title: start; summary: choose a class (after a short beat)"},
	{"keys": "1 / 2", "does": "class select: Pylon engineer / Runner-gunner"},
	{"keys": "R", "does": "death screen: retry the stage, or the fight in the arena"},
	{"keys": "T", "does": "arena death screen: replay stage 3 from its start"},
	{"keys": "N", "does": "death or summary: new run, same class"},
	{"keys": "C", "does": "death screen: choose a class"},
]

const HINT_BREAK := 10
# A glyph per event_kinds shape, so a codex card wears its category's silhouette.
const SHAPE_GLYPHS := {
	"diamond": "◆", "wave": "≈", "burst": "*", "square": "■", "chevron": "›", "star": "★",
	"ring": "○", "arrow": "»", "bar": "=", "cross": "×", "core": "◆", "none": "",
}
const CARD_COLUMNS := 3

var game

var _notes: Control
var _paused: Label
var _title: Label
var _notes_page: Control
var _codex_page: VBoxContainer
var _page := 0


static func hint_rows() -> String:
	var first := PackedStringArray()
	var second := PackedStringArray()
	for i in CONTROLS.size():
		if i < HINT_BREAK:
			first.append(CONTROLS[i]["hint"])
		else:
			second.append(CONTROLS[i]["hint"])
	return "  ·  ".join(first) + "\n" + "  ·  ".join(second)


static func notes_text() -> String:
	var lines := PackedStringArray()
	lines.append("Testing in this build")
	for line in TESTING:
		lines.append("  - " + line)
	lines.append("")
	lines.append("Questions for you")
	for line in QUESTIONS:
		lines.append("  - " + line)
	lines.append("")
	lines.append("What to try first")
	for i in TRY_FIRST.size():
		lines.append("  %d. %s" % [i + 1, TRY_FIRST[i]])
	return "\n".join(lines)


static func controls_text() -> String:
	var lines := PackedStringArray(["Controls"])
	for row in CONTROLS:
		lines.append("%-12s %s" % [row["keys"], row["does"]])
	lines.append("")
	lines.append("Screens")
	for row in SCREEN_KEYS:
		lines.append("%-12s %s" % [row["keys"], row["does"]])
	return "\n".join(lines)


# Every notable fact in its own colour and wording, straight from event_kinds.gd.
static func legend_bbcode() -> String:
	var lines := PackedStringArray(["What the colours mean"])
	for kind in EventKinds.ROWS:
		var row: Dictionary = EventKinds.ROWS[kind]
		if row["priority"] < EventKinds.TOAST_PRIORITY:
			continue
		var words: String = row["hud"] if row["hud"] != "" else kind.replace("_", " ")
		lines.append("[color=#%s]%s  %s[/color]" % [(row["color"] as Color).to_html(false), SHAPE_GLYPHS.get(row["shape"], ""), words])
	return "\n".join(lines)


# Pause has to keep listening while the tree is paused, so this layer always processes
# and the game it steers does not.
func setup(game_ref) -> void:
	game = game_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	_notes = PanelContainer.new()
	_notes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notes.offset_left = 40.0
	_notes.offset_top = 24.0
	_notes.offset_right = -40.0
	_notes.offset_bottom = -24.0
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	backing.set_content_margin_all(22.0)
	backing.set_corner_radius_all(6)
	_notes.add_theme_stylebox_override("panel", backing)
	add_child(_notes)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_notes.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_title)

	_codex_page = VBoxContainer.new()
	_codex_page.add_theme_constant_override("separation", 12)
	_codex_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_page.visible = false
	box.add_child(_codex_page)

	var columns := HBoxContainer.new()
	_notes_page = columns
	columns.add_theme_constant_override("separation", 30)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	var notes := Label.new()
	notes.text = notes_text()
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.size_flags_stretch_ratio = 1.5
	notes.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	notes.add_theme_font_size_override("font_size", 15)
	columns.add_child(notes)
	var controls := Label.new()
	controls.text = controls_text()
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	controls.add_theme_font_size_override("font_size", 15)
	columns.add_child(controls)
	var legend := RichTextLabel.new()
	legend.bbcode_enabled = true
	legend.text = legend_bbcode()
	legend.fit_content = true
	legend.custom_minimum_size = Vector2(300.0, 0.0)
	legend.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	legend.add_theme_font_size_override("normal_font_size", 15)
	columns.add_child(legend)
	_notes.visible = false
	show_page(0)

	_paused = Label.new()
	_paused.text = "PAUSED  ·  P to resume  ·  hold Tab for field notes"
	_paused.add_theme_font_size_override("font_size", 40)
	_paused.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_paused.add_theme_constant_override("outline_size", 10)
	_paused.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_paused.position = Vector2(-470.0, 120.0)
	_paused.visible = false
	add_child(_paused)


# Notes first, then one page per codex category (reserved ones only once they hold
# entries), then the Found list.
func pages() -> Array[String]:
	var list: Array[String] = ["notes"]
	for id in EventKinds.CODEX_CATEGORIES:
		var reserved: bool = EventKinds.CODEX_CATEGORIES[id]["reserved"]
		if not reserved or (_codex() != null and not _codex().entries(id).is_empty()):
			list.append(id)
	list.append("found")
	return list


func _codex():
	return game.codex if game != null else null


func show_page(index: int) -> void:
	var list := pages()
	_page = posmod(index, list.size())
	var page: String = list[_page]
	_notes_page.visible = page == "notes"
	_codex_page.visible = page != "notes"
	_title.text = _tab_row(list, page)
	if page != "notes":
		render_page(page)


func _tab_row(list: Array[String], current: String) -> String:
	var tabs := PackedStringArray()
	for page in list:
		var label := "Notes"
		if page == "found":
			label = "Found %d" % (_codex().found().size() if _codex() != null else 0)
		elif page != "notes":
			label = "%s %d%%" % [EventKinds.category(page)["label"], int(_codex().completion(page) * 100.0) if _codex() != null else 0]
		tabs.append("[ %s ]" % label if page == current else label)
	return "%s  ·  %s  ·  Q / E switch  ·  paused while Tab is held" % [TITLE, "   ".join(tabs)]


# Builds one codex page and returns how many cards or lines it shows.
func render_page(page: String) -> int:
	for child in _codex_page.get_children():
		child.queue_free()
	var codex = _codex()
	if codex == null:
		return 0
	if page == "found":
		return _render_found(codex)
	var style: Dictionary = EventKinds.category(page)
	var listed: Array = codex.entries(page)
	var head := Label.new()
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", style["color"])
	head.text = "%s %s  ·  %d of %d found" % [SHAPE_GLYPHS.get(style["shape"], ""), style["label"],
		listed.filter(func(e): return e["known"]).size(), listed.size()]
	_codex_page.add_child(head)
	if listed.is_empty():
		var none := Label.new()
		none.text = "Nothing recorded here yet."
		_codex_page.add_child(none)
		return 0
	var grid := GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_codex_page.add_child(grid)
	for entry in listed:
		grid.add_child(_card(entry, style))
	return listed.size()


func _card(entry: Dictionary, style: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420.0, 96.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.11, 0.14, 0.96)
	box.border_color = style["color"] if entry["known"] else Color(style["color"], 0.35)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(12.0)
	card.add_theme_stylebox_override("panel", box)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 15)
	var glyph: String = SHAPE_GLYPHS.get(style["shape"], "")
	if entry["known"]:
		text.text = "%s %s\n%s" % [glyph, entry["name"], entry["text"]]
		text.add_theme_color_override("font_color", style["color"])
	else:
		text.text = hint_card_text(glyph, entry["hint"], entry["clue"])
		text.add_theme_color_override("font_color", Color(0.75, 0.76, 0.78))
	card.add_child(text)
	return card


# An undiscovered card: the hint sentence, then the clue on its own line. A hint that
# already names its clue (build's "Chain Arc + something that splits") shows it once.
static func hint_card_text(glyph: String, hint: String, clue: String) -> String:
	var lines := PackedStringArray(["%s ???" % glyph])
	if hint != "":
		lines.append(hint)
	if clue != "" and not hint.contains(clue):
		lines.append("clue: " + clue)
	return "\n".join(lines)


func _render_found(codex) -> int:
	var list := RichTextLabel.new()
	list.bbcode_enabled = true
	list.fit_content = true
	list.add_theme_font_size_override("normal_font_size", 16)
	var lines := PackedStringArray(["Found by accident, no name yet"])
	for text in codex.found():
		var style: Dictionary = EventKinds.category(codex.found_category(text))
		lines.append("[color=#%s]%s %s[/color]" % [(style["color"] as Color).to_html(false), SHAPE_GLYPHS.get(style["shape"], ""), text])
	if codex.found().is_empty():
		lines.append("Nothing yet. Mix elements, patterns and terrain and see what happens.")
	list.text = "\n".join(lines)
	_codex_page.add_child(list)
	return codex.found().size()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	if event.pressed and game != null and game.notes_held() and (event.physical_keycode == KEY_Q or event.physical_keycode == KEY_E):
		show_page(_page + (1 if event.physical_keycode == KEY_E else -1))
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_TAB:
			game.hold_notes(event.pressed)
			if event.pressed:
				show_page(_page)
			get_viewport().set_input_as_handled()
		KEY_P:
			if event.pressed:
				game.toggle_pause()
				get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if game == null:
		return
	_notes.visible = game.notes_held()
	_paused.visible = game.pause_toggled() and not game.notes_held()
