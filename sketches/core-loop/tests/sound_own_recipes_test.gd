extends SceneTree

const T := preload("res://tests/support/t.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Twins := preload("res://src/presentation/sound_twins.gd")
const TwinsTest := preload("res://tests/sound_twins_test.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# The world 1 done read's row "sound-own-recipes" (scripts/world1-bands.rows.json): no world 1 sound
# plays a stand-in. The world 1 facts come from sound_twins_test.gd's own derivation (universe,
# emit_index, world1), so this file types no list. Each fact's NAMED cue is the one its row asks for:
# a table row's sound_next when it has one (Rows.heard plays the row's `sound` in its place while the
# bank has no recipe for it), else the cue the fact is heard as. A named cue has a recipe of its own when:
#   a music cue (a park row's music_cue)   MusicRows.CUES composes it
#   a recorded sound (SfxBank.FILE_SOUNDS)  its file is in the tree (else the bank plays a blip)
#   any other cue                           SfxBank.has_recipe (else the bank's fallback blip)
# A symbolic id (class_motif and the like) is judged once per class motif it resolves to.
# Prints one machine-readable CUE line per world 1 named cue, and a PLANT line: the same count run
# again with one world 1 fact's named cue swapped for an id with no recipe, which must be counted.
# scripts/gate/sound-recipes-receipt.mjs turns this output into the receipt.

const PLANT_ID := "plant_recipe_removed"
# Rows.resolve's symbolic ids (rows.gd): those built from the class motif are judged per class; those
# built from the event's own payload (the holding unit, the arriving faction) are printed as unjudged,
# since the roster facts already name those units' own cues.
const CLASS_SYMBOLS := ["class_motif", "class_break", "motif_release", "mind_quote"]
const EVENT_SYMBOLS := ["hold_by_kind", "faction_arrival"]

var _t := T.new("sound_own_recipes_test")


func _initialize() -> void:
	var facts := TwinsTest.universe(Twins.RELAY)
	var w1 := TwinsTest.world1(facts, TwinsTest.emit_index())
	var named := named_cues(facts, w1)
	_t.check("world 1 facts derived", w1.size() >= 50, str(w1.size()))
	var cues := judge(named)
	var standins := cues.keys().filter(func(c): return not cues[c].own)
	standins.sort()
	for cue in _sorted(cues.keys()):
		print("CUE %s" % JSON.stringify({"cue": cue, "own": cues[cue].own, "how": cues[cue].how, "facts": cues[cue].facts.size(), "fact": cues[cue].facts[0]}))
	_t.check("the count ran over every world 1 named cue", cues.size() >= 30, str(cues.size()))
	# The plant: one world 1 fact whose cue has a recipe now names an id with no recipe (its recipe removed).
	var victim := ""
	for fact in _sorted(named.keys()):
		var cue := String(named[fact].cue)
		if cues.has(cue) and cues[cue].own and cues[cue].how == "recipe":
			victim = fact
			break
	var planted := named.duplicate(true)
	planted[victim] = {"cue": PLANT_ID, "music": false}
	var after := judge(planted)
	var after_standins := after.keys().filter(func(c): return not after[c].own)
	var caught: bool = victim != "" and after.has(PLANT_ID) and not after[PLANT_ID].own and after_standins.size() == standins.size() + 1
	print("PLANT %s" % JSON.stringify({"fact": victim, "cue": PLANT_ID, "before": standins.size(), "after": after_standins.size(), "caught": caught}))
	_t.check("plant: a world 1 cue with its recipe removed is counted", caught, "%s: %d -> %d" % [victim, standins.size(), after_standins.size()])
	_t.check("plant: the planted id really bakes as the fallback blip", SfxBank.samples(PLANT_ID).size() == int(0.12 * SfxBank.RATE), str(SfxBank.samples(PLANT_ID).size()))
	print("SUMMARY %s" % JSON.stringify({"facts": w1.size(), "cues": cues.size(), "standins": standins}))
	quit(_t.verdict())


# {fact: {cue, music}} for every world 1 fact: the cue its row names (sound_next first), resolved.
static func named_cues(facts: Dictionary, w1: Dictionary) -> Dictionary:
	var tables: Dictionary = (load("res://src/core/event_kinds.gd") as GDScript).get_script_constant_map()
	var out := {}
	for fact in w1:
		var id := String(fact)
		var table := id.get_slice(":", 0)
		var key := id.get_slice(":", 1)
		var wanted := String(facts[fact])
		if table in TwinsTest.TABLES and tables[table].has(key):
			var row: Dictionary = tables[table][key]
			wanted = String(row.get("sound_next", "")) if String(row.get("sound_next", "")) != "" else String(row.get("sound", ""))
		if wanted == "" or wanted == "none":
			continue
		if not wanted in CLASS_SYMBOLS and not wanted in EVENT_SYMBOLS:
			out[id] = {"cue": wanted, "music": table == "music"}
			continue
		if wanted in EVENT_SYMBOLS:
			out[id] = {"cue": wanted, "music": false, "unjudged": true}
			continue
		# A class symbol: one entry per class motif. Rows.resolve answers "" when that class has no
		# recipe for it, which is the stand-in Rows.heard then plays.
		for def in ClassDef.all():
			var motif := String(def.motif)
			var cue := Rows.resolve(wanted, {"motif": motif})
			out["%s<%s>" % [id, motif]] = {"cue": cue if cue != "" else "%s<%s>" % [wanted, motif], "music": false}
	return out


# {cue: {own, how, facts}} over the named cues.
static func judge(named: Dictionary) -> Dictionary:
	var out := {}
	for fact in named:
		var cue := String(named[fact].cue)
		if not out.has(cue):
			out[cue] = _own(cue, bool(named[fact].music), bool(named[fact].get("unjudged", false)))
			out[cue]["facts"] = []
		out[cue].facts.append(fact)
	return out


static func _own(cue: String, music: bool, unjudged := false) -> Dictionary:
	if unjudged:
		return {"own": true, "how": "unjudged: resolves from the event's own context"}
	if music:
		return {"own": MusicRows.CUES.has(cue), "how": "music row" if MusicRows.CUES.has(cue) else "no music row"}
	if SfxBank.FILE_SOUNDS.has(cue) or cue.begins_with(SfxBank.STINGER_PREFIX):
		return {"own": SfxBank.file_exists(cue), "how": "file" if SfxBank.file_exists(cue) else "file missing"}
	return {"own": SfxBank.has_recipe(cue), "how": "recipe" if SfxBank.has_recipe(cue) else "fallback blip"}


static func _sorted(keys: Array) -> Array:
	var out := keys.duplicate()
	out.sort()
	return out
