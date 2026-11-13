extends SceneTree

# Which enemies hold the director's cap (director.gd HOLD_M, NEVER_HOLDS, FAR_CEILING; world.gd director_held):
# 1. Rule: an enemy within HOLD_M of the ball holds a slot, one past it does not, the Warden never does, and once
#    FAR_CEILING enemies are alive in all the count is the hard cap, so nothing more comes.
# 2. The dam's opening as the bot traces showed it (13 Nov 2026, stage/alpha-w40): a pack of 3 passed at the drop-in
#    plus the Warden left 2 of the 6 slots, so every 3-pack was refused for 37 s. Replayed on the dam's staged
#    director with the ball rolled 200 m on: counted the new way, a pack places inside a minute. Planted: counted the
#    old way (every enemy), none does until the threat tier raises the cap at 45 s.

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/director.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

var t := T.new("director_hold_test")


func _initialize() -> void:
	_rule()
	_dam_opening()
	quit(t.verdict())


func _rule() -> void:
	var ball := Vector2(10.0, 20.0)
	t.check("a chaser beside the ball holds a slot", Director.holds("chaser", ball + Vector2(30.0, 0.0), ball))
	t.check("one on HOLD_M holds a slot", Director.holds("chaser", ball + Vector2(0.0, Director.HOLD_M), ball))
	t.check("one past HOLD_M does not", not Director.holds("chaser", ball + Vector2(0.0, Director.HOLD_M + 1.0), ball))
	t.check("the Warden never holds one, however near", not Director.holds("warden", ball, ball))
	t.eq("under the ceiling the count is the near enemies", Director.held_count(2, Director.FAR_CEILING - 1), 2)
	t.eq("at the ceiling the count is the hard cap", Director.held_count(2, Director.FAR_CEILING), Director.HARD_CAP)
	t.check("the ceiling sits above the hard cap, so near enemies reach the cap first", Director.FAR_CEILING > Director.HARD_CAP)


# Seconds until the staged dam director places its next pack, with `counted` enemies given to advance(); -1 if none in `limit`.
static func _first_place(counted: Callable, limit: float) -> float:
	var d := Director.new(3101)
	var row: Dictionary = ParkDefs.DEFS[0]
	d.author(row, ParkDefs)
	d.use_row(row)
	d.breathers = []
	# The drop-in pack and the Warden: the pack stands at the drop-in, the ball has rolled 200 m on.
	var spawn := Vector2(-150.0, -690.0)
	var ball := spawn + Vector2(0.0, 200.0)
	var standing := [["chaser", spawn], ["chaser", spawn + Vector2(4.0, 0.0)], ["boom_tender", spawn + Vector2(-4.0, 0.0)],
		["warden", Vector2(-46.0, -12.0)]]
	var steps := int(limit * 30.0)
	for i in steps:
		d.advance(1.0 / 30.0, counted.call(standing, ball), ball, Vector2(0.0, 18.0), Vector2(0.0, 1.0))
		if not d.arrivals.is_empty():
			return i / 30.0
	return -1.0


func _dam_opening() -> void:
	var held := func(standing: Array, ball: Vector2) -> int:
		var n := 0
		for e in standing:
			if Director.holds(e[0], e[1], ball):
				n += 1
		return Director.held_count(n, standing.size())
	var every := func(standing: Array, _ball: Vector2) -> int:
		return standing.size()
	var now := _first_place(held, 60.0)
	print("[hold] dam opening: next pack after %.1f s counted near the ball" % now)
	t.check("dam: with the passed pack and the Warden not holding slots, a pack places inside a minute", now >= 0.0, "%.1f" % now)
	var old := _first_place(every, 60.0)
	print("[hold] dam opening: next pack after %.1f s counting every enemy" % old)
	t.check("planted: counting every enemy, the 3-packs wait until the threat tier raises the cap (the 37 s gap)", old > 40.0, "%.1f" % old)
