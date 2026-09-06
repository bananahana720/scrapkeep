extends SceneTree

const SessionOwner: GDScript = preload("res://proofs/tadr-002/session_owner.gd")
const EncounterCoordinator: GDScript = preload("res://proofs/tadr-002/encounter_coordinator.gd")
const EncounterState: GDScript = preload("res://proofs/tadr-002/encounter_state.gd")
const InputAdapter: GDScript = preload("res://proofs/tadr-002/input_adapter.gd")
const MenuProbe: GDScript = preload("res://proofs/tadr-002/menu_probe.gd")
const Intruder: GDScript = preload("res://proofs/tadr-002/intruder.gd")

const MARKER: String = "S0-04"
const N: int = 10
const PHASE_CEILING: int = 600
const EXIT_PASS: int = 0
const EXIT_ASSERTION: int = 1
const EXIT_CEILING: int = 2
const EXIT_HARNESS: int = 3

var session: SessionOwner = SessionOwner.new()
var menu: MenuProbe = MenuProbe.new()
var intruder: Intruder = Intruder.new()
var failures: int = 0
var assertions: int = 0
var ceiling_hit: String = ""
var phase_frames: int = 0


func _initialize() -> void:
	intruder.coordinator = session.coordinator
	intruder.inject_fault = OS.get_cmdline_user_args().has("--inject-fault")
	root.add_child(session)
	root.add_child(menu)
	root.add_child(intruder)
	print("%s PLACEHOLDER_TICK_RATE %d" % [MARKER, Engine.physics_ticks_per_second])
	run()


func run() -> void:
	await physics_frame
	if not session.coordinator.is_inside_tree() or Engine.physics_ticks_per_second <= 0:
		print("%s harness FAIL tree not built" % [MARKER])
		finish(EXIT_HARNESS)
		return
	for phase: Callable in [phase_a, phase_b, phase_c, phase_d, phase_e]:
		phase_frames = 0
		await phase.call()
		if ceiling_hit != "":
			return
	finish(EXIT_ASSERTION if failures > 0 else EXIT_PASS)


func phase_a() -> void:
	var coordinator: EncounterCoordinator = session.coordinator
	var run_id: String = session.run_id
	var tick0: int = coordinator.published().tick
	var calls0: int = coordinator.physics_calls
	if not await wait_frames("A", N):
		return
	var state: EncounterState = coordinator.published()
	check("A", state.tick - tick0 == N and coordinator.physics_calls - calls0 == N and state.tick == coordinator.physics_calls, "tick %d physics_calls %d after %d frames" % [state.tick, coordinator.physics_calls, N])
	check("A", session.run_id == run_id, "run_id %s unchanged" % [session.run_id])


func phase_b() -> void:
	var coordinator: EncounterCoordinator = session.coordinator
	intruder.arm()
	if not await wait_until("B", func() -> bool: return intruder.timer_fired >= 1 and intruder.process_calls >= 1):
		return
	if not await wait_frames("B", N):
		return
	intruder.disarm()
	var state: EncounterState = coordinator.published()
	check("B", coordinator.rejected_out_of_phase >= 2 and coordinator.accepted_in_phase == 0, "rejected_out_of_phase %d accepted_in_phase %d (process %d timer %d)" % [coordinator.rejected_out_of_phase, coordinator.accepted_in_phase, intruder.process_calls, intruder.timer_fired])
	check("B", state.tick == coordinator.physics_calls, "tick %d physics_calls %d" % [state.tick, coordinator.physics_calls])
	check("B", intruder.copy.casts_committed >= 2 and intruder.copy.prepared == "intruder" and state.casts_committed == 0 and state.prepared == "", "intruder copy casts %d prepared %s; coordinator casts %d prepared %s" % [intruder.copy.casts_committed, intruder.copy.prepared, state.casts_committed, JSON.stringify(state.prepared)])


func phase_c() -> void:
	var coordinator: EncounterCoordinator = session.coordinator
	coordinator.submit(EncounterCoordinator.CMD_PREPARE_CAST)
	session.input.press("cast")
	if not await wait_frames("C", 2):
		return
	var held: EncounterState = coordinator.published()
	session.input.release("cast")
	if not await wait_frames("C", 2):
		return
	var state: EncounterState = coordinator.published()
	check("C", held.prepared == "cast" and held.casts_committed == 0 and state.casts_committed == 1 and state.prepared == "", "prepared while held %s; casts_committed %d after release" % [JSON.stringify(held.prepared), state.casts_committed])


func phase_d() -> void:
	var coordinator: EncounterCoordinator = session.coordinator
	coordinator.submit(EncounterCoordinator.CMD_PREPARE_CAST)
	if not await wait_frames("D", 1):
		return
	session.pause()
	var tick0: int = coordinator.published().tick
	var menu0: int = menu.process_calls
	if not await wait_frames("D", N):
		return
	var state: EncounterState = coordinator.published()
	check("D", paused and state.tick == tick0, "tick %d constant across %d frames while paused" % [state.tick, N])
	check("D", menu.process_calls > menu0, "menu probe _process %d -> %d" % [menu0, menu.process_calls])
	check("D", state.prepared == "cast", "prepared %s untouched by pause" % [JSON.stringify(state.prepared)])


func phase_e() -> void:
	var coordinator: EncounterCoordinator = session.coordinator
	session.resume()
	coordinator.submit(EncounterCoordinator.CMD_PREPARE_CAST)
	session.input.press("cast")
	if not await wait_frames("E", 2):
		return
	var casts_before: int = coordinator.published().casts_committed
	session.lose_focus()
	var tick0: int = coordinator.published().tick
	if not await wait_frames("E", N):
		return
	var during: EncounterState = coordinator.published()
	check("E", paused and not session.input.any_held() and during.tick == tick0, "held all false, tick %d constant, pending %s" % [during.tick, coordinator.pending()])
	session.resume()
	if not await wait_frames("E", N):
		return
	var state: EncounterState = coordinator.published()
	check("E", state.prepared == "" and state.casts_committed == casts_before and state.casts_committed == 1, "prepared %s casts_committed %d after resume" % [JSON.stringify(state.prepared), state.casts_committed])
	check("E", state.tick == tick0 + N and state.tick == coordinator.physics_calls, "tick %d advancing after resume" % [state.tick])


func wait_frames(phase: String, count: int) -> bool:
	for i: int in count:
		if not await next_frame(phase):
			return false
	return true


func wait_until(phase: String, condition: Callable) -> bool:
	while not condition.call():
		if not await next_frame(phase):
			return false
	return true


func next_frame(phase: String) -> bool:
	if phase_frames >= PHASE_CEILING:
		ceiling_hit = phase
		print("%s %s FAIL ceiling of %d physics frames exceeded" % [MARKER, phase, PHASE_CEILING])
		finish(EXIT_CEILING)
		return false
	await physics_frame
	phase_frames += 1
	return true


func check(phase: String, ok: bool, detail: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
	print("%s %s %s %s" % [MARKER, phase, "PASS" if ok else "FAIL", detail])


func finish(code: int) -> void:
	var coordinator: EncounterCoordinator = session.coordinator
	var state: EncounterState = coordinator.published()
	var summary: Dictionary[String, Variant] = {
		"marker": MARKER,
		"engine": version_token(),
		"placeholder_tick_rate": Engine.physics_ticks_per_second,
		"inject_fault": intruder.inject_fault,
		"assertions": assertions,
		"failures": failures,
		"ceiling_hit": ceiling_hit,
		"tick": state.tick,
		"physics_calls": coordinator.physics_calls,
		"rejected_out_of_phase": coordinator.rejected_out_of_phase,
		"accepted_in_phase": coordinator.accepted_in_phase,
		"casts_committed": state.casts_committed,
		"menu_process_calls": menu.process_calls,
		"intruder_process_calls": intruder.process_calls,
		"intruder_timer_fired": intruder.timer_fired,
		"focus_trigger": session.focus_trigger,
		"exit_code": code,
	}
	print("%s SUMMARY %s" % [MARKER, JSON.stringify(summary)])
	quit(code)


func version_token() -> String:
	var info: Dictionary = Engine.get_version_info()
	var major: int = info["major"]
	var minor: int = info["minor"]
	var patch: int = info["patch"]
	var status: String = info["status"]
	var build: String = info["build"]
	var full_hash: String = info["hash"]
	return "%d.%d.%d.%s.%s.%s" % [major, minor, patch, status, build, full_hash.substr(0, 9)]
