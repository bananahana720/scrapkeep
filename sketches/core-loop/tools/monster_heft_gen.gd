extends SceneTree

# Generates data/challenge/monster_heft.json: for each stage entrance, the top-bucket maximum heft of
# the library build, and from those the per-fight thresholds (fights). A pilot is a monster build at a Warden or boss only when
# its heft is strictly above that number (coordinator ruling (B) on #222, 21 Oct). No hand tuning.
# Source: lib-base index.json, branch scratch/challenge-lib commit 01a9f50d (155 docs); copied to
# data/challenge/lib_base_index.json. Run: $GODOT_BIN --headless --path sketches/core-loop -s tools/monster_heft_gen.gd
# The top bucket is the harness's pickBuilds rule: rank a stage's docs by mass, then parts, then
# file; the top is every doc at percentile i/(n-1) >= TOP_PERCENTILE, and at least min(MIN_BUCKET, n).
# Heft comes from RunState.heft() in armour mode, so the game's formula is never copied here.

const Run := preload("res://src/core/run_state.gd")
const INDEX_PATH := "res://data/challenge/lib_base_index.json"
const OUT_PATH := "res://data/challenge/monster_heft.json"
const SOURCE := "lib-base index.json, scratch/challenge-lib 01a9f50d"
const STAGES := 6
const TOP_PERCENTILE := 0.9
const MIN_BUCKET := 3
const WAKING_STAGE := 4
const MIND_STAGE := 6


static func load_index() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	return parsed if parsed is Array else []


static func heft_of(mass: float) -> float:
	var run := Run.new()
	run.armor_mode = true
	run.mass = mass
	return run.heft()


# Entrance thresholds, {stage: heft} for stages 1..STAGES; a stage with no docs is left out.
static func compute(index: Array) -> Dictionary:
	var out := {}
	for stage in range(1, STAGES + 1):
		var docs: Array = index.filter(func(d): return int(d.get("stage", 0)) == stage)
		if docs.is_empty():
			continue
		docs.sort_custom(func(a, b):
			if float(a["mass"]) != float(b["mass"]):
				return float(a["mass"]) < float(b["mass"])
			if float(a["parts"]) != float(b["parts"]):
				return float(a["parts"]) < float(b["parts"])
			return String(a["file"]) < String(b["file"]))
		var n := docs.size()
		var first := n - 1
		for i in n:
			if n > 1 and float(i) / float(n - 1) >= TOP_PERCENTILE:
				first = i
				break
		first = mini(first, n - mini(MIN_BUCKET, n))
		var top := 0.0
		for i in range(first, n):
			top = maxf(top, heft_of(float(docs[i]["mass"])))
		# Rounded up, never to nearest: a top-bucket build must not sit strictly above its own threshold.
		out[stage] = ceilf(top * 1000.0) / 1000.0
	return out


# The fights' thresholds from the entrance values (coordinator ruling on #222, 21 Oct): a park
# Warden is judged at its ARRIVAL, the next stage's entrance (w1 takes s2 ... w5 takes s6). The
# stage 6 park Warden (the crown's choir) has no s7 and no ruled threshold, so it gets none and
# fails closed (MonsterHeft reads INF). The Waking takes its own entrance s4 and the Mind its own s6.
static func fights(entrances: Dictionary) -> Dictionary:
	var wardens := {}
	for stage in range(1, STAGES):
		if entrances.has(stage + 1):
			wardens[str(stage)] = entrances[stage + 1]
	return {"wardens": wardens, "waking": entrances.get(WAKING_STAGE, INF), "mind": entrances.get(MIND_STAGE, INF)}


static func document(index: Array) -> Dictionary:
	var entrances := compute(index)
	var named := {}
	for stage in entrances:
		named[str(stage)] = entrances[stage]
	var doc := {"source": SOURCE, "entrances": named}
	doc.merge(fights(entrances))
	return doc


func _initialize() -> void:
	var doc := document(load_index())
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(doc, "  ") + "\n")
	file.close()
	print("monster_heft_gen: ", doc)
	quit(0)
