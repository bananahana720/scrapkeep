extends SceneTree

const GameScript := preload("res://src/game.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const T := preload("res://tests/support/t.gd")
const Worlds := preload("res://src/core/worlds.gd")
const StageTable := preload("res://src/core/stage_table.gd")

# A run across two worlds on the six-stage double: each world's last stage clears into
# that world's boss, the next world's first stage follows, and the run ends won after
# the last world's boss. Scenario A builds both boss rows; scenario B marks world two's
# row unbuilt, so its stages run with no arena. Scenario C runs three one-stage worlds
# with the real modules: Brindle (the scene's boss.gd) ends world one, and worlds two and
# three run waking.gd and mind.gd (picked from the Waking's and the Mind's rows), which
# extend the stub, its posture Warden broken chunk by chunk. Each stage is cleared by calling flow's own
# finish step, so the test pins the flow's routing, not the beacon, which spine_run_test
# covers.

const TICK_LIMIT := 60 * 60

# The game with the six-stage table in place of the default one.
class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld


# Three worlds of one stage each, on the three existing maps, with worlds.gd's own rows.
class ThreeWorld extends RefCounted:
	const BOSS := "brindle"
	const COUNT := 3
	const DEFS := [
		{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Spillway: the top shelf", "map": "spillway", "threat": 1.0, "unlock_base": 2, "ancient": "reactor_relic",
			"event_mix": {"flood": 1.0}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
			"warden_plating": 45.0, "warden_hp": 800.0, "warden_lesson": "plate", "warden_hint": "Ram it hard, right after it vents."},
		{"stage": 2, "world": 2, "music": {"theme": 1, "ace": ""}, "warden_family": "swarm", "name": "Triple: the Cable Reach", "map": "reach", "threat": 1.25, "unlock_base": 4, "ancient": "swarm_remnant",
			"event_mix": {"flood": 1.0}, "scrap_density": 1.2, "beacon_seconds": 30.0, "beacon_radius": 30.0,
			"warden_plating": 80.0, "warden_hp": 2200.0, "warden_lesson": "caps", "warden_hint": "Bowl through its guard rack and slam its caps."},
		{"stage": 3, "world": 3, "music": {"theme": 2, "ace": ""}, "warden_family": "mind", "name": "Triple: the Weir", "map": "reach", "threat": 2.1, "unlock_base": 6, "ancient": "mind_hand",
			"event_mix": {"flood": 1.0}, "scrap_density": 1.4, "beacon_seconds": 35.0, "beacon_radius": 28.0,
			"warden_plating": 140.0, "warden_hp": 7500.0, "warden_lesson": "magnet", "warden_hint": "In its ring, shoot the magnet while it pulls you."},
	]
	static func of(stage: int) -> Dictionary: return DEFS[clampi(stage, 1, COUNT) - 1]
	static func is_last(stage: int) -> bool: return stage >= COUNT
	static func world_of(stage: int) -> int: return StageTable.world_of(DEFS, stage)
	static func local(stage: int) -> int: return StageTable.local(DEFS, stage)
	static func first_of(world: int) -> int: return StageTable.first_of(DEFS, world)
	static func last_of(world: int) -> int: return StageTable.last_of(DEFS, world)
	static func worlds() -> Array: return StageTable.worlds(DEFS)
	static func is_world_last(stage: int) -> bool: return StageTable.is_world_last(DEFS, stage)
	static func is_run_last(stage: int) -> bool: return StageTable.is_last(DEFS, stage)
	static func synergy_in_play(_synergy_id: String) -> bool: return true
	static func part_in_play(_part_id: String) -> bool: return true
	static func parts_listed() -> bool: return false
	const PICK_ON_CLASS_UP := false
	static func packs() -> Array: return []
	static func elite() -> Dictionary: return {}
	static func elite_arrival() -> int: return 0
	static func has_vault() -> bool: return true


class ThreeWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return ThreeWorld

var _t := T.new("spine_worlds_test")
var _game
var _boss
var _built := true
var _ticks := 0
var _started := false
var _scenario := 0
var _done := false
var _worlds: Array[int] = []
var _entered: Array[int] = []
var _events: Array[String] = []
var _ended := false
var _won := false
var _last_stage := -1
var _replays: Array[int] = []
# Scenario C: the module script behind each arena, and the chunks each stub Warden lost.
var _modules: Array[String] = []
var _chunks: Array[int] = []
var _boss_kills := 0


func _initialize() -> void:
	# The flow is pinned with a smash-per-frame fight, not the fight's length: the PHASE_MIN_SECONDS hold
	# (waking.gd, mind.gd; tests/boss_phase_hold_test.gd) is multiplied out so each Warden falls inside the cap.
	ChallengeDials.set_overrides({"waking.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0], "mind.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]})
	_boot()


func _boot() -> void:
	_game = ThreeWorldGame.new() if _scenario == 2 else TwoWorldGame.new()
	_game.test_mode = true
	root.add_child(_game)
	_started = false
	_ticks = 0
	_worlds = []
	_entered = []
	_events = []
	_replays = []
	_ended = false
	_won = false
	_last_stage = -1
	_modules = []
	_chunks = []
	_boss_kills = 0


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if not _started:
		if _game.flow == null:
			return false
		_start()
		return false
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_t.check("timeout", false, "scenario %d stalled in %s at stage %d" % [_scenario, _game.flow.state_name(), _game.run.stage])
		return _conclude()
	var flow = _game.flow
	match flow.state_name():
		"stage", "beacon", "gates", "launch":
			if _game.run.stage != _last_stage:
				_last_stage = _game.run.stage
				flow._finish_stage()
		"boss":
			if _scenario == 2:
				_fight(flow._boss_module())
			else:
				_boss.defeat()
	if _ended:
		return _conclude()
	return false


func _start() -> void:
	_started = true
	var events = _game.events
	events.world_entered.connect(func(w: int):
		_worlds.append(w)
		_events.append("world %d" % w))
	events.stage_entered.connect(func(s: int, _retry: bool):
		_entered.append(s)
		_events.append("stage %d" % s))
	events.boss_arena_entered.connect(func():
		_events.append("arena")
		_replays.append(_game.flow.final_stage())
		var module = _game.flow._boss_module()
		_modules.append(module.get_script().resource_path.get_file() if module != null else "none"))
	events.boss_defeated.connect(func(): _boss_kills += 1)
	events.run_ended.connect(func(won: bool):
		_ended = true
		_won = won)
	if _scenario == 2:
		_game.ctx.calm = true
		# The Mind's win opens the Q16 ending (fly-over, victory lap, credits); victory_lap_test owns it. This test ends on the summary.
		_game.flow.victory_lap = false
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return
	_boss = BossDouble.new()
	_game.add_child(_boss)
	_boss.setup(_game.ctx)
	_game.ctx.calm = true
	if _built:
		_game.flow.boss_row_override[2] = Worlds.boss_of(1)
	else:
		var unbuilt: Dictionary = Worlds.boss_of(2).duplicate()
		unbuilt["built"] = false
		_game.flow.boss_row_override[2] = unbuilt
	# The Mind's win opens the Q16 ending (fly-over, victory lap, credits); victory_lap_test owns it. This test ends on the summary.
	_game.flow.victory_lap = false
	_game.flow.press_start()
	_game.flow.choose_class(0)


# One posture strike per tick on the stub's Warden: a smash fills its bar to a stagger,
# the next tick's smash lands on the open core and takes a chunk. Brindle, the scene
# module, is routed by his own defeat step.
func _fight(module) -> void:
	if module == _game.boss:
		module._defeat("ram", _game.ctx.player.ball_position())
		return
	var warden = module.warden
	if not is_instance_valid(warden) or warden.is_dead():
		return
	if _chunks.size() < _modules.size():
		_chunks.append(0)
	var was: int = warden.chunks_left()
	var result: Dictionary = warden.judge_hit("slam", 9999.0, true, 3)
	warden.on_struck("slam", String(result.get("part", "")), result)
	if bool(result.get("shatter", false)):
		_chunks[_chunks.size() - 1] += was - warden.chunks_left()
		warden.take_damage(float(result.get("dealt", 0.0)))


func _conclude_three() -> bool:
	var flow = _game.flow
	_t.eq("three: world_entered", _worlds, [1, 2, 3])
	_t.eq("three: order", _events, ["world 1", "stage 1", "arena", "world 2", "stage 2", "arena", "world 3", "stage 3", "arena"])
	_t.eq("three: Brindle ends world one, the Waking and the Mind worlds two and three", _modules, ["boss.gd", "waking.gd", "mind.gd"])
	_t.eq("three: each stub Warden lost its four chunks", _chunks, [0, 4, 4])
	_t.eq("three: three bosses defeated", _boss_kills, 3)
	_t.check("three: run ends won in the summary", _ended and _won and flow.state_name() == "summary",
		"ended %s, won %s, state %s" % [_ended, _won, flow.state_name()])
	_t.check("three: world one still answers to the scene's Brindle", flow._module_for(1) == _game.boss \
			and _game.boss.get_script().resource_path == "res://src/boss/boss.gd", "")
	_t.eq("three: no skip warning", flow._warned.keys().filter(func(k): return String(k).begins_with("boss_")), [])
	print("three order: %s" % " > ".join(_events))
	_game.free()
	_done = true
	quit(_t.verdict())
	return true


func _conclude() -> bool:
	if _scenario == 2:
		return _conclude_three()
	var flow = _game.flow
	var label := "built" if _built else "unbuilt"
	var warnings := 0
	for key in flow._warned:
		if String(key).begins_with("boss_unbuilt"):
			warnings += 1
	_t.eq("%s: world_entered" % label, _worlds, [1, 2])
	_t.eq("%s: stage_entered" % label, _entered, [1, 2, 3, 4, 5, 6])
	_t.check("%s: run ends won in the summary" % label, _ended and _won and flow.state_name() == "summary",
		"ended %s, won %s, state %s" % [_ended, _won, flow.state_name()])
	print("%s order: %s" % [label, " > ".join(_events)])
	if _built:
		_t.eq("built: two boss arenas", _boss.entries, 2)
		_t.eq("built: order", _events, [
			"world 1", "stage 1", "stage 2", "stage 3", "arena",
			"world 2", "stage 4", "stage 5", "stage 6", "arena"])
		_t.eq("built: no skip warning", warnings, 0)
	else:
		_t.eq("unbuilt: one arena, world one's", _boss.entries, 1)
		_t.eq("unbuilt: order", _events, [
			"world 1", "stage 1", "stage 2", "stage 3", "arena",
			"world 2", "stage 4", "stage 5", "stage 6"])
		_t.eq("unbuilt: one skip warning", warnings, 1)
	_t.eq("%s: in each arena the replay key is that world's last stage" % label, _replays, [3, 6] if _built else [3])
	_game.free()
	_scenario += 1
	if _scenario == 1:
		_built = false
	_boot()
	return false
