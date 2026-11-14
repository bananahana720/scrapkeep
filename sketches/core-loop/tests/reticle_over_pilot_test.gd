extends SceneTree

const AimReticle := preload("res://src/ui/aim_reticle.gd")
const T := preload("res://tests/support/t.gd")

# The reticle does not hide the pilot (finding UF-06, UI principle P1). The pilot rides in view
# inside the ball, and at the resting camera the aim point sits on them. While it does, the
# reticle's dark tracks and fills drop away and its lines thin, and the aim point stays whole.
#   - clear of the pilot the reticle is drawn at full strength;
#   - on the pilot it is fully "over";
#   - the change is gradual: it never jumps more than a third in 4 px;
#   - the lines keep at least half their strength (the readings still read) and the dark
#     parts keep at most a quarter (the pilot shows through);
#   - planted: no pilot on screen means never over; a reticle with LINE_OVER 1 and BACK_OVER 1
#     would not thin at all, and the judge below says so.

var _t := T.new("reticle_over_pilot_test")


func _initialize() -> void:
	var pilot := 26.0
	_t.eq("clear of the pilot the reticle is whole", AimReticle.over_pilot(pilot + AimReticle.RING + AimReticle.BAND + 1.0, pilot), 0.0)
	_t.eq("on the pilot the reticle is over them", AimReticle.over_pilot(0.0, pilot), 1.0)
	_t.eq("touching the pilot with its inner ring, it is over them", AimReticle.over_pilot(pilot + AimReticle.RING, pilot), 1.0)
	var worst := 0.0
	var last := AimReticle.over_pilot(0.0, pilot)
	var rising := false
	for px in range(4, 120, 4):
		var now := AimReticle.over_pilot(float(px), pilot)
		worst = maxf(worst, absf(now - last))
		rising = rising or now > last
		last = now
	_t.check("the change never jumps more than a third in 4 px", worst <= 0.34, "%.2f" % worst)
	_t.check("moving away from the pilot never thins the reticle more", not rising)
	_t.check("the lines and the dark parts hold their bounds", _thins(AimReticle.LINE_OVER, AimReticle.BACK_OVER),
		"lines %.2f, dark parts %.2f" % [AimReticle.LINE_OVER, AimReticle.BACK_OVER])
	_t.eq("planted: no pilot on screen is never over", AimReticle.over_pilot(0.0, 0.0), 0.0)
	_t.check("planted: a reticle that does not thin fails the bounds", not _thins(1.0, 1.0))
	_t.check("planted: lines thinned to a ghost fail the bounds", not _thins(0.2, 0.2))
	quit(_t.verdict())


static func _thins(lines: float, dark: float) -> bool:
	return lines >= 0.5 and lines < 1.0 and dark <= 0.25
