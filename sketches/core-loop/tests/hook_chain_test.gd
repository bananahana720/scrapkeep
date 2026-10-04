extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const ChainState := preload("res://src/combat/chain.gd")

# The harpoon chain (design-v3/HOOK-CHAIN.md): fourteen scripted sequences through a real
# Game's player and ChainState. Bites go through grapple_to, let-gos through the line's own
# end publication, the ground through state.grounded, and the clock through the chain's tick;
# every step runs synchronously, so physics never moves the ball between steps.
# Evidence limit: the rule and the multiplier a landing derives, not a played fight; how the
# chain feels is unjudged.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _failures := 0
var _count := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _seen: Array = []
var _fails: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	_count += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _enemy(dx: float) -> Node3D:
	var at: Vector3 = _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z, 1.0)
	var enemy: Node3D = _combat.spawn_enemy("chaser", at)
	enemy.live = Callable(self, "_never")
	return enemy


func _fresh() -> void:
	_player.kit.drop_line("reset")
	_player.kit.line_end = ""
	_player.chain.reset()
	_player.state.grounded = false
	_player.kit.rewind_left = 0.0
	_player._landing_mult = 1.0
	_seen.clear()
	_fails.clear()


func _bite(enemy: Node3D) -> void:
	_player.grapple_to(enemy.global_position, Vector3.UP, enemy)
	_player._publish_line(0.0)


func _wall() -> void:
	_player.grapple_to(Vector3(-40.0, 20.0, 0.0), Vector3.RIGHT, null)
	_player._publish_line(0.0)


func _let_go() -> void:
	_player.release_grapple()
	_player._publish_line(0.0)


func _air(seconds: float) -> void:
	_player.state.grounded = false
	_player._tick_chain(seconds)


func _ids() -> Array:
	var out: Array = []
	for row in _seen:
		out.append(row[0])
	return out


func _end_cause() -> String:
	for i in range(_seen.size() - 1, -1, -1):
		if _seen[i][0] == "chain_end":
			return _seen[i][1]
	return ""


func _chain() -> ChainState:
	return _player.chain


func _paid_ratio_for(links: int) -> float:
	# links total links on the chain at the landing.
	var enemy := _enemy(0.0)
	_fresh()
	for i in links - 1:
		_bite(enemy)
		_let_go()
	_bite(enemy)
	_player.kit.line_state = Augments.LINE_SMASH
	var landed: bool = _player._begin_landing(enemy)
	var plain := 40.0
	var ratio: float = _combat.punch_of("stomp", _player._landing_force("stomp", plain)) / _combat.punch_of("stomp", plain)
	var ram_ratio: float = _combat.punch_of("ram", _player._landing_force("ram", 25.0)) / _combat.punch_of("ram", 25.0)
	_player._finish_landing(enemy, 20.0)
	enemy.queue_free()
	return ratio if landed and absf(ratio - ram_ratio) < 0.001 else -1.0


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_combat.heft_override = 1.0
	_game.events.line_state_changed.connect(func(id: String, _t: Node3D, _at: Vector3, cause: String): _seen.append([id, cause]))
	_game.events.verb_failed.connect(func(_verb: String, reason: String, _at: Vector3): _fails.append(reason))
	_player.set_physics_process(false)
	var a := _enemy(0.0)
	var b := _enemy(6.0)
	_check("setup", _player.kit.on(Augments.GRAPPLE), "the pilot's kit carries the harpoon")

	_fresh()
	_bite(a)
	_let_go()
	_air(0.2)
	_bite(b)
	_check("1 enemy-enemy", _chain().combo == 2 and _chain().links == 2 and _chain().pivots == 0 and _ids().count("chain_link") == 2,
		"combo %d links %d, events %s" % [_chain().combo, _chain().links, _ids()])

	_fresh()
	_bite(a)
	_let_go()
	_wall()
	_let_go()
	_bite(b)
	_check("2 enemy-wall-enemy", _chain().combo == 2 and _chain().pivots == 1 and _chain().active() and _ids().has("chain_pivot"),
		"combo %d pivots %d, events %s" % [_chain().combo, _chain().pivots, _ids()])

	_fresh()
	_wall()
	_let_go()
	_wall()
	_check("3 wall-wall", not _chain().active() and _chain().combo == 0 and _end_cause() == "double_pivot",
		"active %s combo %d cause %s" % [_chain().active(), _chain().combo, _end_cause()])

	_fresh()
	_bite(a)
	_let_go()
	_wall()
	_let_go()
	_wall()
	_check("4 enemy-wall-wall", not _chain().active() and _chain().combo == 0 and _end_cause() == "double_pivot" \
			and _chain().finished.back()["combo"] == 1,
		"ended %s with the combo of 1 on record, cause %s" % [not _chain().active(), _end_cause()])

	_fresh()
	_bite(a)
	_let_go()
	_air(0.1)
	_bite(b)
	_let_go()
	_player.state.grounded = true
	_player._tick_chain(0.016)
	_check("5 ground break", not _chain().active() and _chain().combo == 0 and _end_cause() == "ground" and _chain().finished.back()["combo"] == 2,
		"ended %s cause %s after combo 2" % [not _chain().active(), _end_cause()])

	_fresh()
	_bite(a)
	_let_go()
	_air(0.79)
	_bite(b)
	_check("6 grace edge 0.79 s", _chain().combo == 2 and _chain().active() and _end_cause() == "",
		"bite after 0.79 s of airtime: combo %d alive %s" % [_chain().combo, _chain().active()])

	_fresh()
	_bite(a)
	_let_go()
	_air(0.81)
	var ended: bool = _end_cause() == "grace" and not _chain().active()
	_bite(b)
	_check("7 grace edge 0.81 s", ended and _chain().combo == 1 and _chain().links == 1,
		"after 0.81 s the chain ended (%s) and the next bite starts a new chain at %d" % [_end_cause(), _chain().combo])

	_fresh()
	_bite(a)
	_let_go()
	_air(0.1)
	_player.kit.aim = Augments.no_aim()
	_player._press_harpoon()
	var cooldown: float = _chain().miss_left
	var ready_while: bool = _player.verb_ready("harpoon")
	var before: int = _ids().count("chain_miss")
	_player._press_harpoon()
	_check("8 dry fire mid-chain", not _chain().active() and _end_cause() == "dry_fire" and absf(cooldown - 0.6) < 0.001 and _ids().has("chain_miss") \
			and not ready_while and _ids().count("chain_miss") == before and _fails.has("cooldown"),
		"ended %s cause %s, cooldown %.2f, harpoon refused while it runs (%s), a second press adds no miss" % [not _chain().active(), _end_cause(), cooldown, not ready_while])

	var m1 := _paid_ratio_for(1)
	_check("9 payout combo 1", absf(m1 - 1.0) < 0.001, "combo 1 pays x%.3f" % m1)
	var m4 := _paid_ratio_for(4)
	_check("10 payout combo 4", absf(m4 - 1.9) < 0.001, "combo 4 pays x%.3f" % m4)
	var m6 := _paid_ratio_for(6)
	_check("11 payout combo 6", absf(m6 - 2.5) < 0.001, "combo 6 pays x%.3f" % m6)
	var m8 := _paid_ratio_for(8)
	_check("12 payout combo 8 capped", absf(m8 - 2.5) < 0.001, "combo 8 pays x%.3f, the cap" % m8)

	var c := _enemy(12.0)
	_fresh()
	_bite(c)
	_let_go()
	_bite(c)
	_player.kit.line_state = Augments.LINE_SMASH
	var landed: bool = _player._begin_landing(c)
	var rec: Dictionary = _chain().finished.back() if not _chain().finished.is_empty() else {}
	_player._finish_landing(c, 20.0)
	_check("13 smash pays and resets", landed and _chain().combo == 0 and not _chain().active() and rec.get("paid", false) and rec.get("combo", 0) == 2 \
			and _end_cause() == "paid" and _player._landing_mult == 1.0,
		"record %s, combo now %d, cause %s" % [rec, _chain().combo, _end_cause()])

	_fresh()
	_player.kit.aim = {"state": Augments.AIM_BODY, "point": a.global_position, "normal": Vector3.UP, "body": a}
	var ready_before: bool = _player.verb_ready("harpoon")
	_bite(a)
	_let_go()
	var single: float = _player._landing_mult
	_check("14 combo 1 is today's game", _chain().combo == 1 and _chain().miss_left == 0.0 and ready_before and _player.verb_ready("harpoon") \
			and _player._harpoon_refusal() == "" and not _ids().has("chain_miss") and single == 1.0 and not _fails.has("cooldown"),
		"combo %d, no cooldown, the harpoon still fires, refusal '%s'" % [_chain().combo, _player._harpoon_refusal()])

	print("hook_chain_test: %s, %d sequences" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _count - 1])
	quit(0 if _failures == 0 else 1)
