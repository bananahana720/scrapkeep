extends SceneTree

const HelpPage := preload("res://src/ui/help_page.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("help_page_alpha_test")


func _init() -> void:
	var goal: Array = HelpPage.GOAL
	_t.eq("a goal steps", goal.size(), 4)
	var all_kinds := true
	for step in goal:
		if not EventKinds.has(step["kind"]):
			all_kinds = false
	_t.check("a goal kinds exist", all_kinds)
	_t.eq("b last step is the next world", goal[goal.size() - 1]["kind"], "world_entered")
	var obj: String = FieldNotes.OBJECTIVE
	# Ruling cx: the title body is two sentences and still says what to do; the bosses are met, not listed.
	_t.eq("e objective reads as written, with no colon", obj, "A machine runs your world \"perfectly\". Take it back. Get heavy, break the Wardens, smash their cores.")
	_t.check("e objective within 24 words", WordBudget.words_in(obj) <= 24, str(WordBudget.words_in(obj)))
	quit(_t.verdict())
