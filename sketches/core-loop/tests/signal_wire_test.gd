extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const Events := preload("res://src/core/game_events.gd")
const Swarm := preload("res://src/combat/warden_swarm.gd")
const Game := preload("res://src/game.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")

class Fleet extends RefCounted:
	var bus
	func events():
		return bus

class Warden extends Node:
	var fleet
	var target = null
	var world_root: Node

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
	if "--signal-wire-child" in OS.get_cmdline_user_args():
		_run.call_deferred()
	else:
		_run_parent.call_deferred()

func _run_parent() -> void:
	var audio_only := "--audio-only" in OS.get_cmdline_user_args()
	var args := ["--signal-wire-child"]
	if audio_only:
		args.append("--audio-only")
	var result: Dictionary = ChildRuns.run([
		{"script": "res://tests/signal_wire_test.gd", "args": args}
	], 120.0)[0]
	var summary := ChildRuns.summary(result)
	for line in summary.checks:
		print(line)
	for error in summary.errors:
		print("child engine error: %s" % error)
	var ok: bool = result.code == 0 and not result.timed_out \
		and summary.verdict == "signal_wire_test: PASS" and summary.errors.is_empty()
	_report("bounded child audio-only=%s" % audio_only, ok,
		"exit=%s timed_out=%s verdict=%s errors=%d" % [result.code, result.timed_out, summary.verdict, summary.errors.size()])
	if not audio_only:
		_report("bus may free before owner", ok and String(result.log).contains("[bus-first cleanup completed]"),
			"cleanup completed with checked child result")
	_finish()

func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])

func _on_clear(_reason := "") -> void:
	_named += 1

func _on_bound(_reason: String, _tag: String) -> void:
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
	Audio._listen(events, "stage_content_cleared", _on_clear.unbind(1))
	events.stage_content_cleared.emit("arena")
	_report("named method dedupes loose=%s" % loose, _named == 1 and events.get_signal_connection_list("stage_content_cleared").size() == 1,
		"calls=%d connections=%d want=1" % [_named, events.get_signal_connection_list("stage_content_cleared").size()])
	events.free()
	events = Events.new()
	_first = 0
	_second = 0
	var same_name_first := func _on_clear(_reason = ""): _first += 1
	var same_name_second := func _on_clear(_reason = ""): _second += 1
	Audio._listen(events, "stage_content_cleared", same_name_first)
	Audio._listen(events, "stage_content_cleared", same_name_first, true)
	Audio._listen(events, "stage_content_cleared", same_name_second, true)
	events.stage_content_cleared.emit("arena")
	_report("named lambdas keep identity across loose", _first == 1 and _second == 1 and events.get_signal_connection_list("stage_content_cleared").size() == 2,
		"first=%d second=%d connections=%d want=2" % [_first, _second, events.get_signal_connection_list("stage_content_cleared").size()])
	_named = 0
	Audio._listen(events, "stage_content_cleared", _on_clear)
	events.stage_content_cleared.emit("arena")
	_report("named lambda differs from named method", _named == 1 and _first == 2 and _second == 2 and events.get_signal_connection_list("stage_content_cleared").size() == 3,
		"method calls=%d connections=%d want=3" % [_named, events.get_signal_connection_list("stage_content_cleared").size()])
	events.free()
	events = Events.new()
	_named = 0
	Audio._listen(events, "stage_content_cleared", _on_bound.bind("first"))
	Audio._listen(events, "stage_content_cleared", _on_bound.bind("second"))
	events.stage_content_cleared.emit("arena")
	_report("bound named method keeps method dedupe", _named == 1 and events.get_signal_connection_list("stage_content_cleared").size() == 1,
		"calls=%d connections=%d want=1" % [_named, events.get_signal_connection_list("stage_content_cleared").size()])
	events.free()

func _owner_exit() -> void:
	var events := Events.new()
	var owner := Node.new()
	var other_owner := Node.new()
	root.add_child(owner)
	root.add_child(other_owner)
	var calls := [0, 0, 0]
	var callback := func(_reason: String):
		calls[0] += 1
		owner.set_meta("heard", true)
	var second_callback := func(_reason: String):
		calls[1] += 1
		owner.set_meta("heard_second", true)
	var other_callback := func(_reason: String):
		calls[2] += 1
		other_owner.set_meta("heard", true)
	SignalWire.listen_until_exit(owner, events.stage_content_cleared, callback)
	SignalWire.listen_until_exit(owner, events.stage_content_cleared, callback)
	SignalWire.listen_until_exit(owner, events.stage_content_cleared, second_callback)
	SignalWire.listen_until_exit(other_owner, events.stage_content_cleared, other_callback)
	events.stage_content_cleared.emit("alive")
	_report("helper keeps three distinct listeners", calls == [1, 1, 1] and events.stage_content_cleared.get_connections().size() == 3,
		"calls=%s want=[1, 1, 1] connections=%d want=3" % [calls, events.stage_content_cleared.get_connections().size()])
	root.remove_child(owner)
	_report("owner exit disconnects only its two callbacks",
		not events.stage_content_cleared.is_connected(callback) and not events.stage_content_cleared.is_connected(second_callback)
		and events.stage_content_cleared.is_connected(other_callback),
		"first=%s second=%s other=%s want=false,false,true" % [events.stage_content_cleared.is_connected(callback), events.stage_content_cleared.is_connected(second_callback), events.stage_content_cleared.is_connected(other_callback)])
	events.stage_content_cleared.emit("detached")
	_report("other owner listener still fires", calls == [1, 1, 2], "calls=%s want=[1, 1, 2]" % [calls])
	owner.free()
	root.remove_child(other_owner)
	_report("second owner exit disconnects its callback", not events.stage_content_cleared.is_connected(other_callback),
		"other=%s want=false" % events.stage_content_cleared.is_connected(other_callback))
	events.stage_content_cleared.emit("both detached")
	_report("both owners stop receiving after exit", calls == [1, 1, 2], "calls=%s want=[1, 1, 2]" % [calls])
	other_owner.free()
	events.free()
	events = Events.new()
	owner = Node.new()
	root.add_child(owner)
	SignalWire.listen_until_exit(owner, events.stage_content_cleared, func(_reason: String): pass)
	events.free()
	owner.free()
	print("[bus-first cleanup completed] owner cleanup emitted after bus free")

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

func _swarm_slab() -> void:
	var warden := Warden.new()
	root.add_child(warden)
	var driver := Swarm.new()
	driver._build_slab(warden)
	var slab: Node = driver._slab
	_report("swarm slab fixture", slab != null and warden.tree_exiting.get_connections().size() == 1, "pool floor listens to Warden exit")
	slab.free()
	_report("freed pool floor disconnects", warden.tree_exiting.get_connections().is_empty(),
		"remaining=%d want=0" % warden.tree_exiting.get_connections().size())
	warden.free()
	warden = Warden.new()
	root.add_child(warden)
	driver = Swarm.new()
	driver._build_slab(warden)
	slab = driver._slab
	warden.free()
	await process_frame
	_report("Warden exit still frees live pool floor", not is_instance_valid(slab), "floor cleanup retained")

func _mind_body() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	var audio = game.presentation.audio
	var before: int = game.events.element_resolved.get_connections().filter(func(c): return c.callable.get_object() == audio).size()
	audio.wire_optional()
	audio.wire_optional()
	var after: int = game.events.element_resolved.get_connections().filter(func(c): return c.callable.get_object() == audio).size()
	_report("optional wiring reuses one listener", before == 1 and after == 1, "Audio element listeners %d -> %d want=1" % [before, after])
	var spec := {"kind": "warden", "family": "mind", "stage": 6, "variant": "choir", "harpoon_anchor": true, "fleet": game.combat.fleet}
	var warden := WardenScript.new()
	game.add_child(warden)
	warden.setup(game.player, game.ctx.terrain, game, func(): return true, 1.0, spec)
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
	warden = WardenScript.new()
	game.add_child(warden)
	warden.setup(game.player, game.ctx.terrain, game, func(): return true, 1.0, spec)
	warden.set_physics_process(false)
	await process_frame
	assets._dress_warden(warden)
	driver = warden.mount_driver
	assets.get_parent().remove_child(assets)
	await process_frame
	_report("retired Mind body disconnects before Warden", driver.took_off.get_connections().is_empty() and driver.landed.get_connections().is_empty(),
		"takeoff=%d landing=%d want=0 while Warden alive" % [driver.took_off.get_connections().size(), driver.landed.get_connections().size()])
	driver.took_off.emit(0, 1)
	driver.landed.emit(1)
	assets.free()
	warden.free()
	game.free()

func _run() -> void:
	_audio(false)
	_audio(true)
	if "--audio-only" in OS.get_cmdline_user_args():
		_finish()
		return
	_swarm()
	_owner_exit()
	_shell_ring()
	await _swarm_slab()
	await _mind_body()
	_finish()

func _finish() -> void:
	print("signal_wire_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
