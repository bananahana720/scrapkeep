extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const Cues := preload("res://src/presentation/positional_cue_rows.gd")

const TRIM_TABLE := "(?m)^\\s*(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*(?:const|var)\\s+TRIM_DB\\b"
const TRIM_OWNERS: Array[String] = ["res://src/presentation/sfx_bank.gd"]
const FILE_OWNERS: Array[String] = ["res://src/presentation/positional_cue_rows.gd"]


func run(t) -> void:
	t.eq("only sfx_bank.gd declares a TRIM_DB table under src", SourceScan.matching(t, ["res://src"], TRIM_TABLE), TRIM_OWNERS)
	var cue_file := "(?:foley|specials)/(?:%s)\\.wav" % "|".join(Cues.ROWS.keys())
	t.eq("only positional_cue_rows.gd names a positional cue's file under src", SourceScan.matching(t, ["res://src"], cue_file),
		FILE_OWNERS)
