extends SceneTree
# smoke: solo timeout=360s

const T := preload("res://tests/support/t.gd")
const HookSites := preload("res://tools/hook_sites.gd")


func _initialize() -> void:
	var t := T.new("hook_sites_test")
	var output := []
	# The smoke runner gives this process a fresh scratch home. The headless child
	# inherits it and runs one physics tick per frame regardless of rendering load.
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "90",
		"--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/hook_sites.gd"], output, true)
	var rows := []
	var log := "\n".join(output)
	for line in log.split("\n"):
		if line.begins_with("HOOK_SITES "):
			var payload = JSON.parse_string(line.trim_prefix("HOOK_SITES "))
			if payload is Array:
				rows = payload
	if not t.check("fixed-tick probe ran", code == 0 and not "SCRIPT ERROR:" in log and not rows.is_empty()):
		printerr(log)
		quit(t.verdict())
		return
	var stations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HookSites.STATIONS))
	var sampled := {}
	var paid := 0
	for row: Dictionary in rows:
		t.check("known distinct site", stations.has(row.site) and not sampled.has(row.site), row.site)
		sampled[row.site] = true
		if row.site == "flume_hollow_trestles":
			t.eq("known flume timber takes a line", row.status, "measured")
		t.check("%s comparison finished" % row.site, row.status in ["no hold", "measured"], row.status)
		if row.status != "measured":
			continue
		t.eq("%s tried every earlier physics tick" % row.site, int(row.early_trials), HookSites.HOLD_TICKS - 1)
		if row.held.landing_mps >= row.best_early.landing_mps:
			paid += 1
	t.eq("station count", sampled.size(), stations.size())
	print("RECEIPT ", JSON.stringify({"row": "hook-pays", "pass": paid == stations.size() and t.failures == 0,
		"measured": {"entry_mps": HookSites.ENTRY_SPEED, "sites_where_hold_beats_release": paid, "stations": rows}}))
	quit(t.verdict())
