extends SceneTree

# Rule: the camp skee lane scores a nine-ball game. Each cup's ball-only sensor books that
# cup's value (10 20 30 40 50 100 100), the return gutter books 0, the ball goes back to the
# start bar at rest after each one, leaving the lane ends the game, and the best total is
# kept. The scoring is checked with no scene; the sensors are checked by dropping a 1 m
# ball onto each cup of the committed lane's collision (the lane is turned and moved so lane
# space is not world space) at 90 ticks. This is physics evidence, not a feel check.
const T := preload("res://tests/support/t.gd")
const FakeHub := preload("res://tests/support/camp_fake_hub.gd")
const Skee := preload("res://src/world/camp_skee.gd")
const Records := preload("res://src/core/camp_records.gd")
const Profile := preload("res://src/core/profile.gd")

var _t := T.new("camp_skee_test")


func _initialize() -> void:
	Engine.physics_ticks_per_second = 90
	_scoring()
	await _lane()
	quit(_t.verdict())


func _scoring() -> void:
	var m := Skee.Match.new()
	_t.eq("nine balls to a game", m.balls_left, 9)
	_t.eq("a game starts at nothing", m.score, 0)
	for id in ["cup_10", "cup_20", "cup_30", "cup_40", "cup_50", "cup_100_l", "cup_100_r"]:
		_t.eq("%s value" % id, Skee.points_for(id), {"cup_10": 10, "cup_20": 20, "cup_30": 30, "cup_40": 40, "cup_50": 50}.get(id, 100))
	_t.eq("the gutter is worth nothing", Skee.points_for("return"), 0)
	for p in [10, 0, 100, 50, 20, 10, 10, 40, 30]:
		m.roll(p)
	_t.eq("running total", m.score, 270)
	_t.check("nine rolls end the game", m.over())
	m.roll(100)
	_t.eq("a tenth roll books nothing", m.score, 270)
	_t.eq("the roll list keeps order", m.rolls[2], 100)
	var n := Skee.Match.new()
	n.roll(30)
	_t.eq("board text", n.board(), "SCORE 30   BALLS 8")
	var radii := {"cup_10": 2.0, "cup_20": 1.4, "cup_30": 1.3, "cup_40": 1.3, "cup_50": 1.25, "cup_100_l": 1.25, "cup_100_r": 1.25}
	for id in radii:
		_t.near("%s radius from the recipe" % id, Skee.CUPS[id]["radius"], radii[id])


func _lane() -> void:
	var hub := FakeHub.new()
	root.add_child(hub)
	await physics_frame
	var yaw := 0.7
	hub.place("camp_skee_lane", Vector3(30, 0, 10), yaw)
	var profile := Profile.new("user://test-camp-skee-%d.json" % OS.get_process_id())
	var lane := Skee.new()
	hub.root.add_child(lane)
	lane.setup(hub, Records.new(profile))
	_t.eq("one station is offered at the foot", hub.stations.size(), 1)
	_t.check("the station sits at the interact socket", hub.stations[0]["at"].is_equal_approx(hub.socket("camp_skee_lane", "interact").origin))
	_t.check("the scoreboard shows the lane idle", lane.score_label.text.begins_with("SKEE-BALL"), lane.score_label.text)
	_t.check("the scoreboard is amber", lane.score_label.modulate.is_equal_approx(Color("e5a044")))
	var lane_basis: Basis = hub.piece("camp_skee_lane").global_transform.basis
	var normal := lane_basis * Vector3(0, cos(deg_to_rad(35)), sin(deg_to_rad(35)))
	var cups := {"cup_10": 10, "cup_20": 20, "cup_30": 30, "cup_40": 40, "cup_50": 50, "cup_100_l": 100, "cup_100_r": 100}
	for id in cups:
		hub.stations[0]["on_press"].call()
		_t.eq("a press starts a game", lane.phase, Skee.Phase.PLAYING)
		var start_at: Vector3 = hub.socket("camp_skee_lane", "start").origin
		_t.check("%s: the ball starts on the bar" % id, hub.ball.body().global_position.is_equal_approx(start_at))
		var floor_at: Vector3 = hub.socket("camp_skee_lane", id).origin
		hub.ball.reset_to(floor_at + normal * 3.5, -normal * 5.0)
		await _until(func(): return lane.phase != Skee.Phase.PLAYING, 4.0)
		_t.eq("%s: the drop is booked once" % id, lane.match_state.rolls, [cups[id]])
		lane.end_game(true)
		await physics_frame

	# The gutter books 0 and the ball is served again.
	hub.stations[0]["on_press"].call()
	var gutter: Vector3 = hub.socket("camp_skee_lane", "return_exit").origin
	hub.ball.reset_to(gutter + Vector3.UP * 0.3, Vector3.ZERO)
	await _until(func(): return lane.phase != Skee.Phase.PLAYING, 4.0)
	_t.eq("the gutter books a zero", lane.match_state.rolls, [0])
	_t.eq("a ball is spent", lane.match_state.balls_left, 8)
	await _until(func(): return lane.phase == Skee.Phase.PLAYING, 3.0)
	_t.check("the next ball is back on the bar", hub.ball.body().global_position.distance_to(hub.socket("camp_skee_lane", "start").origin) < 0.3)
	_t.near("and at rest", hub.ball.body().linear_velocity.length(), 0.0, 0.5)

	# A rolled ball (no drive, 24 m/s up the lane, enough to clear the kicker) books something and is never double counted.
	lane.end_game(true)
	hub.stations[0]["on_press"].call()
	hub.ball.reset_to(hub.socket("camp_skee_lane", "start").origin, -lane_basis.z * 24.0)
	await _until(func(): return lane.phase != Skee.Phase.PLAYING, 40.0)
	_t.eq("a rolled ball books exactly one score, the 10 cup", lane.match_state.rolls, [10])
	lane.end_game(true)
	await physics_frame

	# Rolling away past the foot ends the game.
	hub.stations[0]["on_press"].call()
	_t.eq("a game is running before the ball leaves", lane.phase, Skee.Phase.PLAYING)
	hub.ball.reset_to(hub.socket("camp_skee_lane", "start").origin + lane_basis.z * 9.0, Vector3.ZERO)
	await _until(func(): return lane.phase == Skee.Phase.IDLE, 1.0)
	_t.eq("leaving the lane ends the game", lane.phase, Skee.Phase.IDLE)
	_t.check("the board says so", lane.score_label.text.begins_with("GAME OVER"), lane.score_label.text)

	# A full game's total is kept as the best, and a worse one does not replace it.
	var records := Records.new(profile)
	_t.eq("an abandoned game still keeps its score (the 100 cup drop)", records.skee_best(), 100)
	var full := Skee.Match.new()
	for p in [10, 10, 50, 20, 100, 0, 10, 30, 10]:
		full.roll(p)
	hub.stations[0]["on_press"].call()
	lane.match_state = full
	lane.phase = Skee.Phase.SETTLING
	lane.call("_after_settle")
	_t.eq("the finished game ends", lane.phase, Skee.Phase.IDLE)
	_t.eq("the best total is kept", records.skee_best(), 240)
	_t.check("the final board shows score and best", lane.score_label.text == "FINAL 240   BEST 240", lane.score_label.text)
	_t.check("a lower total is not a new best", not records.submit_skee(100))
	_t.eq("best stays", records.skee_best(), 240)
	hub.queue_free()


func _until(done: Callable, seconds: float) -> void:
	var ticks := int(seconds * 90.0)
	for i in ticks:
		if done.call():
			return
		await physics_frame
