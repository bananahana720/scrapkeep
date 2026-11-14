extends SceneTree

const Gauge := preload("res://src/ui/gauge.gd")
const T := preload("res://tests/support/t.gd")

# The welded stretch of a bar carries its own shape, a cross (UI finding UF-07, principle P2:
# colour never works alone). Under red-green colour blindness the weld's edge colour and the
# armour bar beside it read as one, so the cross is what says "welded off".
#   - a plate wide enough carries a cross, inside the plate and clear of its edge;
#   - a plate too narrow for a clean cross carries none;
#   - a weld over a tenth of the HUD's health bar (hud.gd HEALTH_BAR, 190 px) is wide enough
#     to carry it; a thinner weld is told by the bracket alone;
#   - planted: a cross as tall as the bar would touch the plate's edge, and the judge says so.

var _t := T.new("ui_gauge_weld_test")


func _initialize() -> void:
	var plate := Rect2(Vector2(100.0, 7.0), Vector2(40.0, Gauge.BAR_H))
	var mark := Gauge.weld_mark(plate)
	_t.check("a wide plate carries a cross", mark.size.x > 0.0 and is_equal_approx(mark.size.x, mark.size.y), str(mark))
	_t.check("the cross sits inside the plate, clear of its edge", _clear(plate, mark), str(mark))
	_t.check("the cross is big enough to see", mark.size.x >= 6.0, "%.1f px" % mark.size.x)
	_t.eq("a plate too narrow for a clean cross carries none", Gauge.weld_mark(Rect2(Vector2.ZERO, Vector2(8.0, Gauge.BAR_H))).size, Vector2.ZERO)
	var hull_bar := 190.0
	_t.check("a weld a tenth of the health bar carries the cross", Gauge.weld_mark(Rect2(Vector2.ZERO, Vector2(hull_bar * 0.1, Gauge.BAR_H))).size.x > 0.0)
	_t.check("planted: a cross as tall as the bar is not clear of the edge", not _clear(plate, Rect2(plate.get_center() - Vector2(6.0, 6.0), Vector2(12.0, 12.0))))
	quit(_t.verdict())


static func _clear(plate: Rect2, mark: Rect2) -> bool:
	return mark.size.x > 0.0 and plate.grow(-2.0).encloses(mark)
