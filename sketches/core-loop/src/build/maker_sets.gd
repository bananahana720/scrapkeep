extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")


const SPILLWAY := "spillway_works"
const FLEET := "fleet_surplus"
const REDJAW := "redjaw"
const ROOSTS := "highdraft_roosts"
const WAKING := "waking"
const MIND := "mind_glass"
const MOSS := "moss"

const SETS := {
	SPILLWAY: {"name": "Spillway Works", "pieces": 3, "bonus": "full_pressure", "bonus_name": "Full Pressure",
		"text": "Every active vents a steam ring that shoves machines back"},
	FLEET: {"name": "Fleet Surplus", "pieces": 3, "bonus": "rounded_up", "bonus_name": "Rounded Up",
		"text": "Every hit's damage rounds up to the next 5"},
	REDJAW: {"name": "Redjaw Workshops", "pieces": 3, "bonus": "bench_teeth", "bonus_name": "Bench Teeth",
		"text": "Your rolling line leaves teeth that bite anything crossing"},
	ROOSTS: {"name": "Highdraft Roosts", "pieces": 3, "bonus": "open_frame", "bonus_name": "Open Frame",
		"text": "An active fired in the air fires twice"},
	WAKING: {"name": "Waking-made", "pieces": 3, "bonus": "tremor", "bonus_name": "Tremor",
		"text": "Landing from a jump sends a ground ripple"},
	MIND: {"name": "Mind-glass", "pieces": 3, "bonus": "noticed", "bonus_name": "Noticed",
		"text": "Every crit leaves a glass splinter that strikes again"},
	MOSS: {"name": "Moss's Spares", "pieces": 2, "bonus": "packed_a_spare", "bonus_name": "Packed a Spare",
		"text": "The next item each stage comes with a second copy"},
}

const GRAPPLE_MUTATIONS := {
	SPILLWAY: "hot_wire",
	REDJAW: "det_cord",
	MOSS: "dragnet_siphon",
	ROOSTS: "sonic_snap_sling",
	MIND: "live_bus",
	WAKING: "tether_slam",
	FLEET: "wrecking_flail",
}


static func grapple_mutation_for_maker(maker: String) -> String:
	return String(GRAPPLE_MUTATIONS.get(maker, ""))


static func live_grapple_mutations(parts: Array, extra: Array = []) -> Array:
	var counted := counts(parts, extra)
	var out: Array = []
	for maker in SETS:
		if int(counted.get(maker, 0)) >= int(SETS[maker]["pieces"]):
			var mut_id := grapple_mutation_for_maker(maker)
			if mut_id != "" and not mut_id in out:
				out.append(mut_id)
	return out

static func maker_of(part_id: String) -> String:
	return Parts.maker_of(part_id)


static func relic_maker(relic_id: String) -> String:
	return String(Relics.row(relic_id).get("maker", ""))


static func counts(parts: Array, extra: Array = []) -> Dictionary:
	var seen := {}
	var out := {}
	var held := Parts.maker_counts(parts)
	for maker in held:
		if SETS.has(maker):
			out[maker] = held[maker]
	for i in extra.size():
		_count(out, seen, "extra:%d" % i, String(extra[i]))
	return out


static func _count(out: Dictionary, seen: Dictionary, key: String, maker: String) -> void:
	if maker == "" or not SETS.has(maker) or seen.has(key):
		return
	seen[key] = true
	out[maker] = int(out.get(maker, 0)) + 1


static func live_bonuses(counted: Dictionary) -> Array:
	var out := []
	for maker in SETS:
		if int(counted.get(maker, 0)) >= int(SETS[maker]["pieces"]):
			out.append(SETS[maker]["bonus"])
	return out


static func maker_of_bonus(bonus_id: String) -> String:
	for maker in SETS:
		if SETS[maker]["bonus"] == bonus_id:
			return maker
	return ""


static func validate() -> Array:
	var bad := []
	for part_id in Parts.rows():
		var maker := maker_of(part_id)
		if maker == "" or not SETS.has(maker):
			if _is_item(part_id):
				bad.append("%s: no known maker" % part_id)
	for relic_id in Relics.ids():
		if not SETS.has(relic_maker(relic_id)):
			bad.append("%s: relic has no known maker" % relic_id)
	for pilot in Relics.PILOTS:
		var reach := {}
		for part_id in Parts.rows():
			var r: Dictionary = Parts.rows()[part_id]
			var only := String(r.get("class_id", ""))
			if only != "" and only != pilot:
				continue
			var maker := maker_of(part_id)
			if maker != "":
				reach[maker] = int(reach.get(maker, 0)) + 1
		for maker in SETS:
			if int(reach.get(maker, 0)) < int(SETS[maker]["pieces"]):
				bad.append("%s: only %d %s pieces reachable" % [pilot, int(reach.get(maker, 0)), maker])
	return bad


static func _is_item(part_id: String) -> bool:
	return Parts.Items.TABLE.has(part_id) or Parts.Items.CELLS.has(part_id) or part_id in Parts.PATTERN_PARTS
