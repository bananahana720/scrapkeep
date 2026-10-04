extends SceneTree

const Game := preload("res://src/game.gd")

# The harpoon chain's run record and codex card (HOOK-CHAIN.md, HC3). The test drives the
# bus and writes player.chain.finished / combo directly, as the player would before it
# publishes; chain.gd's own rule is covered elsewhere. Pass: every label prints PASS, exit 0.

var _game
var _failures := 0
var _wait := 0
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _end(links: int, combo: int, paid: bool) -> void:
	var chain = _game.player.chain
	chain.finished.append({"links": links, "pivots": 0, "combo": combo, "paid": paid, "cause": "paid" if paid else "ground"})
	_game.events.line_state_changed.emit("chain_end", null, Vector3.ZERO, "paid" if paid else "ground")


func _link(combo: int) -> void:
	_game.player.chain.combo = combo
	_game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		# (e) nothing counts before a run
		_game.events.line_state_changed.emit("chain_miss", null, Vector3.ZERO, "")
		_report("(e) no run", _game.run_log._record.is_empty(), "record empty, handlers ignored the emits")
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 3:
		return false
	var log = _game.run_log
	var rec: Dictionary = log._record
	_report("(a) start", rec.get("chains") == [] and rec.get("best_combo") == 0 and rec.get("misses") == 0,
		"chains %s, best_combo %s, misses %s" % [rec.get("chains"), rec.get("best_combo"), rec.get("misses")])
	_game.player.chain.reset()
	for i in 3:
		_link(i + 1)
	_report("(g) combo 3 opens the card", _game.codex.known("chain") and "chain" in _game.codex.discovered_this_run(),
		"known %s, this run %s" % [_game.codex.known("chain"), _game.codex.discovered_this_run()])
	_end(3, 3, true)
	var c: Dictionary = rec["chains"][0] if rec["chains"].size() == 1 else {}
	_report("(b) paid chain", c.get("links") == 3 and c.get("pivots") == 0 and c.get("combo") == 3 and c.get("paid") == true and rec["best_combo"] == 3,
		"chains %s, best_combo %s" % [rec["chains"], rec["best_combo"]])
	_end(2, 2, false)
	_report("(c) lesser chain", rec["chains"].size() == 2 and rec["best_combo"] == 3, "chains %d, best_combo %s" % [rec["chains"].size(), rec["best_combo"]])
	for i in 2:
		_game.events.line_state_changed.emit("chain_miss", null, Vector3.ZERO, "")
	_report("(d) misses", rec["misses"] == 2, "misses %s" % rec["misses"])
	log._in_arena = true
	_game.events.line_state_changed.emit("chain_miss", null, Vector3.ZERO, "")
	_end(4, 4, true)
	_report("(e) arena", rec["misses"] == 2 and rec["chains"].size() == 2 and rec["best_combo"] == 3, "misses %s, chains %d, best_combo %s" % [rec["misses"], rec["chains"].size(), rec["best_combo"]])
	log._in_arena = false
	log._write("died")
	var lines := FileAccess.get_file_as_string(log.storage_dir.path_join(log.LOG_FILE)).strip_edges().split("\n")
	var line: Dictionary = JSON.parse_string(lines[lines.size() - 1]) if lines.size() > 0 else {}
	_report("(f) written line", line.has("chains") and line.has("best_combo") and line.has("misses") and int(line["best_combo"]) == 3 and int(line["misses"]) == 2 and line["chains"].size() == 2,
		"chains %s, best_combo %s, misses %s" % [line.get("chains"), line.get("best_combo"), line.get("misses")])
	# (g) below three: a fresh codex run state
	_game.events.run_started.emit("runner_gunner")
	_game.player.chain.reset()
	_link(2)
	_report("(g) combo 2 does not", not ("chain" in _game.codex.discovered_this_run()), "this run %s" % [_game.codex.discovered_this_run()])
	print("chain_log_test: %s" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures])
	quit(1 if _failures > 0 else 0)
	return true
