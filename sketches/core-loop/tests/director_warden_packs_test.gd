extends SceneTree

const Director := preload("res://src/world/director.gd")
const T := preload("res://tests/support/t.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

# w18 Warden-fight packs (ruling 15 c'): while a Warden core is live the director draws its authored
# arrivals from the row's warden_packs, so the mobs near the core are damage dealers that close on the
# ball. With no Warden live, or no key, the draw and its RNG are what they were.
# Planted control: draw from `authored` always in _draw_authored and "swap" fails; drop the clear in
# the warden_core setter and "flip clears the cached pack" fails.

const DRAWS := 40
const CORE := Vector2(100.0, 40.0)

var _t := T.new("director_warden_packs_test")


func _initialize() -> void:
	_tables_match()
	_spawnable()
	_swap_only_while_live()
	_flip_resets_cache()
	_unchanged_without_warden()
	_stage_one_unkeyed()
	_swarm_keeps_out()
	quit(_t.verdict())


func _director(row: Dictionary, seed_value: int):
	var d = Director.new(seed_value)
	d.authored = row["packs"]
	d.warden_packs = row.get("warden_packs", [])
	return d


func _ids(packs: Array) -> Array:
	return packs.map(func(p: Dictionary) -> String: return p["id"])


func _draw_ids(d, count: int) -> Array:
	var out := []
	for i in count:
		var pack: Dictionary = d._draw_authored()
		out.append(pack["id"])
		d._last_pack_id = pack["id"]
	return out


func _tables_match() -> void:
	for stage in range(2, 7):
		var a: Array = AlphaDefs.of(stage).get("warden_packs", [])
		var p: Array = ParkDefs.of(stage).get("warden_packs", [])
		_t.check("stage %d warden_packs present" % stage, a.size() == 2, str(a.size()))
		_t.check("stage %d alpha and park warden_packs identical" % stage, a == p)


func _spawnable() -> void:
	for stage in range(2, 7):
		for pack in AlphaDefs.of(stage).get("warden_packs", []):
			for kind in pack["kinds"]:
				_t.check("stage %d %s: %s is a director kind" % [stage, pack["id"], kind], kind in Director.KIND_NAMES)


func _swap_only_while_live() -> void:
	for stage in range(2, 7):
		var row: Dictionary = AlphaDefs.of(stage)
		var warden_ids := _ids(row["warden_packs"])
		var d = _director(row, 7 + stage)
		var calm := _draw_ids(d, DRAWS)
		_t.check("stage %d: no Warden draws only the stage packs" % stage, calm.all(func(i: String) -> bool: return not i in warden_ids))
		d.warden_core = CORE
		var live := _draw_ids(d, DRAWS)
		_t.check("stage %d: swap, live Warden draws only warden_packs" % stage, live.all(func(i: String) -> bool: return i in warden_ids))
		_t.check("stage %d: both warden packs come up" % stage, live.has(warden_ids[0]) and live.has(warden_ids[1]))
		d.warden_core = Vector2.INF
		var after := _draw_ids(d, DRAWS)
		_t.check("stage %d: Warden gone returns to the stage packs" % stage, after.all(func(i: String) -> bool: return not i in warden_ids))


func _flip_resets_cache() -> void:
	var row: Dictionary = AlphaDefs.of(2)
	var d = _director(row, 5)
	d._next_pack = d.authored[0]
	d.warden_core = CORE
	_t.check("flip clears the cached pack (INF to finite)", d._next_pack.is_empty())
	d._next_pack = d.warden_packs[0]
	d.warden_core = CORE + Vector2(3.0, 0.0)
	_t.check("a moving core keeps the cached pack", not d._next_pack.is_empty())
	d.warden_core = Vector2.INF
	_t.check("flip clears the cached pack (finite to INF)", d._next_pack.is_empty())
	var bare = _director({"packs": row["packs"]}, 5)
	bare._next_pack = bare.authored[0]
	bare.warden_core = CORE
	_t.check("no warden_packs: the cache is left alone", not bare._next_pack.is_empty())


func _unchanged_without_warden() -> void:
	for stage in range(2, 7):
		var row: Dictionary = AlphaDefs.of(stage)
		var keyless: Dictionary = row.duplicate()
		keyless.erase("warden_packs")
		var with_key = _director(row, 31 + stage)
		var without = _director(keyless, 31 + stage)
		_t.check("stage %d: key at INF draws the same %d packs as no key" % [stage, DRAWS], _draw_ids(with_key, DRAWS) == _draw_ids(without, DRAWS))
		_t.check("stage %d: RNG state identical after the draws" % stage, with_key._rng.state == without._rng.state)
		var live = _director(keyless, 31 + stage)
		live.warden_core = CORE
		var plain = _director(keyless, 31 + stage)
		_t.check("stage %d: keyless stage unchanged with a Warden live" % stage, _draw_ids(live, DRAWS) == _draw_ids(plain, DRAWS))


func _stage_one_unkeyed() -> void:
	_t.check("alpha stage 1 has no warden_packs", not AlphaDefs.of(1).has("warden_packs"))
	_t.check("park stage 1 has no warden_packs", not ParkDefs.of(1).has("warden_packs"))


# A swarm Warden is its own hive: no ring, no warden_packs (the camper never breaks the hive).
func _swarm_keeps_out() -> void:
	var at := Vector2(10.0, 20.0)
	_t.check("reactor Warden live: core follows", Director.contact_core(true, 3, "reactor", at) == at)
	_t.check("mind Warden live: core follows", Director.contact_core(true, 5, "mind", at) == at)
	_t.check("swarm Warden live: no core", Director.contact_core(true, 3, "swarm", at) == Vector2.INF)
	_t.check("no fight: no core", Director.contact_core(false, 3, "reactor", at) == Vector2.INF)
	_t.check("stage 1: no core", Director.contact_core(true, 1, "reactor", at) == Vector2.INF)
	var row: Dictionary = AlphaDefs.of(3)
	var d = _director(row, 9)
	d.warden_core = Director.contact_core(true, 3, "swarm", at)
	var ids := _draw_ids(d, DRAWS)
	_t.check("swarm Warden: draws only the stage packs", ids.all(func(i: String) -> bool: return not i in _ids(row["warden_packs"])))
	_t.check("swarm Warden: spawn spot is not on the ring", not d.warden_core.is_finite())
