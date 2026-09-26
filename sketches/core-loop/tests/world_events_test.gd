extends SceneTree

const StageDefs := preload("res://src/core/stage_defs.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
const Sluice := preload("res://src/world/map_sluice.gd")
const Weir := preload("res://src/world/map_weir.gd")

# The event director stepped headless at a fixed h with no wall clock (TADR-010):
# every stage's events announce with their lead before they go live, a player who
# opts in can win each participatory event and it publishes a milestone, a player
# who ignores them never starts one, the miniboss spot follows the seed, and no
# world push brakes the ball.

const H := 1.0 / 90.0
const SECONDS := 300.0
const CRUISE := 14.0
const FAR := Vector3(400.0, 0.0, 400.0)
const SEEDS := [11, 29, 47, 83, 131, 197]
const EXPECTED := {
	1: ["flood", "scrap_stampede"],
	2: ["flood", "dust_squall", "surge_run"],
	3: ["flood", "dust_squall", "surge_run", "hold_the_relay"],
}

var _failures := 0
var _maps := [Spillway.new(), Sluice.new(), Weir.new()]


func _initialize() -> void:
	for stage in [1, 2, 3]:
		_check_stage(stage)
	_check_skip()
	_check_miniboss_seeds()
	_check_pushes()
	print("world_events_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _director(stage: int, seed_value: int) -> RefCounted:
	var map = _maps[stage - 1]
	var height := func(x: float, z: float) -> float: return map.sample(x, z)[0]
	return EventDirector.new(seed_value, StageDefs.of(stage), map, CRUISE, height)


# Plays the opted-in player: into a ring once it is armed, then onto whatever the live
# event asks for (the next gate, the hauler, the relay).
static func _autopilot(director, map) -> Vector3:
	for offer in director.offers:
		if offer["phase"] != EventDirector.LIVE:
			continue
		var model = offer["model"]
		match offer["id"]:
			"surge_run":
				var g: Vector2 = model.gates[mini(model.next_gate, model.gates.size() - 1)]
				return Vector3(g.x, map.sample(g.x, g.y)[0] + 1.0, g.y)
			"scrap_stampede":
				return model.hauler_position()
			"hold_the_relay":
				var r: Vector2 = model.relay
				return Vector3(r.x, map.sample(r.x, r.y)[0] + 1.0, r.y)
	for offer in director.offers:
		if offer["phase"] == EventDirector.ARMED:
			var ring: Vector2 = offer["model"].ring
			return Vector3(ring.x, 0.0, ring.y)
	return FAR


func _run(director, map, opt_in: bool) -> Array:
	var log := []
	var t := 0.0
	var steps := int(SECONDS / H)
	for i in steps:
		var ball: Vector3 = _autopilot(director, map) if opt_in else FAR
		for fact in director.advance(H, ball, Vector3.ZERO):
			log.append([t, fact])
		t += H
	return log


func _check_stage(stage: int) -> void:
	var director = _director(stage, 20260926 + stage)
	var log := _run(director, _maps[stage - 1], true)
	var announced := {}
	var seen := {}
	var early: Array[String] = []
	var unannounced: Array[String] = []
	var won: Array[String] = []
	var milestones: Array[String] = []
	var minibosses := 0
	for entry in log:
		var t: float = entry[0]
		var fact: Dictionary = entry[1]
		match fact["kind"]:
			"announced":
				announced[fact["id"]] = [t, fact["seconds"]]
			"started":
				seen[fact["id"]] = true
				if not announced.has(fact["id"]):
					unannounced.append(fact["id"])
				elif t + H * 1.5 < announced[fact["id"]][0] + announced[fact["id"]][1]:
					early.append("%s at %.2f s, announced %.2f s with %.1f s lead" % [fact["id"], t, announced[fact["id"]][0], announced[fact["id"]][1]])
			"ended":
				if fact["outcome"] == "won":
					won.append(fact["id"])
			"milestone":
				milestones.append(fact["id"])
			"miniboss":
				minibosses += 1
	var missing: Array[String] = []
	for id in EXPECTED[stage]:
		if not seen.has(id):
			missing.append(id)
	_report("stage %d events" % stage, missing.is_empty(),
		"went live in %d s: %s; expected %s; missing %s" % [int(SECONDS), seen.keys(), EXPECTED[stage], missing])
	_report("stage %d announce first" % stage, unannounced.is_empty() and early.is_empty(),
		"every start came after its announcement and lead; unannounced %s, early %s" % [unannounced, early])
	var participatory := 0
	for o in director.offers:
		participatory += 1
	_report("stage %d participatory" % stage, participatory >= 1,
		"%d opt-in event(s) offered: %s" % [participatory, director.offers.map(func(o): return o["id"])])
	_report("stage %d milestones" % stage, not won.is_empty() and won == milestones,
		"won %s, milestone facts %s" % [won, milestones])
	if stage == 3:
		_report("stage 3 miniboss", minibosses >= 2,
			"%d miniboss arrivals across the relay hold and the surge" % minibosses)


func _check_skip() -> void:
	var stuck: Array[String] = []
	var started: Array[String] = []
	for stage in [1, 2, 3]:
		var director = _director(stage, 7 + stage)
		for entry in _run(director, _maps[stage - 1], false):
			var fact: Dictionary = entry[1]
			if fact["kind"] == "started" and fact["id"] in EventDirector.PARTICIPATORY:
				started.append(fact["id"])
		for o in director.offers:
			if o["phase"] != EventDirector.ARMED:
				stuck.append("%s %s" % [o["id"], EventDirector.PHASE_NAMES[o["phase"]]])
	_report("skip stays optional", started.is_empty() and stuck.is_empty(),
		"a player who never rolls into a ring starts nothing in %d s per stage (started %s) and every offer waits armed (%s)"
			% [int(SECONDS), started, "all armed" if stuck.is_empty() else str(stuck)])


func _miniboss_spot(seed_value: int) -> Vector2:
	var director = _director(3, seed_value)
	var offer: Dictionary = director.offer("hold_the_relay")
	offer["timer"] = 0.0
	var relay: Vector2 = offer["model"].relay
	var ball := Vector3(relay.x, _maps[2].sample(relay.x, relay.y)[0] + 1.0, relay.y)
	for i in int(30.0 / H):
		for fact in director.advance(H, ball, Vector3.ZERO):
			if fact["kind"] == "miniboss" and fact["id"] == "hold_the_relay":
				return fact["at"]
	return Vector2.INF


func _check_miniboss_seeds() -> void:
	var spots: Array[Vector2] = []
	var distinct := 0
	var in_zone := true
	for s in SEEDS:
		var spot := _miniboss_spot(s)
		var fresh := true
		for other in spots:
			if other.distance_to(spot) < 4.0:
				fresh = false
		if fresh:
			distinct += 1
		spots.append(spot)
		var d := spot.distance_to(Weir.RELAY)
		if d < 30.0 or d > 48.0:
			in_zone = false
	var again := _miniboss_spot(SEEDS[0])
	_report("miniboss seeded", distinct == SEEDS.size() and in_zone and again.distance_to(spots[0]) < 0.001,
		"%d seeds put the relay miniboss at %d distinct spots %s, all 30 to 48 m from the relay %s; seed %d again lands %.3f m from its first spot"
			% [SEEDS.size(), distinct, spots.map(func(v): return "(%.0f, %.0f)" % [v.x, v.y]), in_zone, SEEDS[0], again.distance_to(spots[0])])


# The squall and the surge may steer and help; neither may oppose the ball's motion.
func _check_pushes() -> void:
	var director = _director(3, 5)
	var squall = director.squall
	squall.begin(10.0)
	squall.step(5.0)
	var offer: Dictionary = director.offer("surge_run")
	var model = offer["model"]
	offer["phase"] = EventDirector.LIVE
	model.begin()
	model.front = 20.0
	var on_front: Vector2 = model.route.at(24.0)
	var ball := Vector3(on_front.x, 0.0, on_front.y)
	var worst := 0.0
	var helped := 0
	for i in 36:
		var a := i * TAU / 36.0
		var v := Vector3(cos(a), 0.0, sin(a)) * 18.0
		var p: Vector3 = director.push(ball, v)
		worst = minf(worst, p.dot(v.normalized()))
		if p.dot(v.normalized()) > 1.0:
			helped += 1
	_report("pushes never brake", worst >= -0.0001 and squall.intensity() > 0.9 and helped > 0,
		"with the squall at full strength and the surge front on the ball, the worst push along the ball's motion is %.4f m/s2 over 36 headings; %d headings are helped" % [worst, helped])


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
