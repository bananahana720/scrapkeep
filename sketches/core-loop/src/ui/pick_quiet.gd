extends RefCounted

const WordFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")

# What goes quiet behind a pick card. The tree is paused while a pick is up, so a hit word, a
# synergy callout, a toast or Moss's line stamped just before it would hang in the picture and
# make the card read as part of the fight (PF-30). Each owner hides and restores what it owns:
# the HUD (toasts, callout, hit numbers, corner cards) and the world's word effects. Nothing
# here changes what those owners track; they only stop drawing.


# Hushes the fight's transient words and returns what to give back.
static func hush(host) -> Array:
	var game = host.get("game") if host != null else null
	if game == null:
		return []
	game.hud.quiet(true)
	WordFxWord.quiet(true)
	return [game.hud]


# Gives back what hush hid.
static func restore(hidden: Array) -> void:
	for hud in hidden:
		if is_instance_valid(hud):
			hud.quiet(false)
	WordFxWord.quiet(false)
