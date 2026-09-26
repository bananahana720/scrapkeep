extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")

# The catalogue change request (DEMO-SPEC, reconciled.json, owner B): every row has a
# verb, a punch value and one or two known tags; only common rows may be
# percentage-only; of 50 seeded gate pairs each holds a part that raises punch or
# transforms a pattern; rarity follows source (gate tiers by bonus cores, fabricator
# uncommon, vault rare, milestone rare-plus); a vault kill adds exactly one rare part
# with source "vault"; and the gate label reads "{name}: {verb}. Punch +{n}".

var _game
var _failures := 0
var _ticks := 0
var _gained: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_game.events.part_gained.connect(func(id: String, source: String): _gained.append([id, source]))
		return false
	if _ticks < 12:
		return false
	_check_rows()
	_check_gate_pairs()
	_check_sources()
	_check_vault()
	_check_label()
	print("build_catalogue_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_rows() -> void:
	var bad: Array = []
	var plain_above_common: Array = []
	var tags_used := {}
	for part_id in Parts.ids():
		var d: Resource = Parts.def(part_id)
		if d.verb == "" or d.punch < 0.0 or d.tags.is_empty() or d.tags.size() > 2 or not d.rarity in PartDef.RARITIES:
			bad.append(part_id)
		for tag in d.tags:
			if not tag in PartDef.TAGS:
				bad.append("%s tag %s" % [part_id, tag])
			tags_used[tag] = true
		if d.rarity != "common" and d.percentage_only():
			plain_above_common.append(part_id)
	_report("every row has verb, punch and tags", bad.is_empty() and tags_used.size() == PartDef.TAGS.size(),
		"%d rows; rows missing a verb or with 0 or 3+ tags or an unknown tag %s; %d of %d tags in use"
			% [Parts.ids().size(), bad, tags_used.size(), PartDef.TAGS.size()])
	_report("no plain rows above common", plain_above_common.is_empty(),
		"uncommon, rare and rare-plus rows that only scale numbers: %s" % [plain_above_common])


func _check_gate_pairs() -> void:
	var rng := RandomNumberGenerator.new()
	var soft: Array = []
	for seed_value in 50:
		rng.seed = 1000 + seed_value
		var cores := seed_value % 3
		var pair: Array = Parts.roll(rng, Parts.gate_rarities(cores), "runner_gunner", [], 2)
		if pair.size() != 2 or not pair.any(func(key): return Parts.def(key).hits_harder()):
			soft.append(pair)
	_report("gate pairs hit harder", soft.is_empty(),
		"50 seeded gate pairs across 0 to 2 bonus cores; pairs with no punch or pattern part: %s" % [soft])


func _check_sources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wrong: Array = []
	var expect := {0: ["common", "uncommon"], 1: ["uncommon", "rare"], 2: ["rare", "rare_plus"], 3: ["rare", "rare_plus"]}
	for cores in expect:
		if Parts.gate_rarities(cores) != expect[cores]:
			wrong.append("gate %d cores %s" % [cores, Parts.gate_rarities(cores)])
	for source in ["fabricator", "vault", "milestone"]:
		for i in 60:
			var picks: Array = Parts.roll(rng, Parts.SOURCE_RARITIES.get(source, []), "pylon_engineer", [], 1)
			if source == "milestone":
				picks = [Parts.milestone_for("event_%d" % i, [])]
			if picks.is_empty() or Parts.def(picks[0]).rarity != Parts.SOURCE_RARITIES[source][0]:
				wrong.append("%s gave %s" % [source, picks])
				break
	_report("rarity by source", wrong.is_empty(),
		"gates: 0 cores common/uncommon, 1 uncommon/rare, 2+ rare/rare-plus; fabricator uncommon, vault rare, milestone rare-plus; wrong %s" % [wrong])


func _check_vault() -> void:
	var before: int = _game.run.parts.size()
	_gained.clear()
	_game.run.record_kill("vault", _game.player.ball_position() + Vector3(4.0, 0.0, 0.0), 0)
	var ok: bool = _gained.size() == 1 and _gained[0][1] == "vault" and Parts.def(_gained[0][0]).rarity == "rare" \
		and _game.run.parts.size() == before + 1
	_game.run.record_kill("chaser", _game.player.ball_position(), 0)
	_report("vault pays a rare part", ok and _game.run.parts.size() == before + 1,
		"a vault kill published %s; a chaser kill after it added nothing" % [_gained])


func _check_label() -> void:
	var line := Parts.headline("slag_rounds")
	var plain := Parts.headline("loose_trigger")
	_report("gate label", line == "Slag Rounds: Shots land heavy. Punch +10" and plain == "Loose Trigger: Fire faster.",
		"'%s' and '%s'" % [line, plain])
