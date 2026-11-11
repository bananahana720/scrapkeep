extends VBoxContainer

const Parts := preload("res://src/build/parts.gd")
const Build := preload("res://src/build/build.gd")
const HotwireRules := preload("res://src/build/hotwire_rules.gd")
const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# The look-before-fitting preview for a hot-wired part (BUILD-SYSTEMS.md, Two hot-wired
# parts): two rows, the upside then the downside, each one icon and a few words. The rows
# are built by one function from one style, so neither can weigh more than the other. The
# numbers come from Build and HotwireRules, never from typed text, so a tuning change moves
# the words. The Fit / Recycle transaction is build.gd's (hotwire_fit, hotwire_recycle); this
# shows both consequences and the recycle price before the choice. No cue, no equip. The
# part's "label" sentence says what the two rows already say, so it is not shown anywhere
# (a tooltip repeating the rows was one fact in two places).

const ICON_PX := 40.0
const ROW_H := 48.0
const FONT_PX := 22
const GAP := 12.0

var part_id := ""
var rows: Array[Control] = []


# The part's resolved copy: {"name", "label", "upside": {"icon", "words"}, "downside": {...},
# "recycle": cogs}. {} for an id that is not hot-wired.
static func resolve(id: String) -> Dictionary:
	var row := Parts.hotwired(id)
	if row.is_empty():
		return {}
	# What fitting changes, from the baseline the player is rolling on (build.gd, RIVETED_*).
	var mult: float = Build.RIVETED_ARMOUR
	var steer := int(round((1.0 - Build.RIVETED_AIR_FACTOR) * 100.0))
	var mult_text := _times(mult)
	var wear_text := _times(HotwireRules.WEAR_SCALE)
	var bonus := int(round(HotwireRules.BONUS * 100.0))
	var fill := func(text: String) -> String:
		return text.replace("{armor}", "Double" if is_equal_approx(mult, 2.0) else mult_text + "x") \
			.replace("{armor_x}", mult_text).replace("{steer}", str(steer)) \
			.replace("{wear}", "Double" if is_equal_approx(HotwireRules.WEAR_SCALE, 2.0) else wear_text + "x") \
			.replace("{wear_x}", wear_text).replace("{bonus}", str(bonus))
	return {
		"name": row["name"],
		"label": fill.call(row["label"]),
		"upside": {"icon": row["upside"]["icon"], "words": fill.call(row["upside"]["words"])},
		"downside": {"icon": row["downside"]["icon"], "words": fill.call(row["downside"]["words"])},
		"recycle": Parts.hotwire_recycle(id),
	}


static func _times(value: float) -> String:
	return "%d" % int(value) if is_equal_approx(value, round(value)) else "%.1f" % value


func _init(id := "") -> void:
	part_id = id
	add_theme_constant_override("separation", int(GAP))
	var copy := resolve(id)
	if copy.is_empty():
		return
	rows = [_row(copy["upside"], Palette.BRASS), _row(copy["downside"], Palette.RUST)]
	for row in rows:
		add_child(row)


# One row: the same icon box, the same font and the same height whichever side it is. Only
# the tint differs, at the same alpha, so colour says which side and never how loud.
static func _row(side: Dictionary, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_H)
	row.add_theme_constant_override("separation", int(GAP))
	var icon := TextureRect.new()
	icon.texture = Icons.texture(side["icon"])
	icon.modulate = Icons.tint(side["icon"], tint)
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := Label.new()
	label.text = side["words"]
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", FONT_PX)
	label.add_theme_color_override("font_color", Palette.SAND)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row
