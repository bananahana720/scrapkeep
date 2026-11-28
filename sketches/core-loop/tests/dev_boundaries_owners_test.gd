extends SceneTree

const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Combat := preload("res://src/combat/combat.gd")
const DevFight := preload("res://src/dev/dev_fight.gd")
const DevInspect := preload("res://src/dev/dev_inspect.gd")
const DevLens := preload("res://src/dev/dev_lens.gd")
const DevOverlay := preload("res://src/dev/dev_overlay.gd")
const Flood := preload("res://src/world/flood.gd")
const FloodCycle := preload("res://src/world/flood_cycle.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const PartResource := preload("res://src/experimental/part_resource.gd")
const RunState := preload("res://src/core/run_state.gd")
const T := preload("res://tests/support/t.gd")

const ALLOWED_PRIVATE_CALLS := [
	"res://src/dev/dev_session.gd: session._boot(",
]

var _t := T.new("dev_boundaries_owners_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_dev_private_calls()
	_check_single_owners()
	_check_owner_apis()
	await _check_standalone_overlay()
	quit(_t.verdict())


func _src_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	out.sort()
	return out


func _strip_strings_and_comments(line: String) -> String:
	var out := ""
	var quote := ""
	var escaped := false
	for i in line.length():
		var ch := line.substr(i, 1)
		if quote != "":
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == quote:
				quote = ""
			continue
		if ch == "#":
			break
		if ch == "\"" or ch == "'":
			quote = ch
			continue
		out += ch
	return out


func _check_dev_private_calls() -> void:
	var re := RegEx.create_from_string("([A-Za-z0-9_\\)\\]]+)\\._([A-Za-z0-9_]+)\\(")
	var unexpected: Array[String] = []
	for path in _src_files("res://src/dev"):
		var text := FileAccess.get_file_as_string(path)
		for raw_line in text.split("\n"):
			var code := _strip_strings_and_comments(raw_line)
			for m in re.search_all(code):
				var entry := "%s: %s._%s(" % [path, m.get_string(1), m.get_string(2)]
				if not entry in ALLOWED_PRIVATE_CALLS:
					unexpected.append(entry)
	_t.eq("src/dev/ makes no unallowed private ._method( calls", unexpected, [])


func _check_single_owners() -> void:
	var console_src := FileAccess.get_file_as_string("res://src/dev/dev_console.gd")
	var fight_src := FileAccess.get_file_as_string("res://src/dev/dev_fight.gd")
	var overlay_src := FileAccess.get_file_as_string("res://src/dev/dev_overlay.gd")
	var part_src := FileAccess.get_file_as_string("res://src/experimental/part_resource.gd")
	var bridge_src := FileAccess.get_file_as_string("res://src/experimental/live_run_bridge.gd")
	var driver_src := FileAccess.get_file_as_string("res://tools/test_batch_driver.gd")

	_t.check("LENS_RANGES lives on DevLens with distance max 400",
		not console_src.contains("const LENS_RANGES") and console_src.contains("DevLens.LENS_RANGES")
		and DevLens.LENS_RANGES["distance"] == [2.0, 400.0, 0.5], str(DevLens.LENS_RANGES.get("distance")))
	_t.check("dev_console.gd preloads DevInspect and DevAgent without fallback path constants",
		not console_src.contains("INSPECT_PATH") and not console_src.contains("AGENT_PATH")
		and console_src.contains('preload("res://src/dev/dev_inspect.gd")')
		and console_src.contains('preload("res://src/dev/dev_agent.gd")'), "")
	_t.check("dev_fight.gd delegates enemy discovery to Combat without combat table preloads",
		not fight_src.contains("res://src/combat/rogue.gd")
		and not fight_src.contains("res://src/combat/fleet.gd")
		and not fight_src.contains("res://src/combat/roster.gd")
		and fight_src.contains("Combat.spawnable_kinds("), "")
	_t.check("dev_fight.gd uses owner APIs instead of private reach-ins",
		not fight_src.contains("STAGE_ALIASES")
		and not fight_src.contains("defend_hook")
		and not fight_src.contains("parts.clear()")
		and not fight_src.contains("yaw_basis()"), "")
	_t.check("dev_overlay.gd reads DevInspect instead of owning a second perf ring",
		not overlay_src.contains("PERF_FRAMES") and not overlay_src.contains("_frame_ms")
		and overlay_src.contains("DevInspect.PERF_RING_CAP"), "")
	_t.check("part_resource.gd validates makers through MakerSets",
		not part_src.contains("VALID_MAKERS") and part_src.contains("MakerSets.SETS.has("), "")
	_t.check("LiveRunBridge._reset forwarder and driver preload are removed",
		not bridge_src.contains("func _reset(") and not driver_src.contains("live_run_bridge.gd"), "")


func _check_owner_apis() -> void:
	_t.check("Combat.spawnable_kinds(1) includes chaser", "chaser" in Combat.spawnable_kinds(1), "")
	_t.check("Combat.kind_label returns non-empty label", Combat.kind_label("chaser") != "", "")

	var park_aliases := DevFight.stage_aliases(ParkDefs)
	_t.eq("ParkDefs stage aliases cover all six park maps",
		[park_aliases.get("dam"), park_aliases.get("flume"), park_aliases.get("pit"),
		park_aliases.get("sinkhole"), park_aliases.get("islands"), park_aliases.get("crown")],
		[1, 2, 3, 4, 5, 6])
	var alpha_aliases := DevFight.stage_aliases(AlphaDefs)
	_t.eq("AlphaDefs stage aliases cover all six alpha maps",
		[alpha_aliases.get("spillway"), alpha_aliases.get("reach"), alpha_aliases.get("dig"),
		alpha_aliases.get("dig_deep"), alpha_aliases.get("highdraft"), alpha_aliases.get("highdraft_crown")],
		[1, 2, 3, 4, 5, 6])

	var run := RunState.new()
	run.parts = ["hot_rivets", "arc_coil"]
	run.clear_parts()
	_t.eq("RunState.clear_parts empties parts", run.parts, [])
	var hook := func(amount: float, _hp: float) -> float: return amount * 0.5
	run.defend_hook = hook
	run.invulnerable = true
	var hp_before := run.hp
	run.damage(40.0, "guard_test")
	_t.check("RunState.invulnerable blocks damage and preserves defend_hook",
		is_equal_approx(run.hp, hp_before) and run.defend_hook == hook, "")
	run.invulnerable = false

	var flood := Flood.new()
	flood.cycle = FloodCycle.new()
	flood.cycle.phase = FloodCycle.WARNING
	flood.cycle.elapsed = 4.25
	flood.set_phase(FloodCycle.HIGH)
	_t.check("Flood.set_phase updates phase and resets elapsed",
		flood.cycle.phase == FloodCycle.HIGH and is_equal_approx(flood.cycle.elapsed, 0.0), "")
	flood.free()

	var part := PartResource.new()
	part.id = &"probe_part"
	part.display_name = "Probe Part"
	part.effect_id = &"probe_effect"
	part.summary = "s"
	part.trade_off = "t"
	part.visual_tell = "v"
	part.audio_tell = "a"
	for maker in MakerSets.SETS.keys():
		part.maker = StringName(maker)
		_t.eq("PartResource accepts MakerSets maker '%s'" % maker, part.validate(), [])
	part.maker = &"not_a_real_maker"
	_t.check("PartResource rejects unknown maker", not part.validate().is_empty(), "")


func _check_standalone_overlay() -> void:
	var overlay := DevOverlay.new()
	root.add_child(overlay)
	overlay.setup(null, null)
	overlay.set_perf_mode("on")
	for _i in 3:
		await process_frame
	var insp: DevInspect = overlay.get_node_or_null("DevInspect")
	_t.check("standalone DevOverlay mounts DevInspect and fills frame_ms_ring",
		insp != null and insp.frame_ms_ring().size() >= 2 and overlay.perf_visible(),
		"ring=%d" % (insp.frame_ms_ring().size() if insp != null else -1))
	overlay.free()
