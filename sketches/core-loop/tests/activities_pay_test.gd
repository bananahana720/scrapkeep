extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")
const Parts := preload("res://src/build/parts.gd")

# PARK.md 2.12's pay ladder: every activity kind takes pay.rarities (and pay.named) from its park
# row's spec, scrap stays PAY_SCRAP, and a park row naming a kind with no RULES row is caught.
# Sites are built and finished directly on a live game; the paid part's rarity is read from the
# table, so a named part is judged by its own tier. An ambush altar's authored pack replaces the rule's
# chaser pack (park_pit's bench3_altar, 2026-10-17), and an empty one keeps it. This does not qualify play feel.

const SEEDS := 20
const KINDS := ["cracked_cache", "ambush_altar", "hauler_bounty", "enemy_camp"]
const PARK_DIRS := ["res://src/world/park", "res://assets/park", "res://assets/park/park_test"]

var _t := preload("res://tests/support/t.gd").new("activities_pay_test")
var _game


func _initialize() -> void:
	_run()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.player.source = Intent.Scripted.new()
	_game.world.set_physics_process(false)
	_game.world.activities.set_physics_process(false)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	_game.world.activities.clear()
	_ladder()
	_defaults()
	_scrap_ignored()
	_named()
	_unruled_kinds()
	_altar_pack()
	_game.free()
	quit(_t.verdict())


# Build the kind with `pay` on its spec, finish it and return the part it offers ("" for none).
func _paid(kind: String, pay: Dictionary, seed_value: int) -> String:
	var acts = _game.world.activities
	acts.clear()
	_game.ctx.rng.seed = seed_value
	var spec := {"id": kind, "at": Vector2(0.0, 0.0)}
	if not pay.is_empty():
		spec["pay"] = pay
	var s = acts._build(kind, Vector2(0.0, 0.0), spec)
	acts.sites.append(s)
	acts._finish(s, Vector3.ZERO)
	return String(s.pickup_part)


func _rarities_over_seeds(kind: String, pay: Dictionary) -> Array:
	var seen := {}
	for i in SEEDS:
		var part := _paid(kind, pay, 100 + i)
		seen[Parts.rarity_of(part) if part != "" else "none"] = true
	return seen.keys()


func _ladder() -> void:
	# enemy_camp is left out: its row's named hot_rivets wins over rarities (see _named).
	for kind in ["cracked_cache", "ambush_altar", "hauler_bounty"]:
		_t.eq("%s rare ladder" % kind, _rarities_over_seeds(kind, {"rarities": ["rare"]}), ["rare"])
		_t.eq("%s common ladder" % kind, _rarities_over_seeds(kind, {"rarities": ["common"]}), ["common"])


func _defaults() -> void:
	# No pay key: the rule is the RULES row untouched, so the part rolled is today's roll.
	for kind in KINDS:
		var acts = _game.world.activities
		var s = acts._build(kind, Vector2.ZERO, {"id": kind, "at": Vector2.ZERO})
		_t.check("%s no pay key keeps its row" % kind, s.rule["pay"] == Activities.RULES[kind]["pay"], str(s.rule["pay"]))
		s.queue_free()
		for i in 5:
			var a := _paid(kind, {}, 200 + i)
			var b := _paid(kind, {"rarities": Activities.PAY_RARITIES}, 200 + i)
			if kind != "enemy_camp":
				_t.eq("%s default roll matches the common-or-rare row (seed %d)" % [kind, i], a, b)


func _scrap_ignored() -> void:
	for kind in KINDS:
		var acts = _game.world.activities
		var s = acts._build(kind, Vector2.ZERO, {"id": kind, "at": Vector2.ZERO, "pay": {"scrap": 5, "rarities": ["rare"]}})
		_t.eq("%s spec scrap ignored" % kind, int(s.rule["pay"]["scrap"]), Activities.PAY_SCRAP)
		_t.eq("%s spec rarities taken" % kind, s.rule["pay"]["rarities"], ["rare"])
		s.queue_free()


func _named() -> void:
	# Named wins over rarities when the table offers it; its own tier is what the ladder reads.
	for kind in KINDS:
		var part := _paid(kind, {"named": "hot_rivets", "rarities": ["rare"]}, 300)
		_t.eq("%s named wins over rarities" % kind, part, "hot_rivets")
		_t.eq("%s named part reads common" % kind, Parts.rarity_of(part), "common")
	_t.check("a named part of the wrong tier is caught",
		Parts.rarity_of("hot_rivets") != "rare", "hot_rivets is %s" % Parts.rarity_of("hot_rivets"))
	_t.eq("enemy_camp default pays hot_rivets as common", Parts.rarity_of(_paid("enemy_camp", {"named": "hot_rivets"}, 301)), "common")


# Every activity kind the checked-in park files name must have a RULES row; surge_run has no
# site in any park file today, so the list is empty.
func _unruled_kinds() -> void:
	var unruled := {}
	var scanned := 0
	for dir_path in PARK_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if not file.ends_with(".json"):
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if not parsed is Dictionary or not parsed.has("activity_rows"):
				continue
			scanned += 1
			for row in parsed["activity_rows"]:
				if not Activities.RULES.has(String(row["activity"])):
					unruled[String(row["activity"])] = true
	_t.check("park files with activity_rows were scanned", scanned >= 1, "%d files" % scanned)
	_t.eq("every park activity kind has a rule", unruled.keys(), [])


func _altar_pack() -> void:
	var acts = _game.world.activities
	var pack := ["drill_crew", "lamp_swarm", "drill_crew"]
	var s = acts._build("ambush_altar", Vector2.ZERO, {"id": "ambush_altar", "at": Vector2.ZERO, "pack": pack})
	_t.eq("ambush_altar takes its row's pack", s.rule["pack"], pack)
	s.queue_free()
	s = acts._build("ambush_altar", Vector2.ZERO, {"id": "ambush_altar", "at": Vector2.ZERO, "pack": []})
	_t.eq("ambush_altar empty pack keeps the rule's", s.rule["pack"], Activities.RULES["ambush_altar"]["pack"])
	s.queue_free()
	_t.eq("the rule's own pack is untouched", Activities.RULES["ambush_altar"]["pack"], ["chaser", "chaser", "lobber"])
