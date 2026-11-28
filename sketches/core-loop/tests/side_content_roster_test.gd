extends SceneTree

# Rule: every alpha zone has a combat challenge, a contraption/cache secret, and
# exactly one camp paying a real part allowed by the live stage table. Pending
# zones name their completion unit and may waive only the listed missing category.
const Game := preload("res://src/game.gd")
const Parts := preload("res://src/build/parts.gd")
const Activities := preload("res://src/world/activities.gd")

# 2026-10-04: SC2/SC3 own only Reach. The rescue site another writer adds does not
# supply Spillway's missing challenge or secret. SC4 is a proposed coordinator assignment.
const PENDING := {
	"1-1": {"name": "Spillway: the top shelf", "unit": "SC4 (proposed Spillway challenge and secret)",
		"missing": ["combat challenge", "contraption or cache secret"]},
}
const CONTRAPTION_KINDS := ["barge", "lift", "launcher", "cable", "valve", "cracked_wall", "thermal"]
const SIDE_CONTENT_PENDING := preload("res://tests/support/pending_content.gd").SIDE_CONTENT_PENDING
var _game
var _failures := 0


func _initialize() -> void:
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _clear_storage(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for folder in dir.get_directories():
		_clear_storage(path.path_join(folder))
		dir.remove(folder)


func _errors(map) -> Array[String]:
	var errors: Array[String] = []
	var sites: Array = map.activity_sites if "activity_sites" in map else []
	var combat := sites.any(func(site): return site.id in ["ambush_altar", "hauler_bounty"] and Activities.RULES.has(site.id))
	if not combat:
		errors.append("combat challenge")
	var secret := sites.any(func(site): return site.id == "cracked_cache" and Activities.RULES.has(site.id))
	if "contraptions" in map:
		secret = secret or map.contraptions.any(func(spec): return spec.get("kind", "") in CONTRAPTION_KINDS)
	if not secret:
		errors.append("contraption or cache secret")
	var camps := sites.filter(func(site): return site.id == "enemy_camp")
	if camps.size() != 1:
		errors.append("exactly one enemy camp")
	else:
		var pay: Dictionary = Activities.RULES["enemy_camp"]["pay"].merged(camps[0].get("pay", {}), true)
		var named := String(pay.get("named", ""))
		if not Parts.rows().has(named) or not _game.ctx.stages.part_in_play(named):
			errors.append("camp reward in play")
	return errors


func _run() -> void:
	_clear_storage("user://test-%d" % OS.get_process_id())
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.world.set_physics_process(false)
	_game.world.activities.set_physics_process(false)
	var seen := []
	var checked := 0
	var real := 0
	for row in _game.ctx.stages.DEFS:
		var stage: int = row["stage"]
		var key := "%d-%d" % [_game.ctx.stages.world_of(stage), _game.ctx.stages.local(stage)]
		seen.append(key)
		var map = _game.ctx.terrain.map_for(stage)
		var errors := _errors(map)
		if SIDE_CONTENT_PENDING.has(String(row["map"])):
			# 2026-10-04 (wave 9): greybox zone, its side content lands in wave 10.
			print("[skip %s: %s] greybox map %s; side content pending wave 10" % [key, row["name"], row["map"]])
			continue
		if String(row["name"]).contains("placeholder"):
			print("[skip %s: %s] placeholder row on a reused map; no authored side content yet" % [key, row["name"]])
			continue
		real += 1
		if PENDING.has(key):
			var pending: Dictionary = PENDING[key]
			_report("pending %s: %s" % [key, row["name"]], pending.name == row["name"] and not pending.unit.is_empty()
				and errors == pending.missing and not errors.is_empty(),
				"%s; missing %s; observed %s" % [pending.unit, pending.missing, errors])
		else:
			checked += 1
			_report("zone %s: %s" % [key, row["name"]], errors.is_empty(), "missing %s" % [errors])
		if row["map"] == "reach":
			_negative_cases(map)
	for key in PENDING:
		_report("pending row exists", key in seen, key)
	_report("at least two authored zones checked", real >= 2, "%d non-placeholder zones checked" % real)
	_report("at least one complete zone", checked > 0, "%d zones checked without waiver" % checked)
	_game.free()
	print("side_content_roster_test: %s" % ("PASS (Spillway zone 1-1 pending: SC4 proposed challenge and secret)" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _negative_cases(map) -> void:
	var sites: Array = map.activity_sites.duplicate(true)
	var specs: Array = map.contraptions.duplicate(true)
	map.activity_sites = sites.filter(func(site): return site.id != "enemy_camp")
	_report("removed Reach camp fails guard", "exactly one enemy camp" in _errors(map), str(_errors(map)))
	map.activity_sites = sites.filter(func(site): return not site.id in ["ambush_altar", "hauler_bounty"])
	_report("removed Reach combat fails guard", "combat challenge" in _errors(map), str(_errors(map)))
	map.activity_sites = sites.filter(func(site): return site.id != "cracked_cache")
	map.contraptions = []
	_report("removed Reach secrets fail guard", "contraption or cache secret" in _errors(map), str(_errors(map)))
	map.contraptions = specs
	map.activity_sites = sites.duplicate(true)
	for site in map.activity_sites:
		if site.id == "enemy_camp":
			site.pay.named = "not_a_part"
	_report("unknown camp part fails guard", "camp reward in play" in _errors(map), str(_errors(map)))
	# 2026-10-16 (wave 14 merge check): the excluded part is the first catalogue row not in play,
	# not a named one; SQ19b put glide_vane, the old fixture, on the alpha list.
	var excluded := ""
	for id in Parts.rows():
		if not _game.ctx.stages.part_in_play(id):
			excluded = id
			break
	for site in map.activity_sites:
		if site.id == "enemy_camp":
			site.pay.named = excluded
	_report("excluded camp part fails guard", excluded != "" and "camp reward in play" in _errors(map), "%s: %s" % [excluded, _errors(map)])
	map.activity_sites = sites
