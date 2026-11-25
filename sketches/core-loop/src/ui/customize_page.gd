extends Control

const Secrets := preload("res://src/core/secrets.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const CosmeticWear := preload("res://src/core/cosmetic_wear.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CosmeticPresentation := preload("res://src/presentation/cosmetic_presentation.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const WorldGrade := preload("res://src/presentation/world_grade.gd")


signal back_requested

const GROUPS := [
	["BALL", ["paint", "shell", "trail", "decal"]],
	["PILOT", ["outfit"]],
	["SPIL-9", ["companion_paint", "companion_skin"]],
	["BAY", ["bay_decor"]],
]
const SLOT_WORDS := {"paint": "Paint", "shell": "Shell", "trail": "Trail", "decal": "Decal", "outfit": "Outfit",
	"companion_paint": "Paint", "companion_skin": "Skin", "bay_decor": "Decoration"}
const ORDER := ["pilot", "paint", "shell", "trail", "decal", "outfit", "companion_paint", "companion_skin", "bay_decor", "back"]
const HEFT_WORDS := ["I", "II", "III", "IV", "V"]

const PREVIEW_SHARE := 0.55
const MARGIN := 24.0
const HEADER_H := 56.0
const CARD := 132.0
const CARD_GAP := 8.0
const ROW_H := 36.0
const GROUP_H := 20.0
const PORTRAIT := 48.0
const HEFT_H := 64.0
const HOVER_H := 58.0
const SLIDE_SECONDS := 0.22
const SWAP_SECONDS := 0.12
const POP_SECONDS := 0.18
const SHAKE_SECONDS := 0.15
const SHAKE_PX := 3.0
const HOP_SECONDS := 0.25
const CROSSFADE_SECONDS := 0.08
const SEEN_AFTER := 0.6
const STEP_SECONDS := 0.4
const CAM_DISTANCE := 3.6
const CAM_MIN := 3.0
const CAM_MAX := 5.0
const CAM_PITCH := 17.0
const CAM_FOV := 65.0
const SPIN_TURNS := 0.2
const DRAG_DEGREES := 0.5
const SPIN_RESUME := 1.5

var rows := {}
var back: Button
var pilot := "pylon_engineer"
var assets := Cosmetics.asset_paths()
var resolver := Cosmetics.new()
var reduced_motion := false
var slot := "paint"
var trying := {}
var heft_pinned := 1
var seen_saves := 0
var cards: Array = []

var _profile
var _progress
var _pilots: Array = []
var _camp
var _entry: Button
var _game
var _notice: Label
var _title: Label
var _column: VBoxContainer
var _pilot_strip: HBoxContainer
var _portraits := {}
var _slot_list: VBoxContainer
var _group_labels := {}
var _scroll: ScrollContainer
var _grid: GridContainer
var _hover: Label
var _heft_strip: HBoxContainer
var _pips: Array = []
var _backdrop: ColorRect
var _seen_clock := {}
var _seen_dirty := false
var _intro_shown := {}
var _intro_left := -1.0
var _intro_class := 1
var _container: SubViewportContainer
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _painter
var _decal_view
var _ball: Node3D
var _rec := {}
var _look_key := ""
var _distance := CAM_DISTANCE
var _dragging := false
var _spin_wait := 0.0


class Card:
	extends Button
	var id := ""
	var state := "owned"
	var tint := Palette.SAND
	var words := ""

	func _init(card_id: String, card_state: String, card_tint: Color, card_words: String) -> void:
		id = card_id
		state = card_state
		tint = card_tint
		words = card_words
		accessibility_name = card_words
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(132.0, 132.0)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pivot_offset = Vector2(66.0, 66.0)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA)
		plate.border_color = UiTokens.LINE
		plate.set_border_width_all(UiTokens.EDGE)
		plate.set_corner_radius_all(UiTokens.RADIUS)
		add_theme_stylebox_override("normal", plate)
		var lit := plate.duplicate() as StyleBoxFlat
		lit.border_color = Palette.SAND
		add_theme_stylebox_override("hover", lit)
		add_theme_stylebox_override("pressed", lit)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	func caption() -> String:
		return "" if state == "hidden" else words

	func _draw() -> void:
		var s := size
		var swatch := Rect2(Vector2(14.0, 12.0), Vector2(s.x - 28.0, s.y - 52.0))
		var fill := tint
		if state in ["locked", "hidden"]:
			fill = Color.from_hsv(tint.h, tint.s, tint.v * 0.35)
		draw_rect(swatch, fill)
		var font := UiFonts.bold()
		if state == "hidden":
			draw_string(font, swatch.get_center() + Vector2(-9.0, 12.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.HEADING, Palette.SAND)
		elif state == "locked":
			var c := swatch.get_center()
			draw_rect(Rect2(c + Vector2(-10.0, -2.0), Vector2(20.0, 16.0)), Palette.SAND)
			draw_arc(c + Vector2(0.0, -2.0), 7.0, PI, TAU, 10, Palette.SAND, 3.0)
		if state == "worn":
			draw_rect(Rect2(Vector2(3.0, 3.0), s - Vector2(6.0, 6.0)), Palette.COPPER, false, 4.0)
			var c := Vector2(s.x - 24.0, 26.0)
			draw_circle(c, 11.0, Palette.COPPER)
			draw_polyline(PackedVector2Array([c + Vector2(-5.0, 0.0), c + Vector2(-1.0, 4.0), c + Vector2(5.0, -4.0)]), Palette.CHARCOAL, 2.5)
		elif state == "new":
			draw_circle(Vector2(s.x - 16.0, 16.0), 7.0, Palette.ARC)
		draw_string(font, Vector2(10.0, s.y - 14.0), caption(), HORIZONTAL_ALIGNMENT_CENTER, s.x - 20.0, UiTokens.CAPTION, Palette.SAND if state != "locked" else UiTokens.quiet())


func _init() -> void:
	name = "CustomizePage"
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = ColorRect.new()
	_backdrop.color = Color(Palette.CHARCOAL, 0.94)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_title = _label("CUSTOMIZE", UiTokens.HEADING)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_title)
	back = ChoiceButton.new("back", "key_esc", "Back")
	back.pressed.connect(_row_clicked.bind("back"))
	rows["back"] = back
	add_child(back)
	_build_preview()
	_heft_strip = HBoxContainer.new()
	_heft_strip.add_theme_constant_override("separation", 8)
	_heft_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heft_word := _label("HEFT", UiTokens.BODY)
	_heft_strip.add_child(heft_word)
	for i in HEFT_WORDS.size():
		var pip := Button.new()
		pip.text = HEFT_WORDS[i]
		pip.focus_mode = Control.FOCUS_NONE
		pip.toggle_mode = true
		pip.custom_minimum_size = Vector2(UiTokens.TARGET, UiTokens.TARGET)
		pip.add_theme_font_override("font", UiFonts.bold())
		pip.mouse_entered.connect(_hover_heft.bind(i + 1))
		pip.mouse_exited.connect(_hover_heft.bind(0))
		pip.pressed.connect(pin_heft.bind(i + 1))
		_pips.append(pip)
		_heft_strip.add_child(pip)
	add_child(_heft_strip)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 8)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_pilot_strip = HBoxContainer.new()
	_pilot_strip.add_theme_constant_override("separation", 4)
	_pilot_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_pilot_strip)
	var pilot_row := ChoiceButton.new("pilot", "key_enter", "")
	pilot_row.custom_minimum_size = Vector2(168.0, PORTRAIT)
	pilot_row.add_theme_font_size_override("font_size", UiTokens.BODY)
	pilot_row.pressed.connect(_row_clicked.bind("pilot"))
	rows["pilot"] = pilot_row
	_pilot_strip.add_child(pilot_row)
	for def in ClassDef.all():
		var portrait := Button.new()
		portrait.name = "Portrait_" + def.id
		portrait.accessibility_name = String(def.display_name)
		portrait.focus_mode = Control.FOCUS_NONE
		portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
		portrait.mouse_entered.connect(_hover_portrait.bind(def.id))
		portrait.mouse_exited.connect(_hover_clear)
		portrait.pressed.connect(pick_pilot.bind(def.id))
		_portraits[def.id] = portrait
		_pilot_strip.add_child(portrait)
	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 4)
	_slot_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_slot_list)
	for group in GROUPS:
		var heading := _label(group[0], UiTokens.CAPTION)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		heading.add_theme_color_override("font_color", Palette.SANDSTONE)
		_group_labels[group[0]] = heading
		_slot_list.add_child(heading)
		for id in group[1]:
			var row := _slot_row()
			row.pressed.connect(_row_clicked.bind(id))
			row.focus_entered.connect(_select_slot.bind(id))
			row.draw.connect(_draw_row_dot.bind(row, id))
			rows[id] = row
			_slot_list.add_child(row)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_exited.connect(_leave_grid)
	_column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", int(CARD_GAP))
	_grid.add_theme_constant_override("v_separation", int(CARD_GAP))
	_scroll.add_child(_grid)
	_hover = _label("", UiTokens.BODY)
	_hover.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hover.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover.custom_minimum_size = Vector2(0.0, HOVER_H)
	_column.add_child(_hover)
	_notice = _label("", UiTokens.CAPTION)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_column.add_child(_notice)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and not get_viewport().size_changed.is_connected(_on_resize):
		get_viewport().size_changed.connect(_on_resize)
	elif what == NOTIFICATION_PREDELETE:
		if _painter != null:
			_painter.free()
		if _decal_view != null:
			_decal_view.free()


static func attach(camp) -> void:
	var page = load("res://src/ui/customize_page.gd").new()
	page._camp = camp
	page.visible = false
	camp.add_child(page)
	var entry := ChoiceButton.new("customize", "key_c", "Customize")
	entry.name = "CustomizeButton"
	entry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	camp.add_child(entry)
	camp.customize = page
	camp.customize_entry = entry
	page._entry = entry
	entry.pressed.connect(page._open_from_camp)
	camp.visibility_changed.connect(func():
		if not camp.visible and page.visible:
			page.close())


func _slot_row() -> Button:
	var row := Button.new()
	row.focus_mode = Control.FOCUS_ALL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0.0, ROW_H)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_font_override("font", UiFonts.bold())
	row.add_theme_font_size_override("font_size", UiTokens.BODY)
	row.add_theme_color_override("font_color", Palette.SAND)
	row.add_theme_color_override("font_hover_color", UiTokens.TEXT)
	row.add_theme_color_override("font_focus_color", UiTokens.TEXT)
	for pair in [["normal", UiTokens.LINE, 2, true], ["hover", Palette.SAND, 2, true], ["pressed", Palette.AMBER, 3, true], ["focus", Palette.SAND, 4, false]]:
		var box: StyleBoxFlat = ChoiceButton.plate(pair[1], pair[2], 14.0, pair[3])
		box.content_margin_top = 4.0
		box.content_margin_bottom = 4.0
		row.add_theme_stylebox_override(pair[0], box)
	return row


func _label(words: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.SAND)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_preview() -> void:
	_container = SubViewportContainer.new()
	_container.name = "LivePreview"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_container.gui_input.connect(_preview_input)
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.msaa_3d = Viewport.MSAA_4X
	_container.add_child(_viewport)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.CHARCOAL.darkened(0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.SAND
	env.ambient_light_energy = 0.45
	WorldGrade.menu(env, ClassPreview.MENU_EXPOSURE)
	world.environment = env
	_viewport.add_child(world)
	ClassPreview.preview_lights(_viewport, Palette.SAND, false)
	var bench := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = 1.5
	drum.bottom_radius = 1.6
	drum.height = 0.3
	bench.mesh = drum
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Palette.RUST.darkened(0.35)
	wood.roughness = 0.9
	drum.material = wood
	bench.position = Vector3(0.0, -1.15, 0.0)
	_viewport.add_child(bench)
	_pivot = Node3D.new()
	_pivot.name = "Turntable"
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = CAM_FOV
	_viewport.add_child(_camera)
	_place_camera()
	_painter = HeroAssets.previewing()
	_decal_view = CosmeticPresentation.new()


func _place_camera() -> void:
	var pitch := deg_to_rad(CAM_PITCH)
	_camera.position = Vector3(0.0, sin(pitch) * _distance, cos(pitch) * _distance)
	_camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if not event.pressed:
				_spin_wait = SPIN_RESUME
			_stop_intro()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance + (-0.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.2), CAM_MIN, CAM_MAX)
			_place_camera()
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y += deg_to_rad(event.relative.x * DRAG_DEGREES)


func look(for_slot: String) -> String:
	if trying.get("slot", "") == for_slot:
		return String(trying.get("id", ""))
	return selected(for_slot)


func preview_heft() -> int:
	return _intro_class if _intro_left >= 0.0 else heft_pinned


func refresh_preview(animate := true) -> void:
	if _painter == null:
		return
	var def = ClassDef.by_id(pilot)
	if def == null:
		return
	var tints := {"class": def.color}
	var paint_id := look("paint")
	if paint_id != "":
		var tint = _painter.paint_tint(pilot, paint_id)
		if tint != null:
			tints["paint"] = tint
	var shell_id := look("shell")
	var variant := String(Cosmetics.row(shell_id).get("asset", "")) if shell_id != "" else ""
	var key := "%s|%s" % [pilot, variant]
	var moving: bool = animate and not reduced_motion and is_visible_in_tree()
	if key != _look_key or _rec.is_empty():
		var hop: bool = _look_key != "" and not _look_key.begins_with(pilot + "|")
		_decal_view._decal = {}
		if _ball != null:
			_pivot.remove_child(_ball)
			_ball.free()
		_ball = Node3D.new()
		_ball.name = "PreviewBall"
		_pivot.add_child(_ball)
		_rec = _painter.fit_shell_into(_ball, pilot, variant, 1, tints)
		_look_key = key
		if _rec.is_empty():
			return
		var fitted: Dictionary = _painter.fit_pilot_into(_rec.pod, pilot, def.color)
		_rec["pilot"] = fitted.get("pilot")
		if fitted.get("animator") != null:
			fitted.animator.stop()
		_painter.set_heft_class(_rec, preview_heft(), moving)
		if hop and moving and _rec.pilot != null:
			var seat: Vector3 = _rec.pilot.position
			_rec.pilot.position = seat + Vector3(0.0, 0.5, 0.0)
			_rec.pilot.create_tween().tween_property(_rec.pilot, "position", seat, HOP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if not _intro_shown.has(variant) and not reduced_motion and is_visible_in_tree():
			_intro_shown[variant] = true
			_intro_class = 1
			_intro_left = STEP_SECONDS
	else:
		_rec["tints"] = tints
		_painter.paint(_rec.core, tints)
		_painter.paint(_rec.pod, tints)
		if _rec.get("pilot") != null:
			_painter.paint(_rec.pilot, {"class": def.color})
	if _rec.get("pilot") != null:
		_painter.fit_outfit(_rec.pilot, look("outfit"), tints)
	_decal_view._apply_decal(_rec, resolver.resolve(look("decal"), assets) if look("decal") != "" and not Cosmetics.is_pending(look("decal")) else {})
	if reduced_motion and is_visible_in_tree():
		_container.modulate.a = 0.4
		create_tween().tween_property(_container, "modulate:a", 1.0, CROSSFADE_SECONDS)


func preview_rec() -> Dictionary:
	return _rec


func _hover_heft(n: int) -> void:
	if _rec.is_empty():
		return
	_painter.set_heft_class(_rec, n if n > 0 else heft_pinned, not reduced_motion)


func pin_heft(n: int) -> void:
	_stop_intro()
	heft_pinned = clampi(n, 1, 5)
	for i in _pips.size():
		_pips[i].button_pressed = i + 1 == heft_pinned
	if not _rec.is_empty():
		_painter.set_heft_class(_rec, heft_pinned, not reduced_motion)


func _stop_intro() -> void:
	if _intro_left >= 0.0:
		_intro_left = -1.0
		if not _rec.is_empty():
			_painter.set_heft_class(_rec, heft_pinned, false)


func _open_from_camp() -> void:
	var screens = _camp.get_parent().get_parent()
	_game = screens.game
	if _game.get("storage_dir") != null:
		reduced_motion = SettingsStore.new(_game.storage_dir).reduced_motion()
	open(_game.ctx.profile, _game.progress)


func open(profile, progress = null) -> void:
	_profile = profile
	_progress = progress
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
		_camp.page_opened()
	trying = {}
	_seen_dirty = false
	_seen_clock.clear()
	show()
	layout(_screen())
	refresh()
	focus("pilot")
	if is_inside_tree():
		if reduced_motion:
			modulate.a = 0.0
			create_tween().tween_property(self, "modulate:a", 1.0, CROSSFADE_SECONDS)
		else:
			position.x = size.x
			create_tween().tween_property(self, "position:x", 0.0, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
	return CosmeticWear.owns(profile, id)


static func equip(profile, owner: String, slot_id: String, id: String) -> bool:
	if profile == null or not slot_id in Cosmetics.SLOTS or owner == "":
		return false
	if Cosmetics.OWNERS.has(slot_id) != (owner == Cosmetics.OWNERS.get(slot_id, "")):
		return false
	if not Cosmetics.OWNERS.has(slot_id) and ClassDef.by_id(owner) == null:
		return false
	if id != "" and Cosmetics.is_pending(id):
		return false
	if id != "" and (not owns(profile, id) or not Cosmetics.fits(id, owner, slot_id)):
		return false
	profile.equip(owner, slot_id, id)
	profile.add_stat("cos.equip." + slot_id)
	return profile.save()


func shown_ids(slot_id: String) -> Array:
	var out: Array = []
	for id in Cosmetics.for_slot(slot_id, pilot):
		if not Cosmetics.is_pending(id) and not Secrets.shut_paint(id, _profile):
			out.append(id)
	return out


func slot_shown(slot_id: String) -> bool:
	return not shown_ids(slot_id).is_empty()


func order() -> Array:
	var out: Array = []
	for id in ORDER:
		if id in Cosmetics.SLOTS and not slot_shown(id):
			continue
		out.append(id)
	return out


func choices(slot_id: String) -> Array:
	var out: Array = [""]
	for id in shown_ids(slot_id):
		if owns(_profile, id):
			out.append(id)
	return out


func selected(slot_id: String) -> String:
	if _profile == null:
		return ""
	return CosmeticWear.worn(_profile, Cosmetics.owner_for(pilot, slot_id), slot_id)


func effective(slot_id: String) -> Dictionary:
	return resolver.resolve(selected(slot_id), assets)


func is_new(id: String) -> bool:
	return _profile != null and owns(_profile, id) and not Cosmetics.row(id).get("starter", false) and not _profile.is_seen(id)


func slot_has_new(slot_id: String) -> bool:
	for id in shown_ids(slot_id):
		if is_new(id):
			return true
	return false


func refresh() -> void:
	rows["pilot"].text = ClassDef.by_id(pilot).display_name
	for group in GROUPS:
		var any := false
		for id in group[1]:
			var shown := slot_shown(id)
			rows[id].visible = shown
			any = any or shown
			if not shown:
				continue
			var worn := selected(id)
			var words := "Default" if id in ["paint", "companion_paint"] else "None"
			if worn != "":
				words = Cosmetics.row(worn)["name"]
			rows[id].text = "%s   %s" % [SLOT_WORDS[id], words]
			rows[id].queue_redraw()
		_group_labels[group[0]].visible = any
	for def in ClassDef.all():
		var portrait: Button = _portraits[def.id]
		var open_pilot: bool = def.id in _pilots
		portrait.text = def.display_name.substr(0, 1) if open_pilot else "?"
		var ring: Color = ClassDef.screen_color(def.color) if open_pilot else Palette.CABLE
		portrait.add_theme_stylebox_override("normal", _round(ring, def.id == pilot))
		portrait.add_theme_stylebox_override("hover", _round(ring.lightened(0.2), def.id == pilot))
		portrait.add_theme_stylebox_override("pressed", _round(ring, true))
	if not slot_shown(slot):
		slot = "paint"
	_build_cards()
	_notice.text = ""
	refresh_preview()


func _round(fill: Color, ring: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(PORTRAIT * 0.5))
	box.border_color = Palette.COPPER if ring else Color(Palette.SAND, 0.3)
	box.set_border_width_all(3 if ring else 1)
	return box


func _draw_row_dot(row: Button, id: String) -> void:
	if slot_has_new(id):
		row.draw_circle(Vector2(row.size.x - 14.0, row.size.y * 0.5), 5.0, Palette.ARC)


func _build_cards() -> void:
	for card in cards:
		_grid.remove_child(card)
		card.queue_free()
	cards.clear()
	var worn := selected(slot)
	var first := Card.new("", "worn" if worn == "" else "owned", Palette.SLATE, "Default" if slot in ["paint", "companion_paint"] else "None")
	cards.append(first)
	for id in shown_ids(slot):
		var r := Cosmetics.row(id)
		var state := "owned"
		if not owns(_profile, id):
			var grant := Achievements.for_cosmetic(id)
			state = "hidden" if Achievements.row(grant).get("hidden", false) else "locked"
		elif id == worn:
			state = "worn"
		elif is_new(id):
			state = "new"
		cards.append(Card.new(id, state, r.get("tint", Palette.SAND), String(r.get("name", id))))
	for card in cards:
		card.mouse_entered.connect(_hover_card.bind(card))
		card.pressed.connect(click_card.bind(card))
		_grid.add_child(card)


func card_for(id: String) -> Button:
	for card in cards:
		if card.id == id:
			return card
	return null


func hover_text(card) -> String:
	if card.state == "hidden":
		return "Hidden. Keep playing."
	if card.state == "locked":
		var grant := Achievements.for_cosmetic(card.id)
		var g := Achievements.row(grant)
		var line := "%s. %s %s" % [card.words, String(g.get("name", "Locked")) + ":", String(g.get("text", ""))]
		var need := float(g.get("count", 1))
		var have := 0.0
		if _progress != null and _progress.has_method("count_of"):
			have = minf(float(_progress.count_of(grant)), need)
		return "%s  %d / %d" % [line, int(have), int(need)]
	if card.id == "":
		return "%s. The pilot's own look." % card.words
	return "%s." % card.words


func _hover_card(card) -> void:
	_hover.text = hover_text(card)
	if card.state in ["owned", "new", "worn"]:
		trying = {"slot": slot, "id": card.id}
		refresh_preview()


func _leave_grid() -> void:
	if not trying.is_empty():
		trying = {}
		refresh_preview()


func click_card(card) -> bool:
	_stop_intro()
	if card.state in ["locked", "hidden"]:
		_hover.text = hover_text(card)
		if not reduced_motion and card.is_inside_tree():
			var rest: Vector2 = card.position
			var tween: Tween = card.create_tween()
			for dx in [SHAKE_PX, -SHAKE_PX, SHAKE_PX * 0.5, 0.0]:
				tween.tween_property(card, "position:x", rest.x + dx, SHAKE_SECONDS / 4.0)
		return false
	if not equip(_profile, Cosmetics.owner_for(pilot, slot), slot, card.id):
		_notice.text = "Choice kept for this session. Save failed."
		return false
	trying = {}
	if card.id != "" and _profile.mark_seen(card.id):
		_seen_dirty = true
	refresh()
	var worn := card_for(card.id)
	if worn != null and not reduced_motion and worn.is_inside_tree():
		worn.scale = Vector2(0.9, 0.9)
		worn.create_tween().tween_property(worn, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


func _select_slot(id: String) -> void:
	if id == slot or not id in Cosmetics.SLOTS:
		return
	slot = id
	trying = {}
	_seen_clock.clear()
	_build_cards()
	if reduced_motion or not is_inside_tree():
		return
	_grid.modulate.a = 0.0
	create_tween().tween_property(_grid, "modulate:a", 1.0, SWAP_SECONDS)


func _hover_portrait(id: String) -> void:
	if id in _pilots:
		_hover.text = ClassDef.by_id(id).display_name
		return
	var grant := Achievements.for_pilot(id)
	_hover.text = "Locked. %s" % String(Achievements.row(grant).get("text", "Keep playing.")) if grant != "" else "Locked."


func _hover_clear() -> void:
	_hover.text = ""


func pick_pilot(id: String) -> bool:
	if not id in _pilots:
		return false
	pilot = id
	trying = {}
	refresh()
	return true


func focused_id() -> String:
	for id in ORDER:
		if rows[id].has_focus():
			return id
	return ""


func focus(id: String) -> void:
	if is_visible_in_tree() and rows.has(id) and rows[id].visible:
		rows[id].grab_focus()
		_select_slot(id)


func press(id: String) -> void:
	if id == "back":
		close()
	else:
		_step(id, 1)


func _row_clicked(id: String) -> void:
	if id in Cosmetics.SLOTS:
		rows[id].grab_focus()
		_select_slot(id)
	else:
		press(id)


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
		if next != "" and _profile.mark_seen(next):
			_seen_dirty = true
	refresh()


func close() -> void:
	if _seen_dirty and _profile != null and _profile.can_save:
		_profile.save()
		seen_saves += 1
	_seen_dirty = false
	trying = {}
	_intro_left = -1.0
	hide()
	position = Vector2.ZERO
	modulate.a = 1.0
	if _camp != null:
		_camp.page_closed()
		if _camp.is_visible_in_tree() and not _camp.walk:
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
	var list := order()
	var index := list.find(focused_id())
	focus(list[0 if index < 0 else posmod(index + direction, list.size())])


func _input(event: InputEvent) -> void:
	if is_visible_in_tree():
		if event is InputEventMouseButton and event.pressed:
			_stop_intro()
		if handle(event):
			get_viewport().set_input_as_handled()
	elif _camp != null and _camp.is_visible_in_tree() and not _camp.walk and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C:
		_open_from_camp()
		get_viewport().set_input_as_handled()


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


func layout(screen: Vector2) -> void:
	size = screen
	_backdrop.position = Vector2.ZERO
	_backdrop.size = screen
	_title.position = Vector2(MARGIN, 0.0)
	_title.size = Vector2(screen.x * 0.5, HEADER_H)
	back.size = Vector2(160.0, 44.0)
	back.position = Vector2(screen.x - MARGIN - back.size.x, (HEADER_H - back.size.y) * 0.5)
	var left_w := screen.x * PREVIEW_SHARE - MARGIN * 1.5
	_container.position = Vector2(MARGIN, HEADER_H)
	_container.size = Vector2(left_w, screen.y - HEADER_H - HEFT_H - MARGIN)
	_heft_strip.position = Vector2(MARGIN, screen.y - HEFT_H - MARGIN * 0.5)
	_heft_strip.size = Vector2(left_w, HEFT_H)
	var right_x := screen.x * PREVIEW_SHARE + MARGIN * 0.5
	var right_w := screen.x - right_x - MARGIN
	_column.position = Vector2(right_x, HEADER_H)
	_column.size = Vector2(right_w, screen.y - HEADER_H - MARGIN)
	var fit := int((right_w + CARD_GAP) / (CARD + CARD_GAP))
	_grid.columns = clampi(mini(fit, 4 if screen.x >= 1600.0 else 3), 1, 4)
	var pilot_w: float = rows["pilot"].custom_minimum_size.x
	var portrait_w: float = (right_w - pilot_w - 6.0 * 6.0) / 6.0
	for portrait in _portraits.values():
		portrait.custom_minimum_size = Vector2(minf(PORTRAIT, portrait_w), PORTRAIT)


func _on_resize() -> void:
	if visible:
		layout(_screen())


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not reduced_motion and not _dragging and _pivot != null:
		if _spin_wait > 0.0:
			_spin_wait = maxf(0.0, _spin_wait - delta)
		else:
			_pivot.rotation.y += TAU * SPIN_TURNS * delta
	if _intro_left >= 0.0:
		_intro_left -= delta
		if _intro_left < 0.0:
			if _intro_class < 5:
				_intro_class += 1
				_intro_left = STEP_SECONDS
				if not _rec.is_empty():
					_painter.set_heft_class(_rec, _intro_class, true)
			elif not _rec.is_empty():
				_painter.set_heft_class(_rec, heft_pinned, true)
	_age_new_marks(delta)


func _age_new_marks(delta: float) -> void:
	if _profile == null:
		return
	var view := _scroll.get_global_rect()
	var aged := false
	for card in cards:
		if card.state != "new":
			continue
		if not view.intersects(card.get_global_rect()):
			continue
		_seen_clock[card.id] = float(_seen_clock.get(card.id, 0.0)) + delta
		if _seen_clock[card.id] >= SEEN_AFTER and _profile.mark_seen(card.id):
			_seen_dirty = true
			card.state = "owned"
			card.queue_redraw()
			aged = true
	if aged:
		for id in Cosmetics.SLOTS:
			rows[id].queue_redraw()
