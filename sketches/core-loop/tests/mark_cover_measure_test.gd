extends SceneTree

const Cover := preload("res://tools/mark_cover_capture.gd")
const T := preload("res://tests/support/t.gd")

# UA-03 (principle P1): the arithmetic behind tools/mark_cover_capture.gd, on synthetic images, no
# GPU. A warning that paints over half the attacker must score 0.5 and fail the line, one that
# paints beside it must score 0, and a control that moved by itself must be subtracted.

var _t := T.new("mark_cover_measure_test")


func _flat(c: Color) -> Image:
	var image := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	image.fill(c)
	return image


func _initialize() -> void:
	var base := _flat(Color8(100, 100, 100))
	# The crew is the 20 x 20 square at the origin: the mask from a frame with it and without it.
	var with_crew := _flat(Color8(100, 100, 100))
	with_crew.fill_rect(Rect2i(0, 0, 20, 20), Color8(200, 60, 60))
	var crew_mask: PackedByteArray = Cover._mask(with_crew, [base])
	_t.eq("the crew mask holds the 400 crew pixels", Cover._count(crew_mask), 400)

	var over_half := with_crew.duplicate()
	over_half.fill_rect(Rect2i(0, 0, 20, 10), Color8(30, 200, 30))
	var body: float = Cover._changed(over_half, [with_crew], crew_mask)
	_t.near("a mark over the top half of the crew changes 0.5 of it", body, 0.5)
	_t.near("and scores 0.5 with a quiet control", Cover.score(body, 0.0), 0.5)
	_t.check("0.5 is over the line", Cover.score(body, 0.0) > Cover.COVER_LINE, "line %s" % Cover.COVER_LINE)

	var beside := with_crew.duplicate()
	beside.fill_rect(Rect2i(20, 0, 20, 40), Color8(30, 200, 30))
	var body_beside: float = Cover._changed(beside, [with_crew], crew_mask)
	_t.near("a mark beside the crew changes 0 of it", body_beside, 0.0)
	_t.check("and passes", Cover.score(body_beside, 0.0) <= Cover.COVER_LINE)

	var quarter := with_crew.duplicate()
	quarter.fill_rect(Rect2i(0, 0, 10, 10), Color8(30, 200, 30))
	var body_quarter: float = Cover._changed(quarter, [with_crew], crew_mask)
	_t.near("a mark over a quarter changes 0.25", body_quarter, 0.25)
	_t.near("a control that itself moved 0.25 is subtracted down to 0", Cover.score(body_quarter, 0.25), 0.0)
	_t.near("a control that moved 0.1 leaves 0.15", Cover.score(body_quarter, 0.1), 0.15)

	var tiny := with_crew.duplicate()
	tiny.fill_rect(Rect2i(0, 0, 20, 20), Color8(210, 60, 60))
	_t.near("a change under the 24 level threshold is not counted", Cover._changed(tiny, [with_crew], crew_mask), 0.0)

	var empty := PackedByteArray()
	empty.resize(1600)
	_t.eq("an empty crew mask has no share", Cover._changed(over_half, [with_crew], empty), -1.0)
	_t.eq("and scores 1.0, so a blind measure fails", Cover.score(-1.0, 0.0), 1.0)

	# Planted wrong input: a score that forgot to subtract a control must not agree with the right one.
	var wrong: float = body_quarter
	_t.check("planted: the unsubtracted 0.25 differs from the subtracted score", not is_equal_approx(wrong, Cover.score(body_quarter, 0.25)))
	quit(_t.verdict())
