extends RefCounted


static func of(defs: Array, stage: int) -> Dictionary:
	return defs[clampi(stage, 1, defs.size()) - 1]


static func is_last(defs: Array, stage: int) -> bool:
	return stage >= defs.size()


static func world_of(defs: Array, stage: int) -> int:
	return int(defs[clampi(stage, 1, defs.size()) - 1].get("world", 1))


static func first_of(defs: Array, world: int) -> int:
	for d in defs:
		if int(d.get("world", 1)) == world:
			return int(d["stage"])
	return 0


static func last_of(defs: Array, world: int) -> int:
	var found := 0
	for d in defs:
		if int(d.get("world", 1)) == world:
			found = int(d["stage"])
	return found


static func local(defs: Array, stage: int) -> int:
	return clampi(stage, 1, defs.size()) - first_of(defs, world_of(defs, stage)) + 1


static func worlds(defs: Array) -> Array:
	var out := []
	for d in defs:
		var w := int(d.get("world", 1))
		if w not in out:
			out.append(w)
	return out


static func is_world_last(defs: Array, stage: int) -> bool:
	return stage >= last_of(defs, world_of(defs, stage))


static func part_in_play(part_id: String, pools: Array) -> bool:
	for pool in pools:
		if part_id in pool:
			return true
	return false
