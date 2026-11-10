extends RefCounted

# What goes quiet behind a pick card. The tree is paused while a pick is up, so a hit word, a
# synergy callout or Moss's line stamped just before it would hang in the picture and make the
# card read as part of the fight (PF-30). The pick hides them on open and gives back exactly the
# ones it hid on close. Nothing here changes what those owners track; they only stop drawing.

const WORD_SCRIPT := "res://src/presentation/world_fx/world_fx_word.gd"


# Hides the fight's transient words under `host` (the workshop) and returns what it hid.
static func hush(host) -> Array:
	var hidden: Array = []
	var game = host.get("game") if host != null else null
	if game == null:
		return hidden
	_hide(host.get("bubble"), hidden)
	var hud = game.get("hud")
	if hud != null:
		_hide(hud.get("why_callout"), hidden)
		_hide(hud.get("damage_numbers"), hidden)
	_hide_words(game, hidden)
	return hidden


# Gives back what hush hid; a node that has since left the tree is skipped.
static func restore(hidden: Array) -> void:
	for item in hidden:
		if is_instance_valid(item):
			item.visible = true


static func _hide(item, hidden: Array) -> void:
	if item != null and item.visible:
		item.visible = false
		hidden.append(item)


static func _hide_words(node: Node, hidden: Array) -> void:
	for child in node.get_children():
		if child is Label3D and child.get_script() != null and child.get_script().resource_path == WORD_SCRIPT:
			_hide(child, hidden)
		else:
			_hide_words(child, hidden)
