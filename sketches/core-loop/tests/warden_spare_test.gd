# smoke: solo timeout=300s
extends SceneTree

# WARDEN-SPARE (perf lane, flume entry): where stages build on workers (a played game, a frame-capture bot run), a
# launch flight readies a painted spare body for each Warden kind the run has loaded, off the tree, and the next
# dress of that kind takes it whole (hero_assets._on_launched, _step_spares, _take_spare). The 4080 probe on
# ca004071 (scrapkeep#512) had the flume Warden's paint at 12-15 ms of the entry frame.
#
# Plays the park table headless through the real flow with SimClock.ticks off, as a played game, and checks:
#   - stage 1's dam Warden wears its reactor body; the flight readies a reactor spare, painted, off the tree;
#   - the flume Warden's dress takes that spare (the same body), and the pool is empty after;
#   - the taken body's surfaces carry the same materials, slot for slot, as a stage 2 retry's own dress, with its own
#     copies of the per-body slots;
#   - a bot run (SimClock.ticks) readies nothing.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const SETTLE_TICKS := 30
const WAIT_TICKS_MAX := 3600

var _game
var _t := T.new("warden_spare_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SimClock.ticks = false
	seed(11)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await physics_frame
	await physics_frame
	_game.run.run_seed_override = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _ticks(SETTLE_TICKS)
	var hero = _game.find_child("HeroAssets", true, false)
	_t.check("the run is on park stage 1 with hero assets", _game.flow.stage() == 1 and hero != null, "stage %d" % _game.flow.stage())
	if hero == null:
		quit(_t.verdict())
		return
	var dam := _warden_body()
	_t.check("the dam Warden wears its reactor body", dam != null, "")
	var terrain = _game.ctx.terrain
	terrain.prepare(2)
	var waited := 0
	while not terrain.is_ready(2) and waited < WAIT_TICKS_MAX:
		await physics_frame
		waited += 1

	_launch()
	var ticks := 0
	while (not hero._spares.has("reactor") or not hero._spares.reactor.unpainted.is_empty()) and _game.flow.state_name() == "launch" and ticks < 200:
		await physics_frame
		ticks += 1
	var spare: Dictionary = hero._spares.get("reactor", {})
	_t.check("the flight readies a painted reactor spare before the entry", not spare.is_empty() and spare.unpainted.is_empty()
		and _game.flow.state_name() == "launch", "%s after %d ticks" % [_game.flow.state_name(), ticks])
	var spare_body: Node3D = spare.get("body")
	_t.check("the spare is off the tree", spare_body != null and not spare_body.is_inside_tree(), "")
	while _game.flow.state_name() == "launch" and ticks < WAIT_TICKS_MAX:
		await physics_frame
		ticks += 1
	await _ticks(3)
	var flume := _warden_body()
	_t.check("the flume Warden's dress takes the spare", _game.flow.stage() == 2 and flume != null and flume == spare_body,
		"stage %d" % _game.flow.stage())
	_t.check("the spare pool is empty after the dress", not hero._spares.has("reactor"), "")
	var taken := _paint(flume)
	var taken_slots := _slots(flume)

	_game.flow.retry_stage()
	await _ticks(4)
	var own := _warden_body()
	_t.check("a stage 2 retry dresses its own body", own != null and own != spare_body, "")
	var built := _paint(own)
	_t.check("the taken body is painted as the retry's own, slot for slot", taken.size() > 0 and taken == built,
		"%d vs %d surfaces" % [taken.size(), built.size()])
	var odd := _shared_wrong(taken_slots, _slots(own))
	_t.check("the taken body has its own per-body materials and shares the rest", own != null and taken_slots.size() > 0 and odd.is_empty(),
		str(odd))

	SimClock.ticks = true
	hero._on_launched(Vector3.ZERO)
	_t.check("a bot run readies nothing", hero._spare_wait == -1, "")
	SimClock.ticks = false

	_game.queue_free()
	await process_frame
	quit(_t.verdict())


func _launch() -> void:
	_game.player.reset_to(_game.ctx.terrain.spawn_point(_game.flow.stage()) + Vector3.UP * 2.0, Vector3(0.0, 0.0, 6.0))
	_game.flow._set_state(_game.flow.GATES)
	_game.ctx.events.launched.emit(Vector3(0.0, 8.0, 12.0))


func _warden_body() -> Node3D:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.is_inside_tree() and enemy.has_node("HeroWarden"):
			return enemy.get_node("HeroWarden")
	return null


# Each mesh surface's material slot and kind, in tree order.
func _paint(body: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if body == null:
		return out
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i)
			out.append("%s %d %s %s" % [mi.name, i, mat.resource_name if mat != null else "-", mat.get_class() if mat != null else "-"])
	return out


# Each material slot under body -> the material's instance id.
func _slots(body: Node) -> Dictionary:
	var out := {}
	if body == null:
		return out
	for node in body.find_children("*", "MeshInstance3D", true, false):
		for i in (node as MeshInstance3D).mesh.get_surface_count():
			var mat := (node as MeshInstance3D).get_surface_override_material(i)
			if mat != null:
				out[mat.resource_name] = mat.get_instance_id()
	return out


# The slots where two bodies share a per-body material (ancient_light*, ancient_enamel) or hold two of a shared one.
static func _shared_wrong(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for slot: String in a:
		if not b.has(slot):
			continue
		var own := slot.begins_with("ancient_light") or slot == "ancient_enamel"
		if own == (a[slot] == b[slot]):
			out.append(slot)
	return out


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
