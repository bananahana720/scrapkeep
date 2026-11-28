extends SceneTree

# PF-34 (w37 player's-eye film, pictures 054-055): the reveal card cut its verb line mid-word ("Bounces hit
# machines like a sh"). Every part's and relic's card line now fits the card's text column, on one
# line or broken at a word onto two (reward_view.gd verb_fit), with or without the link button.
# Planted: Impact Driver's line, the one the film caught, needs two lines on a card with the link.

const RewardView := preload("res://src/ui/reward_view.gd")
const RewardCeremony := preload("res://src/presentation/reward_ceremony.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const T := preload("res://tests/support/t.gd")

# reward_view.gd _draw_card: the text column is the card less the socket (92) and the link (52) or a margin (16).
const WITH_LINK := RewardView.CARD.x - 92.0 - 52.0
const NO_LINK := RewardView.CARD.x - 92.0 - 16.0

var _t := T.new("ui_reward_card_words_test")


func _initialize() -> void:
	var lines := []
	for id in Parts.ids():
		lines.append(RewardCeremony.card_words(String(id)))
	for id in Relics.ids():
		lines.append(String(Relics.row(String(id)).get("text", "")))
	var bad := []
	for words in lines:
		for width in [WITH_LINK, NO_LINK]:
			var fit: Dictionary = RewardView.verb_fit(words, width)
			var out: Array = fit["lines"]
			var fits: bool = out.size() <= 2 and out.all(func(line): return UiFonts.width(line, fit["size"]) <= width)
			if not fits or " ".join(out) != words.strip_edges():
				bad.append("%s @%d -> %s" % [words, int(width), out])
	_t.check("%d card lines fit the text column on at most two lines, every word kept" % lines.size(), bad.is_empty(), "%s" % [bad])
	var planted: Array = RewardView.verb_fit("Bounces hit machines like a shot", WITH_LINK)["lines"]
	_t.check("planted: the line the film cut needs two lines beside the link", planted.size() == 2, "%s" % [planted])
	_t.eq("a short line stays one line", RewardView.verb_fit("Raise your max health", NO_LINK)["lines"], ["Raise your max health"])
	quit(_t.verdict())
