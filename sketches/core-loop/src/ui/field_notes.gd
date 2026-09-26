extends CanvasLayer

const EventKinds := preload("res://src/core/event_kinds.gd")

# The one copy of the field notes: the Tab overlay prints these, the HUD hint line is
# built from CONTROLS, and README.md mirrors them by hand. The legend is generated
# from event_kinds.gd, so it always shows the colours and wording the game uses.
const TITLE := "Scrapkeep: First Run · field notes"

const TESTING := [
	"The spine of the core loop: title, class, three stages, beacon, reward gates, launch, summary. Combat, build, audio and events are minimal stubs; the real ones land next.",
	"Momentum is sacred: the beacon charges while you roll inside its ring, reward gates are arches you roll through, and the launch keeps your horizontal speed into the next stage.",
	"The pylon banks the speed you plant with. Space slingshots you off along the face with it plus a boost; E drops off where you are. The camera goes to the shoulder while mounted.",
	"Death is one key: R retries the stage from its start with the scrap, health and parts you entered with; N starts a new run as the same class. Hold R in play to retry the stage.",
]

const QUESTIONS := [
	"Does the loop read without instructions: where to go, what the beacon wants, what a gate gives?",
	"Does the launch into the next stage feel like momentum carried, or like a load screen?",
	"Is the shoulder view while mounted enough to see what you are shooting?",
	"Is retry fast enough that dying costs you nothing but the stage?",
]

const TRY_FIRST := [
	"Pick either class with 1 or 2. You drop in already rolling: take the chute down to the mid shelf.",
	"Roll into the beacon's ring and keep moving inside it; leaving pauses the charge.",
	"When it charges, two arches appear ahead of you. Roll through one to take its part.",
	"Hit a steep face at speed, press E, fire with left mouse, then Space to slingshot off.",
	"Get scrapped on purpose, then press R: you are back at the stage start in under a second.",
]

const CONTROLS := [
	{"keys": "W A S D", "does": "drive, relative to where the camera looks", "hint": "WASD move"},
	{"keys": "mouse", "does": "look", "hint": "mouse look"},
	{"keys": "Space", "does": "jump, double jump, hold falling to glide; slingshots off a pylon", "hint": "Space jump/glide"},
	{"keys": "Shift", "does": "boost; airborne it is the air dash", "hint": "Shift boost/dash"},
	{"keys": "Ctrl", "does": "brake; airborne it is the slam", "hint": "Ctrl brake/slam"},
	{"keys": "left mouse", "does": "fire the class weapon (hold)", "hint": "LMB fire"},
	{"keys": "F", "does": "class special", "hint": "F special"},
	{"keys": "right mouse", "does": "fire the grapple at the reticle's target; release to let go", "hint": "RMB grapple"},
	{"keys": "Q (hold)", "does": "winch: haul toward the hook", "hint": "Q winch"},
	{"keys": "E", "does": "plant a pylon on a steep face or a close wall hook; again to drop off", "hint": "E pylon"},
	{"keys": "mouse wheel", "does": "down pays rope out, up notches it in", "hint": "wheel rope"},
	{"keys": "Tab (hold)", "does": "these field notes; the game pauses while held", "hint": "Tab notes"},
	{"keys": "P", "does": "pause / resume", "hint": "P pause"},
	{"keys": "R (hold)", "does": "retry the stage from its start", "hint": "hold R retry"},
	{"keys": "F1", "does": "tuning panel (frees the mouse)", "hint": "F1 tuning"},
	{"keys": "F3", "does": "physics interpolation on/off (off by default)", "hint": "F3 interp"},
	{"keys": "F4", "does": "save every tuning value to user://tuning-<time>.json", "hint": "F4 save tuning"},
	{"keys": "Esc", "does": "free the mouse; again to quit", "hint": "Esc mouse/quit"},
]

const SCREEN_KEYS := [
	{"keys": "Space", "does": "title: start; summary: choose a class"},
	{"keys": "1 / 2", "does": "class select: Pylon engineer / Runner-gunner"},
	{"keys": "R", "does": "death screen: retry the stage"},
	{"keys": "N", "does": "death or summary: new run, same class"},
	{"keys": "C", "does": "death screen: choose a class"},
]

const HINT_BREAK := 9

var game

var _notes: Control
var _paused: Label


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
		lines.append("[color=#%s]%s  %s[/color]" % [(row["color"] as Color).to_html(false), row["shape"], words])
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
	var title := Label.new()
	title.text = "%s  ·  paused while Tab is held" % TITLE
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var columns := HBoxContainer.new()
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

	_paused = Label.new()
	_paused.text = "PAUSED  ·  P to resume  ·  hold Tab for field notes"
	_paused.add_theme_font_size_override("font_size", 40)
	_paused.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_paused.add_theme_constant_override("outline_size", 10)
	_paused.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_paused.position = Vector2(-470.0, 120.0)
	_paused.visible = false
	add_child(_paused)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB:
			game.hold_notes(event.pressed)
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
