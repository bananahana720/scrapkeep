extends SceneTree

var untyped_count = 0


func _init() -> void:
	untyped_count += 1
	print("SCRAPKEEP_SMOKE_NEGATIVE reached _init, typing was not enforced")
	quit(0)
