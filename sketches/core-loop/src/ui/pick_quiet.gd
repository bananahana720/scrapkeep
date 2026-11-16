extends RefCounted

const WordFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")

# What goes quiet behind a pick card. The tree is paused while a pick is up, so a hit word, a
# synergy callout, a toast or Moss's line stamped just before it would hang in the picture and
# make the card read as part of the fight (PF-30). Each owner hides and restores what it owns:
# the HUD (toasts, callout, hit numbers, corner cards) and the world's word effects. Nothing
# here changes what those owners track; they only stop drawing.


# Holds are counted, so a kit pick and the start card's briefing can overlap and neither one's
# release undoes the other's: the HUD and the word effects come back when the last hold lets go.
static var _holds := {}
static var _total := 0


# Hushes the fight's transient words and returns what to give back.
static func hush(host) -> Array:
	var game = host.get("game") if host != null else null
	if game == null:
		return []
	var hud = game.hud
	_holds[hud] = int(_holds.get(hud, 0)) + 1
	if _holds[hud] == 1:
		hud.quiet(true)
	_total += 1
	WordFxWord.quiet(true)
	return [hud]


# Gives back what hush hid.
static func restore(hidden: Array) -> void:
	for hud in hidden:
		if _total <= 0:
			continue
		_total -= 1
		if _holds.has(hud):
			_holds[hud] -= 1
			if _holds[hud] <= 0:
				_holds.erase(hud)
				if is_instance_valid(hud):
					hud.quiet(false)
	if _total <= 0:
		_total = 0
		WordFxWord.quiet(false)
