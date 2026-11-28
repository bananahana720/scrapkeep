extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
# How far over the stage the blocked throw is made from: past the landing ray's 60 m reach down.
const VOID_HEIGHT := 200.0

# The class specials and Kest's kit through the real game (calm, stage 1): the gauge's
# release scaling, the drawn geometry being exactly the committed one with the
# forgiveness in the hit test, a knock mid-charge leaving nothing spent or fired,
# Rivet's sprint ignoring the knock while the damage lands, pins once per knock, the
# rocket jump's bounded chain, stickies (three live, fuse), the detonation line's caught
# charges and cap, and the cloak's sight and crit. The class is swapped in place (run
# row plus fit_class) so one boot covers all three.

var _game
var _combat
var _player
var _source := Intent.Scripted.new()
var _failures := 0
var _steps := []
var _index := 0
var _ticks := 0
var _booted := false
var _record := {}
var _facts := {}
var _struck: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_boot()
		return false
	if _index >= _steps.size():
		print("char_combat_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	elif step.size() > 3:
		(step[3] as Callable).call()
	_ticks += 1
	if _ticks >= int(step[1]):
		(step[2] as Callable).call()
		_index += 1
		_ticks = 0
	return false


func _boot() -> void:
	_booted = true
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_player = _game.player
	for kind in ["gauge_released", "gauge_cancelled", "special_used", "cc_ignored", "enemy_pinned", "rocket_jumped",
			"sticky_detonated", "cloak_started", "cloak_broken"]:
		var list: Array = []
		_facts[kind] = list
		_game.events.connect(kind, func(a = null, b = null): list.append([a, b]))
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _struck.append([enemy, kind, force]))
	_steps = [
		[_scale_begin.bind(0.0), 1, _scale_release],
		[_noop, 3, _scale_record],
		[_scale_begin.bind(0.3), 27, _scale_release],
		[_noop, 3, _scale_record],
		[_scale_begin.bind(0.6), 54, _scale_release],
		[_noop, 3, _scale_record],
		[_scale_begin.bind(1.0), 90, _scale_release],
		[_noop, 3, _check_scaling],
		[_edge_start, 2, _check_edge],
		[_cc_start, 27, _cc_hit],
		[_noop, 20, _check_cc],
		[_pull_start, 10, _check_pull],
		[_sprint_start, 10, _sprint_hit],
		[_noop, 3, _sprint_release],
		[_noop, 190, _sprint_plain_hit],
		[_noop, 3, _check_sprint],
		[_pin_start, 40, _check_pin],
		[_rocket_start, 270, _rocket_floor, _blast_at_feet],
		[_noop, 180, _check_rocket, _blast_at_feet],
		[_sticky_start, 6, _check_sticky_live, _tap_fire],
		[_noop, 130, _check_sticky_fuse],
		[_void_start, 2, _check_void],
		[_line_start, 2, _check_line],
		[_line_cap_start, 2, _check_line_cap],
		[_cloak_start, 3, _cloak_blink],
		[_noop, 3, _check_cloak],
		[_noop, 3, _check_crit],
	]


func _noop() -> void:
	pass


func _as_class(id: String) -> void:
	var def: Resource = ClassDef.by_id(id)
	_game.run.class_def = def
	_player.fit_class(def)
	_clear_enemies()
	_combat.sticky.clear()
	_combat.cloak_left = 0.0
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0


func _clear_enemies() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()


func _spawn(kind: String, flat: Vector3) -> Node3D:
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	return _combat.spawn_enemy(kind, Vector3(flat.x, ground + 1.5, flat.z))


func _ball_flat() -> Vector3:
	var b: Vector3 = _player.ball_position()
	return Vector3(b.x, 0.0, b.z)


# --- gauge scaling ---------------------------------------------------------------------

func _scale_begin(seconds: float) -> void:
	if not _record.has("bursts"):
		_as_class("pylon_engineer")
		_record = {"bursts": []}
	_player.abilities.refill()
	_source.press = {"special_pressed": true}
	_source.hold = {"special_held": true} if seconds > 0.0 else {}


func _scale_release() -> void:
	_source.hold = {}


func _scale_record() -> void:
	_record["bursts"].append([_combat.last_committed.get("fraction", -1.0), _combat.last_burst.get("radius", -1.0),
		_combat.last_burst.get("damage", -1.0)])
	_record["drawn_same"] = _player.indicator.last_shape.get("special", {}) == _combat.last_committed.get("geometry", {1: 1})


func _check_scaling() -> void:
	_scale_record()
	var rows: Array = _record["bursts"]
	var rising := rows.size() == 4
	for i in range(1, rows.size()):
		rising = rising and rows[i][0] > rows[i - 1][0] and rows[i][1] >= rows[i - 1][1] and rows[i][2] > rows[i - 1][2]
	var tap_floor: bool = is_equal_approx(rows[0][0], 0.0) and is_equal_approx(rows[0][1], Weapons.BURST_RADIUS)
	_report("gauge scales", rising and tap_floor and _record["drawn_same"],
		"Sable's F tapped then held 0.3 / 0.6 / 1.0 s: [fraction, radius, damage] %s; a tap is the floor (%.0f m); the drawn ring equals the committed one"
			% [rows.map(func(r): return [snappedf(r[0], 0.01), snappedf(r[1], 0.1), snappedf(r[2], 0.1)]), Weapons.BURST_RADIUS])


# --- drawn equals committed; forgiveness in the hit test ---------------------------------

func _edge_start() -> void:
	_as_class("runner_gunner")
	var centre := _ball_flat()
	var radius := Weapons.OVERDRIVE_RADIUS
	_record = {"inside": _spawn("chaser", centre + Vector3(radius * 1.1 + 1.0, 0.0, 0.0)),
		"outside": _spawn("chaser", centre + Vector3(-(radius * 1.35 + 1.0), 0.0, 0.0))}
	_struck.clear()
	_source.press = {"special_pressed": true}


func _check_edge() -> void:
	var drawn: Dictionary = _player.indicator.last_shape.get("special", {})
	var committed: Dictionary = _combat.last_committed.get("geometry", {})
	var hit_in := _struck.any(func(s): return s[0] == _record["inside"] and s[1] == "runner")
	var hit_out := _struck.any(func(s): return s[0] == _record["outside"] and s[1] == "runner")
	_report("drawn is committed", not drawn.is_empty() and drawn == committed and is_equal_approx(float(drawn["radius"]), Weapons.OVERDRIVE_RADIUS),
		"Rivet's tapped blast drew a %.1f m ring and committed the same record" % float(drawn.get("radius", -1.0)))
	_report("edge forgiven", hit_in and not hit_out,
		"a chaser whose hull sits 10%% past the drawn edge is hit (%s); one 35%% past is not (%s)" % [hit_in, hit_out])


# --- a knock mid-charge -------------------------------------------------------------------

func _cc_start() -> void:
	_as_class("demolitions_caster")
	_record = {"released": _facts["gauge_released"].size(), "used": _facts["special_used"].size(),
		"cancelled": _facts["gauge_cancelled"].size()}
	_combat.last_committed = {}
	_source.press = {"special_pressed": true}
	_source.hold = {"special_held": true}


func _cc_hit() -> void:
	var gauge = _player.abilities.gauge(AbilityState.SPECIAL)
	_record["was"] = gauge.fraction()
	_game.ctx.calm = false
	_record["drawn"] = _player.indicator.shapes.has("special")
	_combat._on_player_hit(4.0, Vector3(3.0, 0.0, 0.0), "test")
	_game.ctx.calm = true
	_record["after"] = gauge.fraction()
	_record["collapsing"] = _player.indicator.collapsing("special")


func _check_cc() -> void:
	_source.hold = {}
	var gauge = _player.abilities.gauge(AbilityState.SPECIAL)
	var cancelled: Array = _facts["gauge_cancelled"].slice(_record["cancelled"])
	_report("knock collapses", _record["drawn"] and _record["collapsing"] and not _player.indicator.collapsing("special"),
		"the drawn line starts collapsing on the knock and is gone %d ms later (collapse %d ms)" % [int(20.0 / 0.09), 120])
	_report("knock cancels", _record["was"] > 0.2 and _record["after"] == 0.0 and not gauge.charging \
			and _player.abilities.ready(AbilityState.SPECIAL) and _combat.last_committed.is_empty() \
			and _facts["gauge_released"].size() == _record["released"] and _facts["special_used"].size() == _record["used"] \
			and cancelled.size() == 1 and cancelled[0] == ["detonation_line", "knock"] and not _player.indicator.shapes.has("special"),
		"Kest's line at %.2f of its gauge, then a knock: gauge %.2f, charge still in, nothing released or used, cancelled %s, still F held stays idle"
			% [_record["was"], _record["after"], cancelled])


# --- a steady pull is crowd control, but it does not wipe a charge -------------------

func _pull_start() -> void:
	_as_class("pylon_engineer")
	_source.press = {"special_pressed": true}
	_source.hold = {"special_held": true}


func _check_pull() -> void:
	var landed: bool = _player.crowd_control("warden_magnet", Vector3(20.0, 0.0, 0.0), false)
	var charging: bool = _player.abilities.gauge(AbilityState.SPECIAL).charging
	var knocked: bool = _player.crowd_control("warden_pulse", Vector3.UP * 30.0)
	var dropped: bool = not _player.abilities.gauge(AbilityState.SPECIAL).charging
	_source.hold = {}
	_report("pull keeps the charge", landed and charging and knocked and dropped,
		"the Warden magnet's tug lands and Sable's gauge keeps charging; the Warden pulse's lift drops it")


# --- Rivet's sprint: the knock slides off, the damage lands --------------------------

func _sprint_start() -> void:
	_as_class("runner_gunner")
	_record = {"ignored": _facts["cc_ignored"].size()}
	_source.hold = {"movement_held": true}
	_source.press = {"movement_pressed": true}


func _sprint_hit() -> void:
	_record["hp"] = _game.run.hp
	_record["v"] = _player.state.velocity
	_game.ctx.calm = false
	_combat._on_player_hit(10.0, Vector3(40.0, 0.0, 0.0), "test")
	_game.ctx.calm = true
	_record["sprint_dmg"] = _record["hp"] - _game.run.hp
	_record["sprinting"] = _player.kit.sprinting
	_record["pulse_ignored"] = not _player.crowd_control("warden_pulse", Vector3.UP * 30.0) \
		and not _player.crowd_control("brindle_charge", Vector3(30.0, 0.0, 0.0))


func _sprint_release() -> void:
	_record["sprint_drift"] = absf(_player.state.velocity.x - (_record["v"] as Vector3).x)
	_source.hold = {}


func _sprint_plain_hit() -> void:
	_record["hp2"] = _game.run.hp
	_record["v2"] = _player.state.velocity
	_game.ctx.calm = false
	_combat._on_player_hit(10.0, Vector3(40.0, 0.0, 0.0), "test")
	_game.ctx.calm = true
	_record["plain_dmg"] = _record["hp2"] - _game.run.hp


func _check_sprint() -> void:
	var plain_drift := absf(_player.state.velocity.x - (_record["v2"] as Vector3).x)
	_report("sprint is no tank", _record["sprinting"] and _record["sprint_dmg"] > 0.0 and is_equal_approx(_record["sprint_dmg"], _record["plain_dmg"]) \
			and _record["sprint_drift"] < 0.5 and plain_drift > 5.0 and _record["pulse_ignored"] \
			and _facts["cc_ignored"].size() == _record["ignored"] + 3,
		"a 10-damage hit with a 40 m/s shove: sprinting took %.1f damage and drifted %.2f m/s (the Warden pulse and Brindle's charge shove ignored too); after the sprint the same hit took %.1f and drifted %.1f m/s"
			% [_record["sprint_dmg"], _record["sprint_drift"], _record["plain_dmg"], plain_drift])


# --- pins -----------------------------------------------------------------------------

func _pin_start() -> void:
	_as_class("runner_gunner")
	var base := _ball_flat() + Vector3(0.0, 0.0, 30.0)
	var carrier := _spawn("chaser", base)
	var victim := _spawn("chaser", base + Vector3(2.4, 0.0, 0.0))
	_record = {"carrier": carrier, "victim": victim, "pins": _facts["enemy_pinned"].size()}
	_struck.clear()
	carrier.knock(Vector3(1.0, 0.0, 0.0), 12.0 * carrier.weight)


func _check_pin() -> void:
	var pins: Array = _facts["enemy_pinned"].slice(_record["pins"])
	var on_victim := pins.filter(func(p): return p[0] == _record["victim"])
	var strikes := _struck.filter(func(s): return s[0] == _record["victim"] and s[1] == "pin")
	var damage: float = strikes[0][2] if strikes.size() == 1 else -1.0
	_report("pin once per knock", on_victim.size() == 1 and strikes.size() == 1 \
			and damage >= Weapons.PIN_BASE + Weapons.PIN_PER_SPEED * Weapons.PIN_MIN_SPEED and damage <= Weapons.PIN_BASE + Weapons.PIN_PER_SPEED * 12.0,
		"a chaser knocked at 12 m/s into another 0.4 m away: %d pin on the victim over 40 ticks, %d pin strike of %.1f (8 + 0.5 x speed)"
			% [on_victim.size(), strikes.size(), damage])


# --- the rocket jump's chain is bounded ---------------------------------------------------

func _rocket_start() -> void:
	_as_class("demolitions_caster")
	_record = {"jumps": _facts["rocket_jumped"].size()}
	_source.hold = {"jump_held": true}


func _blast_at_feet() -> void:
	_combat.detonate({"pos": _player.ball_position() + Vector3.DOWN * 0.5, "radius": 3.0, "damage": 0.0, "crit": false})


func _rocket_floor() -> void:
	_record["plain"] = _facts["rocket_jumped"].size() - _record["jumps"]
	_record["jumps"] = _facts["rocket_jumped"].size()
	_combat.rocket_cooldown_scale = 0.0
	_player.abilities.set_cooldown_scale(AbilityState.WEAPON, 0.0)


func _check_rocket() -> void:
	var floored: int = _facts["rocket_jumped"].size() - _record["jumps"]
	_combat.rocket_cooldown_scale = 1.0
	_player.abilities.set_cooldown_scale(AbilityState.WEAPON, 1.0)
	_source.hold = {}
	_report("rocket chain bounded", _record["plain"] >= 2 and _record["plain"] <= 4 and floored >= 3 and floored <= 6,
		"a blast at Kest's feet every tick with Space held: %d rocket jumps in 3 s (1.0 s cooldown); with the cooldown scaled to 0, %d in 2 s (0.4 s floor)"
			% [_record["plain"], floored])


# --- stickies -----------------------------------------------------------------------------

func _sticky_start() -> void:
	_as_class("demolitions_caster")
	_player.abilities.set_max_charges(AbilityState.WEAPON, 5)
	_player.abilities.tick(10.0)
	_record = {"booms": _facts["sticky_detonated"].size(), "max_live": 0}
	_source.press = {"fire_pressed": true}


func _check_sticky_live() -> void:
	_record["max_live"] = _combat.sticky.live().size()
	_record["early"] = _facts["sticky_detonated"].size() - _record["booms"]


func _check_sticky_fuse() -> void:
	_player.abilities.set_max_charges(AbilityState.WEAPON, 1)
	_report("three live, fuse", _record["max_live"] <= Weapons.STICKY_MAX_LIVE and _record["early"] >= 1 and _combat.sticky.live().is_empty(),
		"tapping LMB on consecutive ticks with charges to spare: %d live at most, %d set off early to make room; all gone %.1f s later"
			% [_record["max_live"], _record["early"], Weapons.STICKY_FUSE])


func _tap_fire() -> void:
	_source.press = {"fire_pressed": true}


# A throw with no ground under it has nowhere to stick: it draws blocked and throws nothing.
# The ball is high over the stage, out of the landing ray's reach of the floor. Off the map
# would not do: the fall rescue puts the ball back on the tick it is placed there.
func _void_start() -> void:
	_as_class("demolitions_caster")
	_player.reset_to(_game.ctx.terrain.spawn_point(1) + Vector3.UP * VOID_HEIGHT)
	_record = {"cancelled": _facts["gauge_cancelled"].size(), "volleys": _combat.volleys}
	_source.press = {"fire_pressed": true}


func _check_void() -> void:
	var cancelled: Array = _facts["gauge_cancelled"].slice(_record["cancelled"])
	var drawn: Dictionary = _player.indicator.last_shape.get("landing", {})
	_report("blocked throw", drawn.get("blocked", false) and cancelled.size() == 1 and cancelled[0] == [Weapons.STICKY_CHARGE, "blocked"] \
			and _combat.volleys == _record["volleys"] and _player.abilities.ready(AbilityState.WEAPON),
		"a tapped throw with no ground under it drew blocked (%s), threw nothing, kept its charge and said %s"
			% [drawn.get("blocked", false), cancelled])


# --- the detonation line -----------------------------------------------------------------

func _line_start() -> void:
	_as_class("demolitions_caster")
	var aim: Vector3 = _combat.aim_heading()
	var ground: Vector3 = _player.ball_position() + Vector3.DOWN * 0.9
	for d in [2.5, 4.5]:
		_combat.sticky.drop(ground + aim * d, 0.0, 1.0, 10.0, 10.0)
	_record = {"enemy": _spawn("chaser", _ball_flat() + aim * 5.0)}
	_struck.clear()
	_source.press = {"special_pressed": true}


func _check_line() -> void:
	var line_hits := _struck.filter(func(s): return s[0] == _record["enemy"] and s[1] == "line")
	var want := Weapons.LINE_DAMAGE_MIN * (1.0 + Weapons.LINE_PER_CHARGE * 2.0)
	_report("line catches charges", _combat.last_burst.get("caught", -1) == 2 and line_hits.size() == 1 and is_equal_approx(line_hits[0][2], want),
		"a tapped 6 m line over two stickies: caught %d, the chaser in it took %.1f (want %.1f, +25%% each)"
			% [_combat.last_burst.get("caught", -1), line_hits[0][2] if not line_hits.is_empty() else -1.0, want])


func _line_cap_start() -> void:
	_as_class("demolitions_caster")
	var aim: Vector3 = _combat.aim_heading()
	var ground: Vector3 = _player.ball_position() + Vector3.DOWN * 0.9
	for d in [1.5, 2.5, 3.5, 4.5, 5.5]:
		_combat.sticky.drop(ground + aim * d, 0.0, 1.0, 10.0, 10.0)
	_record = {"enemy": _spawn("chaser", _ball_flat() + aim * 4.0)}
	_struck.clear()
	_source.press = {"special_pressed": true}


func _check_line_cap() -> void:
	var line_hits := _struck.filter(func(s): return s[0] == _record["enemy"] and s[1] == "line")
	var want := Weapons.LINE_DAMAGE_MIN * (1.0 + Weapons.LINE_PER_CHARGE * Weapons.LINE_MAX_CAUGHT)
	_report("line bonus capped", _combat.last_burst.get("caught", -1) == 5 and line_hits.size() == 1 and is_equal_approx(line_hits[0][2], want),
		"five stickies in the line all go off, but the line counts %d: %.1f damage (want %.1f)"
			% [Weapons.LINE_MAX_CAUGHT, line_hits[0][2] if not line_hits.is_empty() else -1.0, want])


# --- the cloak ----------------------------------------------------------------------------

func _cloak_start() -> void:
	_as_class("demolitions_caster")
	var aim: Vector3 = _combat.aim_heading()
	_record = {"near": _spawn("chaser", _ball_flat() + aim * 18.0), "far": _spawn("chaser", _ball_flat() - aim * 34.0),
		"started": _facts["cloak_started"].size(), "broken": _facts["cloak_broken"].size()}
	_source.hold = {"fire_held": true}


# RMB while the throw is charging still blinks: only the special and the slingshot
# take RMB as a cancel.
func _cloak_blink() -> void:
	_record["aiming"] = _player.abilities.gauge(AbilityState.WEAPON).charging
	_source.press = {"movement_pressed": true}


func _check_cloak() -> void:
	var ball: Vector3 = _player.ball_position()
	var near_sees: bool = (_record["near"].target.ball_position() as Vector3).is_equal_approx(ball)
	var far_sees: bool = (_record["far"].target.ball_position() as Vector3).is_equal_approx(ball)
	_record["damage"] = _combat._patterns[Weapons.STICKY_CHARGE].damage
	_report("cloak sight", _record["aiming"] and _combat.cloak_left > 0.0 and _facts["cloak_started"].size() == _record["started"] + 1 \
			and near_sees and not far_sees,
		"a blink with the throw charging raised the cloak: a chaser 18 m off still sees the ball (%s), one past %.0f m sees the smoke (%s)"
			% [near_sees, 40.0 * Weapons.CLOAK_SIGHT, not far_sees])
	_source.hold = {}


func _check_crit() -> void:
	var live: Array = _combat.sticky.live()
	var charge: Dictionary = live[-1] if not live.is_empty() else {}
	var broken: Array = _facts["cloak_broken"].slice(_record["broken"])
	_report("first shot crits", charge.get("crit", false) and is_equal_approx(float(charge.get("damage", 0.0)), _record["damage"] * Weapons.CLOAK_CRIT) \
			and _combat.cloak_left == 0.0 and broken.size() == 1 and broken[0][0] == "shot",
		"the throw out of the cloak carries %.0f damage (x%.0f) and ends it %s" % [float(charge.get("damage", 0.0)), Weapons.CLOAK_CRIT, broken])
