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
const ClassDef := preload("res://src/core/class_def.gd")
const Dials := preload("res://src/core/challenge_dials.gd")
const PocketArena := preload("res://tools/pocket_arena.gd")
const PocketTerrain := preload("res://tools/pocket_terrain.gd")

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
#   pocket sweep: -- --out=<abs ndjson> --pocket=<half_pipe|rolling_wall|crevice|hazard_field|rail_grove|all>
#     [--mobility=ground,flyer,burrower,hop] [--seeds=1,2,3,4,5] [--runs=3] [--plant=pilot_helpless=1|packs_passive=1|pack_damage=4] ...
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
	"bola_thrower": "cc", "gyro_jammer": "cc", "ramp_flipper": "cc", "swatter": "cc", "pit_jaw": "cc", "gap_net": "cc", "boom_tender": "cc",
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
const NO_RESULT := ["no_result", "wall_timeout", "stage_changed", "no_perch", "not_perched"]
# Pocket sweep (--pocket): a lab pocket (tools/lab_pockets) is the arena, a pack of three of one enemy kind is the
# opponent, and the verdict per cell is the pilot's win rate. The row key is `pocket:<shape>/<enemy>`.
const POCKET_PREFIX := "pocket:"
const POCKET_SEP := "/"
const POCKET_PACK := 3
const POCKET_SEEDS := [1, 2, 3, 4, 5]
const POCKET_RUNS := 3
# A repeat run of one seed reseeds the run stream by this much per run index, so the three runs of a seed differ.
const POCKET_RUN_STRIDE := 1000
# The page's mobility kinds. Hop is "my grouping, not a code field": roster.gd MOVE_CLASSES lists only fixed, ground and
# airborne, so no enemy kind hops and its cells are an explicit n/a.
const POCKET_COLUMNS := [
	{"id": "ground", "enemies": ["chaser"], "na": ""},
	{"id": "flyer", "enemies": ["kite_drone", "winch_drone"], "na": ""},
	{"id": "burrower", "enemies": ["burrower"], "na": ""},
	{"id": "hop", "enemies": [], "na": "no enemy kind hops (roster MOVE_CLASSES: fixed, ground, airborne)"},
]
# Test-only plants (the controls): `pilot_helpless=1` stands the pilot still (the --idle duel) and makes every enemy hit
# HELPLESS_DAMAGE times as hard, so the first hit runs the hull out and the cell must read a 0% flag (idle alone is not
# enough: a chaser pack blows itself up on a still ball, half_pipe 15 of 15 kills); `packs_passive=1` zeroes the mobs.damage dial (the packs still attack but cannot hurt) and
# must drive a cell to 100%. `pack_damage=<k>` multiplies every enemy hit through that dial; it is kept as a probe, not
# a control: pilots kill a pack of three in 1 to 7 s and take 0 or 1 hits, so x4 cannot reach 0%. Absent, nothing
# changes.
const PLANT_DIAL := "mobs.damage_mult"
const HELPLESS_DAMAGE := 50.0
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
var _pass_source: PassSource
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
var _early := ""
var _relocated := false
var _perch_top := Vector3.INF
var _perch_source := "unknown"
var _perch_base_rise := -1.0
var _standoff_m := -1.0
var _standoff_ok := false
var _standoff_clear := false
var _standoff_at := Vector2.ZERO
var _held := false
var _perched_under := false
var _perch_over_ball := -1.0
var _ball_to_perch := -1.0
var _perch_rise := -1.0
var _mast_built := false
var _snap := {}
var _dispatcher_down_s := -1.0
# Pocket duel state (child).
var _pocket := ""
var _pocket_enemy := ""
var _arena
var _real_max_hull := -1.0
var _plant := {}
var _pocket_slots: Array = []
var _kill_order: Array = []
var _hull_out := false
var _base_seed := 0
var _run_index := 0
var _pocket_spots: Array = []
# Pocket sweep state (parent).
var _pocket_mode := false
var _pocket_shapes: Array = []
var _pocket_columns: Array = []
var _pocket_runs := POCKET_RUNS


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	_bot_options = BotOptions.new(_settings, self)
	_cap = float(_settings.get("cap", "40"))
	if _settings.has("pass-job"):
		_run_pass.call_deferred()
		return
	if _settings.has("pass") and not _settings.has("bosses"):
		_begin_pass_table()
		return
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
	if _settings.has("pocket"):
		_begin_pocket_parent()
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
	var pocket_rows := rows.filter(func(r): return String(r.get("kind", "")).begins_with(POCKET_PREFIX))
	if not pocket_rows.is_empty():
		# A control shard pooled with a real shard would read as one cell: refuse a mix of plants.
		var plants := {}
		for r in pocket_rows:
			plants[String(r.get("plant", ""))] = true
		if plants.size() > 1:
			printerr("matchup_lab: --from mixes pocket rows with different plants %s; merge each plant apart" % [plants.keys()])
			quit(2)
			return
		_write_pocket(pocket_rows, [])
		quit(0)
		return
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


# Heatmap labels for `kinds`: row_label, with a numeric suffix on any label two rows share
# (`+plate_pr` twice reads `+plate_pr` and `+plate_p2`).
static func row_labels(kinds: Array) -> Dictionary:
	var used := {}
	var out := {}
	for kind in kinds:
		var label := row_label(String(kind))
		var n := 1
		while used.has(label):
			n += 1
			var tail := str(n)
			label = row_label(String(kind)).substr(0, 9 - tail.length()) + tail
		used[label] = true
		out[kind] = label
	return out


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


# ---- Pocket sweep: pure parts ------------------------------------------------------------

# The row key of one pocket x enemy duel: `pocket:half_pipe/chaser`.
static func pocket_key(shape: String, enemy: String) -> String:
	return POCKET_PREFIX + shape + POCKET_SEP + enemy


# {shape, enemy} of a row key, or {} for any other kind or an unknown shape.
static func pocket_parts(key: String) -> Dictionary:
	if not key.begins_with(POCKET_PREFIX) or POCKET_SEP not in key:
		return {}
	var parts := key.substr(POCKET_PREFIX.length()).split(POCKET_SEP)
	if parts.size() != 2 or not PocketArena.valid(parts[0]) or parts[1] == "":
		return {}
	return {"shape": parts[0], "enemy": parts[1]}


# The column an enemy kind sits in ("" when none lists it).
static func pocket_column_of(enemy: String) -> String:
	for column in POCKET_COLUMNS:
		if enemy in column["enemies"]:
			return String(column["id"])
	return ""


# The pilot of run `run` of seed `seed_value`: the band harness's seed rotation (class index = seed modulo the roster),
# stepped one class per repeat, so the three runs of a seed are three classes, not one run three times.
static func pocket_pilot(seed_value: int, run: int, roster: Array) -> String:
	return String(roster[(seed_value + run) % roster.size()])


# The rng seed of a run: the seed itself for the first run (so a seed's first run is the plain seed), then stepped.
static func pocket_rng_seed(seed_value: int, run: int) -> int:
	return seed_value + POCKET_RUN_STRIDE * run


# Every duel job of a sweep, in shape, column, enemy, seed, run order. Hop (no enemies) queues nothing.
static func pocket_jobs(shapes: Array, columns: Array, seeds: Array, runs: int, roster: Array) -> Array:
	var jobs := []
	for shape in shapes:
		for column in POCKET_COLUMNS:
			if String(column["id"]) not in columns:
				continue
			for enemy in column["enemies"]:
				for seed_value in seeds:
					for run in runs:
						jobs.append({"n": jobs.size(), "pilot": pocket_pilot(int(seed_value), run, roster), "kind": pocket_key(shape, enemy),
								"seed": pocket_rng_seed(int(seed_value), run), "base_seed": int(seed_value), "run": run, "give": ""})
	return jobs


# Who won a pocket duel. The pilot wins iff it killed the whole pack and its hull_lost stayed under the class's real max
# hull; anything else the enemy wins (the hull ran out first, the cap passed, the pilot died). "void" is a run that
# measured nothing (no result, wall timeout, stage change, or no real max hull to compare to).
static func pocket_winner(row: Dictionary) -> String:
	var outcome := String(row.get("outcome", "no_result"))
	var cap_hull := float(row.get("real_max_hull", -1.0))
	if outcome in NO_RESULT or cap_hull <= 0.0:
		return "void"
	# A pack that did not spawn whole measured a smaller fight than the cell's.
	if row.has("spawned") and int(row["spawned"]) != POCKET_PACK:
		return "void"
	if outcome == "killed" and float(row.get("hull_lost", 0.0)) < cap_hull:
		return "pilot"
	return "enemy"


# One cell from its rows: the pilot's win rate over the runs that measured something, and the retune flag
# (0% or 100%, the map page's rule). `flag_kind` is "low" at 0%, "high" at 100%, else "". `wins`, `n` (non-void),
# `void` and `runs` are counts.
static func pocket_cell(rows: Array) -> Dictionary:
	var wins := 0
	var n := 0
	var voided := 0
	for r in rows:
		match pocket_winner(r):
			"pilot":
				wins += 1
				n += 1
			"enemy":
				n += 1
			_:
				voided += 1
	var rate := float(wins) / float(n) if n > 0 else -1.0
	var kind := ""
	if n > 0 and wins == 0:
		kind = "low"
	elif n > 0 and wins == n:
		kind = "high"
	return {"na": false, "win_rate": rate, "wins": wins, "n": n, "void": voided, "runs": rows.size(), "flag": kind != "", "flag_kind": kind}


# The table: shapes x columns. A column with no enemy kind is an explicit n/a cell (`na` true, with the reason). A
# column with several (flyer) carries its sub-rows in `rows`, each its own cell; the column's cell pools them and
# is flagged when any sub-row is.
static func pocket_table(rows: Array, shapes: Array, columns: Array = []) -> Dictionary:
	var out := {"shapes": shapes.duplicate(), "columns": [], "cells": {}}
	for column in POCKET_COLUMNS:
		if columns.is_empty() or String(column["id"]) in columns:
			out["columns"].append(String(column["id"]))
	for shape in shapes:
		out["cells"][shape] = {}
		for column in POCKET_COLUMNS:
			var id := String(column["id"])
			if id not in out["columns"]:
				continue
			if (column["enemies"] as Array).is_empty():
				out["cells"][shape][id] = {"na": true, "reason": String(column["na"]), "win_rate": -1.0, "wins": 0, "n": 0, "void": 0, "runs": 0, "flag": false, "flag_kind": "", "rows": {}}
				continue
			var pooled := []
			var subs := {}
			for enemy in column["enemies"]:
				var sub_rows := rows.filter(func(r): return String(r.get("kind", "")) == pocket_key(shape, enemy))
				subs[enemy] = pocket_cell(sub_rows)
				pooled.append_array(sub_rows)
			var cell := pocket_cell(pooled)
			var flagged := []
			var kinds := []
			for enemy in subs:
				if subs[enemy]["flag"]:
					flagged.append("%s %s" % [enemy, subs[enemy]["flag_kind"]])
					if subs[enemy]["flag_kind"] not in kinds:
						kinds.append(subs[enemy]["flag_kind"])
			cell["flag"] = not flagged.is_empty()
			cell["flag_kind"] = "" if kinds.is_empty() else (kinds[0] if kinds.size() == 1 else "mixed")
			cell["flagged_rows"] = flagged
			cell["rows"] = subs
			out["cells"][shape][id] = cell
	return out


static func _cell_text(cell: Dictionary) -> String:
	if cell["na"]:
		return "n/a"
	var rows: Dictionary = cell.get("rows", {})
	if rows.size() > 1:
		var parts := []
		for enemy in rows:
			parts.append("%s %s" % [enemy, _rate_text(rows[enemy])])
		return " / ".join(parts)
	return _rate_text(cell)


static func _rate_text(cell: Dictionary) -> String:
	if int(cell["n"]) == 0:
		return "- (n=0, void %d)" % int(cell["void"])
	var text := "%d%% (n=%d)" % [int(round(float(cell["win_rate"]) * 100.0)), int(cell["n"])]
	if int(cell["void"]) > 0:
		text += " void %d" % int(cell["void"])
	if cell["flag"]:
		text += " FLAG retune (%s)" % ("0%" if cell["flag_kind"] == "low" else "100%")
	return text


# The table as markdown lines: pilot win rate per cell, n, and the retune flag.
static func pocket_markdown(table: Dictionary) -> Array:
	var lines := ["Pilot win rate per cell (the pilot kills the whole pack of %d inside the cap with hull lost under the class's real max hull). n counts runs that measured something. FLAG marks a 0%% or 100%% cell (retune)." % POCKET_PACK, ""]
	var head := "| pocket |"
	var rule := "|---|"
	for id in table["columns"]:
		head += " %s |" % id
		rule += "---|"
	lines.append(head)
	lines.append(rule)
	for shape in table["shapes"]:
		var line := "| %s |" % shape
		for id in table["columns"]:
			line += " %s |" % _cell_text(table["cells"][shape][id])
		lines.append(line)
	return lines


# Parses --plant=<name>=<value>. {ok, name, value, dials (the ChallengeDials override), expect ("low" or "high" for the
# canonical control values, else ""), error}. No spec is the identity: no dial, no expectation.
static func pocket_plant(spec: String) -> Dictionary:
	if spec == "":
		return {"ok": true, "name": "", "value": 0.0, "dials": {}, "expect": "", "error": ""}
	var eq := spec.find("=")
	var name := spec.substr(0, eq) if eq > 0 else spec
	var raw := spec.substr(eq + 1) if eq > 0 else ""
	if not raw.is_valid_float():
		return {"ok": false, "name": name, "value": 0.0, "dials": {}, "expect": "", "error": "--plant needs <name>=<number>, got '%s'" % spec}
	var value := float(raw)
	match name:
		"pack_damage":
			if value <= 1.0:
				return {"ok": false, "name": name, "value": value, "dials": {}, "expect": "", "error": "--plant=pack_damage needs a factor over 1"}
			return {"ok": true, "name": name, "value": value, "dials": {PLANT_DIAL: value}, "expect": "", "error": ""}
		"pilot_helpless":
			if value != 1.0:
				return {"ok": false, "name": name, "value": value, "dials": {}, "expect": "", "error": "--plant=pilot_helpless takes 1"}
			return {"ok": true, "name": name, "value": value, "dials": {PLANT_DIAL: HELPLESS_DAMAGE}, "expect": "low", "error": ""}
		"packs_passive":
			if value != 1.0:
				return {"ok": false, "name": name, "value": value, "dials": {}, "expect": "", "error": "--plant=packs_passive takes 1"}
			return {"ok": true, "name": name, "value": value, "dials": {PLANT_DIAL: 0.0}, "expect": "high", "error": ""}
	return {"ok": false, "name": name, "value": value, "dials": {}, "expect": "", "error": "unknown --plant %s (pilot_helpless=1, packs_passive=1, pack_damage=<k>)" % name}


# The control's reading: the planted cell must carry the plant's expected flag (0% for pack_damage, 100% for packs_passive).
static func pocket_control_ok(plant: Dictionary, cell: Dictionary) -> bool:
	return String(plant.get("expect", "")) != "" and not bool(cell.get("na", false)) and String(cell["flag_kind"]) == String(plant["expect"])


# ---- Pocket sweep: parent ----------------------------------------------------------------

func _begin_pocket_parent() -> void:
	var shapes := PocketArena.SHAPES.duplicate() if String(_settings["pocket"]) == "all" else Array(String(_settings["pocket"]).split(",", false))
	for shape in shapes:
		if not PocketArena.valid(shape):
			printerr("matchup_lab: unknown --pocket %s (%s or all)" % [shape, "|".join(PocketArena.SHAPES)])
			quit(2)
			return
	var columns := []
	for id in String(_settings.get("mobility", "ground,flyer,burrower,hop")).split(",", false):
		var known := POCKET_COLUMNS.any(func(c): return String(c["id"]) == id)
		if not known:
			printerr("matchup_lab: unknown --mobility %s (ground, flyer, burrower, hop)" % id)
			quit(2)
			return
		columns.append(id)
	var plant := pocket_plant(String(_settings.get("plant", "")))
	if not plant["ok"]:
		printerr("matchup_lab: %s" % plant["error"])
		quit(2)
		return
	var seeds := []
	for part in String(_settings.get("seeds", ",".join(POCKET_SEEDS.map(func(v): return str(v))))).split(",", false):
		seeds.append(int(part))
	_pocket_runs = maxi(1, int(_settings.get("runs", str(POCKET_RUNS))))
	_pocket_shapes = shapes
	_pocket_columns = columns
	var roster: Array = ClassDef.all().map(func(c): return String(c.id))
	_queue = pocket_jobs(shapes, columns, seeds, _pocket_runs, roster)
	_total = _queue.size()
	_procs = clampi(int(_settings.get("procs", "4")), 1, 8)
	_sweep_dir = OS.get_user_data_dir().path_join("matchup_lab").path_join("p%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_sweep_dir)
	_pocket_mode = true
	_parent = true


# Writes the pocket table beside the rows (markdown and JSON) and prints it. `rows` is every pocket row.
func _write_pocket(rows: Array, columns: Array) -> void:
	var shapes := []
	for shape in PocketArena.SHAPES:
		if rows.any(func(r): return String(r.get("kind", "")).begins_with(POCKET_PREFIX + shape + POCKET_SEP)) or shape in _pocket_shapes:
			shapes.append(shape)
	var table := pocket_table(rows, shapes, columns)
	var plant := pocket_plant(String(_settings.get("plant", "")))
	table["plant"] = _settings.get("plant", "")
	table["cap_s"] = _cap
	table["pack"] = POCKET_PACK
	var lines := pocket_markdown(table)
	if plant["ok"] and plant["expect"] != "":
		var verdicts := []
		for shape in shapes:
			for id in table["columns"]:
				var cell: Dictionary = table["cells"][shape][id]
				if not cell["na"]:
					verdicts.append("%s/%s %s" % [shape, id, "control reads %s" % ("PASS" if pocket_control_ok(plant, cell) else "FAIL")])
		lines.append("")
		lines.append("Plant %s expects a %s flag: %s" % [_settings["plant"], "0%" if plant["expect"] == "low" else "100%", "; ".join(verdicts)])
	for line in lines:
		print(line)
	if not _settings.has("out"):
		return
	var path := String(_settings["out"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if _parent:
		var file := FileAccess.open(path, FileAccess.WRITE)
		for r in rows:
			file.store_line(JSON.stringify(r))
		file.close()
	var md := FileAccess.open(path.get_basename() + ".pocket.md", FileAccess.WRITE)
	for line in lines:
		md.store_line(line)
	md.close()
	var js := FileAccess.open(path.get_basename() + ".pocket.json", FileAccess.WRITE)
	js.store_string(JSON.stringify(table, "  ") + "\n")
	js.close()


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
		if int(run["pid"]) <= 0 or not OS.is_process_running(run["pid"]):
			_reap(run, false)
		elif float(Time.get_ticks_msec() - int(run["started"])) / 1000.0 > WALL_LIMIT_S:
			OS.kill(run["pid"])
			_reap(run, true)
	while _running.size() < _procs and not _queue.is_empty():
		_spawn(_queue.pop_front())
	if _running.is_empty() and _queue.is_empty():
		if not _settings.has("pass") and _phase == 1 and _begin_answer_phase():
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
	if job.has("pass"):
		args = PackedStringArray(["--log-file", home.path_join("engine.log")]) + args
		args.append_array(["--pass-job=" + String(job.pass), "--stage=%d" % job.stage,
			"--speed=%d" % job.speed, "--plant=" + String(job.plant)])
		return args
	if String(job["give"]) != "":
		args.append("--give=" + String(job["give"]))
	if settings.has("dodge"):
		args.append("--dodge=%s" % settings["dodge"])
	if settings.has("range"):
		args.append("--range=%s" % settings["range"])
	if settings.has("idle"):
		args.append("--idle=%s" % settings["idle"])
	# A game variant behind a ChallengeDials key (the pack pressure experiments): every duel plays it.
	if settings.has("tune"):
		args.append("--tune=%s" % settings["tune"])
	if String(job["kind"]).begins_with(PACK_PREFIX):
		args.append("--pack-table=" + table_id)
	if String(job["kind"]).begins_with(POCKET_PREFIX):
		args.append("--base-seed=%d" % int(job.get("base_seed", job["seed"])))
		args.append("--run=%d" % int(job.get("run", 0)))
		if settings.has("plant"):
			args.append("--plant=%s" % settings["plant"])
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
	var project := ProjectSettings.globalize_path("res://") if _pass_source == null else _pass_source.project
	var args := child_args(job, _cap, _settings, _table_id, home, project)
	if _pass_source != null:
		args.append_array(["--source-head=" + _pass_source.head, "--source-project=" + _pass_source.project])
	var previous := {}
	for kind in ["DATA", "CONFIG", "CACHE"]:
		var key: String = "XDG_%s_HOME" % kind
		previous[key] = OS.get_environment(key)
		OS.set_environment(key, home.path_join("state-" + kind.to_lower()))
	if OS.get_name() == "macOS" and job.has("pass"):
		previous["HOME"] = OS.get_environment("HOME")
		OS.set_environment("HOME", home)
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
	if run.has("pass"):
		var log_file := home.path_join("engine.log")
		var log_text := FileAccess.get_file_as_string(log_file) if FileAccess.file_exists(log_file) else ""
		if log_text.is_empty() or "SCRIPT ERROR:" in log_text or run.pid <= 0 or timed_out:
			result["outcome"] = "no_result"
			result["diagnostic"] = log_text.substr(maxi(0, log_text.find("SCRIPT ERROR:")), 300)
		for key in ["n", "stage", "pilot", "pass", "speed", "seed", "plant"]:
			if key == "n" or not result.has(key):
				result[key] = run[key]
		if not result.has("pack"):
			result["pack"] = run.kind
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
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	for sub in directory.get_directories():
		if directory.is_link(sub):
			directory.remove(sub)
		else:
			_remove_tree(path.path_join(sub))
	for file in directory.get_files():
		directory.remove(file)
	if DirAccess.remove_absolute(path) != OK:
		push_error("could not remove lab scratch directory: " + path)


# After the baseline table: for each hard cell, look up its answer item and queue the paired
# duels with it in hand. Returns true when jobs were queued. With no `answers` field on this
# base's part rows (or no row for a cell's axis) the cell is reported pending and nothing runs.
func _begin_answer_phase() -> bool:
	_phase = 2
	if _pocket_mode:
		return false
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
	if _settings.has("pass"):
		_write_pass_table()
		return
	if _pocket_mode:
		_write_pocket(_results, _pocket_columns)
		_remove_tree(_sweep_dir)
		quit(0)
		return
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
	return {"cells": cells, "pilots": pilots, "kinds": kinds, "row_median": row_median, "hard": hard, "cap": cap, "wall": wall_rows(cells, pilots, kinds)}


# WALL rows: at least one pilot ran the row and no pilot killed. Such a
# row's median is the cap, so the HARD rule (over 2.0 x the row median) can never flag it.
static func wall_rows(cells: Dictionary, pilots: Array, kinds: Array) -> Array:
	var out := []
	for kind in kinds:
		var ran := 0
		var killed := 0
		for pilot in pilots:
			var cell: Dictionary = cells[cell_key(pilot, kind)]
			if cell["runs"] > 0:
				ran += 1
			killed += int(cell["kills"])
		if ran > 0 and killed == 0:
			out.append(kind)
	return out


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
	if not gate_hard(table)["ok"] or not (table.get("wall", []) as Array).is_empty():
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
	var labels := row_labels(table["kinds"])
	for kind in table["kinds"]:
		var line := "%-9s%5.1f" % [labels[kind], table["row_median"][kind]]
		for pilot in pilots:
			var cell: Dictionary = table["cells"][cell_key(pilot, kind)]
			if cell["runs"] == 0:
				line += " %9s" % "-"
			else:
				line += " %9s" % ("%.1f%s[%d]" % [cell["median_ttk"], "*" if cell["hard"] else "", int(round(cell["median_hull"]))])
		if kind in table.get("wall", []):
			line += "  WALL"
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
	var wall: Array = table.get("wall", [])
	lines.append("matchup_lab: gate no wall row (a pilot ran it, no pilot killed): %s" % ("PASS" if wall.is_empty() else "FAIL (wall rows: %s)" % ", ".join(wall)))
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
	if _kind.begins_with(POCKET_PREFIX):
		var parts := pocket_parts(_kind)
		_plant = pocket_plant(String(_settings.get("plant", "")))
		if parts.is_empty() or not _plant["ok"] or not Roster.ROWS.has(parts["enemy"]) or not Roster.built(parts["enemy"]):
			printerr("matchup_lab: a pocket child needs --kind=pocket:<shape>/<built enemy kind> and a valid --plant (%s)" % _plant.get("error", ""))
			quit(2)
			return
		_pocket = parts["shape"]
		_pocket_enemy = parts["enemy"]
		_base_seed = int(_settings.get("base-seed", str(_run_seed)))
		_run_index = int(_settings.get("run", "0"))
		# A pocket duel is a pack duel of three of one kind on the pocket's far side: the pack bookkeeping is shared.
		_pack_mode = true
		_pack_id = _kind
		_pack_members = []
		for i in POCKET_PACK:
			_pack_members.append(_pocket_enemy)
		if not _plant["dials"].is_empty():
			Dials.set_overrides(_plant["dials"])
	elif _kind.begins_with(PACK_PREFIX):
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
	if _settings.has("pass-job") or _parent or _done or _game == null or _game.flow == null:
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
		_driver.idle = String(_settings.get("idle", "0")) == "1" or String(_plant.get("name", "")) == "pilot_helpless"
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
		if _pocket != "":
			_install_pocket()
		_driver.start()
		return false
	if not _spawned:
		if _pocket != "" and _game.flow.in_stage():
			# Pocket duel: the pilot starts at rest at the entry whatever the pocket's slope (the half pipe's floor falls 3%
			# and the drop-in's speed would carry the ball down the channel): hold it still until the spawn.
			_game.player.set_velocity_now(Vector3.ZERO, "matchup_lab")
			_held = true
		if _relocated:
			# Perched duel: hold the relocated ball at its standoff (it may not be level), zeroing
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
				if step == "no_perch" or step == "not_perched":
					# Ended before the spawn: nothing to fight. not_perched keeps its diagnostic fields on the row.
					_early = step
					_end_early()
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
			if _early != "":
				_end_early()
				return false
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
	if not over and _pocket != "" and _spawned and _real_max_hull > 0.0 and _hull_lost() >= _real_max_hull:
		# The pilot's real hull would have run out: the enemy won. The row says so and the duel ends.
		_hull_out = true
		_driver._end("hull_out")
		over = true
	# A freed object compares equal to null, so the duel's own flag says the enemy was ever set.
	if _pack_mode:
		if _pocket != "":
			_track_kills(t)
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
	# A pocket duel judges the hull against what the pilot class really has, read before the pool replaces it.
	_real_max_hull = float(_game.run.max_hp)
	_game.run.set_max_hp(HULL_POOL)
	if _settings.has("give"):
		_game.run.add_part(String(_settings["give"]), "matchup_lab")
	var ball: Vector3 = _game.player.ball_position()
	var forward: Vector3 = _game.ctx.aim_forward()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	if forward.length() < 0.5:
		forward = Vector3.FORWARD
	var flat: Vector3 = ball + forward * float(_settings.get("range", str(PACK_RANGE if _pack_mode else DUEL_RANGE)))
	if _pocket != "":
		_spawn_pocket_pack()
		return
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


# Records the early outcome (_early), frees the game (and any enemy already spawned) and quits.
func _end_early() -> void:
	_done = true
	_record()
	_game.free()
	_game = null
	quit(0)


# Chooses this seed's perch top. "near": the terrain's own pick was within reach of the resting ball.
# "relocated": none was, so the ball was moved to a standoff `--range` from a top chosen from the whole
# stage by the seed. "no_perch": the stage has no top at all. "not_perched": the standoff (or the resting
# ball) is not clear of landforms or not PERCH_MIN under the top, or no spot lies in the play rect; the duel
# ends before the spawn.
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
		_match_top(tops)
		if found.is_empty():
			return "not_perched"
		var spot: Vector2 = found["p"]
		_standoff_m = found["dist"]
		_standoff_ok = found["ok"]
		_standoff_clear = found["clear"]
		_standoff_at = spot
		_perched_under = found["under"]
		_perch_over_ball = _perch_top.y - float(terrain.height(spot.x, spot.y))
		if not (found["clear"] and found["under"]):
			return "not_perched"
		_game.player.reset_to(terrain.drop_point(spot.x, spot.y, 1.05))
		_relocated = true
	_match_top(tops)
	if not _relocated and _perch_top.y - float(terrain.height(ball.x, ball.z)) < PerchPoints.PERCH_MIN:
		# The terrain's own pick is not PERCH_MIN over the resting ball: not a perched duel.
		_perched_under = false
		_perch_over_ball = _perch_top.y - float(terrain.height(ball.x, ball.z))
		return "not_perched"
	return "relocated" if _relocated else "near"


# The chosen top's source and base rise, read from the stage's tops.
func _match_top(tops: Array) -> void:
	for entry in tops:
		if (entry["top"] as Vector3).is_equal_approx(_perch_top):
			_perch_source = entry["source"]
			_perch_base_rise = float(entry["base_rise"])


# A level, landform-clear spot for the ball: bearings (16, from `start`) at `distance`, then the radius
# stepped out by STANDOFF_STEP_M up to STANDOFF_REACH_M past it. The first spot whose ground spread over
# STANDOFF_PROBES is within STANDOFF_FLAT_M, clear of landforms and PERCH_MIN under the top wins (ok = true).
# When none is, the best of: clear of landforms, then under the top, then least spread, is used with
# ok = false. Spots outside the map's play rect are never candidates; when none lies inside it the result is
# empty (never an unchecked spot). Returns {p (x, z), dist, ok, clear, under}, or {}.
func _standoff(top: Vector3, distance: float, start: float) -> Dictionary:
	var terrain = _game.ctx.terrain
	var m = terrain.map()
	var blocked: Array = PerchPoints.blockers(m.park) if m is ParkMap and m.ok else []
	var steps := int(STANDOFF_REACH_M / STANDOFF_STEP_M)
	var play := Rect2()
	if m is ParkMap and m.ok:
		play = m.play_rect
	var best := {}
	var best_score := INF
	for r in range(steps + 1):
		var dist := distance + STANDOFF_STEP_M * r
		for k in STANDOFF_BEARINGS:
			var a := start + TAU * k / float(STANDOFF_BEARINGS)
			var p := Vector2(top.x, top.z) + Vector2(cos(a), sin(a)) * dist
			if play.size != Vector2.ZERO and not play.has_point(p):
				continue
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
				return {"p": p, "dist": dist, "ok": true, "clear": true, "under": true}
			# Clear first (a ball placed in a solid is wrong whatever the rise), then under, then spread; a
			# clear spot that is not under the top is flagged by perched_under false.
			var score := (hi - lo) + (0.0 if under else 1000.0) + (0.0 if clear else 10000.0)
			if score < best_score:
				best_score = score
				best = {"p": p, "dist": dist, "ok": false, "clear": clear, "under": under}
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
	if not _perched_under:
		# The real body is not PERCH_MIN over the ball (a mast row on a tall post, or a held ball that drifted
		# uphill): not a perched duel. The caller ends the run before any fight.
		_early = "not_perched"
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


# ---- Pocket duel (child) ----------------------------------------------------------------

# Stands the lab pocket up as the arena before the run starts: the pocket's colliders over the legacy map, the legacy
# colliders off, and the live Terrain instance re-scripted (its variables carried across) so every holder of
# ctx.terrain, and every enemy handed it, reads the pocket for height, drop_point, spawn_point and entry_heading.
func _install_pocket() -> void:
	_arena = PocketArena.new()
	if not _arena.build(_game.ctx.root, _pocket, Vector3(0.0, PocketArena.LIFT, 0.0)):
		printerr("matchup_lab: the %s pocket glb will not load" % _pocket)
		quit(2)
		return
	var legacy: Node3D = _game.ctx.terrain.geometry_root(1)
	for body in legacy.find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).collision_layer = 0
	var live = _game.ctx.terrain
	# set_script drops the instance's variables, so the live Terrain's are carried across by hand.
	var kept := {}
	for prop in live.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			kept[prop["name"]] = live.get(prop["name"])
	live.set_script(PocketTerrain)
	for name in kept:
		live.set(name, kept[name])
	live.arena = _arena


# The pack of three on the pocket's far side, each dropped with terrain.drop_point like a pack duel's members.
func _spawn_pocket_pack() -> void:
	_collecting = true
	_pocket_spots = _arena.pack_spots(POCKET_PACK, Director.PACK_SPREAD)
	for spot in _pocket_spots:
		var enemy = _game.combat.spawn_enemy(_pocket_enemy, _game.ctx.terrain.drop_point(spot.x, spot.z, 1.8))
		if enemy != null:
			_pack_spawned += 1
			if enemy not in _driver.members:
				_driver.members.append(enemy)
	_collecting = false
	_enemy_set = true
	_pocket_slots = _driver.members.duplicate()


func _hull_lost() -> float:
	return float(_game.run.metrics["hull_damage"]) - _hull_start


# Kill order: the slot (spawn order, left to right across the line) of each pack member as it falls.
func _track_kills(t: float) -> void:
	for i in _pocket_slots.size():
		if not DuelDriver.alive(_pocket_slots[i]) and not _kill_order.any(func(k): return k["slot"] == i):
			_kill_order.append({"slot": i, "kind": _pocket_enemy, "t": snappedf(t, 0.01)})


func _record() -> void:
	var lost: float = float(_game.run.metrics["hull_damage"]) - _hull_start if _spawned else 0.0
	var outcome: String = _early if _early != "" else (pack_outcome(_pack_spawned, _driver.outcome) if _pack_mode else _driver.outcome)
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
		if _standoff_at != Vector2.ZERO:
			row["standoff_m"] = snappedf(_standoff_m, 0.1)
			row["standoff_ok"] = _standoff_ok
			row["standoff_clear"] = _standoff_clear
			row["standoff_at"] = [snappedf(_standoff_at.x, 0.1), snappedf(_standoff_at.y, 0.1)]
		row["held"] = _held
		row["perched_under"] = _perched_under
		row["perch_over_ball_m"] = snappedf(_perch_over_ball, 0.01)
	if _pocket != "":
		row["seed"] = _base_seed
		row["run"] = _run_index
		row["rng_seed"] = _run_seed
		row["pocket"] = _pocket
		row["enemy"] = _pocket_enemy
		row["column"] = pocket_column_of(_pocket_enemy)
		row["members"] = _pack_members
		row["spawned"] = _pack_spawned
		row["first_down_s"] = snappedf(-1.0 if _stage_changed else _first_down_s, 0.01)
		row["real_max_hull"] = snappedf(_real_max_hull, 0.1)
		row["kill_order"] = _kill_order
		row["hull_out"] = _hull_out
		row["rescues"] = _arena.rescues if _arena != null else 0
		row["spots"] = _pocket_spots.map(func(v): return [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)])
		row["plant"] = String(_settings.get("plant", ""))
		row["winner"] = pocket_winner(row)
	elif _pack_mode:
		row["pack"] = _pack_id
		row["members"] = _pack_members
		row["table"] = _table_id
		row["spawned"] = _pack_spawned
		row["skipped"] = _pack_skipped
		row["first_down_s"] = snappedf(-1.0 if _stage_changed else _first_down_s, 0.01)
	var file := FileAccess.open(String(_settings["result"]), FileAccess.WRITE)
	file.store_string(JSON.stringify(row) + "\n")
	file.close()


# The planted crew still sees the ball and can hurt it. Only its prediction input is zero.
class NoLeadSight extends "res://src/combat/sight.gd":
	func planar_velocity() -> Vector3:
		return Vector3.ZERO


class PassCounter:
	var threats := {}
	var strikes := {}
	var contacts: Array = []

	var ball_position: Callable
	var members: Array = []
	var serials := {}
	var slots := {}
	var pulses := {}
	var tick := 0
	var warnings: Array = []
	var strike_ticks := {}

	func shape(owner: String, key: String, mark, ball: Vector3, at_tick: int, attacker: int) -> void:
		if not is_instance_valid(mark) or not mark.is_hostile():
			return
		if not strikes.has(key):
			strikes[key] = false
		if strikes[key] or not mark.contains(ball):
			return
		strikes[key] = true
		threats[owner] = int(threats.get(owner, 0)) + 1
		var geometry: Dictionary = mark.descriptor()
		for field in geometry:
			var value = geometry[field]
			if value is Vector3:
				geometry[field] = [value.x, value.y, value.z]
		geometry.erase("tone")
		contacts.append({"attacker": attacker, "kind": owner, "attack": key, "tick": at_tick,
			"ball": [ball.x, ball.y, ball.z], "geometry": geometry})


	func observe(enemy, kind: String) -> void:
		members.append(weakref(enemy))
		var owner_id: int = enemy.get_instance_id()
		var slot := members.size() - 1
		slots[owner_id] = slot
		enemy.attack_phase.connect(func(facts: Dictionary):
			var key := "%d/%d" % [slot, facts.instance]
			if facts.phase == "windup":
				warnings.append({"tick": tick, "kind": kind, "attacker": slot})
			if kind == "mag_trapper" and facts.phase == "recover" and serials.get(owner_id) == key and enemy.broken_by == "":
				# _end publishes recover after the pit's last occupancy check, before clearing
				# its mark. A player break skips that check and a death publishes cancelled.
				shape(kind, key, enemy.telegraph(), ball_position.call(), tick, slot)
			if facts.phase != "strike":
				return
			serials[owner_id] = key
			strike_ticks[owner_id] = tick
			if kind == "chaser" and is_instance_valid(enemy.telegraph()):
				strikes[key] = false
			if kind not in ["lobber", "chaser", "jolt_layer", "mag_trapper", "boom_tender"]:
				shape(kind, key, enemy.telegraph(), ball_position.call(), tick, slot))
		if kind == "chaser":
			# A head reaching the ball inside its committed lane is the chaser's strike.
			enemy.hit_player.connect(func(_damage, _shove):
				shape(kind, str(serials.get(owner_id, "lunge/%d/%d" % [slot, enemy.lunges])), enemy.telegraph(), ball_position.call(), tick, slot))
		if kind == "lobber":
			enemy.released.connect(func(_ring):
				for shell in enemy.get_tree().get_nodes_in_group("enemy_shot"):
					if shell.lobber == enemy and not shell.has_meta("pass_watched"):
						shell.set_meta("pass_watched", true)
						var key := "shell/%d/%d" % [slot, enemy.shots]
						shell.exploded.connect(func(at, _radius, _hit):
							if not shell.returned and at.is_equal_approx(shell.landing):
								shape(kind, key, shell.ring, ball_position.call(), tick, slot)))


	func fields() -> void:
		for ref in members:
			var enemy = ref.get_ref()
			if not is_instance_valid(enemy) or enemy.is_dead():
				continue
			var id: int = enemy.get_instance_id()
			if not serials.has(id):
				continue
			var key: String = serials[id]
			if enemy.kind == "jolt_layer" and enemy.field != null:
				# The mat's fill goes live before its first pulse. Only the pulse can jolt.
				var count: int = enemy.field.outcomes.size()
				if count > int(pulses.get(key, 0)):
					shape(enemy.kind, "%s/pulse/%d" % [key, enemy.field.pulses], enemy.telegraph(), ball_position.call(), tick, slots[id])
				pulses[key] = count
			elif enemy.kind in ["mag_trapper", "boom_tender"] and enemy.phase == enemy.Phase.LIVE and tick > int(strike_ticks[id]):
				var mark = enemy.telegraph()
				if enemy.kind != "boom_tender" or (tick - int(strike_ticks[id])) <= enemy.SWEEP * Engine.physics_ticks_per_second:
					shape(enemy.kind, key, mark, ball_position.call(), tick, slots[id])


# Runs after the crew on the same physics tick. Reading during the next physics_frame
# can sample the ball after Jolt has already moved it another step.
class PassFieldSampler extends Node:
	signal sampled
	var counter: PassCounter

	func _physics_process(_delta: float) -> void:
		counter.fields()
		sampled.emit()


var _pass_counter := PassCounter.new()


static func spillway_packs(ids: PackedStringArray) -> Array:
	var packs := []
	for stage in ParkDefs.DEFS:
		if stage.world != 1:
			continue
		for pack in stage.packs + [stage.elite]:
			if "all" in ids or pack.id in ids:
				packs.append({"stage": stage.stage, "pack": pack.id, "members": pack.kinds,
					"elite": pack.id == stage.elite.id})
		if "staged_winch" in ids and stage.stage == 1:
			packs.append({"stage": 1, "pack": "staged_winch", "members": ParkDefs.ELITE.kinds, "elite": false})
	return packs


# Only fast-pass receipts attest a Git source. Import a private detached checkout once,
# then keep its project (including the imported resources) read-only for all workers.
class PassSource:
	const SKETCH := "sketches/core-loop"
	var origin: String
	var head: String
	var checkout: String
	var project: String

	static func revision(repo: String) -> String:
		var output := []
		if OS.execute("git", ["-C", repo, "rev-parse", "--verify", "HEAD^{commit}"], output) != 0:
			return ""
		return String(output[0]).strip_edges()

	static func same_project(actual: String, expected: String) -> bool:
		var directory := DirAccess.open(actual)
		return directory != null and not expected.is_empty() and directory.is_equivalent(actual, expected)

	static func clean(repo: String) -> bool:
		var output := []
		if OS.execute("git", ["-C", repo, "status", "--porcelain", "-uno"], output) != 0 or not "".join(output).is_empty():
			return false
		# A loose project input could change what the caller thinks it is measuring.
		output.clear()
		return OS.execute("git", ["-C", repo, "ls-files", "--others", "--exclude-standard", "--", SKETCH + "/src", SKETCH + "/assets", SKETCH + "/tools/stations"], output) == 0 and "".join(output).is_empty()

	static func detached(repo: String, commit: String, dest: String) -> bool:
		return OS.execute("git", ["clone", "--quiet", "--local", "--shared", "--no-checkout", "--sparse", repo, dest]) == 0 \
			and OS.execute("git", ["-C", dest, "sparse-checkout", "set", SKETCH]) == 0 \
			and OS.execute("git", ["-C", dest, "checkout", "--quiet", "--detach", commit]) == 0 \
			and revision(dest) == commit

	func prepare(repo: String, dest: String) -> bool:
		origin = repo
		head = revision(origin)
		if head.is_empty() or not clean(origin):
			printerr("fast pass refuses a dirty or unreadable source checkout")
			return false
		checkout = dest
		project = checkout.path_join(SKETCH)
		if not detached(origin, head, checkout):
			return false
		var output := []
		var args := ["--headless", "--path", project, "--editor", "--import"]
		# First import builds the global class cache. Judge the second, like import-stamp.mjs.
		OS.execute(OS.get_executable_path(), args)
		if OS.execute(OS.get_executable_path(), args, output, true) != 0 or "SCRIPT ERROR:" in "".join(output):
			printerr("fast pass could not import the detached source: ", "".join(output).right(1500))
			return false
		return OS.execute("chmod", ["-R", "a-w", project]) == 0 and matches()

	func matches() -> bool:
		return revision(checkout) == head and OS.execute("git", ["-C", checkout, "diff", "--quiet", head, "--", SKETCH]) == 0 \
			and clean(origin) and revision(origin) == head

func _begin_pass_table() -> void:
	var ids := String(_settings.get("packs", "all")).split(",")
	var packs := spillway_packs(ids)
	var modes := String(_settings.pass).split(",")
	var speeds := String(_settings.get("speed", "14,28")).split(",")
	var seeds := String(_settings.get("seeds", "1,2,3,4,5,6,7,8")).split(",")
	var pilots := String(_settings.get("pilots", "tarn")).split(",")
	var plant := String(_settings.get("plant", OS.get_environment("PLANT")))
	_pilots = Array(pilots)
	if _settings.get("table", "park") != "park" or String(_settings.get("receipt", "")).is_empty() or plant not in ["", "zero_lead"]:
		printerr("fast pass needs --table=park, --receipt=<file> and optionally --plant=zero_lead")
		quit(2)
		return
	for selection in [ids, modes, speeds, seeds, pilots]:
		var seen := {}
		for token in selection:
			if token.is_empty() or seen.has(token):
				printerr("empty or duplicate fast-pass selection: ", token)
				quit(2)
				return
			seen[token] = true
	for id in ids:
		if id != "all" and not packs.any(func(p): return p.pack == id):
			printerr("unknown Spillway pack: ", id)
			quit(2)
			return
	for mode in modes:
		if mode not in ["straight", "weave", "stall"]:
			printerr("unknown pass: ", mode)
			quit(2)
			return
	for speed in speeds:
		if speed not in ["14", "28"]:
			printerr("unknown pass speed: ", speed)
			quit(2)
			return
	for s in seeds:
		if not s.is_valid_int():
			printerr("invalid seed: ", s)
			quit(2)
			return
	for pilot in pilots:
		if BotDriver.class_index_for(0, pilot) < 0:
			printerr("unknown pilot: ", pilot)
			quit(2)
			return
	for pack in packs:
		for pilot in pilots:
			for s in seeds:
				for mode in modes:
					for speed in speeds:
						_queue.append({"n": _queue.size(), "kind": pack.pack, "stage": pack.stage,
							"pilot": pilot, "seed": int(s), "give": "", "pass": mode,
							"speed": int(speed), "plant": plant})
						if plant == "" and mode == "straight" and "lobber" in pack.members:
							var control: Dictionary = _queue.back().duplicate()
							control.n = _queue.size()
							control.plant = "zero_lead"
							_queue.append(control)
	_total = _queue.size()
	_procs = clampi(int(_settings.get("procs", "2")), 1, 6)
	_sweep_dir = OS.get_user_data_dir().path_join("matchup_lab/" + Crypto.new().generate_random_bytes(16).hex_encode())
	var repo := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	_pass_source = PassSource.new()
	if DirAccess.make_dir_recursive_absolute(_sweep_dir) != OK:
		quit(2)
		return
	print("fast pass scratch for PID %d: %s" % [OS.get_process_id(), _sweep_dir])
	if not _pass_source.prepare(repo, _sweep_dir.path_join("source")):
		printerr("fast pass source could not be bound before dispatch")
		quit(2)
		return
	_parent = true


func _finalize() -> void:
	if _pass_source != null:
		for job in _running:
			if job.pid > 0 and OS.is_process_running(job.pid):
				OS.kill(job.pid)
		for attempt in 100:
			if not _running.any(func(job): return job.pid > 0 and OS.is_process_running(job.pid)):
				break
			OS.delay_msec(20)
		if _running.any(func(job): return job.pid > 0 and OS.is_process_running(job.pid)):
			push_error("worker still using fast-pass scratch: " + _sweep_dir)
			return
		if not _pass_source.project.is_empty() and DirAccess.dir_exists_absolute(_pass_source.project):
			OS.execute("chmod", ["-R", "u+w", _pass_source.project])
		_remove_tree(_sweep_dir)


# A release receipt must cover the complete matched matrix. Partial sweeps report
# their individual passes without turning missing seeds, modes or controls into passes.
static func pass_grade(rows: Array, controls: Array, baseline: Array, pilots: Array) -> Dictionary:
	var base_weave := {}
	for row in baseline:
		if row.get("outcome") == "pass_complete" and row.get("pass") == "weave" and row.get("plant", "") == "":
			if base_weave.has(_pass_key(row)):
				return {"pass": false, "plant_caught": false, "matched": 0, "expected": 0,
					"straight_misses": 0, "weave_misses": 0, "stall_misses": 0, "zero_lead_ok": 0,
					"zero_lead_expected": 0, "invalid": "duplicate baseline weave"}
			base_weave[_pass_key(row)] = row
	var indexed := {}
	var planted := {}
	for row in rows:
		if row.get("outcome") == "pass_complete" and row.get("plant", "") == "":
			indexed[_pass_key(row)] = row
	for row in controls:
		if row.get("outcome") == "pass_complete" and row.get("plant") == "zero_lead":
			planted[_pass_key(row)] = row
	var unique := indexed.size() == rows.size() and planted.size() == controls.size()
	var expected := 0
	var matched := 0
	var zero_lead_expected := 0
	var zero_lead_ok := 0
	var straight_misses := 0
	var weave_misses := 0
	var stall_misses := 0
	for pack in spillway_packs(PackedStringArray(["all"])):
		for pilot in pilots:
			for s in range(1, 9):
				for speed in [14, 28]:
					var query := {"stage": pack.stage, "pack": pack.pack, "pilot": pilot, "seed": s, "speed": speed, "pass": "straight"}
					var k := _pass_key(query)
					var straight: Dictionary = indexed.get(k, {})
					if "lobber" in pack.members:
						zero_lead_expected += 1
						if planted.has(k) and planted[k].threats == 0 and planted[k].get("observed_strikes", 0) > 0:
							zero_lead_ok += 1
					query.pass = "weave"
					var weave: Dictionary = indexed.get(_pass_key(query), {})
					var base: Dictionary = base_weave.get(_pass_key(query), {})
					query.pass = "stall"
					var stall: Dictionary = indexed.get(_pass_key(query), {})
					expected += 1
					if straight.is_empty() or weave.is_empty() or stall.is_empty():
						continue
					matched += 1
					if straight.threats < 1:
						straight_misses += 1
					if base.is_empty() or base.site != weave.site or weave.hull_lost > base.hull_lost + 0.00001:
						weave_misses += 1
					if stall.hull_per_min <= 0 or stall.hull_per_min + 0.00001 < 2.0 * straight.hull_per_min:
						stall_misses += 1
	var caught := unique and zero_lead_expected > 0 and zero_lead_ok == zero_lead_expected
	return {"plant_caught": caught, "pass": unique and matched == expected and caught and straight_misses + weave_misses + stall_misses == 0,
		"matched": matched, "expected": expected, "straight_misses": straight_misses, "weave_misses": weave_misses,
		"stall_misses": stall_misses, "zero_lead_ok": zero_lead_ok, "zero_lead_expected": zero_lead_expected}


static func _pass_key(row: Dictionary) -> String:
	return "%d/%s/%s/%d/%d/%s" % [row.stage, row.pack, row.pilot, row.seed, row.speed, row.pass]


func _write_pass_table() -> void:
	var path := String(_settings.receipt)
	_results.sort_custom(func(a, b): return a.n < b.n)
	var valid := _results.size() == _total and _results.all(func(r): return r.get("outcome") == "pass_complete")
	var head := _pass_source.head
	if not _results.all(func(r): return r.get("source_head", "") == head):
		printerr("fast pass refuses results without the pinned worker identity")
		quit(2)
		return
	var controls := _results.filter(func(r): return r.get("plant") == "zero_lead")
	var rows := _results.filter(func(r): return r.get("plant", "") == "")
	var baseline := []
	var baseline_identity := {}
	if _settings.has("baseline"):
		var source := String(_settings.baseline)
		var digest := FileAccess.get_sha256(source)
		var base = JSON.parse_string(FileAccess.get_file_as_string(source))
		if not base is Dictionary or base.get("row") != "fast-threat" or not base.get("complete") or not base.get("passes") is Array:
			printerr("invalid --baseline fast-threat receipt")
			quit(2)
			return
		if head.is_empty() or base.get("head", "") in ["", head] or not base.get("baseline_identity", {}).is_empty() \
				or digest.is_empty() or digest != _settings.get("round-zero-sha256", ""):
			printerr("--baseline must match the published round-zero SHA256, be from another head and itself have no baseline")
			quit(2)
			return
		baseline_identity = {"head": base.head, "sha256": digest}
		baseline = base.passes
	var grade := pass_grade(rows, controls, baseline, _pilots)
	var report := {"row": "fast-threat", "head": head, "passes": rows, "controls": controls, "grade": grade, "baseline_identity": baseline_identity,
		"complete": valid, "pass": valid and grade.pass, "plant_caught": valid and grade.plant_caught,
		"measured": "%d/%d matched pack/speed/seed/pilot triples; misses: straight %d, weave %d, stall %d; zero-lead %d/%d" % [
			grade.matched, grade.expected, grade.straight_misses, grade.weave_misses, grade.stall_misses,
			grade.zero_lead_ok, grade.zero_lead_expected]}
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var tmp := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(tmp, FileAccess.WRITE) if error == OK else null
	if file == null:
		printerr("cannot write fast-pass receipt ", path)
		quit(2)
		return
	file.store_line(JSON.stringify(report))
	file.close()
	if not _pass_source.matches():
		printerr("fast pass source changed before publication")
		DirAccess.remove_absolute(tmp)
		quit(2)
		return
	var published := DirAccess.rename_absolute(tmp, path) == OK
	if not published:
		printerr("cannot publish fast-pass receipt ", path)
		quit(2)
		return
	print("RECEIPT ", JSON.stringify({"row": report.row, "measured": report.measured, "head": head}))
	quit(0 if valid else 1)


# Before W1-132a stacks, take the matched approach from the stage's authored floor line.
func _pass_site(stage: int) -> Vector3:
	var shared := "res://tools/stations/shared_route.json"
	if stage == 1 and FileAccess.file_exists(shared):
		var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(shared))["west_wash_run"]
		return Vector3(row.point[0], 0, row.point[2])
	var map: String = ParkDefs.DEFS[stage - 1].map
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/park/%s/lines.json" % map))
	# One specific floor waypoint on each stage, by its route neighbours. On the dam the
	# shared station is Sable's approach in the same file.
	if stage == 1:
		var line: Array = lines.pilots.sable.waypoints
		var p: Array = line[line.find("the_eye") - 3]
		return Vector3(p[0], 0, p[1])
	var floor_line: Array = lines.floor.waypoints
	var p: Array = floor_line[floor_line.find("siphon_camp") + 1]
	return Vector3(p[0], 0, p[1])


func _pass_enemy(enemy, kind: String) -> void:
	if _settings.get("plant") == "zero_lead":
		enemy.target = NoLeadSight.new(_game.player, _game.combat, enemy, kind)
	_pass_counter.observe(enemy, kind)


func _run_pass() -> void:
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var source_head := PassSource.revision(project)
	if not PassSource.same_project(project, _settings.get("source-project", "")) or source_head.is_empty() or source_head != _settings.get("source-head", ""):
		printerr("fast pass worker source differs from its dispatch")
		quit(2)
		return
	var stage := int(_settings.stage)
	var id := String(_settings.kind)
	var entries := spillway_packs(PackedStringArray([id]))
	var entry: Dictionary = {}
	for item in entries:
		if item.stage == stage:
			entry = item
	if entry.is_empty():
		quit(2)
		return
	var pilot := String(_settings.pilot)
	var s := int(_settings["run-seed"])
	var mode := String(_settings["pass-job"])
	var speed := int(_settings.speed)
	seed(s)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.codex.storage_dir = _settings.home
	_game.run_log.storage_dir = _settings.home
	_game.run.run_seed_override = s
	_game.flow.beacon_seconds_override = BEACON_PIN_S
	_game.ctx.rng.seed = s
	_game.player.source = preload("res://src/movement/intent.gd").Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(BotDriver.class_index_for(0, pilot))
	if stage != 1:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_game.presentation.juice.hit_stop_sink = func(_seconds): pass
	for i in 10:
		await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.is_in_group("harpoon_anchor"):
			enemy.queue_free()
	await physics_frame
	var site := _pass_site(stage)
	var point := site - Vector3.BACK * 25.0
	var heading := Vector3.BACK
	var terrain = _game.ctx.terrain
	var velocity := heading * (0 if mode == "stall" else speed)
	_game.player.reset_to(terrain.drop_point(point.x, point.z, 1.0), velocity)
	_game.camera.snap(heading)
	_pass_counter.ball_position = Callable(_game.player, "ball_position")
	var sampler := PassFieldSampler.new()
	sampler.counter = _pass_counter
	sampler.process_physics_priority = 1000
	_game.add_child(sampler)
	_game.events.enemy_spawned.connect(_pass_enemy)
	var spawned := 0
	for i in entry.members.size():
		var offset := Director.PACK_SPREAD * (float(i) - float(entry.members.size() - 1) / 2.0)
		var enemy = _game.combat.spawn_enemy(entry.members[i], terrain.drop_point(site.x + offset, site.z, 1.8))
		if enemy != null:
			spawned += 1
			enemy.set_meta("pack_seq", 1)
			if entry.elite:
				enemy.set_meta("elite_pack", true)
	var hull_start := float(_game.run.metrics.hull_damage)
	var dt := 1.0 / Engine.physics_ticks_per_second
	# Drive an identical, terrain-following path even when a hold or a ram would push the
	# pilot aside. The game's actual player, target sight, hit geometry and damage stay live.
	var by_source := {}
	var damage_total := [hull_start]
	_game.events.player_hit.connect(func(_amount: float, source: String):
		var total := float(_game.run.metrics.hull_damage)
		by_source[source] = float(by_source.get(source, 0)) + total - float(damage_total[0])
		damage_total[0] = total)
	# Match both arms across the ten-second silt-boil history and its 1.2 s warning.
	var ticks := 12 * Engine.physics_ticks_per_second
	var elapsed := 0
	for i in ticks:
		await physics_frame
		_pass_counter.tick = i
		if mode == "weave":
			velocity = heading.rotated(Vector3.UP, 0.65 * sin(TAU * i * dt / 1.8)) * speed
		_game.player.body().teleport(terrain.drop_point(point.x, point.z, 1.0), velocity)
		await sampler.sampled
		elapsed += 1
		point += velocity * dt
		if _game.run.hp <= 0.0:
			break
	var lost := float(_game.run.metrics.hull_damage) - hull_start
	var row := {"source_head": source_head, "pilot": pilot, "pack": id, "stage": stage, "seed": s, "pass": mode, "speed": speed,
		"members": entry.members, "spawned": spawned, "plant": _settings.get("plant", ""),
		"warnings": _pass_counter.warnings, "observed_strikes": _pass_counter.strikes.size(), "threats_by_kind": _pass_counter.threats, "contacts": _pass_counter.contacts,
		"threats": _pass_counter.contacts.size(),
		"site": [site.x, site.z], "seconds": elapsed * dt, "died": _game.run.hp <= 0.0,
		"hull_lost": lost, "hull_by_source": by_source, "hull_per_min": lost * 60 / (elapsed * dt),
		"outcome": "pass_complete" if spawned == entry.members.size() and _game.run.stage == stage and _game.run.class_id() == pilot else "no_result"}
	var file := FileAccess.open(String(_settings.result), FileAccess.WRITE)
	if file != null:
		file.store_line(JSON.stringify(row))
		file.close()
	_game.queue_free()
	await process_frame
	_game = null
	quit(0 if file != null else 2)
