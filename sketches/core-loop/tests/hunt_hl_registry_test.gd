extends SceneTree

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("hunt_hl_registry_test")


class DressingHost extends Node:
	func _sync_dressing() -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = await Probe.boot(self)
	if not _t.check("HL01 game booted", game.flow != null):
		game.free()
		quit(_t.verdict())
		return
	Harness.enter_world(game, 2)
	Harness.module(game, 2).exit_arena()
	await process_frame
	var before := _registry()
	for attempt in 20:
		Harness.enter_world(game, 2)
		var mod = Harness.module(game, 2)
		_t.check("HL01 attempt %d builds real Waking dressing" % attempt, mod._arena_dress != null)
		mod.exit_arena()
		await process_frame
	_t.eq("HL01 teardown keeps registry size and dead entries at baseline", _registry(), before)
	game.free()
	_t.eq("HL01 disposing the game removes all dressing hosts", _registry(), {"entries": 0, "dead": 0})
	var host := DressingHost.new()
	root.add_child(host)
	before = _registry()
	Preset.register_dressing_host(host)
	Preset.register_dressing_host(host)
	_t.eq("HL01 registering the same host twice adds one entry", _registry().entries, before.entries + 1)
	root.remove_child(host)
	_t.eq("HL01 removing a host unregisters it before deletion", _registry(), before)
	host.free()
	quit(_t.verdict())


func _registry() -> Dictionary:
	var dead := 0
	for ref in Preset._dressing_hosts:
		if ref.get_ref() == null:
			dead += 1
	return {"entries": Preset._dressing_hosts.size(), "dead": dead}
