extends SceneTree

const Game := preload("res://src/game.gd")
const Roster := preload("res://src/combat/roster.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Director := preload("res://src/world/director.gd")
const DirectorCards := preload("res://src/world/director_cards.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const T := preload("res://tests/support/t.gd")

# The Spillway roster (design-v3/SPILLWAY-ROSTER.md):
# - tables: the dam names five packs and the flume six, both tables agree, both stages share
#   the Spillway elite, and the three re-admitted kinds fight in world 1 only, each with a
#   director card and a finite pack cost;
# - soaked crews: the chaser, the hooker and the sluice flap read "wet" (arc 150%, nothing
#   resisted); the jolt layer is dry;
# - wind-ups: each re-admitted kind's row names a sound SfxBank can play;
# - live: a sluice flap launches a FAST ball along its line and flings a slow one; a hooker's
#   tether snaps on a harpoon bite on world geometry ("hook"); a jolt layer's mat laid on
#   standing water spreads WET_SPREAD wider; a boom tender pins a cruising ball in its lane, and
#   a FAST ball bursts its floats instead, all five a strike. Each discovers its codex entry.

const SPILLWAY := ["jolt_layer", "hooker", "ramp_flipper", "boom_tender"]
const NEAR := Vector3(5.0, 0.0, 2.0)
const OFFSET := Vector3(9.0, 0.0, 3.0)
const LIMIT := 6.0

var _t := T.new("spillway_roster_test")
var _game
var _fleet
var _combat
var _ball_at := Vector3.ZERO
var _hooker: Node3D
var _clock := 0.0
var _started := false
var _done := false


# Stands in for combat's Ground under one jolt layer: everywhere is water.
class WetGround:
	extends RefCounted
	var dry
	func _init(ground) -> void:
		dry = ground
	func on_water(_point: Vector3) -> bool:
		return true
	func height(x: float, z: float) -> float:
		return dry.height(x, z)
	func height_at(point: Vector3) -> float:
		return dry.height_at(point)


func _initialize() -> void:
	_tables()
	_soaked()
	_windups()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _tables() -> void:
	for table in [AlphaDefs, ParkDefs]:
		var name := String(table.resource_path.get_file())
		_t.eq("%s pack counts" % name, [table.DEFS[0]["packs"].size(), table.DEFS[1]["packs"].size()], [5, 6])
		_t.eq("%s Spillway elite" % name, [table.DEFS[0]["elite"]["kinds"], table.DEFS[1]["elite"]["id"]],
			[["hooker", "jolt_layer", "plated_brute"], "elite"])
	_t.eq("both tables name the same Spillway packs", [AlphaDefs.PACKS_DAM, AlphaDefs.PACKS_FLUME, AlphaDefs.ELITE_SPILLWAY],
		[ParkDefs.PACKS_DAM, ParkDefs.PACKS_FLUME, ParkDefs.ELITE_SPILLWAY])
	var outside := []
	var stages := {}
	for row in AlphaDefs.DEFS:
		var kinds: Array = row["elite"]["kinds"].duplicate()
		for pack in row["packs"]:
			kinds.append_array(pack["kinds"])
		for kind in SPILLWAY:
			if kind in kinds:
				if int(row["world"]) != 1:
					outside.append([row["stage"], kind])
				stages[kind] = int(stages.get(kind, 0)) + 1
		for pack in row["packs"] + [row["elite"]]:
			if not is_finite(DirectorCards.cost(pack["kinds"])):
				outside.append([row["stage"], pack["id"], "cost"])
	_t.eq("every re-admitted kind is on both Spillway stages and nowhere else", [stages, outside],
		[{"jolt_layer": 2, "hooker": 2, "ramp_flipper": 2, "boom_tender": 2}, []])
	var wired := []
	for kind in SPILLWAY:
		wired.append([Roster.built(kind), int(Roster.row(kind).get("world", 0)), Director.KIND_NAMES.has(kind), DirectorCards.CARDS.has(kind)])
	_t.eq("each is a built world 1 kind with a director card", wired, [[true, 1, true, true], [true, 1, true, true], [true, 1, true, true], [true, 1, true, true]])
	_t.check("the hooker breaks on a hook", "hook" in Roster.row("hooker")["breaks"], str(Roster.row("hooker")["breaks"]))


func _soaked() -> void:
	_t.eq("wet: arc weak, kinetic and frost plain, abilities plain",
		[DamageFamilies.mult("wet", "arc", ""), DamageFamilies.mult("wet", "ram", ""), DamageFamilies.mult("wet", "frost", ""),
			DamageFamilies.mult("wet", "ram", DamageFamilies.ABILITY)], [1.5, 1.0, 1.0, 1.0])
	var kinds := {}
	for kind in ["chaser", "hooker", "ramp_flipper", "boom_tender", "jolt_layer", "lobber"]:
		kinds[kind] = String(DamageFamilies.ARMOUR_OF.get(kind, ""))
	_t.eq("the soaked crews", kinds, {"chaser": "wet", "hooker": "wet", "ramp_flipper": "wet", "boom_tender": "wet", "jolt_layer": "", "lobber": ""})


func _windups() -> void:
	var sounds := {}
	for kind in SPILLWAY:
		var id := String(WindupRows.ROWS[kind]["sound"])
		var playable := id != "none" and (SfxBank.samples(id).size() > 0 or SfxBank.rendered(id) != null)
		sounds[kind] = [id, playable]
	_t.eq("each wind-up names a playable sound", sounds,
		{"jolt_layer": ["jolt_layer_tell", true], "hooker": ["warn_tether", true], "ramp_flipper": ["warn_flap", true],
			"boom_tender": ["warn_reel", true]})


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if not _started:
		_setup()
		return false
	_clock += delta
	# The flap checks wait for the ball to settle on the park floor.
	if _hooker == null:
		if _game.player.state.on_floor() or _clock > LIMIT:
			_flaps()
			_wet_mat()
			_boom()
			_ball_at = _game.player.ball_position()
			_hooker = _spawn("hooker")
			_clock = 0.0
		return false
	if _fleet.holds.held(_hooker):
		return _hook_out()
	if _clock > LIMIT:
		_t.check("the hooker held the ball", false, "never held in %.0f s" % LIMIT)
		return _finish()
	return false


func _setup() -> void:
	_started = true
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_fleet = ctx.spawner.fleet
	_combat = ctx.spawner
	_ball_at = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_game.player.reset_to(_ball_at)


func _spawn(kind: String, offset := OFFSET) -> Node3D:
	var ctx = _game.ctx
	var at: Vector3 = _ball_at + offset
	var unit: Node3D = ctx.spawner.spawn_enemy(kind, ctx.terrain.drop_point(at.x, at.z, 1.8))
	unit._rest = 0.3
	return unit


# The flap's go-live, called directly with the ball parked grounded in its committed ring, so the
# test sets the tier the plate reads on that one tick.
func _flap_live(tier: int) -> Node3D:
	var player = _game.player
	var unit := _spawn("ramp_flipper")
	_fleet.holds.clear()
	# The unit's sight has not had a frame to find the ball; aim it at the ball itself.
	unit.target = player
	unit._warn((player.ball_position() - unit.global_position))
	player.state.tier = tier
	unit.phase = unit.Phase.LIVE
	unit._t = 0.0
	unit._go_live()
	return unit


func _flaps() -> void:
	var fast := _flap_live(SpeedTier.FAST)
	_t.eq("a FAST ball rides the flap and is never held", [fast.rides, fast.flings, fast.broken_by, _fleet.holds.held(fast)],
		[1, 0, "speed", false])
	_t.check("riding the flap discovers its codex entry", _combat.discovered.has("flap_ride"), str(_combat.discovered.keys()))
	fast.queue_free()
	var slow := _flap_live(SpeedTier.CRUISE)
	_t.eq("a cruising ball is flung", [slow.rides, slow.flings, _fleet.holds.held(slow)], [0, 1, true])
	_fleet.holds.clear()
	slow.queue_free()


func _wet_mat() -> void:
	var dry := _spawn("jolt_layer")
	dry._commit(Vector3.ZERO)
	var dry_radius: float = dry.field.radius()
	dry.queue_free()
	var wet := _spawn("jolt_layer")
	wet.terrain = WetGround.new(wet.terrain)
	wet._commit(Vector3.ZERO)
	var wet_radius: float = wet.field.radius()
	wet.queue_free()
	_t.eq("a mat laid on water spreads half as wide again", [dry_radius, wet_radius], [6.0, 6.0 * wet.WET_SPREAD])


# The boom tender's live tick, called directly with its lane committed on the grounded ball.
func _boom_live(tier: int) -> Node3D:
	var player = _game.player
	var unit := _spawn("boom_tender", NEAR)
	_fleet.holds.clear()
	unit.target = player
	unit._warn((player.ball_position() - unit.global_position))
	player.state.tier = tier
	unit.phase = unit.Phase.LIVE
	unit._t = 0.0
	unit._live(1.0 / 60.0)
	return unit


func _boom() -> void:
	var slow := _boom_live(SpeedTier.CRUISE)
	_t.eq("a cruising ball in the lane is pinned", [slow.pinned, slow.pops, _fleet.holds.held(slow)], [1, 0, true])
	_fleet.holds.clear()
	slow.queue_free()
	var fast := _boom_live(SpeedTier.FAST)
	_t.check("a FAST ball bursts the floats it touches and is never pinned",
		fast.pops >= 1 and fast.pinned == 0 and not _fleet.holds.held(fast), "pops %d pinned %d" % [fast.pops, fast.pinned])
	_t.check("bursting a float discovers its codex entry", _combat.discovered.has("boom_pop"), str(_combat.discovered.keys()))
	fast.queue_free()
	var bowl := _boom_live(SpeedTier.FAST)
	bowl.popped = [false, false, false, false, false]
	bowl._pops_live = 0
	var pieces_before: int = _game.build.scrap.count()
	for i in bowl.FLOAT_OUT.size():
		bowl._bowl_through(bowl.float_position(i))
	_t.eq("five floats in one pass is a strike", [bowl.popped, bowl.strikes], [[true, true, true, true, true], 1])
	_t.check("the strike discovers its codex entry", _combat.discovered.has("boom_strike"), str(_combat.discovered.keys()))
	var first_payout: int = _game.build.scrap.count() - pieces_before
	_t.eq("the five float pops each pay one piece", first_payout, 5)
	for i in bowl.FLOAT_OUT.size():
		bowl._bowl_through(bowl.float_position(i))
	_t.eq("the same spent line pays nothing on a return crossing",
		[_game.build.scrap.count() - pieces_before, bowl.strikes], [5, 1])
	bowl.queue_free()


func _hook_out() -> bool:
	var player = _game.player
	player.kit.anchor_body = null
	var snaps_before: int = _hooker.snaps
	_game.events.grapple_fired.emit(player.ball_position() + Vector3(0.0, 4.0, 6.0))
	var last: Dictionary = _fleet.holds.last_release
	_t.eq("a bite on a post snaps the tether by the hook", [_fleet.holds.held(_hooker), String(last.get("reason", "")),
		_hooker.snaps - snaps_before, _hooker.broken_by], [false, "hook", 1, "hook"])
	_t.check("hooking out discovers its codex entry", _combat.discovered.has("hook_out"), str(_combat.discovered.keys()))
	return _finish()


func _finish() -> bool:
	_done = true
	_game.free()
	quit(_t.verdict())
	return true
