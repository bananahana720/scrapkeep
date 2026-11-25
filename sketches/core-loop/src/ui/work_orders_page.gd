extends VBoxContainer

const WorkOrders := preload("res://src/core/work_orders.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Parts := preload("res://src/build/parts.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Icons := preload("res://src/ui/icons.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")

# Camp Dispatch Board (W50 Stage D): Work Orders & Repeatable Shift Orders, 7 Maker
# Licenses, and Head Starts + Foreman Override Codes. Four-Hand mixed surface (ruling ek):
# reclaimed Old-Works cast header and Foreman Override plates with the uranium-green seam;
# Keeper riveted cards for pinned clips, Crew/Shift Orders, and Maker License plaques.
# Strictly adheres to Four-Hand ink boundaries and zero slop copy.

signal back_requested

const TABS := ["orders", "licenses", "overrides"]
const TAB_WORDS := {"orders": "Orders", "licenses": "Licenses", "overrides": "Overrides"}
const WIDTH := 980.0
const SCROLL_H := 520.0
const HEADER_SERIAL := 57
const OVERRIDE_SERIAL := 71
const HINT_PARTS := [
	{"cap": "key_q", "say": "Q"},
	{"cap": "key_e", "say": "E"},
	{"say": "tabs"},
	{"cap": "key_enter", "say": "Enter"},
	{"say": "toggle"},
	{"cap": "key_esc", "say": "Esc"},
	{"say": "back"},
]

var back: Button
var active_tab := "orders"
var order_rows := {}
var license_cards := {}
var override_rows := {}
var head_start_rows := {}
var tab_buttons := {}

var _profile
var _sitting := false
var _header_title: Label
var _header_sub: Label
var _pinned_row: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _focus_ring: Array[Control] = []


func _init() -> void:
	name = "WorkOrdersPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UiTokens.GAP_M)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header := PanelContainer.new()
	header.name = "DispatchHeader"
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.custom_minimum_size = Vector2(WIDTH, 0.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cast = ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, HEADER_SERIAL)
	cast.content_margin_left = UiTokens.GAP_L
	cast.content_margin_right = UiTokens.GAP_L
	cast.content_margin_top = UiTokens.GAP_S
	cast.content_margin_bottom = UiTokens.GAP_L
	header.add_theme_stylebox_override("panel", cast)
	add_child(header)

	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", UiTokens.GAP_XS)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(hbox)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", UiTokens.GAP_M)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(top_bar)

	_header_title = _label("SHIFT DISPATCH", UiTokens.LABEL, UiTokens.HANDS[UiTokens.Hand.OLD_WORKS].ink, true)
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_header_title)

	var strip := HBoxContainer.new()
	strip.name = "TabStrip"
	strip.add_theme_constant_override("separation", UiTokens.GAP_S)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(strip)
	for tab_id in TABS:
		var btn := _tab_button(tab_id)
		btn.pressed.connect(func(): show_tab(tab_id))
		strip.add_child(btn)
		tab_buttons[tab_id] = btn

	_header_sub = _label("", UiTokens.BODY, UiTokens.HANDS[UiTokens.Hand.KEEPER].ink)
	_header_sub.add_theme_font_override("font", UiFonts.face(UiTokens.Hand.KEEPER))
	hbox.add_child(_header_sub)

	_pinned_row = HBoxContainer.new()
	_pinned_row.name = "PinnedClips"
	_pinned_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pinned_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pinned_row.custom_minimum_size = Vector2(WIDTH, 0.0)
	_pinned_row.add_theme_constant_override("separation", UiTokens.GAP_M)
	_pinned_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pinned_row)

	var plate := PanelContainer.new()
	plate.name = "BodyPlate"
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plate.custom_minimum_size = Vector2(WIDTH, SCROLL_H)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_box = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, HEADER_SERIAL + 3)
	body_box.set_content_margin_all(UiTokens.GAP_M)
	plate.add_theme_stylebox_override("panel", body_box)
	add_child(plate)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	plate.add_child(_scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UiTokens.GAP_S)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_body)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", UiTokens.GAP_XL)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foot)

	var hints := CreditsHint.new()
	hints.name = "Keys"
	hints.setup(HINT_PARTS)
	foot.add_child(hints)

	back = ChoiceButton.new("back", "key_esc", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): back_requested.emit())
	foot.add_child(back)


func refresh(profile, sitting := false) -> void:
	_profile = profile
	_sitting = sitting
	if _profile != null:
		WorkOrders.ensure_default_pin(_profile)
	_rebuild()


func show_tab(tab_id: String) -> void:
	if not tab_id in TABS:
		return
	active_tab = tab_id
	_rebuild()
	focus_first()


func step_tab(delta: int) -> void:
	var idx := TABS.find(active_tab)
	show_tab(TABS[posmod((0 if idx < 0 else idx) + delta, TABS.size())])


func focus_first() -> void:
	if not is_visible_in_tree():
		return
	if not _focus_ring.is_empty() and is_instance_valid(_focus_ring[0]):
		_focus_ring[0].grab_focus()
	elif is_instance_valid(back):
		back.grab_focus()


func pinned_summary() -> Array[String]:
	var out: Array[String] = []
	for oid in WorkOrders.active_ids(_profile):
		var row: Dictionary = WorkOrders.order(String(oid))
		if not row.is_empty():
			out.append(String(row.get("name", oid)))
	return out


func press_order(order_id: String) -> bool:
	if _profile == null or WorkOrders.order(order_id).is_empty():
		return false
	var active := WorkOrders.active_ids(_profile)
	var changed := false
	if order_id in active:
		changed = WorkOrders.unpin(_profile, order_id)
	else:
		changed = WorkOrders.pin(_profile, order_id, _sitting)
	if changed and _profile.can_save:
		_profile.save()
	var focus_id := order_id
	_rebuild()
	if order_rows.has(focus_id) and is_instance_valid(order_rows[focus_id]):
		order_rows[focus_id].grab_focus()
	return changed


func press_override(code_id: String) -> bool:
	if _profile == null or not MetaOptions.OVERRIDE_CODES.has(code_id):
		return false
	var ok := MetaOptions.toggle_override(_profile, code_id, _sitting)
	if ok and _profile.can_save:
		_profile.save()
	_rebuild()
	if override_rows.has(code_id) and is_instance_valid(override_rows[code_id]):
		override_rows[code_id].grab_focus()
	return ok


func _rebuild() -> void:
	for tab_id in tab_buttons:
		var btn: Button = tab_buttons[tab_id]
		var on: bool = tab_id == active_tab
		btn.add_theme_color_override("font_color", Palette.AMBER if on else Palette.SAND)
		btn.add_theme_color_override("font_hover_color", UiTokens.TEXT)
	_clear(_pinned_row)
	_clear(_body)
	order_rows.clear()
	license_cards.clear()
	override_rows.clear()
	head_start_rows.clear()
	_focus_ring.clear()

	var state: Dictionary = WorkOrders.camp_state(_profile, _sitting)
	var done: int = int(state.get("completed_count", 0))
	var total: int = WorkOrders.CREW_ORDERS.size()
	var active_ov: int = MetaOptions.active_overrides(_profile, false, _sitting).size()
	match active_tab:
		"orders":
			_header_sub.text = "%d of %d crew orders stamped   %d of %d clips pinned" % [done, total, WorkOrders.active_ids(_profile).size(), WorkOrders.MAX_ACTIVE]
			_pinned_row.visible = true
			_build_pinned_strip()
			_build_orders_body()
		"licenses":
			_header_sub.text = "Seven yard makers   Three stamp rungs each"
			_pinned_row.visible = false
			_build_licenses_body()
		"overrides":
			_header_sub.text = "%d of %d override codes armed   %d of %d head starts open" % [active_ov, MetaOptions.OVERRIDE_CODES.size(), MetaOptions.level(_profile), MetaOptions.ids().size()]
			_pinned_row.visible = false
			_build_overrides_body()
	_scroll.scroll_vertical = 0


func _build_pinned_strip() -> void:
	var active := WorkOrders.active_ids(_profile)
	var crew_pin := ""
	var shift_pin := ""
	for oid in active:
		var sid := String(oid)
		if WorkOrders.SHIFT_ORDERS.has(sid):
			shift_pin = sid
		else:
			crew_pin = sid
	_pinned_row.add_child(_clip_card("Crew clip", crew_pin, 11))
	_pinned_row.add_child(_clip_card("Shift clip", shift_pin, 12))


func _clip_card(slot_name: String, order_id: String, serial: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, serial)
	plate.tape = 0.5
	plate.border_color = Palette.AMBER if order_id != "" else UiTokens.LINE
	plate.set_content_margin_all(UiTokens.GAP_S)
	card.add_theme_stylebox_override("panel", plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTokens.GAP_XS)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	if order_id == "":
		col.add_child(_label(slot_name, UiTokens.CAPTION, UiTokens.quiet()))
		col.add_child(_label("Empty clip. Pick one below.", UiTokens.BODY, Palette.SLATE))
		return card
	var row: Dictionary = WorkOrders.order(order_id)
	var who := WorkOrders.issuer_label(order_id, _profile)
	col.add_child(_label("%s   %s" % [slot_name, who], UiTokens.CAPTION, Palette.AMBER))
	col.add_child(_label(String(row.get("name", order_id)), UiTokens.BODY, Palette.LEDGER_CREAM))
	var line := _label(String(row.get("text", "")), UiTokens.CAPTION, Palette.SAND)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	return card


func _build_orders_body() -> void:
	var active := WorkOrders.active_ids(_profile)
	var offers := WorkOrders.shift_offers(_profile, 0, _sitting)
	_body.add_child(_section_heading("Rotating shift orders   Repeatable each run"))
	for oid in offers:
		var sid := String(oid)
		var btn := _order_button(sid, sid in active, false, false)
		_body.add_child(btn)
		order_rows[sid] = btn
		_focus_ring.append(btn)

	_body.add_child(_section_heading("Crew orders"))
	var patch_open: bool = WorkOrders.completed("wo_patch_2", _profile) or (_profile != null and _profile.has_pilot("line_splicer"))
	for raw_oid in WorkOrders.CREW_ORDERS.keys():
		var oid := String(raw_oid)
		var done: bool = WorkOrders.completed(oid, _profile)
		var open: bool = WorkOrders.unlocked(oid, _profile, _sitting)
		if not done and not open and String(WorkOrders.order(oid).get("issuer", "")) == "patch" and not patch_open:
			continue
		var btn := _order_button(oid, oid in active, done, not open and not done)
		_body.add_child(btn)
		order_rows[oid] = btn
		_focus_ring.append(btn)


func _order_button(oid: String, pinned: bool, completed: bool, locked: bool) -> Button:
	var row: Dictionary = WorkOrders.order(oid)
	var who := WorkOrders.issuer_label(oid, _profile)
	var pay := _pay_words(row.get("pays", {}))
	var btn := Button.new()
	btn.name = oid
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_ALL
	btn.disabled = completed or locked
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not btn.disabled else Control.CURSOR_ARROW
	btn.custom_minimum_size = Vector2(WIDTH - 56.0, 56.0)
	var state_word := "Stamped" if completed else ("Pinned" if pinned else ("Locked" if locked else "Pin"))
	var title := String(row.get("name", oid))
	var text := String(row.get("text", ""))
	btn.text = "%s   %s   %s\n%s   %s" % [title, who, state_word, text, pay]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_override("font", UiFonts.bold())
	btn.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	var ink := Palette.AMBER if pinned else (Palette.SAND if not locked and not completed else UiTokens.quiet())
	btn.add_theme_color_override("font_color", ink)
	btn.add_theme_color_override("font_hover_color", UiTokens.TEXT)
	btn.add_theme_color_override("font_focus_color", UiTokens.TEXT)
	btn.add_theme_color_override("font_disabled_color", Palette.AMBER if completed else UiTokens.quiet())
	_dress_row_button(btn, UiTokens.Hand.KEEPER, oid.hash(), Palette.AMBER if pinned or completed else UiTokens.LINE)
	btn.pressed.connect(func(): press_order(oid))
	return btn


func _build_licenses_body() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UiTokens.GAP_M)
	grid.add_theme_constant_override("v_separation", UiTokens.GAP_M)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(grid)
	for maker in WorkOrders.LICENSES:
		var card := _license_card(String(maker))
		grid.add_child(card)
		license_cards[String(maker)] = card
		_focus_ring.append(card)


func _license_card(maker: String) -> PanelContainer:
	var stamps := WorkOrders.license_stamps(maker, _profile)
	var tier := WorkOrders.license_tier(maker, _profile)
	var tier_name := WorkOrders.license_tier_name(tier)
	var card := PanelContainer.new()
	card.name = "License_" + maker
	card.focus_mode = Control.FOCUS_ALL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(440.0, 0.0)
	var plate = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, maker.hash())
	plate.border_color = Palette.AMBER if tier >= 3 else (Palette.COPPER if tier >= 1 else UiTokens.LINE)
	plate.set_content_margin_all(UiTokens.GAP_M)
	card.add_theme_stylebox_override("panel", plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTokens.GAP_XS)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTokens.GAP_S)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var name_lbl := _label(String(MakerSets.SETS.get(maker, {}).get("name", maker.capitalize())), UiTokens.LABEL, Palette.AMBER if tier > 0 else Palette.SAND)
	var plaque := TextureRect.new()
	var plaque_id := "lic_" + maker
	plaque.texture = Icons.texture(plaque_id)
	plaque.modulate = Icons.tint(plaque_id, Palette.AMBER if tier > 0 else Palette.SLATE)
	plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	plaque.custom_minimum_size = Vector2(24.0, 24.0)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(plaque)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_lbl)
	head.add_child(_label(tier_name, UiTokens.BODY, Palette.LEDGER_CREAM if tier > 0 else UiTokens.quiet()))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", UiTokens.GAP_S)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pips)
	for t in range(1, WorkOrders.LICENSE_STAMPS_MAX + 1):
		var hit: bool = stamps >= t
		var icon := TextureRect.new()
		icon.texture = Icons.shape("star" if hit else "ring")
		icon.modulate = Palette.AMBER if hit else Palette.SLATE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(20.0, 20.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(icon)
	pips.add_child(_label("%d of %d stamps" % [mini(stamps, WorkOrders.LICENSE_STAMPS_MAX), WorkOrders.LICENSE_STAMPS_MAX], UiTokens.CAPTION, Palette.SAND))
	var rungs: Dictionary = WorkOrders.LICENSES[maker]
	for t in range(1, WorkOrders.LICENSE_STAMPS_MAX + 1):
		var r: Dictionary = rungs[t]
		var done: bool = tier >= t
		var pay := _pay_words(r.get("pays", {}))
		var line := _label("%s   %s" % [String(r.get("name", "")), pay], UiTokens.CAPTION, Palette.SAND if done else UiTokens.quiet())
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(line)
	return card


func _build_overrides_body() -> void:
	_body.add_child(_section_heading("Foreman override codes   Give and take run rules"))
	var active := MetaOptions.active_overrides(_profile, false, _sitting)
	for cid in MetaOptions.override_ids():
		var row := MetaOptions.override_row(cid)
		var open := MetaOptions.override_open(cid, _profile, _sitting)
		var on: bool = cid in active
		var btn := Button.new()
		btn.name = cid
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_ALL
		btn.disabled = not open
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
		btn.custom_minimum_size = Vector2(WIDTH - 56.0, 62.0)
		var state := "Armed" if on else ("Ready" if open else "Locked")
		var grant := String(row.get("grant", ""))
		var body_line := "%s  Downside %s" % [String(row.get("text", "")), String(row.get("downside_text", ""))]
		if not open:
			body_line = _grant_hint(grant)
		btn.text = "%s   %s\n%s" % [String(row.get("name", cid)), state, body_line]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_override("font", UiFonts.face(UiTokens.Hand.OLD_WORKS))
		btn.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		var works: Dictionary = UiTokens.HANDS[UiTokens.Hand.OLD_WORKS]
		btn.add_theme_color_override("font_color", Palette.AMBER if on else (works.ink if open else works.quiet))
		btn.add_theme_color_override("font_hover_color", UiTokens.TEXT)
		btn.add_theme_color_override("font_focus_color", UiTokens.TEXT)
		btn.add_theme_color_override("font_disabled_color", works.quiet)
		_dress_row_button(btn, UiTokens.Hand.OLD_WORKS, OVERRIDE_SERIAL + cid.hash(), Palette.AMBER if on else works.edge)
		btn.pressed.connect(func(): press_override(cid))
		_body.add_child(btn)
		override_rows[cid] = btn
		_focus_ring.append(btn)

	_body.add_child(_section_heading("Head starts   Earned permanently"))
	for mid in MetaOptions.ids():
		var mrow := MetaOptions.row(mid)
		var open: bool = _profile != null and _profile.has_option(mid)
		var box := HBoxContainer.new()
		box.name = "HeadStart_" + mid
		box.add_theme_constant_override("separation", UiTokens.GAP_S)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var star := TextureRect.new()
		star.texture = Icons.shape("star" if open else "ring")
		star.modulate = Palette.AMBER if open else Palette.SLATE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(22.0, 22.0)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(star)
		var desc := String(mrow.get("text", ""))
		if not open:
			desc = String(Achievements.row(String(mrow.get("grant", ""))).get("text", desc))
		var lbl := _label("%s   %s" % [String(mrow.get("name", mid)), desc], UiTokens.CAPTION, Palette.SAND if open else UiTokens.quiet())
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(lbl)
		_body.add_child(box)
		head_start_rows[mid] = box


func _grant_hint(grant: String) -> String:
	if grant.begins_with("order:"):
		var oid := grant.trim_prefix("order:")
		var orow: Dictionary = WorkOrders.order(oid)
		if not orow.is_empty():
			return "Complete %s to open this code." % String(orow.get("name", oid))
	var arow := Achievements.row(grant)
	if not arow.is_empty():
		return String(arow.get("text", "Locked."))
	return "Locked."


func _pay_words(pays: Dictionary) -> String:
	var out: Array[String] = []
	if pays.has("item"):
		out.append("Opens %s" % Parts.display_name(String(pays["item"])))
	if pays.has("override_code"):
		var ov := MetaOptions.override_row(String(pays["override_code"]))
		out.append("Opens %s" % String(ov.get("name", pays["override_code"])))
	if pays.has("alt_loadout"):
		var alt := MetaOptions.alt_loadout(String(pays["alt_loadout"]))
		out.append("Opens %s" % String(alt.get("name", pays["alt_loadout"])))
	if pays.has("license_stamp"):
		var mk := String(pays["license_stamp"])
		out.append("Stamps %s license" % String(MakerSets.SETS.get(mk, {}).get("name", mk.capitalize())))
	if pays.has("tune"):
		out.append("Presses a record")
	if pays.has("plaque") and out.is_empty():
		out.append("Camp plaque")
	return "   ".join(out)


func _tab_button(tab_id: String) -> Button:
	var btn := Button.new()
	btn.name = "Tab_" + tab_id
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.text = TAB_WORDS[tab_id]
	btn.add_theme_font_override("font", UiFonts.bold())
	btn.add_theme_font_size_override("font_size", UiTokens.BODY)
	btn.custom_minimum_size = Vector2(128.0, UiTokens.TARGET)
	_dress_row_button(btn, UiTokens.Hand.OLD_WORKS, 90 + tab_id.hash(), UiTokens.HANDS[UiTokens.Hand.OLD_WORKS].edge)
	return btn


func _dress_row_button(btn: Button, hand: int, serial: int, edge: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box = ScrapFrame.hand_plate(hand, serial)
		box.content_margin_left = UiTokens.GAP_M
		box.content_margin_right = UiTokens.GAP_M
		box.content_margin_top = UiTokens.GAP_S
		box.content_margin_bottom = UiTokens.GAP_S
		box.border_color = Palette.SAND if state in ["hover", "focus"] else (Palette.AMBER if state == "pressed" else edge)
		box.border_width = 3.0 if state in ["focus", "pressed"] else 2.0
		if state == "focus":
			box.bg_color = Color(box.bg_color, 0.0)
			box.rivets = false
			box.halftone = false
		btn.add_theme_stylebox_override(state, box)


func _section_heading(text: String) -> Label:
	var lbl := _label(text, UiTokens.BODY, Palette.AMBER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return lbl


func _label(text: String, font_size: int, color: Color, mono := false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", UiFonts.face(UiTokens.Hand.OLD_WORKS, mono) if mono else UiFonts.bold())
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _move(direction: int) -> void:
	var controls: Array = _focus_ring + [back]
	if controls.is_empty():
		return
	var index := controls.find(get_viewport().gui_get_focus_owner())
	var next: Control = controls[0 if index < 0 else posmod(index + direction, controls.size())]
	if is_instance_valid(next):
		next.grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		match code:
			KEY_Q:
				step_tab(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_E:
				step_tab(1)
				get_viewport().set_input_as_handled()
				return
			KEY_DOWN, KEY_S:
				_move(1)
				get_viewport().set_input_as_handled()
				return
			KEY_UP, KEY_W:
				_move(-1)
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step_tab(-1)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step_tab(1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_down", true):
		_move(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up", true):
		_move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton and is_ancestor_of(focused) and not (focused as BaseButton).disabled:
			(focused as BaseButton).pressed.emit()
			get_viewport().set_input_as_handled()
