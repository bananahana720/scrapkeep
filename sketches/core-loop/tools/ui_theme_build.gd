extends SceneTree

const UiTokens := preload("res://src/core/ui_tokens.gd")


func _initialize() -> void:
	var err := ResourceSaver.save(UiTokens.theme(), UiTokens.THEME_PATH)
	print("ui_theme_build: %s %s" % [UiTokens.THEME_PATH, error_string(err)])
	quit(0 if err == OK else 1)
