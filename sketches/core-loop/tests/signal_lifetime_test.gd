extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const Events := preload("res://src/core/game_events.gd")
const Swarm := preload("res://src/combat/warden_swarm.gd")
const Game := preload("res://src/game.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")

class Fleet extends RefCounted:
	var bus
	func events():
		return bus

class Warden extends Node:
	var fleet
	var target = null

class ShellAssets extends HeroAssets:
	func _addon(_path: String) -> Node3D:
		var shell := Node3D.new()
		var core := Node3D.new()
		core.name = "Core"
		shell.add_child(core)
		var pod := Node3D.new()
		pod.name = "Pod"
		shell.add_child(pod)
		var ring := Node3D.new()
		ring.name = "WeaponRing"
		pod.add_child(ring)
		return shell

var _failures := 0
var _first := 0
var _second := 0
var _named := 0

func _initialize() -> void:
	_run.call_deferred()

func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])

func _on_clear(_reason := "") -> void:
	_named += 1

func _audio(loose: bool) -> void:
	var events := Events.new()
	_first = 0
	_second = 0
	_named = 0
	var first: Callable
	var second: Callable
	if loose:
		first = func(): _first += 1
		second = func(): _second += 1
	else:
		first = func(_reason: String): _first += 1
		second = func(_reason: String): _second += 1
	Audio._listen(events, "stage_content_cleared", first, loose)
	Audio._listen(events, "stage_content_cleared", second, loose)
	Audio._listen(events, "stage_content_cleared", first, loose)
	events.stage_content_cleared.emit("arena")
	_report("distinct lambdas loose=%s" % loose, _first == 1 and _second == 1,
		"first=%d second=%d connections=%d" % [_first, _second, events.get_signal_connection_list("stage_content_cleared").size()])
	_report("identical lambda loose=%s" % loose, events.get_signal_connection_list("stage_content_cleared").size() == 2,
		"connections=%d want=2" % events.get_signal_connection_list("stage_content_cleared").size())
	events.free()
	events = Events.new()
	Audio._listen(events, "stage_content_cleared", _on_clear, loose)
	Audio._listen(events, "stage_content_cleared", _on_clear, loose)
	Audio._listen(events, "stage_content_cleared", _on_clear)
	events.stage_content_cleared.emit("arena")
	_report("named method dedupes loose=%s" % loose, _named == 1 and events.get_signal_connection_list("stage_content_cleared").size() == 1,
		"calls=%d connections=%d want=1" % [_named, events.get_signal_connection_list("stage_content_cleared").size()])
	events.free()

func _swarm() -> void:
	var events := Events.new()
	var fleet := Fleet.new()
	fleet.bus = events
	var warden := Warden.new()
	warden.fleet = fleet
	root.add_child(warden)
	var driver := Swarm.new()
	driver._listen(warden)
	_report("swarm alive listener", events.get_signal_connection_list("enemy_struck").size() == 1, "one lamp listener")
	events.enemy_struck.emit(null, "weapon", 1.0)
	warden.free()
	_report("freed Warden disconnects", events.get_signal_connection_list("enemy_struck").is_empty(),
		"remaining=%d want=0" % events.get_signal_connection_list("enemy_struck").size())
	events.enemy_struck.emit(null, "weapon", 1.0)
	events.free()

func _shell_ring() -> void:
	var assets := ShellAssets.new()
	root.add_child(assets)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = assets.fit_shell_into(ball, "runner_gunner", "", 2, {})
	var pod: Node3D = rec.get("pod")
	var holder: Node3D = pod.get_node_or_null("HeftC2") if pod != null else null
	var ring: Node3D = pod.get_node_or_null("WeaponRing/HeftC2") if pod != null else null
	_report("shell ring fixture", holder != null and ring != null, "fit_shell_into creates layer and weapon ring")
	if holder != null and ring != null:
		holder.visible = false
		_report("ring follows layer while alive", not ring.visible, "visibility listener ran")
		ring.free()
		_report("freed shell ring disconnects", holder.visibility_changed.get_connections().is_empty(),
			"remaining=%d want=0" % holder.visibility_changed.get_connections().size())
		holder.visible = true
	ball.free()
	assets.free()

func _mind_body() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	var warden := WardenScript.new()
	game.add_child(warden)
	warden.setup(game.player, game.ctx.terrain, game, func(): return true, 1.0,
		{"kind": "warden", "family": "mind", "stage": 6, "variant": "choir", "harpoon_anchor": true, "fleet": game.combat.fleet})
	warden.set_physics_process(false)
	await process_frame
	var assets = game.presentation.hero_assets
	assets._dress_warden(warden)
	var driver = warden.mount_driver
	_report("Mind body fixture", driver != null and driver.took_off.get_connections().size() == 1 and driver.landed.get_connections().size() == 1,
		"real body has takeoff and landing listeners")
	driver.took_off.emit(0, 1)
	driver.landed.emit(1)
	warden.free()
	await process_frame
	_report("freed Mind body disconnects takeoff", driver.took_off.get_connections().is_empty(),
		"remaining=%d want=0" % driver.took_off.get_connections().size())
	_report("freed Mind body disconnects landing", driver.landed.get_connections().is_empty(),
		"remaining=%d want=0" % driver.landed.get_connections().size())
	driver.took_off.emit(0, 1)
	driver.landed.emit(1)
	game.free()

func _run() -> void:
	_audio(false)
	_audio(true)
	_swarm()
	_shell_ring()
	await _mind_body()
	print("signal_lifetime_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
