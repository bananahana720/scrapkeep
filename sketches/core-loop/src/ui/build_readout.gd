extends Button

const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

var _data := {}
var _popup: PopupPanel
var _rows: VBoxContainer


func _init() -> void:
	name = "BuildReadout"
	text = "Build"
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_open)
	_popup = PopupPanel.new()
	_popup.transparent_bg = true
	add_child(_popup)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Palette.CHARCOAL
	plate.border_color = Palette.SAND
	plate.set_border_width_all(2)
	plate.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", plate)
	_popup.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var close := Button.new()
	close.text = "Close build"
	close.pressed.connect(_popup.hide)
	column.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580.0, 400.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 12)
	scroll.add_child(_rows)


func _open() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("tree") and ancestor.has_method("shop"):
			var game = ancestor.get("game")
			if game != null:
				show_build(game.run.parts)
				_popup.popup_centered()
			return
		ancestor = ancestor.get_parent()


func popup_visible() -> bool:
	return _popup.visible


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func visible_text() -> String:
	return "\n".join(_rows.get_children().map(func(row): return row.text))


func show_build(held: Array) -> void:
	_data = describe(held)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for key in _data["pools"]:
		_line(_data["pools"][key]["text"])
	for row in _data["parts"]:
		_line(row["text"])
	if _data["parts"].is_empty():
		_line("No parts fitted")


func _line(words: String) -> void:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Palette.SAND)
	_rows.add_child(label)


# SG3, comps/gunfire/elements-and-fusion.md:69. Totals come from the same
# sheet and effect fold as combat; the other game's resistance number is not used.
static func describe(held: Array) -> Dictionary:
	var sheet = BuildSheet.from_parts(held)
	var effects = ItemEffects.new(null)
	effects.refresh(held)
	var pools := {}
	for key in sheet.mods:
		_pool(pools, key, "multiplying", sheet.mods[key])
	for key in ["punch", "max_hp_bonus"]:
		_pool(pools, key, "additive", sheet.get(key))
	for key in ["cooldown_scale", "magnet", "kill_scrap"]:
		_pool(pools, key, "multiplying", sheet.get(key))
	for key in sheet.patterns:
		_pool(pools, "pattern." + key, "additive", sheet.patterns[key])
	for key in sheet.dials:
		_pool(pools, "dial." + key, "multiplying", sheet.dials[key])
	for key in effects.charges:
		_pool(pools, "charges." + key, "additive", effects.charges[key])
	for key in effects.cooldown_scale:
		_pool(pools, "cooldown." + key, "multiplying", effects.cooldown_scale[key])
	_pool(pools, "price_scale", "multiplying", effects.price_scale)
	_pool(pools, "hp_per_mass", "additive", effects.hp_per_mass)
	_pool(pools, "vault_cooldown_scale", "multiplying", effects.vault_cooldown_scale)
	_pool(pools, "vault_charges", "additive", effects.vault_charges)
	var counts := {}
	for id in held:
		counts[id] = int(counts.get(id, 0)) + 1
	var rows: Array = []
	var remaining_cap := 1.0
	for id in counts:
		var d = Parts.def(id)
		if d == null:
			continue
		if d.effect.get("do", "") == "damage_reduction":
			remaining_cap *= 1.0 - (d.stack_cap if d.stack_cap > 0.0 else 1.0)
		var n: int = counts[id]
		var cap := _cap(d)
		var effect_key := ItemEffects.stack_key(String(d.effect.get("do", "")))
		var at_cap: bool = d.stack_cap >= 1.0 and n >= int(d.stack_cap) if d.stack_rule in ["linear", "capped"] else false
		if d.stack_rule == "hyperbolic" and effect_key != "" and d.stack_cap > 0.0:
			at_cap = is_equal_approx(ItemEffects.stacked(d, effect_key, n), d.stack_cap)
		if d.stack_rule == "spike":
			at_cap = is_equal_approx(d.stacked(1.0, n), _spike_cap(d))
		var bonuses := _bonuses(d, n)
		var layer_name := "weapon-local" if d.layer == "local" else "player-global"
		var words := "%s x%d · %s · %s%s" % [d.display_name, n, layer_name, cap, " (at cap)" if at_cap else ""]
		if d.layer == "global":
			words += "\nReads: " + ", ".join(d.reads).replace("_", " ")
		words += "\n" + d.text
		for bonus in bonuses:
			words += "\n" + bonus["text"]
		rows.append({"id": id, "copies": n, "layer": d.layer, "reads": d.reads.duplicate(),
			"cap": d.stack_cap, "stack": d.stack_rule, "at_cap": at_cap, "bonuses": bonuses, "text": words})
	_pool(pools, "resistance", "multiplying remaining", effects.damage_reduction, 1.0 - remaining_cap)
	return {"pools": pools, "parts": rows}


static func _pool(out: Dictionary, key: String, pool: String, total: float, cap := -1.0) -> void:
	var percent := key == "resistance" or key.ends_with(".chance") or pool == "multiplying remaining"
	var shown := String.num(total * 100.0, 2) + "%" if percent else String.num(total, 4)
	if pool == "multiplying":
		shown = "x" + shown
	elif pool == "additive" and total >= 0.0:
		shown = "+" + shown
	var limit := String.num(cap * 100.0, 2) + "%" if percent else String.num(cap, 4)
	var words := "%s · %s · total %s · %s" % [key.replace("_", " "), pool, shown,
		"cap " + limit if cap >= 0.0 else "no cap"]
	out[key] = {"pool": pool, "total": total, "cap": cap, "text": words}


static func _cap(d: Resource) -> String:
	if d.stack_rule == "spike":
		return "spike cap %s x one copy" % String.num(_spike_cap(d), 2)
	if d.stack_rule == "hyperbolic":
		return "hyperbolic cap %s%%" % String.num(100.0 * (d.stack_cap if d.stack_cap > 0.0 else 1.0), 2)
	return "%s cap %s copies" % [d.stack_rule, String.num(d.stacked(1.0, int(d.stack_cap)), 0)] if d.stack_cap >= 1.0 else "%s, no copy cap" % d.stack_rule


static func _spike_cap(d: Resource) -> float:
	return d.stacked(1.0, int(PartDef.SPIKE_MAX_MULTIPLE))


static func _sheet_cap(d: Resource, per: float, multiplying: bool) -> float:
	if d.stack_rule == "hyperbolic" or d.stack_cap < 1.0:
		return -1.0
	return pow(per, int(d.stack_cap)) if multiplying else per * int(d.stack_cap)


static func _bonuses(d: Resource, n: int) -> Array:
	var out := {}
	var counted := mini(n, int(d.stack_cap)) if d.stack_rule != "hyperbolic" and d.stack_cap >= 1.0 else n
	for key in d.mods:
		_pool(out, key, "multiplying", pow(float(d.mods[key]), counted), _sheet_cap(d, float(d.mods[key]), true))
	for key in ["punch", "max_hp_bonus"]:
		if d.get(key) != 0.0:
			_pool(out, key, "additive", float(d.get(key)) * counted, _sheet_cap(d, float(d.get(key)), false))
	for key in ["cooldown_scale", "magnet", "kill_scrap"]:
		if d.get(key) != 1.0:
			_pool(out, key, "multiplying", pow(float(d.get(key)), counted), _sheet_cap(d, float(d.get(key)), true))
	for key in d.patterns:
		_pool(out, "pattern." + key, "additive", float(d.patterns[key]) * counted, _sheet_cap(d, float(d.patterns[key]), false))
	for key in d.charges:
		_pool(out, "charges." + key, "additive", d.stacked(float(d.charges[key]), n), _sheet_cap(d, float(d.charges[key]), false))
	var effect_key := ItemEffects.stack_key(String(d.effect.get("do", "")))
	if effect_key != "" and d.effect.has(effect_key):
		var per := float(d.effect[effect_key])
		var pool := "multiplying remaining" if d.effect["do"] in ["damage_reduction", "slot_cooldown", "price_scale", "vault_cooldown"] else "additive"
		var ceiling: float = per * _spike_cap(d) if d.stack_rule == "spike" else d.stack_cap
		if d.stack_rule in ["linear", "capped"] and d.stack_cap >= 1.0:
			ceiling = d.stacked(per, int(d.stack_cap))
		_pool(out, String(d.effect["do"]) + "." + effect_key, pool, ItemEffects.stacked(d, effect_key, n), ceiling if ceiling > 0.0 else -1.0)
	return out.values()
