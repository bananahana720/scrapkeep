extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")

# The three family Wardens (DESIGN-V2 section 11) on the shared clamp, one per stage,
# each broken under the plating grammar:
# - stage 1 is a reactor relic, stage 2 a swarm hive, stage 3 one of the Mind's hands;
# - a punch below the plating chips 20%, a punch at the plating lands in full anywhere;
# - the family's own mechanic opens its weak point at plating 0: the reactor's core
#   after a pulse (vent_charging, vent_erupted), the hive's queen when its guard rack
#   scatters, the Mind's lens once it has quoted you and braced (a ram then meets 1.4
#   times its plating);
# - broken, it opens the beacon (the Warden gate).

const REACH_OFFSET := Vector3(12.0, 0.0, 3.0)

# Preserve the legacy three-stage rule on a double using surviving maps.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _combat
var _failures := 0
var _stage := 0
var _step := 0
var _clock := 0.0
var _warden: Node3D
var _facts := {}


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	match _step:
		0:
			_setup()
			_enter(1)
		1:
			if _warden.family_open():
				_opened()
			elif _clock > 12.0:
				_report("stage %d opens" % _stage, false, "the %s kit never opened in 12 s" % _warden.family)
				return _finish()
			elif _stage == 2 and _warden.guard != null and _warden.guard.alive().size() == 10 and _warden.guard.scatters == 0:
				_warden.guard.scatter(_game.player.ball_position())
		2:
			if _clock >= 0.2:
				_report("stage %d gate" % _stage, _facts.has("beacon_unsealed"),
					"the broken %s Warden unsealed the beacon: %s" % [_warden_family(), _facts.keys()])
				if _stage == 3:
					return _finish()
				_enter(_stage + 1)
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.force_warden = true
	_combat = ctx.spawner
	for name in ["vent_charging", "vent_erupted", "weak_point_opened", "mind_adapted", "beacon_unsealed", "swarm_scattered"]:
		_game.events.connect(name, _on_fact.bind(name).unbind(_argc(name)))
	_game.flow.press_start()


func _on_fact(name: String) -> void:
	_facts[name] = int(_facts.get(name, 0)) + 1


func _argc(name: String) -> int:
	for info in _game.events.get_signal_list():
		if info["name"] == name:
			return (info["args"] as Array).size()
	return 0


func _enter(stage: int) -> void:
	_stage = stage
	_facts.clear()
	if stage == 1:
		_game.flow.choose_class(0)
	else:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_game.run.set_max_hp(99999.0)
	_warden = _game.flow.warden
	var ctx = _game.ctx
	var at: Vector3 = _warden.global_position + REACH_OFFSET
	_game.player.reset_to(ctx.terrain.drop_point(at.x, at.z, 1.05))
	_report("stage %d family" % stage, _warden.family == Roster.warden_family(stage),
		"stage %d Warden is the %s family (lesson %s kept)" % [stage, _warden.family, _warden.lesson])
	var plating: float = _combat.plating_of(_warden)
	var chip: Dictionary = _combat.resolve(_warden, "runner", plating * 0.5)
	var full: Dictionary = _combat.resolve(_warden, "runner", plating)
	_report("stage %d plating grammar" % stage, not chip["full"] and absf(chip["dealt"] - plating * 0.5 * 0.2) < 0.01 and full["full"],
		"plating %.0f: half of it chips %.1f, all of it lands %.0f anywhere" % [plating, chip["dealt"], full["dealt"]])
	match stage:
		1:
			_warden._pulse_clock = Warden.PULSE_CYCLE - Warden.PULSE_TELEGRAPH - 0.02
		3:
			for i in 6:
				_game.events.enemy_struck.emit(null, "ram", 20.0)
			_warden._adapt_clock = Warden.ADAPT_CYCLE - 0.05
	_step = 1
	_clock = 0.0


func _opened() -> void:
	var point: String = _warden.family_point()
	var plating: float = _combat.plating_of(_warden)
	var through: Dictionary = _combat.resolve(_warden, "runner", plating * 0.3, point)
	var listed := false
	for p in _warden.weak_points():
		listed = listed or p["id"] == point
	var family_facts := true
	var extra := ""
	match _stage:
		1:
			family_facts = _facts.has("vent_charging") and _facts.has("vent_erupted")
			extra = "vents %d/%d" % [_facts.get("vent_charging", 0), _facts.get("vent_erupted", 0)]
		2:
			family_facts = _facts.has("swarm_scattered")
			extra = "guard scattered %d" % _facts.get("swarm_scattered", 0)
		3:
			family_facts = _facts.has("mind_adapted") and absf(_warden.plating_for("ram", "") - _warden.plating_now() * Warden.BRACE_MULT) < 0.01
			extra = "quoted %d, braced ram plating %.0f" % [_facts.get("mind_adapted", 0), _warden.plating_for("ram", "")]
	_report("stage %d weak point" % _stage, through["full"] and through["plating"] == 0.0 and listed and family_facts
			and _facts.has("weak_point_opened"),
		"the %s opened: a punch of %.0f meets plating %.0f there; %s" % [point, plating * 0.3, through["plating"], extra])
	var hits := 0
	while not _warden.is_dead() and hits < 200:
		_combat.strike(_warden, "runner", _combat.plating_of(_warden) + 400.0)
		hits += 1
	_report("stage %d breaks" % _stage, _warden.is_dead(), "broken in %d full hits" % hits)
	_step = 2
	_clock = 0.0


func _warden_family() -> String:
	return Roster.warden_family(_stage)


func _finish() -> bool:
	var ok := _failures == 0
	print("warden_family_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)
	return true
