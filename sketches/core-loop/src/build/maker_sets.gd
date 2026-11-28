extends RefCounted

const MakerDefs := preload("res://src/build/maker_defs.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")

const SPILLWAY := MakerDefs.SPILLWAY
const FLEET := MakerDefs.FLEET
const REDJAW := MakerDefs.REDJAW
const ROOSTS := MakerDefs.ROOSTS
const WAKING := MakerDefs.WAKING
const MIND := MakerDefs.MIND
const MOSS := MakerDefs.MOSS

const SETS := MakerDefs.SETS
const GRAPPLE_MUTATIONS := MakerDefs.GRAPPLE_MUTATIONS


static func grapple_mutation_for_maker(maker: String) -> String:
	return MakerDefs.grapple_mutation_for_maker(maker)


static func live_grapple_mutations(parts: Array, extra: Array = []) -> Array:
	return MakerDefs.live_grapple_mutations_from(counts(parts, extra))


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
	return MakerDefs.live_bonuses(counted)


static func maker_of_bonus(bonus_id: String) -> String:
	return MakerDefs.maker_of_bonus(bonus_id)


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
	for pilot in Relics.pilots():
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
