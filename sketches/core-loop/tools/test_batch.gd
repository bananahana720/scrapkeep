extends SceneTree

# Runs many `extends SceneTree` tests in one Godot process, so the game's scripts compile once
# instead of once per test (about 7 s each on the cloud box). Usage:
#   godot --headless --path sketches/core-loop --script res://tools/test_batch.gd  (with SCRAPKEEP_TEST_BATCH=tests/a_test.gd,tests/b_test.gd)
# Each test's output sits between "BATCH START <path>" and "BATCH END <path> exit=<code> ms=<n>".

const Shim := preload("res://tools/test_batch_shim.gd")
const Driver := preload("res://tools/test_batch_driver.gd")


func _initialize() -> void:
	# The list comes in the environment, so the game reads the same command line as a solo run.
	var paths := Array(OS.get_environment("SCRAPKEEP_TEST_BATCH").split(",", false))
	var driver = Driver.new(self, paths)
	Shim.batch = driver
	driver.next.call_deferred()
