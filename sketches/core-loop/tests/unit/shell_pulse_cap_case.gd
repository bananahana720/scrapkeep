extends RefCounted

const Juice := preload("res://src/presentation/juice.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")

# The ball's swell on a pickup (presentation/juice.gd pulse): one pickup swells it as it always did,
# and a pile landing together cannot swell it past a fifth. The kicks used to add with no ceiling:
# twelve pieces in one frame doubled the ball (2.04), thirty over a quarter second tripled it.

const FRAME := 1.0 / 60.0
# What one kick did before the limits, to a thousandth: a piece at the streak's cap, a part, a loss.
const ONE_PIECE := 1.086
const ONE_PART := 1.065
const ONE_LOSS := 0.881
const MOST := 1.2


# The shell's highest and lowest size over three seconds: kicks[frame] is that frame's pulses.
func _swing(kicks: Dictionary) -> Vector2:
	var juice = Juice.new()
	var reach := Vector2(1.0, 1.0)
	for frame in 180:
		for amount in kicks.get(frame, []):
			juice.pulse(amount)
		juice.step_springs(FRAME)
		reach = Vector2(maxf(reach.x, juice.shell), minf(reach.y, juice.shell))
	juice.free()
	return reach


func run(t) -> void:
	var piece := float(EventJuice.juice("scrap_collected")["pulse_cap"])
	var loss := float(EventJuice.juice("scrap_lost")["pulse"])
	var one := _swing({0: [piece]})
	var part := _swing({0: [0.12]})
	var lost := _swing({0: [loss]})
	t.check("one pickup swells the ball as it did", absf(one.x - ONE_PIECE) < 0.002 and absf(part.x - ONE_PART) < 0.002, "piece %.3f (was %.3f), part %.3f (was %.3f)" % [one.x, ONE_PIECE, part.x, ONE_PART])
	t.check("a loss shrinks it as it did", absf(lost.y - ONE_LOSS) < 0.002, "%.3f (was %.3f)" % [lost.y, ONE_LOSS])
	var at_once := {0: []}
	for i in 12:
		at_once[0].append(piece)
	var stream := {}
	var pairs := {}
	var slow := {}
	for i in 30:
		stream[i] = [piece]
	for i in 15:
		pairs[i] = [piece, piece]
	for i in 40:
		slow[i * 3] = [piece]
	var peaks := [_swing(at_once).x, _swing(stream).x, _swing(pairs).x, _swing(slow).x]
	t.check("a pile landing together swells it more than one piece and never past a fifth", peaks.min() > one.x and peaks.max() <= MOST,
		"twelve at once %.3f (was 2.037), thirty one a frame %.3f (was 2.191), thirty two a frame %.3f (was 3.080), forty every third frame %.3f (was 1.400)" % peaks)
	var losses := {}
	for i in 12:
		losses[i] = [loss]
	var shrunk := _swing(losses)
	t.check("a run of losses cannot shrink it past a fifth either", shrunk.y >= 2.0 - MOST and shrunk.y < lost.y, "%.3f" % shrunk.y)
