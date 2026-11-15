extends RefCounted

# The one screen-layout rule (CONTRACTS, UI regions). Four horizontal bands, as shares
# of the visible height, that never overlap:
#   top      screen titles, the objective with its core pips, the run status
#   toasts   the stage card or one toast (TOAST_ROWS), then a first-run callout or the
#            hold-R restart meter
#   prompts  world-attached prompts such as fabricators, placed under their anchor and
#            clamped inside this band
#   bottom   the HUD: speed, health, the ability bar, heft and scrap
# The middle of the screen between toasts and prompts is left to the play view and
# the reticle, with the contextual key glyphs beside the ball or target and the edge
# markers at its rim. A sign (a reward gate's offer) hangs from the thing it names in its own
# slot of the sign room (sign_slot), the play view and the prompts band together, clear of the
# ball and the reticle and moved only down (PF-22). Everything that draws text during play asks
# this file for its band.

const BANDS := {
	"top": Vector2(0.0, 0.14),
	"toasts": Vector2(0.15, 0.29),
	"prompts": Vector2(0.62, 0.84),
	"bottom": Vector2(0.86, 1.0),
}
const ORDER := ["top", "toasts", "prompts", "bottom"]
const SIDE_MARGIN := 0.06
const TOAST_ROWS := 1
# Band prompts only: a reward gate's sign is not counted, every standing gate gets its own name.
const MAX_PROMPTS := 3
const PROMPT_WIDTH := 360.0
const PROMPT_GAP := 12.0
const PROMPT_GROUP := "world_prompt"
# A sign's top stands this far under its anchor, so the name hangs from the gate's crossbar.
const SIGN_DROP := 6.0


static func rect(region: String, size: Vector2) -> Rect2:
	var band: Vector2 = BANDS[region]
	var x := 0.0
	var w := size.x
	if region == "prompts":
		x = size.x * SIDE_MARGIN
		w = size.x * (1.0 - 2.0 * SIDE_MARGIN)
	return Rect2(x, size.y * band.x, w, size.y * (band.y - band.x))


# Where a prompt of prompt_size goes when its anchor projects to `at`: centred on the
# anchor's column and just above it, clamped inside the prompts band.
static func clamp_prompt(at: Vector2, prompt_size: Vector2, size: Vector2) -> Vector2:
	var band := rect("prompts", size)
	var x := clampf(at.x - prompt_size.x * 0.5, band.position.x, maxf(band.position.x, band.end.x - prompt_size.x))
	var y := clampf(at.y - prompt_size.y, band.position.y, maxf(band.position.y, band.end.y - prompt_size.y))
	return Vector2(x, y)


# Where a sign may stand: from under the toasts band to the bottom of the prompts band, inside
# the prompts band's side margins.
static func sign_room(size: Vector2) -> Rect2:
	var band := rect("prompts", size)
	var top := rect("toasts", size).end.y
	return Rect2(band.position.x, top, band.size.x, band.end.y - top)


# The slot of the sign room that gate `index` owns, given the screen columns of every standing gate
# (placed or not): from the midpoint to its left neighbour's column to the midpoint to its right
# neighbour's, each shared side inset by half PROMPT_GAP, an outermost gate's side running to the
# room's. Slots never overlap, so no sign can reach another gate's column. An empty rect when the gate's
# own column is not inside its slot (the gate stands off the room's sides, or too near a neighbour).
static func sign_slot(columns: Array[float], index: int, size: Vector2) -> Rect2:
	var room := sign_room(size)
	var own := columns[index]
	var lo := room.position.x
	var hi := room.end.x
	for i in columns.size():
		if i == index:
			continue
		var mid := (columns[i] + own) * 0.5
		if columns[i] < own or (columns[i] == own and i < index):
			lo = maxf(lo, mid + PROMPT_GAP * 0.5)
		else:
			hi = minf(hi, mid - PROMPT_GAP * 0.5)
	if own < lo or own > hi:
		return Rect2()
	return Rect2(lo, room.position.y, hi - lo, room.size.y)
