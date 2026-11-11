extends CanvasLayer

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Bindings := preload("res://src/core/bindings.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
const ThreatSheet := preload("res://src/ui/threat_sheet.gd")
const GrowthSheet := preload("res://src/ui/growth_sheet.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")

# Tab's field notes are pictures (playtest entry 8: the old page was "a whole essay of
# text"): the controls as a keyboard and mouse with your pilot's keys lit, what hurts
# you, and how you grow, then the codex pages. Each picture page stays inside the
# calm-screen budget of 40 words. CONTROLS below is the one key list; the diagram draws
# its rows with caps and a short word. The tester notes (TESTING, QUESTIONS, TRY_FIRST,
# SCREEN_KEYS) and the legend are no longer drawn on Tab; README.md mirrors them.
# What the run asks of you and why, in one line: the title screen shows it too. The why is the game's
# one line (ruling cj, design-v3/STORY-MAP.md): a machine runs the world and calls it perfect (the quote marks are the crew's), and the crew takes it back.
const OBJECTIVE := "A machine runs your world \"perfectly\". Take it back. Get heavy, break the Wardens, smash their cores."

const TESTING := [
	"A run goes from the title and a pilot through two stages in each of three worlds, each sealed by a Warden at its beacon. Grow, crack its guard, smash its open core, then roll through a reward gate and launch into the next stage. Each world's last stage launches you into its boss arena, where you rout Admiral Brindle, still the Waking and quiet the Mind. Quieting the Mind ends the run.",
	"Scrap you roll up becomes heft, parts add more, and heft multiplies your punch. The plate at the top of the screen is the Warden's guard. Hits fill its bar, a full bar staggers the Warden and opens its core, and a hit on the open core shatters one of its chunks. A light ball fills the bar slowly, so grow and come back.",
	"Outweigh fodder and you roll straight through it with no speed lost. Events and vaults drop bonus cores (the diamonds beside the objective) that raise the gate tiers.",
	"Sable's pylon banks the speed you plant with. While mounted, jump slingshots you off along the face with a boost added, and use drops you off where you are. The camera goes to the shoulder while mounted.",
	"Death ends the run, and the next one starts from world 1 as the same pilot. The one second chance is a part you earn, the Spare Frame, which leaves you at 20% health once a run. Hold restart in play to abandon the run and start a new one.",
]

const QUESTIONS := [
	"Was the Warden a goal or a chore? Did growth feel like enough growth?",
	"Does the loop read without instructions? Do you know where to go, what the beacon wants and what a gate gives?",
	"Does the launch into the next stage feel like momentum carried, or like a load screen?",
	"Is the shoulder view while mounted enough to see what you are shooting?",
	"Does dying and starting again feel quick enough that you want one more run?",
]

const TRY_FIRST := [
	"Pick Sable, Rivet or Kest with a number key or a click. You drop in already rolling; the Warden is at the beacon you can see from the drop, and a chevron at the screen edge points to it when it is out of view.",
	"Roll up the scrap lines on the way down. Scrap is your heft, and a heavier ball hits harder.",
	"Break the Warden. The line at the top of the screen says what it wants next. At the dam, ride the water sheet up the face into its core. At the flume, hook your line onto it and fire. Its gates open when it breaks, and rolling through one takes its part.",
	"As Sable, hit a steep face at speed, plant a pylon, fire, then hold and release jump to slingshot off.",
	"Get scrapped on purpose, then hold restart for a new run as the same pilot from world 1.",
	"Against Brindle, read the line at the top of the screen. Shoot the crane magnets in phase 1 and slam the vent caps in phase 2. In phase 3, bait his charge into the rim wall and hit the open cockpit. Then ram or stomp the scooter when he runs.",
]

# The key list. The ten verbs come first, their keys read from the bindings table; the rest
# are menu and screen keys, which are not verbs. A row with "caps" and "short" is drawn on the
# controls diagram (Tab's Keys page and the title's Help page), as its keycaps and those one
# or two words. The F special retired into slot 2 (design-v3/SKILL-BAR.md section 5).
const VERB_ROWS := [
	["roll", "drive, relative to where the camera looks. At top speed walls and overhang lips count as ground", "drive"],
	["look", "look", "look"],
	["jump", "jump and double jump. Sable vault-kicks off a steep face in the air, and mounted she holds and releases to slingshot. Kest holds falling to glide, and holds in his own blast to rocket jump", "jump"],
	["fire", "left click fires your pick, the weapon unless you picked 2 or 3. Sable and Rivet fire while held; Kest holds to aim a sticky charge, releases to throw. A special fills while held and fires on release", "fire"],
	["select", "1, 2, 3 pick what left click does. 1 is the weapon, 2 the special and 3 the line skill. A cast, or 3 s without one, returns to 1", "pick"],
	["harpoon", "the harpoon. Press hooks the aim point, hold keeps the line, release flings. During a charge it cancels. With a line skill loaded, the next hook carries it", "harpoon"],
	["haul", "haul the line in. It smashes on a body and winches on the world. With no line it brakes on the ground and slams in the air", "haul"],
	["boost", "your go verb, which is Sable's boost, Rivet's sprint (hold) and Kest's smoke blink", "boost"],
	["ultimate", "your ultimate, when the ring round the crosshair is full. It rides a line or a launch to where you aim and your tech fires on the way. Jump bails out", "ultimate"],
	["interact", "interact with the device you face within 18 m (the lock holds after you pass it). Hold it for anything with a cost or a bet, press it for a cache. At a relay mast each hold raises the bet one step (up to x4, one more clears it) until you roll into its ring. Inside an amber lane it arms the ride. Sable, with nothing in reach, plants a pylon on a steep face or a close wall hook, and again to drop off", "use / ride"],
]
const MENU_ROWS := [
	{"keys": "Tab (hold)", "does": "field notes and the codex; the game pauses while held; Q / E switch pages", "caps": ["key_tab"], "short": "notes"},
	{"keys": ". , / ;", "does": "the radio, with . for the next station, , for back, / to skip the track and ; to keep the track on through a boss"},
	{"keys": "F", "does": "fire the racked active, when actives are on (the D-pad down on a pad); nothing is racked otherwise"},
	{"keys": "- / =", "does": "music volume down / up (also in the pause menu)"},
	{"keys": "[ / ]", "does": "effects volume down / up (also in the pause menu)"},
	{"keys": "M", "does": "mute or unmute"},
	{"keys": "P / Esc", "does": "opens the pause menu with resume, new run, field notes, music and effects volume, and quit with X (hold)", "caps": ["key_p"], "short": "pause"},
	{"keys": "R (hold)", "does": "new run as the same pilot, from world 1. Release before holding again", "caps": ["key_r"], "short": "hold restart"},
	{"keys": "F1", "does": "with --dev only, the tuning panel (frees the mouse)"},
	{"keys": "F3", "does": "with --dev only, frame smoothing on or off for this session (Settings, Display keeps it)"},
	{"keys": "F4", "does": "with --dev only, saves every tuning value to user://tuning-<time>.json"},
	{"keys": "Esc", "does": "quit, outside play"},
]
static var CONTROLS := controls()

# The field rules page of the title's Help (help_page.gd), one line per rule, each short enough
# for its calm-screen budget of 40 words with the title and buttons. A line is {id, words}; the
# words open with the rule's own name. They go with the key list above: the keys read F (the
# active; the help page shows its line only while the actives option is on) and . , / (the
# radio). Wall grip, jam fields, cast times and relay stakes have no key; each is also said once,
# in play, when first met (field_tips.gd). A cast is a slot with a cast time: the Q variants and
# Gather Plate (ability_state.gd VARIANT_CAST).
const FIELD_RULES := [
	{"id": "grip", "say": "Stay fast against a wall and you climb it."},
	{"id": "radio", "say": "Radio", "keys": [["cl_radio_next", "next"], ["cl_radio_prev", "back"], ["cl_radio_skip", "skip"]]},
	{"id": "stake", "say": "Hold", "verb": "interact", "then": "at a relay mast to raise the bet."},
	{"id": "active", "verb": "active", "then": "fire your active"},
]

const SCREEN_KEYS := [
	{"keys": "Space", "does": "starts from the title and chooses a pilot on the summary (pad B on the summary)"},
	{"keys": "H", "does": "how to play from the title, and back"},
	{"keys": "1, 2, ...", "does": "one number per pilot card on pilot select, left to right"},
	{"keys": "N", "does": "new run as the same pilot, on the summary (pad A on the summary)"},
]

# A rule as credits_hint.gd parts: its words, with each key drawn as the keycap the bindings give now
# (a rebind moves the cap), never a typed letter. The jam and cast rules are the picture pages' captions.
static func rule_parts(rule: Dictionary) -> Array:
	var parts := []
	if rule.has("say"):
		parts.append({"say": rule["say"]})
	for pair in rule.get("keys", []):
		var cap := Glyphs.of_action(pair[0], "key_" + OS.get_keycode_string(Bindings.EXTRA_ACTIONS[pair[0]]["keys"][0]).to_lower())
		parts.append({"cap": cap, "say": Keycap.label(cap)})
		parts.append({"say": pair[1]})
	if rule.has("verb"):
		var glyph := Glyphs.of(rule["verb"])
		parts.append({"cap": glyph, "say": Keycap.label(glyph)})
	if rule.has("then"):
		parts.append({"say": rule["then"]})
	return parts


# The key list in display order: a row per verb with its table keys and caps, then the menu keys.
static func controls() -> Array:
	var out := []
	for spec in VERB_ROWS:
		var verb: String = spec[0]
		out.append({"keys": Bindings.label(verb), "does": spec[1], "caps": verb_caps(verb), "short": spec[2]})
	out.append_array(MENU_ROWS)
	return out


# The caps a verb draws on the diagram: its glyph, one cap per drive key for the roll, and one
# per number key for the pick.
static func verb_caps(verb: String) -> Array:
	if verb == "select":
		return Bindings.SELECT_ACTIONS.map(func(action):
			return "key_" + OS.get_keycode_string(Bindings.VERBS["select"]["actions"][action]["keys"][0]).to_lower())
	if verb != "roll":
		return [Bindings.glyph(verb)]
	var caps := []
	for action in ["cl_forward", "cl_left", "cl_back", "cl_right"]:
		caps.append("key_" + OS.get_keycode_string(Bindings.VERBS["roll"]["actions"][action]["keys"][0]).to_lower())
	return caps


# A glyph per event_kinds shape, so a codex card wears its category's silhouette.
const SHAPE_GLYPHS := {
	"diamond": "◆", "wave": "≈", "burst": "*", "square": "■", "chevron": "›", "star": "★",
	"ring": "○", "arrow": "»", "bar": "=", "cross": "×", "core": "◆", "none": "",
}
const CARD_COLUMNS := 3
const MOUSE_STEPS := {MOUSE_BUTTON_LEFT: 1, MOUSE_BUTTON_WHEEL_DOWN: 1, MOUSE_BUTTON_RIGHT: -1, MOUSE_BUTTON_WHEEL_UP: -1}
# The picture pages, before the codex: id -> {label, icon}. An icon names an Icons id.
const PICTURE_PAGES := {
	"keys": {"label": "Keys", "icon": "key_lmb"},
	"hurts": {"label": "What hurts", "icon": "thr_instant"},
	"grow": {"label": "Growth", "icon": "res_heft"},
}

var game

var _notes: Control
var _tabs
var _diagram
var _pictures := {}
var _codex_page: VBoxContainer
var _page := 0


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


# Tab has to keep listening while the tree is paused, so this layer always processes
# and the game it steers does not. P and Esc belong to the pause menu (pause_menu.gd).
func setup(game_ref) -> void:
	game = game_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	_notes = PanelContainer.new()
	_notes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notes.offset_left = 40.0
	# Below the objective and run status strip, which presentation draws on top.
	_notes.offset_top = 72.0
	_notes.offset_right = -40.0
	_notes.offset_bottom = -24.0
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := ScrapFrame.plate(Color(Palette.SAND, 0.3), 5, Color(0.07, 0.08, 0.11, 0.94), 2.0, 0.62)
	backing.set_content_margin_all(22.0)
	_notes.add_theme_stylebox_override("panel", backing)
	add_child(_notes)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_notes.add_child(box)
	_tabs = TabStrip.new()
	_tabs.notes = self
	box.add_child(_tabs)

	_codex_page = VBoxContainer.new()
	_codex_page.add_theme_constant_override("separation", 12)
	_codex_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_page.visible = false
	box.add_child(_codex_page)

	_diagram = ControlsDiagram.new()
	var sheets := {"keys": _diagram, "hurts": ThreatSheet.new(), "grow": GrowthSheet.new()}
	for id in PICTURE_PAGES:
		var holder := CenterContainer.new()
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(sheets[id])
		box.add_child(holder)
		_pictures[id] = holder
	_notes.visible = false
	show_page(0)


# The picture pages first, then one page per codex category (reserved ones only once
# they hold entries), then the Found list and lore Notes.
func pages() -> Array[String]:
	var list: Array[String] = []
	list.append_array(PICTURE_PAGES.keys())
	for id in EventKinds.CODEX_CATEGORIES:
		var reserved: bool = EventKinds.CODEX_CATEGORIES[id]["reserved"]
		if not reserved or (_codex() != null and not _codex().entries(id).is_empty()):
			list.append(id)
	list.append("found")
	list.append("notes")
	return list


func _codex():
	return game.codex if game != null else null


func show_page(index: int) -> void:
	var list := pages()
	_page = posmod(index, list.size())
	var page: String = list[_page]
	for id in _pictures:
		_pictures[id].visible = id == page
	_codex_page.visible = not PICTURE_PAGES.has(page)
	if page == "keys":
		_diagram.set_class(game.run.class_def if game != null and game.run != null else null)
	elif not PICTURE_PAGES.has(page):
		render_page(page)
	_tabs.queue_redraw()


func current_page() -> String:
	return pages()[_page]


func diagram():
	return _diagram


func tab_label(page := "") -> String:
	if page == "":
		page = current_page()
	if PICTURE_PAGES.has(page):
		return PICTURE_PAGES[page]["label"]
	if page == "notes":
		return "Notes"
	if page == "found":
		return "Found %d" % (_codex().found().size() if _codex() != null else 0)
	return "%s %d%%" % [EventKinds.category(page)["label"], int(_codex().completion(page) * 100.0) if _codex() != null else 0]


func _tab_icon(page: String) -> Texture2D:
	if PICTURE_PAGES.has(page):
		return Icons.texture(PICTURE_PAGES[page]["icon"])
	if page in ["found", "notes"]:
		return Icons.shape("star")
	return Icons.shape(EventKinds.category(page)["shape"])


func _tab_color(page: String) -> Color:
	if page == "hurts":
		return Palette.HAZARD
	if page == "grow":
		return Palette.AMBER
	if page == "keys":
		var def = game.run.class_def if game != null and game.run != null else null
		return def.color if def != null else Palette.SAND
	if page in ["found", "notes"]:
		return Palette.SAND
	return EventKinds.category(page)["color"]


# The page row: Q, one icon per page (the open one wears its name and an underline in
# its colour), E. Hovering an icon opens its page when the mouse is free (notes pinned
# from the pause menu).
class TabStrip:
	extends Control

	const H := 40.0
	const CAP := 26.0
	const ICON := 26.0
	const STEP := 46.0
	const FONT := 20

	var notes
	var _spots: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, H)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func drawn_words() -> PackedStringArray:
		var out := PackedStringArray(["Q", "E"])
		out.append(notes.tab_label())
		return out

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			for spot in _spots:
				if spot["rect"].has_point(event.position) and spot["index"] != notes._page:
					notes.show_page(spot["index"])
					return

	func _draw() -> void:
		var list: Array[String] = notes.pages()
		var x := 0.0
		var mid := H * 0.5
		x += Keycap.draw(self, Vector2(CAP * 0.5, mid), "key_q", Palette.SAND, CAP).size.x + 18.0
		_spots.clear()
		var font := UiFonts.bold()
		for i in list.size():
			var page: String = list[i]
			var color: Color = notes._tab_color(page)
			var open: bool = i == notes._page
			var icon := Rect2(Vector2(x, mid - ICON * 0.5), Vector2(ICON, ICON))
			draw_texture_rect(notes._tab_icon(page), icon, false, Color(color, 1.0 if open else 0.45))
			var width := ICON
			if open:
				var label: String = notes.tab_label(page)
				draw_string(font, Vector2(x + ICON + 8.0, mid + font.get_ascent(FONT) * 0.5 - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, color)
				width += 8.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x
				draw_line(Vector2(x, H - 1.0), Vector2(x + width, H - 1.0), color, 3.0)
			_spots.append({"index": i, "rect": Rect2(Vector2(x - 6.0, 0.0), Vector2(width + 12.0, H))})
			x += width + STEP - ICON
		Keycap.draw(self, Vector2(x + 4.0 + CAP * 0.5, mid), "key_e", Palette.SAND, CAP)


# Builds one codex page and returns how many cards or lines it shows.
func render_page(page: String) -> int:
	for child in _codex_page.get_children():
		_codex_page.remove_child(child)
		child.queue_free()
	if page == "notes":
		return _render_notes()
	var codex = _codex()
	if codex == null:
		return 0
	if page == "found":
		return _render_found(codex)
	var style: Dictionary = EventKinds.category(page)
	var listed: Array = codex.entries(page)
	var head := Label.new()
	head.add_theme_font_size_override("font_size", UiTokens.BODY)
	head.add_theme_color_override("font_color", style["color"])
	head.text = "%s %s, %d of %d found" % [SHAPE_GLYPHS.get(style["shape"], ""), style["label"],
		listed.filter(func(e): return e["known"]).size(), listed.size()]
	_codex_page.add_child(head)
	if listed.is_empty():
		var none := Label.new()
		none.text = "Nothing recorded here yet."
		_codex_page.add_child(none)
		return 0
	var grid := GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_codex_page.add_child(grid)
	for entry in listed:
		grid.add_child(_card(entry, style))
	return listed.size()


# Saved codex ids are the only found-state; locked rows never expose their words.
func note_entries() -> Array:
	var listed := []
	var codex = _codex()
	for row in LoreRows.ROWS:
		if row["kind"] != "field_note":
			continue
		var known: bool = codex != null and codex.known(row["id"])
		listed.append({"id": row["id"], "known": known, "text": row["text"] if known else ""})
	return listed


func _render_notes() -> int:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_page.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 12)
	scroll.add_child(lines)
	var listed := note_entries()
	for i in listed.size():
		var entry: Dictionary = listed[i]
		var line := Label.new()
		line.name = entry["id"]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", UiTokens.BODY)
		line.add_theme_color_override("font_color", Palette.SAND if entry["known"] else UiTokens.quiet())
		line.text = "%d. %s" % [i + 1, entry["text"] if entry["known"] else "Locked"]
		lines.add_child(line)
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
	text.add_theme_font_size_override("font_size", UiTokens.CAPTION)
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
		# A clue that opens with "+" carries on from its hint ("Knocked machines" / "+ three down").
		lines.append(clue if clue.begins_with("+") else "Try " + clue)
	return "\n".join(lines)


func _render_found(codex) -> int:
	var list := RichTextLabel.new()
	list.bbcode_enabled = true
	list.fit_content = true
	list.add_theme_font_size_override("normal_font_size", UiTokens.BODY)
	var lines := PackedStringArray(["Found by accident, no name yet"])
	for text in codex.found():
		var style: Dictionary = EventKinds.category(codex.found_category(text))
		lines.append("[color=#%s]%s %s[/color]" % [(style["color"] as Color).to_html(false), SHAPE_GLYPHS.get(style["shape"], ""), text])
	if codex.found().is_empty():
		lines.append("Nothing yet. Mix elements, patterns and terrain and see what happens.")
	list.text = "\n".join(lines)
	_codex_page.add_child(list)
	return codex.found().size()


# While Tab is held the mouse is captured, so its buttons turn pages: left or wheel down
# for the next, right or wheel up for the one before.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and game != null and game.notes_held() and MOUSE_STEPS.has(event.button_index):
		show_page(_page + MOUSE_STEPS[event.button_index])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_BACK:
			game.hold_notes(event.pressed)
			if event.pressed:
				show_page(_page)
			get_viewport().set_input_as_handled()
		elif event.pressed and game != null and game.notes_held() and (event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_RIGHT):
			show_page(_page + (1 if event.button_index == JOY_BUTTON_DPAD_RIGHT else -1))
			get_viewport().set_input_as_handled()
		return
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


func _process(_delta: float) -> void:
	if game == null:
		return
	_notes.visible = game.notes_held()
