extends SceneTree

# PF-16 (W1-05): a crew enemy whose body runs its lane after the warning goes live (the chaser's
# lunge, the miniboss's charge) ended its warning on the live tick: the danger mark and the way-out
# paint went and the dense live band drew while the body was still on its way. Telegraph.run_body
# now carries where the body is, the grammar keeps the light fill, and the dodge watch keeps the
# mark and the way out up until the body's reach covers the ball. The near-miss award is still
# decided when the warning ends, the committed lane and the damage are unchanged.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const NearMiss := preload("res://src/combat/near_miss.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("body_run_warning_test")
var _game


class _Bus:
	signal player_hit(amount: float, source: String)
	signal near_miss(kind: String, at: Vector3)


class _Flat:
	func height(_x: float, _z: float) -> float:
		return 0.0


var _flat := _Flat.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_unit()
	await _watched()
	await _boot()
	await _live("chaser", func(e): e._begin_windup(Vector3.FORWARD), 8.0, "LUNGE")
	await _live("miniboss", func(e):
		e._next_attack = 1
		e._begin_attack(Vector3.FORWARD), 15.0, "CHARGE")
	quit(_t.verdict())


func _lane() -> Node:
	var lane := Telegraph.lane(root, _flat, Threat.Type.LANE, Vector3.ZERO, Vector3(0, 0, -1), 11.0, 2.8)
	lane.add_to_group(Threat.GROUP)
	return lane


# The owner's one call; a base without it leaves the checks below to fail by their own count.
func _run_body(lane: Node, along: float, reach: float) -> void:
	if lane.has_method("run_body"):
		lane.run_body(along, reach)


func _unit() -> void:
	var ball := Vector3(0.0, 0.0, -8.0)
	var plain := _lane()
	plain.set_progress(1.0)
	var p: Dictionary = plain.descriptor()
	_t.check("planted: a live lane with no running body draws its dense band", Threat.live_band(p))
	_t.check("planted: and lands for the ball on the live tick", NearMiss._landed(plain, ball, p))
	_t.check("planted: and carries no body field", not p.has("body_m"))
	var lane := _lane()
	_t.check("the lane takes the owner's run_body call", lane.has_method("run_body"))
	_run_body(lane, 2.4, 2.4)
	lane.set_progress(1.0)
	var d: Dictionary = lane.descriptor()
	_t.check("a live lane with a running body has body_m and body_reach", d.has("body_m") and d.has("body_reach"))
	_t.check("it keeps the light fill, not the dense live band", not Threat.live_band(d) and d.get("live", false))
	_t.check("a lane with no run_body call is still dense (control)", Threat.live_band(plain.descriptor()))
	_t.check("the committed lane is the same with or without a body", lane.contains(ball) == plain.contains(ball) \
		and lane.contains(Vector3(0, 0, -10.9)) == plain.contains(Vector3(0, 0, -10.9)) and lane.contains(Vector3(3, 0, -8)) == plain.contains(Vector3(3, 0, -8)))
	# Hit reach: a ball off the axis is reached later than one on it. Body reach 2.4, ball 1.2 to the
	# side: it is covered once the along gap is under sqrt(2.4^2 - 1.2^2) = 2.078, not 2.4.
	var side := Vector3(1.2, 0.0, -8.0)
	_t.check("an off-axis ball at along gap 2.2 is not yet reached", not _arrived(side, _with_body(lane, 5.8)))
	_t.check("and is reached at along gap 2.0", _arrived(side, _with_body(lane, 6.0)))
	_t.check("an on-axis ball is reached at gap 2.3", _arrived(ball, _with_body(lane, 5.7)))
	_t.check("and not at gap 2.6", not _arrived(ball, _with_body(lane, 5.4)))
	_t.check("a body that ran past the ball has arrived", _arrived(ball, _with_body(lane, 9.0)))
	plain.free()
	lane.free()


# The dodge watch's reach test, called by name so a base without it fails the counted checks, not the parse.
func _arrived(at: Vector3, d: Dictionary) -> bool:
	var script: Variant = NearMiss
	return script.has_method("_body_arrived") and bool(script.call("_body_arrived", at, d))


func _with_body(lane: Node, along: float) -> Dictionary:
	_run_body(lane, along, 2.4)
	return lane.descriptor()


# The dodge watch reads threats in the tree. A plain crew lane and one with a running body are
# stepped side by side through the same ball track, so the award is compared moment by moment.
func _watched() -> void:
	await physics_frame
	var track: Array = []
	for mode in 2:
		track.append(await _scenario(mode == 1, false))
	_t.eq("the near-miss award lands on the same tick with and without a running body", track[1]["fired_at"], track[0]["fired_at"])
	_t.eq("and pays exactly one near miss", track[1]["fired"], 1)
	_t.check("the plain lane drops its mark at the live tick (today's behaviour)", track[0]["held"] == 0)
	_t.check("the running body keeps the mark and a way out while it runs", track[1]["held"] >= 2 and track[1]["way_ok"])
	var hit: Dictionary = await _scenario(true, true)
	_t.eq("a hit then a shove pays no near miss", hit["fired"], 0)
	var arrival: Dictionary = await _arrival(true)
	_t.check("the ball stays in the lane: the mark is up on every tick the body is short of its reach", arrival["samples_up"] >= 10 and arrival["all_up"])
	_t.check("and is down on every tick once the reach covers the ball, the lane still live", arrival["samples_down"] >= 10 and arrival["all_down"])
	_t.check("the arrival ran past the 0.25 s grace, so a done watch holds the mark too", arrival["up_ticks"] > int(0.25 * 60.0))
	var plain: Dictionary = await _arrival(false)
	_t.check("planted: the same track on a lane with no body never holds a mark", plain["samples_up"] >= 10 and plain["none_up"])


# Ball in the lane, lane goes live, body runs 0 -> past the ball in steps. The ball leaves 0.13 s
# after the live tick, inside the 0.25 s grace (a dodge), or is hit at once and shoved (a hit).
func _scenario(with_body: bool, hit_case: bool) -> Dictionary:
	var at := [Vector3(0.0, 0.0, -8.0)]
	var bus := _Bus.new()
	var watch := NearMiss.new()
	var fired := []
	var tick := [0]
	bus.near_miss.connect(func(_k, _a): fired.append(tick[0]))
	watch.setup(bus, func(): return at[0])
	root.add_child(watch)
	var lane := _lane()
	lane.set_progress(0.5)
	if with_body:
		_run_body(lane, 0.0, 2.4)
	watch.step(1.0 / 60.0)
	lane.set_progress(1.0)
	var held := 0
	var way_ok := true
	var body := 0.0
	for i in 40:
		tick[0] = i
		if i == 8 and not hit_case:
			at[0] = Vector3(6.0, 0.0, -8.0)
		if body < 11.0:
			body += 1.0 if hit_case else 0.5
			if with_body:
				_run_body(lane, body, 2.4)
		if hit_case and body >= 5.6 and i < 30:
			bus.player_hit.emit(10.0, "chaser")
			at[0] = Vector3(6.0, 0.0, -8.0)
		watch.step(1.0 / 60.0)
		var gap := 8.0 - body
		if not hit_case and i < 8 and gap > 2.9 and watch.standing_in() >= 0.0:
			held += 1
			way_ok = way_ok and not watch.escape().is_empty() and absf(watch.escape()["dir"].x) > 0.9
	lane.free()
	watch.free()
	return {"fired": fired.size(), "fired_at": fired[0] if not fired.is_empty() else -1, "held": held, "way_ok": way_ok}


# The ball stays in the lane the whole time and nothing hits it. The body runs 0.25 m a tick, past the
# grace, from the lane's start to past the ball (8 m down); reach 2.4. The mark must be up while the
# gap to the ball is above the reach and down from the first tick it is at or below, with the lane live.
func _arrival(with_body: bool) -> Dictionary:
	var at := Vector3(0.0, 0.0, -8.0)
	var watch := NearMiss.new()
	watch.setup(_Bus.new(), func(): return at)
	root.add_child(watch)
	var lane := _lane()
	lane.set_progress(0.5)
	if with_body:
		_run_body(lane, 0.0, 2.4)
	watch.step(1.0 / 60.0)
	lane.set_progress(1.0)
	var up := 0
	var down := 0
	var all_up := true
	var all_down := true
	var none_up := true
	var body := 0.0
	for i in 60:
		body += 0.25
		if with_body:
			_run_body(lane, body, 2.4)
		watch.step(1.0 / 60.0)
		var standing := watch.standing_in() >= 0.0
		if 8.0 - body > 2.4:
			up += 1
			all_up = all_up and standing
			none_up = none_up and not standing
		else:
			down += 1
			all_down = all_down and not standing
	lane.free()
	watch.free()
	return {"samples_up": up, "samples_down": down, "up_ticks": up, "all_up": all_up, "all_down": all_down, "none_up": none_up}


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	for i in 3:
		await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


# The hit distance in metres, pinned absolutely by behaviour: a ball 0.05 m inside the enemy's reach
# is hit and one 0.05 m outside is not, where the reach is computed here from the enemy's own radius
# (chaser: radius + 1.4, 2.4 m at its radius of 1.0; miniboss: 2.3 + 1.6 = 3.9 m), never from
# hit_reach() or HIT_REACH. The committed lane's body_reach must equal it too. The hit test is the one
# the lunge and the charge run each tick (_check_hit, _check_charge).
func _reach_pin(kind: String, enemy) -> void:
	enemy.set_physics_process(false)
	enemy._clear_telegraph()
	if kind == "chaser":
		enemy._begin_windup(Vector3.FORWARD)
	else:
		enemy._next_attack = 1
		enemy._begin_attack(Vector3.FORWARD)
	var lane = enemy.telegraph()
	var reach: float = enemy.radius + 1.4 if kind == "chaser" else 2.3 + 1.6
	var advertised := float(lane.descriptor().get("body_reach", -1.0))
	var results := []
	for offset in [-0.05, 0.05]:
		enemy._landed = false
		var at: Vector3 = enemy.global_position + Vector3.FORWARD * (reach + offset)
		at.y = lane.center.y + 1.0
		_game.player.body().global_position = at
		if kind == "chaser":
			enemy._check_hit(lane)
		else:
			enemy._check_charge(lane)
		results.append(enemy._landed)
	_t.check("%s: the lane's body_reach (%.2f) is the reach its hit test uses" % [kind, reach], is_equal_approx(advertised, reach) and results == [true, false])


# A real enemy, the ball held `ahead` metres down its lane: on the first ticks of its run the
# descriptor has a body short of the ball, the watch still stands in it with a way out, and the
# dense band is not drawn; once the enemy's reach covers the ball the mark is gone.
func _live(kind: String, begin: Callable, ahead: float, run_state: String) -> void:
	var enemy = _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(-100.0, -90.0, 3.5))
	enemy.hp = 100000.0
	var start: Vector3 = enemy.global_position
	var ball_at := Vector3(start.x, start.y, start.z - ahead)
	begin.call(enemy)
	var in_run := int(enemy.State[run_state])
	var checked := false
	var early_ok := false
	var cleared := false
	var up_ok := true
	var down_ok := true
	var down_samples := 0
	var reach_samples := 0
	var reach_ok := true
	var want_reach: float = enemy.hit_reach() if kind == "chaser" else enemy.HIT_REACH
	var up_samples := 0
	var near: Node = _game.combat.near_miss
	for i in 240:
		_game.player.body().global_position = ball_at
		await physics_frame
		var lane = enemy.telegraph()
		if enemy.state == in_run and lane != null and not checked and enemy._clock > 0.02:
			checked = true
			var d: Dictionary = lane.descriptor()
			var along := absf(ball_at.z - lane.center.z)
			early_ok = d.get("live", false) and d.has("body_m") and float(d["body_m"]) < along and not Threat.live_band(d) \
				and near.standing_in() >= 0.0 and not near.escape().is_empty()
		# The ball is pinned each frame, so a hit cannot shove it out: the mark must follow the body
		# alone. The watch reads the body one tick apart from this sample, so a 0.6 m band either side
		# of the reach (about one tick of the body's 33 m/s) is left out.
		if lane != null and enemy.state == in_run and lane.descriptor().has("body_m"):
			reach_samples += 1
			reach_ok = reach_ok and is_equal_approx(float(lane.descriptor()["body_reach"]), want_reach)
			var gap := absf(ball_at.z - lane.center.z) - float(lane.descriptor()["body_m"])
			var reach := float(lane.descriptor()["body_reach"])
			if gap > reach + 0.6:
				up_samples += 1
				up_ok = up_ok and near.standing_in() >= 0.0
			elif gap < reach - 0.6:
				down_samples += 1
				down_ok = down_ok and near.standing_in() < 0.0
		if checked and lane == null and _game.combat.near_miss.standing_in() < 0.0:
			cleared = true
			break
	_t.check("%s: in the first ticks of its run the mark and way out stay and no dense band" % kind, early_ok)
	_t.check("%s: once the run is over the mark is gone" % kind, cleared)
	_t.check("%s: up on every sampled tick short of the reach (%d sampled)" % [kind, up_samples], up_samples >= 1 and up_ok)
	_t.check("%s: down on every sampled tick the reach covers the ball, the lane still there (%d sampled)" % [kind, down_samples], down_samples >= 1 and down_ok)
	_t.check("%s: on every run tick the descriptor's body_reach is the owner's hit reach %.2f (%d sampled)" % [kind, want_reach, reach_samples], reach_samples >= 1 and reach_ok)
	_reach_pin(kind, enemy)
	if is_instance_valid(enemy):
		enemy.free()
