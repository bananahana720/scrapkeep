extends SceneTree


const Shim := preload("res://tools/test_batch_shim.gd")
const Driver := preload("res://tools/test_batch_driver.gd")


func _initialize() -> void:
	var paths := Array(OS.get_environment("SCRAPKEEP_TEST_BATCH").split(",", false))
	var driver = Driver.new(self, paths)
	Shim.batch = driver
	driver.next.call_deferred()
