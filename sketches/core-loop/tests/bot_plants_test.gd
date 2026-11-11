# smoke: solo (the bot tool layer's test-only plants: parsing, the dials they set, the damage wrap)
extends SceneTree

const BotPlants := preload("res://tools/bot_plants.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

# tools/bot_plants.gd: the anti-kiting gates' controls. Parsing refuses unknown names, bad numbers and the combined
# pack_damage + packs_passive; pack_damage and packs_passive set the mobs.damage_mult dial and nothing else; damage=K
# scales a hit before the run's own defend_hook reads it, keeps that hook, and is re-applied when the hook is replaced.
# With no plant, no BotPlants exists (tools/bot_run.gd), which tests/challenge_dials_test.gd and the skipper replay
# in the G-A receipt cover; this file does not run a game.

class FakeGame extends Node:
	var run
	var flow := {"warden": null}


var _t := T.new("bot_plants_test")
# Every run this file makes: their hooks are dropped at the end, or the closures keep them (and their class
# resources) alive past exit.
var _runs: Array = []


func _initialize() -> void:
	# The fake game joins the tree on the first frame, so get_tree() answers.
	await process_frame
	ChallengeDials.reset()
	_parse()
	_dials()
	_damage()
	ChallengeDials.reset()
	for run in _runs:
		run.defend_hook = Callable()
		run.events.free()
	_runs.clear()
	quit(_t.verdict())


func _parse() -> void:
	_t.eq("pack_damage parses", BotPlants.parse("pack_damage=4"), {"pack_damage": 4.0})
	_t.eq("rut parses", BotPlants.parse("rut=1"), {"rut": 1.0})
	_t.eq("the fairness plants parse", BotPlants.parse("drain=1,fast_tax=2,ringless=1"), {"drain": 1.0, "fast_tax": 2.0, "ringless": 1.0})
	_t.eq("two plants", BotPlants.parse("damage=2,hide_pack_telegraphs=1"), {"damage": 2.0, "hide_pack_telegraphs": 1.0})
	_t.check("an unknown name is refused", BotPlants.parse("nope=1").has("error"))
	_t.check("a bad number is refused", BotPlants.parse("damage=x").has("error"))
	_t.check("a negative number is refused", BotPlants.parse("damage=-1").has("error"))
	_t.check("pack_damage with packs_passive is refused", BotPlants.parse("pack_damage=4,packs_passive=1").has("error"))
	_t.check("an empty flag is refused", BotPlants.parse("").has("error"))
	_t.check("a missing value is refused", BotPlants.parse("damage").has("error"))


func _dials() -> void:
	_t.near("mobs damage is 1 with no plant", float(ChallengeDials.value("mobs.damage_mult")), 1.0)
	var game := _fake()
	var plants := BotPlants.new()
	plants.attach(game, null, {"pack_damage": 4.0})
	_t.near("pack_damage 4 sets the mobs dial", float(ChallengeDials.value("mobs.damage_mult")), 4.0)
	_t.near("and not the Warden's pulse", float(ChallengeDials.value("warden.pulse_damage_mult")), 1.0)
	_t.eq("the record names it", ChallengeDials.describe(), {"mobs.damage_mult": 4.0})
	ChallengeDials.reset()
	var passive := BotPlants.new()
	passive.attach(_fake(), null, {"packs_passive": 1.0})
	_t.near("packs_passive zeroes the mobs dial", float(ChallengeDials.value("mobs.damage_mult")), 0.0)
	ChallengeDials.reset()
	_t.near("reset restores the identity", float(ChallengeDials.value("mobs.damage_mult")), 1.0)


func _fake() -> FakeGame:
	var game := FakeGame.new()
	root.add_child(game)
	return game


func _run_state() -> RunState:
	var run := RunState.new(GameEvents.new())
	run.begin(ClassDef.new())
	_runs.append(run)
	return run


func _damage() -> void:
	var plain := _run_state()
	var before := plain.hp
	plain.damage(10.0, "chaser")
	var lost_plain := before - plain.hp
	var run := _run_state()
	var game := _fake()
	game.run = run
	var plants := BotPlants.new()
	plants.attach(game, null, {"damage": 2.0})
	run.damage(10.0, "chaser")
	_t.near("damage 2 doubles a hit", run.hp, before - 2.0 * lost_plain)
	# the set piece's own defence keeps working under the wrap: x0.5 here, so 10 -> 10
	var guarded := _run_state()
	game.run = guarded
	guarded.defend_hook = func(amount: float, _hp: float) -> float: return amount * 0.5
	plants.step()
	guarded.damage(10.0, "chaser")
	_t.near("the wrapped hook is kept and chained", guarded.hp, before - lost_plain)
	# a rebuilt hook is wrapped again on the next step
	guarded.defend_hook = func(amount: float, _hp: float) -> float: return amount * 0.25
	plants.step()
	var mid := guarded.hp
	guarded.damage(10.0, "chaser")
	_t.near("a replaced hook is wrapped again", mid - guarded.hp, 10.0 * 2.0 * 0.25 * (lost_plain / 10.0))
