extends SceneTree

const Game := preload("res://src/game.gd")
const Roster := preload("res://src/combat/roster.gd")
const Holds := preload("res://src/combat/holds.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")

# No reskins (DESIGN-V2 section 10, Andrew's rule) and the roster's other promises:
# - every enemy id owns a mechanic tag no other id has, and says in one line what the
#   player must do about it;
# - every warn tag is unique and a real sound; the Fleet's voice and each ancient
#   family's voice are two timbre families that never cross;
# - every hold is broken by the player's own action, at least one of boost, jump, smash;
# - every reinforcement spawns as its own kind in its faction;
# - a pack spawned in one frame is one pack_arrived per faction, with the faction's
#   fac_ icon; a chaser alone is not a pack.

const OWN_ACTIONS := ["boost", "jump", "smash"]

var _game
var _failures := 0
var _step := 0
var _packs: Array = []


func _initialize() -> void:
	_data()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _data() -> void:
	var shared: Array = []
	var owners := Roster.mechanic_owners()
	for mechanic in owners:
		if (owners[mechanic] as Array).size() != 1:
			shared.append([mechanic, owners[mechanic]])
	var lines_ok := true
	for id in Roster.ROWS:
		lines_ok = lines_ok and String(Roster.ROWS[id].get("line", "")).length() > 20
	_report("no shared mechanics", shared.is_empty() and owners.size() == Roster.ROWS.size() and lines_ok,
		"%d enemy ids, %d mechanic tags, shared %s" % [Roster.ROWS.size(), owners.size(), shared])

	var tags := {}
	var dup: Array = []
	var unbaked: Array = []
	for id in Roster.COUNTERS + Roster.ANCIENTS:
		var tag := String(Roster.row(id)["tag"])
		if tag == "" or tags.has(tag):
			dup.append([id, tag])
		tags[tag] = id
		for motif in ["sable", "rivet", "kest"]:
			var heard := Roster.voiced(tag, motif)
			if not SfxBank.has_recipe(heard):
				unbaked.append(heard)
	_report("one tag per entry", dup.is_empty() and unbaked.is_empty(),
		"%d reinforcement tags, duplicate or empty %s, not a baked sound %s" % [tags.size(), dup, unbaked])

	var fleet_voice := String(Roster.faction(Roster.FLEET)["voice"])
	var crossed: Array = []
	for family in Roster.WARDEN_FAMILIES:
		var voice := String(Roster.faction(family)["voice"])
		if voice == fleet_voice or not Roster.is_ancient(family):
			crossed.append(family)
	_report("two timbre families", crossed.is_empty() and not Roster.is_ancient(Roster.FLEET),
		"Fleet voice %s; ancient voices %s; crossed %s" % [fleet_voice,
			Roster.WARDEN_FAMILIES.map(func(f): return Roster.faction(f)["voice"]), crossed])

	var unbreakable: Array = []
	for id in Roster.ROWS:
		var row: Dictionary = Roster.ROWS[id]
		if not row["holds"]:
			continue
		var own := false
		for method in row["breaks"]:
			own = own or method in OWN_ACTIONS
			if not method in Holds.PLAYER_BREAKS:
				unbreakable.append([id, method])
		if not own:
			unbreakable.append([id, "no boost, jump or smash"])
	_report("every hold breaks", unbreakable.is_empty(), "holding rows whose breaks are not the player's own: %s" % [unbreakable])

	# 2026-10-04, alpha wave 8: the world 2 and 3 kinds are declared ahead of their scripts.
	# 2026-10-17: seven with the pit jaw (design-v3/WORLD-ROSTERS.md); eight with the prop crew (stage/alpha-w16).
	# 2026-10-18 (w17 fix): ten with 3059e90's Highdraft ballast heavy and gap net; was 8.
	var declared: Array = Roster.world_kinds(2) + Roster.world_kinds(3)
	# 2026-10-04: built tracks the script file, so a wave 9 unit that adds one needs no edit here.
	var mismatched: Array = []
	var built: Array = []
	for id in declared:
		var has_script := ResourceLoader.exists(String(Roster.row(id).get("script", "")))
		if Roster.built(id):
			built.append(id)
		if Roster.built(id) != has_script:
			mismatched.append(id)
	_report("declared kinds are built exactly when their script exists", declared.size() == 10 and mismatched.is_empty(), "declared %s; built %s; mismatched %s" % [declared, built, mismatched])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	var ctx = _game.ctx
	var ball: Vector3 = ctx.terrain.spawn_point(1)
	match _step:
		0:
			ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_game.run.set_max_hp(99999.0)
			_game.events.pack_arrived.connect(func(faction: String, at: Vector3, kinds: Array): _packs.append([faction, kinds, at]))
			var wrong: Array = []
			var kinds: Array = Roster.ROWS.keys().filter(func(id): return Roster.built(id))
			for i in kinds.size():
				var kind: String = kinds[i]
				var at: Vector3 = ball + Vector3(cos(i * 0.6) * 40.0, 0.0, sin(i * 0.6) * 40.0)
				var unit: Node3D = ctx.spawner.spawn_enemy(kind, ctx.terrain.drop_point(at.x, at.z, 2.0))
				if unit == null or unit.kind != kind or unit.faction != Roster.faction_of(kind) or not unit.is_in_group("enemy"):
					wrong.append(kind)
			_report("every kind spawns as itself", wrong.is_empty(), "%d built kinds spawned; wrong %s" % [kinds.size(), wrong])
			_step = 1
		1:
			var factions := {}
			for p in _packs:
				factions[p[0]] = factions.get(p[0], 0) + 1
			_report("one pack per faction per frame", factions.get("fleet", 0) == 1 and factions.get("reactor", 0) == 1
					and factions.get("swarm", 0) == 1 and factions.get("mind", 0) == 1,
				"one frame's spawns arrived as %s" % [factions])
			for node in _game.get_tree().get_nodes_in_group("enemy"):
				node.queue_free()
			_packs.clear()
			_step = 2
		2:
			var at: Vector3 = ball + Vector3(30.0, 0.0, 0.0)
			ctx.spawner.spawn_enemy("mag_trapper", ctx.terrain.drop_point(at.x, at.z, 1.8))
			ctx.spawner.spawn_enemy("bola_thrower", ctx.terrain.drop_point(at.x + 4.0, at.z, 1.8))
			_step = 3
		3:
			var ok: bool = _packs.size() == 1 and _packs[0][0] == "fleet" and _packs[0][1] == ["mag_trapper", "bola_thrower"]
			var icons_ok := true
			for faction in [Roster.FLEET] + Roster.WARDEN_FAMILIES:
				icons_ok = icons_ok and Icons.has(EventKinds.faction_icon(faction))
			_report("pack_arrived", ok and icons_ok and EventKinds.ROWS["pack_arrived"]["color"] == EventKinds.color("event_announced"),
				"a trapper and a thrower in one frame: %s; every faction has its fac_ icon %s" % [_packs, icons_ok])
			_packs.clear()
			ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(ball.x - 30.0, ball.z, 1.8))
			_step = 4
		4:
			_report("fodder is not a pack", _packs.is_empty(), "a lone chaser published %d pack_arrived" % _packs.size())
			var ok := _failures == 0
			print("enemy_roster_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
			_game.free()
			quit(0 if ok else 1)
			return true
	return false
