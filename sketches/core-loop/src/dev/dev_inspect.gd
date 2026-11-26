extends Node

const DevCommands := preload("res://src/dev/dev_commands.gd")
const AppShell := preload("res://src/core/app_shell.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Relics := preload("res://src/build/relics.gd")

const EVENTS_CAP := 256
const ITEMS_CAP := 128
const TOPICS := ["state", "player", "enemies", "boss", "telegraphs", "build", "look", "lens", "perf", "prims", "ui", "events", "anomalies"]

var game
var console
var recording := false
var _events: Array[Dictionary] = []
var _event_counts := {}
var _connected: Array[Dictionary] = []
var _assertions: Array[Dictionary] = []
var _assert_passed := 0
var _assert_failed := 0


func setup(game_ref, console_ref) -> void:
	game = game_ref
	console = console_ref
	name = "DevInspect"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	_disconnect_events()


func register(commands) -> void:
	commands.add("inspect", "[topic]", "return a structured JSON-safe snapshot of game state", _cmd_inspect)
	commands.add("events", "[on|off|tail [n]|clear]", "record or inspect GameEvents signals", _cmd_events)
	commands.add("assert", "<finite|no_anomalies|state|stage|enemies|hp|draws|event|no_event|expr> ...", "assert an invariant and track pass/fail", _cmd_assert)
	commands.add("anomalies", "", "scan positions and run log for non-finite values or anomalies", func(_args: Array[String]): return _cmd_inspect(["anomalies"]))
	commands.add("perf", "", "show engine performance monitors", func(_args: Array[String]): return _cmd_inspect(["perf"]))
	commands.add("prims", "", "census of visible PrimitiveMesh nodes in the game scene", func(_args: Array[String]): return _cmd_inspect(["prims"]))


func set_recording(on: bool) -> Dictionary:
	if on == recording:
		return {"recording": recording, "count": _events.size()}
	if on:
		_connect_events()
	else:
		_disconnect_events()
	recording = on
	return {"recording": recording, "count": _events.size()}


func clear_events() -> void:
	_events.clear()
	_event_counts.clear()


func recent_events(n := 32) -> Array[Dictionary]:
	n = clampi(n, 1, EVENTS_CAP)
	var start := maxi(0, _events.size() - n)
	var out: Array[Dictionary] = []
	for i in range(start, _events.size()):
		out.append(_events[i].duplicate(true))
	return out


func event_count(sig_name: String) -> int:
	return int(_event_counts.get(sig_name, 0))


func reset_assertions() -> void:
	_assertions.clear()
	_assert_passed = 0
	_assert_failed = 0


func assertion_summary() -> Dictionary:
	return {"passed": _assert_passed, "failed": _assert_failed, "rows": _assertions.duplicate(true)}


func snapshot(topic := "all") -> Dictionary:
	var key := topic.strip_edges().to_lower()
	if key == "" or key == "all":
		var all_data := {}
		for t in TOPICS:
			all_data[t] = _topic_data(t)
		return all_data
	if not key in TOPICS:
		return {}
	var val: Variant = _topic_data(key)
	if val is Dictionary:
		return val
	if val is Array:
		return {"count": val.size(), "items": val}
	return {"value": val}


func _topic_data(topic: String) -> Variant:
	match topic:
		"state":
			return _snap_state()
		"player":
			return _snap_player()
		"enemies":
			return _snap_enemies()
		"boss":
			return _snap_boss()
		"telegraphs":
			return _snap_telegraphs()
		"build":
			return _snap_build()
		"look":
			return _snap_look()
		"lens":
			return _snap_lens()
		"perf":
			return _snap_perf()
		"prims":
			return _snap_prims()
		"ui":
			return _snap_ui()
		"events":
			return _snap_events()
		"anomalies":
			return _snap_anomalies()
	return null


func _snap_state() -> Dictionary:
	var map_name := ""
	if is_instance_valid(game) and game.flow != null and game.ctx != null and game.run != null and game.ctx.stages != null:
		var def: Dictionary = game.flow.stage_def()
		map_name = String(def.get("map", ""))
	return {
		"flow": game.flow.state_name() if is_instance_valid(game) and game.flow != null else "",
		"stage": int(game.run.stage) if is_instance_valid(game) and game.run != null else 0,
		"world": int(game.run.world) if is_instance_valid(game) and game.run != null else 0,
		"map": map_name,
		"paused": get_tree().paused if is_inside_tree() else false,
		"pause_wanted": game.pause_wanted() if is_instance_valid(game) and game.has_method("pause_wanted") else false,
		"time_scale": Engine.time_scale,
		"calm": bool(game.ctx.calm) if is_instance_valid(game) and game.ctx != null else false,
		"god": bool(console.fight.god) if is_instance_valid(console) and console.fight != null else false,
		"ticks": Engine.get_physics_frames(),
		"run_time": _safe_float(float(game.run.run_time)) if is_instance_valid(game) and game.run != null else 0.0,
		"headless": AppShell.headless(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"audio_driver": AudioServer.get_driver_name(),
	}


func _snap_player() -> Dictionary:
	if not is_instance_valid(game) or game.player == null:
		return {}
	var p = game.player
	var ball_pos: Vector3 = p.ball_position()
	var shown_pos: Vector3 = p.shown_position()
	var vel: Vector3 = p.state.velocity if p.state != null else Vector3.ZERO
	var aim_state := ""
	if p.kit != null and p.kit.aim is Dictionary:
		aim_state = str(p.kit.aim.get("state", ""))
	var run = game.run
	return {
		"pos": _vec3(ball_pos),
		"shown_pos": _vec3(shown_pos),
		"vel": _vec3(vel),
		"speed": _safe_float(vel.length()),
		"speed_tier": int(p.speed_tier()) if p.has_method("speed_tier") else 0,
		"hp": _safe_float(float(run.hp)) if run != null else 0.0,
		"max_hp": _safe_float(float(run.max_hp)) if run != null else 0.0,
		"scrap": int(run.scrap) if run != null else 0,
		"cogs": int(run.cogs) if run != null else 0,
		"mass": _safe_float(float(run.mass)) if run != null else 0.0,
		"heft": _safe_float(float(run.heft())) if run != null else 0.0,
		"heft_class": int(run.heft_class()) if run != null else 1,
		"pilot": String(run.class_id()) if run != null else "",
		"kit_aim_state": aim_state,
	}


func _snap_enemies() -> Array:
	var out: Array = []
	if not is_inside_tree() or not is_instance_valid(game):
		return out
	var ball_pos: Vector3 = game.player.ball_position() if game.player != null else Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var pos: Vector3 = e.global_position if e is Node3D else Vector3.ZERO
		var affix := ""
		if "spec" in e and e.spec is Dictionary and e.spec.has("affix"):
			affix = String(e.spec.get("affix", ""))
		elif "affix" in e:
			affix = String(e.get("affix"))
		out.append({
			"kind": String(e.kind) if "kind" in e else String(e.name),
			"pos": _vec3(pos),
			"dist": _safe_float(pos.distance_to(ball_pos)) if pos.is_finite() and ball_pos.is_finite() else null,
			"hp": _safe_float(float(e.hp)) if "hp" in e else 0.0,
			"max_hp": _safe_float(float(e.max_hp)) if "max_hp" in e else 0.0,
			"plating": _safe_float(float(e.plating)) if "plating" in e else 0.0,
			"affix": affix,
		})
	return out


func _snap_boss() -> Dictionary:
	if not is_instance_valid(game) or game.ctx == null:
		return {"active": false, "state": "idle", "phase": 0, "posture": 0.0, "staggered": false, "chunks_left": 0, "hazards": 0, "floor_y": null}
	var b = game.ctx.boss if "boss" in game.ctx else null
	var active: bool = (game.flow != null and bool(game.flow.boss_active)) or (b != null and b.has_method("active") and bool(b.active()))
	var floor_y: Variant = null
	if b != null and b.has_method("floor_y"):
		floor_y = _safe_float(float(b.floor_y()))
	return {
		"active": active,
		"state": String(b.state_name()) if b != null and b.has_method("state_name") else "idle",
		"phase": int(b.phase) if b != null and "phase" in b else 0,
		"posture": _safe_float(float(b.posture())) if b != null and b.has_method("posture") else 0.0,
		"staggered": bool(b.staggered()) if b != null and b.has_method("staggered") else false,
		"chunks_left": int(b.chunks_left()) if b != null and b.has_method("chunks_left") else 0,
		"hazards": b.hazards.size() if b != null and "hazards" in b and b.hazards is Array else 0,
		"floor_y": floor_y,
	}


func _snap_telegraphs() -> Array:
	var out: Array = []
	if not is_inside_tree() or not is_instance_valid(game):
		return out
	var ball_pos: Vector3 = game.player.ball_position() if game.player != null else Vector3.ZERO
	var seen := {}
	var nodes: Array = get_tree().get_nodes_in_group("telegraph")
	if Threat.GROUP != "telegraph":
		nodes = nodes + get_tree().get_nodes_in_group(Threat.GROUP)
	for node in nodes:
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var iid: int = node.get_instance_id()
		if seen.has(iid):
			continue
		seen[iid] = true
		var desc: Dictionary = _jsonify(node.descriptor()) if node.has_method("descriptor") else {}
		desc["name"] = String(node.name)
		if node.has_method("contains") and ball_pos.is_finite():
			desc["contains_ball"] = bool(node.contains(ball_pos))
		out.append(desc)
	return out


func _snap_build() -> Dictionary:
	if not is_instance_valid(game) or game.run == null or game.build == null:
		return {}
	return {
		"parts": Array(game.run.parts.duplicate()),
		"panel_counts": _jsonify(game.run.panel_counts()),
		"relics": _jsonify(Relics.held(game.run.parts)),
		"synergies": _jsonify(game.build.active_synergies()),
		"punch": _safe_float(float(game.build.punch_bonus())),
		"power": _safe_float(float(game.build.power())),
		"shot_bits": int(game.build.shot_bits()),
	}


func _snap_look() -> Dictionary:
	if not is_instance_valid(console) or console.look == null:
		return {}
	var snap: Dictionary = _jsonify(console.look.snapshot())
	snap["passes_live"] = _jsonify(console.look.passes_live())
	return snap


func _snap_lens() -> Dictionary:
	if not is_instance_valid(console) or console.lens == null:
		return {}
	var l = console.lens
	return {
		"mode": String(l.mode),
		"ortho": bool(l.ortho),
		"fov": _safe_float(float(l.fov)),
		"distance": _safe_float(float(l.distance)),
		"pitch": _safe_float(float(l.pitch)),
		"yaw": _safe_float(float(l.yaw)),
		"size": _safe_float(float(l.ortho_size)),
		"lift": _safe_float(float(l.lift)),
		"spin": _safe_float(float(l.spin)),
		"tilt": _safe_float(float(l.tilt_shift)),
		"cut": _safe_float(float(l.cutaway)),
	}


func _snap_perf() -> Dictionary:
	return {
		"fps": _safe_float(Performance.get_monitor(Performance.TIME_FPS)),
		"process_ms": _safe_float(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
		"physics_ms": _safe_float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"static_mem_mb": _safe_float(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		"emitting_particles": _count_emitting_particles(),
	}


func _count_emitting_particles() -> int:
	if not is_instance_valid(game):
		return 0
	var count := 0
	for node in game.find_children("*", "GPUParticles3D", true, false):
		if node.emitting:
			count += 1
	for node in game.find_children("*", "CPUParticles3D", true, false):
		if node.emitting:
			count += 1
	return count


func _snap_prims() -> Dictionary:
	var items: Array = []
	var count := 0
	if not is_instance_valid(game):
		return {"count": 0, "items": items}
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or not mi.is_visible_in_tree() or not (mi.mesh is PrimitiveMesh):
			continue
		if is_instance_valid(console) and (mi == console or console.is_ancestor_of(mi)):
			continue
		count += 1
		if items.size() < ITEMS_CAP:
			items.append({
				"name": String(mi.name),
				"path": String(game.get_path_to(mi)),
				"mesh_class": String(mi.mesh.get_class()),
			})
	return {"count": count, "items": items}


func _snap_ui() -> Array:
	var items: Array = []
	if not is_instance_valid(game):
		return items
	for node in game.find_children("*", "Control", true, false):
		var ctrl := node as Control
		if ctrl == null or not ctrl.is_visible_in_tree():
			continue
		if is_instance_valid(console) and (ctrl == console or console.is_ancestor_of(ctrl)):
			continue
		var text_val := ""
		if "text" in ctrl:
			text_val = String(ctrl.get("text"))
		var is_interactive := ctrl is Button or ctrl is LineEdit or ctrl is Slider or ctrl is CheckBox
		if text_val.is_empty() and not is_interactive:
			continue
		if items.size() >= ITEMS_CAP:
			break
		var rect := ctrl.get_global_rect()
		var script_res = ctrl.get_script()
		items.append({
			"name": String(ctrl.name),
			"class": String(ctrl.get_class()),
			"script": String(script_res.resource_path) if script_res is Script else "",
			"text": text_val,
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		})
	return items


func _snap_events() -> Dictionary:
	return {
		"recording": recording,
		"count": _events.size(),
		"counts": _event_counts.duplicate(),
		"items": recent_events(32),
	}


func _snap_anomalies() -> Dictionary:
	var items: Array = []
	if is_instance_valid(game) and game.player != null:
		if not game.player.ball_position().is_finite():
			items.append({"kind": "non_finite", "who": "player.ball_position"})
		if not game.player.shown_position().is_finite():
			items.append({"kind": "non_finite", "who": "player.shown_position"})
		if game.player.state != null and not game.player.state.velocity.is_finite():
			items.append({"kind": "non_finite", "who": "player.velocity"})
	if is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		if is_instance_valid(cam) and not cam.global_position.is_finite():
			items.append({"kind": "non_finite", "who": "camera.global_position"})
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and not e.is_queued_for_deletion() and e is Node3D and not e.global_position.is_finite():
				items.append({"kind": "non_finite", "who": "enemy:%s" % String(e.kind if "kind" in e else e.name)})
		var seen := {}
		var teles: Array = get_tree().get_nodes_in_group("telegraph")
		if Threat.GROUP != "telegraph":
			teles = teles + get_tree().get_nodes_in_group(Threat.GROUP)
		for t in teles:
			if not is_instance_valid(t) or t.is_queued_for_deletion() or seen.has(t.get_instance_id()):
				continue
			seen[t.get_instance_id()] = true
			if t is Node3D and not t.global_position.is_finite():
				items.append({"kind": "non_finite", "who": "telegraph:%s" % String(t.name)})
	if is_instance_valid(game) and game.run != null:
		for entry in game.run.anomalies:
			items.append(_jsonify(entry))
	return {"count": items.size(), "items": items}


func _cmd_inspect(args: Array[String]):
	var topic := DevCommands.word(args, 0, "all").to_lower()
	if topic != "all" and not topic in TOPICS:
		return {"ok": false, "text": "!unknown inspect topic '%s' (%s)" % [topic, ", ".join(TOPICS)], "data": null}
	var data: Variant = snapshot("all") if topic == "all" else _topic_data(topic)
	return {"ok": true, "text": _summarize(topic, data), "data": data}


func _cmd_events(args: Array[String]):
	var sub := DevCommands.word(args, 0, "tail").to_lower()
	if sub == "on":
		var info := set_recording(true)
		return {"ok": true, "text": "events recording on (%d buffered)" % info.count, "data": info}
	if sub == "off":
		var info := set_recording(false)
		return {"ok": true, "text": "events recording off (%d buffered)" % info.count, "data": info}
	if sub == "clear":
		clear_events()
		return {"ok": true, "text": "events cleared", "data": {"recording": recording, "count": 0}}
	if sub == "tail":
		var n := DevCommands.whole(args, 1, 16)
		var items := recent_events(n)
		return {"ok": true, "text": "events tail %d/%d (recording=%s)" % [items.size(), _events.size(), str(recording)],
			"data": {"recording": recording, "count": _events.size(), "items": items}}
	return "!events [on|off|tail [n]|clear]"


func _cmd_assert(args: Array[String]):
	return assert_check(args)


func assert_check(args: Array[String]) -> Dictionary:
	if args.is_empty():
		return _record_assert("assert", false, "missing check name")
	var kind := args[0].to_lower()
	var desc := " ".join(args)
	match kind:
		"finite":
			var anoms: Dictionary = _snap_anomalies()
			var bad: Array = anoms.items.filter(func(x): return x is Dictionary and String(x.get("kind", "")) == "non_finite")
			return _record_assert(desc, bad.is_empty(), "" if bad.is_empty() else str(bad))
		"no_anomalies":
			var anoms: Dictionary = _snap_anomalies()
			return _record_assert(desc, int(anoms.count) == 0, "" if int(anoms.count) == 0 else "%d anomalies" % int(anoms.count))
		"state":
			if args.size() < 2:
				return _record_assert(desc, false, "usage: assert state <name>")
			var actual: String = game.flow.state_name() if is_instance_valid(game) and game.flow != null else ""
			var want := args[1].to_lower()
			return _record_assert(desc, actual == want, "actual=%s want=%s" % [actual, want])
		"stage":
			if args.size() < 2 or not args[1].is_valid_int():
				return _record_assert(desc, false, "usage: assert stage <n>")
			var actual := int(game.run.stage) if is_instance_valid(game) and game.run != null else 0
			var want := args[1].to_int()
			return _record_assert(desc, actual == want, "actual=%d want=%d" % [actual, want])
		"enemies":
			var actual := float(_snap_enemies().size())
			return _eval_cmp(desc, actual, args.slice(1), "assert enemies <op|N> [N]")
		"hp":
			var actual := float(game.run.hp) if is_instance_valid(game) and game.run != null else 0.0
			return _eval_cmp(desc, actual, args.slice(1), "assert hp <op> <n>")
		"draws":
			var actual := float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			return _eval_cmp(desc, actual, args.slice(1), "assert draws <op> <n>")
		"event":
			if args.size() < 2:
				return _record_assert(desc, false, "usage: assert event <signal> [min_count]")
			var sig := args[1]
			var min_c := DevCommands.whole(args, 2, 1)
			var got := event_count(sig)
			return _record_assert(desc, got >= min_c, "signal=%s count=%d min=%d" % [sig, got, min_c])
		"no_event":
			if args.size() < 2:
				return _record_assert(desc, false, "usage: assert no_event <signal>")
			var sig := args[1]
			var got := event_count(sig)
			return _record_assert(desc, got == 0, "signal=%s count=%d" % [sig, got])
		"expr":
			if args.size() < 2:
				return _record_assert(desc, false, "usage: assert expr <godot_expr>")
			var src := " ".join(args.slice(1))
			var expr := Expression.new()
			var perr := expr.parse(src)
			if perr != OK:
				return _record_assert(desc, false, "parse error: %s" % expr.get_error_text())
			var val = expr.execute([], game)
			if expr.has_execute_failed():
				return _record_assert(desc, false, "execute error: %s" % expr.get_error_text())
			return _record_assert(desc, bool(val), "result=%s" % str(val))
	return _record_assert(desc, false, "unknown assert kind '%s'" % kind)


func _eval_cmp(desc: String, actual: float, tail: Array[String], usage_hint: String) -> Dictionary:
	if tail.is_empty():
		return _record_assert(desc, false, "usage: %s" % usage_hint)
	var op := "eq"
	var raw_num := ""
	if tail.size() == 1:
		raw_num = tail[0]
	else:
		op = tail[0].to_lower()
		raw_num = tail[1]
	if not raw_num.is_valid_float():
		return _record_assert(desc, false, "expected number, got '%s'" % raw_num)
	var want := raw_num.to_float()
	var ok := compare_number(actual, op, want)
	if not is_valid_op(op):
		return _record_assert(desc, false, "unknown comparator '%s'" % op)
	return _record_assert(desc, ok, "actual=%s %s %s" % [str(actual), op, str(want)])


static func is_valid_op(op: String) -> bool:
	return op in ["eq", "==", "ne", "!=", "gt", ">", "gte", ">=", "lt", "<", "lte", "<="]


static func compare_number(actual: float, op: String, want: float) -> bool:
	match op:
		"eq", "==":
			return is_equal_approx(actual, want)
		"ne", "!=":
			return not is_equal_approx(actual, want)
		"gt", ">":
			return actual > want
		"gte", ">=":
			return actual >= want or is_equal_approx(actual, want)
		"lt", "<":
			return actual < want
		"lte", "<=":
			return actual <= want or is_equal_approx(actual, want)
	return false


func _record_assert(desc: String, ok: bool, detail: String) -> Dictionary:
	var row := {"check": desc, "ok": ok, "detail": detail}
	_assertions.append(row)
	if ok:
		_assert_passed += 1
	else:
		_assert_failed += 1
	var text := ("assert pass: %s" % desc) if ok else ("!assert fail: %s (%s)" % [desc, detail])
	return {"ok": ok, "text": text, "data": row}


func _connect_events() -> void:
	_disconnect_events()
	if not is_instance_valid(game) or game.events == null:
		return
	var ev: Object = game.events
	var allowed := {}
	var script_res = ev.get_script()
	if script_res is Script:
		for info in script_res.get_script_signal_list():
			allowed[String(info["name"])] = true
	if ev.has_signal("consumable_used"):
		allowed["consumable_used"] = true
	for info in ev.get_signal_list():
		var sig_name := String(info["name"])
		if not allowed.has(sig_name):
			continue
		var argc := (info["args"] as Array).size()
		var cb := _listener_for(sig_name, argc)
		if cb.is_valid() and not ev.is_connected(sig_name, cb):
			ev.connect(sig_name, cb)
			_connected.append({"name": sig_name, "cb": cb})


func _disconnect_events() -> void:
	if is_instance_valid(game) and is_instance_valid(game.events):
		for entry in _connected:
			if game.events.is_connected(entry["name"], entry["cb"]):
				game.events.disconnect(entry["name"], entry["cb"])
	_connected.clear()


func _listener_for(sig_name: String, argc: int) -> Callable:
	match argc:
		0:
			return _on_ev_0.bind(sig_name)
		1:
			return _on_ev_1.bind(sig_name)
		2:
			return _on_ev_2.bind(sig_name)
		3:
			return _on_ev_3.bind(sig_name)
		4:
			return _on_ev_4.bind(sig_name)
		5:
			return _on_ev_5.bind(sig_name)
		6:
			return _on_ev_6.bind(sig_name)
	return Callable()


func _on_ev_0(sig_name: String) -> void:
	_push_event(sig_name, [])


func _on_ev_1(a, sig_name: String) -> void:
	_push_event(sig_name, [a])


func _on_ev_2(a, b, sig_name: String) -> void:
	_push_event(sig_name, [a, b])


func _on_ev_3(a, b, c, sig_name: String) -> void:
	_push_event(sig_name, [a, b, c])


func _on_ev_4(a, b, c, d, sig_name: String) -> void:
	_push_event(sig_name, [a, b, c, d])


func _on_ev_5(a, b, c, d, e, sig_name: String) -> void:
	_push_event(sig_name, [a, b, c, d, e])


func _on_ev_6(a, b, c, d, e, f, sig_name: String) -> void:
	_push_event(sig_name, [a, b, c, d, e, f])


func _push_event(sig_name: String, raw_args: Array) -> void:
	_event_counts[sig_name] = int(_event_counts.get(sig_name, 0)) + 1
	_events.append({
		"tick": Engine.get_physics_frames(),
		"signal": sig_name,
		"args": _jsonify(raw_args),
	})
	while _events.size() > EVENTS_CAP:
		_events.pop_front()


static func _summarize(topic: String, data: Variant) -> String:
	match topic:
		"state":
			if data is Dictionary:
				return "state %s stage=%s map=%s paused=%s" % [data.get("flow", ""), str(data.get("stage", 0)), data.get("map", ""), str(data.get("paused", false))]
		"player":
			if data is Dictionary and not data.is_empty():
				return "player %s hp=%.0f/%.0f speed=%.1f heft=%.2f" % [data.get("pilot", ""), float(data.get("hp", 0.0)), float(data.get("max_hp", 0.0)), float(data.get("speed", 0.0)), float(data.get("heft", 0.0))]
		"enemies":
			if data is Array:
				return "enemies: %d" % data.size()
		"boss":
			if data is Dictionary:
				return "boss active=%s state=%s phase=%d chunks=%d" % [str(data.get("active", false)), data.get("state", ""), int(data.get("phase", 0)), int(data.get("chunks_left", 0))]
		"telegraphs":
			if data is Array:
				return "telegraphs: %d" % data.size()
		"perf":
			if data is Dictionary:
				return "perf fps=%.1f draws=%d objects=%d mem=%.1fMB" % [float(data.get("fps", 0.0)), int(data.get("draws", 0)), int(data.get("objects", 0)), float(data.get("static_mem_mb", 0.0))]
		"prims":
			if data is Dictionary:
				return "prims: %d" % int(data.get("count", 0))
		"anomalies":
			if data is Dictionary:
				return "anomalies: %d" % int(data.get("count", 0))
		"ui":
			if data is Array:
				return "ui controls: %d" % data.size()
		"events":
			if data is Dictionary:
				return "events: %d (recording=%s)" % [int(data.get("count", 0)), str(data.get("recording", false))]
	return "inspect %s ok" % topic


static func _safe_float(v: float) -> Variant:
	return v if is_finite(v) else null


static func _vec3(v: Vector3) -> Array:
	return [_safe_float(v.x), _safe_float(v.y), _safe_float(v.z)]


static func _jsonify(value: Variant, depth := 0) -> Variant:
	if depth > 6 or value == null:
		return null
	match typeof(value):
		TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			return _safe_float(float(value))
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return String(value)
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return [_safe_float(v2.x), _safe_float(v2.y)]
		TYPE_VECTOR3:
			return _vec3(value as Vector3)
		TYPE_COLOR:
			return "#" + (value as Color).to_html(false)
		TYPE_RECT2:
			var r: Rect2 = value
			return [_safe_float(r.position.x), _safe_float(r.position.y), _safe_float(r.size.x), _safe_float(r.size.y)]
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_jsonify(item, depth + 1))
			return arr
		TYPE_DICTIONARY:
			var out := {}
			for k in value:
				out[str(k)] = _jsonify(value[k], depth + 1)
			return out
		TYPE_OBJECT:
			if not is_instance_valid(value):
				return null
			if value is Node:
				return String((value as Node).name)
			return String(value.get_class())
	return str(value)
