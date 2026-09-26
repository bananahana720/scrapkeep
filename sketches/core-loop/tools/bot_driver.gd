extends RefCounted

const Intent := preload("res://src/movement/intent.gd")
const EventDirector := preload("res://src/world/event_director.gd")

# One scripted player for the design feedback loop (DEMO-SPEC, "Bot runs"). It plays a
# real Game through the same doors a person uses: an Intent.Scripted source for the
# keys, camera.look() for the mouse and the flow's own title and class calls. It never
# calls a run mutator, strikes an enemy or moves the ball, so the run log and the codex
# log it leaves behind record play, not a test's shortcuts.
#
# What it may read is what a player could see: the ball, enemies in the `enemy` group,
# the gates' offer records, the fabricator hoops, the scrap lines, the vault and the
# stage events' rings. Those reads go through the game's module nodes; the bot is a
# harness, not a module, so the CONTRACTS rule against reaching into another module's
# folder does not bind it, and it writes nothing there.
#
# Policies (DEMO-SPEC, three drivers):
#   skipper        beelines at the Warden from the drop, breaks it, takes the first gate.
#   completionist  rolls the scrap lines (and so the fabricator hoops on them), joins
#                  an armed event, cracks the vault, then breaks the Warden; prefers a
#                  gate that completes a synergy, then the higher tier.
#   random         a seeded wander biased toward the beacon, which commits to the
#                  Warden once close or late; random gate choice.
#
# Every fight uses one loop: the camera looks at the target (its weak point when one
# shows), fire is held, and the ball makes ram laps: charge, overshoot, run up, charge
# again. On a caps Warden it jumps on the approach and slams from above.
#
# A run ends at stage-3 clear (outcome "won"), death ("died"), a flow state named
# "boss" (wave 4; "boss") or a stage that runs past STAGE_LIMIT seconds ("stalled").

const POLICIES := ["skipper", "completionist", "random"]
# Radians of camera yaw per second: a brisk mouse, not a snap.
const TURN_RATE := 5.0
const SENSITIVITY := 0.0022
# A stage longer than this is a stall: the bot could not break the Warden.
const STAGE_LIMIT := 240.0
const STUCK_SPEED := 2.5
const STUCK_SECONDS := 2.0
const DETOUR_SECONDS := 1.4
const BOOST_GAP := 1.6
# Off the line by more than this (cosine) at more than this speed, brake to carve the turn.
const DRIFT_LINE := 0.5
const DRIFT_SPEED := 9.0
# The ram lap: charge until this close, then run up this far and charge again.
const CHARGE_CLOSE := 3.8
const RUNUP := 24.0
const RUNUP_SECONDS := 3.2
const AIM_REACH := 40.0
const WAYPOINT_REACHED := 9.0
const WAYPOINT_SECONDS := 14.0
const VAULT_SECONDS := 45.0
const EVENT_PURSUIT_SECONDS := 40.0
const EVENT_LATEST := 150.0
const WANDER_GAP := Vector2(3.0, 6.0)
const WANDER_SPREAD := 1.0
const WANDER_COMMIT_DISTANCE := 45.0
const WANDER_COMMIT_TIME := 45.0

var game
var policy := "skipper"
var seed_value := 1
var class_index := 0
var rng := RandomNumberGenerator.new()
var source := Intent.Scripted.new()

# "", then won, died, stalled or boss.
var outcome := ""
var ticks := 0
# One row per stage the bot entered: what it tried, for the sidecar log.
var stage_notes: Array[Dictionary] = []

var _offers: Array = []
var _gate_pick := -1
var _stage := 0
var _fight_phase := "charge"
var _fight_target: Node3D = null
var _runup_point := Vector3.ZERO
var _runup_time := 0.0
var _slow_time := 0.0
var _detour_time := 0.0
var _detour := Vector3.ZERO
var _boost_clock := 0.0
var _waypoints: Array[Vector3] = []
var _waypoint_time := 0.0
var _vault_time := 0.0
var _vault_done := false
var _event_time := {}
var _event_skip := {}
var _wander_clock := 0.0
var _wander_heading := Vector3.FORWARD
var _committed := false
var _planned := false
var _note := {}
# Set by the runner's --trace: prints the bot's goal and the ball every two seconds.
var trace := false
var _goal := ""


func _init(game_ref, policy_name: String, seed_number: int) -> void:
	game = game_ref
	policy = policy_name if policy_name in POLICIES else "skipper"
	seed_value = seed_number
	class_index = seed_number % 2
	rng.seed = hash([policy, seed_number])


# Call once the game's flow exists. Reseeding the run's stream makes each seed its own
# stage plan (events, scrap, spawns); the base seed alone would give every run of a
# policy the same map draw.
func start() -> void:
	game.ctx.rng.seed = 20260926 + seed_value * 7919
	game.player.source = source
	var events = game.events
	events.stage_entered.connect(_on_stage_entered)
	events.stage_cleared.connect(func(_s: int): _close_note())
	events.reward_offered.connect(_on_offers)
	events.reward_chosen.connect(func(_id: String): _offers = [])
	events.player_died.connect(func(): _end("died"))
	events.run_ended.connect(func(won: bool): _end("won" if won else "lost"))
	events.beacon_unsealed.connect(func(_s: int): _note_set("warden_broken_s", snappedf(game.run.stage_time, 0.01)))
	events.event_started.connect(func(id: String): _note_add("events_joined", id))
	events.core_gained.connect(func(source_id: String, _at: Vector3, _n: int): _note_add("cores", source_id))
	events.part_gained.connect(func(id: String, source_id: String): _note_add("parts", "%s:%s" % [source_id, id]))
	game.flow.press_start()
	game.flow.choose_class(class_index)


func class_id() -> String:
	return game.run.class_id()


# One physics tick. Returns true when the run is over.
func tick(delta: float) -> bool:
	if outcome != "":
		return true
	ticks += 1
	var flow = game.flow
	var state: String = flow.state_name()
	match state:
		"boss":
			_end("boss")
			return true
		"dead":
			_end("died")
			return true
		"summary":
			_end("won")
			return true
	if not flow.in_play():
		source.hold = {}
		return false
	if (state == "stage" or state == "beacon") and game.run.stage_time > STAGE_LIMIT:
		_end("stalled")
		return true
	_boost_clock -= delta
	if trace and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var b: Vector3 = game.player.ball_position()
		print("  trace t=%.0f stage %d %s goal=%s ball=(%.0f, %.0f, %.0f) speed=%.1f hp=%.0f heft=%.2f" % [game.run.stage_time,
			game.run.stage, state, _goal, b.x, b.y, b.z, game.player.planar_velocity().length(), game.run.hp, game.run.heft()])
	match state:
		"stage", "beacon":
			_roam(delta)
		"gates":
			_to_gate(delta)
		_:
			source.hold = {}
	return outcome != ""


func _end(why: String) -> void:
	if outcome != "":
		return
	outcome = why
	_close_note()
	source.hold = {}


# --- stage bookkeeping ----------------------------------------------------------------

func _on_stage_entered(stage: int, _retry: bool) -> void:
	_close_note()
	_stage = stage
	_offers = []
	_gate_pick = -1
	_fight_phase = "charge"
	_fight_target = null
	_slow_time = 0.0
	_detour_time = 0.0
	_waypoints = []
	_waypoint_time = 0.0
	_vault_time = 0.0
	_vault_done = false
	_event_time = {}
	_event_skip = {}
	_wander_clock = 0.0
	_committed = policy == "skipper"
	_planned = false
	_note = {"stage": stage, "warden_broken_s": null, "exit_s": null, "events_joined": [], "cores": [], "parts": [],
		"vault_tried": false, "waypoints": 0, "stuck_detours": 0}


func _note_set(key: String, value) -> void:
	if not _note.is_empty():
		_note[key] = value


func _note_add(key: String, value) -> void:
	if not _note.is_empty():
		(_note[key] as Array).append(value)


func _close_note() -> void:
	if _note.is_empty():
		return
	_note["exit_s"] = snappedf(game.run.stage_time, 0.01)
	stage_notes.append(_note)
	_note = {}


# The completionist's route, laid once the build has laid out the stage: every scrap
# line end to end, nearest to the drop first, so its hoops are rolled through too.
func _plan() -> void:
	_planned = true
	if policy != "completionist":
		return
	var terrain = game.ctx.terrain
	var spawn: Vector3 = terrain.spawn_point(_stage)
	var beacon: Vector3 = terrain.beacon_point(_stage)
	var axis := Vector2(beacon.x - spawn.x, beacon.z - spawn.z).normalized()
	var lines: Array = terrain.scrap_lines(_stage).duplicate()
	lines.sort_custom(func(a, b): return _along(a, spawn, axis) < _along(b, spawn, axis))
	var at := Vector2(spawn.x, spawn.z)
	for line in lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		if at.distance_to(to) < at.distance_to(from):
			var swap := from
			from = to
			to = swap
		_waypoints.append(terrain.drop_point(from.x, from.y, 1.0))
		_waypoints.append(terrain.drop_point(to.x, to.y, 1.0))
		at = to
	_note["waypoints"] = _waypoints.size()


static func _along(line: Array, spawn: Vector3, axis: Vector2) -> float:
	var mid: Vector2 = ((line[0] as Vector2) + (line[1] as Vector2)) * 0.5
	return (mid - Vector2(spawn.x, spawn.z)).dot(axis)


# --- the roam: what to go for now ----------------------------------------------------

func _roam(delta: float) -> void:
	if not _planned:
		_plan()
	var warden: Node3D = game.flow.warden if is_instance_valid(game.flow.warden) else null
	match policy:
		"skipper":
			_fight(warden, delta)
		"completionist":
			_completionist(warden, delta)
		_:
			_random(warden, delta)


func _completionist(warden: Node3D, delta: float) -> void:
	var event := _event_goal(delta)
	if not event.is_empty():
		_goal = event["goal"]
		_drive(event["steer"], event.get("aim", null), delta)
		return
	if not _waypoints.is_empty():
		_waypoint_time += delta
		var ball: Vector3 = game.player.ball_position()
		if _flat(ball, _waypoints[0]) < WAYPOINT_REACHED or _waypoint_time > WAYPOINT_SECONDS:
			_waypoints.pop_front()
			_waypoint_time = 0.0
		if not _waypoints.is_empty():
			_goal = "waypoint %d" % _waypoints.size()
			_drive(_waypoints[0], _nearest_enemy(), delta)
			return
	var vault: Node3D = _vault()
	if vault != null and not _vault_done:
		_note["vault_tried"] = true
		_vault_time += delta
		if _vault_time > VAULT_SECONDS:
			_vault_done = true
		else:
			_goal = "vault"
			_fight(vault, delta)
			return
	_goal = "warden"
	_fight(warden, delta)


func _random(warden: Node3D, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	if warden != null and not _committed:
		_committed = _flat(ball, warden.global_position) < WANDER_COMMIT_DISTANCE or game.run.stage_time > WANDER_COMMIT_TIME
	if _committed or warden == null:
		_fight(warden, delta)
		return
	_wander_clock -= delta
	if _wander_clock <= 0.0:
		_wander_clock = rng.randf_range(WANDER_GAP.x, WANDER_GAP.y)
		var to_beacon: Vector3 = game.ctx.terrain.beacon_point(_stage) - ball
		var base := atan2(to_beacon.x, to_beacon.z)
		var angle := base + rng.randfn(0.0, WANDER_SPREAD)
		_wander_heading = Vector3(sin(angle), 0.0, cos(angle))
		if rng.randf() < 0.3:
			source.press["jump_pressed"] = true
	_goal = "wander"
	_drive(ball + _wander_heading * 30.0, _nearest_enemy(), delta)


# The stage's participatory event, when the completionist should be on it: its ring
# while armed, then the event's own target while live. Empty when there is none.
func _event_goal(delta: float) -> Dictionary:
	var world = game.world
	if world == null or world.events == null:
		return {}
	for offer in world.events.offers:
		var id: String = offer["id"]
		if _event_skip.has(id):
			continue
		var phase: int = offer["phase"]
		var model = offer["model"]
		if phase == EventDirector.LIVE:
			return {"goal": "live " + id, "steer": _live_target(id, model), "aim": _nearest_enemy()}
		if phase == EventDirector.ANNOUNCED or phase == EventDirector.ARMED:
			if game.run.stage_time > EVENT_LATEST:
				continue
			_event_time[id] = float(_event_time.get(id, 0.0)) + delta
			if _event_time[id] > EVENT_PURSUIT_SECONDS:
				_event_skip[id] = true
				continue
			var ring: Vector2 = model.ring
			return {"goal": "ring " + id, "steer": game.ctx.terrain.drop_point(ring.x, ring.y, 1.0), "aim": _nearest_enemy()}
		if phase == EventDirector.COOLDOWN:
			# One attempt each: a lost event is not chased round again.
			_event_skip[id] = true
	return {}


func _live_target(id: String, model) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	match id:
		"scrap_stampede":
			return model.hauler_position()
		"surge_run":
			var next: int = clampi(model.next_gate, 0, model.gates.size() - 1)
			var g: Vector2 = model.gates[next]
			return game.ctx.terrain.drop_point(g.x, g.y, 1.0)
		"hold_the_relay":
			var relay: Vector2 = model.relay
			var out := Vector2(ball.x - relay.x, ball.z - relay.y)
			if out.length() < 0.5:
				out = Vector2(1.0, 0.0)
			var around := out.normalized().rotated(0.7) * 12.0
			return game.ctx.terrain.drop_point(relay.x + around.x, relay.y + around.y, 1.0)
	var ring: Vector2 = model.ring
	return game.ctx.terrain.drop_point(ring.x, ring.y, 1.0)


# --- fighting a plated lock: ram laps with the gun held on it -------------------------

func _fight(target: Node3D, delta: float) -> void:
	_goal = "fight %s %s" % [String(target.get("kind")) if is_instance_valid(target) else "beacon", _fight_phase]
	if target == null or not is_instance_valid(target):
		# No lock stands (an unsealed stage): roll into the beacon's ring.
		_drive(game.flow.beacon.global_position, _nearest_enemy(), delta)
		return
	if target != _fight_target:
		_fight_target = target
		_fight_phase = "charge"
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	var distance := _flat(ball, at)
	var caps: bool = target.has_method("cap_points") and not (target.cap_points() as Array).is_empty()
	match _fight_phase:
		"charge":
			if distance < CHARGE_CLOSE:
				_fight_phase = "runup"
				_runup_time = 0.0
				var away := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
				if away.length() < 0.5:
					away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
				away = away.normalized().rotated(Vector3.UP, rng.randf_range(-0.7, 0.7))
				_runup_point = game.ctx.terrain.drop_point(at.x + away.x * RUNUP, at.z + away.z * RUNUP, 1.0)
			elif caps and distance < 9.0 and game.player.state.grounded and game.player.planar_velocity().length() > 8.0:
				source.press["jump_pressed"] = true
		"runup":
			_runup_time += delta
			if _flat(ball, _runup_point) < 4.0 or _runup_time > RUNUP_SECONDS:
				_fight_phase = "charge"
	var steer: Vector3 = at if _fight_phase == "charge" else _runup_point
	_drive(steer, target, delta)
	# Over a caps Warden and falling: slam onto it.
	if caps and not game.player.state.grounded and distance < 3.0 and game.player.state.velocity.y < 0.0:
		source.hold["brake_held"] = true


# --- the gates -----------------------------------------------------------------------

func _on_offers(offers: Array) -> void:
	_offers = offers
	_gate_pick = _choose_gate(offers)


func _choose_gate(offers: Array) -> int:
	if offers.is_empty():
		return -1
	match policy:
		"skipper":
			return 0
		"completionist":
			var best := 0
			var best_score := -1.0
			for i in offers.size():
				var o: Dictionary = offers[i]
				var score := float(o.get("tier", 1)) + (10.0 if String(o.get("synergy", "")) != "" else 0.0) \
					+ (0.5 if String(o.get("mark", "")) != "" else 0.0)
				if score > best_score:
					best_score = score
					best = i
			return best
	return rng.randi_range(0, offers.size() - 1)


func _to_gate(delta: float) -> void:
	_goal = "gate %d" % _gate_pick
	if _offers.is_empty() or _gate_pick < 0:
		source.hold = {"move": Vector2(0.0, 1.0)}
		return
	var offer: Dictionary = _offers[mini(_gate_pick, _offers.size() - 1)]
	var at: Vector3 = offer["at"]
	var facing: Vector3 = offer["facing"]
	var rel: Vector3 = game.player.ball_position() - at
	var along := rel.dot(facing)
	var side := (rel - facing * along).length()
	# Lined up behind the arch: roll through it. Otherwise swing round behind it first.
	var target := at - facing * 9.0
	if side < 2.5 and along < 1.0:
		target = at + facing * 10.0
	_drive(target, null, delta)


# --- the hands: stick, mouse and buttons ---------------------------------------------

# Rolls toward steer and looks at aim (or along the way when there is nothing to aim
# at). The stick is set in the camera's frame, as a person's WASD is.
func _drive(steer: Vector3, aim, delta: float) -> void:
	var player = game.player
	var ball: Vector3 = player.ball_position()
	var speed: float = player.planar_velocity().length()
	if speed < STUCK_SPEED and player.state.grounded:
		_slow_time += delta
	else:
		_slow_time = 0.0
	if _slow_time > STUCK_SECONDS and _detour_time <= 0.0:
		_slow_time = 0.0
		_detour_time = DETOUR_SECONDS
		var to := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z).normalized()
		_detour = to.rotated(Vector3.UP, PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
		source.press["jump_pressed"] = true
		_note["stuck_detours"] = int(_note.get("stuck_detours", 0)) + 1
	var heading := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z)
	if _detour_time > 0.0:
		_detour_time -= delta
		heading = _detour
	var hold := {"fire_held": true}
	var look_at: Vector3 = ball + heading
	var aiming := false
	if aim != null and is_instance_valid(aim):
		look_at = _aim_point(aim)
		aiming = true
	_look(ball, look_at, aiming, delta)
	var yaw: float = game.camera.yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	if heading.length() > 0.3:
		var dir := heading.normalized()
		# Steer the velocity, not the ball: push toward the change that turns the current
		# velocity onto the target at the same speed, so a fast ball does not orbit it.
		var v: Vector3 = player.planar_velocity()
		v.y = 0.0
		var change := dir * maxf(v.length(), 12.0) - v
		var want := dir if change.length() < 0.5 else change.normalized()
		hold["move"] = Vector2(want.dot(right), want.dot(forward)).normalized()
		var lined: float = v.normalized().dot(dir) if v.length() > 0.5 else 1.0
		# The brake tightens a turn on the ground (BRAKE_TURN_BOOST); off-line and quick, carve.
		if player.state.grounded and v.length() > DRIFT_SPEED and lined < DRIFT_LINE:
			hold["brake_held"] = true
		if _boost_clock <= 0.0 and lined > 0.9 and player.state.grounded:
			_boost_clock = BOOST_GAP
			source.press["boost_pressed"] = true
	source.hold = hold


func _look(ball: Vector3, point: Vector3, pitch_to: bool, delta: float) -> void:
	var cam = game.camera
	var flat := Vector3(point.x - ball.x, 0.0, point.z - ball.z)
	var dyaw := 0.0
	if flat.length() > 0.3:
		var want := atan2(-flat.x, -flat.z)
		dyaw = clampf(wrapf(want - cam.yaw, -PI, PI), -TURN_RATE * delta, TURN_RATE * delta)
	var want_pitch := -0.30
	if pitch_to and flat.length() > 0.5:
		var pivot := ball + Vector3.UP * 0.8
		want_pitch = clampf(atan2(point.y - pivot.y, flat.length()), -1.2, 0.5)
	var dpitch := clampf(want_pitch - cam.pitch, -TURN_RATE * delta, TURN_RATE * delta)
	# camera.look takes mouse pixels: yaw -= x * s, pitch -= y * s.
	cam.look(Vector2(-dyaw / SENSITIVITY, -dpitch / SENSITIVITY))


func _aim_point(target: Node3D) -> Vector3:
	if target.has_method("weak_points"):
		var points: Array = target.weak_points()
		if not points.is_empty():
			return points[0]["at"]
	return target.global_position + Vector3.UP * 1.2


func _nearest_enemy() -> Node3D:
	var ball: Vector3 = game.player.ball_position()
	var best: Node3D = null
	var best_d := AIM_REACH
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		var d := ball.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _vault() -> Node3D:
	var world = game.world
	if world == null or world.vault == null or not is_instance_valid(world.vault):
		return null
	return world.vault


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# The sidecar record: who drove, what happened, how long it took.
func record(wall_seconds: float) -> Dictionary:
	return {
		"run_id": game.run.run_id, "policy": policy, "seed": seed_value, "class": class_id(),
		"outcome": outcome, "stage_reached": game.run.stage, "ticks": ticks,
		"game_seconds": snappedf(float(ticks) / float(Engine.physics_ticks_per_second), 0.01),
		"wall_seconds": snappedf(wall_seconds, 0.01), "stages": stage_notes,
	}
