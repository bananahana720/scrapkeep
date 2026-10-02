extends SceneTree

const BalanceReport := preload("res://tools/balance_report.gd")

# A run log written by a build that still had the loop and gun switches carries
# loop_mode, gun_role and the drop fields (drops_to_break in the delivered-damage ledger,
# drop and lap notes on the bot's stage). The balance report joins and reads such a
# record without error, keeps every number the default game still reports, and ignores
# the fields no build writes now.

var _failures := 0


func _initialize() -> void:
	var dir := "user://old_record_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var spine := {"run_id": "old-1", "class": "rivet", "outcome": "won", "loop_mode": "drop", "gun_role": "hold",
		"delivered_damage": {"total": 120.0, "overkill": 4.0, "hits": 9,
			"by_source": {"drop_or_slam": 80.0, "weapon": 40.0}, "by_action": {}, "by_target_class": {"Warden": 120.0},
			"by_range": {"near": 120.0}, "retirements": {},
			"drops_to_break": {"1": 3, "2": null}, "warden_slam_hits": {"1": 5}},
		"stages": {"1": {"loop_mode": "drop", "gun_role": "hold"}}}
	var bot := {"run_id": "old-1", "policy": "lapper", "loop_mode": "drop", "gun_role": "hold", "outcome": "won",
		"stages": [{"stage": 1, "laps": 3, "bell_s": 4.5, "lap_times": [20.0, 18.5, 17.0], "near_misses": 2,
			"drop": {"windows": 6, "drops_landed": 3, "gun_role": "hold"}}]}
	_write(dir.path_join("runs.ndjson"), JSON.stringify(spine) + "\n")
	_write(dir.path_join("bots.ndjson"), JSON.stringify(bot) + "\n")
	var runs: Array[Dictionary] = BalanceReport._join(dir)
	var joined: bool = runs.size() == 1 and runs[0]["spine"].get("loop_mode") == "drop" and runs[0]["spine"].get("gun_role") == "hold" \
		and runs[0]["bot"].get("policy") == "lapper"
	_check("joins", joined, "the old record and its bot line join: %d run(s)" % runs.size())
	var report = BalanceReport.new()
	report._delivered_damage_section(runs)
	var text := "\n".join(report._lines)
	var read: bool = text.contains("1 run(s), 0 zero-damage run(s), 9 hit(s), 120 HP delivered") and text.contains("| drop_or_slam | 80 |") \
		and text.contains("- stage 1: 5.0 (1 break(s))")
	_check("reads", read, "the delivered-damage section reads the old ledger and drops its drops_to_break: %s" % text.replace("\n", " / "))
	report.free()
	print("balance_report_old_record_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
