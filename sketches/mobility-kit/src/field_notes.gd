extends CanvasLayer

# The one copy of the field notes: the Tab overlay prints these, the HUD hint line is
# built from CONTROLS, and the README's v2 sections mirror them by hand.
const TITLE := "Mobility kit v2 · field notes"

const TESTING := [
	"Slam anchor: one rule for every landing angle. Flat ground plants you for up to 0.3 s with the biggest shockwave; a steep slope barely plants and throws you downhill.",
	"Winch: hold Q and the rope hauls you toward the hook, slack or taut.",
	"Grapple reach indicator with a 4 degree magnetic assist: the reticle's shape and colour say whether a shot connects before you fire.",
	"Pylon mount replaces mag-cling: E drives a post into a steep face and holds the ball on it. The LMB zap is a PLACEHOLDER weapon.",
	"Physics interpolation on F3 (off by default, so v1's feel is the baseline). F4 saves every tuning value to a file.",
]

const QUESTIONS := [
	"Does the angle-blended slam read, with a plant on flat ground and a launch on hills?",
	"Does the winch haul feel intuitive?",
	"Can you tell before firing whether the grapple will connect?",
	"Is mount-to-fire fun, and is it a breather when surrounded?",
	"Does air dash feel starved sharing one 1.1 s cooldown with boost? (F1: Split dash cooldown.)",
	"F3: does interpolation make the ball and grapple aim steadier?",
]

const TRY_FIRST := [
	"Jump on the pad and Ctrl-slam flat ground: you should stop dead for a beat. Hold Space as you land; the jump fires the moment the plant lets go.",
	"Slam onto the orange kicker, then onto the banked turn's outer wall: less plant, more launch.",
	"Sweep the crosshair past a post top: cross (nothing), ring (in reach), diamond (the magnet snapped on).",
	"Hook a post from the ground, let the rope go slack, then hold Q to be winched up.",
	"Drive into the dummies on the pad, hop next to a pillar and press E: the pylon shoves them back. LMB to zap, Space to jump off.",
	"Grapple a magnet wall, swing in close and press E to mount where the hook bit.",
	"F1, flip Split dash cooldown, and chain boost into air dash to compare.",
	"Ride the downhill run with F3 off, then on: watch the ball and the reticle for judder. F4 when a setup feels right.",
]

const CONTROLS := [
	{"keys": "W A S D", "does": "drive, relative to where the camera looks", "hint": "WASD move"},
	{"keys": "mouse", "does": "look (free while mounted)", "hint": "mouse look"},
	{"keys": "Space", "does": "jump, double jump, hold falling to glide; jumps off a pylon", "hint": "Space jump/glide"},
	{"keys": "Shift", "does": "boost; airborne it is the air dash", "hint": "Shift boost/air dash"},
	{"keys": "Ctrl", "does": "brake; airborne it is the slam", "hint": "Ctrl brake/slam"},
	{"keys": "right mouse", "does": "fire the grapple at the reticle's target; release to let go", "hint": "RMB grapple"},
	{"keys": "Q (hold)", "does": "winch: haul toward the hook", "hint": "Q winch"},
	{"keys": "mouse wheel", "does": "down pays rope out, up notches it in", "hint": "wheel rope"},
	{"keys": "E", "does": "plant a pylon on a steep face or a close wall hook; again to drop off", "hint": "E pylon"},
	{"keys": "left mouse", "does": "while mounted: zap (placeholder weapon)", "hint": "LMB zap (mounted)"},
	{"keys": "1 - 5", "does": "toggle the five augments", "hint": "1-5 augments"},
	{"keys": "Tab (hold)", "does": "these field notes; the game pauses while held", "hint": "Tab notes"},
	{"keys": "P", "does": "pause / resume", "hint": "P pause"},
	{"keys": "F1", "does": "tuning panel (frees the mouse)", "hint": "F1 tuning"},
	{"keys": "F2", "does": "switch physics mode (rigid <-> kinematic)", "hint": "F2 physics mode"},
	{"keys": "F3", "does": "physics interpolation on/off (off by default)", "hint": "F3 interp"},
	{"keys": "F4", "does": "save every tuning value to user://tuning-<time>.json", "hint": "F4 save tuning"},
	{"keys": "R", "does": "respawn at the top of the downhill run", "hint": "R respawn"},
	{"keys": "Esc", "does": "free the mouse; again to quit", "hint": "Esc mouse/quit"},
]

const HINT_BREAK := 10

var lab

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
	return "\n".join(lines)


# Pause has to keep listening while the tree is paused, so this layer always processes
# and the lab it steers does not.
func setup(lab_ref) -> void:
	lab = lab_ref
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
	columns.add_theme_constant_override("separation", 36)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	var notes := Label.new()
	notes.text = notes_text()
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.size_flags_stretch_ratio = 1.6
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
			lab.hold_notes(event.pressed)
			get_viewport().set_input_as_handled()
		KEY_P:
			if event.pressed:
				lab.toggle_pause()
				get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if lab == null:
		return
	_notes.visible = lab.notes_held()
	_paused.visible = lab.pause_toggled() and not lab.notes_held()
