extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")

# The meltdown Warden's slag lane is telegraphed: it appears at progress 0 on the pulse,
# fills over SLAG_WARN before it burns, publishes windup then strike through
# attack_phase, and the burn reads the lane node's contains(). Before SLAG_WARN passes a
# ball standing in the lane takes nothing; a ball outside the lane never does.


class FlowDouble extends RefCounted:
	var row := {"warden_variant": "meltdown"}

	func stage_def() -> Dictionary:
		return row


class CtxDouble extends RefCounted:
	var events
	var flow := FlowDouble.new()


var _game
var _failures := 0
var _hits: Array = []
var _phases: Array = []
const DT := 1.0 / 90.0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _on_hit(amount: float, _push: Vector3) -> void:
	_hits.append(amount)


func _on_phase(facts: Dictionary) -> void:
	_phases.append(String(facts["phase"]))
	if facts["row"] != "W01":
		_failures += 1


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await physics_frame
	_game.run.set_max_hp(99999.0)
	_check()
	_game.free()
	print("warden_meltdown_slag_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _place_ball(at: Vector3) -> void:
	_game.player._rigid.global_position = at
	_game.player.state.grounded = true


func _on_ground(node, at: Vector3) -> Vector3:
	return Vector3(at.x, node.ground_under(node.terrain, at) + 1.0, at.z)


func _check() -> void:
	var fleet := preload("res://src/combat/fleet.gd").new()
	var ctx := CtxDouble.new()
	ctx.events = _game.events
	fleet.ctx = ctx
	fleet.combat = _game.ctx.spawner
	var warden := Warden.new()
	_game.add_child(warden)
	warden.position = Vector3(40.0, 0.0, 0.0)
	warden.setup(_game.player, _game.ctx.terrain, _game, func(): return false, 1.0,
		fleet.dress("warden", {"family": Roster.REACTOR, "stage": 1, "fleet": fleet, "plating": 30.0, "hp": 800.0}))
	warden.hit_player.connect(_on_hit)
	warden.attack_phase.connect(_on_phase)
	_place_ball(warden.global_position + Vector3(0.0, 1.0, 12.0))
	var guard := 0
	while warden.pulses == 0 and guard < 2000:
		warden._step_pulse(DT, true)
		guard += 1
	var lane: Dictionary = warden.slag_lanes[0] if warden.slag_lanes.size() == 1 else {}
	var node = lane.get("node")
	_report("lane laid at progress 0", warden.variant == "meltdown" and node != null and node.progress == 0.0
		and _phases == ["windup"], "variant '%s', lanes %d, phases %s" % [warden.variant, warden.slag_lanes.size(), _phases])
	if node == null:
		warden.free()
		fleet.free()
		return
	var inside := _on_ground(node, lane["from"] + lane["dir"] * 5.0)
	var outside := _on_ground(node, lane["from"] + lane["dir"].cross(Vector3.UP).normalized() * 20.0)
	_report("lane contains by node", node.contains(inside) and not node.contains(outside),
		"inside %s, outside %s" % [node.contains(inside), node.contains(outside)])
	_place_ball(inside)
	_hits.clear()
	var early := 0.0
	while early < 0.9:
		warden._step_slag(DT)
		early += DT
	_report("no damage before SLAG_WARN", _hits.is_empty() and warden._slag_burn == 0.0 and node.progress < 1.0,
		"after %.2f s: hits %d, burn %.2f, progress %.2f" % [early, _hits.size(), warden._slag_burn, node.progress])
	var t := early
	var filling := 0.0
	var damage_at := -1.0
	while t < Warden.SLAG_WARN + 1.5 and not warden.slag_lanes.is_empty():
		warden._step_slag(DT)
		t += DT
		if node.progress < 1.0 and is_instance_valid(node):
			filling = t
		if damage_at < 0.0 and not _hits.is_empty():
			damage_at = t
	_report("filled for SLAG_WARN before damage", filling >= Warden.SLAG_WARN * 0.9 and damage_at >= Warden.SLAG_WARN * 0.9,
		"progress < 1 until %.2f s, first damage at %.2f s, SLAG_WARN %.2f" % [filling, damage_at, Warden.SLAG_WARN])
	_report("windup then strike", _phases.size() >= 2 and _phases[0] == "windup" and _phases[1] == "strike",
		"phases %s" % [_phases])
	# A ball outside the lane takes nothing while it burns.
	_place_ball(outside)
	_hits.clear()
	for i in 90:
		warden._step_slag(DT)
	_report("outside the lane takes none", _hits.is_empty() and not warden.slag_lanes.is_empty(),
		"hits %d, lanes %d" % [_hits.size(), warden.slag_lanes.size()])
	warden.free()
	fleet.free()
