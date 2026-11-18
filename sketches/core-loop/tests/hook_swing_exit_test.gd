extends SceneTree
# smoke: solo timeout=360s

const T := preload("res://tests/support/t.gd")
const Teardown := preload("res://tests/support/teardown_noise.gd")


func _initialize() -> void:
	var t := T.new("hook_swing_exit_test")
	var output := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://tests/hook_sites_test.gd"], output, true)
	var log := Teardown.strip("\n".join(output))
	var receipt := {}
	for line in log.split("\n"):
		if line.begins_with("RECEIPT "):
			receipt = JSON.parse_string(line.trim_prefix("RECEIPT "))
	if not t.check("station measurement completed", code == 0 and not "ERROR:" in log and receipt.get("row") == "hook-pays"):
		printerr(log)
		quit(t.verdict())
		return
	for station in receipt.measured.stations:
		# The dam span had no usable collider in round 0. Once it can take
		# a bite it owes the same payoff as every other site (W1-135c).
		if station.site == "dam_viga_span" and station.status == "no hold":
			continue
		if t.eq("%s takes the line" % station.site, station.status, "measured"):
			t.check("%s hold pays in landing speed or an exclusive tier" % station.site, station.hold_pays)
			t.check("%s keeps the best early landing" % station.site, station.early_speed_preserved)
			t.check("%s adds no exit energy at any release tick" % station.site, station.within_stock_allowance)
	quit(t.verdict())
