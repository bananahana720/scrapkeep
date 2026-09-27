extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")

# The four screens outside play: title, class select, death and summary. Each is one
# glance and one key, so starting and restarting take a second (principle 2).

var game

var _veil: ColorRect
var _title: Label
var _body: Label
var _choices: HBoxContainer


func setup(game_ref) -> void:
	game = game_ref
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(Palette.CHARCOAL, 0.84)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	_veil.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 72)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 48)
	box.add_child(_choices)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 26)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_body)
	game.events.flow_changed.connect(_on_flow_changed)


func _on_flow_changed(state: String) -> void:
	for child in _choices.get_children():
		child.queue_free()
	visible = true
	match state:
		"title":
			_show("SCRAPKEEP: FIRST RUN", Palette.AMBER,
				"Space to start\n\n" + FieldNotes.OBJECTIVE + "\nIn play, hold Tab for field notes.")
		"class_select":
			_show("Choose your class", Palette.SAND, "Both classes share the whole mobility kit.")
			var classes: Array = game.flow.classes
			for i in classes.size():
				_choices.add_child(_class_card(i + 1, classes[i]))
		"dead":
			var class_text: String = game.run.class_def.display_name if game.run.class_def != null else ""
			var gap: String = game.flow.gap_line()
			var retry := "R   retry the arena from its entry" if game.flow.in_arena else "R   retry stage %d from its start" % game.run.stage
			var keys := "%s\nN   new run as %s\nC   choose a class" % [retry, class_text]
			if game.flow.can_replay_final_stage():
				keys += "\nT   replay stage %d from its start" % StageDefs.COUNT
			_show("SCRAPPED", EventKinds.color("player_died"), (gap + "\n\n" if gap != "" else "") + keys)
		"victory":
			_show("BRINDLE ROUTED", EventKinds.color("boss_defeated"), "The Requisition is scrap.")
		"summary":
			_show("RUN COMPLETE", EventKinds.color("run_ended"), _summary_text() + "\n\nN   run again as the same class\nSpace   choose a class")
		_:
			visible = false


func body_text() -> String:
	return _body.text


func _show(title: String, color: Color, body: String) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_body.text = body


func _class_card(key: int, def: Resource) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520.0, 280.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.10, 0.95)
	style.border_color = def.color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22.0)
	card.add_theme_stylebox_override("panel", style)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 22)
	text.text = "%d\n%s\n\n%s\n\nweapon: %s\nspecial: %s" % [key, def.display_name, def.pitch,
		def.weapon_id.replace("_", " "), def.special_id.replace("_", " ")]
	text.add_theme_color_override("font_color", def.color)
	card.add_child(text)
	return card


func _summary_text() -> String:
	var s: Dictionary = game.run.summary()
	var minutes := int(s["time"]) / 60
	var seconds := int(s["time"]) % 60
	return "%s  ·  stages %d / %d  ·  time %d:%02d\nscrap %d  ·  parts %d  ·  kills %d  ·  events won %d  ·  retries %d" % [
		s["class"], s["stages"], StageDefs.COUNT, minutes, seconds,
		s["scrap"], (s["parts"] as Array).size(), s["kills"], s["events_won"], s["retries"]]
