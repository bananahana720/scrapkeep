extends SceneTree

const EdgeMarkers := preload("res://src/ui/edge_markers.gd")

# PF-35 (w37 film 081-082): Brindle's MAGNET tag stood over the player's own ball when the
# magnet was behind it on screen, so the ball read as the target. A mark's tag stays off the
# ball and the readouts riding on it (the HUD's keep_clear): over the brackets, slid along a
# little if that clears it, else under them the same way, else no tag. The brackets stay put.

var _t := preload("res://tests/support/t.gd").new("ui_mark_tag_clear_test")


func _initialize() -> void:
	var room := Rect2(0, 120, 1600, 520)
	var box := Rect2(780, 400, 60, 60)
	var none: Array[Rect2] = []
	_t.eq("planted: with nothing to keep clear the tag goes over, centred", EdgeMarkers.tag_place(box, "MAGNET", room, none, none), {"under": false, "shift": 0.0})
	var over := EdgeMarkers.tag_rect(box, "MAGNET", false)
	# A ball a little left of the over-tag: the chip slides right just off it.
	var nudge: Array[Rect2] = [Rect2(over.position.x - 40.0, over.position.y, 50.0, over.size.y)]
	var slid := EdgeMarkers.tag_place(box, "MAGNET", room, none, nudge)
	_t.check("a ball at the over-tag's edge slides it along, still over", not slid.is_empty() and not slid["under"] and slid["shift"] > 0.0
		and not nudge[0].intersects(EdgeMarkers.tag_rect(box, "MAGNET", false, slid["shift"])), str(slid))
	_t.check("and its stem still meets the brackets' column", not slid.is_empty() and EdgeMarkers.tag_rect(box, "MAGNET", false, slid["shift"]).position.x + 8.0 <= box.end.x, str(slid))
	# A ball wider than the chip right over the brackets: no slide clears it, so the tag goes under.
	var wide: Array[Rect2] = [over.grow(40.0)]
	_t.eq("a ball covering the over-tag sends it under", EdgeMarkers.tag_place(box, "MAGNET", room, none, wide), {"under": true, "shift": 0.0})
	var both: Array[Rect2] = [over.grow(40.0), EdgeMarkers.tag_rect(box, "MAGNET", true).grow(40.0)]
	_t.check("both sides covered: no tag", EdgeMarkers.tag_place(box, "MAGNET", room, none, both).is_empty())
	var on_box: Array[Rect2] = [box]
	_t.eq("the ball on the brackets alone does not move the tag", EdgeMarkers.tag_place(box, "MAGNET", room, none, on_box), {"under": false, "shift": 0.0})
	quit(_t.verdict())
