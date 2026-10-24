# smoke: solo (the surge's siren and front run at wall pace)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")

# The flume's surge course in the running game (activities.gd surge_run, the park's sluice_surge row).
# (a) the flume builds the course on flume_upper with six gates on the decks' surfaces;
# (b) rolling into the ring opens the sluice: the park row is announced, then lands, and only then does the course
#     go live (the front is behind the head);
# (c) taking the gates in order wins it: one progress step per gate, the course's own event ends won, the sluice
#     row ends early and the win pays one part;
# (d) on a stage retry, a ball that waits in the ring is caught by the front: the course is lost, the sluice row ends,
#     and it does not re-open inside retry_s.
# Until the flume's park file carries the two rows (unit 11), the test adds them to the loaded map.

const SEED := 31
const COURSE := {"id": "weir_surge", "activity": "surge_run", "site": "weir_intake", "at": [-384, -612], "pack": [],
	"pay": {"rarities": ["common", "rare"]}, "route": "flume_upper"}
const SLUICE := {"id": "head_gate_sluice", "kind": "sluice_surge", "family": "industrial", "site": "weir_intake",
	"trigger": {"on": "activity", "value": "weir_surge"}, "weight": 1.0,
	"telegraph": {"lead_s": 4.0, "form": "sluice_siren", "on_bar": true}, "live_s": 45.0, "effect": {},
	"route_change": {"closes": [], "opens": []}, "hold_clear_m": 0.0, "cooldown_s": 0.0, "once": false,
	"music_cue": {"telegraph": "riser_industrial", "land": "drop_industrial"}}
# The weir reach's floor between its walls; the gap reach's work deck stands above the ground beneath it.
const WEIR_TOP := 109.4
const GAP_LOW := 66.0
const GAP_START := 69.0
const OPEN_SECONDS := 12.0
const GATE_FRAMES := 30
const LOSE_SECONDS := 60.0
const EXPECTED_CHECKS := 12

var _game
var _t := preload("res://tests/support/t.gd").new("surge_course_park_test")
var _log: Array = []


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
	_game.player.source = Intent.Scripted.new()
	for sig in ["event_announced", "event_started", "event_ended", "event_progress"]:
		_game.events.connect(sig, func(a = null, b = null): _log.append([sig, a, b]))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)


# Until the park file carries the rows: they go into the entered stage's map, the activities rebuild from it, and the
# director takes the sluice row as its park build would have.
func _inject() -> void:
	var map = _game.ctx.terrain.map()
	map.park.activity_rows.append(COURSE.duplicate(true))
	map.park.event_rows.append(SLUICE.duplicate(true))
	map.activity_sites.append({"id": "surge_run", "row": COURSE.id, "site": COURSE.site,
		"at": Vector2(COURSE.at[0], COURSE.at[1]), "pay": COURSE.pay.duplicate(true), "route": COURSE.route})
	_game.world.activities._enter_stage(false)
	var director = _game.world.events
	director._park.event_rows.append(SLUICE.duplicate(true))
	director._park_states.append(director._park_state(SLUICE.duplicate(true), false))


func _seen(sig: String, id: String) -> Array:
	return _log.filter(func(e): return e[0] == sig and e[1] == id)


func _hold(at: Vector3) -> void:
	_game.player.reset_to(at + Vector3(0.0, 1.05, 0.0), Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await physics_frame


func _run() -> void:
	await _boot()
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	_inject()
	_log.clear()
	await _win()
	_log.clear()
	_game.flow.enter_stage(2, Vector3.ZERO, true)
	await _frames(4)
	_inject()
	await _lose()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _open(s) -> bool:
	var ring: Vector3 = s.global_position
	for frame in int(OPEN_SECONDS * Engine.physics_ticks_per_second):
		await _hold(ring)
		if s.surge_live:
			return true
	return false


func _win() -> void:
	var s = _game.world.activities.site("surge_run")
	_t.check("(a) the flume builds the course", s != null and s.course != null and s.course.model.gates.size() == 6, "no course")
	if s == null or s.course == null:
		return
	var live := await _open(s)
	# Live, the gates stand on the decks found by ray: the gap reach's work deck starts on the ground and climbs.
	var h: Array = s.course.model.gate_heights
	_t.check("(a) its gates stand on the decks' surfaces", absf(h[0] - WEIR_TOP) < 0.5 and h[3] < GAP_START + 1.0 and h[5] > GAP_LOW
		and h[5] < WEIR_TOP - 10.0, str(h))
	var announced := _seen("event_announced", SLUICE.id)
	var started := _seen("event_started", "surge_run")
	_t.check("(b) the ring opens the sluice, and the course goes live when it lands", live and announced.size() == 1
		and started.size() == 1 and _log.find(announced[0]) < _log.find(started[0]), str(_log))
	_t.check("(b) the front starts behind the head", s.course.model.front < 0.0, str(s.course.model.front))
	var parts_before: int = _game.run.parts.size()
	for gate in s.course.model.gates.size():
		for frame in GATE_FRAMES:
			await _hold(s.course.next_gate_point())
			if s.course.model.next_gate > gate or s.done:
				break
	await _frames(3)
	_t.check("(c) the gates in order win it", s.done and _seen("event_ended", "surge_run").map(func(e): return e[2]) == ["won"], str(_seen("event_ended", "surge_run")))
	_t.check("(c) one progress step per gate", _seen("event_progress", "surge_run").size() >= 6, str(_seen("event_progress", "surge_run").size()))
	_t.check("(c) the sluice row ends early", _seen("event_ended", SLUICE.id).size() == 1, str(_seen("event_ended", SLUICE.id)))
	_t.eq("(c) the win pays one part", _game.run.parts.size() - parts_before, 1)


func _lose() -> void:
	var s = _game.world.activities.site("surge_run")
	if s == null or s.course == null:
		_t.check("(d) the retry builds the course", false, "no course")
		return
	await _open(s)
	var ring: Vector3 = s.global_position
	for frame in int(LOSE_SECONDS * Engine.physics_ticks_per_second):
		await _hold(ring)
		if not _seen("event_ended", "surge_run").is_empty():
			break
	_t.check("(d) waiting in the ring loses to the front", _seen("event_ended", "surge_run").map(func(e): return e[2]) == ["lost"] and not s.done,
		str(_seen("event_ended", "surge_run")))
	_t.check("(d) the sluice row ends with it", _seen("event_ended", SLUICE.id).size() == 1, str(_seen("event_ended", SLUICE.id)))
	for frame in int((float(s.rule.retry_s) - 1.0) * Engine.physics_ticks_per_second):
		await _hold(ring)
	_t.check("(d) it does not re-open inside retry_s", not s.started and _seen("event_announced", SLUICE.id).size() == 1, str(_seen("event_announced", SLUICE.id)))
