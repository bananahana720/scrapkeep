extends SceneTree

const Game := preload("res://src/game.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Roster := preload("res://src/combat/roster.gd")
const Director := preload("res://src/world/director.gd")
const Parts := preload("res://src/build/parts.gd")
const TelegraphScript := preload("res://src/combat/telegraph.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const PerchPoints := preload("res://src/world/perch_points.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

# MATCHUP LAB (design-v3/ENEMY-PRIORITY.md lever 7; usage and definitions in tools/matchup_lab.md).
# A headless duel table: each pilot alone against each enemy kind, N seeds, recording time to
# kill and hull lost. It prints a pilot x kind heatmap, marks the HARD cells, and grades the
# gate: every pilot has a hard cell, and the brawler bot wins each hard cell once given that
# cell's answer item (a part whose row carries an `answers` tag for the cell's axis).
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/matchup_lab.gd \
#     -- --out=<abs ndjson> [--procs=4] [--seeds=1,...,8] [--cap=40] [--dodge=0.65]
#     [--pilots=a,b] [--kinds=a,b] [--answer=1] [--give=<part id>] [--range=18] [--idle=0]
#   pack mode: -- --out=<abs ndjson> --packs=<id,id|all> [--table=park|alpha] [--range=12] ...
#   perched duel: -- --out=<abs ndjson> --kinds=dispatcher --perched=park,mast [--range=15] ...
#   or: -- --from=<a.ndjson,b.ndjson> [--out=<heatmap txt>]   re-render saved rows
#
# Each duel is its own process (a bot run repeats exactly only in a fresh one). The harness is
# tools/priority_proof.gd's: calm map, bot driver, the dodge share, the settle wait.

# The two kill-first specials are measured by tools/priority_proof.gd: the Linker guards a
# partner (nothing to duel alone) and the Foreman never attacks (its row is its crew).
const SKIP_KINDS := ["linker", "foreman"]
# The axis a kind's answer item must carry (ENEMY-PRIORITY section 5; items/parts tag
# `answers`: range, spread, fuse, cc, air, plating). A kind not listed answers to range.
const ANSWER_AXIS := {
	"plated_brute": "plating", "deflector": "plating", "ballast_heavy": "plating",
	"swarm_remnant": "spread", "lamp_swarm": "spread", "drill_crew": "spread", "prop_crew": "spread",
	"chaser": "fuse", "burrower": "fuse", "splitter": "fuse",
	"mag_trapper": "cc", "catch_trap": "cc", "anchor_crew": "cc", "hooker": "cc", "netcaster": "cc",
	"bola_thrower": "cc", "gyro_jammer": "cc", "ramp_flipper": "cc", "swatter": "cc", "pit_jaw": "cc", "gap_net": "cc",
	"kite_drone": "air", "winch_drone": "air",
}
const AXES := ["range", "spread", "fuse", "cc", "air", "plating"]
# HARD: a cell's median time to kill over 2.0 x its row's median (row = that kind across pilots),
# with the row median floored at MIN_ROW_S so a row of instant kills cannot make a second hard.
const HARD_RATIO := 2.0
const MIN_ROW_S := 1.0
# The answer arm wins a cell when the bot kills in at least this share of seeds and the cell
# is no longer hard against the unchanged baseline row median.
const WIN_SHARE := 0.5
const DODGE := 0.65
const DUEL_RANGE := 18.0
# Pack mode (--packs): a named authored pack is the opponent, closer in, spaced like Director._place_pack.
const PACK_RANGE := 12.0
# Beacon seconds no duel can reach (the stage's own is 25).
const BEACON_PIN_S := 1.0e9
const PACK_PREFIX := "pack:"
const TABLES := ["park", "alpha"]
# Perched duel (--perched): the Dispatcher on a park perch top (`park`) or on its own mast (`mast`).
# The row key is `dispatcher@<mode>`. Both modes play the park table so the two rows share a map.
const PERCHED_KIND := "dispatcher"
const PERCHED_MODES := ["park", "mast"]
const PERCH_SEP := "@"
const PERCH_RANGE := 15.0
# A relocated ball stands on ground this flat (height spread over STANDOFF_PROBES) and this clear of landforms.
const STANDOFF_FLAT_M := 0.12
# Probe offsets: the spot and 8 points on a 4 m ring, so a gentle slope (which rolls a resting ball) fails.
const STANDOFF_PROBES := [Vector2(0, 0), Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4), Vector2(2.8, 2.8), Vector2(-2.8, 2.8), Vector2(2.8, -2.8), Vector2(-2.8, -2.8)]
const STANDOFF_CLEAR_M := 3.0
const STANDOFF_BEARINGS := 16
const STANDOFF_STEP_M := 5.0
const STANDOFF_REACH_M := 15.0
# A duel starts at rest: the ball must be grounded and slower than REST_SPEED for SETTLE_S in a
# row. If it has not come to rest REST_WAIT_S after first landing, it is set to rest where it
# stands (the player's own set_velocity_now); at SETTLE_MAX_S the duel starts regardless.
const SETTLE_S := 2.0
const REST_SPEED := 0.5
const REST_WAIT_S := 6.0
const SETTLE_MAX_S := 12.0
# The hull pool a duel gives the ball, so a lost duel is measured by hull_lost and does not end the run.
const HULL_POOL := 99999.0
const WALL_LIMIT_S := 600.0
# Outcomes that measured nothing: left out of the table and the answer arm.
const NO_RESULT := ["no_result", "wall_timeout", "stage_changed", "no_perch"]
const PENDING := "answer: pending (no answers tags on this base)"


class DuelDriver extends BotDriver:
	var enemy: Node3D = null
	var adds: Array = []
	# Pack mode: the pack's members; the driver fights the nearest live one (or add).
	var members: Array = []
	var dodge := 1.0
	# --idle=1: the pilot stands still and never fights, so the lab's damage path can be shown
	# (the planted positive control in tests/matchup_lab_test.gd).
	var idle := false
	var _dodge_rng := RandomNumberGenerator.new()
	var _answers := {}

	# Each telegraph is answered or missed once, when first seen, from the run's own stream.
	func _threats() -> Array:
		var out: Array = []
		for h in super._threats():
			var id: int = h.get_instance_id()
			if not _answers.has(id):
				_answers[id] = _dodge_rng.randf() < dodge
			if _answers[id]:
				out.append(h)
		return out

	func _roam(delta: float) -> void:
		if idle:
			source.hold = {}
			return
		var target := pick()
		if target == null:
			source.hold = {}
			return
		_fight(target, delta)

	func pick() -> Node3D:
		if alive(enemy):
			return enemy
		var ball: Vector3 = game.player.ball_position()
		var best: Node3D = null
		var best_d := INF
		for member in members:
			if alive(member) and ball.distance_to(member.global_position) < best_d:
				best_d = ball.distance_to(member.global_position)
				best = member
		for add in adds:
			if alive(add) and ball.distance_to(add.global_position) < best_d:
				best_d = ball.distance_to(add.global_position)
				best = add
		return best

	static func alive(e) -> bool:
		return e != null and is_instance_valid(e) and not (e.has_method("is_dead") and e.is_dead())


var _settings := {}
var _bot_options
var _cap := 40.0
var _parent := false
var _done := false

# Parent state.
var _queue: Array = []
var _running: Array = []
var _results: Array = []
var _answer_results: Array = []
var _procs := 4
var _total := 0
var _sweep_dir := ""
var _phase := 1
var _pilots: Array = []
var _kinds: Array = []
var _table_id := "park"
var _seeds: Array[int] = []
var _answer_plan := {}
var _out_rows: Array = []

# Child state.
var _pilot := ""
var _kind := ""
var _run_seed := 0
var _game
var _driver
var _spawned := false
var _start_s := 0.0
var _grounded_s := 0.0
var _landed_s := 0.0
var _rest_forced := false
var _settle_s := 0.0
var _hull_start := 0.0
var _taken := 0.0
var _hits := 0
var _kill_s := -1.0
var _kill_dist := -1.0
var _last_dist := -1.0
var _enemy_set := false
var _pack_mode := false
var _pack_id := ""
var _pack_members: Array = []
var _pack_spawned := 0
var _pack_skipped: Array = []
var _collecting := false
var _first_down_s := -1.0
var _spawn_stage := 0
var _stage_changed := false
var _warnings := 0
var _joined := 0
var _scrap_serial := 0
var _counter_serial := 0
# Perched duel state (child).
var _perched := ""
var _perch_chosen := false
var _no_perch := false
var _relocated := false
var _perch_top := Vector3.INF
var _perch_source := "unknown"
var _perch_base_rise := -1.0
var _standoff_m := -1.0
var _standoff_ok := false
var _held := false
var _perched_under := false
var _perch_over_ball := 0.0
var _ball_to_perch := -1.0
var _perch_rise := -1.0
var _mast_built := false
var _snap := {}
var _dispatcher_down_s := -1.0


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	_bot_options = BotOptions.new(_settings, self)
	_cap = float(_settings.get("cap", "40"))
	if _settings.has("kind"):
		_begin_child()
		return
	if _settings.has("from"):
		_render_from()
		return
	if not _settings.has("out"):
		printerr("matchup_lab: usage: -- --out=<abs ndjson> [--procs=4] [--seeds=1,...,8] [--cap=40] [--dodge=0.65] [--pilots=a,b] [--kinds=a,b | --packs=a,b|all --table=park|alpha | --kinds=dispatcher --perched=park,mast] [--answer=1]")
		quit(2)
		return
	for part in String(_settings.get("seeds", "1,2,3,4,5,6,7,8")).split(",", false):
		_seeds.append(int(part))
	_pilots = Array(String(_settings.get("pilots", ",".join(PILOTS))).split(",", false))
	_kinds = Array(String(_settings.get("kinds", ",".join(default_kinds()))).split(",", false))
	if _settings.has("packs"):
		_table_id = String(_settings.get("table", "park"))
		if _table_id not in TABLES:
			printerr("matchup_lab: unknown --table %s (park or alpha)" % _table_id)
			quit(2)
			return
		var ids: Array = pack_ids(_table_id) if String(_settings["packs"]) == "all" else Array(String(_settings["packs"]).split(",", false))
		_kinds = []
		for id in ids:
			if pack_kinds(_table_id, id).is_empty():
				printerr("matchup_lab: unknown pack %s on the %s table" % [id, _table_id])
				quit(2)
				return
			if PACK_PREFIX + id not in _kinds:
				_kinds.append(PACK_PREFIX + id)
		if _kinds.is_empty():
			printerr("matchup_lab: --packs named no pack")
			quit(2)
			return
	if _settings.has("perched"):
		var plan := perched_plan(String(_settings["perched"]), _kinds, _settings.has("packs"))
		if not plan["ok"]:
			printerr("matchup_lab: %s" % plan["error"])
			quit(2)
			return
		_kinds = plan["kinds"]
	for p in _pilots:
		if BotDriver.class_index_for(0, p) < 0:
			printerr("matchup_lab: unknown pilot %s" % p)
			quit(2)
			return
	var n := 0
	for kind in _kinds:
		for pilot in _pilots:
			for seed_value in _seeds:
				_queue.append({"n": n, "pilot": pilot, "kind": kind, "seed": seed_value, "give": ""})
				n += 1
	_total = n
	_procs = clampi(int(_settings.get("procs", "4")), 1, 8)
	_sweep_dir = OS.get_user_data_dir().path_join("matchup_lab").path_join("p%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_sweep_dir)
	_parent = true


# --from=<a.ndjson,b.ndjson>: rebuild the heatmap and baseline gate from saved rows (runs nothing).
# The answer arm is not replayed, so its cells read pending.
func _render_from() -> void:
	var rows := []
	for path in String(_settings["from"]).split(",", false):
		for line in FileAccess.get_file_as_string(path).split("\n", false):
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary and String(parsed.get("give", "")) == "":
				rows.append(parsed)
	var pilots := []
	for p in PILOTS:
		for r in rows:
			if r["pilot"] == p:
				pilots.append(p)
				break
	var kinds := []
	for k in default_kinds():
		for r in rows:
			if r["kind"] == k:
				kinds.append(k)
				break
	for r in rows:
		var k := String(r["kind"])
		if k.begins_with(PACK_PREFIX) and k not in kinds:
			kinds.append(k)
	for r in rows:
		var k := String(r["kind"])
		if PERCH_SEP in k and k not in kinds:
			kinds.append(k)
	var table := build_table(rows, pilots, kinds, _cap)
	var lines := heatmap(table)
	lines.append_array(gate_lines(table, grade_answers(table, [], {}, _cap, 0)))
	for line in lines:
		print(line)
	if _settings.has("out"):
		var f := FileAccess.open(String(_settings["out"]), FileAccess.WRITE)
		for line in lines:
			f.store_line(line)
		f.close()
	quit(0)


const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out


# Every spawnable, built kind the director names, bar SKIP_KINDS.
static func default_kinds() -> Array:
	var out := []
	for kind in Director.KIND_NAMES:
		if kind in SKIP_KINDS:
			continue
		if Roster.ROWS.has(kind) and Roster.built(kind):
			out.append(kind)
	return out


# ---- Pack tables ------------------------------------------------------------------------

static func _defs(table: String) -> Array:
	return AlphaDefs.DEFS if table == "alpha" else ParkDefs.DEFS


# Every distinct pack id on a table, in first-seen stage order: each stage's `packs`, then its `elite`.
static func pack_ids(table: String) -> Array:
	var out := []
	for def in _defs(table):
		var entries: Array = (def.get("packs", []) as Array).duplicate()
		if def.get("elite") is Dictionary:
			entries.append(def["elite"])
		for pack in entries:
			if String(pack["id"]) not in out:
				out.append(String(pack["id"]))
	return out


# The member kinds of a pack id: the first stage that names it wins (empty for an unknown id).
static func pack_kinds(table: String, id: String) -> Array:
	for def in _defs(table):
		var entries: Array = (def.get("packs", []) as Array).duplicate()
		if def.get("elite") is Dictionary:
			entries.append(def["elite"])
		for pack in entries:
			if String(pack["id"]) == id:
				return (pack["kinds"] as Array).duplicate()
	return []


# The axis a pack's answer must carry: the most common ANSWER_AXIS among its members, ties by AXES order.
static func pack_axis(members: Array) -> String:
	var counts := {}
	for k in members:
		var axis: String = ANSWER_AXIS.get(k, "range")
		counts[axis] = int(counts.get(axis, 0)) + 1
	var best := "range"
	var best_n := 0
	for axis in AXES:
		if int(counts.get(axis, 0)) > best_n:
			best_n = int(counts[axis])
			best = axis
	return best


# The 9-char heatmap row label: kinds as is, a pack row `+<id>`.
static func row_label(kind: String) -> String:
	if PERCH_SEP in kind:
		var parts := kind.split(PERCH_SEP)
		return (parts[0].substr(0, 4) + PERCH_SEP + parts[1].substr(0, 4)).substr(0, 9)
	var text := "+" + kind.substr(PACK_PREFIX.length()) if kind.begins_with(PACK_PREFIX) else kind
	return text.substr(0, 9)


# ---- Perched duel ------------------------------------------------------------------------

# The row key of a perched duel: `dispatcher@park` or `dispatcher@mast`.
static func perched_key(mode: String) -> String:
	return PERCHED_KIND + PERCH_SEP + mode


# The mode of a perched row key, or "" for any other kind.
static func perched_mode(kind: String) -> String:
	if not kind.begins_with(PERCHED_KIND + PERCH_SEP):
		return ""
	var mode := kind.substr(PERCHED_KIND.length() + 1)
	return mode if mode in PERCHED_MODES else ""


# --perched=park,mast against the --kinds list: valid only with dispatcher as the one duel kind
# (and not in pack mode). {ok, kinds (the row keys, in the order given), error}.
static func perched_plan(modes_text: String, kinds: Array, packs: bool) -> Dictionary:
	var modes := Array(modes_text.split(",", false))
	var bad := {"ok": false, "kinds": [], "error": ""}
	if modes.is_empty():
		bad["error"] = "--perched named no mode (park or mast)"
		return bad
	for mode in modes:
		if mode not in PERCHED_MODES:
			bad["error"] = "unknown --perched mode %s (park or mast)" % mode
			return bad
	if packs or kinds != [PERCHED_KIND]:
		bad["error"] = "--perched needs --kinds=dispatcher and no --packs"
		return bad
	var keys := []
	for mode in modes:
		if perched_key(mode) not in keys:
			keys.append(perched_key(mode))
	return {"ok": true, "kinds": keys, "error": ""}


# ---- Answer lookup ----------------------------------------------------------------------

# The `answers` tags of a part row, as an array; empty when the field is absent.
static func answers_of(row: Dictionary) -> Array:
	var raw = row.get("answers", [])
	if raw is String:
		return [raw]
	return raw if raw is Array else []


# True when any part row carries an `answers` field at all (the Systems lane's branch).
static func answers_field_exists(rows: Dictionary) -> bool:
	for id in rows:
		if rows[id] is Dictionary and (rows[id] as Dictionary).has("answers"):
			return true
	return false


# The part to hand `pilot` for `kind`'s axis: the first id (sorted) whose answers carry the
# axis and whose class gate admits the pilot. "" when none, or when the field does not exist.
static func answer_item(rows: Dictionary, pilot: String, kind: String, members := []) -> String:
	var axis: String = pack_axis(members) if kind.begins_with(PACK_PREFIX) else ANSWER_AXIS.get(kind, "range")
	var ids := rows.keys()
	ids.sort()
	for id in ids:
		var row = rows[id]
		if not row is Dictionary:
			continue
		if axis not in answers_of(row):
			continue
		var only := String(row.get("class", ""))
		if only != "" and only != pilot:
			continue
		return String(id)
	return ""


# ---- Parent: the pool -------------------------------------------------------------------

func _process(_delta: float) -> bool:
	if not _parent or _done:
		return false
	for run in _running.duplicate():
		if not OS.is_process_running(run["pid"]):
			_reap(run, false)
		elif float(Time.get_ticks_msec() - int(run["started"])) / 1000.0 > WALL_LIMIT_S:
			OS.kill(run["pid"])
			_reap(run, true)
	while _running.size() < _procs and not _queue.is_empty():
		_spawn(_queue.pop_front())
	if _running.is_empty() and _queue.is_empty():
		if _phase == 1 and _begin_answer_phase():
			return false
		_done = true
		_finish()
		return false
	OS.delay_msec(250)
	return false


# The child's command line. A pack child names its pack list with --pack-table; a bare --table= here
# would be read by Game._chosen_table() and move the duel onto a park or alpha stage map, away from
# the legacy map the kind duels play.
static func child_args(job: Dictionary, cap: float, settings: Dictionary, table_id: String, home: String, project_path: String) -> PackedStringArray:
	var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path", project_path,
			"--script", "res://tools/matchup_lab.gd", "--", "--pilot=" + String(job["pilot"]), "--kind=" + String(job["kind"]),
			"--run-seed=%d" % job["seed"], "--cap=%s" % cap, "--result=" + home.path_join("result.json"), "--home=" + home])
	if String(job["give"]) != "":
		args.append("--give=" + String(job["give"]))
	if settings.has("dodge"):
		args.append("--dodge=%s" % settings["dodge"])
	if settings.has("range"):
		args.append("--range=%s" % settings["range"])
	if settings.has("idle"):
		args.append("--idle=%s" % settings["idle"])
	if String(job["kind"]).begins_with(PACK_PREFIX):
		args.append("--pack-table=" + table_id)
	if perched_mode(String(job["kind"])) != "":
		args.append("--perched=" + perched_mode(String(job["kind"])))
	for key in BotOptions.FAST_FLAGS:
		if settings.has(key):
			args.append("--%s=%s" % [key, settings[key]])
	return args


# A pack whose members were all skipped (or never spawned) measured nothing: no_result, left out of the table.
static func pack_outcome(spawned: int, outcome: String) -> String:
	return "no_result" if spawned <= 0 else outcome


func _spawn(job: Dictionary) -> void:
	var home := _sweep_dir.path_join("job%d_%d" % [_phase, job["n"]])
	DirAccess.make_dir_recursive_absolute(home)
	var args := child_args(job, _cap, _settings, _table_id, home, ProjectSettings.globalize_path("res://"))
	var previous := {}
	for kind in ["DATA", "CONFIG", "CACHE"]:
		var key: String = "XDG_%s_HOME" % kind
		previous[key] = OS.get_environment(key)
		OS.set_environment(key, home.path_join("state-" + kind.to_lower()))
	var pid := OS.create_process(OS.get_executable_path(), args)
	for key in previous:
		if previous[key].is_empty():
			OS.unset_environment(key)
		else:
			OS.set_environment(key, previous[key])
	job["pid"] = pid
	job["home"] = home
	job["started"] = Time.get_ticks_msec()
	_running.append(job)


func _reap(run: Dictionary, timed_out: bool) -> void:
	_running.erase(run)
	var home: String = run["home"]
	var path := home.path_join("result.json")
	var result = null
	if FileAccess.file_exists(path) and not timed_out:
		result = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not result is Dictionary:
		result = {"pilot": run["pilot"], "kind": run["kind"], "seed": run["seed"], "give": run["give"],
				"outcome": "wall_timeout" if timed_out else "no_result", "ttk_s": -1.0, "hull_lost": 0.0}
	if String(run["kind"]).begins_with(PACK_PREFIX):
		result["pack"] = String(run["kind"]).substr(PACK_PREFIX.length())
		result["table"] = _table_id
		if not result.has("members"):
			result["members"] = pack_kinds(_table_id, result["pack"])
	result["phase"] = "answer" if _phase == 2 else "baseline"
	(_answer_results if _phase == 2 else _results).append(result)
	_remove_tree(home)
	print("matchup_lab: %d of %d (phase %d): %s" % [_results.size() + _answer_results.size(), _total, _phase, JSON.stringify(result)])


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


# After the baseline table: for each hard cell, look up its answer item and queue the paired
# duels with it in hand. Returns true when jobs were queued. With no `answers` field on this
# base's part rows (or no row for a cell's axis) the cell is reported pending and nothing runs.
func _begin_answer_phase() -> bool:
	_phase = 2
	if String(_settings.get("answer", "1")) != "1":
		return false
	var table := build_table(_results, _pilots, _kinds, _cap)
	var rows := Parts.rows()
	var field := answers_field_exists(rows)
	var n := _total
	for cell in table["hard"]:
		var item := answer_item(rows, cell["pilot"], cell["kind"], _row_members(cell["kind"])) if field else ""
		_answer_plan[cell_key(cell["pilot"], cell["kind"])] = item
		if item == "":
			continue
		for seed_value in _seeds:
			_queue.append({"n": n, "pilot": cell["pilot"], "kind": cell["kind"], "seed": seed_value, "give": item})
			n += 1
	return not _queue.is_empty()


func _row_members(kind: String) -> Array:
	return pack_kinds(_table_id, kind.substr(PACK_PREFIX.length())) if kind.begins_with(PACK_PREFIX) else []


func _finish() -> void:
	var table := build_table(_results, _pilots, _kinds, _cap)
	var answers := grade_answers(table, _answer_results, _answer_plan, _cap, _seeds.size(), _settings.get("answer", "1") == "1")
	var path := String(_settings["out"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	for r in _results + _answer_results:
		file.store_line(JSON.stringify(r))
	file.close()
	var lines := heatmap(table)
	lines.append_array(gate_lines(table, answers))
	var text_file := FileAccess.open(path.get_basename() + ".heatmap.txt", FileAccess.WRITE)
	for line in lines:
		print(line)
		text_file.store_line(line)
	text_file.close()
	_remove_tree(_sweep_dir)
	quit(0)


# ---- Pure parts: table, hard cells, gate, heatmap ---------------------------------------

static func cell_key(pilot: String, kind: String) -> String:
	return "%s|%s" % [pilot, kind]


# One cell per pilot x kind from baseline result rows: median time to kill over the seeds that
# produced a result (a duel not won counts the cap), median hull lost, kills and runs. Then each
# kind's row median (the median of its pilots' cell medians, floored at MIN_ROW_S) and the HARD
# cells: median above HARD_RATIO x row median.
static func build_table(results: Array, pilots: Array, kinds: Array, cap: float) -> Dictionary:
	var cells := {}
	for pilot in pilots:
		for kind in kinds:
			cells[cell_key(pilot, kind)] = {"pilot": pilot, "kind": kind, "ttk": [], "hull": [], "kills": 0, "runs": 0, "hard": false}
	for r in results:
		var key := cell_key(String(r.get("pilot", "")), String(r.get("kind", "")))
		if not cells.has(key) or String(r.get("outcome", "")) in NO_RESULT:
			continue
		var cell: Dictionary = cells[key]
		var killed := float(r.get("ttk_s", -1.0)) >= 0.0
		cell["ttk"].append(float(r["ttk_s"]) if killed else cap)
		cell["hull"].append(float(r.get("hull_lost", 0.0)))
		cell["runs"] += 1
		if killed:
			cell["kills"] += 1
	var row_median := {}
	var hard := []
	for kind in kinds:
		var meds := []
		for pilot in pilots:
			var cell: Dictionary = cells[cell_key(pilot, kind)]
			cell["median_ttk"] = median(cell["ttk"])
			cell["median_hull"] = median(cell["hull"])
			if cell["runs"] > 0:
				meds.append(cell["median_ttk"])
		row_median[kind] = maxf(median(meds), MIN_ROW_S)
	for kind in kinds:
		for pilot in pilots:
			var cell: Dictionary = cells[cell_key(pilot, kind)]
			cell["row_median"] = row_median[kind]
			cell["hard"] = cell["runs"] > 0 and cell["median_ttk"] > HARD_RATIO * row_median[kind]
			if cell["hard"]:
				hard.append(cell)
	return {"cells": cells, "pilots": pilots, "kinds": kinds, "row_median": row_median, "hard": hard, "cap": cap}


# Hard cells per pilot, in kind order.
static func hard_by_pilot(table: Dictionary) -> Dictionary:
	var out := {}
	for pilot in table["pilots"]:
		out[pilot] = []
	for cell in table["hard"]:
		out[cell["pilot"]].append(cell["kind"])
	return out


# Gate part one: every pilot has at least one hard cell. {ok, missing}.
static func gate_hard(table: Dictionary) -> Dictionary:
	var missing := []
	var by := hard_by_pilot(table)
	for pilot in table["pilots"]:
		if (by[pilot] as Array).is_empty():
			missing.append(pilot)
	return {"ok": missing.is_empty() and not (table["pilots"] as Array).is_empty(), "missing": missing}


# Gate part two, per hard cell: "won" (the answer arm killed in at least WIN_SHARE of its seeds
# and its median time is no longer hard against the baseline row median), "lost", or "pending"
# (no answer item exists on this base). `plan` maps cell key to the item given ("" = none).
static func grade_answers(table: Dictionary, answer_results: Array, plan: Dictionary, cap: float, seeds_per_cell: int, enabled := true) -> Dictionary:
	var out := {}
	for cell in table["hard"]:
		var key := cell_key(cell["pilot"], cell["kind"])
		var item := String(plan.get(key, ""))
		if not enabled or item == "":
			out[key] = {"status": "pending", "item": "", "text": PENDING}
			continue
		var ttk := []
		var kills := 0
		var runs := 0
		for r in answer_results:
			if cell_key(String(r.get("pilot", "")), String(r.get("kind", ""))) != key or String(r.get("outcome", "")) in NO_RESULT:
				continue
			runs += 1
			if float(r.get("ttk_s", -1.0)) >= 0.0:
				kills += 1
				ttk.append(float(r["ttk_s"]))
			else:
				ttk.append(cap)
		var won := runs > 0 and float(kills) / float(maxi(runs, 1)) >= WIN_SHARE and median(ttk) <= HARD_RATIO * float(cell["row_median"])
		out[key] = {"status": "won" if won else "lost", "item": item, "kills": kills, "runs": runs, "median_ttk": median(ttk),
				"text": "answer %s: %s (%d of %d killed, median %.1fs)" % [item, "won" if won else "lost", kills, runs, median(ttk)]}
	return out


# Overall verdict: PASS needs every pilot hard-celled and every hard cell won; any pending
# answer makes the second half INCONCLUSIVE rather than a pass.
static func gate_verdict(table: Dictionary, answers: Dictionary) -> String:
	if not gate_hard(table)["ok"]:
		return "FAIL"
	var pending := false
	for key in answers:
		match answers[key]["status"]:
			"lost":
				return "FAIL"
			"pending":
				pending = true
	return "INCONCLUSIVE" if pending else "PASS"


static func heatmap(table: Dictionary) -> Array:
	var pilots: Array = table["pilots"]
	var lines := []
	var head := "%-14s" % "kind (row med)"
	for pilot in pilots:
		head += " %9s" % String(pilot).substr(0, 9)
	lines.append("matchup_lab: heatmap, median seconds to kill (cap %.0fs); * = HARD (over %.1fx row median); med hull lost in brackets" % [table["cap"], HARD_RATIO])
	lines.append(head)
	for kind in table["kinds"]:
		var line := "%-9s%5.1f" % [row_label(String(kind)), table["row_median"][kind]]
		for pilot in pilots:
			var cell: Dictionary = table["cells"][cell_key(pilot, kind)]
			if cell["runs"] == 0:
				line += " %9s" % "-"
			else:
				line += " %9s" % ("%.1f%s[%d]" % [cell["median_ttk"], "*" if cell["hard"] else "", int(round(cell["median_hull"]))])
		lines.append(line)
	return lines


static func gate_lines(table: Dictionary, answers: Dictionary) -> Array:
	var lines := []
	var by := hard_by_pilot(table)
	for pilot in table["pilots"]:
		var cells := []
		for kind in by[pilot]:
			var key := cell_key(pilot, kind)
			cells.append("%s (%s)" % [kind, answers[key]["text"] if answers.has(key) else "-"])
		lines.append("matchup_lab: hard cells %s: %s" % [pilot, ", ".join(cells) if not cells.is_empty() else "none"])
	var g := gate_hard(table)
	lines.append("matchup_lab: gate every pilot has a hard cell: %s%s" % ["PASS" if g["ok"] else "FAIL", "" if g["ok"] else " (missing: %s)" % ", ".join(g["missing"])])
	lines.append("matchup_lab: gate brawler wins each hard cell with its answer item: %s" % _answer_gate_word(answers))
	lines.append("matchup_lab: gate verdict %s" % gate_verdict(table, answers))
	return lines


static func _answer_gate_word(answers: Dictionary) -> String:
	var pending := 0
	var lost := 0
	for key in answers:
		if answers[key]["status"] == "pending":
			pending += 1
		elif answers[key]["status"] == "lost":
			lost += 1
	if lost > 0:
		return "FAIL (%d lost)" % lost
	if pending > 0:
		return "INCONCLUSIVE (%d of %d hard cells pending; %s)" % [pending, answers.size(), PENDING]
	return "PASS"


# True when any row shows the enemy hurting the ball: a hit, damage taken or hull lost.
static func damage_seen(rows: Array) -> bool:
	for r in rows:
		if float(r.get("hits", 0.0)) > 0.0 or float(r.get("damage_taken", 0.0)) > 0.0 or float(r.get("hull_lost", 0.0)) > 0.0:
			return true
	return false


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	return float(sorted[mid]) if sorted.size() % 2 == 1 else (float(sorted[mid - 1]) + float(sorted[mid])) * 0.5


# ---- Child: one duel --------------------------------------------------------------------

func _begin_child() -> void:
	_pilot = String(_settings.get("pilot", ""))
	_kind = String(_settings["kind"])
	if BotDriver.class_index_for(0, _pilot) < 0 or not _settings.has("result") or not _settings.has("home"):
		printerr("matchup_lab: a child needs a known --pilot, --kind, --result and --home")
		quit(2)
		return
	_run_seed = int(_settings.get("run-seed", "1"))
	if PERCH_SEP in _kind:
		_perched = perched_mode(_kind)
		if _perched == "" or String(_settings.get("perched", _perched)) != _perched:
			printerr("matchup_lab: a perched child needs --kind=dispatcher@park|mast and a matching --perched")
			quit(2)
			return
	if _kind.begins_with(PACK_PREFIX):
		_pack_mode = true
		_pack_id = _kind.substr(PACK_PREFIX.length())
		_table_id = String(_settings.get("pack-table", "park"))
		_pack_members = pack_kinds(_table_id, _pack_id)
		if _pack_members.is_empty():
			printerr("matchup_lab: unknown pack %s on the %s table" % [_pack_id, _table_id])
			quit(2)
			return
	node_added.connect(_on_node_added)
	seed(_run_seed)
	_game = Game.new()
	_game.test_mode = true
	if _perched != "":
		_game.table = "park"
	root.add_child(_game)


func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	if _spawned and node.get_script() == TelegraphScript and node.get_parent() == _game:
		_warnings += 1
	if "_strafe" in node:
		node.set_meta("bot_strafe", 1.0 if (_counter_serial + _run_seed) % 2 == 0 else -1.0)
		_counter_serial += 1
	if node.get_parent() == _game.build.scrap:
		node.set_meta("bot_side", 1.0 if (_scrap_serial + _run_seed) % 2 == 0 else -1.0)
		_scrap_serial += 1


func _physics_process(delta: float) -> bool:
	if _parent or _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_game.ctx.calm = true
		var home := String(_settings["home"])
		_game.codex.storage_dir = home
		_game.run_log.storage_dir = home
		# The brawler bot: the completionist profile, which fights with every verb it has.
		_driver = DuelDriver.new(_game, "brawler", _run_seed)
		_driver.class_index = BotDriver.class_index_for(0, _pilot)
		_driver.dodge = float(_settings.get("dodge", str(DODGE)))
		_driver.idle = String(_settings.get("idle", "0")) == "1"
		_driver._dodge_rng.seed = hash(["dodge", _run_seed])
		_driver.stage_limit = INF
		# The calm map's beacon charges from the start (the ball begins in its ring; ctx.calm does not
		# stop beacon.advance) and a full charge runs gates, launch and the next stage, which frees the
		# duel's enemies (a long pack duel read `killed` with ttk -1 and duel_s -10.61). Pin the
		# beacon out of reach so no duel can leave its stage; the stage guard below is the backstop.
		_game.flow.beacon_seconds_override = BEACON_PIN_S
		_game.presentation.audio.bake_now()
		_bot_options.apply_audio(_game.presentation.audio)
		_game.events.player_hit.connect(func(amount: float, _source: String):
			if _spawned:
				_hits += 1
				_taken += amount)
		_game.ctx.events.enemy_spawned.connect(_on_enemy_spawned)
		_game.run.run_seed_override = _run_seed
		_driver.start()
		return false
	if not _spawned:
		if _relocated:
			# Perched duel: hold the relocated ball at its standoff (no level spot exists near the tops), zeroing
			# its velocity every frame with the player's own set_velocity_now until the spawn.
			_game.player.set_velocity_now(Vector3.ZERO, "matchup_lab")
			_held = true
		var down: bool = _game.flow.in_stage() and _game.player.state.grounded
		if down:
			_landed_s += delta
		var slow: bool = _game.player.planar_velocity().length() < REST_SPEED
		_grounded_s = _grounded_s + delta if down and slow else 0.0
		if _landed_s >= REST_WAIT_S and not _rest_forced and _grounded_s <= 0.0:
			_rest_forced = true
			_game.player.set_velocity_now(Vector3.ZERO, "matchup_lab")
		if _grounded_s >= SETTLE_S or _landed_s >= SETTLE_MAX_S:
			if _perched != "" and not _perch_chosen:
				_perch_chosen = true
				var step := _choose_perch()
				if step == "no_perch":
					_no_perch = true
					_done = true
					_record()
					_game.free()
					_game = null
					quit(0)
					return false
				if step == "relocated":
					# The ball was moved: rest-start again from its new spot before spawning.
					_grounded_s = 0.0
					_landed_s = 0.0
					_rest_forced = false
					_driver.source.hold = {}
					return false
			_settle_s = _landed_s
			_spawn_duel()
		else:
			_driver.source.hold = {}
			return false
	var over: bool = _driver.tick(delta)
	var t := _duel_s()
	if not over and (_game.run.stage != _spawn_stage or _game.run.stage_time < _start_s):
		# The stage changed under the duel: its enemies were freed, so "cleared" would be false.
		_stage_changed = true
		_driver._end("stage_changed")
		over = true
	# A freed object compares equal to null, so the duel's own flag says the enemy was ever set.
	if _pack_mode:
		if _first_down_s < 0.0 and _enemy_set:
			for m in _driver.members:
				if not DuelDriver.alive(m):
					_first_down_s = t
					break
	elif _kill_s < 0.0 and _enemy_set and not DuelDriver.alive(_driver.enemy):
		_kill_s = t
		_kill_dist = _last_dist
		_dispatcher_down_s = t
	elif not _pack_mode and DuelDriver.alive(_driver.enemy):
		_last_dist = _game.player.ball_position().distance_to(_driver.enemy.global_position)
		if _perched != "":
			_snapshot(_driver.enemy)
	if not over and _cleared():
		if _pack_mode and _kill_s < 0.0:
			_kill_s = t
		_driver._end("killed")
		over = true
	if not over and t >= _cap:
		_driver._end("capped")
		over = true
	if not over:
		return false
	_done = true
	_record()
	_game.free()
	_game = null
	quit(0)
	return false


func _on_enemy_spawned(enemy: Node3D, _k: String) -> void:
	# spawn_enemy emits this before it returns, so the duel's own enemy is not yet assigned.
	if _collecting:
		if enemy not in _driver.members:
			_driver.members.append(enemy)
		return
	if _spawned and _enemy_set and enemy != _driver.enemy and enemy not in _driver.adds:
		_driver.adds.append(enemy)
		_joined += 1


func _duel_s() -> float:
	return _game.run.stage_time - _start_s


# Won means the enemy and anything it made are down and nothing is still to come.
func _cleared() -> bool:
	if not _game.get_tree().get_nodes_in_group("enemy_pending").is_empty():
		return false
	for add in _driver.adds:
		if DuelDriver.alive(add):
			return false
	for m in _driver.members:
		if DuelDriver.alive(m):
			return false
	return not DuelDriver.alive(_driver.enemy)


func _spawn_duel() -> void:
	_spawned = true
	_start_s = _game.run.stage_time
	_spawn_stage = _game.run.stage
	_hull_start = float(_game.run.metrics["hull_damage"])
	# ctx.calm gates the Warden, the director's packs, flood and event pushes, and hit knockback in
	# combat; it does not gate an enemy's attack or the damage it deals (combat._on_player_hit
	# always calls run.damage). Turning it off here let director packs join and swamp the duel
	# (joined 12 to 27 in a 40 s duel), so it stays on and the enemy under test attacks under the
	# game's own rules. The hull is deep enough to measure a lost duel.
	_game.run.set_max_hp(HULL_POOL)
	if _settings.has("give"):
		_game.run.add_part(String(_settings["give"]), "matchup_lab")
	var ball: Vector3 = _game.player.ball_position()
	var forward: Vector3 = _game.ctx.aim_forward()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	if forward.length() < 0.5:
		forward = Vector3.FORWARD
	var flat: Vector3 = ball + forward * float(_settings.get("range", str(PACK_RANGE if _pack_mode else DUEL_RANGE)))
	if _pack_mode:
		_spawn_pack(flat, forward)
		return
	if _perched != "":
		_spawn_perched(ball)
		return
	_driver.enemy = _game.combat.spawn_enemy(_kind, _game.ctx.terrain.drop_point(flat.x, flat.z, 1.8))
	_enemy_set = true


# ---- Perched duel (child) ---------------------------------------------------------------

# Every perch top of the stage with its source: [{"top": Vector3, "source": "post"|"ledge"}], sorted
# by position. These are the two sources PerchPoints has on this base (anchor-field post tops and
# landform tops), filtered by the same validity rules pick() applies. Empty off a ParkMap.
func _all_tops() -> Array:
	var terrain = _game.ctx.terrain
	var m = terrain.map()
	if not (m is ParkMap) or not m.ok:
		return []
	var ground := Callable(terrain, "height")
	var blocked := PerchPoints.blockers(m.park)
	var out := []
	for top: Vector3 in PerchPoints.derive(m.park, ground):
		if PerchPoints.valid(top, ground, blocked):
			out.append({"top": top, "source": "post", "base_rise": top.y - float(ground.call(top.x, top.z))})
	for ledge: Vector4 in PerchPoints.ledges(m.park, ground):
		if PerchPoints.valid_ledge(ledge):
			out.append({"top": Vector3(ledge.x, ledge.y, ledge.z), "source": "ledge", "base_rise": ledge.y - ledge.w})
	return out


# Chooses this seed's perch top. "near": the terrain's own pick was within reach of the resting ball.
# "relocated": none was, so the ball was moved to a flat standoff `--range` from a top chosen from
# the whole stage by the seed. "no_perch": the stage has no top at all.
func _choose_perch() -> String:
	var terrain = _game.ctx.terrain
	var tops := _all_tops()
	var ball: Vector3 = _game.player.ball_position()
	var salt := hash(["perch", _run_seed])
	var near: Vector3 = terrain.perch_near(ball, salt)
	if near.x != INF:
		_perch_top = near
	elif tops.is_empty():
		return "no_perch"
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["perch_pick", _run_seed])
		_perch_top = tops[rng.randi_range(0, tops.size() - 1)]["top"]
		var found := _standoff(_perch_top, float(_settings.get("range", str(PERCH_RANGE))), rng.randf() * TAU)
		var spot: Vector2 = found["p"]
		_standoff_m = found["dist"]
		_standoff_ok = found["ok"]
		_game.player.reset_to(terrain.drop_point(spot.x, spot.y, 1.05))
		_relocated = true
	for entry in tops:
		if (entry["top"] as Vector3).is_equal_approx(_perch_top):
			_perch_source = entry["source"]
			_perch_base_rise = float(entry["base_rise"])
	return "relocated" if _relocated else "near"


# A level, landform-clear spot for the ball: bearings (16, from `start`) at `distance`, then the radius
# stepped out by STANDOFF_STEP_M up to STANDOFF_REACH_M past it. The first spot whose ground spread over
# STANDOFF_PROBES is within STANDOFF_FLAT_M, clear of landforms and PERCH_MIN under the top wins (ok = true).
# When none is, the best of: under the top, then clear, then least spread, is used with ok = false: the run
# still goes, marked. Returns {p (x, z), dist, ok}.
func _standoff(top: Vector3, distance: float, start: float) -> Dictionary:
	var terrain = _game.ctx.terrain
	var m = terrain.map()
	var blocked: Array = PerchPoints.blockers(m.park) if m is ParkMap and m.ok else []
	var steps := int(STANDOFF_REACH_M / STANDOFF_STEP_M)
	var best := {"p": Vector2(top.x, top.z) + Vector2(cos(start), sin(start)) * distance, "dist": distance, "ok": false}
	var best_score := INF
	for r in range(steps + 1):
		var dist := distance + STANDOFF_STEP_M * r
		for k in STANDOFF_BEARINGS:
			var a := start + TAU * k / float(STANDOFF_BEARINGS)
			var p := Vector2(top.x, top.z) + Vector2(cos(a), sin(a)) * dist
			var lo := INF
			var hi := -INF
			for d in STANDOFF_PROBES:
				var h: float = terrain.height(p.x + d.x, p.y + d.y)
				lo = minf(lo, h)
				hi = maxf(hi, h)
			var clear := not ParkRecipes.in_clear(blocked, p, STANDOFF_CLEAR_M)
			# The top must stand PERCH_MIN over the ground the ball is held on: stamped landforms are terrain,
			# not blockers, so a spot can lie on the same plateau as a ledge top (a Dispatcher 2 m over the ball).
			var under: bool = top.y - float(terrain.height(p.x, p.y)) >= PerchPoints.PERCH_MIN
			if under and clear and hi - lo <= STANDOFF_FLAT_M:
				return {"p": p, "dist": dist, "ok": true}
			var score := (hi - lo) + (0.0 if clear else 1000.0) + (0.0 if under else 10000.0)
			if score < best_score:
				best_score = score
				best = {"p": p, "dist": dist, "ok": false}
	return best


# The Dispatcher goes on the chosen top: `park` passes it as the spawn's perch (no mast built);
# `mast` leaves the arg off so the Dispatcher builds its own mast at the top's flat spot.
func _spawn_perched(ball: Vector3) -> void:
	var terrain = _game.ctx.terrain
	var at: Vector3 = terrain.drop_point(_perch_top.x, _perch_top.z, 1.8)
	if _perched == "park":
		_driver.enemy = _game.combat.spawn_enemy(PERCHED_KIND, at, "", _perch_top)
	else:
		_driver.enemy = _game.combat.spawn_enemy(PERCHED_KIND, at)
	_enemy_set = true
	_ball_to_perch = Vector2(ball.x, ball.z).distance_to(Vector2(_perch_top.x, _perch_top.z))
	_snapshot(_driver.enemy)
	_perch_over_ball = _driver.enemy.global_position.y - float(terrain.height(ball.x, ball.z))
	_perched_under = _perch_over_ball >= PerchPoints.PERCH_MIN
	_perch_rise = float(_driver.enemy.perch_height()) if _driver.enemy.has_method("perch_height") else -1.0
	_mast_built = _driver.enemy.get("mast") != null


# The Dispatcher's own counters, kept each tick while it lives (it is freed at death).
func _snapshot(enemy: Node3D) -> void:
	_snap = {"drops": int(enemy.get("drops")), "landed_hits": int(enemy.get("landed_hits")), "escalation": int(enemy.get("escalation"))}


# The pack side by side across the line, centered offsets like Director._place_pack. Members the
# roster has not built are skipped and recorded. Anything a member makes while it spawns joins the pack.
func _spawn_pack(center: Vector3, forward: Vector3) -> void:
	var side := Vector3(-forward.z, 0.0, forward.x)
	_collecting = true
	for i in _pack_members.size():
		var kind: String = _pack_members[i]
		if not Roster.ROWS.has(kind) or not Roster.built(kind):
			_pack_skipped.append(kind)
			continue
		var spot: Vector3 = center + side * Director.PACK_SPREAD * (float(i) - float(_pack_members.size() - 1) * 0.5)
		var enemy = _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(spot.x, spot.z, 1.8))
		if enemy != null:
			_pack_spawned += 1
			if enemy not in _driver.members:
				_driver.members.append(enemy)
	_collecting = false
	_enemy_set = true


func _record() -> void:
	var lost: float = float(_game.run.metrics["hull_damage"]) - _hull_start if _spawned else 0.0
	var outcome: String = "no_perch" if _no_perch else (pack_outcome(_pack_spawned, _driver.outcome) if _pack_mode else _driver.outcome)
	var killed: bool = _kill_s >= 0.0 and outcome == "killed"
	var row := {"pilot": _pilot, "class": _driver.class_id(), "kind": _kind, "seed": _run_seed, "give": String(_settings.get("give", "")),
			"outcome": outcome, "ttk_s": snappedf(_kill_s if killed else -1.0, 0.01), "hull_lost": snappedf(lost, 0.1),
			"kill_dist_m": snappedf(-1.0 if _stage_changed else _kill_dist, 0.1), "hits": _hits, "damage_taken": snappedf(_taken, 0.1), "warnings": _warnings, "joined": _joined,
			"duel_s": snappedf(_duel_s() if _spawned else 0.0, 0.01), "settle_s": snappedf(_settle_s, 0.01), "rest_forced": _rest_forced, "stage_changed": _stage_changed}
	if _perched != "":
		row["perched"] = _perched
		row["perch"] = [snappedf(_perch_top.x, 0.01), snappedf(_perch_top.y, 0.01), snappedf(_perch_top.z, 0.01)] if _perch_top.x != INF else []
		row["perch_source"] = _perch_source
		row["perch_rise_m"] = snappedf(_perch_rise, 0.01)
		row["perch_base_rise_m"] = snappedf(_perch_base_rise, 0.01)
		row["ball_to_perch_m"] = snappedf(_ball_to_perch, 0.1)
		row["mast_built"] = _mast_built
		row["dispatcher_down_s"] = snappedf(-1.0 if _stage_changed else _dispatcher_down_s, 0.01)
		row["drops"] = int(_snap.get("drops", 0))
		row["landed_hits"] = int(_snap.get("landed_hits", 0))
		row["escalation"] = int(_snap.get("escalation", 0))
		row["relocated"] = _relocated
		row["standoff_m"] = snappedf(_standoff_m, 0.1)
		row["standoff_ok"] = _standoff_ok
		row["held"] = _held
		row["perched_under"] = _perched_under
		row["perch_over_ball_m"] = snappedf(_perch_over_ball, 0.01)
	if _pack_mode:
		row["pack"] = _pack_id
		row["members"] = _pack_members
		row["table"] = _table_id
		row["spawned"] = _pack_spawned
		row["skipped"] = _pack_skipped
		row["first_down_s"] = snappedf(-1.0 if _stage_changed else _first_down_s, 0.01)
	var file := FileAccess.open(String(_settings["result"]), FileAccess.WRITE)
	file.store_string(JSON.stringify(row) + "\n")
	file.close()
