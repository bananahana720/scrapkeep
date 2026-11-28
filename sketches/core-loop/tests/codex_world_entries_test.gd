extends SceneTree

const T := preload("res://tests/support/t.gd")
const CodexWorld := preload("res://src/world/codex_world.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")
const Registry := preload("res://tests/support/content_registry.gd")
const WORLD_IDS := ["breach_plate", "net_deck", "thermal_lift", "moving_island"]
const WORLD_FIELDS := ["id", "category", "name", "hint", "clue", "text"]
const BOSS_FIELDS := ["id", "name", "hint", "clue", "text"]


func _initialize() -> void:
	var t := T.new("codex_world_entries_test")
	_check_world(t)
	_check_bosses(t)
	_check_recipes(t)
	quit(t.verdict())


func _check_world(t) -> void:
	t.check("world ids unique", _unique_ids(CodexWorld.ENTRIES))
	for id in WORLD_IDS:
		var row := CodexWorld.entry(id)
		t.check("world row " + id, not row.is_empty())
		t.check("world fields " + id, _filled(row, WORLD_FIELDS))
		t.eq("world category " + id, row.get("category", ""), "world")


func _check_bosses(t) -> void:
	var rows := CodexEntries.all()
	t.eq("all boss rows", rows.size(), 14)
	t.check("boss ids unique", _unique_ids(rows))
	t.check("world and boss ids unique", _unique_ids(CodexWorld.ENTRIES + rows))
	for row in rows:
		t.check("boss fields " + String(row.get("id", "?")), _filled(row, BOSS_FIELDS))
	# The Waking's own attacks (2026-10-17) added Off the Lip and The Wall Is Home.
	var counts := {"brindle": 4, "waking": 6, "mind": 4}
	for boss in ["brindle", "waking", "mind"]:
		var selected := CodexEntries.for_boss(boss)
		t.eq("%d rows for %s" % [counts[boss], boss], selected.size(), counts[boss])
		var matching := rows.filter(func(row): return String(row.get("id", "")).begins_with(boss + "_"))
		t.eq("all includes rows for " + boss, matching, selected)
		t.check("matching prefix for " + boss, selected.all(func(row): return String(row.get("id", "")).begins_with(boss + "_")))
	t.eq("Brindle table preserved", CodexEntries.for_boss("brindle"), CodexEntries.ENTRIES)
	t.eq("Waking table selected", CodexEntries.for_boss("waking"), CodexEntries.WAKING)
	t.eq("Mind table selected", CodexEntries.for_boss("mind"), CodexEntries.MIND)
	t.eq("unknown boss has no rows", CodexEntries.for_boss("unknown"), [])
	t.eq("golden digest boss.codex_entries.ENTRIES", Registry.digest(CodexEntries.ENTRIES), Registry.GOLDEN_HASHES["boss.codex_entries.ENTRIES"])
	t.eq("golden digest boss.codex_entries.WAKING", Registry.digest(CodexEntries.WAKING), Registry.GOLDEN_HASHES["boss.codex_entries.WAKING"])
	t.eq("golden digest boss.codex_entries.MIND", Registry.digest(CodexEntries.MIND), Registry.GOLDEN_HASHES["boss.codex_entries.MIND"])


func _check_recipes(t) -> void:
	var detector := CodexWorld.new()
	var here := Vector3(10.0, 2.0, 10.0)
	var got := []
	var collect := func(out: Array): for row in out: got.append(row["id"])
	# The five existing recipes retain world_codex_test's order and simulated delays.
	collect.call(detector.note("element", {"material": "water", "behaviour": "electrify", "at": here}))
	detector.advance(1.0)
	collect.call(detector.note("kill", {"at": here + Vector3(5.0, 0.0, 0.0), "in_water": true}))
	collect.call(detector.note("gate", {"id": "surge_run", "at": here, "tier": 3}))
	collect.call(detector.note("airborne", {"at": here, "off_kicker": true}))
	detector.advance(1.0)
	collect.call(detector.note("slam", {"at": here}))
	collect.call(detector.note("jump", {"at": here, "tailwind": true}))
	collect.call(detector.note("element", {"material": "water", "behaviour": "create_surface", "at": here}))
	detector.advance(2.0)
	collect.call(detector.note("grounded", {"at": here + Vector3(3.0, 0.0, 0.0), "over_water": true}))
	t.eq("existing recipe order", got, ["live_wire_flood", "surge_slingshot", "sluice_hammer", "squall_sail", "ice_bridge"])
	for id in WORLD_IDS:
		t.check("new recipe stays undiscovered " + id, not got.has(id) and not detector.fired.has(id))


func _filled(row: Dictionary, fields: Array) -> bool:
	for field in fields:
		var value = row.get(field)
		if not value is String or value.strip_edges().is_empty():
			return false
	return true


func _unique_ids(rows: Array) -> bool:
	var seen := {}
	for row in rows:
		var id := String(row.get("id", ""))
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
