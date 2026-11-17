extends SceneTree
# smoke: timeout=240s

# Forced-contact probe for the Flume's drum lip and the drum-to-gate climb (red team on 49bf68c7, skipper seed 2865
# remembered_cannon on the park table: after the Warden broke the bot sat 25 s at (271, 0, 480-495), rolled back into the
# drum at (245, -13, 465) and did not climb out again before the stall cap; completionist seed 14 on 52e5366e met the same
# spot). With drum_lip_kicker's lip at x 270.07 that spot was a V groove 1.93 m wide between the lip's top and the
# terrace's 82 degree west face (x 270.5 to 272): a resting ball sat at (271.07, 0.37) touching both faces with grounded
# false, so jump and boost never fired, and a stick held at the terrace kept it there (16 s probe on 49bf68c7). The kicker
# now ends on the terrace edge (x 272), so the groove is gone. This test pins that a player's ball there is not wedged.
#
# The real Game on the park table (stage 2, park_flume, calm, no Warden), the real ball and its scripted stick, set in the
# camera's frame each tick as a person's keys are.
#   groove  downward rays across the old groove, x 270 to 274 at three z: the ground never dips below the ramp at x 270
#           (on 49bf68c7 it fell from 0.42 to -10.5 at x 270.5).
#   rest    the ball dropped where the groove was, no input: it lands grounded inside REST_S, within LANDED_NEAR_M of the
#           drop, so jump is live there.
#   east    from that landing, a stick held due east rolls onto the terrace inside SHOT_S;
#   jump    a jump pressed on that landing leaves the ground.
#   climb   from rest on the drum floor (BASIN), a person's line: to DRUM_WEST on the drum floor west of the kicker, up
#           its centre line holding shift, a jump near the lip, then east: on the terrace at the gate's level inside CLIMB_S.
#   sight   the north arch's crossbar is visible along the service grade from the stalled run's camera and ball.
#   roll    the ball rolls out along the service grade, takes an offer and launches east without jumping or boosting.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const T := preload("res://tests/support/t.gd")

const REST := Vector3(271.07, 1.4, 487.0)
const BASIN := Vector3(245.0, -12.0, 465.0)
const DRUM_WEST := Vector3(230.0, 0.0, 483.0)
const KICKER := "drum_lip_kicker"
const TERRACE_EDGE_X := 272.0
const GROOVE_X := [270.0, 274.0]
const GROOVE_Z := [470.0, 480.0, 490.0]
const GROOVE_SLACK_M := 0.1
const JUMP_FROM_X := 266.0
const EXIT_X := 272.5
const LEVEL_BAND := 2.5
const REST_S := 1.0
const LANDED_NEAR_M := 1.0
const SHOT_S := 4.0
const CLIMB_S := 20.0
const JUMP_RISE_M := 1.0
const CENTRE_LEAD_M := 6.0
# Frames 0168, 0172 and 0180 of the wave 44 played run. The old terrain or kicker cuts all six rays.
const DRUM_SIGHTLINES := [
	[Vector3(252.8, -9.6, 459.4), Vector3(262.3, -13.0, 461.2)],
	[Vector3(268.7, -11.0, 462.7), Vector3(269.1, -13.0, 460.7)],
	[Vector3(252.9, -8.1, 456.4), Vector3(253.8, -11.2, 465.5)],
]
const SERVICE_START := Vector3(251.0, -12.0, 458.0)
const SERVICE_CREST_X := 290.0

var t := T.new("park_flume_lip_notch_probe_test")
var game
var source := Intent.Scripted.new()
var taken := ""
var launch := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(1)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	var map = game.ctx.terrain.map()
	t.eq("real Game plays the Flume on the park table", map.title, "park_flume")
	var row: Dictionary = {}
	for r: Dictionary in map.park.park_rows:
		if String(r.get("id", "")) == KICKER:
			row = r
	t.check("the drum lip kicker ends on the terrace edge",
			not row.is_empty() and float(row["at"][0]) + float(row["size"][0]) * 0.5 >= TERRACE_EDGE_X - GROOVE_SLACK_M, "row %s" % row)
	var space = game.get_world_3d().direct_space_state
	for z: float in GROOVE_Z:
		var lowest := INF
		var start_y := NAN
		var x: float = GROOVE_X[0]
		while x <= GROOVE_X[1]:
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 20.0, z), Vector3(x, -20.0, z), 1))
			var y: float = hit["position"].y if not hit.is_empty() else -INF
			if hit.is_empty():
				start_y = -INF
			elif is_nan(start_y):
				start_y = y
			lowest = minf(lowest, y)
			x += 0.25
		print("  groove z %.0f: ground at x %.0f %.2f, lowest to x %.0f %.2f" % [z, GROOVE_X[0], start_y, GROOVE_X[1], lowest])
		t.check("groove z %.0f: the ground never dips below the ramp" % z, start_y > -INF and lowest >= start_y - GROOVE_SLACK_M,
				"x %.0f %.2f, lowest %.2f" % [GROOVE_X[0], start_y, lowest])
	var slot: Dictionary = map.gate_slots[0]
	var gate_ground: float = game.ctx.terrain.height(slot["at"].x, slot["at"].y)
	var run_in: Vector3 = Vector3(slot["at"].x, gate_ground, slot["at"].y) - (slot["facing"] as Vector3) * 9.0
	print("  gate 0 at %s, ground %.2f, run-in %s" % [slot["at"], gate_ground, run_in])
	var crossbar := Vector3(slot["at"].x, gate_ground + RewardGates.HEIGHT, slot["at"].y)
	for pose: Array in DRUM_SIGHTLINES:
		for from: Vector3 in pose:
			var query := PhysicsRayQueryParameters3D.create(from, crossbar, 1)
			query.hit_from_inside = true
			var hit: Dictionary = space.intersect_ray(query)
			t.check("the north crossbar is visible from %s" % from, hit.is_empty(), str(hit.get("position", "clear")))
	var landed: Dictionary = await _land()
	print("  rest: grounded at %.2f s, at %s" % [landed["s"], landed["at"]])
	t.check("rest: a ball dropped where the groove was lands grounded there", landed["s"] >= 0.0
			and Vector2(landed["at"].x - REST.x, landed["at"].z - REST.z).length() <= LANDED_NEAR_M, "at %s" % landed["at"])
	var end: Vector3 = await _shot(Vector3(1.0, 0.0, 0.0))
	print("  east: end=%s" % end)
	t.check("east: rolls onto the terrace", end.x > EXIT_X and gate_ground - end.y <= LEVEL_BAND, "end %s, gate ground %.2f" % [end, gate_ground])
	var jump: Dictionary = await _jump()
	print("  jump: pressed at %s, rise %.2f m" % [jump["at"], jump["rise"]])
	t.check("jump: a jump pressed on the landing leaves the ground", jump["rise"] >= JUMP_RISE_M
			and Vector2(jump["at"].x - REST.x, jump["at"].z - REST.z).length() <= LANDED_NEAR_M, "at %s, rise %.2f m" % [jump["at"], jump["rise"]])
	var climb: Dictionary = await _climb(run_in)
	print("  climb: out at %.1f s, end=%s, peak y %.2f" % [climb["out_s"], climb["end"], climb["peak"]])
	t.check("climb: a player rolls up the kicker from the drum floor and out to the gate's level", climb["out_s"] >= 0.0,
			"end %s, peak y %.2f, gate ground %.2f" % [climb["end"], climb["peak"], gate_ground])
	await _service_exit()
	game.free()
	quit(t.verdict())


func _stick(want: Vector3) -> Vector2:
	var yaw: float = game.camera.yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return Vector2(want.dot(right), want.dot(forward)).normalized()


# The ball dropped where the groove was, with no input, until it lands: {"s" (-1 when it never does), "at"}.
func _land() -> Dictionary:
	game.player.reset_to(REST)
	source.hold = {}
	for tick in int(REST_S * Engine.physics_ticks_per_second):
		await physics_frame
		if game.player.state.grounded:
			return {"s": float(tick) / Engine.physics_ticks_per_second, "at": game.player.ball_position()}
	return {"s": -1.0, "at": game.player.ball_position()}


func _shot(want: Vector3) -> Vector3:
	await _land()
	for tick in int(SHOT_S * Engine.physics_ticks_per_second):
		source.hold = {"move": _stick(want)}
		await physics_frame
	source.hold = {}
	return game.player.ball_position()


func _jump() -> Dictionary:
	var landed: Dictionary = await _land()
	var peak := -INF
	source.press["jump_pressed"] = true
	for tick in int(Engine.physics_ticks_per_second):
		await physics_frame
		peak = maxf(peak, game.player.ball_position().y)
	return {"at": landed["at"], "rise": peak - (landed["at"] as Vector3).y}


func _climb(run_in: Vector3) -> Dictionary:
	var player = game.player
	player.reset_to(BASIN)
	source.hold = {}
	await physics_frame
	var leg := 0
	var jumped := false
	var peak := -INF
	for tick in int(CLIMB_S * Engine.physics_ticks_per_second):
		var ball: Vector3 = player.ball_position()
		peak = maxf(peak, ball.y)
		if ball.x > EXIT_X and player.state.grounded and run_in.y - ball.y <= LEVEL_BAND:
			source.hold = {}
			return {"out_s": float(tick) / Engine.physics_ticks_per_second, "end": ball, "peak": peak}
		if leg == 0 and Vector2(ball.x - DRUM_WEST.x, ball.z - DRUM_WEST.z).length() < 3.0:
			leg = 1
		var to: Vector3 = DRUM_WEST
		if leg == 1:
			to = Vector3(ball.x + CENTRE_LEAD_M, 0.0, DRUM_WEST.z) if ball.x < EXIT_X else run_in
		source.hold = {"move": _stick(Vector3(to.x - ball.x, 0.0, to.z - ball.z).normalized())}
		if leg == 1:
			source.hold["shift_held"] = true
			if tick % 90 == 0:
				source.press["shift_pressed"] = true
			if not jumped and ball.x > JUMP_FROM_X and player.state.grounded:
				source.press["jump_pressed"] = true
				jumped = true
		await physics_frame
	source.hold = {}
	return {"out_s": -1.0, "end": player.ball_position(), "peak": peak}


func _service_exit() -> void:
	var player = game.player
	player.reset_to(SERVICE_START)
	await physics_frame
	game.ctx.events.reward_chosen.connect(func(id: String): taken = id)
	game.ctx.events.launched.connect(func(velocity: Vector3): launch = velocity)
	game.flow._unseal()
	var offers: Array = game.build.gates.offers
	if not t.check("the normal flume gate row opens", offers.size() >= 2, "offers %d" % offers.size()):
		return
	var offer: Dictionary = offers[0]
	var at: Vector3 = offer["at"]
	for tick in int(CLIMB_S * Engine.physics_ticks_per_second):
		var ball: Vector3 = player.ball_position()
		var target := Vector3(ball.x + CENTRE_LEAD_M, ball.y, SERVICE_START.z) if ball.x < SERVICE_CREST_X else Vector3(at.x + 3.0, ball.y, at.z)
		source.hold = {"move": _stick(target - ball)}
		await physics_frame
		if not taken.is_empty():
			break
	source.hold = {}
	t.check("the service grade leads through the north gate on a roll", taken == offer["part_id"], "took %s at %s" % [taken, player.ball_position()])
	t.check("the gate keeps an eastbound launch", launch.x > absf(launch.z) and launch.y > 0.0, str(launch))
