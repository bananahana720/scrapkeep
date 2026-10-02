extends SceneTree

const Fight := preload("res://tests/support/word_budget_fight.gd")

# The word budget on the repeat-find fight: the shared fight in tests/support/word_budget_fight.gd
# with the pickup a repeat find, so no reveal card opens. The HUD's words stay at or under 25.
# The first-find fight is ui_word_budget_first_find_test.

var _fight


func _initialize() -> void:
	_fight = Fight.new(self, "ui_word_budget_test", true)


func _physics_process(_delta: float) -> bool:
	return _fight.tick()
