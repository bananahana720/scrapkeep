extends SceneTree

const Measurement := preload("res://tools/pattern_dps.gd")

const EXPECTED_ROWS := 18
const ERROR_MAX := 0.10

var _game
var _started := false


func _initialize() -> void:
	_game = Measurement.MeasurementGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	Measurement.prepare(_game)
	var rows := Measurement.measure_contract(_game)
	var failures := 0 if rows.size() == EXPECTED_ROWS else 1
	for row in rows:
		var ok := Measurement.valid_row(row) and is_finite(row["difference_pct"]) \
			and absf(row["power_ratio"] / row["measured_ratio"] - 1.0) <= ERROR_MAX
		print("%s contract %s: %s" % ["PASS" if ok else "FAIL", row["id"], JSON.stringify(row)])
		if not ok:
			failures += 1
	print("pattern_dps_test: %s (%d rows, %d failures)" % ["PASS" if failures == 0 else "FAIL", rows.size(), failures])
	_game.free()
	quit(0 if failures == 0 else 1)
	return true
