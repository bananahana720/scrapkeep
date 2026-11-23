extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")
const FightPhases := preload("res://src/combat/fight_phases.gd")
const T := preload("res://tests/support/t.gd")

# What the bot driver reads in a Brindle fight (W46-T5, bot_brindle_short_test red on stage/alpha-w46).
#
# 1. A knockback is not punch. A real game in Brindle's phase 3 takes a real Scuttle charge hit, then
#    the ball is given a 160 m/s planar speed, the kind of throw that read as punch 589 at seed 4. The
#    bot's punch reading must stay under the clash punch, so _clash_viable on a lane staged to clash
#    says no; with the clash punch handed in directly the same lane says yes, so only the punch gate
#    differs.
# 2. The Furnace's cued close vent ring. A fake boss holds the game's harmless preview band (a real
#    Hazard made as boss.gd _bone_ring makes it: reach 0) for the inner ring, with no hazard committed
#    yet. After the bot's reaction time its threat list holds the ring, and its phase 2 move rolls out
#    past the ring instead of the ram run-up (_fight). The ring stays known when it commits.
# 3. Scrap inside, or on the edge of, a live slag ring is not chased; the scrap outside it is.
#
# Evidence limit: 2 and 3 step the driver's own functions against a fake boss and a ball that does not
# move; they show what the bot perceives and where it steers, not that it gets out in time. The fight
# itself is bot_brindle_short_test.

const DT := 1.0 / 90.0
const THROW := 160.0
const CLASH_PUNCH := 150.0


class FakeState:
	var grounded := true
	var air_actions := 1
	var velocity := Vector3.ZERO


class FakePlayer:
	var at := Vector3.ZERO
	var state := FakeState.new()

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return Vector3(state.velocity.x, 0.0, state.velocity.z)


class FakeFlow:
	func state_name() -> String:
		return "boss"


class FakeCtx:
	var boss


class FakeGame extends Node:
	var bot_driven := false
	var player := FakePlayer.new()
	var flow := FakeFlow.new()
	var ctx := FakeCtx.new()


class FakeArena extends Node3D:
	func radius_of(p: Vector3) -> float:
		return Vector2(p.x, p.z).length()

	func angle_of(p: Vector3) -> float:
		return atan2(p.z, p.x)

	func point_at(angle: float, r: float) -> Vector3:
		return Vector3(cos(angle) * r, 0.0, sin(angle) * r)

	func ground(_p: Vector3) -> float:
		return 0.0


class FakeHull extends Node3D:
	var radius := 4.5

	func fight() -> String:
		return "posture"

	func staggered() -> bool:
		return false


class FakeShip:
	var hull: Node3D


class FakeBoss:
	var phase := 2
	var ship := FakeShip.new()
	var arena: Node3D
	var preview: Node3D = null
	var hazards: Array = []
	var pickups: Array = []
	var clash_punch := CLASH_PUNCH
	var _charge := {}

	func enter_arena(_v: Vector3) -> void:
		pass

	func active() -> bool:
		return true

	func reprise_preview() -> Node3D:
		return preview

	func active_hazards() -> Array:
		return hazards.filter(func(h): return is_instance_valid(h) and not h.is_done())

	func pickups_left() -> Array:
		return pickups


class Probe extends BotDriver:
	var steered := Vector3.INF
	var evaded := true
	var rams := 0

	func _init(game_ref) -> void:
		super(game_ref, "skipper", 1)
		boss_note = {"hits": 0}

	func _act(steer: Vector3, _aim, _delta: float, _fight_node: Node3D = null, evade := true) -> void:
		steered = steer
		evaded = evade

	func _fight(_target: Node3D, _delta: float) -> void:
		rams += 1

	func _count(_key: String, _by: float = 1.0) -> void:
		pass


var _t := T.new("bot_brindle_rings_test")
var _game
var _driver
var _boss
var _frames := 0
var _hit_at := -1
var _spike := 0.0
var _seen_max := 0.0


func _initialize() -> void:
	_check_cued_ring()
	_check_pickups()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


# --- 1. a knockback is not punch ---------------------------------------------------------

func _physics_process(delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", 4)
		_driver.class_index = BotDriver.class_index_for(4, "tarn")
		_driver.start()
		return false
	if _boss == null:
		if _game.flow.state_name() == "stage" and _game.run.stage == 1:
			_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
			_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
			_boss = _game.ctx.boss
			_boss.jump_to_phase(3)
		else:
			_driver.tick(delta)
		return false
	_frames += 1
	# A few frames in the fight first, so the driver has opened its boss note.
	if _frames == 10:
		_game.run.damage(5.0, "brindle_charge")
		_hit_at = _frames
	if _hit_at > 0:
		# The throw: the ball's planar speed the frame the driver reads it.
		_game.player.state.velocity = Vector3(THROW, 0.0, 0.0)
		_spike = maxf(_spike, float(_game.flow.punch_now()))
	_driver.tick(delta)
	if _hit_at > 0:
		_seen_max = maxf(_seen_max, float(_driver.get("_punch_seen")))
	if _hit_at < 0 or _frames < _hit_at + 30:
		return false
	_t.check("the throw reads as punch past the clash punch", _spike >= CLASH_PUNCH, "punch_now peaked at %.1f" % _spike)
	_t.check("the bot does not take the knockback as its punch", _seen_max < CLASH_PUNCH,
		"punch reading peaked at %.1f, clash punch %.0f" % [_seen_max, CLASH_PUNCH])
	var staged := _stage_clash()
	var fake: FakeBoss = staged["boss"]
	var h = staged["lane"]
	var ball: Vector3 = staged["ball"]
	var id: int = h.get_instance_id()
	_driver.get("_clash_latched")[id] = true
	_t.check("the staged lane clashes with a real clash punch", _driver._clash_viable(fake, h, ball, CLASH_PUNCH + 1.0, id), "control")
	_t.check("no clash on the knockback's reading", not _driver._clash_viable(fake, h, ball, float(_driver.get("_punch_seen")), id),
		"punch reading %.1f" % float(_driver.get("_punch_seen")))
	h.free()
	_game.free()
	_game = null
	quit(_t.verdict())
	return true


# A charge lane down -z from 60 m out, the ball 40 m along it on the axis, the lane still braced.
func _stage_clash() -> Dictionary:
	var fake := FakeBoss.new()
	var half := Requisition.HULL.z * 0.5
	var from := Vector3(0.0, 0.0, 60.0)
	var h := Hazard.new()
	h.commit_lane("charge", Hazard.Threat.Type.LANE, from, Vector3.FORWARD, half, 70.0 + half, Requisition.HULL.x * 0.5 + 1.0,
		Requisition.HULL.y + 0.5, 1.4, 70.0 / BossRules.CHARGE_SPEED + 0.2)
	fake._charge = {"state": "brace", "hazard": h, "travelled": 0.0}
	return {"boss": fake, "lane": h, "ball": from + Vector3.FORWARD * 40.0}


# --- 2. the cued close vent ring ---------------------------------------------------------

func _check_cued_ring() -> void:
	var game := FakeGame.new()
	var arena := FakeArena.new()
	var hull := FakeHull.new()
	var boss := FakeBoss.new()
	boss.arena = arena
	boss.ship.hull = hull
	game.ctx.boss = boss
	var bot := Probe.new(game)
	game.player.at = Vector3(8.0, 0.0, 0.0)

	# Control: no ring cued, the phase 2 move is the hull's ram routine.
	bot._fight_boss(DT)
	_t.eq("no ring cued: the bot rams", bot.rams, 1)

	# Ring A cued (16 to 21 m): not the close ring, so the ram routine goes on.
	boss.preview = _preview(Vector2(16.0, 21.0))
	for i in 30:
		bot.ticks += 1
		bot._fight_boss(DT)
	_t.eq("ring A cued: still the ram routine", bot.rams, 31)
	boss.preview.free()
	boss.preview = null

	# The inner ring cued: the preview band is up, nothing is committed.
	boss.preview = _preview(BossRules.FURNACE_CLOSE_BAND)
	var reaction_ticks := ceili(0.25 * Engine.physics_ticks_per_second)
	var first_threat := -1
	var first_out := -1
	var rams_cued := 0
	# Each tick as the fight runs it: the move, then the threat list _act reads.
	for i in reaction_ticks + 10:
		bot.ticks += 1
		var rams_was := bot.rams
		bot._fight_boss(DT)
		if first_out < 0 and bot._goal == "boss ring out":
			first_out = i
		if first_out >= 0:
			rams_cued += bot.rams - rams_was
		if first_threat < 0 and not bot._threats().is_empty():
			first_threat = i
	_t.check("the cue is a threat before its warning starts", first_threat >= 0 and boss.active_hazards().is_empty(),
		"first in the threat list after %d ticks, %d hazards committed" % [first_threat, boss.active_hazards().size()])
	_t.check("the cue is read after the reaction time, not before", first_threat >= reaction_ticks - 1,
		"after %d ticks, reaction %d" % [first_threat, reaction_ticks])
	_t.check("the move leaves the ram once the cue is read", first_out >= reaction_ticks - 1 and first_out <= first_threat + 1,
		"out at tick %d, threat at tick %d" % [first_out, first_threat])
	var r_steer: float = arena.radius_of(bot.steered)
	_t.check("inner ring cued: no ram run-up once read", first_out >= 0 and rams_cued == 0, "out at tick %d, %d rams after" % [first_out, rams_cued])
	_t.eq("inner ring cued: the goal is out of the ring", bot._goal, "boss ring out")
	_t.check("inner ring cued: steers past the ring", bot.steered.is_finite() and r_steer > BossRules.FURNACE_CLOSE_BAND.y + 2.0,
		"steer radius %.1f" % r_steer)
	_t.check("inner ring cued: steers away from the hull", bot.steered.is_finite() and bot.steered.x > game.player.at.x,
		"steer %s, ball %s" % [bot.steered, game.player.at])
	_t.check("inner ring cued: the roll out is not turned under the hull by the generic escape", not bot.evaded, "evade %s" % bot.evaded)

	# The reprise commits: the preview goes and the cued ring warns for 0.6 s. A player who saw the
	# preview knows this ring at once.
	boss.preview.free()
	boss.preview = null
	var ring := _ring("slag_ring_inner", BossRules.FURNACE_CLOSE_BAND, true)
	boss.hazards = [ring]
	var rams_committed := bot.rams
	bot.ticks += 1
	bot._fight_boss(DT)
	_t.eq("inner ring committed: still out of the ring on its first tick", bot._goal, "boss ring out")
	_t.eq("inner ring committed: no ram run-up", bot.rams, rams_committed)

	# Ring A is cued as well: the safe floor moves out past it.
	boss.preview = _preview(Vector2(16.0, 21.0))
	for i in reaction_ticks + 2:
		bot.ticks += 1
		bot._fight_boss(DT)
	r_steer = arena.radius_of(bot.steered)
	_t.check("inner ring and ring A known: steers past ring A", bot.steered.is_finite() and r_steer > 21.0 + 2.0, "steer radius %.1f" % r_steer)

	boss.preview.free()
	ring.free()
	hull.free()
	arena.free()
	game.free()


# --- 3. scrap on a live ring -------------------------------------------------------------

func _check_pickups() -> void:
	var game := FakeGame.new()
	var arena := FakeArena.new()
	var boss := FakeBoss.new()
	boss.arena = arena
	game.ctx.boss = boss
	var bot := Probe.new(game)
	game.player.at = Vector3(19.0, 0.0, 0.0)
	var inside := Vector3(13.0, 0.0, 0.0)
	var edge := Vector3(17.5, 0.0, 0.0)
	var outside := Vector3(27.0, 0.0, 0.0)
	boss.pickups = [{"at": inside, "source": "kill"}, {"at": outside, "source": "kill"}]
	_t.eq("no ring: the nearest scrap", bot._nearest_pickup(boss, game.player.at), inside)

	var ring := _ring("slag_ring_inner", BossRules.FURNACE_CLOSE_BAND, false)
	ring.state = Hazard.LIVE
	boss.hazards = [ring]
	for i in ceili(0.25 * Engine.physics_ticks_per_second) + 2:
		bot.ticks += 1
		bot._nearest_pickup(boss, game.player.at)
	_t.eq("live inner ring: the scrap inside it is left", bot._nearest_pickup(boss, game.player.at), outside)
	boss.pickups = [{"at": edge, "source": "kill"}, {"at": outside, "source": "kill"}]
	_t.eq("live inner ring: the scrap on its edge is left", bot._nearest_pickup(boss, game.player.at), outside)

	ring.free()
	arena.free()
	game.free()


# The harmless preview band boss.gd _bone_ring draws for a cued reprise: no reach.
func _preview(band: Vector2) -> Node3D:
	var h := Hazard.new()
	h.warn_floor = FightPhases.CUE_LEAD
	h.commit_annulus("preview_reprise_slag", Hazard.Threat.Type.INSTANT, Vector3.ZERO, band, 0.0, FightPhases.CUE_LEAD, 0.01)
	return h


func _ring(id: String, band: Vector2, cued: bool) -> Node3D:
	var h := Hazard.new()
	if cued:
		h.warn_floor = FightPhases.CUED_WARN
		h.cued = true
	h.commit_annulus(id, Hazard.Threat.Type.INSTANT, Vector3.ZERO, band, BossRules.SLAG_REACH,
		FightPhases.CUED_WARN if cued else BossRules.SLAG_WARN, BossRules.REEL_SLAG_LIVE)
	return h
