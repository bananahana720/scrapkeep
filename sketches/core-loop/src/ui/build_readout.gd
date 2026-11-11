extends Button

const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Attachments := preload("res://src/build/attachments.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const Icons := preload("res://src/ui/icons.gd")

const PIP := 6.0
const ROW_WORDS := 9

const STAT_WORDS := {
	"ability_charges": "Ability charges", "air_control": "Air steering", "air_jumps": "Air jumps",
	"arm_hit.bonus": "Next hit damage", "bonus_scrap.chance": "Extra scrap chance",
	"brace.share": "Impact protection", "burden_payout.per": "Burden hit bonus", "burst.chance": "Burst chance", "charge_count": "Charge releases",
	"charges.movement": "Movement charges", "charges.smash": "Smash charges",
	"charges.special": "Special charges", "charges.weapon": "Weapon charges",
	"cloak_extend.seconds": "Extra cloak time", "cloak_seconds": "Cloak time",
	"cogs_price": "Cog prices", "cooldown.special": "Special cooldown", "cooldown_scale": "Movement cooldown",
	"cruise": "Cruising speed", "damage_reduction.per": "Damage resistance", "damage_taken": "Incoming damage",
	"dash.speed": "Dash speed", "dash_element": "Dash element", "dash_impulse": "Dash force",
	"dial.shatter_damage": "Shatter damage", "discovery_state": "Discoveries", "domino.chance": "Domino chance",
	"drive_accel": "Acceleration", "drone.chance": "Drone chance", "echo_release.chance": "Echo chance",
	"elapsed_seconds": "Elapsed time", "extra_hit.chance": "Extra hit chance", "glide_gravity": "Glide fall rate",
	"harpoon_lock_deg": "Harpoon lock cone", "heal_back.chance": "Healing chance", "hit_damage": "Hit damage", "hp": "Current health",
	"hp_per_mass": "Health per heft", "hp_per_mass.per": "Health per heft", "impact_force": "Impact force",
	"jump_speed": "Jump speed", "kill_count": "Clocked out", "kill_scrap": "Scrap per machine",
	"last_word.bonus": "Low health hit damage", "magnet": "Scrap pickup reach", "magnet_reach": "Scrap pickup reach",
	"mass": "Heft", "max_hp": "Maximum health", "max_hp_bonus": "Extra maximum health",
	"movement_charges": "Movement charges", "movement_cooldown": "Movement cooldown",
	"overcharge.damage": "Overcharge damage", "part_count": "Fitted parts",
	"pattern.chain_arc": "Chain arcs", "pattern.cross_split": "Cross splits", "pattern.fan_spread": "Fan spreads",
	"pattern.helix_drill": "Helix drills", "pattern.spiral_wave": "Spiral waves",
	"pin_bonus.bonus": "Extra knocked machine damage", "pin_chain.count": "Extra machines knocked on", "pin_count": "Machines knocked on",
	"pin_damage": "Knocked machine damage", "pin_speed": "Knocked machine speed", "planar_speed": "Rolling speed",
	"price_scale": "Shop prices", "price_scale.per": "Shop discount", "proc_coefficient": "Trigger strength",
	"punch": "Added hit damage", "ram_damage": "Ram damage", "rebound_count": "Bounces",
	"rebound_speed": "Bounce speed", "rebound_strike.mult": "Bounce hit damage", "reel_speed": "Reel speed",
	"release_damage": "Release damage", "resistance": "Damage resistance", "return_arc.share": "Returned damage",
	"roll_on_water_element": "Water roll element", "rope_range": "Harpoon reach",
	"scrap_burst.chance": "Scrap burst chance", "scrap_mass": "Heft from scrap", "shot_element": "Shot element",
	"slam_element": "Slam element", "slam_speed": "Slam speed", "slingshot_boost": "Slingshot speed",
	"slingshot_keep": "Slingshot carry", "slot_cooldown.per": "Ability cooldown reduction",
	"smash_charges": "Smash charges", "special_charges": "Special charges", "special_cooldown": "Special cooldown",
	"speed.gain": "Rolling speed gain", "speed_tier": "Speed tier", "target_distance": "Target distance",
	"turret_damage": "Turret damage", "vault_charges": "Vault charges", "vault_charges.count": "Extra vault charges",
	"vault_cooldown": "Vault cooldown", "vault_cooldown.per": "Vault cooldown reduction",
	"vault_cooldown_scale": "Vault cooldown", "vault_count": "Vaults", "weapon_charges": "Weapon charges",
	"weapon_damage": "Weapon damage", "weapon_range": "Weapon reach", "weapon_rate": "Weapon firing rate",
	"zap.chance": "Zap chance",
}

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
	# Back with the Esc keycap, as the other pages do; the button keeps the mouse able to close.
	var close := ChoiceButton.new("back", "key_esc", "Back")
	close.name = "Back"
	close.pressed.connect(_popup.hide)
	column.add_child(close)
	_popup.window_input.connect(close_on_key)
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


# Esc (ui_cancel) closes the popup; returns whether it did.
func close_on_key(event: InputEvent) -> bool:
	if _popup.visible and event.is_action_pressed("ui_cancel"):
		_popup.hide()
		return true
	return false


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func visible_text() -> String:
	return "\n".join(_rows.find_children("*", "Label", true, false).map(func(label): return label.text))


func show_build(held: Array, loadout := {}) -> void:
	_data = describe(held)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if not loadout.is_empty():
		_data["attachments"] = describe_attachments(loadout)
		_line(_data["attachments"])
	for key in _data["pools"]:
		var words: String = _data["pools"][key]["text"]
		if words != "":
			_line(words)
	for row in _data["parts"]:
		_part_row(row)
	if _data["parts"].is_empty():
		_line("No parts fitted")


func _line(words: String) -> void:
	_rows.add_child(_label(words))


func _label(words: String) -> Label:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Palette.SAND)
	return label


# One part as one row: its icon, its words, and pips where the part has a copy cap.
func _part_row(row: Dictionary) -> void:
	var box := HBoxContainer.new()
	box.name = "Part_" + String(row["id"])
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(box)
	var icon_id := Parts.icon_of(String(row["id"]))
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_id)
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Icons.tint(icon_id, Palette.SAND)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.add_child(_label(row["text"]))
	if not row["pips"].is_empty():
		var pips := PipRow.new(int(row["pips"]["filled"]), int(row["pips"]["total"]))
		pips.name = "Pips"
		box.add_child(pips)
		# Copies past the cap: the full row, then how many more are held.
		if int(row["over"]) > 0:
			var extra := _label("+%d" % int(row["over"]))
			extra.name = "Over"
			extra.size_flags_horizontal = Control.SIZE_SHRINK_END
			extra.add_theme_font_size_override("font_size", 14)
			box.add_child(extra)
	elif row["at_cap"]:
		# A part with no copy count that has reached its ceiling: one filled pip, the full-row look.
		var mark := PipRow.new(1, 1)
		mark.name = "CapMark"
		box.add_child(mark)


# Filled and empty round pips: how many copies are held out of how many count.
class PipRow extends Control:
	var filled := 0
	var total := 0

	func _init(held := 0, cap := 0) -> void:
		filled = held
		total = cap
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		custom_minimum_size = Vector2(total * PIP * 2.6, PIP * 2.0)

	func _draw() -> void:
		for i in total:
			var at := Vector2(PIP * 1.3 + i * PIP * 2.6, PIP)
			if i < filled:
				draw_circle(at, PIP, Palette.SAND)
			else:
				draw_arc(at, PIP - 1.0, 0.0, TAU, 20, Palette.SAND, 1.5)


# SQ11: the weapon's attachments in words. How many it holds out of its most, each fitted
# attachment, and at the top tier the second mode.
static func describe_attachments(loadout: Dictionary) -> String:
	var tier := int(loadout.get("tier", 1))
	var limits: Array = Attachments.TIER_COUNT[tier]
	var held: Array = loadout.get("attachments", [])
	var words := "%s: %d of %d attachments" % [_weapon_words(String(loadout.get("weapon", ""))), held.size(), int(limits[1])]
	for id in held:
		var row: Dictionary = Attachments.ROWS.get(id, {})
		words += "\n%s: %s" % [row.get("name", id), row.get("text", "")]
	var mode: Dictionary = Attachments.second_mode(loadout)
	if not mode.is_empty():
		words += "\nSecond mode is %s, %s" % [mode["name"], mode["text"]]
	return words


# What a tier gives a weapon, shown before anything is equipped.
static func preview_tier(weapon_id: String, tier: int) -> String:
	var limits: Array = Attachments.TIER_COUNT[clampi(tier, 1, Attachments.TOP_TIER)]
	var words := "%s %s holds %s attachments" % [_weapon_words(weapon_id), Attachments.TIER_WORDS[clampi(tier, 1, Attachments.TOP_TIER)], _range_words(limits)]
	var mode: Dictionary = Attachments.second_mode(Attachments.empty(weapon_id, tier))
	if not mode.is_empty():
		words += "\nSecond mode is %s, %s" % [mode["name"], mode["text"]]
	return words


static func _range_words(limits: Array) -> String:
	return str(limits[0]) if int(limits[0]) == int(limits[1]) else "%d to %d" % [int(limits[0]), int(limits[1])]


static func _weapon_words(weapon_id: String) -> String:
	return weapon_id.capitalize()


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
		# SG15: a levelled part reads as its held level's numbers, once.
		var levelled: bool = not d.levels.is_empty()
		if levelled:
			d = Parts.def_at(id, Parts.level_of(id, held))
		if d.effect.get("do", "") == "damage_reduction":
			remaining_cap *= 1.0 - (d.stack_cap if d.stack_cap > 0.0 else 1.0)
		var n: int = counts[id]
		var effect_key := ItemEffects.stack_key(String(d.effect.get("do", "")))
		var at_cap: bool = d.stack_cap >= 1.0 and n >= int(d.stack_cap) if d.stack_rule in ["linear", "capped"] else false
		if d.stack_rule == "hyperbolic" and effect_key != "" and d.stack_cap > 0.0:
			at_cap = is_equal_approx(ItemEffects.stacked(d, effect_key, n), d.stack_cap)
		if d.stack_rule == "spike":
			at_cap = is_equal_approx(d.stacked(1.0, n), _spike_cap(d))
		var bonuses := _level_bonuses(d, id) if levelled else _bonuses(d, n)
		var pips := {}
		if d.stack_rule in ["linear", "capped"] and d.stack_cap >= 1.0:
			pips = {"filled": mini(n, int(d.stack_cap)), "total": int(d.stack_cap)}
		rows.append({"id": id, "copies": n, "layer": d.layer, "reads": d.reads.duplicate(), "icon": d.icon_category,
			"cap": d.stack_cap, "stack": d.stack_rule, "at_cap": at_cap, "pips": pips,
			"over": maxi(0, n - int(pips["total"])) if not pips.is_empty() else 0, "bonuses": bonuses,
			"text": _part_words(d, n if pips.is_empty() else 1, bonuses)})
	_pool(pools, "resistance", "multiplying remaining", effects.damage_reduction, 1.0 - remaining_cap)
	return {"pools": pools, "parts": rows}


# A pool row says only what changed, as the stat and its signed change ("Weapon damage +12%").
static func _pool(out: Dictionary, key: String, pool: String, total: float, cap := -1.0) -> void:
	var neutral := 1.0 if pool == "multiplying" else 0.0
	var change := "" if is_equal_approx(total, neutral) else _change(key, pool, total)
	out[key] = {"key": key, "pool": pool, "total": total, "cap": cap, "change": change,
		"text": "" if change == "" else "%s %s" % [_stat_words(key), change]}


# The player's number for a total: a multiplier reads as its percent change, a share as a percent.
static func _change(key: String, pool: String, total: float) -> String:
	if pool == "multiplying":
		return _signed((total - 1.0) * 100.0, "%")
	if key == "resistance" or key.ends_with(".chance") or pool == "multiplying remaining":
		return _signed(total * 100.0, "%")
	return _signed(total, "")


static func _signed(value: float, unit: String) -> String:
	var shown := "%.1f" % value if unit == "%" else "%.2f" % value
	while "." in shown and (shown.ends_with("0") or shown.ends_with(".")):
		shown = shown.left(-1)
	if shown == "-0":
		shown = "0"
	return ("+" if value >= 0.0 else "") + shown + unit


# One part, one plain row: its name, a count when above one and no pips carry it, then
# what it gives, kept within ROW_WORDS words. A part with no number says its own line.
static func _part_words(d: Resource, copies: int, bonuses: Array) -> String:
	var head: String = d.display_name if copies <= 1 else "%s x%d" % [d.display_name, copies]
	var given: Array = []
	for bonus in bonuses:
		if bonus["change"] == "":
			continue
		var stat := _stat_words(bonus["key"])
		var phrase := "%s %s" % [bonus["change"], stat.substr(0, 1).to_lower() + stat.substr(1)]
		var candidate := head + ": " + ", ".join(given + [phrase])
		if not given.is_empty() and candidate.split(" ", false).size() > ROW_WORDS:
			break
		given.append(phrase)
	if given.is_empty():
		var own := "%s: %s" % [head, d.text]
		if own.split(" ", false).size() > ROW_WORDS and d.verb != "":
			own = "%s: %s" % [head, d.verb]
		return own
	return head + ": " + ", ".join(given)


static func _stat_words(key: String) -> String:
	if not STAT_WORDS.has(key):
		push_error("BuildReadout.STAT_WORDS missing key: %s" % key)
		return "Unknown stat"
	return STAT_WORDS[key]


static func _spike_cap(d: Resource) -> float:
	return d.stacked(1.0, int(PartDef.SPIKE_MAX_MULTIPLE))


static func _sheet_cap(d: Resource, per: float, multiplying: bool) -> float:
	if d.stack_rule == "hyperbolic" or d.stack_cap < 1.0:
		return -1.0
	return pow(per, int(d.stack_cap)) if multiplying else per * int(d.stack_cap)


# A levelled part's held level, folded once, against its top level's numbers as the cap.
static func _level_bonuses(d: Resource, id: String) -> Array:
	var top: Resource = Parts.def_at(id, PartDef.MAX_LEVEL)
	var out := {}
	for key in d.mods:
		_pool(out, key, "multiplying", float(d.mods[key]), float(top.mods.get(key, d.mods[key])))
	for key in ["punch", "max_hp_bonus"]:
		if d.get(key) != 0.0:
			_pool(out, key, "additive", float(d.get(key)), float(top.get(key)))
	for key in ["cooldown_scale", "magnet", "kill_scrap"]:
		if d.get(key) != 1.0:
			_pool(out, key, "multiplying", float(d.get(key)), float(top.get(key)))
	return out.values()


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
