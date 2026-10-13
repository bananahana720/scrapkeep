extends SceneTree

# Unit DOMINO-DET (wave 13, 2026-10-13): the domino chain roll reads a per-run serial, never the
# victim's object id, so two runs with the same clock and the same victims roll the same
# dominoes however many throwaway objects each run allocates between victims.
# - the roll is fposmod(clock * 7.31 + float(serial % 997) * Triggers.SPREAD, 1.0); the serial
#   counts one draw per _domino call that reaches the roll;
# - reset_stage restarts the serial, so a reset-and-redraw pass in the same instance repeats
#   the first pass;
# - each pass makes DRAWS draws and the test asserts the expected sequence from that formula.

const T := preload("res://tests/support/t.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Triggers := preload("res://src/build/triggers.gd")

const CLOCK := 2.5
const CHANCE := 0.5
const DRAWS := 12
# Checks made before the final "every check ran" check.
const EXPECTED_CHECKS := 5


class Victim extends Node3D:
	var weight := 1.0
	var knocks := 0

	func knock(_direction: Vector3, _force: float) -> void:
		knocks += 1

	func is_dead() -> bool:
		return false


class FakeBuild extends RefCounted:
	var near: Array = []

	func enemies_near(_at: Vector3, _radius: float, _limit: int) -> Array:
		return near


var _ran := false


# The checks run on the first frame, once the scene tree is live, so victims are inside the tree
# when their global positions are read.
func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_checks()
	return false


func _run_checks() -> void:
	var t := T.new("domino_roll_order_test")
	var expected: Array = []
	for i in DRAWS:
		expected.append(fposmod(CLOCK * 7.31 + float(i % 997) * Triggers.SPREAD, 1.0) < CHANCE)

	var build_a := FakeBuild.new()
	var fx_a := ItemEffects.new(build_a)
	fx_a._clock = CLOCK
	var first := _pass(fx_a, build_a, 0)
	t.eq("run one pass makes %d draws" % DRAWS, first.size(), DRAWS)
	t.eq("run one rolls the expected sequence from the serial", first, expected)
	var passes := 0
	for outcome in first:
		if outcome:
			passes += 1
	t.check("the sequence mixes passes and fails (%d of %d pass)" % [passes, DRAWS],
		passes >= 1 and passes < DRAWS, "at least one pass and one fail")

	fx_a.reset_stage()
	fx_a._clock = CLOCK
	var second := _pass(fx_a, build_a, 0)
	t.eq("reset_stage restarts the serial, so the next pass draws the same sequence", second, expected)

	var build_b := FakeBuild.new()
	var fx_b := ItemEffects.new(build_b)
	fx_b._clock = CLOCK
	var third := _pass(fx_b, build_b, 3)
	t.eq("a fresh run with throwaway allocations rolls the same sequence as run one", third, first)

	t.eq("every check ran", t.checks, EXPECTED_CHECKS)
	var code := t.verdict()
	print("domino_roll_order_test: %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)


# One domino draw per victim: each victim is fresh, with one neighbour 2 m away inside the
# 8 m reach. The per-window cap is cleared before each draw, so every draw reaches the roll.
# `throwaway` objects are allocated and freed before each victim, so instance IDs differ.
func _pass(fx: ItemEffects, build: FakeBuild, throwaway: int) -> Array:
	var outcomes: Array = []
	for i in DRAWS:
		fx._domino_count = 0
		var junk: Array = []
		for j in throwaway:
			junk.append(Node3D.new())
		var base := Vector3(float(i) * 40.0, 0.0, 0.0)
		var victim := Victim.new()
		var neighbor := Victim.new()
		root.add_child(victim)
		root.add_child(neighbor)
		victim.position = base
		neighbor.position = base + Vector3(2.0, 0.0, 0.0)
		build.near = [victim, neighbor]
		fx._domino("domino_test", _domino_part(), 1, victim)
		outcomes.append(victim.knocks > 0)
		victim.free()
		neighbor.free()
		for node in junk:
			node.free()
	return outcomes


func _domino_part() -> PartDef:
	var d := PartDef.new()
	d.effect = {"do": "domino", "chance": CHANCE, "speed": 10.0}
	return d
