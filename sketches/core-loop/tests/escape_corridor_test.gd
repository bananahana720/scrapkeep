extends SceneTree

# Rule (GP4): after a survived low-hull hit the seated escape piece acts within one frame, once
# per stage. The vent shoves the ball away from the hitter (speed rises, never past the cap);
# the rail lays a slick lane along its travel. escape_acted fires once, the body flares or
# flicks for the act's seconds and then shows spent until a fresh stage. A lethal hit opens
# nothing, revives nothing and spends no retry.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("escape_corridor_test")
var _game
var _acts: Array = []
var _windows := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _seat(pair: Array) -> void:
	var c := Companion.new()
	for id in pair:
		c.acquire(id)
	_t.eq("assemble %s" % [pair], c.assemble(pair), "")
	_game.run.companion = c.to_dict()


func _fresh_stage() -> void:
	_game.run._on_stage_entered(_game.run.stage, false)
	_game.ctx.spawner._on_stage_entered(_game.run.stage, false)


# The hit door at identity: the dam (stage 1) ships mob hits at x2 (ChallengeDials MOBS_DAMAGE_W1).
func _hit(amount: float) -> void:
	ChallengeDials.set_overrides({"mobs.damage_by_stage": ChallengeDials.ONES6})
	_game.ctx.spawner._on_player_hit(amount, Vector3(0.0, 0.0, 0.2), "test")
	ChallengeDials.reset()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _ticks(5)
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _ticks(12)
	var run = _game.run
	var combat = ctx.spawner
	var body = _game.presentation.get_node("CompanionBody")
	run.set_max_hp(100.0)
	combat.escape_acted.connect(func(piece: String, style: String): _acts.append([piece, style]))
	ctx.events.escape_window.connect(func(_s: float): _windows += 1)
	var retries: int = run.retries

	_t.eq("vent row", Companion.escape_of("escape_vent"), {"style": "shove", "seconds": 1.2})
	_t.eq("rail row", Companion.escape_of("escape_rail"), {"style": "lane", "seconds": 1.2})
	_t.eq("pieces table sound", Companion.validate(), [])

	# GP4-1, vent: a shove away from the hitter.
	_seat(["escape_vent", "ram_prow"])
	_fresh_stage()
	run.hp = 30.0
	_game.player.set_velocity_now(Vector3(4.0, 0.0, 0.0))
	await _ticks(2)
	await process_frame
	await process_frame
	_t.eq("vent ready before the hit", combat.escape_phase(), "ready")
	_t.eq("body lamp ready", body.escape_cue(), "ready")
	var before: Vector3 = _game.player.planar_velocity()
	_hit(10.0)
	_t.near("hit leaves 0.2 hull", run.hp / run.max_hp, 0.2, 0.01)
	_t.eq("vent acts on the hit", _acts, [["escape_vent", "shove"]])
	_t.eq("one window", _windows, 1)
	_t.eq("acting", combat.escape_phase(), "acting")
	# The physics_frame signal comes before the step, so the second wait sees one step done.
	await _ticks(2)
	var after: Vector3 = _game.player.planar_velocity()
	var cap := maxf(before.length() * Companion.ESCAPE_SHOVE_CAP, Companion.ESCAPE_SHOVE_FLOOR)
	_t.check("shove raises speed within one frame", after.length() > before.length() + 2.0 and after.length() <= cap + 0.5,
		"speed %.2f -> %.2f, cap %.2f" % [before.length(), after.length(), cap])
	_t.check("shove points away from the hitter", after.z - before.z > 2.0, "z %.2f -> %.2f" % [before.z, after.z])
	await _ticks(1)
	await process_frame
	await process_frame
	_t.eq("body flares", body.escape_cue(), "flare")
	_hit(10.0)
	_t.eq("second low hit acts nothing", _acts.size(), 1)
	_t.eq("window does not re-open", _windows, 1)
	_t.check("no revive and hull kept", run.hp > 0.0 and run.hp <= 11.0, "hp %.1f" % run.hp)

	# GP4-3: spent after the act's seconds, cleared by a fresh stage.
	var until: float = combat._escape["until"]
	var guard := 0
	while combat._clock < until and guard < 200:
		if guard % 30 == 0:
			_t.check("acting until %.2f" % until, combat.escape_phase() == "acting", "clock %.3f" % combat._clock)
		await _ticks(1)
		guard += 1
	_t.eq("spent once the seconds pass", combat.escape_phase(), "spent")
	await _ticks(1)
	await process_frame
	await process_frame
	_t.eq("body shows spent", body.escape_cue(), "spent")
	_t.check("spent lamp dimmed", body._lamp.material_override.emission_energy_multiplier < body.LAMP_ENERGY["ready"], "energy %.2f" % body._lamp.material_override.emission_energy_multiplier)
	_fresh_stage()
	_t.eq("fresh stage re-arms", combat.escape_phase(), "ready")
	await _ticks(1)
	await process_frame
	await process_frame
	_t.eq("body lamp lit again", body.escape_cue(), "ready")

	# GP4-1, rail: a slick lane along the ball's travel.
	_seat(["escape_rail", "ram_prow"])
	_fresh_stage()
	run.hp = 30.0
	_game.player.set_velocity_now(Vector3(6.0, 0.0, 0.0))
	await _ticks(2)
	_hit(10.0)
	_t.eq("rail acts on the hit", _acts.size(), 2)
	_t.eq("rail act style", _acts.back(), ["escape_rail", "lane"])
	_t.eq("two windows over two stages", _windows, 2)
	var lane: Dictionary = combat.escape_lane
	_t.check("lane region exists", not lane.is_empty() and lane["length"] == Companion.ESCAPE_LANE_LENGTH
		and lane["friction"] == Companion.ESCAPE_LANE_FRICTION and Vector3(lane["dir"]).x > 0.9, "lane %s" % [lane])
	await _ticks(1)
	await process_frame
	await process_frame
	_t.eq("body flicks", body.escape_cue(), "flick")
	_hit(5.0)
	_t.eq("rail does not re-open", [_acts.size(), _windows], [2, 2])

	# GP4-2: a lethal hit opens nothing and revives nothing.
	_fresh_stage()
	run.hp = 5.0
	_hit(10.0)
	_t.eq("lethal hit acts nothing", [_acts.size(), _windows], [2, 2])
	_t.check("dead stays dead", run.hp == 0.0 and not run.alive(), "hp %.1f" % run.hp)
	_t.check("charge untouched by the death", run.companion["escape_spent"] == false, "doc %s" % [run.companion])
	_t.eq("no retry spent by the corridor", run.retries, retries)
	quit(_t.verdict())
