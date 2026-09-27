extends CanvasLayer

const EventKinds := preload("res://src/core/event_kinds.gd")

# The one copy of the field notes: the Tab overlay prints these and README.md mirrors
# them by hand. They are the full key list; in play the HUD shows a key only while its
# action is available. The legend is generated from event_kinds.gd, so it always shows
# the colours and wording the game uses.
const TITLE := "Scrapkeep: First Run · field notes"
# What the run asks of you, in one line: the title screen shows it too.
const OBJECTIVE := "Break each stage's Warden at its beacon; grow your punch through its plating. Three stages, then rout Admiral Brindle."

const TESTING := [
	"One run: title, class, three stages, each sealed by a Warden at its beacon. Grow until your punch beats its plating, break it, roll through a reward gate and launch into the next stage. Stage 3's launch drops you into the arena against Admiral Brindle; beat him for the summary.",
	"Growth is heft: scrap you roll up becomes mass, parts add more, and heft multiplies your punch. Under the objective, the top bar is your punch and the hatched bar the Warden's plating; get the punch past the white notch.",
	"Outweigh fodder and you roll straight through it with no speed lost. Events and vaults drop bonus cores (the diamonds beside the objective) that raise the gate tiers.",
	"Sable's pylon banks the speed you plant with. Space slingshots you off along the face with it plus a boost; E drops off where you are. The camera goes to the shoulder while mounted.",
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
	"Pick Sable, Rivet or Kest with a number key or a click. You drop in already rolling; the Warden is at the beacon you can see from the drop, and a chevron at the screen edge points to it when it is out of view.",
	"Roll the scrap lines on the way down: watch the heft dial's needle climb, and your punch bar grow under the objective.",
	"Break the Warden (close to it, the objective says how); the gates open wherever you are. Roll through one to take its part.",
	"As Sable, hit a steep face at speed, press E, fire with left mouse, then hold and release Space to slingshot off.",
	"Get scrapped on purpose, then press R: you are back at the stage start in under a second.",
	"Against Brindle, read the ship's plating line: hit what glows amber, slam the vent caps in phase 2, and ram or stomp the scooter when he runs.",
]

const CONTROLS := [
	{"keys": "W A S D", "does": "drive, relative to where the camera looks"},
	{"keys": "mouse", "does": "look"},
	{"keys": "Space", "does": "jump and double jump. Sable: vault kick at a steep face in the air; mounted, hold and release to slingshot. Kest: hold falling to glide; hold in your own blast to rocket jump"},
	{"keys": "Shift", "does": "boost"},
	{"keys": "Ctrl", "does": "brake; airborne, the smash: Sable's arc slam, Rivet's shockwave skid, Kest's demo slam"},
	{"keys": "left mouse", "does": "the class weapon. Sable and Rivet fire while held; Kest holds to aim a sticky charge, releases to throw"},
	{"keys": "F (hold)", "does": "the class special: hold to fill the gauge, release to fire. Planting a pylon fires Sable's for free"},
	{"keys": "right mouse", "does": "the class movement: Sable's grapple, Rivet's sprint (hold), Kest's smoke blink. During a charge it cancels"},
	{"keys": "Q (hold)", "does": "Sable: winch toward the hook"},
	{"keys": "E", "does": "Sable: plant a pylon on a steep face or a close wall hook; again to drop off"},
	{"keys": "mouse wheel", "does": "Sable: down pays rope out, up notches it in"},
	{"keys": "Tab (hold)", "does": "field notes and the codex; the game pauses while held; Q / E switch pages"},
	{"keys": "- / =", "does": "music volume down / up"},
	{"keys": "[ / ]", "does": "effects volume down / up"},
	{"keys": "M", "does": "mute or unmute"},
	{"keys": "F6", "does": "boss tempo: 129, or 172 while held"},
	{"keys": "P", "does": "pause / resume"},
	{"keys": "R (hold)", "does": "retry the stage from its start (in the arena, the fight); release before holding again"},
	{"keys": "F1", "does": "tuning panel (frees the mouse)"},
	{"keys": "F3", "does": "physics interpolation on/off (off by default)"},
	{"keys": "F4", "does": "save every tuning value to user://tuning-<time>.json"},
	{"keys": "Esc", "does": "free the mouse; again to quit"},
]

const SCREEN_KEYS := [
	{"keys": "Space", "does": "title: start; summary: choose a class (after a short beat)"},
	{"keys": "1, 2, ...", "does": "class select: one number per class card, left to right"},
	{"keys": "R", "does": "death screen: retry the stage, or the fight in the arena"},
	{"keys": "T", "does": "arena death screen: replay stage 3 from its start"},
	{"keys": "N", "does": "death or summary: new run, same class"},
	{"keys": "C", "does": "death screen: choose a class"},
]

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
	lines.append("Screens (every choice is also a button: click it, or press its key)")
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
