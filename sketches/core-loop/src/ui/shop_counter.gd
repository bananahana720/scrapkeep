extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const RunState := preload("res://src/core/run_state.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const Icons := preload("res://src/core/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const HeftDial := preload("res://src/ui/heft_dial.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const ShopTile := preload("res://src/ui/shop_tile.gd")
const CompanionPanel := preload("res://src/ui/companion_panel.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Fabricators := preload("res://src/build/fabricators.gd")


signal acted(fact: String, record: Dictionary)
signal pick_wanted
signal leave_wanted

const WIDTH := 700.0
const PAD := 18.0
const GAP := 12
const SHELF_TILE := Vector2(112.0, 124.0)
const HOOK_TILE := Vector2(150.0, 124.0)
const CELL_TILE := Vector2(96.0, 124.0)
const SELL_TILE := Vector2(96.0, 110.0)
const SELL_COLUMNS := 6
const DETAIL_FONT := UiTokens.BODY
const FADE_IN := 0.22
const FADE_OUT := 0.18
const SLIDE := 40.0

var game
var shop
var face := "buy"
var _box: VBoxContainer
var _wallet: HBoxContainer
var _scrap: Control
var _heft
var _faces := {}
var _rows: VBoxContainer
var _detail: Label
var _leave: Button
var _open := false
var _tween: Tween
var _generation := 0
var _rest_x := 0.0
var _frame = _counter_frame()


class ScrapChip extends Control:
	var amount := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(110.0, 34.0)

	func drawn_words() -> PackedStringArray:
		return PackedStringArray([str(amount)])

	func _draw() -> void:
		var mid := size.y * 0.5
		draw_texture_rect(Icons.texture("res_scrap"), Rect2(Vector2(0.0, mid - 12.0), Vector2(24.0, 24.0)), false, Icons.tint("res_scrap", Palette.STEEL))
		UiDraw.text(self, 32.0, mid, str(amount), UiTokens.LABEL, Palette.SAND, true)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_box = VBoxContainer.new()
	_box.position = Vector2(PAD, PAD)
	_box.add_theme_constant_override("separation", GAP)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_wallet = HBoxContainer.new()
	_wallet.add_theme_constant_override("separation", 16)
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_wallet)
	_scrap = ScrapChip.new()
	_wallet.add_child(_scrap)
	_heft = HeftDial.new()
	_wallet.add_child(_heft)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet.add_child(spacer)
	for f in [["buy", "shop_bought", "Buy"], ["stock", "shop_charge", "Belt and terminal"],
			["fab", "shop_rerolled", "Scrapper and press"], ["sell", "shop_sold", "Sell"]]:
		var b := Button.new()
		b.icon = Icons.shape(String(EventKinds.LOOT_ROWS[f[1]]["shape"]))
		b.expand_icon = true
		b.custom_minimum_size = Vector2(UiTokens.TARGET, UiTokens.TARGET)
		b.focus_mode = Control.FOCUS_ALL
		b.toggle_mode = true
		b.accessibility_name = String(f[2])
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_color_override("icon_normal_color", Color(EventKinds.LOOT_ROWS[f[1]]["color"], 0.6))
		b.add_theme_color_override("icon_pressed_color", EventKinds.LOOT_ROWS[f[1]]["color"])
		b.add_theme_color_override("icon_hover_color", UiTokens.TEXT)
		b.add_theme_color_override("icon_focus_color", UiTokens.TEXT)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(state, _face_plate(state, f[0].hash()))
		b.pressed.connect(set_face.bind(f[0]))
		b.mouse_entered.connect(func(): b.grab_focus())
		_wallet.add_child(b)
		_faces[f[0]] = b
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", GAP)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_rows)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(WIDTH - PAD * 2.0, 26.0)
	_detail.add_theme_font_override("font", UiFonts.bold())
	_detail.add_theme_font_size_override("font_size", DETAIL_FONT)
	_detail.add_theme_color_override("font_color", Palette.SAND)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_detail)
	_leave = ChoiceButton.new("leave", "key_esc", "Leave")
	_leave.size_flags_horizontal = Control.SIZE_SHRINK_END
	_leave.pressed.connect(func(): leave_wanted.emit())
	_leave.mouse_entered.connect(func(): _leave.grab_focus())
	_box.add_child(_leave)


func setup(game_ref) -> void:
	game = game_ref


func is_open() -> bool:
	return _open


func open(shop_ref, rest_x: float) -> void:
	shop = shop_ref
	_rest_x = rest_x
	_generation += 1
	_open = true
	visible = true
	face = "buy"
	refresh()
	_set_live(true)
	focus_first()
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	position.x = _rest_x + SLIDE
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:x", _rest_x, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not _open:
		return
	_generation += 1
	_open = false
	_set_live(false)
	var generation := _generation
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position:x", _rest_x + SLIDE, FADE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func():
		if generation == _generation and not _open:
			visible = false)


func focus_first() -> void:
	var first := tiles()
	if _open and not first.is_empty():
		first[0].grab_focus()


func set_face(which: String) -> void:
	face = which
	refresh()
	if _faces.has(which):
		_faces[which].grab_focus()


func tiles() -> Array:
	var out := []
	for row in _rows.get_children():
		for child in row.get_children():
			if child is ShopTile and not child.is_queued_for_deletion():
				out.append(child)
	return out


func tile_for(kind: String, index := 0) -> Control:
	var matching := tiles().filter(func(t): return t.rec.get("kind", "") == kind)
	return matching[index] if index < matching.size() else null


func detail_text() -> String:
	return _detail.text


func leave_button() -> Button:
	return _leave


func face_button(which: String) -> Button:
	return _faces.get(which)


func refresh() -> void:
	if shop == null or game == null:
		return
	var had := _focus_place()
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_scrap.amount = game.run.cogs
	_scrap.queue_redraw()
	var cls: int = game.run.heft_class()
	_heft.set_reading(cls, RunState.HEFT_CLASS_AT.size(), game.run.heft_progress(), RunState.roman(cls), EventKinds.color("heft_class_changed"))
	for f in _faces:
		_faces[f].set_pressed_no_signal(f == face)
	if face == "sell":
		_build_sell()
	elif face == "stock":
		_build_stock()
	elif face == "fab":
		_build_fab()
	else:
		_build_buy()
	_set_live(_open)
	_restore_focus(had)
	_update_detail()
	size = Vector2(WIDTH, _box.get_combined_minimum_size().y + PAD * 2.0)
	queue_redraw()


func _build_buy() -> void:
	var shelf := _row()
	for offer in shop.shelf_offers():
		var state := "sold" if offer["sold"] else ("ok" if offer["affordable"] else "poor")
		_tile(shelf, {"kind": "shelf", "index": offer["index"], "part_id": offer["part_id"], "icon": offer["icon"],
			"rarity": offer["rarity"], "element_icon": offer["element_icon"], "trigger_icon": offer["trigger_icon"],
			"price": offer["price"], "state": state, "headline": offer.get("headline", ""),
			"set_held": offer.get("set_held", 0), "set_pieces": offer.get("set_pieces", 0)}, SHELF_TILE)
	var cost: int = shop.reroll_price()
	_tile(shelf, {"kind": "reroll", "price": cost,
		"state": "spent" if shop.rerolls_left <= 0 else ("ok" if game.run.cogs >= cost else "poor")}, SHELF_TILE)
	var tree = game.player.get("tree") if game.player != null else null
	if tree != null and tree.pending():
		var pair: Array = tree.offered(tree.class_id, tree.path().size() + 1)
		_tile(shelf, {"kind": "pick", "icons": pair.map(func(n): return n["icon"]), "color": _class_color()}, SHELF_TILE)
	var lower := _row()
	var top: Dictionary = shop.top_shelf()
	if not top.is_empty():
		var state := "sold" if top["sold"] else ("locked" if top["locked"] else ("ok" if game.run.cogs >= top["price"] else "poor"))
		var rec := _part_rec("top", top["part_id"], top["price"], state)
		rec["rarity"] = "relic"
		rec["needs_class"] = top["needs_class"]
		rec["heft_class"] = top["heft_class"]
		rec["classes"] = RunState.HEFT_CLASS_AT.size()
		_tile(lower, rec, HOOK_TILE)
	var slots := {}
	for s in (game.player.abilities.slots() if game.player != null else []):
		slots[s["slot"]] = AbilitySlots.normalized(s, game.run.class_def)
	if shop.stow_open():
		var riding: bool = game.run.carried_core > 0
		var unseats: String = game.run.stow_cost()
		var seat := "" if unseats == "" else String(CompanionPanel.PIECE_ICONS.get(unseats, "disc"))
		_tile(lower, {"kind": "stow", "name": "Stow a core in SPIL-9", "price": -1, "seat_icon": seat,
			"color": EventKinds.color("core_gained"), "state": "spent" if riding else ("ok" if game.run.can_stow_core() else "poor")}, CELL_TILE)
	var brew: Dictionary = shop.brew_offer()
	if not brew.is_empty():
		var ult := "ab_%s_ult" % AbilitySlots.pilot_of(game.run.class_def)
		var price := int(brew["price"])
		_tile(lower, {"kind": "brew", "icon": ult, "color": _class_color(), "cells": brew["pours"], "cap": brew["cap"],
			"price": price, "state": "capped" if price < 0 else ("ok" if game.run.cogs >= price else "poor")}, CELL_TILE)
	for offer in shop.charge_offers():
		var slot: Dictionary = slots.get(offer["slot"], {})
		var state := "capped" if not offer["can"] else ("ok" if game.run.cogs >= offer["price"] else "poor")
		_tile(lower, {"kind": "cell", "slot": offer["slot"], "part_id": offer["part_id"], "icon": slot.get("icon", offer["icon"]),
			"key": slot.get("key", ""), "color": _class_color(), "cells": offer["cells"], "cap": offer["cap"],
			"price": offer["price"], "state": state}, CELL_TILE)


func _build_stock() -> void:
	var tri_row := _row()
	for offer in shop.tri_terminal_offers():
		var state := "sold" if bool(offer["sold"]) or bool(offer["closed"]) else ("ok" if bool(offer["affordable"]) else "poor")
		var revealed := bool(offer.get("revealed", true))
		_tile(tri_row, {
			"kind": "tri", "index": offer["index"], "part_id": offer["part_id"], "icon": offer["icon"],
			"rarity": offer["rarity"], "element_icon": offer["element_icon"], "trigger_icon": offer["trigger_icon"],
			"price": offer["price"], "state": state, "revealed": revealed, "headline": offer.get("headline", ""),
			"name": String(offer.get("name", "")) if revealed else "Sealed crate",
		}, SHELF_TILE)
	var belt_row := _row()
	for offer in shop.consumable_offers():
		var state := "sold" if bool(offer["sold"]) else ("capped" if not bool(offer["can_hold"]) else ("ok" if bool(offer["affordable"]) else "poor"))
		var cid := String(offer["consumable_id"])
		var crow := Consumables.row_of(cid)
		_tile(belt_row, {
			"kind": "consumable", "index": offer["index"], "consumable_id": cid,
			"name": String(offer["name"]), "headline": String(crow.get("headline", "")),
			"icon": String(offer["icon"]), "color": offer["color"], "price": int(offer["price"]), "state": state,
		}, CELL_TILE)
	var belt: Dictionary = shop.belt_offer()
	if not belt.is_empty():
		var b_state := "capped" if not bool(belt["can"]) else ("ok" if bool(belt["affordable"]) else "poor")
		_tile(belt_row, {
			"kind": "belt", "name": "Pocket Belt", "icon": "cons_pocket_belt",
			"cells": int(belt["slots"]), "cap": int(belt["max_slots"]),
			"color": Palette.AMBER, "price": int(belt["price"]), "state": b_state,
		}, CELL_TILE)


func _build_fab() -> void:
	var ingots: Dictionary = shop.ingot_counts()
	var ingot_row := _row()
	for spec in [[1, "common", Palette.STEEL], [2, "rare", Palette.COBALT], [3, "relic", Palette.AMBER]]:
		var tier: int = spec[0]
		var count: int = int(ingots.get(tier, 0))
		_tile(ingot_row, {
			"kind": "ingot_readout", "tier": tier, "rarity": spec[1], "count": count,
			"name": "%s ingots" % String(spec[1]).capitalize(), "color": spec[2], "price": -1, "state": "ok" if count > 0 else "poor",
		}, Vector2(96.0, 56.0))
	var scrap_row := _row()
	var seen_scrap := {}
	for part_id in game.run.parts:
		if seen_scrap.has(part_id) or scrap_row.get_child_count() >= SELL_COLUMNS:
			continue
		seen_scrap[part_id] = true
		var can := Fabricators.can_scrap(part_id, game.run)
		var rec := _part_rec("scrap", part_id, -1, "ok" if can else "welded")
		rec["tier"] = Fabricators.tier_of(part_id)
		_tile(scrap_row, rec, SELL_TILE)
	var press_row := _row()
	var seen_press := {}
	for part_id in game.run.parts:
		if seen_press.has(part_id) or press_row.get_child_count() >= SELL_COLUMNS:
			continue
		seen_press[part_id] = true
		var d: Resource = Parts.def(part_id)
		if d == null or Relics.is_relic(part_id) or String(d.rarity) == "relic":
			continue
		var tier := Fabricators.tier_of(part_id)
		var has_ingot: bool = int(ingots.get(tier, 0)) > 0
		var has_spare := false
		for held_id in game.run.parts:
			var sid := String(held_id)
			if sid != part_id and Fabricators.tier_of(sid) == tier and Fabricators.can_scrap(sid, game.run):
				has_spare = true
				break
		var capped := Parts.maxed(part_id, game.run.parts) or Parts.stacked_out(part_id, game.run.parts)
		var st := "capped" if capped else ("ok" if (has_ingot or has_spare) else "poor")
		var rec := _part_rec("press", part_id, -1, st)
		rec["tier"] = tier
		rec["uses_ingot"] = has_ingot
		_tile(press_row, rec, SELL_TILE)


func _build_sell() -> void:
	var row := _row()
	for offer in shop.sell_offers():
		if row.get_child_count() >= SELL_COLUMNS:
			row = _row()
		var quote: int = offer["quote"]
		_tile(row, _part_rec("sell", offer["part_id"], quote, "ok" if quote >= 0 else "welded"), SELL_TILE)
	if shop.scale_open():
		var weigh: Dictionary = shop.weigh_quote()
		if row.get_child_count() >= SELL_COLUMNS:
			row = _row()
		_tile(row, {"kind": "weigh", "name": ("Weigh %d mass for %d cogs" % [weigh["mass"], weigh["cogs"]]) if int(weigh["cogs"]) > 0 else "Weigh", "mass": weigh["mass"],
			"price": weigh["cogs"], "color": EventKinds.color("heft_class_changed"), "state": "ok" if int(weigh["cogs"]) > 0 else "poor"}, SELL_TILE)


func _part_rec(kind: String, part_id: String, price: int, state: String) -> Dictionary:
	var d: Resource = Parts.def(part_id)
	return {"kind": kind, "part_id": part_id, "price": price, "state": state,
		"icon": "cat_" + (d.icon_category if d != null and d.icon_category != "" else "utility"),
		"rarity": d.rarity if d != null else "common",
		"element_icon": "el_" + d.element if d != null and d.element != "" else "",
		"trigger_icon": "trg_" + d.trigger if d != null and d.trigger != "" else ""}


func _class_color() -> Color:
	return ClassDef.screen_color(game.run.class_def.color) if game.run.class_def != null else Palette.SAND


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(row)
	return row


func _tile(row: HBoxContainer, rec: Dictionary, tile_size: Vector2) -> void:
	var tile := ShopTile.new(rec, tile_size)
	tile.pressed.connect(press.bind(tile))
	tile.focus_entered.connect(_update_detail)
	row.add_child(tile)


func press(tile) -> void:
	if not _open or shop == null or not is_instance_valid(tile):
		return
	var rec: Dictionary = tile.rec
	var result := {}
	var fact := ""
	match String(rec.get("kind", "")):
		"shelf":
			result = shop.buy(int(rec["index"]))
			fact = "shop_bought"
		"top":
			result = shop.buy_top()
			fact = "shop_bought"
		"reroll":
			result = shop.reroll()
			fact = "shop_rerolled"
		"cell":
			result = shop.buy_charge(String(rec["slot"]))
			fact = "shop_charge"
		"sell":
			result = shop.sell(String(rec["part_id"]))
			fact = "shop_sold"
		"weigh":
			result = shop.weigh()
			fact = "shop_sold"
		"stow":
			result = shop.stow_core()
			fact = "shop_charge"
		"brew":
			result = shop.buy_brew()
			fact = "shop_charge"
		"tri":
			result = shop.buy_tri_terminal(int(rec["index"]))
			fact = "shop_bought"
		"consumable":
			result = shop.buy_consumable(int(rec["index"]))
			fact = "shop_bought"
		"belt":
			result = shop.buy_belt_slot()
			fact = "shop_bought"
		"scrap":
			result = shop.scrap_to_ingot(String(rec["part_id"]))
			fact = "shop_sold"
		"press":
			result = shop.press_duplicate(String(rec["part_id"]))
			fact = "shop_bought"
		"ingot_readout":
			return
		"pick":
			pick_wanted.emit()
			return
	if result.is_empty():
		return
	if not result.get("ok", false):
		fact = "shop_refused"
	refresh()
	acted.emit(fact, result)


func step_focus(dx: int, dy: int) -> void:
	var grid := _grid()
	if grid.is_empty():
		return
	var at := _focus_place()
	if at.x < 0:
		grid[mini(1, grid.size() - 1)][0].grab_focus()
		return
	if dy != 0:
		var r := clampi(at.x + dy, 0, grid.size() - 1)
		var from: Control = grid[at.x][at.y]
		var best: Control = grid[r][0]
		for c in grid[r]:
			if absf(c.get_global_rect().get_center().x - from.get_global_rect().get_center().x) < absf(best.get_global_rect().get_center().x - from.get_global_rect().get_center().x):
				best = c
		best.grab_focus()
		return
	var row: Array = grid[at.x]
	row[clampi(at.y + dx, 0, row.size() - 1)].grab_focus()


func confirm() -> void:
	var at := _focus_place()
	if at.x < 0:
		return
	var control: Control = _grid()[at.x][at.y]
	if control is ShopTile:
		press(control)
	elif control is BaseButton:
		(control as BaseButton).pressed.emit()


func _grid() -> Array:
	var grid := [_faces.values()]
	for row in _rows.get_children():
		var live := row.get_children().filter(func(c): return c is ShopTile and not c.is_queued_for_deletion())
		if not live.is_empty():
			grid.append(live)
	grid.append([_leave])
	return grid


func _focus_place() -> Vector2i:
	var grid := _grid()
	for r in grid.size():
		for c in grid[r].size():
			if is_instance_valid(grid[r][c]) and grid[r][c].has_focus():
				return Vector2i(r, c)
	return Vector2i(-1, -1)


func _restore_focus(place: Vector2i) -> void:
	if place.x < 0 or not _open:
		return
	var grid := _grid()
	var r := clampi(place.x, 0, grid.size() - 1)
	grid[r][clampi(place.y, 0, grid[r].size() - 1)].grab_focus()


func _update_detail() -> void:
	var at := _focus_place()
	var text := ""
	if at.x >= 0:
		var control = _grid()[at.x][at.y]
		if control is ShopTile:
			text = _tile_detail(control.rec)
	_detail.text = text


func _tile_detail(rec: Dictionary) -> String:
	var kind := String(rec.get("kind", ""))
	match kind:
		"consumable":
			var hl := String(rec.get("headline", "")).replace(": ", ". ")
			return "%s. %s" % [String(rec.get("name", "")), hl]
		"belt":
			return "Pocket Belt. Hold two cartridges at once."
		"tri":
			if not bool(rec.get("revealed", true)):
				return "Sealed crate. Pick one of three and the other two shut."
			return _detail_line(rec)
		"scrap":
			var pname := Parts.display_name(String(rec.get("part_id", "")))
			if String(rec.get("state", "")) == "welded":
				return "%s is welded and cannot be scrapped." % pname
			return "Scrap %s for one matching ingot." % pname
		"press":
			var pname := Parts.display_name(String(rec.get("part_id", "")))
			return "Press a second %s with a matching ingot or spare part." % pname
		"ingot_readout":
			return "%s held %d." % [String(rec.get("name", "Ingots")), int(rec.get("count", 0))]
	if rec.has("part_id"):
		return _detail_line(rec)
	return ""


func _detail_line(rec: Dictionary) -> String:
	var part_id := String(rec["part_id"])
	if Parts.def(part_id) == null:
		return String(rec.get("headline", "")).replace(": ", ". ")
	if String(rec.get("kind", "")) == "shelf":
		return Parts.offer_shop_line(part_id, game.run.parts)
	return Parts.shop_line(part_id)


func _set_live(live: bool) -> void:
	var controls: Array = tiles()
	controls.append_array(_faces.values())
	controls.append(_leave)
	for c in controls:
		(c as BaseButton).disabled = not live
		(c as Control).mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
		if not live and (c as Control).has_focus():
			(c as Control).release_focus()


func _draw() -> void:
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))


static func _face_plate(state: String, serial: int) -> StyleBox:
	var box = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, serial)
	box.content_margin_left = 8.0
	box.content_margin_right = ChoiceButton.PAD * 1.5
	box.content_margin_top = UiTokens.GAP_S
	box.content_margin_bottom = UiTokens.GAP_S
	if state in ["hover", "focus"]:
		box.border_color = Palette.SAND
	if state == "focus":
		box.border_width = 3.0
		box.bg_color = Color(box.bg_color, 0.0)
		box.rivets = false
		box.halftone = false
	return box


static func _counter_frame() -> StyleBox:
	var box = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, 61)
	box.tape = 0.5
	return box
