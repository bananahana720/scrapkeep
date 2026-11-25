extends SceneTree


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
		out[stage] = ceilf(top * 1000.0) / 1000.0
	return out


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
