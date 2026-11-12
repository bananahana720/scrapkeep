extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Companion := preload("res://src/core/companion.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# SA-F1 (systems audit pass F): a quit or crash after a stage's exit was taken used to Continue
# at that stage's start and lose its cogs and parts; after a world's last stage the window was
# the whole boss fight. The launch now saves the cleared stage (BIBLE section 6: completed
# stages keep the build and resolved rewards, with resume at the next entrance). On the
# two-world table, with Rivet in calm, the Wardens forced and a pick at every clear:
#   (a) a quit at the gates is before the exit: Continue replays the stage's entrance, so the
#       stage's pickups cannot pay twice, and the gate pair comes back the same;
#   (b) a quit in the flight continues at the next entrance with the stage's earnings, the gate
#       part, the live trade memory and the stowed core landed as one of that stage's cores;
#       stage_cleared fires once, and a pick the bay already opened is not opened again;
#   (c) a Warden that vanishes, launched with no bay visit: the Continue opens the owed pick;
#   (d) after the world's last stage, a quit in the boss fight continues in the arena with that
#       stage's earnings.

const DIR := "user://run_resume_cleared_test/"
const PATH := DIR + "run.json"
const FLIGHT := Vector3(0.0, 6.0, 30.0)


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld


var _game
var _failures := 0
var _cleared_count := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	_run.call_deferred()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _boot():
	var game := TwoWorldGame.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	var spawner := SpawnerDouble.new()
	game.add_child(spawner)
	spawner.setup(game.ctx)
	game.ctx.spawner = spawner
	game.ctx.calm = true
	# Every stage clear opens a workshop pick (the world-one profile opens one per world only).
	game.tuning.set_option("world_one_builds", "off")
	game.flow.force_warden = true
	game.player.source = Intent.Scripted.new()
	game.events.stage_cleared.connect(func(_stage: int): _cleared_count += 1)
	return game


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _disk() -> Dictionary:
	return RunStore.new(PATH).load()


func _offer_ids(game) -> Array:
	return game.build.gates.offers.map(func(offer): return String(offer["part_id"]))


func _break(game) -> void:
	var warden = game.flow.warden
	if is_instance_valid(warden):
		game.ctx.spawner.strike(warden, "arc", warden.max_hp * 2.0)


func _resume() -> bool:
	_game = _boot()
	await _frames(2)
	_cleared_count = 0
	var resumed: bool = _game.flow.resume_run()
	await _frames(2)
	return resumed


func _run() -> void:
	# Stage 1: earn, mark the trade memory, stow a core, break the Warden.
	_game = _boot()
	await _frames(2)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)
	var run = _game.run
	var start_cogs: int = run.cogs
	var model := Companion.new()
	model.acquire("primer_coil")
	model.acquire("escape_vent")
	model.assemble(["primer_coil", "escape_vent"])
	run.companion = model.to_dict()
	run.add_core("test", Vector3.ZERO)
	run.add_core("test", Vector3.ZERO)
	var stowed: bool = run.stow_core()
	run.add_part("boost_coil", "test")
	run.add_cogs(321)
	run.trade_memory["risk_taken"] = true
	_report("stage 1 holds a Warden", _game.flow.sealed and is_instance_valid(_game.flow.warden) and stowed,
		"sealed %s, stowed %s" % [_game.flow.sealed, stowed])
	_break(_game)
	await _frames(3)
	var offer: Array = _offer_ids(_game)
	var disk := _disk()
	_report("the gates leave the entrance on disk", _game.flow.state_name() == "gates" and not offer.is_empty()
		and not disk.get("cleared", false) and int(disk.get("stage", 0)) == 1 and int(disk.get("cogs", -1)) == start_cogs,
		"flow %s, offer %s; disk cleared %s stage %s cogs %s (start %d)" % [_game.flow.state_name(), offer,
			disk.get("cleared"), disk.get("stage"), disk.get("cogs"), start_cogs])
	_game.free()

	# (a) A quit at the gates replays the entrance; the same pair comes back at the break.
	var resumed: bool = await _resume()
	run = _game.run
	var replayed: bool = resumed and run.stage == 1 and _game.flow.state_name() == "stage" and _game.flow.sealed and run.cogs == start_cogs
	_report("a quit at the gates replays the entrance", replayed,
		"resumed %s at stage %d, flow %s, sealed %s, cogs %d (start %d)" % [resumed, run.stage, _game.flow.state_name(), _game.flow.sealed, run.cogs, start_cogs])
	run.companion = model.to_dict()
	run.add_core("test", Vector3.ZERO)
	run.add_core("test", Vector3.ZERO)
	run.stow_core()
	run.add_part("boost_coil", "test")
	run.add_cogs(321)
	run.trade_memory["risk_taken"] = true
	_break(_game)
	await _frames(3)
	_report("the gate pair is stable", _offer_ids(_game) == offer, "offer %s against %s" % [_offer_ids(_game), offer])

	# (b) The bay opens the stage's pick, a gate is taken, the launch commits; quit in the flight.
	_game.world._open_pick(1)
	var tree = _game.player.tree
	var allowed: int = int(tree.allowed)
	var gate_part := String(offer[0]) if not offer.is_empty() else ""
	_game.build.gates.chosen.emit(gate_part)
	_game.events.launched.emit(FLIGHT)
	await _frames(1)
	var earned := {"cogs": run.cogs, "parts": Array(run.parts), "seat": run.core_seat, "picks": Array(tree.picks)}
	disk = _disk()
	_report("the launch saves the cleared stage", _game.flow.state_name() == "launch" and bool(disk.get("cleared", false))
		and int(disk.get("stage", 0)) == 1 and int(disk.get("cogs", -1)) == earned["cogs"] and Array(disk.get("parts", [])) == earned["parts"]
		and earned["parts"].has(gate_part) and int(disk.get("carried_core", 0)) == 1 and bool(disk.get("pick_opened", false))
		and bool(disk.get("trade_memory", {}).get("risk_taken", false)),
		"flow %s; disk cleared %s stage %s cogs %s parts %s carried %s pick_opened %s risk %s; earned %s" % [_game.flow.state_name(),
			disk.get("cleared"), disk.get("stage"), disk.get("cogs"), disk.get("parts"), disk.get("carried_core"),
			disk.get("pick_opened"), disk.get("trade_memory", {}).get("risk_taken"), earned])
	_game.free()

	resumed = await _resume()
	run = _game.run
	tree = _game.player.tree
	disk = _disk()
	_report("a quit in the flight continues at the next entrance", resumed and run.stage == 2 and _game.flow.state_name() == "stage"
		and run.cogs == earned["cogs"] and Array(run.parts) == earned["parts"] and Array(tree.picks) == earned["picks"]
		and bool(run.trade_memory.get("risk_taken", false)) and _cleared_count == 1,
		"resumed %s at stage %d, flow %s, cogs %d parts %s picks %s risk %s, stage_cleared %d; earned %s" % [resumed, run.stage,
			_game.flow.state_name(), run.cogs, Array(run.parts), Array(tree.picks), run.trade_memory.get("risk_taken"), _cleared_count, earned])
	_report("the stowed core lands and the bay's pick is not opened twice", run.carried_core == 0 and run.arrived_core == 1
		and run.bonus_cores == 1 and int(tree.allowed) == allowed and int(disk.get("arrived_core", 0)) == 1
		and not disk.get("cleared", false) and not disk.has("carried_core"),
		"carried %d arrived %d bonus %d, tree allowed %d (saved %d); disk arrived %s cleared %s carried %s" % [run.carried_core,
			run.arrived_core, run.bonus_cores, int(tree.allowed), allowed, disk.get("arrived_core"), disk.get("cleared"), disk.get("carried_core")])

	# (c) Stage 2's Warden vanishes and the run launches without a bay visit.
	run.add_cogs(55)
	if is_instance_valid(_game.flow.warden):
		_game.flow.warden.queue_free()
	await _frames(3)
	var vanished: String = _game.flow.state_name()
	allowed = int(_game.player.tree.allowed)
	_game.events.launched.emit(FLIGHT)
	await _frames(1)
	var cogs_two: int = run.cogs
	_game.free()
	resumed = await _resume()
	run = _game.run
	_report("a vanished Warden's launch continues at stage 3 and opens the owed pick", vanished == "gates" and resumed
		and run.stage == 3 and run.cogs == cogs_two and int(_game.player.tree.allowed) == allowed + 1 and _cleared_count == 1,
		"after the vanish %s; resumed %s at stage %d, cogs %d (earned %d), tree allowed %d (saved %d), stage_cleared %d" % [vanished,
			resumed, run.stage, run.cogs, cogs_two, int(_game.player.tree.allowed), allowed, _cleared_count])

	# (d) Stage 3 closes world one: a quit in the boss fight continues in the arena.
	run.add_cogs(77)
	_break(_game)
	await _frames(3)
	_game.events.launched.emit(FLIGHT)
	await _frames(1)
	var cogs_three: int = run.cogs
	_game.flow._finish_stage()
	await _frames(2)
	var in_arena: bool = _game.flow.in_arena
	run.add_cogs(1000)
	_game.free()
	resumed = await _resume()
	run = _game.run
	_report("a quit in the boss fight continues in the arena", in_arena and resumed and run.stage == 3 and _game.flow.in_arena
		and _game.flow.state_name() == "boss" and run.cogs == cogs_three and _cleared_count == 1,
		"arena before the quit %s; resumed %s at stage %d, arena %s, flow %s, cogs %d (earned %d), stage_cleared %d" % [in_arena,
			resumed, run.stage, _game.flow.in_arena, _game.flow.state_name(), run.cogs, cogs_three, _cleared_count])
	_game.free()

	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	print("run_resume_cleared_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
