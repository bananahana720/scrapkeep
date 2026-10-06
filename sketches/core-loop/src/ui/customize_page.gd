extends VBoxContainer

const Cosmetics := preload("res://src/core/cosmetics.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

signal back_requested

const SLOT_WORDS := {"paint": "Ball paint", "trail": "Ball trail", "decal": "Shell decal", "companion_paint": "Companion paint"}
const ORDER := ["pilot", "paint", "trail", "decal", "companion_paint", "back"]
const WIDTH := 660.0

var rows := {}
var back: Button
var pilot := "pylon_engineer"
# The presentation unit supplies the same art-id/resource map to its consumer.
var assets := {}
var resolver := Cosmetics.new()

var _profile
var _pilots: Array = []
var _camp
var _entry: Button
var _game
var _notice: Label


func _init() -> void:
	name = "CustomizePage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label("Customize", 30))
	for id in ORDER:
		var button := ChoiceButton.new(id, "key_esc" if id == "back" else "key_enter", "Back" if id == "back" else "")
		button.custom_minimum_size = Vector2(WIDTH, 48.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(press.bind(id))
		rows[id] = button
		add_child(button)
	back = rows["back"]
	_notice = _label("", 18)
	add_child(_notice)


# One camp-menu call installs the entry and its child page. The page takes input before
# its screen host, so Esc returns to camp and cannot also close the camp behind it.
static func attach(camp) -> void:
	var page = load("res://src/ui/customize_page.gd").new()
	page._camp = camp
	page.visible = false
	camp.add_child(page)
	var entry := ChoiceButton.new("customize", "key_c", "Customize")
	entry.name = "CustomizeButton"
	entry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	camp.add_child(entry)
	page._entry = entry
	entry.pressed.connect(page._open_from_camp)
	camp.visibility_changed.connect(func():
		if not camp.visible and page.visible:
			page.close())


func _label(words: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.SAND)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _open_from_camp() -> void:
	var screens = _camp.get_parent().get_parent()
	_game = screens.game
	open(_game.ctx.profile, _game.progress)


func open(profile, progress = null) -> void:
	_profile = profile
	_pilots.clear()
	for def in ClassDef.all():
		if def.starter or (_profile != null and _profile.has_pilot(def.id)):
			_pilots.append(def.id)
	if _pilots.is_empty():
		return
	if _profile != null and _profile.last_pilot() in _pilots:
		pilot = _profile.last_pilot()
	if not pilot in _pilots:
		pilot = _pilots[0]
	if progress != null:
		backfill(_profile, progress)
	if _camp != null:
		_camp._lines.hide()
		_camp._buttons.hide()
		_entry.hide()
	show()
	refresh()
	focus("pilot")


# A recorded counter is a lower bound, never an estimated lifetime total. Use the
# largest compatible counter, since multiple rows may count the same event.
static func backfill(profile, progress) -> int:
	if profile == null or progress == null:
		return 0
	var granted := 0
	for id in Achievements.ids():
		if not id.begins_with("ach_d7_") or profile.earned(id):
			continue
		var amount := 0.0
		for source in Achievements.recorded_sources(id):
			amount = maxf(amount, profile.stat("ach." + source))
		if amount <= 0.0:
			continue
		profile.set_stat("ach." + id, maxf(amount, profile.stat("ach." + id)))
		if amount >= float(Achievements.row(id)["count"]):
			progress._earn(id, Achievements.row(id))
			granted += 1
	if profile.can_save:
		profile.save()
	return granted


static func owns(profile, id: String) -> bool:
	var data := Cosmetics.row(id)
	return profile != null and not data.is_empty() and (data["starter"] or profile.has_cosmetic(id))


static func equip(profile, owner: String, slot: String, id: String) -> bool:
	if profile == null or not slot in Cosmetics.SLOTS or owner == "":
		return false
	if (slot == "companion_paint") != (owner == "spil9"):
		return false
	if slot != "companion_paint" and ClassDef.by_id(owner) == null:
		return false
	if id != "" and (not owns(profile, id) or not Cosmetics.fits(id, owner, slot)):
		return false
	profile.equip(owner, slot, id)
	return profile.save()


func choices(slot: String) -> Array:
	var out: Array = [""]
	for id in Cosmetics.for_slot(slot, pilot):
		if owns(_profile, id):
			out.append(id)
	return out


func selected(slot: String) -> String:
	if _profile == null:
		return ""
	var owner := Cosmetics.owner_for(pilot, slot)
	var id: String = _profile.equipped(owner, slot)
	return id if owns(_profile, id) and Cosmetics.fits(id, owner, slot) else ""


# Presentation reads this result, not the raw saved id. An empty row means no trail,
# no shell decal, default SPIL-9 enamel, or the pilot's unmodified ball paint.
func effective(slot: String) -> Dictionary:
	return resolver.resolve(selected(slot), assets)


func refresh() -> void:
	rows["pilot"].text = "Pilot: %s" % ClassDef.by_id(pilot).display_name
	for slot in Cosmetics.SLOTS:
		var id := selected(slot)
		var words := "Default" if slot in ["paint", "companion_paint"] else "None"
		if id != "":
			words = Cosmetics.row(id)["name"]
		rows[slot].text = "%s: %s" % [SLOT_WORDS[slot], words]
		rows[slot].tooltip_text = "Left / right to choose. Locked items unlock through achievements."
	_notice.text = "Left / right to choose. Owned choices save immediately."


func focused_id() -> String:
	for id in ORDER:
		if rows[id].has_focus():
			return id
	return ""


func focus(id: String) -> void:
	if is_visible_in_tree() and rows.has(id):
		rows[id].grab_focus()


func press(id: String) -> void:
	if id == "back":
		close()
	else:
		_step(id, 1)


func _step(id: String, direction: int) -> void:
	if id == "pilot":
		pilot = _pilots[posmod(_pilots.find(pilot) + direction, _pilots.size())]
	elif id in Cosmetics.SLOTS:
		var options := choices(id)
		var next: String = options[posmod(options.find(selected(id)) + direction, options.size())]
		if not equip(_profile, Cosmetics.owner_for(pilot, id), id, next):
			refresh()
			_notice.text = "Choice kept for this session. Save failed."
			return
	refresh()


func close() -> void:
	hide()
	if _camp != null:
		_camp._lines.show()
		_camp._buttons.show()
		_entry.show()
		if _camp.is_visible_in_tree():
			_entry.grab_focus()
	back_requested.emit()


func handle(event: InputEvent) -> bool:
	if event is InputEventKey:
		if not event.pressed:
			return true
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code in [KEY_W, KEY_UP]:
			_move(-1)
		elif code in [KEY_S, KEY_DOWN]:
			_move(1)
		elif code in [KEY_A, KEY_LEFT]:
			_step(focused_id(), -1)
		elif code in [KEY_D, KEY_RIGHT]:
			_step(focused_id(), 1)
		elif not event.echo and code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			press(focused_id())
		elif not event.echo and code == KEY_ESCAPE:
			close()
		return true
	if event.is_action_pressed("ui_up", true):
		_move(-1)
	elif event.is_action_pressed("ui_down", true):
		_move(1)
	elif event.is_action_pressed("ui_left", true):
		_step(focused_id(), -1)
	elif event.is_action_pressed("ui_right", true):
		_step(focused_id(), 1)
	elif event.is_action_pressed("ui_accept"):
		press(focused_id())
	elif event.is_action_pressed("ui_cancel"):
		close()
	return event is InputEventAction or event is InputEventJoypadButton or event is InputEventJoypadMotion


func _move(direction: int) -> void:
	var index := ORDER.find(focused_id())
	focus(ORDER[0 if index < 0 else posmod(index + direction, ORDER.size())])


func _input(event: InputEvent) -> void:
	if is_visible_in_tree():
		if handle(event):
			get_viewport().set_input_as_handled()
	elif _camp != null and _camp.is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C:
		_open_from_camp()
		get_viewport().set_input_as_handled()
