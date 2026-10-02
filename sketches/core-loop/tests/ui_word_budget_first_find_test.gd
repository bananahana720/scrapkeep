extends SceneTree

const Fight := preload("res://tests/support/word_budget_fight.gd")

# The word budget on the first-find fight: the shared fight in tests/support/word_budget_fight.gd
# with the pickup a first find, which opens its reveal card during the fight. Quarantined red
# (tests/QUARANTINE.tsv, owner R3 reveal timing) until the card waits for calm.

var _fight


func _initialize() -> void:
	_fight = Fight.new(self, "ui_word_budget_first_find_test", false)


func _physics_process(_delta: float) -> bool:
	return _fight.tick()
