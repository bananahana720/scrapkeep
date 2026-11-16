extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Intent := preload("res://src/movement/intent.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# The legibility grammar's rows (design-v3/LEGIBILITY.md sections 1 to 3): every colour is one
# of the five roles, words stay short, the live colour stays clear of every other meaning, no
# id is dressed by two tables, and the verb and intent names the rows point at exist.

const MIN_LIVE_DISTANCE := 35.0
const MIN_SLATE_DISTANCE := 35.0
# Slate ink against worn steel, the nearest other meaning on the HUD (the cog and money chip): 11.5 apart today.
const MIN_INK_STEEL_DISTANCE := 10.0
const VOCAB_TABLES := {"LINE_ROWS": EventKinds.LINE_ROWS, "STATE_ROWS": EventKinds.STATE_ROWS,
	"CAUSE_ROWS": EventKinds.CAUSE_ROWS, "ACTIVITY_ROWS": EventKinds.ACTIVITY_ROWS}
const OTHER_TABLES := {"ROWS": EventKinds.ROWS, "UI_ROWS": EventKinds.UI_ROWS, "LOOT_ROWS": EventKinds.LOOT_ROWS,
	"WORLD_ROWS": EventKinds.WORLD_ROWS, "THREAT_ROWS": EventKinds.THREAT_ROWS}
# Older rows may wear the live colour only where it is not a "your verb works" cue on the slice.
const LIVE_ALLOWED := {
	"beacon_charge_changed": "the default table's plating Warden badge; the posture Warden reads neutral",
	"shot_fired": "vfx draws the pilot's own shots in the class colour",
	"special_used": "the pilot's own move, drawn in the class colour",
	"element_resolved": "the arc element's identity; timed events are off on the slice",
	"grapple_fired": "Sable's own move in her class colour; vfx draws it in the pilot's class colour",
	"vault_kicked": "Sable's own move in her class colour",
	"arc_slammed": "Sable's own move in her class colour",
	# 2026-10-11 (w13 coordinator, B3 merged): the ultimate's three live rows are named on purpose. SKILL-BAR.md
	# section 4 "Ready cue: one fact, every layer" makes the rim turn live mint at full, "your verb works now"
	# (LEGIBILITY.md:23), and the set piece in flight and at its peak is that verb working (section 7 rows).
	"ultimate_ready": "the meter's ready cue by design: live mint means the ultimate works now (SKILL-BAR.md section 4)",
	"ultimate_started": "the set piece in flight, the ultimate verb working (SKILL-BAR.md section 7, unit B3)",
	"ultimate_peak": "the set piece's peak, the same verb (SKILL-BAR.md section 7, unit B3)",
}
# Scrap, rewards and rides: the world offering or paying.
const PAYING := {"ROWS": ["scrap_collected", "core_gained", "stage_cleared", "run_ended", "beacon_unsealed", "launched"],
	"UI_ROWS": ["callout_scrap"], "LOOT_ROWS": ["shop_charge", "armor_reclaim"]}


func run(t) -> void:
	var new_rows := VOCAB_TABLES

	var bad_roles: Array = []
	var bad_motions: Array = []
	var long_words: Array = []
	var bad_shapes: Array = []
	for name in new_rows:
		var table: Dictionary = new_rows[name]
		for id in table:
			var row: Dictionary = table[id]
			if not String(row.get("color", "")) in EventKinds.COLOR_ROLES:
				bad_roles.append("%s.%s" % [name, id])
			if row.has("motion") and not String(row["motion"]) in EventKinds.MOTIONS:
				bad_motions.append("%s.%s" % [name, id])
			if _word_count(String(row.get("word", ""))) > EventKinds.MAX_WORDS:
				long_words.append("%s.%s" % [name, id])
			if not String(row.get("shape", "")) in EventKinds.SHAPES:
				bad_shapes.append("%s.%s" % [name, id])
	t.check("every colour role is one of the five meanings or neutral", bad_roles.is_empty(), "rows with another role: %s" % [bad_roles])
	t.check("every motion is a known word", bad_motions.is_empty(), "rows with another motion: %s" % [bad_motions])
	t.check("every word is three words or fewer", long_words.is_empty(), "rows over %d words: %s" % [EventKinds.MAX_WORDS, long_words])
	t.check("every shape is a known shape", bad_shapes.is_empty(), "rows with another shape: %s" % [bad_shapes])

	var live := Palette.live()
	var rivals := {"amber": Palette.AMBER, "rust": Palette.RUST, "hazard": Palette.HAZARD, "slate": Palette.SLATE,
		"ancient blue": Palette.ANCIENT, "sandstone": Palette.SANDSTONE}
	var too_close: Array = []
	for name in rivals:
		var gap := _cie76(live, rivals[name])
		if gap < MIN_LIVE_DISTANCE:
			too_close.append("%s %.1f" % [name, gap])
	t.check("the live colour sits clear of every other meaning", too_close.is_empty(),
		"live is under %.0f CIE76 from: %s" % [MIN_LIVE_DISTANCE, too_close])
	var slate_close: Array = []
	for name in ["amber", "rust", "hazard", "ancient blue", "sandstone"]:
		var gap := _cie76(Palette.SLATE, rivals[name])
		if gap < MIN_SLATE_DISTANCE:
			slate_close.append("%s %.1f" % [name, gap])
	t.check("slate sits clear of the warm colours and the ancients' blue", slate_close.is_empty(),
		"slate is under %.0f CIE76 from: %s" % [MIN_SLATE_DISTANCE, slate_close])
	var ink_close: Array = []
	for name in ["amber", "rust", "hazard", "ancient blue", "sandstone"]:
		var gap := _cie76(Palette.SLATE_INK, rivals[name])
		if gap < MIN_SLATE_DISTANCE:
			ink_close.append("%s %.1f" % [name, gap])
	var steel_gap := _cie76(Palette.SLATE_INK, Palette.STEEL)
	if steel_gap < MIN_INK_STEEL_DISTANCE:
		ink_close.append("steel %.1f" % steel_gap)
	t.check("slate ink sits clear of the warm colours, the ancients' blue and worn steel", ink_close.is_empty(), "slate ink is too close to: %s" % [ink_close])
	t.check("slate ink is slate's own hue, lighter", absf(Palette.SLATE_INK.h - Palette.SLATE.h) < 0.03 and Palette.SLATE_INK.v > Palette.SLATE.v,
		"hue %.3f vs %.3f, value %.2f vs %.2f" % [Palette.SLATE_INK.h, Palette.SLATE.h, Palette.SLATE_INK.v, Palette.SLATE.v])
	var not_mint: Array = []
	for class_def in ClassDef.all():
		var pilot_live: Color = Palette.live(class_def)
		if pilot_live != Color("8bf0d3"):
			not_mint.append("%s is %s" % [class_def.id, pilot_live.to_html(false)])
		for name in rivals:
			if _cie76(pilot_live, rivals[name]) < MIN_LIVE_DISTANCE:
				not_mint.append("%s is close to %s" % [class_def.id, name])
	t.check("the live colour is mint for every pilot", not_mint.is_empty() and ClassDef.all().size() >= 3, "%s" % [not_mint])
	t.check("the live role resolves to the live colour", EventKinds.role_color("live") == live and EventKinds.state_color("open") == live and EventKinds.state_color("chunk_shatter") == live,
		"role %s, open %s, chunk_shatter %s" % [EventKinds.role_color("live").to_html(false), EventKinds.state_color("open").to_html(false), EventKinds.state_color("chunk_shatter").to_html(false)])

	var minted: Array = []
	for name in OTHER_TABLES:
		var table: Dictionary = OTHER_TABLES[name]
		for id in table:
			var row = table[id]
			if row is Dictionary and row.get("color") is Color and (row["color"] as Color).is_equal_approx(live) and not LIVE_ALLOWED.has(id):
				minted.append("%s.%s" % [name, id])
	t.check("no older row wears the live colour unless it is named", minted.is_empty(), "in the live colour: %s" % [minted])
	var not_amber: Array = []
	for name in PAYING:
		for id in PAYING[name]:
			var color: Color = (OTHER_TABLES[name] as Dictionary)[id]["color"]
			if not color.is_equal_approx(Palette.AMBER):
				not_amber.append("%s (%s)" % [id, color.to_html(false)])
	t.check("scrap, rewards and rides wear amber", not_amber.is_empty(), "not amber: %s" % [not_amber])

	var seen := {}
	var twice: Array = []
	var every_table := OTHER_TABLES.duplicate()
	every_table.merge(VOCAB_TABLES)
	for name in every_table:
		var table: Dictionary = every_table[name]
		for id in table:
			if seen.has(id):
				twice.append("%s in %s and %s" % [id, seen[id], name])
			seen[id] = name
	t.check("no id has presentation in two tables", twice.is_empty(), "ids in two tables: %s" % [twice])

	var missing_verbs: Array = []
	for id in EventKinds.LINE_ROWS:
		var verb := String(EventKinds.LINE_ROWS[id]["verb"])
		if verb != EventKinds.NONE and not Bindings.VERBS.has(verb):
			missing_verbs.append("%s names %s" % [id, verb])
	for id in EventKinds.STATE_ROWS:
		var verb := String(EventKinds.STATE_ROWS[id]["verb"])
		if verb != EventKinds.NONE and not Bindings.VERBS.has(verb):
			missing_verbs.append("%s names %s" % [id, verb])
	t.check("every prompt verb id exists in Bindings.VERBS", missing_verbs.is_empty(), "unknown verbs: %s" % [missing_verbs])

	var intent := Intent.new()
	var props := {}
	for info in intent.get_property_list():
		props[info["name"]] = true
	var missing_fields: Array = []
	for id in Bindings.VERBS:
		var row: Dictionary = Bindings.VERBS[id]
		var field := String(row.get("intent", ""))
		if field != "" and not props.has(field):
			missing_fields.append("%s names %s" % [id, field])
		if String(row.get("fail", "")) == "":
			missing_fields.append("%s has no fail cue" % id)
	t.check("every VERBS intent field exists on Intent", missing_fields.is_empty(), "unknown fields: %s" % [missing_fields])
	# 2026-10-11 (w13 coordinator, B1 and B3 merged): nine to eleven. select (caps 1, 2, 3) and ultimate (Q)
	# joined the table and the retired special keeps its row (SKILL-BAR.md section 6; bindings_table_test.gd header).
	# 2026-10-17 (item tiers and actives): the active on F makes twelve.
	t.check("twelve verbs", Bindings.VERBS.size() == 12, "%d verbs" % Bindings.VERBS.size())

	var states: Array = EventKinds.LINE_ROWS.keys()
	states.sort()
	var want_states := ["searching", "locked", "dry_fire", "latched_world", "latched_body", "smash_committed", "smash_lands", "rewinding", "let_go", "broke", "chain_link", "chain_pivot", "chain_end", "chain_miss"]
	want_states.sort()
	t.check("LINE_ROWS holds the ten harpoon states and four chain states", states == want_states, "states: %s" % [states])

	var cause_ids: Array = EventKinds.CAUSE_ROWS.keys()
	cause_ids.sort()
	var kept := ["wrecking_ball", "tesla_pylon", "pinwheel", "shrapnel_bloom", "lightning_rod"]
	kept.sort()
	t.check("CAUSE_ROWS holds the five kept synergies", cause_ids == kept, "ids: %s" % [cause_ids])
	var unknown_synergy: Array = []
	var shapes := {}
	var shared_shape: Array = []
	var bad_motif: Array = []
	for id in EventKinds.CAUSE_ROWS:
		if not Synergies.ROWS.has(id):
			unknown_synergy.append(id)
		var shape := String(EventKinds.CAUSE_ROWS[id]["shape"])
		if shapes.has(shape):
			shared_shape.append("%s and %s share %s" % [id, shapes[shape], shape])
		shapes[shape] = id
		var motif: Array = EventKinds.CAUSE_ROWS[id]["motif"]
		if motif.size() != 3:
			bad_motif.append(id)
	t.check("cause ids are synergy ids", unknown_synergy.is_empty(), "not in synergies.gd: %s" % [unknown_synergy])
	t.check("no two causes share a shape", shared_shape.is_empty(), "%s" % [shared_shape])
	t.check("every cause has a three-note motif", bad_motif.is_empty(), "rows: %s" % [bad_motif])

	var no_glyph: Array = []
	var tag_owner := {}
	var shared_tag_glyph: Array = []
	var effect_clash: Array = []
	var effect_shapes: Array = []
	for id in EventKinds.CAUSE_ROWS:
		effect_shapes.append(String(EventKinds.CAUSE_ROWS[id]["shape"]))
	for id in EventKinds.CAUSE_ROWS:
		if not Synergies.ROWS.has(id):
			continue
		for tag in Synergies.ROWS[id]["tags"]:
			var glyph := EventKinds.tag_glyph(String(tag))
			if glyph == "":
				no_glyph.append("%s of %s" % [tag, id])
				continue
			if tag_owner.has(glyph) and tag_owner[glyph] != tag:
				shared_tag_glyph.append("%s and %s share %s" % [tag, tag_owner[glyph], glyph])
			tag_owner[glyph] = tag
			if glyph in effect_shapes:
				effect_clash.append("%s (%s) equals an effect shape" % [tag, glyph])
	t.check("every tag of every cause has a glyph", no_glyph.is_empty(), "no glyph: %s" % [no_glyph])
	t.check("no two slice tags share a cause glyph", shared_tag_glyph.is_empty(), "%s" % [shared_tag_glyph])
	t.check("no tag glyph equals a row's effect shape", effect_clash.is_empty(), "%s" % [effect_clash])
	var want_vocabulary := {"arc": "bolt", "kinetic": "disc", "mass": "core", "anchor": "bar", "speed": "chevron",
		"spiral": "wave", "split": "diamond", "chain": "square", "frost": "diamond"}
	var vocabulary_ok := true
	for tag in want_vocabulary:
		if EventKinds.tag_glyph(tag) != want_vocabulary[tag]:
			vocabulary_ok = false
	t.check("TAG_GLYPHS holds the coordinator's vocabulary", vocabulary_ok and EventKinds.TAG_GLYPHS.size() == want_vocabulary.size(), "table: %s" % [EventKinds.TAG_GLYPHS])

	var activity_ids: Array = EventKinds.ACTIVITY_ROWS.keys()
	activity_ids.sort()
	t.check("ACTIVITY_ROWS holds the six standing activities", activity_ids == ["ambush_altar", "cracked_cache", "enemy_camp", "hauler_bounty", "hold_the_relay", "surge_run"], "ids: %s" % [activity_ids])

	t.check("harpoon_bit left ROWS", not EventKinds.ROWS.has("harpoon_bit"), "ROWS still holds harpoon_bit")
	t.check("harpoon_smashed left ROWS", not EventKinds.ROWS.has("harpoon_smashed"), "ROWS still holds harpoon_smashed")
	var bite := EventKinds.row("harpoon_bit")
	var smash := EventKinds.row("harpoon_smashed")
	t.check("a bite reads as it did", bite.get("shape") == "diamond" and bite.get("sound") == "line_bite" and bite.get("color") == Palette.ARC and bite.get("priority") == 1 and bite.get("group") == "movement",
		"bite row %s" % [bite])
	t.check("a smash reads as it did", smash.get("shape") == "ring" and smash.get("sound") == "slam_boom" and smash.get("color") == Palette.ARC and smash.get("priority") == 1 and smash.get("group") == "movement",
		"smash row %s" % [smash])

	var missing_posture: Array = []
	for id in ["posture_step", "open", "chunk_shatter"]:
		if not EventKinds.STATE_ROWS.has(id) or EventKinds.ROWS.has(id):
			missing_posture.append(id)
	t.check("the Warden's posture facts are state rows with no amber", missing_posture.is_empty()
			and EventKinds.STATE_ROWS["posture_step"]["color"] == "neutral" and EventKinds.STATE_ROWS["open"]["color"] == "live",
		"not state rows: %s" % [missing_posture])

	var arity := {"line_state_changed": 4, "verb_failed": 3, "cause_armed": 1, "cause_fired": 3, "posture_changed": 3}
	var wrong: Array = []
	for info in (GameEvents as Script).get_script_signal_list():
		if arity.has(info["name"]):
			if info["args"].size() != arity[info["name"]]:
				wrong.append("%s takes %d" % [info["name"], info["args"].size()])
			arity.erase(info["name"])
	t.check("the five grammar signals exist with their arguments", wrong.is_empty() and arity.is_empty(), "wrong %s, missing %s" % [wrong, arity.keys()])
	var unlisted: Array = []
	for name in EventKinds.GRAMMAR_SIGNALS:
		if not EventKinds.ROWS.has(name):
			unlisted.append(name)
	t.check("each unheard grammar signal has its quiet row", unlisted.is_empty(), "no row: %s" % [unlisted])


static func _word_count(text: String) -> int:
	return text.split(" ", false).size()


static func _cie76(a: Color, b: Color) -> float:
	var la := _lab(a)
	var lb := _lab(b)
	return la.distance_to(lb)


static func _lab(c: Color) -> Vector3:
	var r := _linear(c.r)
	var g := _linear(c.g)
	var b := _linear(c.b)
	var x := (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
	var y := r * 0.2126729 + g * 0.7151522 + b * 0.0721750
	var z := (b * 0.9503041 + g * 0.1191920 + r * 0.0193339) / 1.08883
	var fx := _lab_f(x)
	var fy := _lab_f(y)
	var fz := _lab_f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _linear(v: float) -> float:
	return pow((v + 0.055) / 1.055, 2.4) if v > 0.04045 else v / 12.92


static func _lab_f(v: float) -> float:
	return pow(v, 1.0 / 3.0) if v > 0.008856 else 7.787 * v + 16.0 / 116.0
