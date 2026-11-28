extends SceneTree

const T := preload("res://tests/support/t.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Roster := preload("res://src/combat/roster.gd")
const Twins := preload("res://src/presentation/sound_twins.gd")
const TwinsTest := preload("res://tests/sound_twins_test.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# The world 1 done read's row "sound-own-recipes" (scripts/world1-bands.rows.json): every world 1 sound
# plays a sound of its own. The world 1 facts come from sound_twins_test.gd's own derivation (universe,
# emit_index, world1), so this file types no list. Each fact's NAMED cue is the one its row asks for: a
# table row's sound_next when it has one, else the cue the fact is heard as. A named cue with no sound of
# its own does not go silent: Rows.heard plays the row's shared `sound` in its place, and a cue named
# with no row behind it (a roster tag, a call site) bakes SfxBank's fallback blip. Each CUE line names
# which, so the list is a work list. A named cue plays its own sound when:
#   a music cue (a park row's music_cue)   MusicRows.CUES composes it
#   any other cue                           SfxBank.plays_own (its recipe, or its recorded file)
# Symbolic ids are judged once per value they resolve to: the class ones per class motif, faction_arrival
# per Roster.FACTIONS faction (and class motif, for the Mind's quote). hold_by_kind is not judged here:
# it resolves to the holding unit's hold or tag, which the roster facts ("roster:<unit>.hold" and
# ".tag", from sound_twins_test's universe) already name for every world 1 unit.
# Prints one CUE line per world 1 named cue, a PLANT line and a SUMMARY line;
# scripts/gate/sound-recipes-receipt.mjs runs this test and turns the output into the receipt.

const PLANT_ID := "plant_recipe_removed"
# The world 1 named cues counted today. A change that adds or drops world 1 cues updates this on purpose.
# Wave 44: 182 -> 197, the three motif cues (gauge, line skill, ultimate peak) are judged once per class motif, 3 -> 18.
# Wave 46 A1: 197 -> 202, own cues for kindness_offered, sluice_warning, sluice_open, quick_sync and shift_over.
# Wave 46 E3-04: 202 -> 219, own cues for 14 pilot cadence facts, 2 Nixie tube rail relay clacks, and site_flip.
const CUES_PINNED := 219
const CLASS_SYMBOLS := ["class_motif", "class_break", "motif_release", "mind_quote", "motif_accumulate", "motif_line", "motif_stinger"]
# Real recipes the plant checks bake something longer than the fallback blip.
const REAL_IDS := ["slam_boom", "found_chime", "threat_whistle"]

var _t := T.new("sound_own_recipes_test")


func _initialize() -> void:
	var facts := TwinsTest.universe(_t, Twins.RELAY)
	var w1 := TwinsTest.world1(_t, facts, TwinsTest.emit_index(_t))
	var named := named_cues(facts, w1)
	_t.check("world 1 facts derived", w1.size() >= 50, str(w1.size()))
	var cues := judge(named)
	var short := cues.keys().filter(func(c): return not cues[c].own)
	for cue in _sorted(cues.keys()):
		var c: Dictionary = cues[cue]
		print("CUE %s" % JSON.stringify({"cue": cue, "own": c.own, "how": c.how, "plays": c.plays, "facts": c.facts.size(), "fact": c.facts[0]}))
	_t.eq("the world 1 named cue count is the pinned one", cues.size(), CUES_PINNED)
	# The plant: one world 1 fact whose cue has a recipe now names an id with no recipe (its recipe removed).
	var victim := ""
	for fact in _sorted(named.keys()):
		var cue := String(named[fact].cue)
		if cues.has(cue) and cues[cue].own and not bool(named[fact].music):
			victim = fact
			break
	var planted := named.duplicate(true)
	planted[victim] = {"cue": PLANT_ID, "music": false, "fallback": ""}
	var after := judge(planted)
	var after_short := after.keys().filter(func(c): return not after[c].own)
	var caught: bool = victim != "" and after.has(PLANT_ID) and not after[PLANT_ID].own and after_short.size() == short.size() + 1
	var blip := int(0.12 * SfxBank.RATE)
	var real_ok := true
	var real_sizes: Array = []
	for id in REAL_IDS:
		var size := SfxBank.samples(id).size()
		real_sizes.append("%s %d" % [id, size])
		real_ok = real_ok and SfxBank.plays_own(id) and size != blip
	var plant_blip := SfxBank.samples(PLANT_ID).size() == blip and not SfxBank.plays_own(PLANT_ID)
	caught = caught and real_ok and plant_blip
	print("PLANT %s" % JSON.stringify({"fact": victim, "cue": PLANT_ID, "before": short.size(), "after": after_short.size(), "real": real_sizes, "caught": caught}))
	_t.check("plant: a world 1 cue with its recipe removed is counted", after_short.size() == short.size() + 1, "%s: %d -> %d" % [victim, short.size(), after_short.size()])
	_t.check("plant: the planted id bakes the fallback blip and plays_own says so", plant_blip, str(SfxBank.samples(PLANT_ID).size()))
	_t.check("plant: real recipes bake something other than the fallback blip", real_ok, ", ".join(real_sizes))
	print("SUMMARY %s" % JSON.stringify({"facts": w1.size(), "cues": cues.size(), "pinned": CUES_PINNED, "short": short.size()}))
	quit(_t.verdict())


# {fact: {cue, music, fallback}} for every world 1 fact: the cue its row names (sound_next first), resolved,
# and what Rows.heard plays when that cue has no sound of its own ("" when no row stands behind it).
static func named_cues(facts: Dictionary, w1: Dictionary) -> Dictionary:
	var tables: Dictionary = (load("res://src/core/event_kinds.gd") as GDScript).get_script_constant_map()
	var out := {}
	for fact in w1:
		var id := String(fact)
		var table := id.get_slice(":", 0)
		var key := id.get_slice(":", 1)
		var wanted := String(facts[fact])
		var row := {}
		if table in TwinsTest.TABLES and tables[table].has(key):
			row = tables[table][key]
			wanted = String(row.get("sound_next", "")) if String(row.get("sound_next", "")) != "" else String(row.get("sound", ""))
		if wanted == "" or wanted == "none" or wanted == "hold_by_kind":
			continue
		for context in _contexts(wanted):
			var cue := Rows.resolve(wanted, context)
			var label := id if context.is_empty() else "%s<%s>" % [id, ",".join(context.values())]
			var fallback := Rows.resolve(String(row.get("sound", "")), context) if not row.is_empty() else ""
			out[label] = {"cue": cue if cue != "" else "%s<%s>" % [wanted, ",".join(context.values())], "music": table == "music", "fallback": fallback}
	return out


# The contexts a named id is judged in: none for a concrete id; each class motif for a class symbol;
# each faction, and each class motif under it, for faction_arrival.
static func _contexts(wanted: String) -> Array:
	var motifs: Array = ClassDef.all().map(func(d): return String(d.motif))
	if wanted in CLASS_SYMBOLS:
		return motifs.map(func(m): return {"motif": m})
	if wanted == "faction_arrival":
		var out: Array = []
		for faction in Roster.FACTIONS:
			for m in motifs:
				out.append({"faction": String(faction), "motif": m})
		return out
	return [{}]


# {cue: {own, how, plays, facts}} over the named cues.
static func judge(named: Dictionary) -> Dictionary:
	var out := {}
	for fact in named:
		var entry: Dictionary = named[fact]
		var cue := String(entry.cue)
		if not out.has(cue):
			out[cue] = _own(cue, bool(entry.music), String(entry.get("fallback", "")))
			out[cue]["facts"] = []
		out[cue].facts.append(fact)
	return out


static func _own(cue: String, music: bool, fallback: String) -> Dictionary:
	if music:
		var has := MusicRows.CUES.has(cue)
		return {"own": has, "how": "music row" if has else "no music row", "plays": cue if has else "nothing"}
	if SfxBank.plays_own(cue):
		return {"own": true, "how": "own sound", "plays": cue}
	if fallback != "" and fallback != cue:
		var shared := fallback if SfxBank.plays_own(fallback) else fallback + " (itself the fallback blip)"
		return {"own": false, "how": "plays its row's shared sound, not a sound of its own", "plays": shared}
	return {"own": false, "how": "no row to fall back to: bakes the fallback blip", "plays": "fallback blip"}


static func _sorted(keys: Array) -> Array:
	var out := keys.duplicate()
	out.sort()
	return out
