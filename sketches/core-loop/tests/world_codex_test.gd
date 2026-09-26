extends SceneTree

const CodexWorld := preload("res://src/world/codex_world.gd")

# The world's codex entries as data and their detector, stepped headless: every entry
# is complete (category world, name, hint, clue, text), each trick fires on its own
# recipe exactly once per stage attempt, and a near miss does not fire.

const FIELDS := ["id", "category", "name", "hint", "clue", "text"]
const H := 1.0 / 90.0

var _failures := 0


func _initialize() -> void:
	_check_entries()
	_check_recipes()
	print("world_codex_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check_entries() -> void:
	var bad: Array[String] = []
	var ids := {}
	for entry in CodexWorld.ENTRIES:
		for field in FIELDS:
			if String(entry.get(field, "")) == "":
				bad.append("%s missing %s" % [entry.get("id", "?"), field])
		if entry.get("category", "") != "world":
			bad.append("%s not in world" % entry.get("id", "?"))
		ids[entry["id"]] = true
	_report("entries", bad.is_empty() and ids.size() == CodexWorld.ENTRIES.size() and ids.size() >= 5,
		"%d world entries %s, each with a name, hint, clue and text; problems %s" % [ids.size(), ids.keys(), bad])


func _wait(d, seconds: float) -> void:
	for i in int(seconds / H):
		d.advance(H)


func _check_recipes() -> void:
	var here := Vector3(10.0, 2.0, 10.0)
	var d = CodexWorld.new()
	var got: Array[String] = []
	var misses: Array[String] = []
	var collect := func(out: Array): for e in out: got.append(e["id"])

	d.note("element", {"material": "water", "behaviour": "electrify", "at": here})
	_wait(d, 1.0)
	if not d.note("kill", {"at": here + Vector3(40.0, 0.0, 0.0), "in_water": true}).is_empty():
		misses.append("live wire fired 40 m from the charge")
	collect.call(d.note("kill", {"at": here + Vector3(5.0, 0.0, 0.0), "in_water": true}))

	if not d.note("gate", {"id": "surge_run", "at": here, "tier": 2}).is_empty():
		misses.append("surge slingshot fired at fast, not blazing")
	collect.call(d.note("gate", {"id": "surge_run", "at": here, "tier": 3}))

	if not d.note("slam", {"at": here}).is_empty():
		misses.append("sluice hammer fired with no kicker")
	d.note("airborne", {"at": here, "off_kicker": true})
	_wait(d, 1.0)
	collect.call(d.note("slam", {"at": here}))

	if not d.note("jump", {"at": here, "tailwind": false}).is_empty():
		misses.append("squall sail fired into a headwind")
	collect.call(d.note("jump", {"at": here, "tailwind": true}))

	d.note("element", {"material": "water", "behaviour": "create_surface", "at": here})
	_wait(d, 2.0)
	collect.call(d.note("grounded", {"at": here + Vector3(3.0, 0.0, 0.0), "over_water": true}))

	var again := d.note("jump", {"at": here, "tailwind": true})
	var wanted: Array[String] = ["live_wire_flood", "surge_slingshot", "sluice_hammer", "squall_sail", "ice_bridge"]
	_report("recipes", got == wanted and misses.is_empty() and again.is_empty(),
		"fired %s in order; near misses that fired %s; a repeat fired %d more" % [got, misses, again.size()])


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
