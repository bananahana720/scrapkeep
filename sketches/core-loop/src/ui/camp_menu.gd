extends VBoxContainer

const Secrets := preload("res://src/core/secrets.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Palette := preload("res://src/core/palette.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Companion := preload("res://src/core/companion.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")


const NO_PIECES := "No SPIL-9 pieces yet. They turn up in runs."
const WALK_HINTS := [{"cap": "key_w", "say": "W"}, {"cap": "key_a", "say": "A"}, {"cap": "key_s", "say": "S"}, {"cap": "key_d", "say": "D"},
	{"say": "roll"}, {"say": "·"}, {"cap": "key_space", "say": "Space"}, {"say": "jump"}, {"say": "·"}, {"say": "mouse to look"}, {"say": "·"},
	{"cap": "key_k", "say": "K"}, {"say": "leave camp"}]
const STRIP_LIFT := 14
const LEAVE_HINT := [{"cap": "key_k", "say": "K"}, {"say": "leave camp"}]
const PAINT := "Choose paint on each pilot's card after Launch."

var back: Button
var walk := false
var walked := false
var customize
var customize_entry: Button

var _lines: VBoxContainer
var _strip: HBoxContainer
var _buttons: HBoxContainer
var _companion: Button
var _walk_keys: Control


func _init() -> void:
	name = "CampMenu"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines = VBoxContainer.new()
	_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buttons)
	_buttons.add_child(ChoiceButton.new("launch", "key_space", "Launch"))
	_companion = ChoiceButton.new("companion", "key_m", "Companion")
	_buttons.add_child(ChoiceButton.new("work_orders", "key_o", "Work orders"))
	_buttons.add_child(ChoiceButton.new("logbook", "key_l", "Logbook"))
	_buttons.add_child(ChoiceButton.new("achievements", "key_a", "Achievements"))
	_buttons.add_child(ChoiceButton.new("settings", "key_s", "Settings"))
	_buttons.add_child(ChoiceButton.new("jukebox", "key_j", "Jukebox"))
	_buttons.add_child(ChoiceButton.new("radio", "key_r", "Radio"))
	back = ChoiceButton.new("back", "key_esc", "Back")
	_buttons.add_child(back)
	_strip = HBoxContainer.new()
	_strip.name = "WalkStrip"
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_theme_constant_override("separation", 24)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.visible = false
	add_child(_strip)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA)
	box.set_corner_radius_all(UiTokens.RADIUS)
	box.content_margin_left = UiTokens.GAP_M
	box.content_margin_right = UiTokens.GAP_M
	box.content_margin_top = UiTokens.GAP_XS
	box.content_margin_bottom = UiTokens.GAP_XS
	plate.add_theme_stylebox_override("panel", box)
	_walk_keys = CreditsHint.new()
	_walk_keys.name = "WalkKeys"
	_walk_keys.setup(WALK_HINTS)
	plate.add_child(_walk_keys)
	var lifted := MarginContainer.new()
	lifted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lifted.add_theme_constant_override("margin_bottom", STRIP_LIFT)
	lifted.add_child(plate)
	_strip.add_child(lifted)
	preload("res://src/ui/customize_page.gd").attach(self)


func walk_words() -> String:
	return _strip.find_child("WalkKeys", true, false).text()


func set_walk(on: bool) -> void:
	if on and not walk:
		_walk_keys.setup(LEAVE_HINT if walked else WALK_HINTS)
		walked = true
	walk = on
	_strip.visible = on
	_lines.visible = not on
	_buttons.visible = not on
	if customize_entry != null:
		customize_entry.visible = not on


func page_opened() -> void:
	_lines.hide()
	_buttons.hide()
	_strip.hide()
	if customize_entry != null:
		customize_entry.hide()


func page_closed() -> void:
	_lines.visible = not walk
	_buttons.visible = not walk
	_strip.visible = walk
	if customize_entry != null:
		customize_entry.visible = not walk


func button_for(action: String) -> Button:
	for child in _buttons.get_children():
		if child.action == action:
			return child
	return null


func companion_button() -> Button:
	return _companion


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
	var doc: Dictionary = game.flow.profile_companion() if profile != null and game.flow != null else {}
	if not doc.is_empty() and not model.from_dict(doc):
		model = Companion.new()
	var seated: Array = []
	for id in model.sockets:
		for piece in Companion.PIECES:
			if piece["id"] == id:
				seated.append(String(piece["name"]))
	var ids: Array = Achievements.ids().filter(func(id): return not Secrets.shut_row(id, profile))
	var earned := 0
	for id in ids:
		if profile != null and profile.earned(id):
			earned += 1
	var lines := PackedStringArray()
	lines.append("%d / %d pilots ready" % [ready, pilots.size()])
	for p in pilots:
		if p["ready"]:
			lines.append("%s is ready" % p["name"])
		else:
			lines.append(("%s is locked. %s" % [p["name"], p["hint"]]) if p["hint"] != "" else "%s is locked" % p["name"])
	var pieces: int = model.owned.size()
	if pieces > 0:
		lines.append("%d / %d companion pieces" % [pieces, Companion.PIECES.size()])
		lines.append(("%s seated" % " + ".join(PackedStringArray(seated))) if not seated.is_empty() else "Nothing seated")
	else:
		lines.append(NO_PIECES)
	lines.append(PAINT)
	lines.append("%d / %d achievements earned" % [earned, ids.size()])
	var codex = game.ctx.get("codex")
	var secrets: Array = []
	for world in Secrets.WORLD_CODEX:
		var count := Secrets.world_count(world, func(id): return codex != null and codex.known(id))
		secrets.append(count)
		lines.append("%d / %d %s secrets found" % [count["found"], count["total"], count["name"]])
	return {"pilots": pilots, "pieces": pieces, "piece_total": Companion.PIECES.size(),
		"seated": seated, "earned": earned, "achievement_total": ids.size(), "secrets": secrets, "lines": lines}


func refresh(game) -> void:
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	var read := reading(game)
	var pilots: Array = read["pilots"]
	var lines: PackedStringArray = read["lines"]
	for i in lines.size():
		var color: Color = Palette.AMBER
		if i >= 1 and i <= pilots.size():
			color = Palette.SAND if pilots[i - 1]["ready"] else Palette.SLATE
		_lines.add_child(UiDraw.label(UiTokens.LABEL, color, lines[i]))
	var wanted: bool = read["pieces"] > 0
	if wanted and _companion.get_parent() == null:
		_buttons.add_child(_companion)
		_buttons.move_child(_companion, 1)
	elif not wanted and _companion.get_parent() == _buttons:
		_buttons.remove_child(_companion)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_companion) and _companion.get_parent() == null:
		_companion.free()


func labels() -> PackedStringArray:
	var out := PackedStringArray()
	for child in _lines.get_children():
		out.append(child.text)
	return out
