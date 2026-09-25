extends SceneTree

# JL-26: the Jev Lab port on Cable Bench. It checks that stage.gd's seed_override keeps
# the hand-picked seeds by default and moves all three stage streams together; that the
# exported state passes protocol v1's validator; that a knocked foe that is still alive
# stays a threat and an attack target, and a dead one leaves (stage-threat-rule 2);
# that hit_kicker carries no speed gate; that take_cache needs
# an affordable cache; and that the route from the spawn climbs every switchback to the
# forge. Headless, no input.

const Stage := preload("res://src/stage.gd")
const Layout := preload("res://src/layout.gd")
const JevIO := preload("res://src/jev/jev_io.gd")
const JevState := preload("res://src/jev/jev_state.gd")
const JevAgent := preload("res://src/jev/jev_agent.gd")
const Scenarios := preload("res://src/jev/scenarios.gd")

var _stages := []
var _started := false
var _waited := 0
var _ok := true
var _scenario := Scenarios.make("bench-one")


func _initialize() -> void:
	for override in [-1, -1, 5, 5]:
		var stage = Stage.new()
		stage.test_mode = true
		stage.seed_override = override
		root.add_child(stage)
		_stages.append(stage)


func _check(label: String, passed: bool) -> void:
	print("[jev] %s -> %s" % [label, "PASS" if passed else "FAIL"])
	_ok = _ok and passed


func _scrap(stage) -> Array:
	return stage.scrap_field._items.map(func(item): return item.position)


func _process(_delta: float) -> bool:
	if not _started:
		for stage in _stages:
			if stage.player == null:
				return false
		_started = true
		_seeds()
		# A teleport lands on a later physics tick, so the placed balls are read below.
		Scenarios.place(_stages[2], _scenario, 1000)
		_stages[3].player.reset_to(Layout.drop_point(0.0, 60.0, 1.0))
		return false
	_waited += 1
	if _waited < 4:
		return false
	_state()
	_knocked()
	_route()
	print("jev_cable_test: %s" % ("PASS" if _ok else "FAIL"))
	for stage in _stages:
		stage.free()
	quit(0 if _ok else 1)
	return true


func _seeds() -> void:
	var a = _stages[0]
	var b = _stages[1]
	var c = _stages[2]
	var d = _stages[3]
	_check("seed_override -1 keeps the hand-picked seeds 90210, 4711, 1337",
		a._rng.seed == 90210 and a.scrap_field.rng.seed == 4711 and a.director.rng.seed == 1337)
	_check("two default stages scatter the same scrap", _scrap(a) == _scrap(b))
	_check("seed_override 5 moves all three streams",
		c._rng.seed != 90210 and c.scrap_field.rng.seed != 4711 and c.director.rng.seed != 1337)
	_check("two stages with seed_override 5 scatter the same scrap", _scrap(c) == _scrap(d))
	_check("seed_override 5 scatters different scrap from the default", _scrap(a) != _scrap(c))
	# N5: seed 0 maps each stream to its default seed, so trial seed 0 replays the
	# hand-picked stage. Batch trial seeds are batch seed x 1000 + i, so only a batch
	# run with --seed 0 meets it, at its trial 0.
	_check("seed_override 0 gives the default seeds", a._seed_for(90210) == 90210 and _seed_with(0, 4711) == 4711)


func _seed_with(override: int, default_seed: int) -> int:
	var stage = _stages[0]
	var kept: int = stage.seed_override
	stage.seed_override = override
	var out: int = stage._seed_for(default_seed)
	stage.seed_override = kept
	return out


func _state() -> void:
	var stage = _stages[2]
	var run := Scenarios.Run.new(_scenario)
	var view := JevState.new(stage, run)
	var state := {"protocol": JevIO.PROTOCOL, "seq": 0, "tick": 0, "held": null}
	state.merge(view.snapshot())
	var errors := JevIO.validate_state(state)
	_check("bench-one's first state passes validate_state (%d errors)" % errors.size(), errors.is_empty())
	var ids: Array = state["jev"]["options"].map(func(option): return option["id"])
	var kicker: Array = state["jev"]["options"].filter(func(option): return option["id"] == "hit_kicker")
	_check("bench-one offers hit_kicker from the top of road 0", kicker.size() == 1)
	_check("hit_kicker carries no requires_speed_ms", kicker.size() == 1 and not kicker[0].has("requires_speed_ms"))
	_check("the 30-scrap purse offers no mesa cache from the bench", not ids.has("take_cache"))
	# On the east ledge's top, with the purse, its cache is offered; with no scrap it is not.
	var on_top := JevState.new(stage, run)
	var at := Vector3(60.0, Layout.mesa_top(0) + 1.0, 84.0)
	_check("on the east ledge, the affordable ledge cache is offered", on_top.cache_offer(at) != null)
	stage.run.scrap = 0
	_check("with no scrap, no cache is offered", on_top.cache_offer(at) == null)


func _knocked() -> void:
	var stage = _stages[3]
	var foe = stage.director.spawn("chaser", Layout.drop_point(8.0, 60.0, 2.2))
	var view := JevState.new(stage)
	view.attach()
	var before: Array = view.threats()
	stage.player.shockwave.emit(foe.global_position, JevState.STOMP_STRENGTH)
	var after: Array = view.threats()
	var offers: Array = view.options(view.jev_block()["state"]).map(func(option): return option["id"])
	var chaser := func(t): return t["kind"] == "chaser"
	_check("a chaser 8 m away is a threat before the knock", before.any(chaser))
	_check("the knock is recorded against that chaser", view.knocked.has(String(foe.name)))
	_check("the knocked chaser, still alive, stays a threat", after.any(chaser))
	_check("and stays a stomp and ram target", offers.has("stomp_target") and offers.has("ram_target"))
	foe.take_damage(foe.hp + 1.0)
	var dead: Array = view.threats()
	var dead_offers: Array = view.options(view.jev_block()["state"]).map(func(option): return option["id"])
	_check("a dead chaser leaves the threats", not dead.any(chaser))
	_check("and the stomp and ram offers", not dead_offers.has("stomp_target") and not dead_offers.has("ram_target"))
	view.detach()


func _route() -> void:
	var points := JevAgent.route_to(Layout.spawn_point(), Scenarios.forge_point())
	var levels: Array = points.map(func(p): return Layout.level_of(p.z))
	var climbing := true
	for i in range(1, levels.size()):
		climbing = climbing and levels[i] >= levels[i - 1]
	_check("the spawn-to-forge route climbs bench by bench to the forge (%d points)" % points.size(),
		climbing and levels[0] == 0 and levels[levels.size() - 1] == 5 and points[points.size() - 1] == Scenarios.forge_point())
