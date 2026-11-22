extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const PART_NAMES := ["ChaserBody", "ChaserFin", "ChaserClaws"]

const KINDS := {
	"chaser": [true, true], "lobber": [true, true], "splitter": [true, false], "reactor_relic": [true, false],
	"swarm_remnant": [true, false], "mind_hand": [true, false], "warden": [false, false], "vault": [false, false],
	"miniboss": [false, false], "rogue_crane": [false, false], "rogue_skip": [false, false],
	"rogue_tender": [false, false], "brindle_hull": [false, false], "waking_core": [false, false],
}


class WorldGround extends RefCounted:
	var number := 1

	func world() -> int:
		return number


class FakeWarden extends "res://src/combat/enemy.gd":
	var _charging := false
	var family := "reactor"

	func charge_fraction() -> float:
		return 0.5


class FakeSwarm extends RefCounted:
	enum State { HUNT, LOCKED }
	const LOCK_WARN := 1.0
	var state := State.HUNT
	var t := 0.5

	func lane():
		return null


class FakeRemnant extends "res://src/combat/enemy.gd":
	var swarm


var _game
var _t := T.new("w45_perf_cpu_unit2_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	_pose_settles()
	_interrupted_lasts()
	_kind_reads()
	_winding_up()
	await _rescue()
	_verb_items()
	_shred()
	_game.free()
	quit(_t.verdict())


func _spawn(kind := "chaser"):
	var enemy = _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(-100.0, -90.0, 1.6))
	enemy.hp = 100000.0
	return enemy


func _at_rest(enemy) -> bool:
	for part_name in PART_NAMES:
		var part: Dictionary = enemy._pose_parts[part_name]
		if part.node.transform != part.rest:
			return false
	return true


func _pose_settles() -> void:
	var enemy = _spawn()
	enemy.set_physics_process(false)
	enemy._pose()
	_t.check("chase pose is rest", _at_rest(enemy) and not enemy._parts_off_rest)
	enemy._begin_windup(Vector3.FORWARD)
	enemy._clock = enemy.WINDUP * 0.5
	enemy._pose()
	var body: Dictionary = enemy._pose_parts["ChaserBody"]
	_t.check("wind-up poses the body", body.node.transform != body.rest and enemy._parts_off_rest)
	enemy.state = enemy.State.LUNGE
	enemy._clock = 0.04
	enemy._pose()
	_t.check("lunge poses the body", body.node.transform != body.rest)
	enemy._end_attack(enemy.State.RECOVER)
	enemy._pose()
	_t.check("recover puts every part back to rest", _at_rest(enemy) and not enemy._parts_off_rest)
	enemy.state = enemy.State.CHASE
	enemy._pose()
	_t.check("chase stays at rest", _at_rest(enemy) and not enemy._parts_off_rest)
	enemy.windup_pose_enabled = false
	enemy._rest = 0.0
	enemy._begin_windup(Vector3.FORWARD)
	enemy._clock = enemy.WINDUP * 0.5
	enemy._pose()
	_t.check("disabled pose stays at rest", _at_rest(enemy) and not enemy._parts_off_rest)
	enemy.free()


func _interrupted_lasts() -> void:
	var enemy = _spawn()
	enemy.set_physics_process(false)
	enemy._begin_windup(Vector3.FORWARD)
	enemy._knock = Vector3(enemy.INTERRUPT + enemy.KNOCK_DECAY * 0.25 + 2.0, 0.0, 0.0)
	var shown := 0
	var painted := true
	for i in 8:
		enemy._physics_process(0.25)
		if enemy.cue_state() == "interrupted":
			shown += 1
			painted = painted and enemy._material.emission_enabled
	_t.eq("interrupted cue ticks at 0.25 s", shown, 4)
	_t.check("interrupted cue painted while shown", painted and not enemy._material.emission_enabled)
	enemy.free()


func _kind_reads() -> void:
	var enemy = _spawn()
	enemy.set_physics_process(false)
	var home = enemy.terrain
	var ground := WorldGround.new()
	enemy.terrain = ground
	var wrong: Array = []
	for pass_index in 2:
		for kind in KINDS:
			enemy.kind = kind
			if enemy._ordinary_reaction() != KINDS[kind][0]:
				wrong.append("%s reaction" % kind)
			for world in [1, 2, 3]:
				ground.number = world
				var want: bool = KINDS[kind][1] and world == enemy.RING_OUT_WORLD
				if enemy.ring_outs_here() != want:
					wrong.append("%s world %d" % [kind, world])
	enemy.kind = "chaser"
	enemy.terrain = null
	if enemy.ring_outs_here():
		wrong.append("no terrain")
	enemy.terrain = home
	_t.check("reaction and ring-out answers by kind and world", wrong.is_empty(), "wrong %s" % [wrong])
	enemy.free()


func _winding_up() -> void:
	var warden := FakeWarden.new()
	root.add_child(warden)
	warden.set_physics_process(false)
	warden.kind = "warden"
	_t.check("idle warden is not winding up", not warden.winding_up())
	warden._charging = true
	_t.check("charging warden is winding up", warden.winding_up())
	warden.free()
	var remnant := FakeRemnant.new()
	root.add_child(remnant)
	remnant.set_physics_process(false)
	remnant.kind = "swarm_remnant"
	remnant.swarm = FakeSwarm.new()
	_t.check("hunting remnant is not winding up", not remnant.winding_up())
	remnant.swarm.state = FakeSwarm.State.LOCKED
	_t.check("locked remnant is winding up", remnant.winding_up())
	remnant.kind = "chaser"
	_t.check("a lock on another kind is not a wind-up", not remnant.winding_up())
	remnant._atk = {"row": "E01"}
	_t.check("an open attack is a wind-up", remnant.winding_up())
	remnant._atk = {}
	remnant.free()
	var chaser = _spawn()
	chaser.set_physics_process(false)
	_t.check("chasing chaser is not winding up", not chaser.winding_up())
	chaser._begin_windup(Vector3.FORWARD)
	_t.check("chaser with a lane is winding up", chaser.winding_up())
	chaser.free()


func _rescue() -> void:
	var enemy = _spawn()
	await _frames(30)
	enemy.set_physics_process(false)
	var at: Vector3 = enemy.global_position
	var ground: float = _game.ctx.terrain.height(at.x, at.z)
	enemy._rescue()
	_t.check("standing body stays put", enemy.global_position == at and enemy.is_on_floor(), "y %.2f ground %.2f" % [at.y, ground])
	enemy.global_position = Vector3(at.x, ground - enemy.FLOOR_RESCUE - 5.0, at.z)
	enemy._rescue()
	_t.check("dropped body is rescued", enemy.global_position.y > ground - enemy.FLOOR_RESCUE, "y %.2f ground %.2f" % [enemy.global_position.y, ground])
	enemy.global_position = Vector3(at.x + 6.0, ground - enemy.FLOOR_RESCUE - 5.0, at.z)
	enemy._rescue()
	var there: float = _game.ctx.terrain.height(at.x + 6.0, at.z)
	_t.check("dropped body in a new cell is rescued", enemy.global_position.y > there - enemy.FLOOR_RESCUE, "y %.2f ground %.2f" % [enemy.global_position.y, there])
	enemy.free()


func _verb_items() -> void:
	var combat = _game.combat
	combat._step_verb_items([])
	_t.check("empty verb items stay empty", combat._strips.is_empty() and combat._bells.is_empty())
	var at: Vector3 = _game.ctx.terrain.drop_point(-60.0, -60.0, 0.0)
	var strip: Dictionary = combat._lay_strip("backwash", at, at + Vector3(4.0, 0.0, 0.0), 2.0, 1.0, 0.5, 0.0)
	var bell := {"id": "second_bell", "at": combat._clock + 0.25, "source": "item_proc", "bits": 0, "knock": 0.0,
		"breaks": false, "mode": "pulse", "damage": 1.0, "limit": -1, "layer": "unit2_bell",
		"shape": _game.ctx.player.yours({"kind": "ring", "centre": at, "radius": 1.0})}
	combat._bells.append(bell)
	combat.last_bell = {}
	combat._step_verb_items([])
	_t.check("live strip and early bell are kept", combat._strips.has(strip) and combat._bells.has(bell) and combat.last_bell.is_empty())
	combat._clock += 0.3
	combat._step_verb_items([])
	_t.check("due bell tolls once", not combat._bells.has(bell) and combat.last_bell.get("hits", -1) == 0 and combat._strips.has(strip))
	combat._clock += 0.3
	combat._step_verb_items([])
	_t.check("spent strip goes", not combat._strips.has(strip) and combat._bells.is_empty())


func _shred() -> void:
	var combat = _game.combat
	combat._shred.clear()
	combat._decay_shred(0.1)
	_t.check("no shred stays none", combat._shred.is_empty())
	var enemy = _spawn("lobber")
	enemy.set_physics_process(false)
	enemy.plating = 20.0
	combat._add_shred(enemy, 40.0)
	var before: float = combat.shred_of(enemy)
	combat._decay_shred(0.1)
	var after: float = combat.shred_of(enemy)
	_t.check("shred decays", before > 0.0 and after > 0.0 and after < before, "%.4f -> %.4f" % [before, after])
	var dead = _spawn("lobber")
	combat._add_shred(dead, 40.0)
	var dead_id: int = dead.get_instance_id()
	dead.free()
	combat._decay_shred(0.1)
	_t.check("a freed body's shred goes", not combat._shred.has(dead_id) and combat._shred.has(enemy.get_instance_id()))
	enemy.free()
	combat._decay_shred(0.1)
	_t.check("all shred gone with its bodies", combat._shred.is_empty())
