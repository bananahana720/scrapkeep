extends SceneTree

const Game := preload("res://src/game.gd")

# A retry rewinds the codex with the run (CONTRACTS, Codex): an enemy trick first
# pulled in the retried attempt fires again and pays its burst again. Combat calls
# ctx.codex.mark_discovered every time a trick fires and leaves the dedupe to the codex.
# Counter-ram, die by retry, counter-ram again: two banner facts and two bursts.

var _game
var _combat
var _failures := 0
var _facts := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_game.events.synergy_discovered.connect(func(id: String, _category: String, _first: bool):
		if id == "counter_ram":
			_facts += 1)
	var scrap_before: int = _game.run.scrap
	_counter_ram()
	var first_burst: int = _game.run.scrap - scrap_before
	_report("first", _facts == 1 and first_burst > 0,
		"counter-ram in the first attempt: %d fact, burst %d scrap" % [_facts, first_burst])
	_game.flow.retry_stage()
	var scrap_retry: int = _game.run.scrap
	_counter_ram()
	var second_burst: int = _game.run.scrap - scrap_retry
	_report("after_retry", _facts == 2 and second_burst == first_burst,
		"counter-ram again after the retry: %d facts in total, burst %d scrap (first paid %d)" % [_facts, second_burst, first_burst])
	var ok := _failures == 0
	print("combat_rediscovery_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true


func _counter_ram() -> void:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1) + Vector3(0.0, 0.0, 60.0)
	var chaser: Node3D = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(at.x, at.z, 1.6))
	chaser.hp = 500.0
	chaser.max_hp = 500.0
	chaser.state = chaser.State.WINDUP
	_combat.strike(chaser, "ram", 14.0)
