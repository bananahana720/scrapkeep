extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const DECLARES := "(?m)^\\s*(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*(?:const|var|func)\\s+"
const STAGE_LOCKS := "res://src/world/stage_locks.gd"
const TUNING := "res://src/movement/tuning.gd"


func run(t) -> void:
	for name in ["WALL_SPRING", "WALL_DAMP", "WALL_ACCEL_CAP"]:
		t.eq("only stage_locks.gd declares %s under src" % name,
			SourceScan.matching(t, ["res://src"], DECLARES + name + "\\b"), [STAGE_LOCKS])

	var cruise_rows := Tuning.SPECS.filter(func(spec): return spec["key"] == "cruise")
	t.eq("the cruise row's default is Tuning.CRUISE_MPS", cruise_rows.map(func(spec): return spec["value"]), [Tuning.CRUISE_MPS])
	t.eq("only tuning.gd declares a cruise speed constant under src",
		SourceScan.matching(t, ["res://src"], DECLARES + "(?:DEFAULT_)?CRUISE(?:_SPEED)?_MPS\\b"), [TUNING])
