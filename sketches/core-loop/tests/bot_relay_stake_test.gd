# smoke: solo (two 18 s relay charges run at wall pace)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const HoldRelay := preload("res://src/world/hold_relay.gd")
const Cards := preload("res://src/core/director_cards.gd")
const T := preload("res://tests/support/t.gd")

# The bot's SR10 arm (bot_run --relay-stake=0..4, bot_driver.gd _relay_arm).
# (a) the setting parses 0 to 4, treats an absent flag as 0, and rejects 5, -1 and non-numbers;
#     at 0 the driver makes no call at all into the world (a planted spy counts zero);
# (b) on the park dam, at k = 2 and k = 4, the arm stakes the relay through set_stakes before the
#     charge, the stake locks once the charge starts, and after the win the relay's credit
#     is base x (1 + k), rewards 1 + k, minibosses 1 + k and the pickup adds 1 + k parts;
# (c) planted negative controls: a late set_stakes(0) changes nothing, and the check that reads
#     the credit fails against base x k (the wrong multiplier).

const SEED := 23
const CHARGE_SECONDS := 30.0
const PICKUP_FRAMES := 40
const EXPECTED_CHECKS := 40

var _t := T.new("bot_relay_stake_test")
var _game
var _source := Intent.Scripted.new()


class SpyRelay extends RefCounted:
	var calls := 0
	var stakes := 0

	func set_stakes(k: int) -> bool:
		calls += 1
		stakes = k
		return true


class SpyActivities extends RefCounted:
	var asked := 0
	var relay := SpyRelay.new()

	func site(_id: String):
		asked += 1
		return null


class SpyWorld extends RefCounted:
	var activities := SpyActivities.new()


class SpyGame extends RefCounted:
	var bot_driven := false
	var world := SpyWorld.new()


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_parser()
	_default_untouched()
	for k in [2, 4]:
		await _staked_game(k)
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _parser() -> void:
	for k in 5:
		_t.eq("--relay-stake=%d parses" % k, BotOptions.relay_stake({"relay-stake": str(k)}), k)
	_t.eq("an absent flag is 0", BotOptions.relay_stake({}), 0)
	_t.eq("5 is rejected", BotOptions.relay_stake({"relay-stake": "5"}), -1)
	_t.eq("-1 is rejected", BotOptions.relay_stake({"relay-stake": "-1"}), -1)
	_t.eq("a non-number is rejected", BotOptions.relay_stake({"relay-stake": "two"}), -1)
	_t.eq("a fraction is rejected", BotOptions.relay_stake({"relay-stake": "2.5"}), -1)


func _default_untouched() -> void:
	var spy := SpyGame.new()
	var driver := BotDriver.new(spy, "skipper", 2)
	_t.eq("the driver's stake defaults to 0", driver.relay_stake, 0)
	var drove := false
	for i in 30:
		drove = drove or driver._relay_arm(1.0 / 60.0)
	_t.check("at 0 the arm drives nothing, asks the world nothing and stakes nothing",
		not drove and spy.world.activities.asked == 0 and spy.world.activities.relay.calls == 0,
		"drove %s asked %d stakes %d" % [drove, spy.world.activities.asked, spy.world.activities.relay.calls])
	driver.relay_stake = 3
	driver._relay_arm(1.0 / 60.0)
	_t.eq("planted control: at 3 the spy world is asked (the spy can see a call)", spy.world.activities.asked, 1)


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.run.run_seed_override = SEED
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	await _frames(4)


func _staked_game(k: int) -> void:
	await _boot()
	var activities = _game.world.activities
	var s = activities.site("hold_the_relay")
	_t.check("k=%d: the dam builds a relay" % k, s != null and s.relay != null, "no site")
	if s == null:
		_game.free()
		await _frames(2)
		return
	var driver := BotDriver.new(_game, "skipper", 2)
	driver.relay_stake = k
	_t.eq("k=%d: the relay starts unstaked" % k, s.relay.stakes, 0)
	driver._relay_arm(1.0 / 60.0)
	_t.check("k=%d: the arm staked the relay before the charge" % k, s.relay.stakes == k and not s.relay.charging() and not s.started,
		"stakes %d charging %s started %s" % [s.relay.stakes, s.relay.charging(), s.started])
	var at: Vector3 = _game.ctx.terrain.drop_point(s.global_position.x, s.global_position.z, 1.05)
	var parts_before: int = _game.run.parts.size()
	var seen := {}
	var locked_ok := false
	var late_ok := false
	for frame in int(CHARGE_SECONDS * Engine.physics_ticks_per_second):
		_game.player.reset_to(at, Vector3.ZERO)
		_game.player.set_velocity_now(Vector3.ZERO)
		driver._relay_arm(1.0 / Engine.physics_ticks_per_second)
		await physics_frame
		if s.relay.charging() and not locked_ok:
			# The stake locks once the charge starts: the game refuses a late change.
			late_ok = not s.relay.set_stakes(0) and not s.relay.set_stakes(Cards.RELAY_STAKE_MAX)
			locked_ok = s.relay.stakes == k
		for enemy in s.pack:
			if is_instance_valid(enemy):
				seen[enemy.get_instance_id()] = true
		if frame % 30 == 29:
			for enemy in s.pack + s.minibosses:
				if is_instance_valid(enemy):
					enemy.take_damage(100000.0)
		if s.done:
			break
	_t.check("k=%d: the charge started, won, and the stake was locked at k" % k, s.done and locked_ok and late_ok, "done %s locked %s late %s" % [s.done, locked_ok, late_ok])
	var rows: Array = driver._note.get("relay_stakes", [])
	var row: Dictionary = rows[0] if rows.size() == 1 else {}
	var base: float = activities.relay_pack_cost(s) * int(s.rule["waves"])
	_t.eq("k=%d: one relay_stakes row, stage 1, k" % k, [rows.size(), row.get("stage"), row.get("k")], [1, 1, k])
	_t.near("k=%d: credit = base x (1 + k)" % k, float(row.get("credit", -1.0)), base * (1 + k), 0.01)
	_t.eq("k=%d: rewards = 1 + k" % k, row.get("rewards"), 1 + k)
	_t.eq("k=%d: minibosses = 1 + k" % k, s.minibosses_sent, 1 + k)
	_t.eq("k=%d: the game's own staked() agrees" % k, snappedf(Cards.staked(base, k), 0.01), snappedf(float(row.get("credit", -1.0)), 0.01))
	_t.eq("k=%d: the credit bought waves x (1 + k) packs" % k, seen.size(), int(s.rule["waves"]) * (1 + k) * s.rule["pack"].size())
	# Planted negative control: the same readout against the wrong multiplier (k) must not match.
	_t.check("k=%d: planted control: base x k does not match the credit" % k, absf(float(row.get("credit", -1.0)) - base * k) > 0.01, str(row))
	var pickup_at: Vector3 = s.pickup.global_position if s.pickup != null else Vector3.INF
	_game.player.reset_to(pickup_at + Vector3(4.0, 1.05, 0.0), Vector3.ZERO)
	await physics_frame
	for frame in PICKUP_FRAMES:
		_game.player.reset_to(pickup_at + Vector3(0.0, 1.05, 0.0), Vector3.ZERO)
		await physics_frame
		if s.pickup_taken:
			break
	_t.eq("k=%d: the pickup adds 1 + k parts" % k, _game.run.parts.size() - parts_before, 1 + k)
	# The arm closes its row once the pay is taken and then leaves the relay alone.
	var drove := driver._relay_arm(1.0 / 60.0)
	_t.check("k=%d: the arm closes the row and stops driving" % k, not drove and row.get("outcome") == "won" and int(row.get("parts", -1)) == 1 + k and s.relay.stakes == k,
		"drove %s row %s" % [drove, row])
	for enemy in s.pack + s.minibosses:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_game.free()
	await _frames(2)
