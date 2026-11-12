extends SceneTree

const EdgeMarkers := preload("res://src/ui/edge_markers.gd")

# PF-35 (w37 film 081-082): Brindle's MAGNET tag stood over the player's own ball when the
# magnet was behind it on screen, so the ball read as the target. A mark's tag stays off the
# ball and the readouts riding on it (the HUD's keep_clear): over the brackets if clear, else
# under them, else no tag. The brackets stay where the thing is.

var _t := preload("res://tests/support/t.gd").new("ui_mark_tag_clear_test")


func _initialize() -> void:
	var room := Rect2(0, 120, 1600, 520)
	var box := Rect2(780, 400, 60, 60)
	var none: Array[Rect2] = []
	_t.check("planted: with nothing to keep clear the tag goes over", EdgeMarkers.tag_free(box, "MAGNET", false, room, none, none))
	var over := EdgeMarkers.tag_rect(box, "MAGNET", false)
	var ball: Array[Rect2] = [over.grow(-4.0)]
	_t.check("a ball under the over-tag refuses it", not EdgeMarkers.tag_free(box, "MAGNET", false, room, none, ball))
	_t.check("and the tag still fits under the brackets", EdgeMarkers.tag_free(box, "MAGNET", true, room, none, ball))
	var both: Array[Rect2] = [over.grow(-4.0), EdgeMarkers.tag_rect(box, "MAGNET", true).grow(-4.0)]
	_t.check("both sides covered: no tag", not EdgeMarkers.tag_free(box, "MAGNET", false, room, none, both)
		and not EdgeMarkers.tag_free(box, "MAGNET", true, room, none, both))
	var on_box: Array[Rect2] = [box]
	_t.check("the ball on the brackets alone does not move the tag", EdgeMarkers.tag_free(box, "MAGNET", false, room, none, on_box))
	quit(_t.verdict())
