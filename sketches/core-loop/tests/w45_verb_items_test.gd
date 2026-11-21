extends SceneTree

# W45-B2 U7 (design-v3/ABILITY-MUTATIONS.md sections 7 C3–C7): the five verb items.
# Backwash: dash lays a 4 m committed strip behind the ball at 0.4x weapon hit.
# Barbed Reel: harpoon_smashed chains once to the nearest other machine at 0.7x.
# Faultline Cap: smash landing cracks 8 m ahead at 0.5x, breaks props at +1 tier.
# Second Bell: kit special repeats once 1 s later at half strength.
# Long Leash: line skill's load_seconds doubles.
# Each rule carries a planted control: the naive version the rule exists to refuse.

const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w45_verb_items_test")

const IDS := ["backwash", "barbed_reel", "faultline_cap", "second_bell", "long_leash"]
const EXPECTED := {
	"backwash": {"maker": "spillway_works", "rarity": "uncommon", "touches": "movement", "base": "mobility",
		"effect_do": "dash_wake"},
	"barbed_reel": {"maker": "redjaw", "rarity": "rare", "touches": "harpoon", "base": "weapon",
		"effect_do": "reel_chain"},
	"faultline_cap": {"maker": "waking", "rarity": "rare", "touches": "jump", "base": "defense",
		"effect_do": "slam_crack"},
	"second_bell": {"maker": "mind_glass", "rarity": "uncommon", "touches": "special", "base": "charge",
		"effect_do": "second_bell"},
	"long_leash": {"maker": "moss", "rarity": "uncommon", "touches": "harpoon", "base": "utility",
		"effect_do": "line_leash"},
}


func _initialize() -> void:
	_check_rows()
	_check_effects_table()
	_check_alpha_admission()
	_check_word_budget()
	_check_anti_loop_data()
	_check_long_leash_data()
	_check_slam_crack_data()
	_check_second_bell_data()
	_check_backwash_data()
	_check_barbed_reel_data()
	quit(_t.verdict())


func _check_rows() -> void:
	for id in IDS:
		var d: Resource = Parts.def(id)
		var expect: Dictionary = EXPECTED[id]
		_t.check("%s row exists" % id, d != null, "missing")
		if d == null:
			continue
		_t.eq("%s maker" % id, d.maker, expect["maker"])
		_t.check("%s rarity is %s" % [id, expect["rarity"]], d.rarity == ItemGen.resolve_rarity(expect["rarity"]),
			d.rarity)
		var row: Dictionary = Items.TABLE[id]
		_t.eq("%s touches" % id, row.get("touches", ""), expect["touches"])
		_t.eq("%s base" % id, row.get("base", ""), expect["base"])
		_t.eq("%s effect do" % id, d.effect.get("do", ""), expect["effect_do"])
		_t.check("%s stack is capped at 1" % id, d.stack_rule == "capped" and d.stack_cap == 1.0,
			"%s/%s" % [d.stack_rule, d.stack_cap])


func _check_effects_table() -> void:
	for id in IDS:
		var d: Resource = Parts.def(id)
		if d == null:
			continue
		var effect_id: String = d.effect.get("do", "")
		_t.check("%s effect '%s' is in the closed EFFECTS table" % [id, effect_id],
			ItemEffects.EFFECTS.has(effect_id), effect_id)
	_t.check("a made-up verb effect is not in EFFECTS", not ItemEffects.EFFECTS.has("dash_unleash"), "")


func _check_alpha_admission() -> void:
	for id in IDS:
		var d: Resource = Parts.def(id)
		if d == null:
			continue
		_t.check("%s admitted to AlphaDefs.PARTS" % id, id in AlphaDefs.PARTS, "")
		_t.check("%s is never relic or rare_plus" % id, not d.rarity in ["relic", "rare_plus"], d.rarity)


func _check_word_budget() -> void:
	for id in IDS:
		var d: Resource = Parts.def(id)
		if d == null:
			continue
		_t.check("%s verb is at most 6 words" % id, WordBudget.words_in(String(d.verb)) <= 6,
			"%d: '%s'" % [WordBudget.words_in(String(d.verb)), d.verb])
		_t.check("%s text is at most %d words and not clipped" % [id, ItemGen.MAX_WORDS],
			WordBudget.words_in(String(d.text)) <= ItemGen.MAX_WORDS and not "..." in String(d.text),
			"%d: '%s'" % [WordBudget.words_in(String(d.text)), d.text])
		_t.check("%s text has no banned words" % id,
			not "unleash" in String(d.text).to_lower() and not "foes" in String(d.text).to_lower(),
			String(d.text))


func _check_anti_loop_data() -> void:
	for id in IDS:
		var d: Resource = Parts.def(id)
		if d == null:
			continue
		_t.check("%s has no trigger (passive)" % id, d.trigger == "", d.trigger)
		var effect_id: String = d.effect.get("do", "")
		_t.check("%s is in PASSIVE_EFFECTS" % id, effect_id in ItemEffects.PASSIVE_EFFECTS, effect_id)


func _check_long_leash_data() -> void:
	var d: Resource = Parts.def("long_leash")
	_t.check("long_leash effect has mult", d.effect.has("mult"), str(d.effect))
	_t.eq("long_leash mult is 2.0", float(d.effect.get("mult", 0)), 2.0)
	for ability_id in AbilityState.ABILITIES:
		var row: Dictionary = AbilityState.ABILITIES[ability_id]
		if row.has("load_seconds"):
			var base: float = float(row["load_seconds"])
			_t.check("line skill '%s' has load_seconds %s" % [ability_id, base], base > 0.0, str(base))


func _check_slam_crack_data() -> void:
	var d: Resource = Parts.def("faultline_cap")
	_t.check("slam_crack has length 8.0", float(d.effect.get("length", 0)) == 8.0, str(d.effect))
	_t.check("slam_crack has share 0.5", float(d.effect.get("share", 0)) == 0.5, str(d.effect))
	_t.check("slam_crack has break_radius 2.5", float(d.effect.get("break_radius", 0)) == 2.5, str(d.effect))


func _check_second_bell_data() -> void:
	var d: Resource = Parts.def("second_bell")
	_t.check("second_bell has delay 1.0", float(d.effect.get("delay", 0)) == 1.0, str(d.effect))
	_t.check("second_bell has share 0.5", float(d.effect.get("share", 0)) == 0.5, str(d.effect))
	_t.check("second_bell effect id is distinct from special_echo",
		d.effect.get("do", "") != "special_echo" and d.effect.get("do", "") != "echo_release",
		d.effect.get("do", ""))


func _check_backwash_data() -> void:
	var d: Resource = Parts.def("backwash")
	_t.check("dash_wake has length 4.0", float(d.effect.get("length", 0)) == 4.0, str(d.effect))
	_t.check("dash_wake has share 0.4", float(d.effect.get("share", 0)) == 0.4, str(d.effect))


func _check_barbed_reel_data() -> void:
	var d: Resource = Parts.def("barbed_reel")
	_t.check("reel_chain has share 0.7", float(d.effect.get("share", 0)) == 0.7, str(d.effect))
	_t.check("reel_chain has reach 6.0", float(d.effect.get("reach", 0)) == 6.0, str(d.effect))
