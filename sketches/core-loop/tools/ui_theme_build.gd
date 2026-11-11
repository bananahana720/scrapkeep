extends SceneTree

const UiTokens := preload("res://src/ui/ui_tokens.gd")

# Writes the project theme (UiTokens.THEME_PATH, project.godot gui/theme/custom) from the tokens.
# Run after changing a token; tests/ui_tokens_test.gd fails while the file and the tokens differ.
#   <godot> --headless --path sketches/core-loop --script res://tools/ui_theme_build.gd


func _initialize() -> void:
	var err := ResourceSaver.save(UiTokens.theme(), UiTokens.THEME_PATH)
	print("ui_theme_build: %s %s" % [UiTokens.THEME_PATH, error_string(err)])
	quit(0 if err == OK else 1)
