extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Companion := preload("res://src/core/companion.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const ClassCard := preload("res://src/ui/class_card.gd")

# The interim camp between runs, a title page on K: which pilots are ready and how each
# locked one unlocks, the companion pieces found and seated, where paint is chosen, and the
# achievements count. Launch, Achievements, Settings, Jukebox and Back press their keys through
# screens.gd; Companion shows only when the companion owns a piece. The full camp scene
# replaces this page.

const NO_PIECES := "Companion: no pieces yet. Pieces turn up during runs."
const PAINT := "Paint: choose on each pilot's card after Launch."

var back: Button

var _lines: VBoxContainer
var _buttons: HBoxContainer
var _companion: Button


func _init() -> void:
	name = "CampMenu"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines = VBoxContainer.new()
	_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 18)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buttons)
	_buttons.add_child(ChoiceButton.new("launch", "key_space", "Launch"))
	_companion = ChoiceButton.new("companion", "key_m", "Companion")
	_buttons.add_child(ChoiceButton.new("achievements", "key_a", "Achievements"))
	_buttons.add_child(ChoiceButton.new("settings", "key_s", "Settings"))
	_buttons.add_child(ChoiceButton.new("jukebox", "key_j", "Jukebox"))
	back = ChoiceButton.new("back", "key_k", "Back")
	_buttons.add_child(back)
	preload("res://src/ui/customize_page.gd").attach(self)


func button_for(action: String) -> Button:
	for child in _buttons.get_children():
		if child.action == action:
			return child
	return null


# The companion button, in or out of the row, so screens.gd wires it once.
func companion_button() -> Button:
	return _companion


# What the camp shows, for a test and for the page: pilots, pieces, seated, achievements.
static func reading(game) -> Dictionary:
	var profile = game.ctx.profile
	var pilots: Array = []
	var ready := 0
	for def in game.flow.classes:
		var is_ready: bool = game.pilot_unlocked(def)
		if is_ready:
			ready += 1
		pilots.append({"id": def.id, "name": def.display_name, "ready": is_ready,
			"hint": ClassCard.unlock_hint(def, game.progress)})
	var model = Companion.new()
	var doc: Dictionary = profile.companion() if profile != null else {}
	if not doc.is_empty() and not model.from_dict(doc):
		model = Companion.new()
	var seated: Array = []
	for id in model.sockets:
		for piece in Companion.PIECES:
			if piece["id"] == id:
				seated.append(String(piece["name"]))
	var ids: Array = Achievements.ids()
	var earned := 0
	for id in ids:
		if profile != null and profile.earned(id):
			earned += 1
	var lines := PackedStringArray()
	lines.append("Pilots ready: %d of %d" % [ready, pilots.size()])
	for p in pilots:
		if p["ready"]:
			lines.append("%s: ready" % p["name"])
		else:
			lines.append("%s: %s" % [p["name"], p["hint"] if p["hint"] != "" else "locked"])
	var pieces: int = model.owned.size()
	if pieces > 0:
		lines.append("Companion pieces: %d of %d" % [pieces, Companion.PIECES.size()])
		lines.append("Seated: %s" % (" + ".join(PackedStringArray(seated)) if not seated.is_empty() else "none"))
	else:
		lines.append(NO_PIECES)
	lines.append(PAINT)
	lines.append("Achievements: %d of %d earned" % [earned, ids.size()])
	return {"pilots": pilots, "pieces": pieces, "piece_total": Companion.PIECES.size(),
		"seated": seated, "earned": earned, "achievement_total": ids.size(), "lines": lines}


func refresh(game) -> void:
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	var read := reading(game)
	var pilots: Array = read["pilots"]
	var lines: PackedStringArray = read["lines"]
	for i in lines.size():
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", UiFonts.bold())
		label.add_theme_font_size_override("font_size", 22)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color: Color = Palette.AMBER
		if i >= 1 and i <= pilots.size():
			color = Palette.SAND if pilots[i - 1]["ready"] else Palette.SLATE
		label.add_theme_color_override("font_color", color)
		label.text = lines[i]
		_lines.add_child(label)
	var wanted: bool = read["pieces"] > 0
	if wanted and _companion.get_parent() == null:
		_buttons.add_child(_companion)
		_buttons.move_child(_companion, 1)
	elif not wanted and _companion.get_parent() == _buttons:
		_buttons.remove_child(_companion)


# The Companion button lives outside the tree while hidden; free it with the page.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_companion) and _companion.get_parent() == null:
		_companion.free()


func labels() -> PackedStringArray:
	var out := PackedStringArray()
	for child in _lines.get_children():
		out.append(child.text)
	return out
