# smoke: solo (an 18 s relay charge runs at wall pace)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")

# SR10 in the parks: Hold the Relay stands in the Spillway dam (stage 1) and the Highdraft
# islands (stage 5) as an opt-in activity with a stake post at its mast.
# (a) each park builds one relay site with a registered stake post, and the word shows the
#     stake before commit;
# (b) the post stands outside the ring: a ball at the post is E's target and starts nothing;
#     holds walk the stake up and the prompt names what the next hold does;
# (c) on the dam at k = 3, killing what arrives: rolling into the ring starts the event, the
#     charge completes, the relay buys exactly waves x (1 + k) packs, sends 1 + k minibosses,
#     never stands more than its attacker budget and keeps every two arrivals pack_gap_s apart;
# (d) the win leaves one pickup that adds exactly 1 + k parts;
# (e) the islands' relay at k = 4, killing nothing, fills its budget and never passes it, and a
#     loss with the ball still in the ring does not restart it inside retry_s.

const Cards := preload("res://src/core/director_cards.gd")

const SEED := 23
const STAKE := 3
const CHARGE_SECONDS := 25.0
const PICKUP_FRAMES := 40
const FILL_SECONDS := 9.0
const EXPECTED_CHECKS := 15

var _game
var _t := preload("res://tests/support/t.gd").new("relay_park_test")
var _source := Intent.Scripted.new()
var _started := 0
var _ended := []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = _source
	_game.events.event_started.connect(func(id: String): _started += int(id == "hold_the_relay"))
	_game.events.event_ended.connect(func(id: String, outcome: String): if id == "hold_the_relay": _ended.append(outcome))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)


func _site():
	return _game.world.activities.site("hold_the_relay")


func _run() -> void:
	await _boot()
	await _frames(4)
	await _dam()
	_game.flow.enter_stage(5, Vector3.ZERO, false)
	await _frames(4)
	await _islands()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _dam() -> void:
	var s = _site()
	var interact = _game.ctx.root.get_node("Interact")
	_t.check("the dam builds a relay site", s != null and s.relay != null, "no site")
	if s == null:
		return
	_t.check("its stake post is registered with interact", s.stake_post in interact.devices, "")
	_t.check("the word shows the stake before commit", s.view.word.text == s.relay.stake_line() and "1 part roll" in s.view.word.text, s.view.word.text)
	var post_at: Vector3 = s.stake_post.global_position
	var out_m := Vector2(post_at.x - s.global_position.x, post_at.z - s.global_position.z).length()
	for frame in 6:
		_game.player.reset_to(post_at + Vector3(0.8, 1.05, 0.0), Vector3.ZERO)
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
	_t.check("a ball at the post outside the ring is E's target and starts nothing",
		out_m > float(s.rule["ring"]) + 2.0 and interact.target == s.stake_post and not s.started, "post %.1f m out, started %s" % [out_m, s.started])
	var prompts := []
	for i in STAKE:
		prompts.append(s.stake_post.words())
		interact.fire(s.stake_post)
	_t.eq("holds walk the stake up", s.relay.stakes, STAKE)
	_t.check("the prompt names the next hold", prompts[0] == "Fight: x1 stake, 2 parts" and "x4 stake" in s.stake_post.words(), str(prompts) + " / " + s.stake_post.words())
	var arrivals := []
	var gap_ok := true
	var peak := 0
	var seen := {}
	var parts_before: int = _game.run.parts.size()
	var at: Vector3 = _game.ctx.terrain.drop_point(s.global_position.x, s.global_position.z, 1.05)
	for frame in int(CHARGE_SECONDS * Engine.physics_ticks_per_second):
		_game.player.reset_to(at, Vector3.ZERO)
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
		var standing: int = _game.world.activities.relay_standing(s)
		peak = maxi(peak, standing)
		var fresh := 0
		for enemy in s.pack + s.minibosses:
			if is_instance_valid(enemy) and not seen.has(enemy.get_instance_id()):
				seen[enemy.get_instance_id()] = true
				fresh += 1
		if fresh > 0:
			arrivals.append(frame)
		# Clear the packs each beat so the cap never holds a buy back; minibosses stay.
		if frame % 30 == 29:
			for enemy in s.pack + s.minibosses:
				if is_instance_valid(enemy):
					enemy.take_damage(100000.0)
		if s.done:
			break
	for i in range(1, arrivals.size()):
		gap_ok = gap_ok and float(arrivals[i] - arrivals[i - 1]) / Engine.physics_ticks_per_second >= float(s.rule["pack_gap_s"]) - 0.02
	var packs: int = int(s.rule["waves"]) * (1 + STAKE)
	_t.check("rolling in starts the relay and the charge wins", _started == 1 and _ended == ["won"] and s.done, "started %d ended %s" % [_started, _ended])
	_t.eq("relay buys waves x (1 + k) packs", arrivals.size() - s.minibosses_sent, packs)
	_t.eq("relay sends 1 + k minibosses", s.minibosses_sent, 1 + STAKE)
	var budget: int = _game.world.activities.relay_budget(s)
	_t.check("never past the attacker budget, arrivals pack_gap_s apart", peak <= budget and gap_ok,
		"peak %d budget %d arrivals %s" % [peak, budget, arrivals])
	var pickup_at: Vector3 = s.pickup.global_position if s.pickup != null else Vector3.INF
	_game.player.reset_to(pickup_at + Vector3(4.0, 1.05, 0.0), Vector3.ZERO)
	await physics_frame
	for frame in PICKUP_FRAMES:
		_game.player.reset_to(pickup_at + Vector3(0.0, 1.05, 0.0), Vector3.ZERO)
		await physics_frame
		if s.pickup_taken:
			break
	_t.eq("the pickup adds 1 + k parts", _game.run.parts.size() - parts_before, 1 + STAKE)
	for enemy in s.minibosses:
		if is_instance_valid(enemy):
			enemy.queue_free()


func _islands() -> void:
	var s = _site()
	_t.check("islands build a relay with its authored pack", s != null and s.rule["pack"] == ["line_cutter", "kite_drone", "kite_drone"]
		and s.stake_post != null, str(s.rule["pack"]) if s != null else "no site")
	if s == null:
		return
	s.relay.set_stakes(Cards.RELAY_STAKE_MAX)
	var at: Vector3 = _game.ctx.terrain.drop_point(s.global_position.x, s.global_position.z, 1.05)
	var peak := 0
	for frame in int(FILL_SECONDS * Engine.physics_ticks_per_second):
		_game.player.reset_to(at, Vector3.ZERO)
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
		peak = maxi(peak, _game.world.activities.relay_standing(s))
	var budget: int = _game.world.activities.relay_budget(s)
	_t.check("a k = 4 relay left alone fills its budget and never passes it", peak <= budget and peak > budget - s.rule["pack"].size(),
		"peak %d budget %d" % [peak, budget])
	# A loss with the ball still in the ring waits out retry_s before the relay can start again.
	var starts_before := _started
	s.relay.elapsed = s.relay.WINDOW - 0.001
	for frame in 90:
		_game.player.reset_to(at, Vector3.ZERO)
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
	_t.check("a loss frees the stake and waits retry_s before a restart", _ended.back() == "lost" and not s.started
		and not s.relay.charging() and _started == starts_before and s.relay_cooldown > 0.0, "ended %s started %s" % [_ended, s.started])
	for enemy in s.pack + s.minibosses:
		if is_instance_valid(enemy):
			enemy.queue_free()
