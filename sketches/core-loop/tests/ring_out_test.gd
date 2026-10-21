extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")

# Ring-outs (design-v3/WORLD-ROSTERS.md, Andrew's "Ring-outs" tap): in the Highdraft an enemy
# knocked off an island edge is gone and counts as the pilot's kill. A knock that leaves it on
# the island, a throw that lands back on it, an enemy that walks off with no knock, and the
# kept kinds are not rung out. The Spillway keeps its rescue.

class HighdraftGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/highdraft_world_three_defs.gd")

var game
var t := T.new("ring_out_test")
var rung := []
var killed := []


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _boot(highdraft: bool) -> void:
	game = HighdraftGame.new() if highdraft else preload("res://src/game.gd").new()
	game.test_mode = true
	if not highdraft:
		game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	game.events.enemy_ringed_out.connect(func(kind: String, _at: Vector3): rung.append(kind))
	game.events.enemy_killed.connect(func(kind: String, _at: Vector3, _scrap: int): killed.append(kind))


# A spot on the spawn island, `out` metres from its centre toward +Z, on its flat top.
func _on_island(out: float) -> Vector3:
	var island: Dictionary = Highdraft.ISLANDS["spawn"]
	var at := Vector3(island["at"].x, 0.0, island["at"].y + out)
	at.y = game.ctx.terrain.height(at.x, at.z) + 1.2
	return at


func _spawn(at: Vector3):
	var unit = game.combat.spawn_enemy("lobber", at)
	unit.hp = 100000.0
	await _frames(20)
	return unit


func _edge() -> void:
	# The ball sits on the far side of the island, so nothing else reaches the lobber.
	game.player.reset_to(_on_island(-12.0))
	var unit = await _spawn(_on_island(15.0))
	t.check("rings out in the Highdraft", unit.ring_outs_here(), "world %d" % game.ctx.terrain.world())
	var kills_before: int = game.run.kills
	unit.knock(Vector3(0.0, 0.0, 1.0), 40.0 * unit.weight)
	var frames := 0
	while is_instance_valid(unit) and not unit.is_dead() and frames < 240:
		await physics_frame
		frames += 1
	t.check("a knock off the island edge rings it out", rung.has("lobber") and (not is_instance_valid(unit) or unit.ringed_out), "%d frames, rung %s" % [frames, rung])
	t.eq("and it is the pilot's kill", game.run.kills, kills_before + 1)
	t.check("enemy_killed follows the ring-out", killed.has("lobber"), "")


# The ball's own ram (player_ball.gd) at its plain strength, on a lobber at the rim.
func _ram() -> void:
	rung.clear()
	var unit = await _spawn(_on_island(17.5))
	unit.knock(Vector3(0.0, 0.0, 1.0) + Vector3.UP * 0.35, Augments.RAM_KNOCK)
	var frames := 0
	while is_instance_valid(unit) and not unit.is_dead() and frames < 240:
		await physics_frame
		frames += 1
	t.check("a plain ram rings out a lobber at the rim", rung.has("lobber"), "%d frames" % frames)


# A ram straight down a beacon ramp (map_highdraft.gd RAMPS, 14 m over 44 m) slides the
# enemy downhill, part on its feet and part in a hop over the ramp: it drops metres but the
# ground under it stays close, so it is not rung out.
func _ramp() -> void:
	rung.clear()
	var line: Dictionary = Highdraft.new().ramp_line(Highdraft.RAMPS[0])
	var rim: Vector2 = line["rim"]
	var down: Vector2 = ((line["foot"] as Vector2) - rim).normalized()
	var spot: Vector2 = rim + down * 6.0
	var at := Vector3(spot.x, game.ctx.terrain.height(spot.x, spot.y) + 1.2, spot.y)
	var z := spot.y
	var unit = await _spawn(at)
	var start: float = unit.global_position.y
	# A ram at a light enemy's speed: the knock is per weight.
	unit.knock(Vector3(down.x, 0.0, down.y) + Vector3.UP * 0.35, Augments.RAM_KNOCK * unit.weight)
	var lowest := start
	for frame in 150:
		await physics_frame
		if not is_instance_valid(unit) or unit.is_dead():
			break
		lowest = minf(lowest, unit.global_position.y)
	t.check("a ram down a ramp carries it more than 4 m downhill", is_instance_valid(unit) and start - lowest > 4.0, "dropped %.1f m from z %.1f" % [start - lowest, z])
	t.check("and it is not rung out on its feet", rung.is_empty() and is_instance_valid(unit) and not unit.is_dead(), "rung %s" % [rung])
	if is_instance_valid(unit):
		unit.free()


func _stays() -> void:
	rung.clear()
	var unit = await _spawn(_on_island(-2.0))
	unit.knock(Vector3(1.0, 0.0, 0.0), 8.0 * unit.weight)
	await _frames(120)
	t.check("a knock that leaves it on the island does not", is_instance_valid(unit) and not unit.is_dead() and rung.is_empty(), "")
	t.eq("and the knock closes once it settles", unit._ring_from, INF)
	unit.knock(Vector3.UP, 30.0 * unit.weight)
	unit._knock = Vector3(1.5, unit._knock.y, 0.0)
	var frames := 0
	while frames < 30 or (not unit.is_on_floor() and frames < 400):
		await physics_frame
		frames += 1
	t.check("a throw that lands back on the island does not", is_instance_valid(unit) and unit.is_on_floor() and not unit.is_dead() and rung.is_empty(),
		"landed after %d frames at y %.1f" % [frames, unit.global_position.y])
	unit.free()


func _walks_off() -> void:
	var island: Dictionary = Highdraft.ISLANDS["spawn"]
	var past := Vector3(island["at"].x, island["top"] + 1.0, island["at"].y + island["radius"] + Highdraft.SKIRT + 6.0)
	var unit = game.combat.spawn_enemy("lobber", past)
	unit.hp = 100000.0
	await _frames(5)
	# A bolt knocks it while it falls: the knock struck it in the air, so it opens nothing.
	unit.knock(Vector3(0.0, 0.0, 1.0), 30.0 * unit.weight)
	await _frames(120)
	t.check("one that drops off with no knock, or is knocked mid-fall, is not rung out", is_instance_valid(unit) and not unit.is_dead() and rung.is_empty(), "y %.1f" % unit.global_position.y)
	unit.kind = "linker"
	t.check("the kill-first specials are always rescued", not unit.ring_outs_here(), "")
	unit.kind = "warden"
	t.check("and so are Wardens", not unit.ring_outs_here(), "")
	unit.free()


func _spillway() -> void:
	await _boot(false)
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	var unit = game.combat.spawn_enemy("lobber", game.ctx.terrain.drop_point(spawn.x + 8.0, spawn.z, 1.2))
	await _frames(5)
	t.eq("the Spillway is world 1", game.ctx.terrain.world(), 1)
	t.check("and keeps its rescue", not unit.ring_outs_here(), "")
	unit.free()


func _run() -> void:
	await _boot(true)
	await _edge()
	await _ram()
	await _ramp()
	await _stays()
	await _walks_off()
	game.free()
	await _spillway()
	game.free()
	quit(t.verdict())
