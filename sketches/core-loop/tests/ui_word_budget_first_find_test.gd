extends SceneTree

const Fight := preload("res://tests/support/word_budget_fight.gd")

# The word budget on the first-find fight: the shared fight in tests/support/word_budget_fight.gd
# with the pickup a first find, whose card is held until the fight is over, so the part's name
# at the ball is the only word it adds.

var _fight


func _initialize() -> void:
	_fight = Fight.new(self, "ui_word_budget_first_find_test", false)


func _physics_process(_delta: float) -> bool:
	return _fight.tick()
