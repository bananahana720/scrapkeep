extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Roster := preload("res://src/combat/roster.gd")
const Director := preload("res://src/world/director.gd")
const Activities := preload("res://src/world/activities.gd")
const AmbushAltar := preload("res://src/world/ambush_altar.gd")
const Worlds := preload("res://src/core/worlds.gd")
const CombatCodex := preload("res://src/combat/codex_entries.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")
const CodexWorld := preload("res://src/world/codex_world.gd")

# Every enemy kind that can spawn has a codex entry with a trick and a detector that can
# fire it, and every world codex row has a detector. Reachable kinds are collected from
# every stage table the game can pick (game.gd TABLES): each row's authored packs and
# elite (or, with no authored packs, the director's own packs and the row's ancient),
# its map's activity sites, its Warden and the Warden's guard, the vault when the table
# has one, the miniboss when the row has timed events, and the world bosses' summons. A
# detector reference is a DETECTORS row naming a script whose source fires the entry's id.

# Spawns written into code rather than a table, each cited where it happens.
const WARDEN_GUARD := "swarm_remnant"  # combat/warden.gd guard_kind(); brood's lamp_swarm is in its packs
const BOSS_SUMMONS := {
	"brindle": ["lobber"],  # boss/boss.gd: ctx.spawner.spawn_enemy("lobber", ...)
	"waking": [],
	"mind": ["mind_hand"],  # boss/mind.gd: ctx.spawner.spawn_enemy("mind_hand", ...)
}

# Roster kinds no table, site or summon reaches today. Each keeps its script and gets no
# new entry (ST4 ruling 1); the test fails if one becomes reachable, so its entry is written then.
const NEVER_SPAWNS := ["miniboss", "vault", "netcaster", "bola_thrower", "gyro_jammer", "swatter",
	"ramp_flipper", "catch_trap", "reactor_relic", "hooker", "dispatcher", "jolt_layer"]


func _initialize() -> void:
	var t := T.new("codex_coverage_test")
	var reach := _reachable(t)
	_check_enemies(t, reach)
	_check_never(t, reach)
	_check_combat_detectors(t)
	_check_world(t)
	_check_bosses(t)
	quit(t.verdict())


# {kind: [variants]}: every kind some table can spawn, with the Warden's variants.
func _reachable(t) -> Dictionary:
	var reach := {}
	var park_sites := {}
	for id in Game.TABLES:
		var table = Game.TABLES[id]
		for row in table.DEFS:
			var packs: Array = row.get("packs", table.packs())
			for pack in packs:
				_add_all(reach, pack["kinds"])
			_add_all(reach, row.get("elite", table.elite()).get("kinds", []))
			if packs.is_empty():
				_add_all(reach, ["chaser", "lobber", String(row.get("ancient", ""))])
				for pack_id in Director.PACKS:
					_add_all(reach, [Director.PACKS[pack_id]["controller"], Director.PACKS[pack_id]["punisher"]])
			_add(reach, "warden", String(row.get("warden_variant", "")))
			if String(row.get("warden_family", "")) == Roster.SWARM:
				_add(reach, WARDEN_GUARD)
			if not row.get("event_mix", {}).is_empty():
				_add(reach, "miniboss")
			var map = Terrain.map_named(String(row["map"]), int(row["stage"]))
			_add_sites(reach, map)
			if String(row["map"]).begins_with("park_"):
				_add_sites(park_sites, map)
		if table.has_vault():
			_add(reach, "vault")
	for world in Worlds.ROWS:
		_add_all(reach, BOSS_SUMMONS.get(String(world["boss"]), []))
	_add_all(reach, AmbushAltar.PACK)
	t.check("park site kinds found", not park_sites.is_empty(), "%d kinds: %s" % [park_sites.size(), park_sites])
	return reach


func _add_sites(reach: Dictionary, map) -> void:
	for site in map.activity_sites:
		var rule: Dictionary = Activities.RULES.get(site["id"], {})
		_add_all(reach, site.get("pack", rule.get("pack", [])))
		if rule.has("kind"):
			_add(reach, String(rule["kind"]))


func _add_all(reach: Dictionary, kinds: Array) -> void:
	for kind in kinds:
		_add(reach, String(kind))


func _add(reach: Dictionary, kind: String, variant := "") -> void:
	if kind == "":
		return
	if not reach.has(kind):
		reach[kind] = []
	if variant != "" and not variant in reach[kind]:
		reach[kind].append(variant)


func _check_enemies(t, reach: Dictionary) -> void:
	t.check("reachable kinds found", reach.size() >= 10, "%d kinds: %s" % [reach.size(), reach])
	for kind in reach:
		t.check("roster row " + kind, Roster.has(kind))
		t.check("entry for " + kind, _covered(kind, ""), "an entry whose detector names %s" % kind)
		for variant in reach[kind]:
			t.check("entry for %s %s" % [kind, variant], _covered(kind, variant), "an entry for the %s variant" % variant)


# An entry for the kind and variant ("" is the shared entry) that is declared, has a trick,
# and whose detector script fires it.
func _covered(kind: String, variant: String) -> bool:
	for id in CombatCodex.DETECTORS:
		var row: Dictionary = CombatCodex.DETECTORS[id]
		if row["kind"] == kind and String(row.get("variant", "")) == variant and _fires(id, row["script"]):
			return true
	return false


func _fires(id: String, script: String) -> bool:
	var entry := {}
	for row in CombatCodex.all():
		if row["id"] == id:
			entry = row
	if entry.is_empty() or String(entry["text"]).strip_edges() == "" or String(entry["clue"]).strip_edges() == "":
		return false
	return script != "" and FileAccess.get_file_as_string(script).contains('discover("%s"' % id)


func _check_never(t, reach: Dictionary) -> void:
	for kind in NEVER_SPAWNS:
		t.check("never spawns " + kind, Roster.has(kind) and not reach.has(kind), "no table, site or summon reaches it")
	for kind in Roster.ROWS:
		t.check("accounted " + kind, reach.has(kind) or kind in NEVER_SPAWNS, "reachable, or listed as never spawning")


func _check_combat_detectors(t) -> void:
	for id in CombatCodex.ids():
		var row: Dictionary = CombatCodex.DETECTORS.get(id, {})
		t.check("combat detector " + id, not row.is_empty() and _fires(id, String(row.get("script", ""))),
			"DETECTORS row %s" % [row])
	for id in CombatCodex.DETECTORS:
		t.check("detector row declared " + id, id in CombatCodex.ids())


func _check_world(t) -> void:
	for row in CodexWorld.ENTRIES:
		var id: String = row["id"]
		var script := String(CodexWorld.DETECTORS.get(id, ""))
		var source := FileAccess.get_file_as_string(script) if script != "" else ""
		var fires: bool
		if script == "res://src/world/codex_world.gd":
			fires = source.contains('_fire("%s"' % id)
		else:
			fires = source.contains('"id": "%s"' % id) or source.contains('_mark("%s"' % id) or source.contains('entry("%s")' % id)
		t.check("world detector " + id, fires, "script '%s' fires it" % script)


func _check_bosses(t) -> void:
	for boss in Worlds.BOSSES:
		t.check("boss rows " + boss, not BossCodex.for_boss(boss).is_empty())
