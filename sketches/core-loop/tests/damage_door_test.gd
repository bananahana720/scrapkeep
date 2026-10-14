extends SceneTree

# SR1 one damage door (comps/W13-INTEGRATION-3.md, unit SR1; comps/ror2/architecture.md
# "Lab measure"). Every strike passes damage_door.gd's pass_hit(), which runs combat's
# stages in the door's declared ORDER and only then the door's hooks, at most HOOK_CAP per
# event. Proves, on the real strike() path with every hook slot filled:
# 1. 1,000 scripted hits (weapon and ram, deflected and full, 100 of them kills): the stage
#    order matches ORDER on all 1,000 and every hit runs exactly one door pass;
# 2. no hook runs before the health stage, read two ways: the trace index and the hit record
#    each hook is handed (it already carries the HP removed);
# 3. hooks per event per hit stay at or under HOOK_CAP, and a hook past the cap is refused;
# 4. the wear trail keeps its bypass: a patch hit removes HP through the door's one health
#    measure but makes no door pass, runs no hook and publishes no enemy_struck;
# 5. 100 kill-and-respawn cycles leave the run owner's parts, relics, tree picks and
#    companion unchanged.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const T := preload("res://tests/support/t.gd")

const DOOR_PATH := "res://src/combat/damage_door.gd"
const HITS := 1000
const KILL_EVERY := 10
const DEFLECT_EVERY := 7
const CYCLES := 100
const BIG := 1.0e9
const EXPECTED_CHECKS := 26

var _t := T.new("damage_door_test")
var _game
var _ticks := 0
var _spawned: Array = []
# Hook calls that found no health result on the hit record they were handed.
var _early_hooks := 0
var _hook_calls := {"hit": 0, "deflect": 0, "kill": 0}
var _struck_seen := 0
# Probe hooks this test seated per event (the production hooks fill the rest of "hit").
var _probes := {"hit": 0, "deflect": 0, "kill": 0}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_setup()
		return false
	if _ticks < 12:
		return false
	_run_checks()
	return true


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var anchor := Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z) + 1.05, spawn.z)
	_game.player.reset_to(anchor)
	_game.player.body().global_position = anchor
	var c := Companion.new()
	for id in ["primer_mesh", "ram_prow"]:
		c.acquire(id)
	c.assemble(["primer_mesh", "ram_prow"])
	ctx.run.companion = c.to_dict()
	ctx.events.enemy_struck.connect(func(_e, _k, _f): _struck_seen += 1)


func _run_checks() -> void:
	var combat = _game.ctx.spawner
	var door = combat.get("door")
	_t.check("combat owns a damage door", door != null and ResourceLoader.exists(DOOR_PATH), DOOR_PATH)
	if door == null:
		_t.eq("every check ran", _t.checks + 1, EXPECTED_CHECKS)
		quit(_t.verdict())
		return
	_check_declared(door)
	_check_cap(door)
	_check_order(combat, door)
	_check_bypass(combat, door)
	_check_respawn(combat, door)
	_clear()
	_t.eq("every check ran", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _check_declared(door) -> void:
	_t.eq("declared order", door.ORDER, ["armour", "caps", "crit", "announce", "plates", "health", "execute", "events"])
	_t.eq("declared events", door.EVENTS, ["hit", "deflect", "kill"])
	_t.check("hooks run only after health", door.ORDER.find("health") < door.ORDER.size() - 1,
		"health at %d of %d stages; hooks follow the last" % [door.ORDER.find("health"), door.ORDER.size()])


# Fills every event to its cap with recording hooks; the production hooks already seated
# on "hit" count against the same cap.
func _check_cap(door) -> void:
	var refused := 0
	for event in door.EVENTS:
		var n := 0
		while door.hooks(event).size() < door.HOOK_CAP and n < 32:
			if door.hook(event, "probe_%s_%d" % [event, n], _probe.bind(event)):
				_probes[event] = int(_probes[event]) + 1
			n += 1
		if not door.hook(event, "probe_%s_over" % event, _probe.bind(event)):
			refused += 1
	_t.eq("a hook past the cap is refused on each event", refused, door.EVENTS.size())
	_t.check("every event full to its cap", door.hooks("hit").size() == door.HOOK_CAP
			and door.hooks("deflect").size() == door.HOOK_CAP and door.hooks("kill").size() == door.HOOK_CAP,
		"hit %d, deflect %d, kill %d, cap %d" % [door.hooks("hit").size(), door.hooks("deflect").size(),
			door.hooks("kill").size(), door.HOOK_CAP])
	_t.check("an unknown event takes no hook", not door.hook("parry", "probe", _probe.bind("parry")), "parry")
	_t.check("production hooks seated on hit", door.hooks("hit").has("primer_mesh") and door.hooks("hit").has("companion_ram"),
		"hit hooks %s" % [door.hooks("hit")])


func _probe(hit: Dictionary, event: String) -> void:
	_hook_calls[event] = int(_hook_calls.get(event, 0)) + 1
	if not hit.has("removed"):
		_early_hooks += 1


func _check_order(combat, door) -> void:
	door.trace_on = true
	door.traces.clear()
	_early_hooks = 0
	for key in _hook_calls:
		_hook_calls[key] = 0
	var tank := _spawn("chaser", Vector3(3.0, 0.0, 0.0), true)
	_spawn("chaser", Vector3(-3.0, 0.0, 0.0), true)
	var victim: Node3D = null
	var kills := 0
	var deflects := 0
	for i in HITS:
		if i % KILL_EVERY == KILL_EVERY - 1:
			victim = _spawn("chaser", Vector3(0.0, 0.0, 3.0), false)
			combat.strike(victim, "arc", victim.max_hp * 10.0, "", "weapon")
			kills += 1 if victim.is_dead() else 0
			continue
		var deflect := i % DEFLECT_EVERY == 0
		tank.plating = BIG if deflect else 0.0
		deflects += 1 if deflect else 0
		if i % 2 == 0:
			combat.strike(tank, "arc", 5.0, "", "weapon")
		else:
			combat.strike(tank, "ram", 20.0)
	tank.plating = 0.0
	door.trace_on = false
	var traces: Array = door.traces.duplicate()
	var ordered := 0
	var early := 0
	var over_cap := 0
	for trace in traces:
		var stages: Array = trace.slice(0, door.ORDER.size())
		var rest: Array = trace.slice(door.ORDER.size())
		if stages == door.ORDER and rest.all(func(s): return String(s).begins_with("hook:")):
			ordered += 1
		# A stage's name is traced as it starts, so health has finished only once the stage
		# after it has started.
		var health_done: int = trace.find(door.ORDER[door.ORDER.find("health") + 1])
		for j in trace.size():
			if String(trace[j]).begins_with("hook:") and (health_done < 0 or j < health_done):
				early += 1
		var per := {}
		for s in trace:
			if not String(s).begins_with("hook:"):
				continue
			var event := String(s).split(":")[1]
			per[event] = int(per.get(event, 0)) + 1
		for event in per:
			if int(per[event]) > door.HOOK_CAP:
				over_cap += 1
	_t.eq("one door pass per scripted hit", traces.size(), HITS)
	_t.eq("stage order matches ORDER on every hit", ordered, HITS)
	_t.eq("no hook before health (trace)", early, 0)
	_t.eq("no hook before health (hit record)", _early_hooks, 0)
	_t.eq("hooks per event within cap on every hit", over_cap, 0)
	_t.eq("kills through the door", kills, HITS / KILL_EVERY)
	_t.eq("kill hooks ran once per kill per probe", int(_hook_calls["kill"]), kills * int(_probes["kill"]))
	_t.eq("deflect hooks ran once per deflected hit per probe", int(_hook_calls["deflect"]), deflects * int(_probes["deflect"]))
	_t.eq("hit hooks ran on every hit per probe", int(_hook_calls["hit"]), HITS * int(_probes["hit"]))


func _check_bypass(combat, door) -> void:
	var foe := _spawn("chaser", Vector3(0.0, 0.0, -3.0), true)
	door.trace_on = true
	door.traces.clear()
	var struck_before := _struck_seen
	var calls_before := int(_hook_calls["hit"])
	var hp_before: float = foe.hp
	var deal: Callable = combat.wear_trail.deal
	var removed: float = deal.call(foe, combat.wear_trail.DAMAGE) if deal.is_valid() else 0.0
	door.trace_on = false
	_t.near("a patch hit removes its damage", hp_before - float(foe.hp), combat.wear_trail.DAMAGE)
	_t.near("the patch reports the HP it removed", removed, combat.wear_trail.DAMAGE)
	_t.check("the wear trail bypasses the door", door.traces.is_empty() and int(_hook_calls["hit"]) == calls_before
			and _struck_seen == struck_before,
		"door passes %d, hit hooks %d, enemy_struck %d" % [door.traces.size(), int(_hook_calls["hit"]) - calls_before,
			_struck_seen - struck_before])


func _owner_state() -> Dictionary:
	var run = _game.ctx.run
	return {"parts": Array(run.parts).duplicate(), "relics": run.relics.duplicate(true),
		"tree_picks": Array(run.tree_picks).duplicate(), "companion": run.companion.duplicate(true)}


func _check_respawn(combat, door) -> void:
	# A held part makes "unchanged" mean something; an empty inventory stays empty trivially.
	_game.run.add_part("boost_coil", "test")
	var before := _owner_state()
	var anchor: Vector3 = _game.player.ball_position()
	var kills_before := int(_hook_calls["kill"])
	var dead := 0
	for i in CYCLES:
		var foe := _spawn("chaser", Vector3(2.0, 0.0, 2.0), false)
		combat.strike(foe, "arc", foe.max_hp * 10.0, "", "weapon")
		dead += 1 if foe.is_dead() else 0
		_game.player.reset_to(anchor)
	var after := _owner_state()
	_t.eq("kill-and-respawn cycles killed every foe", dead, CYCLES)
	_t.eq("kill hooks ran on every cycle", int(_hook_calls["kill"]) - kills_before, CYCLES * int(_probes["kill"]))
	_t.check("owner inventory unchanged", not (before["parts"] as Array).is_empty() and after["parts"] == before["parts"] and after["relics"] == before["relics"]
			and after["tree_picks"] == before["tree_picks"],
		"parts %s -> %s, relics %s -> %s" % [before["parts"], after["parts"], before["relics"], after["relics"]])
	_t.eq("companion unchanged", after["companion"], before["companion"])
	_t.check("the companion stayed seated", Companion.seated(after["companion"], Companion.CONDUCTIVE_PRIMER) == "primer_mesh",
		"%s" % [after["companion"]])


func _spawn(kind: String, offset: Vector3, tank: bool) -> Node3D:
	var spot: Vector3 = _game.player.ball_position() + offset
	var e: Node3D = _game.ctx.spawner.spawn_enemy(kind, _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	_spawned.append(e)
	if tank:
		e.hp = BIG
		e.max_hp = BIG
	return e


func _clear() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.remove_from_group("enemy")
			e.queue_free()
	_spawned.clear()
