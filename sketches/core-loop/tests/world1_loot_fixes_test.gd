extends SceneTree

const Game := preload("res://src/game.gd")
const Parts := preload("res://src/build/parts.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const T := preload("res://tests/support/t.gd")

# World 1 items and progression (Codex world 1 review on main d561e6eb, 24 Oct; design #2, #3,
# #5, #6 and feel #2). On the park table, the one a launched game and --profile=sitting play:
# 1. Every alpha part drops, and every maker set completes for every pilot from what the
#    table's sources offer (it was an eighteen-part list: 27 parts never dropped, three sets
#    could not complete).
# 2. Spare Frame, the earned save, has a source: the relic tier, for every pilot.
# 3. Actives are on by default, and a run opens racked.
# 4. Punch Rivet panels add their flat damage to a weapon hit and a ball contact, not to procs.
# 5. The damage a hit's listeners read (the damage number, crit flash and hit-stop) is what
#    the hit removed, armour multiplier included.
# 6. The ram preview reads base cruise: a cruise up never drops it below CRUISE.
# smoke: timeout=180s

const RIVETS := 5
const PUNCH := 30.0

var _t := T.new("world1_loot_fixes_test")
var _game
var _ticks := 0


func _initialize() -> void:
	_check_parts()
	_check_spare_frame()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check_parts() -> void:
	var missing: Array = AlphaDefs.PARTS.filter(func(id): return not ParkDefs.part_in_play(id))
	_t.check("the park table offers every alpha part", missing.is_empty() and ParkDefs.PARTS.size() == 49,
		"%d parts, missing %s" % [ParkDefs.PARTS.size(), missing])
	var before = Synergies.table
	Synergies.table = ParkDefs
	var short: Array = []
	for def in ClassDef.all():
		var pool: Array = Parts.offer_pool(def.id, ItemGen.RARITIES)
		for maker in MakerSets.SETS:
			var offered: Array = pool.filter(func(id): return Parts.maker_of(id) == maker)
			if offered.size() < MakerSets.SETS[maker]["pieces"]:
				short.append("%s for %s (%s)" % [maker, def.id, offered])
	Synergies.table = before
	_t.check("every maker set completes for every pilot from park offers", short.is_empty(), "short: %s" % [short])


func _check_spare_frame() -> void:
	var before = Synergies.table
	Synergies.table = ParkDefs
	var without: Array = []
	var relics := {}
	for def in ClassDef.all():
		var pool: Array = Parts.offer_pool(def.id, ["relic"])
		relics[def.id] = pool
		if not "spare_frame" in pool:
			without.append(def.id)
	Synergies.table = before
	_t.check("Spare Frame drops at relic tier for every pilot", without.is_empty() and Parts.row("spare_frame")["rarity"] == "relic",
		"pilots without it: %s; relic pools %s" % [without, relics])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_t.eq("actives default on", _game.tuning.option("actives"), "on")
		_game.flow.press_start()
		_game.flow.choose_class(0)
	elif _ticks == 20:
		var rack = _game.combat.get("actives")
		_t.check("a run opens with an active racked", rack != null and rack.enabled() and rack.active_id != "",
			"racked %s" % (rack.active_id if rack != null else "no rack"))
		_check_punch_rivet()
		_check_shown_damage()
		_check_ram_preview()
		_game.free()
		quit(_t.verdict())
		return true
	return false


func _chaser(offset: float) -> Node3D:
	var terrain = _game.ctx.terrain
	var at: Vector3 = terrain.spawn_point(1) + Vector3(offset, 0.0, 14.0)
	var enemy: Node3D = _game.ctx.spawner.spawn_enemy("chaser", terrain.drop_point(at.x, at.z, 1.5))
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.plating = 0.0
	enemy.hp = 1000.0
	return enemy


func _loss(kind: String, force: float, source := "") -> float:
	var enemy := _chaser(0.0)
	var before: float = enemy.hp
	_game.combat.strike(enemy, kind, force, "", source)
	var lost := before - float(enemy.hp)
	enemy.queue_free()
	return lost


func _set_rivets(n: int) -> void:
	_game.ctx.run.panels.clear()
	for i in n:
		_game.ctx.run.panels.append("punch_rivet")
	_game.ctx.build.recompute()


func _check_punch_rivet() -> void:
	_set_rivets(0)
	var bolt := _loss("frost", PUNCH, "weapon")
	var ram := _loss("ram", 20.0)
	var proc := _loss("synergy", PUNCH)
	_set_rivets(RIVETS)
	_t.near("Punch Rivet panels read through the build", _game.ctx.build.panel_punch(), float(RIVETS))
	var bolt_r := _loss("frost", PUNCH, "weapon")
	var ram_r := _loss("ram", 20.0)
	var proc_r := _loss("synergy", PUNCH)
	_t.check("rivets add to a weapon hit", bolt_r - bolt >= RIVETS - 0.001, "%.2f -> %.2f" % [bolt, bolt_r])
	_t.check("rivets add to a ram", ram_r - ram >= RIVETS - 0.001, "%.2f -> %.2f" % [ram, ram_r])
	_t.near("rivets leave a proc alone", proc_r, proc, 0.001)
	# A special striking as "ram" keeps the panels' heft (their mass) but not their punch.
	var special_r := _loss("ram", 20.0, "special")
	_t.near("rivets leave a special's ram alone", special_r, ram_r - RIVETS, 0.001)
	_set_rivets(0)
	# would_crush asks the same punch the strike lands: a chaser between the bare ram and the
	# riveted ram is crushed, so the ball rolls through the kill instead of bouncing off it.
	_set_rivets(RIVETS)
	var enemy := _chaser(-8.0)
	enemy.hp = ram + RIVETS * 0.5
	var crush: bool = _game.combat.would_crush(enemy, "ram", 20.0)
	_game.combat.strike(enemy, "ram", 20.0)
	var killed: bool = not is_instance_valid(enemy) or enemy.is_dead()
	_t.check("would_crush matches a riveted ram's kill", crush and killed, "would_crush %s, killed %s" % [crush, killed])
	if is_instance_valid(enemy):
		enemy.queue_free()
	_set_rivets(0)


func _check_shown_damage() -> void:
	var shown := []
	var results := []
	var listen := func(enemy: Node3D, kind: String, force: float):
		var result: Dictionary = _game.combat.resolve(enemy, kind, force)
		results.append(result)
		shown.append(float(result["dealt"]))
	_game.ctx.events.enemy_struck.connect(listen)
	var enemy := _chaser(8.0)
	var before: float = enemy.hp
	_game.combat.strike(enemy, "arc", PUNCH)
	var lost := before - float(enemy.hp)
	_game.ctx.events.enemy_struck.disconnect(listen)
	_t.check("an arc hit on a wet chaser is raised by its armour", String(enemy.get_meta("armour_read", "")) == "weak" and lost > PUNCH * 1.4,
		"lost %.2f of %.1f, read %s" % [lost, PUNCH, enemy.get_meta("armour_read", "")])
	_t.check("the shown damage is the damage removed", shown.size() == 1 and absf(float(shown[0]) - lost) < 0.001,
		"shown %s, removed %.2f" % [shown, lost])
	_t.check("a weak armour read alone is no crit", results.size() == 1 and not DamageNumbers.is_crit(results[0], 0.0),
		"%s" % [results])
	enemy.queue_free()
	# A drill crew's plate takes the first breaking hit whole: the hit is marked absorbed, so no
	# number rises for the 0 it removes.
	results.clear()
	_game.ctx.events.enemy_struck.connect(listen)
	var terrain = _game.ctx.terrain
	var at: Vector3 = terrain.spawn_point(1) + Vector3(-16.0, 0.0, 14.0)
	var crew: Node3D = _game.ctx.spawner.spawn_enemy("drill_crew", terrain.drop_point(at.x, at.z, 1.5))
	crew.set_process(false)
	crew.set_physics_process(false)
	var hp_before: float = crew.hp
	_game.combat.strike(crew, "arc", 200.0)
	_game.ctx.events.enemy_struck.disconnect(listen)
	_t.check("a plate-absorbed hit is marked and removes nothing",
		results.size() == 1 and bool(results[0].get("absorbed", false)) and is_equal_approx(float(crew.hp), hp_before),
		"absorbed %s, hp %.1f -> %.1f" % [results[0].get("absorbed", false) if results.size() > 0 else "-", hp_before, crew.hp])
	crew.queue_free()


func _check_ram_preview() -> void:
	var player = _game.player
	var tuning = player.tuning
	var base: float = tuning.tier_cruise()
	player.state.velocity = Vector3(base * 0.6, 0.0, 0.0)
	tuning.set_mod("cruise", 1.5)
	var modded_tier: int = SpeedTier.of(player.state.velocity.length(), tuning.f("cruise"))
	var preview: float = _game.combat.ram_punch_now()
	tuning.set_mod("cruise", 1.0)
	player.state.velocity = Vector3.ZERO
	_t.check("a cruise up keeps the ram preview at CRUISE", modded_tier < SpeedTier.CRUISE and preview > 0.0,
		"modded tier %d, preview %.1f" % [modded_tier, preview])
