extends RefCounted


const BANDS := {
	"top": Vector2(0.0, 0.14),
	"toasts": Vector2(0.15, 0.29),
	"prompts": Vector2(0.62, 0.84),
	"bottom": Vector2(0.86, 1.0),
}
const ORDER := ["top", "toasts", "prompts", "bottom"]
const SIDE_MARGIN := 0.06
const TOAST_ROWS := 1
const MAX_PROMPTS := 3
const PROMPT_WIDTH := 360.0
const PROMPT_GAP := 12.0
const PROMPT_GROUP := "world_prompt"


static func rect(region: String, size: Vector2) -> Rect2:
	var band: Vector2 = BANDS[region]
	var x := 0.0
	var w := size.x
	if region == "prompts":
		x = size.x * SIDE_MARGIN
		w = size.x * (1.0 - 2.0 * SIDE_MARGIN)
	return Rect2(x, size.y * band.x, w, size.y * (band.y - band.x))


static func clamp_prompt(at: Vector2, prompt_size: Vector2, size: Vector2) -> Vector2:
	var band := rect("prompts", size)
	var x := clampf(at.x - prompt_size.x * 0.5, band.position.x, maxf(band.position.x, band.end.x - prompt_size.x))
	var y := clampf(at.y - prompt_size.y, band.position.y, maxf(band.position.y, band.end.y - prompt_size.y))
	return Vector2(x, y)
