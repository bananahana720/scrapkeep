extends Node

const SafeStore := preload("res://src/core/safe_store.gd")
const DevCommands := preload("res://src/dev/dev_commands.gd")
const DevInspect := preload("res://src/dev/dev_inspect.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const DEFAULT_IDLE_S := 180.0
const DEFAULT_UNTIL_FRAMES := 300
const MAX_WAIT_FRAMES := 3600

var game
var console
var out_dir := ""
var inbox_dir := ""
var idle_limit_s := DEFAULT_IDLE_S
var _batch_steps: Array[String] = []
var _mailbox_active := false
var _mailbox_busy := false
var _idle_s := 0.0
var _quitting := false


func setup(game_ref, console_ref) -> void:
	game = game_ref
	console = console_ref
	name = "DevAgent"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args(OS.get_cmdline_user_args())
	if out_dir != "" and is_instance_valid(console) and "shot_dir" in console:
		console.shot_dir = out_dir
	if inbox_dir != "" or not _batch_steps.is_empty():
		var insp := _inspect()
		if insp != null:
			insp.set_recording(true)
	if inbox_dir != "":
		_start_mailbox()
	elif not _batch_steps.is_empty():
		if out_dir == "":
			out_dir = "user://dev_out"
			if is_instance_valid(console) and "shot_dir" in console:
				console.shot_dir = out_dir
		_run_batch.call_deferred()


func _exit_tree() -> void:
	_cleanup_ready()


func _parse_args(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--dev-out="):
			out_dir = arg.trim_prefix("--dev-out=").strip_edges()
		elif arg.begins_with("--dev-run="):
			_append_steps(arg.trim_prefix("--dev-run="))
		elif arg.begins_with("--dev-file="):
			_load_steps_file(arg.trim_prefix("--dev-file=").strip_edges())
		elif arg.begins_with("--dev-inbox="):
			inbox_dir = arg.trim_prefix("--dev-inbox=").strip_edges()
		elif arg.begins_with("--dev-idle="):
			var raw := arg.trim_prefix("--dev-idle=").strip_edges()
			if raw.is_valid_float():
				idle_limit_s = maxf(0.0, raw.to_float())


func _append_steps(script: String) -> void:
	for part in script.split(";", false):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			_batch_steps.append(trimmed)


func _load_steps_file(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		push_warning("DevAgent: --dev-file not found: %s" % path)
		return
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		var clean := line.strip_edges()
		if clean.is_empty() or clean.begins_with("#"):
			continue
		_append_steps(clean)


func active() -> bool:
	return _mailbox_active or not _batch_steps.is_empty()


func run_scenario(steps: Array, options := {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var insp := _inspect()
	if insp != null and bool(options.get("reset_assertions", true)):
		insp.reset_assertions()
	var scripted := bool(options.get("scripted", true))
	var expanded: Array[String] = []
	for s in steps:
		for part in String(s).split(";", false):
			var trimmed := part.strip_edges()
			if not trimmed.is_empty() and not trimmed.begins_with("#"):
				expanded.append(trimmed)
	var step_rows: Array = []
	var shots: Array = []
	var passed := 0
	var failed := 0
	var idx := 0
	for step in expanded:
		if not is_inside_tree():
			break
		var step_t0 := Time.get_ticks_usec()
		var res: Dictionary = await _exec_step(step, scripted, shots)
		var step_ms := snappedf((Time.get_ticks_usec() - step_t0) / 1000.0, 0.001)
		var ok := bool(res.get("ok", false))
		if ok:
			passed += 1
		else:
			failed += 1
		var run_time := float(game.run.run_time) if is_instance_valid(game) and game.run != null else 0.0
		step_rows.append({
			"index": idx,
			"cmd": String(res.get("cmd", step)),
			"ok": ok,
			"text": String(res.get("text", "")),
			"tone": String(res.get("tone", "ok" if ok else "warn")),
			"data": res.get("data", null),
			"ms": step_ms,
			"frame": Engine.get_physics_frames(),
			"run_time": run_time,
		})
		idx += 1
		if bool(res.get("quit", false)):
			break
	var assertions: Dictionary = insp.assertion_summary() if insp != null else {"passed": 0, "failed": 0, "rows": []}
	var anomalies: Dictionary = insp.snapshot("anomalies") if insp != null else {"count": 0, "items": []}
	var state_snap: Dictionary = insp.snapshot("state") if insp != null else {}
	var dead_shot := shots.any(func(s): return s is Dictionary and bool(s.get("dead_frame", false)))
	var all_ok := failed == 0 and int(assertions.get("failed", 0)) == 0 and not dead_shot
	var elapsed_ms := snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.001)
	var receipt := {
		"ok": all_ok,
		"steps_total": step_rows.size(),
		"steps_passed": passed,
		"steps_failed": failed,
		"steps": step_rows,
		"assertions": assertions,
		"shots": shots,
		"anomalies": anomalies,
		"state": state_snap,
		"renderer": RenderingServer.get_current_rendering_method(),
		"headless": AppShell.headless(),
		"audio_driver": AudioServer.get_driver_name(),
		"ms": elapsed_ms,
		"elapsed_ms": elapsed_ms,
	}
	var target_out := String(options.get("out", ""))
	if not target_out.is_empty():
		var written := _write_artifacts(target_out, step_rows, receipt)
		receipt["receipt_path"] = written["receipt_path"]
		receipt["steps_path"] = written["steps_path"]
	return receipt


func _run_batch() -> void:
	var steps := _batch_steps.duplicate()
	_batch_steps.clear()
	var receipt: Dictionary = await run_scenario(steps, {"out": out_dir, "scripted": true, "reset_assertions": true})
	var receipt_path := String(receipt.get("receipt_path", ""))
	if not receipt_path.is_empty():
		print("DEV_RECEIPT %s" % receipt_path)
	if is_inside_tree():
		get_tree().quit(0 if bool(receipt.get("ok", false)) else 1)


func _start_mailbox() -> void:
	var base := ProjectSettings.globalize_path(inbox_dir)
	DirAccess.make_dir_recursive_absolute(base)
	DirAccess.make_dir_recursive_absolute(base.path_join("in"))
	DirAccess.make_dir_recursive_absolute(base.path_join("out"))
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var ready_doc := {
		"pid": OS.get_process_id(),
		"ready": true,
		"inbox": base,
		"out": ProjectSettings.globalize_path(out_dir) if out_dir != "" else base.path_join("out"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"headless": AppShell.headless(),
		"audio_driver": AudioServer.get_driver_name(),
	}
	var err := SafeStore.write_atomic(base.path_join("ready.json"), JSON.stringify(ready_doc, "\t") + "\n")
	if err != OK:
		push_warning("DevAgent: could not write ready.json (%d)" % err)
		return
	_mailbox_active = true
	_idle_s = 0.0


func _cleanup_ready() -> void:
	if not _mailbox_active or inbox_dir == "":
		return
	var ready_path := ProjectSettings.globalize_path(inbox_dir).path_join("ready.json")
	if FileAccess.file_exists(ready_path):
		DirAccess.remove_absolute(ready_path)
	_mailbox_active = false


func _process(delta: float) -> void:
	if not _mailbox_active or _quitting:
		return
	_idle_s += delta / maxf(Engine.time_scale, 0.05)
	if idle_limit_s > 0.0 and _idle_s >= idle_limit_s and not _mailbox_busy:
		_quitting = true
		_cleanup_ready()
		if is_inside_tree():
			get_tree().quit(0)
		return
	if _mailbox_busy:
		return
	var in_dir := ProjectSettings.globalize_path(inbox_dir).path_join("in")
	var files := Array(DirAccess.get_files_at(in_dir)).filter(func(f: String): return f.ends_with(".req.json"))
	if files.is_empty():
		return
	files.sort()
	_handle_mailbox_request(in_dir.path_join(String(files[0])))


func _handle_mailbox_request(req_path: String) -> void:
	_mailbox_busy = true
	_idle_s = 0.0
	var t0 := Time.get_ticks_usec()
	var raw := FileAccess.get_file_as_string(req_path) if FileAccess.file_exists(req_path) else ""
	DirAccess.remove_absolute(req_path)
	var parsed = SafeStore.parse(raw, TYPE_DICTIONARY)
	var req_id := String(parsed.get("id", req_path.get_file().trim_suffix(".req.json"))) if parsed is Dictionary else req_path.get_file().trim_suffix(".req.json")
	var cmd := String(parsed.get("cmd", "")) if parsed is Dictionary else ""
	var results: Array = []
	var texts: Array[String] = []
	var shots: Array = []
	var all_ok := parsed is Dictionary
	var want_quit := false
	if not all_ok:
		var err_text := "!invalid request JSON"
		results.append({"cmd": "", "ok": false, "text": err_text, "data": null, "tone": "warn"})
		texts.append(err_text)
	else:
		for part in cmd.split(";", false):
			var step := part.strip_edges()
			if step.is_empty() or step.begins_with("#"):
				continue
			var res: Dictionary = await _exec_step(step, true, shots)
			var ok := bool(res.get("ok", false))
			if not ok:
				all_ok = false
			var text := String(res.get("text", ""))
			if not text.is_empty():
				texts.append(text)
			results.append({
				"cmd": String(res.get("cmd", step)),
				"ok": ok,
				"text": text,
				"data": res.get("data", null),
				"tone": String(res.get("tone", "ok" if ok else "warn")),
			})
			if bool(res.get("quit", false)):
				want_quit = true
				break
	var response := {
		"id": req_id,
		"ok": all_ok,
		"results": results,
		"shots": shots,
		"text": "\n".join(texts),
		"ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.001),
		"quitting": want_quit,
	}
	var out_path := ProjectSettings.globalize_path(inbox_dir).path_join("out").path_join("%s.res.json" % req_id)
	SafeStore.write_atomic(out_path, JSON.stringify(response) + "\n")
	_idle_s = 0.0
	_mailbox_busy = false
	if want_quit:
		_quitting = true
		if is_inside_tree():
			await get_tree().process_frame
		_cleanup_ready()
		if is_inside_tree():
			get_tree().quit(0)


func _exec_step(step: String, scripted: bool, shots: Array) -> Dictionary:
	var words := _split_words(step)
	if words.is_empty():
		return {"cmd": "", "ok": true, "text": "", "tone": "ok", "data": null}
	var head := words[0].to_lower()
	match head:
		"wait":
			var frames := clampi(DevCommands.whole(words, 1, 1), 1, MAX_WAIT_FRAMES)
			for i in frames:
				if not is_inside_tree():
					return {"cmd": step, "ok": false, "text": "!tree exited during wait", "tone": "warn", "data": {"frames": i}}
				await get_tree().process_frame
			return {"cmd": step, "ok": true, "text": "waited %d frames" % frames, "tone": "ok", "data": {"frames": frames}}
		"tick":
			if not is_instance_valid(console) or console.fight == null:
				return {"cmd": step, "ok": false, "text": "!no fight module", "tone": "warn", "data": null}
			var n := DevCommands.whole(words, 1, 1)
			var res: Dictionary = await console.fight.step_physics(n)
			var ok := bool(res.get("ok", false))
			return {"cmd": step, "ok": ok, "text": String(res.get("text", "")), "tone": "ok" if ok else "warn", "data": res.get("data", null)}
		"until":
			return await _exec_until(step, words)
		"shot":
			return await _exec_shot(step, DevCommands.word(words, 1, ""), scripted, shots)
		"sheet":
			return await _exec_sheet(step, words, scripted, shots)
		"quit":
			return {"cmd": step, "ok": true, "text": "quitting", "tone": "ok", "data": {"quitting": true}, "quit": true}
	var out: Dictionary = console.commands.run_one_detailed(step)
	if is_instance_valid(console) and console.has_method("_refresh_rows"):
		console._refresh_rows()
	return out


func _exec_until(step: String, words: Array[String]) -> Dictionary:
	if words.size() < 2:
		return {"cmd": step, "ok": false, "text": "!until <state|play|enemies|event> <val> [max_frames]", "tone": "warn", "data": null}
	var kind := words[1].to_lower()
	var max_frames := DEFAULT_UNTIL_FRAMES
	if kind == "play":
		max_frames = clampi(DevCommands.whole(words, 2, DEFAULT_UNTIL_FRAMES), 1, MAX_WAIT_FRAMES)
		for f in max_frames + 1:
			if is_instance_valid(game) and game.flow != null and game.flow.in_play():
				return {"cmd": step, "ok": true, "text": "in play after %d frames" % f, "tone": "ok", "data": {"frames": f, "state": game.flow.state_name()}}
			if f < max_frames and is_inside_tree():
				await get_tree().process_frame
		return {"cmd": step, "ok": false, "text": "!until play timed out after %d frames" % max_frames, "tone": "warn", "data": {"frames": max_frames}}
	if words.size() < 3:
		return {"cmd": step, "ok": false, "text": "!until %s <value> [max_frames]" % kind, "tone": "warn", "data": null}
	match kind:
		"state":
			var want := words[2].to_lower()
			max_frames = clampi(DevCommands.whole(words, 3, DEFAULT_UNTIL_FRAMES), 1, MAX_WAIT_FRAMES)
			for f in max_frames + 1:
				var cur: String = game.flow.state_name() if is_instance_valid(game) and game.flow != null else ""
				if cur == want:
					return {"cmd": step, "ok": true, "text": "reached state %s after %d frames" % [want, f], "tone": "ok", "data": {"frames": f, "state": cur}}
				if f < max_frames and is_inside_tree():
					await get_tree().process_frame
			return {"cmd": step, "ok": false, "text": "!until state %s timed out after %d frames" % [want, max_frames], "tone": "warn", "data": {"frames": max_frames}}
		"enemies":
			var op := "eq"
			var want_n := 0
			if words.size() >= 4 and DevInspect.is_valid_op(words[2].to_lower()) and words[3].is_valid_int():
				op = words[2].to_lower()
				want_n = words[3].to_int()
				max_frames = clampi(DevCommands.whole(words, 4, DEFAULT_UNTIL_FRAMES), 1, MAX_WAIT_FRAMES)
			elif words[2].is_valid_int():
				want_n = words[2].to_int()
				max_frames = clampi(DevCommands.whole(words, 3, DEFAULT_UNTIL_FRAMES), 1, MAX_WAIT_FRAMES)
			else:
				return {"cmd": step, "ok": false, "text": "!until enemies <op|N> [N] [max_frames]", "tone": "warn", "data": null}
			for f in max_frames + 1:
				var alive: int = console.fight.living().size() if is_instance_valid(console) and console.fight != null else 0
				if DevInspect.compare_number(float(alive), op, float(want_n)):
					return {"cmd": step, "ok": true, "text": "enemies %s %d after %d frames" % [op, want_n, f], "tone": "ok", "data": {"frames": f, "enemies": alive}}
				if f < max_frames and is_inside_tree():
					await get_tree().process_frame
			return {"cmd": step, "ok": false, "text": "!until enemies %s %d timed out after %d frames" % [op, want_n, max_frames], "tone": "warn", "data": {"frames": max_frames}}
		"event":
			var sig := words[2]
			max_frames = clampi(DevCommands.whole(words, 3, DEFAULT_UNTIL_FRAMES), 1, MAX_WAIT_FRAMES)
			var insp := _inspect()
			if insp == null:
				return {"cmd": step, "ok": false, "text": "!DevInspect not mounted", "tone": "warn", "data": null}
			if not insp.recording:
				insp.set_recording(true)
			for f in max_frames + 1:
				if insp.event_count(sig) > 0:
					return {"cmd": step, "ok": true, "text": "event %s seen after %d frames" % [sig, f], "tone": "ok", "data": {"frames": f, "signal": sig, "count": insp.event_count(sig)}}
				if f < max_frames and is_inside_tree():
					await get_tree().process_frame
			return {"cmd": step, "ok": false, "text": "!until event %s timed out after %d frames" % [sig, max_frames], "tone": "warn", "data": {"frames": max_frames}}
	return {"cmd": step, "ok": false, "text": "!unknown until target '%s' (state|play|enemies|event)" % kind, "tone": "warn", "data": null}


func _exec_shot(step: String, shot_name: String, scripted: bool, shots: Array) -> Dictionary:
	if not is_instance_valid(console):
		return {"cmd": step, "ok": false, "text": "!no console", "tone": "warn", "data": null}
	var reply: Variant = "!console cannot capture shots"
	if console.has_method("shot_detailed"):
		reply = await console.shot_detailed(shot_name, scripted)
	elif console.has_method("shot"):
		reply = await console.shot(shot_name, scripted)
	return _normalize_capture(step, "shot", shot_name, reply, shots)


func _exec_sheet(step: String, words: Array[String], scripted: bool, shots: Array) -> Dictionary:
	if not is_instance_valid(console):
		return {"cmd": step, "ok": false, "text": "!no console", "tone": "warn", "data": null}
	var mode := "presets"
	var sheet_name := ""
	if words.size() >= 2 and words[1].to_lower() in ["presets", "cams", "quality"]:
		mode = words[1].to_lower()
		sheet_name = DevCommands.word(words, 2, "")
	else:
		sheet_name = DevCommands.word(words, 1, "")
	var reply: Variant = "!console cannot capture contact sheets"
	if console.has_method("sheet_detailed"):
		reply = await console.sheet_detailed(mode, sheet_name, scripted)
	elif console.has_method("contact_sheet_mode"):
		reply = await console.contact_sheet_mode(mode, sheet_name, scripted)
	elif console.has_method("contact_sheet"):
		var argc := _method_argc(console, "contact_sheet")
		if argc >= 3:
			reply = await console.contact_sheet(mode, sheet_name, scripted)
		elif argc == 2:
			reply = await console.contact_sheet(mode, scripted)
		else:
			reply = await console.contact_sheet(scripted)
	return _normalize_capture(step, "sheet:%s" % mode, sheet_name, reply, shots)


func _normalize_capture(step: String, kind: String, cap_name: String, reply: Variant, shots: Array) -> Dictionary:
	if reply is Dictionary:
		var ok := bool(reply.get("ok", false))
		var text := String(reply.get("text", ""))
		var data = reply.get("data", reply)
		var dead_tile := false
		if data is Dictionary and data.get("tiles") is Array:
			for tile in data.tiles:
				if tile is Dictionary and bool(tile.get("dead", false)):
					dead_tile = true
					break
		var dead_frame := bool(reply.get("dead_frame", false))
		if data is Dictionary:
			dead_frame = dead_frame or bool(data.get("dead_frame", false)) or (int(data.get("dead_count", 0)) > 0) or dead_tile
		var entry := {"kind": kind, "name": cap_name, "ok": ok, "path": String(reply.get("path", data.get("path", "") if data is Dictionary else "")),
			"dead_frame": dead_frame}
		shots.append(entry)
		return {"cmd": step, "ok": ok and not entry.dead_frame, "text": text, "tone": "ok" if (ok and not entry.dead_frame) else "warn", "data": data}
	var text := String(reply)
	var ok := not text.begins_with("!")
	var path := ""
	var arrow := text.find("-> ")
	if arrow >= 0:
		path = text.substr(arrow + 3).strip_edges()
	var entry := {"kind": kind, "name": cap_name, "ok": ok, "path": path, "dead_frame": false}
	shots.append(entry)
	return {"cmd": step, "ok": ok, "text": text, "tone": "ok" if ok else "warn", "data": entry}


func _write_artifacts(target_dir: String, step_rows: Array, receipt: Dictionary) -> Dictionary:
	var global_dir := ProjectSettings.globalize_path(target_dir)
	DirAccess.make_dir_recursive_absolute(global_dir)
	var lines: Array[String] = []
	for row in step_rows:
		lines.append(JSON.stringify(row))
	var ndjson := ("\n".join(lines) + "\n") if not lines.is_empty() else ""
	var steps_path := global_dir.path_join("steps.ndjson")
	var receipt_path := global_dir.path_join("receipt.json")
	var err_steps := SafeStore.write_atomic(steps_path, ndjson)
	var err_receipt := SafeStore.write_atomic(receipt_path, JSON.stringify(receipt, "\t") + "\n")
	return {"steps_path": steps_path, "receipt_path": receipt_path, "ok": err_steps == OK and err_receipt == OK}


func _inspect() -> Node:
	if not is_instance_valid(console):
		return null
	if "inspect" in console and is_instance_valid(console.get("inspect")):
		return console.get("inspect") as Node
	return console.get_node_or_null("DevInspect")


static func _split_words(step: String) -> Array[String]:
	var words: Array[String] = []
	for w in step.strip_edges().split(" ", false):
		words.append(w)
	return words


static func _method_argc(obj: Object, method_name: String) -> int:
	var script_res = obj.get_script()
	if script_res is Script:
		for info in script_res.get_script_method_list():
			if String(info["name"]) == method_name:
				return (info["args"] as Array).size()
	return 1
