extends RefCounted

const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Weapons := preload("res://src/combat/weapons.gd")


static func problems(for_class: String, world_one := false, tree: GDScript = UpgradeTree) -> Array[String]:
	var out: Array[String] = []
	var list: Array = tree.nodes(for_class, world_one)
	if list.size() != tree.SIZE:
		out.append("%s has %d nodes, not %d" % [for_class, list.size(), tree.SIZE])
	var seen := {}
	var bus: Script = GameEvents
	var first_leaf := list.size() - 16
	if world_one:
		list = list.slice(0, tree.WORLD_ONE_SIZE)
		first_leaf = tree.WORLD_ONE_SIZE - 4
	for leaf in range(first_leaf, list.size()):
		var loop := proc_loop(for_class, tree.path_to(for_class, list[leaf].get("id", ""), world_one), world_one, tree)
		if loop != "":
			out.append("%s: the build ending in %s can loop on %s" % [for_class, list[leaf].get("id", ""), loop])
	for n in list:
		var id: String = n.get("id", "")
		if id == "" or seen.has(id):
			out.append("%s: missing or repeated id '%s'" % [for_class, id])
		seen[id] = true
		var words: int = String(n.get("name", "")).split(" ", false).size()
		if words < 1 or words > tree.NAME_WORDS:
			out.append("%s: name has %d words" % [id, words])
		words = String(n.get("effect", "")).split(" ", false).size()
		if words < 1 or words > tree.EFFECT_WORDS:
			out.append("%s: effect has %d words" % [id, words])
		if not n.get("key", "") in tree.KEYS:
			out.append("%s: key '%s' is not one of %s" % [id, n.get("key", ""), tree.KEYS])
		if not String(n.get("icon", "")).begins_with("ab_"):
			out.append("%s: icon '%s' is not an ab_ id" % [id, n.get("icon", "")])
		var tags: Array = n.get("tags", [])
		if tags.is_empty() or tags.any(func(t): return not t in tree.TAGS):
			out.append("%s: tags %s outside %s" % [id, tags, tree.TAGS])
		if not tree.OPS.any(func(op): return n.has(op)):
			out.append("%s: no op" % id)
		for k in n.get("knob", {}):
			if not tree.KNOBS.has(k):
				out.append("%s: unknown knob '%s'" % [id, k])
		for slot in n.get("swap", {}):
			var variant: String = n["swap"][slot]
			if not slot in AbilityState.SWAPPABLE or not AbilityState.ABILITIES.has(variant):
				out.append("%s: swap %s -> %s is not a slot and ability row" % [id, slot, variant])
		for slot in n.get("charges", {}):
			if not slot in AbilityState.SLOTS or int(n["charges"][slot]) < 1:
				out.append("%s: charges %s" % [id, n["charges"]])
		for slot in n.get("cooldown", {}):
			if not slot in AbilityState.SLOTS:
				out.append("%s: cooldown slot %s" % [id, slot])
		for weapon in n.get("pattern", {}):
			if not weapon in Weapons.ALL:
				out.append("%s: pattern for unknown weapon %s" % [id, weapon])
				continue
			var base: Resource = Weapons.base(weapon)
			for part in n["pattern"][weapon]:
				for key in n["pattern"][weapon][part]:
					if not part in ["set", "add", "mul", "min"] or base.get(key) == null:
						out.append("%s: pattern %s.%s" % [id, part, key])
		for p in n.get("proc", []):
			if not tree.ACTIONS.has(p.get("do", "")) or not bus.has_script_signal(p.get("on", "")):
				out.append("%s: proc %s" % [id, p])
	return out


static func proc_loop(for_class: String, build: Array[String], world_one := false, tree: GDScript = UpgradeTree) -> String:
	var links := {}
	for id in build:
		for p in tree.node(for_class, id, world_one).get("proc", []):
			if not links.has(p["on"]):
				links[p["on"]] = []
			links[p["on"]].append_array(tree.ACTIONS.get(p["do"], []))
	for start in links:
		var frontier: Array = links[start].duplicate()
		var visited := {}
		while not frontier.is_empty():
			var fact = frontier.pop_back()
			if fact == start:
				return start
			if visited.has(fact):
				continue
			visited[fact] = true
			frontier.append_array(links.get(fact, []))
	return ""
