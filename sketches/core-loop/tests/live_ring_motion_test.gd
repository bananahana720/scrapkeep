extends SceneTree

# PF-16 (w42 first-timer film, pictures 099-104): Brindle's live slag ring read as floor paint,
# because a live ring's fill read no time and so never moved. The hazard's descriptor now carries
# the live age, and the fill's tint swings with it (threat_grammar.gd fill_tint). Only the tint
# moves: warning seconds, live seconds and the ring's contains() are the committed numbers.

const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")

const DT := 1.0 / 60.0

var _t := T.new("live_ring_motion_test")


func _initialize() -> void:
	_run.call_deferred()


func _ring() -> Node:
	var h := Hazard.new()
	h.commit_annulus("slag", Threat.Type.INSTANT, Vector3.ZERO, Vector2(16.0, 21.0), 1.8, 2.5, 6.0)
	root.add_child(h)
	return h


func _fill(h: Node) -> Color:
	return (h.painter()._layer("fill").material_override as StandardMaterial3D).albedo_color


func _step_to(h: Node, age: float) -> void:
	var guard := 0
	while h.age < age and guard < 2000:
		h.step(DT)
		guard += 1


func _run() -> void:
	for look in ["clear", "classic"]:
		Threat.set_haze(look == "clear")
		var h := _ring()
		_step_to(h, 1.0)
		var early := _fill(h)
		_step_to(h, 2.0)
		_t.check("%s: during the warning the fill is unchanged from age 1 s to 2 s" % look, _fill(h) == early and not h.descriptor().has("live_age"), str(early))
		_t.check("%s: the warning's own tint is clear (no live fill yet)" % look, early.a == 0.0, str(early))
		_step_to(h, 2.5 + 0.0 + DT)
		_t.check("%s: live now" % look, h.state == Hazard.LIVE and h.descriptor().has("live_age"))
		_step_to(h, 2.5 + 0.2)
		var a := _fill(h)
		_step_to(h, 2.5 + 0.7)
		var b := _fill(h)
		_t.check("%s: the live fill's tint at two live ages 0.5 s apart differs" % look, a != b, "%s then %s" % [a, b])
		_t.near("%s: and only its colour moves, not its alpha" % look, a.a, b.a)
		_step_to(h, 2.5 + 0.2 + Threat.LIVE_PULSE_SECONDS)
		_t.check("%s: one pulse period later it is back" % look, absf(_fill(h).r - a.r) + absf(_fill(h).g - a.g) + absf(_fill(h).b - a.b) < 0.03, "%s vs %s" % [_fill(h), a])
		# The committed numbers.
		_t.near("%s: warn_seconds" % look, h.warn_seconds, 2.5)
		_t.near("%s: live_seconds" % look, h.live_seconds, 6.0)
		_t.check("%s: contains() in the band" % look, h.contains(Vector3(18.0, 0.0, 0.0)))
		_t.check("%s: contains() inside the hole" % look, not h.contains(Vector3(10.0, 0.0, 0.0)))
		_t.check("%s: contains() beyond the rim" % look, not h.contains(Vector3(23.0, 0.0, 0.0)))
		h.free()
	Threat.set_haze(true)
	quit(_t.verdict())
