extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const DECLARES := "(?m)^\\s*(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*(?:const|var|func)\\s+"
const STAGE_LOCKS := "res://src/world/stage_locks.gd"


func run(t) -> void:
	for name in ["WALL_SPRING", "WALL_DAMP", "WALL_ACCEL_CAP"]:
		t.eq("only stage_locks.gd declares %s under src" % name,
			SourceScan.matching(t, ["res://src"], DECLARES + name + "\\b"), [STAGE_LOCKS])
