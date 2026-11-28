extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")

# PC-POOL (wave 14, Bible Mobility row, Andrew 2026-10-12): movement that changes how a pilot
# moves belongs to that pilot. Shared parts may change what a verb does, never how far or fast
# the ball moves. Checks:
#   - no part every pilot can be offered carries a movement mod: a tuning knob outside
#     NOT_MOVEMENT, or a cooldown scale (it feeds the boost cooldown). Class parts are exempt;
#   - the five wave 11 verb parts keep their ids, tags and touch verbs;
#   - grip_tread, vent_baffle and spring_shims are class parts of the pilot whose Shift they
#     deepen (the pilots' PILOTS.md Shift feel); live_line and drop_weight stay shared because
#     they are the second ingredients of two evolutions, and carry no movement knob;
#   - both evolutions still have both ingredients in every pilot's pool, at common rarity.
# Evidence limit: static rows and the offer pool. That each pilot still wins its bot runs is
# bot_six_pilots_test's claim, and how the new effects feel is Andrew's to play.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const RARITIES := [["common"], ["rare"], ["relic"], ["evolved"], ["common", "rare", "relic"]]
# The mod knobs that change what a part does without changing how the ball moves.
# 2026-10-15 PC-POOL (coordinator ruling P4): harpoon_lock_deg widens the harpoon's targeting
# cone; it moves the ball neither farther nor faster.
const NOT_MOVEMENT := ["weapon_damage", "weapon_rate", "weapon_range", "turret_damage", "harpoon_lock_deg"]
# id: [tags, touch verb, class_id]. A class_id of "" is shared.
const FIVE := {
	"grip_tread": [["anchor"], "roll", "runner_gunner"],
	"live_line": [["arc"], "harpoon", ""],
	"vent_baffle": [["speed"], "boost", "tally"],
	"spring_shims": [["spiral"], "jump", "pylon_engineer"],
	"drop_weight": [["mass"], "haul", ""],
}
const EVOLUTIONS := {"tesla_pylon": ["focus_lens", "live_line"], "lightning_rod": ["arc_coil", "drop_weight"]}

var _t := preload("res://tests/support/t.gd").new("parts_pool_movement_test")


func _initialize() -> void:
	_run()


func _run() -> void:
	Synergies.set_table(AlphaDefs)
	_t.check("the alpha table lists its parts", PartOffers.listed_only(), "offer_pool must read the alpha table")
	_pool_is_clear()
	_five_rows()
	_shared_verbs_act()
	_evolutions()
	quit(_t.verdict())


func _movement_mods(part_id: String) -> Array:
	var d: Resource = Parts.def(part_id)
	var found: Array = []
	for knob in d.mods:
		if not knob in NOT_MOVEMENT:
			found.append(knob)
	if d.cooldown_scale != 1.0:
		found.append("cooldown_scale")
	return found


func _pool_is_clear() -> void:
	var offered := 0
	var bad: Array = []
	for pilot in PILOTS:
		for rarities in RARITIES:
			for id in Parts.offer_pool(pilot, rarities):
				offered += 1
				var only: String = Parts.row(id).get("class_id", "")
				if only == "" and not _movement_mods(id).is_empty():
					bad.append("%s offered to %s with %s" % [id, pilot, _movement_mods(id)])
	_t.check("the pools are not empty", offered > 0, str(offered))
	_t.eq("no shared part in any pilot's pool carries a movement mod", bad, [])
	var listed_bad: Array = []
	for id in AlphaDefs.PARTS:
		var row: Dictionary = Parts.row(id)
		if row.get("class_id", "") == "" and not _movement_mods(id).is_empty():
			listed_bad.append(id)
	_t.eq("no shared part on the alpha list carries a movement mod", listed_bad, [])


func _five_rows() -> void:
	for id in FIVE:
		var want: Array = FIVE[id]
		var row: Dictionary = Parts.row(id)
		_t.check("%s is on the alpha list" % id, id in AlphaDefs.PARTS, "")
		_t.eq("%s tags" % id, row.get("tags", []), want[0])
		_t.eq("%s touches" % id, row.get("touches", ""), want[1])
		_t.eq("%s class_id" % id, row.get("class_id", ""), want[2])
		for pilot in PILOTS:
			var offered: bool = id in Parts.offer_pool(pilot, ["common"])
			_t.eq("%s is offered to %s only if shared or its own" % [id, pilot], offered, want[2] == "" or want[2] == pilot)
		if want[2] == "":
			_t.eq("%s has no movement mod" % id, _movement_mods(id), [])


# Round 2 (gate finding) and coordinator ruling P4 (2026-10-15): a shared part's touches field must
# name a verb its own change acts on. live_line widens the harpoon lock cone (harpoon_lock_deg,
# which the harpoon reads through tuning); drop_weight acts on the smash itself: its base row
# was slam_speed 1.15, now on_smash arms the pins it throws.
func _shared_verbs_act() -> void:
	var live: Dictionary = Parts.row("live_line")
	_t.eq("live_line widens the harpoon lock cone and touches harpoon", [live.get("touches", ""), live.get("mods", {}).has("harpoon_lock_deg")], ["harpoon", true])
	_t.check("live_line no longer duplicates focus_lens's weapon range", not live.get("mods", {}).has("weapon_range"), "")
	var drop: Dictionary = Parts.row("drop_weight")
	_t.eq("drop_weight fires on a smash", drop.get("trigger", ""), "on_smash")
	_t.eq("drop_weight arms the pins a smash throws", drop.get("effect", {}).get("do", ""), "pin_bonus")
	_t.check("drop_weight no longer adds hull", not drop.has("max_hp_bonus"), "")


func _evolutions() -> void:
	for synergy in EVOLUTIONS:
		for pilot in PILOTS:
			var pool: Array = Parts.offer_pool(pilot, ["common"])
			for ingredient in EVOLUTIONS[synergy]:
				_t.check("%s ingredient %s is in %s's common pool" % [synergy, ingredient, pilot], ingredient in pool, "")
		var into: String = ""
		for key in Synergies.EVOLUTIONS:
			if Synergies.evolution_of(key) == synergy and Synergies.EVOLUTIONS[key] == EVOLUTIONS[synergy]:
				into = key
		_t.check("%s still evolves" % synergy, into != "" and Parts.EVOLVED.has(into), into)
