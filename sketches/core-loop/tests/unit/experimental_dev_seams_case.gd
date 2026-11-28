extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const DEV_DIR := "res://src/dev"
const EXPERIMENTAL_DIR := "res://src/experimental"
const CAPTURE := "res://src/dev/dev_capture.gd"
const ACTOR_CRAFT := "res://src/experimental/live_world_actor_craft.gd"
const BRIDGE := "res://src/experimental/live_run_bridge.gd"
const VAR_START := "(?m)^\\s*(?:static\\s+|@[a-z_]+(?:\\([^)]*\\))?\\s+)*var\\s+"


func run(t) -> void:
	for name in ["_busy", "_shots", "shot_dir"]:
		t.eq("only dev_capture.gd declares %s in src/dev" % name,
			SourceScan.matching(t, [DEV_DIR], VAR_START + name + "\\b"), [CAPTURE])
	t.eq("only dev_capture.gd declares the SHOT_DIR, SHEET_* and SAME_LUMA constants in src/dev",
		SourceScan.matching(t, [DEV_DIR], "(?m)^\\s*const\\s+(SHOT_DIR|SHEET_[A-Z0-9_]+|SAME_LUMA)\\b"), [CAPTURE])
	t.eq("only dev_capture.gd declares the still, QA-pack and sheet calls in src/dev",
		SourceScan.matching(t, [DEV_DIR],
			"(?m)^\\s*(static\\s+)?func\\s+(shot|shot_detailed|qa_pack_detailed|contact_sheet|sheet_detailed|sheet_ids|sheet_grid)\\("),
		[CAPTURE])

	for name in ["_mesh_cache", "_fx_mats"]:
		t.eq("only live_world_actor_craft.gd declares %s in src/experimental" % name,
			SourceScan.matching(t, [EXPERIMENTAL_DIR], VAR_START + name + "\\b"), [ACTOR_CRAFT])
	t.eq("only live_world_actor_craft.gd declares mesh builders in src/experimental",
		SourceScan.matching(t, [EXPERIMENTAL_DIR], "(?m)^\\s*(static\\s+)?func\\s+\\w+_mesh\\("), [ACTOR_CRAFT])

	t.eq("only live_run_bridge.gd holds the experimental audio cooldowns",
		SourceScan.matching(t, [EXPERIMENTAL_DIR], VAR_START + "audio_cooldowns\\b"), [BRIDGE])
	t.eq("no script under src/ declares _last_trigger_s",
		SourceScan.matching(t, ["res://src"], VAR_START + "_last_trigger_s\\b"), [])
