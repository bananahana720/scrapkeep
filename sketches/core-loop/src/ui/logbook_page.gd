extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const Icons := preload("res://src/core/icons.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const WorkOrders := preload("res://src/core/work_orders.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")


const STATUS_TEXT := {"none": "", "unencountered": "Unencountered", "new": "New", "available": "Available"}
const TABS := ["entries", "arcs", "pairs", "trail", "foreman"]
const TAB_WORDS := {"entries": "Entries", "arcs": "Crew arcs", "pairs": "Chemistry", "trail": "Wire trail", "foreman": "Foreman"}
const WIDTH := 1020.0
const SERIAL := 81
const CAST_NAMES := {
	"pylon_engineer": "Sable",
	"runner_gunner": "Rivet",
	"demolitions_caster": "Kest",
	"tarn": "Tarn",
	"tally": "Tally",
	"remembered_cannon": "Cannon",
	"moss": "Moss",
	"patch": "Patch",
}
const AXIS_NAMES := {
	"chronic_gambler": "Risk taker",
	"kindness_regular": "Kindness regular",
	"cursed_runner": "Cursed runner",
	"speed_demon": "Fast mover",
	"heavy_roller": "Heavy roller",
	"sig_circuit": "Circuit builder",
	"sig_burst": "Burst builder",
}
const PATCH_TRAIL_ORDER := [
	"patch.rogue.w1", "patch.wire.w1",
	"patch.rogue.w2", "patch.wire.w2",
	"patch.rogue.w3", "patch.wire.w3",
]
const HINT_PARTS := [
	{"cap": "key_q", "say": "Q"},
	{"cap": "key_e", "say": "E"},
	{"say": "tabs"},
	{"cap": "key_enter", "say": "Enter"},
	{"say": "read"},
]

var rows := {}
var arc_rows := {}
var pair_rows := {}
var trail_rows := {}
var tab_buttons := {}
var active_tab := "entries"
var detail: Label
var back: Button

var _list: VBoxContainer
var _scroll: ScrollContainer
var _detail_panel: PanelContainer
var _summary_label: Label
var _codex
var _profile
var _sitting := false
var _pages: Array = []
var _focus_ring: Array[Control] = []


func _init() -> void:
	name = "LogbookPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UiTokens.GAP_M)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_pad := Control.new()
	top_pad.custom_minimum_size.y = UiTokens.GAP_L
	top_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_pad)

	var header := PanelContainer.new()
	header.name = "LogbookHeader"
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.custom_minimum_size = Vector2(WIDTH, 0.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head_plate = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, SERIAL)
	head_plate.tape = 0.5
	head_plate.set_content_margin_all(UiTokens.GAP_M)
	header.add_theme_stylebox_override("panel", head_plate)
	add_child(header)

	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override("separation", UiTokens.GAP_XS)
	hcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(hcol)

	var strip := HBoxContainer.new()
	strip.name = "TabStrip"
	strip.add_theme_constant_override("separation", UiTokens.GAP_S)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hcol.add_child(strip)
	for tab_id in TABS:
		var btn := _tab_button(tab_id)
		btn.pressed.connect(func(): show_tab(tab_id))
		strip.add_child(btn)
		tab_buttons[tab_id] = btn

	_summary_label = _label("", UiTokens.CAPTION, Palette.SAND)
	hcol.add_child(_summary_label)

	var split := HBoxContainer.new()
	split.name = "SplitView"
	split.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.custom_minimum_size = Vector2(WIDTH, 0.0)
	split.add_theme_constant_override("separation", UiTokens.GAP_M)
	split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(split)

	var list_plate := PanelContainer.new()
	list_plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_plate.custom_minimum_size = Vector2(440.0, 0.0)
	list_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lp = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, SERIAL + 1)
	lp.set_content_margin_all(UiTokens.GAP_S)
	list_plate.add_theme_stylebox_override("panel", lp)
	split.add_child(list_plate)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	list_plate.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UiTokens.GAP_S)
	_scroll.add_child(_list)

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "DetailPlate"
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.custom_minimum_size = Vector2(540.0, 0.0)
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_detail_hand(UiTokens.Hand.KEEPER)
	split.add_child(_detail_panel)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_panel.add_child(detail_scroll)

	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size = Vector2(490.0, 0.0)
	detail.add_theme_font_override("font", UiFonts.bold())
	detail.add_theme_font_size_override("font_size", UiTokens.BODY)
	detail.add_theme_color_override("font_color", Palette.SAND)
	detail_scroll.add_child(detail)

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
	foot.add_child(back)

	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size.y = UiTokens.GAP_L
	bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_pad)


func refresh(codex, profile, sitting := false, pages: Array = []) -> void:
	_codex = codex
	_profile = profile
	_sitting = sitting
	_pages = pages
	active_tab = "entries"
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


func open_entry(id: String) -> void:
	if _codex == null or not rows.has(id):
		return
	_codex.open_entry(id, _profile)
	for entry in _codex.entries("", _profile):
		if entry["id"] != id:
			continue
		_read_row(id, entry)
		var words: String = _codex.entry_detail(id, _profile)
		detail.text = "%s\n%s" % [entry["name"], words]
		return


func open_arc(cast_id: String) -> void:
	var card := PilotStory.card_for(cast_id, _profile, _sitting, _codex)
	if card.is_empty():
		return
	var who := _cast_label(cast_id)
	var lines := PackedStringArray()
	var ot := int(card.get("overtime", 0))
	var head := "%s   %d of 5 chapters punched" % [who, int(card.get("punched", 0))]
	if ot > 0:
		head += "   Overtime rung %d" % ot
	lines.append(head)
	lines.append("")
	for ch in card.get("chapters", []):
		var num := int(ch.get("num", 0))
		var mark := "●" if bool(ch.get("punched", false)) else "○"
		if bool(ch.get("punched", false)):
			lines.append("%s Chapter %d   %s" % [mark, num, String(ch.get("title", ""))])
			lines.append(String(ch.get("note", "")))
		else:
			lines.append("%s Chapter %d   Open" % [mark, num])
			var chase := _chapter_chase(ch)
			if chase != "":
				lines.append(chase)
		lines.append("")
	var next_ch: Dictionary = card.get("next_chase", {})
	if not next_ch.is_empty():
		var next_line := _chapter_chase(next_ch)
		if next_line != "":
			lines.append("Next lead   %s" % next_line)
	detail.text = "\n".join(lines).strip_edges()


func open_pair(pair_id: String) -> void:
	var pair: Dictionary = PilotStory.PAIRS.get(pair_id, {})
	if pair.is_empty():
		return
	var known := _known_cb()
	var stage := PilotStory.pair_stage(pair_id, known)
	var names := _pair_title(pair)
	var lines := PackedStringArray()
	lines.append("%s   %d of 3 beats" % [names, stage])
	lines.append("")
	var b1 = pair.get("spark", [])
	if stage >= 1 and b1 is Array:
		lines.append("Beat 1   Camp spark logged")
		for row in b1:
			if row is Dictionary:
				lines.append("%s   %s" % [_speaker_name(String(row.get("speaker", ""))), String(row.get("text", ""))])
	else:
		lines.append("Beat 1   Walk past both pilots in camp.")
	lines.append("")
	if stage >= 2:
		var b2: Dictionary = pair.get("field", {})
		lines.append("Beat 2   Field call logged")
		var variants: Dictionary = b2.get("variants", {})
		for spk in variants:
			var vlist = variants[spk]
			if vlist is Array and not vlist.is_empty():
				lines.append("%s   %s" % [_speaker_name(String(spk)), String(vlist[0])])
	else:
		lines.append("Beat 2   Bring the pair into a run.")
	lines.append("")
	var payoff: Dictionary = pair.get("payoff", {})
	if stage >= 3:
		lines.append("Beat 3   %s" % String(payoff.get("name", "")))
		lines.append(String(payoff.get("codex_text", "")))
		var margin := PilotStory.synthesis_margin("pair." + pair_id + ".3", known)
		if margin != "":
			lines.append(margin.strip_edges())
	else:
		lines.append("Beat 3   Return to camp after a boss clear.")
	detail.text = "\n".join(lines).strip_edges()


func open_trail_node(node_id: String) -> void:
	var row: Dictionary = PilotStory.PATCH_TRAIL.get(node_id, {})
	if row.is_empty():
		return
	var known := _known_cb()
	var found := bool(known.call(node_id))
	var lines := PackedStringArray()
	lines.append("%s   %s" % [String(row.get("name", node_id)), "Logged" if found else "Signal tracked"])
	lines.append("")
	if found:
		lines.append(String(row.get("log", "")))
	else:
		lines.append(String(row.get("hint", "")))
		var clue := String(row.get("clue", ""))
		if clue != "":
			lines.append(clue)
	detail.text = "\n".join(lines).strip_edges()


func _rebuild() -> void:
	for tab_id in tab_buttons:
		var btn: Button = tab_buttons[tab_id]
		var on: bool = tab_id == active_tab
		btn.add_theme_color_override("font_color", Palette.AMBER if on else Palette.SAND)
		btn.add_theme_color_override("font_hover_color", UiTokens.TEXT)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	rows.clear()
	arc_rows.clear()
	pair_rows.clear()
	trail_rows.clear()
	_focus_ring.clear()
	_apply_detail_hand(UiTokens.Hand.OLD_WORKS if active_tab == "foreman" else UiTokens.Hand.KEEPER)

	match active_tab:
		"entries":
			_build_entries()
		"arcs":
			_build_arcs()
		"pairs":
			_build_pairs()
		"trail":
			_build_trail()
		"foreman":
			_build_foreman()
	_scroll.scroll_vertical = 0


func _build_entries() -> void:
	detail.text = "Select an entry to read."
	if _codex == null:
		_summary_label.text = "No codex loaded."
		return
	var listed: Array = _codex.entries("", _profile)
	var known_count := listed.filter(func(e): return bool(e.get("known", false))).size()
	_summary_label.text = "%d of %d field entries logged" % [known_count, listed.size()]
	for entry in listed:
		var id: String = entry["id"]
		var button := _row_button(id)
		_list.add_child(button)
		rows[id] = button
		_focus_ring.append(button)
		_read_row(id, entry)
		button.pressed.connect(func(): open_entry(id))


func _build_arcs() -> void:
	var shown := 0
	var punched_total := 0
	var first_cast := ""
	for cast_id in PilotStory.CAST_ORDER:
		if not PilotStory.card_visible(cast_id, _profile, _sitting, _codex):
			continue
		shown += 1
		var card := PilotStory.card_for(cast_id, _profile, _sitting, _codex)
		var count := int(card.get("punched", 0))
		punched_total += count
		var holes := ""
		for ch in card.get("chapters", []):
			holes += "●" if bool(ch.get("punched", false)) else "○"
		var btn := _row_button("arc_" + cast_id)
		btn.text = "%s   %s" % [_cast_label(cast_id), holes]
		btn.add_theme_color_override("font_color", Palette.AMBER if count >= 5 else Palette.SAND)
		btn.pressed.connect(func(): open_arc(cast_id))
		_list.add_child(btn)
		arc_rows[cast_id] = btn
		_focus_ring.append(btn)
		if first_cast == "":
			first_cast = cast_id
	_summary_label.text = "%d of %d chapters punched across %d time cards" % [punched_total, shown * 5, shown]
	if first_cast != "":
		open_arc(first_cast)
	else:
		detail.text = "No crew cards punched yet."


func _build_pairs() -> void:
	var known := _known_cb()
	var payoffs := 0
	var first_pid := ""
	for pid in PilotStory.pair_ids():
		var pair: Dictionary = PilotStory.PAIRS[pid]
		var stage := PilotStory.pair_stage(pid, known)
		if stage >= 3:
			payoffs += 1
		var pips := ""
		for i in 3:
			pips += "●" if i < stage else "○"
		var btn := _row_button("pair_" + pid)
		btn.text = "%s   %s" % [_pair_title(pair), pips]
		btn.add_theme_color_override("font_color", Palette.AMBER if stage >= 3 else (Palette.SAND if stage > 0 else UiTokens.quiet()))
		btn.pressed.connect(func(): open_pair(pid))
		_list.add_child(btn)
		pair_rows[pid] = btn
		_focus_ring.append(btn)
		if first_pid == "":
			first_pid = pid
	_summary_label.text = "%d of %d pilot pairings completed" % [payoffs, PilotStory.pair_ids().size()]
	if first_pid != "":
		open_pair(first_pid)


func _build_trail() -> void:
	var known := _known_cb()
	var visible_nodes: Array[String] = []
	var logged := 0
	for nid in PATCH_TRAIL_ORDER:
		var is_known := bool(known.call(nid))
		var is_vis := is_known or PilotStory.entry_visible(nid, known)
		if not is_vis:
			continue
		visible_nodes.append(nid)
		if is_known:
			logged += 1
		var row: Dictionary = PilotStory.PATCH_TRAIL[nid]
		var btn := _row_button("trail_" + nid)
		btn.text = "%s   %s" % [String(row.get("name", nid)), "Logged" if is_known else "Open lead"]
		btn.add_theme_color_override("font_color", Palette.AMBER if is_known else Palette.SAND)
		btn.pressed.connect(func(): open_trail_node(nid))
		_list.add_child(btn)
		trail_rows[nid] = btn
		_focus_ring.append(btn)
	var who := "Patch" if _patch_revealed() else "Unsigned"
	_summary_label.text = "%s trail   %d of %d nodes logged" % [who, logged, visible_nodes.size()]
	if visible_nodes.is_empty():
		detail.text = "No unsigned signals logged yet. Watch for rogue machines on the line."
	else:
		open_trail_node(visible_nodes[0])


func _build_foreman() -> void:
	var habits := PilotStory.classify_habits(_profile, _pages)
	var dormant := bool(habits.get("dormant", true))
	var active_axis := String(habits.get("axis", ""))
	var suppressed := bool(habits.get("suppressed", false))
	var scores: Dictionary = habits.get("scores", {})
	var runs := int(habits.get("total_runs", 0))
	_summary_label.text = "Foreman habit audit   %d shifts recorded" % runs
	for axis in PilotStory.FOREMAN_AXIS_ORDER:
		var sc := float(scores.get(axis, 0.0))
		var btn := _row_button("axis_" + axis)
		var tag := "Active" if axis == active_axis else ("Dormant" if dormant else ("Observed" if sc > 0.0 else "Quiet"))
		btn.text = "%s   %s" % [AXIS_NAMES.get(axis, axis.capitalize()), tag]
		btn.disabled = dormant
		btn.add_theme_color_override("font_color", Palette.AMBER if axis == active_axis else UiTokens.HANDS[UiTokens.Hand.OLD_WORKS].ink)
		btn.add_theme_color_override("font_disabled_color", UiTokens.HANDS[UiTokens.Hand.OLD_WORKS].quiet)
		btn.pressed.connect(func(): _show_foreman_axis(axis, habits))
		_list.add_child(btn)
		if not dormant:
			_focus_ring.append(btn)
	if dormant:
		detail.text = "AUDIT DORMANT\nComplete three shifts before the Foreman opens a habit column."
	elif active_axis != "":
		_show_foreman_axis(active_axis, habits)
	elif suppressed:
		detail.text = "AUDIT COOLDOWN\nThe Foreman filed an observation last shift and is holding comment for one cycle."
	else:
		detail.text = "AUDIT NOMINAL\nNo single operating habit leads your record yet."


func _show_foreman_axis(axis: String, habits: Dictionary) -> void:
	if bool(habits.get("dormant", true)):
		detail.text = "AUDIT DORMANT\nComplete three shifts before the Foreman opens a habit column."
		return
	var active_axis := String(habits.get("axis", ""))
	var sc := float(habits.get("scores", {}).get(axis, 0.0))
	var runs := int(habits.get("total_runs", 0))
	var lines := PackedStringArray()
	lines.append(String(AXIS_NAMES.get(axis, axis.capitalize())))
	lines.append("%s   %d shifts recorded" % ["Active habit" if axis == active_axis else ("Observed" if sc > 0.0 else "Quiet"), runs])
	lines.append("")
	if sc <= 0.0 and axis != active_axis:
		lines.append("No observation filed on this habit yet.")
		detail.text = "\n".join(lines)
		return
	var row: Dictionary = PilotStory.FOREMAN_AXES.get(axis, {})
	var stage_memos: Array = row.get("stage_memos", [])
	var loss_memos: Array = row.get("loss_memos", [])
	var crown_lines: Array = row.get("crown_lines", [])
	if not stage_memos.is_empty():
		lines.append(String(stage_memos[0]))
	if not loss_memos.is_empty():
		lines.append(String(loss_memos[0]))
	if not crown_lines.is_empty() and _profile != null and _profile.earned("highdraft_reached"):
		lines.append(String(crown_lines[0]))
	detail.text = "\n".join(lines)


func _patch_revealed() -> bool:
	return WorkOrders.completed("wo_patch_2", _profile) or (_profile != null and _profile.has_pilot("line_splicer"))


func _cast_label(cast_id: String) -> String:
	if cast_id == "patch" and not _patch_revealed():
		return "Unsigned"
	return String(CAST_NAMES.get(cast_id, cast_id.capitalize()))


func _chapter_chase(ch: Dictionary) -> String:
	var wo_id := String(ch.get("work_order", ""))
	if wo_id != "":
		var orow: Dictionary = WorkOrders.order(wo_id)
		if not orow.is_empty():
			return String(orow.get("text", ""))
	for raw in ch.get("accepts", []):
		var token := String(raw)
		if token.begins_with("order:"):
			var orow: Dictionary = WorkOrders.order(token.trim_prefix("order:"))
			if not orow.is_empty():
				return String(orow.get("text", ""))
		elif token.begins_with("codex:"):
			var cid := token.trim_prefix("codex:")
			var trow: Dictionary = PilotStory.PATCH_TRAIL.get(cid, {})
			if not trow.is_empty():
				return String(trow.get("clue", trow.get("hint", "")))
		else:
			var arow: Dictionary = Achievements.row(token)
			if not arow.is_empty():
				return String(arow.get("text", ""))
	return "Earn this chapter in the field."


func _apply_detail_hand(hand: int) -> void:
	var plate = ScrapFrame.hand_plate(hand, SERIAL + 2)
	plate.set_content_margin_all(UiTokens.GAP_L)
	_detail_panel.add_theme_stylebox_override("panel", plate)
	if detail != null:
		detail.add_theme_font_override("font", UiFonts.face(hand))
		detail.add_theme_color_override("font_color", UiTokens.HANDS[hand].ink)


func _known_cb() -> Callable:
	return func(id: String) -> bool:
		return _codex != null and _codex.known(id)


func _pair_title(pair: Dictionary) -> String:
	var pilots: Array = pair.get("pilots", [])
	var names: Array[String] = []
	for pid in pilots:
		var def = ClassDef.by_id(String(pid))
		names.append(String(def.display_name) if def != null else String(CAST_NAMES.get(String(pid), String(pid).capitalize())))
	return " and ".join(names)


func _speaker_name(speaker: String) -> String:
	return String(CAST_NAMES.get(speaker, speaker.capitalize()))


func _read_row(id: String, entry: Dictionary) -> void:
	var status: String = entry["status"]
	var suffix: String = STATUS_TEXT.get(status, "")
	rows[id].text = ("%s   %s" % [entry["name"], suffix]) if suffix != "" else String(entry["name"])
	rows[id].add_theme_color_override("font_color", Palette.AMBER if status == "new" else Palette.SAND if entry["known"] else UiTokens.quiet())


func _row_button(id: String) -> Button:
	var button := Button.new()
	button.name = id
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", UiFonts.bold())
	button.add_theme_font_size_override("font_size", UiTokens.BODY)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, id.hash())
		box.content_margin_left = UiTokens.GAP_M
		box.content_margin_right = UiTokens.GAP_M
		box.content_margin_top = UiTokens.GAP_XS
		box.content_margin_bottom = UiTokens.GAP_XS
		box.border_color = Palette.SAND if state in ["hover", "focus"] else (Palette.AMBER if state == "pressed" else UiTokens.LINE)
		box.border_width = 3.0 if state == "focus" else 1.5
		if state == "focus":
			box.bg_color = Color(box.bg_color, 0.0)
			box.rivets = false
			box.halftone = false
		button.add_theme_stylebox_override(state, box)
	return button


func _tab_button(tab_id: String) -> Button:
	var btn := Button.new()
	btn.name = "Tab_" + tab_id
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.text = TAB_WORDS[tab_id]
	btn.add_theme_font_override("font", UiFonts.bold())
	btn.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	btn.custom_minimum_size = Vector2(106.0, UiTokens.TARGET)
	var plate = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, 110 + tab_id.hash())
	plate.set_content_margin_all(UiTokens.GAP_XS)
	btn.add_theme_stylebox_override("normal", plate)
	return btn


func _label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", UiFonts.bold())
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


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
