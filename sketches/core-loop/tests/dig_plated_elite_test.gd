extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const T := preload("res://tests/support/t.gd")

# The Dig's plate theme (design-v3/WORLD-ROSTERS.md, Andrew's "Flow, Plate, Wind"): every
# member of a Dig elite pack arrives with armour "plated"; other packs and other worlds don't.

var game
var t := T.new("dig_plated_elite_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _run() -> void:
	game = preload("res://src/game.gd").new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(3)
	var director = game.ctx.root.get_node("World").director
	var ball: Vector3 = game.player.ball_position()
	var at := Vector2(ball.x + 20.0, ball.z)
	var flat := Vector2(ball.x, ball.z)
	for world in [2, 1]:
		director.world = world
		for elite in [true, false]:
			var before: int = director.arrivals.size()
			director._place_pack(at, ["drill_crew", "burrower"], flat, elite)
			var placed: Array = director.arrivals.slice(before)
			var plated := placed.filter(func(a: Dictionary): return a.get("affix", "") == EliteAffixes.PLATED)
			var want: int = placed.size() if world == 2 and elite else 0
			t.check("world %d %s pack: %d of %d arrive plated" % [world, "elite" if elite else "plain", want, placed.size()],
				placed.size() > 0 and plated.size() == want, "plated %d" % plated.size())
			director.arrivals.resize(before)
	var unit = game.combat.spawn_enemy("drill_crew", game.ctx.terrain.drop_point(at.x, at.y, 1.5), EliteAffixes.PLATED)
	t.eq("a plated spawn reads armour plated", unit.armour_class(), "plated")
	var plain = game.combat.spawn_enemy("drill_crew", game.ctx.terrain.drop_point(at.x + 4.0, at.y, 1.5))
	t.eq("a plain spawn reads no armour of its own", plain.armour_class(), "")
	t.check("the affix is no brute behaviour", EliteAffixes.row(EliteAffixes.PLATED).is_empty(), "")
	unit.free()
	plain.free()
	game.free()
	quit(t.verdict())
