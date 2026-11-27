extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")


const CATEGORIES := {
	"build": {"label": "Build", "color": Palette.AMBER, "shape": "diamond", "blurb": "Parts that change each other"},
	"world": {"label": "World", "color": Color("5fb3a8"), "shape": "wave", "blurb": "Terrain and element tricks"},
	"enemy": {"label": "Enemies", "color": Palette.COPPER, "shape": "burst", "blurb": "Ways to turn a threat"},
	"npc": {"label": "Folk", "color": Palette.SANDSTONE, "shape": "ring", "blurb": "Reserved"},
	"coop": {"label": "Together", "color": Palette.ARC, "shape": "rings", "blurb": "Reserved"},
}
const ICON_SIZE := 64

static var _icons := {}


static func _spine_table() -> Dictionary:
	var constants := (EventKinds as Script).get_script_constant_map()
	return constants.get("CODEX_CATEGORIES", {})


static func category(id: String) -> Dictionary:
	var entry: Dictionary = CATEGORIES.get(id, CATEGORIES["build"]).duplicate()
	var spine: Dictionary = _spine_table().get(id, {})
	for key in ["color", "shape", "label"]:
		if spine.has(key):
			entry[key] = spine[key]
	entry["id"] = id
	entry["icon"] = icon(id)
	return entry


static func category_color(id: String) -> Color:
	return category(id)["color"]


static func style() -> Dictionary:
	var categories := {}
	for id in CATEGORIES:
		categories[id] = category(id)
	return {
		"categories": categories,
		"order": ["build", "world", "enemy", "npc", "coop"],
		"font_size": {"title": 30, "body": 17},
		"undiscovered": Color(0.55, 0.55, 0.55, 0.8),
	}


static func icon(id: String, tint = null) -> ImageTexture:
	var key := id if not tint is Color else "%s:%s" % [id, (tint as Color).to_html()]
	if _icons.has(key):
		return _icons[key]
	var entry: Dictionary = CATEGORIES.get(id, CATEGORIES["build"])
	var spine: Dictionary = _spine_table().get(id, {})
	var shape: String = spine.get("shape", entry["shape"])
	var color: Color = tint if tint is Color else spine.get("color", entry["color"])
	var image := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var half := ICON_SIZE * 0.5
	for y in ICON_SIZE:
		for x in ICON_SIZE:
			var p := Vector2((x + 0.5 - half) / half, (y + 0.5 - half) / half)
			var d := _distance(shape, p)
			var alpha := clampf(0.5 - d * half * 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	var texture := ImageTexture.create_from_image(image)
	_icons[key] = texture
	return texture


static func _distance(shape: String, p: Vector2) -> float:
	match shape:
		"diamond":
			return (absf(p.x) + absf(p.y)) - 0.8
		"wave":
			var band := absf(p.y - 0.28 * sin(p.x * PI * 1.5)) - 0.16
			return maxf(band, absf(p.x) - 0.85)
		"burst":
			var best := 99.0
			for i in 3:
				var angle := PI * i / 3.0
				var along := Vector2(cos(angle), sin(angle))
				var across := absf(p.dot(Vector2(-along.y, along.x))) - 0.1
				best = minf(best, maxf(across, absf(p.dot(along)) - 0.85))
			return best
		"ring":
			return absf(p.length() - 0.6) - 0.14
		"square":
			return maxf(absf(p.x), absf(p.y)) - 0.62
		"chevron":
			var arm := absf(p.y + 0.35 - absf(p.x) * 0.9) - 0.16
			return maxf(arm, absf(p.x) - 0.8)
		"rings":
			var a := absf((p - Vector2(-0.28, 0.0)).length() - 0.45) - 0.1
			var b := absf((p - Vector2(0.28, 0.0)).length() - 0.45) - 0.1
			return minf(a, b)
	return p.length() - 0.7
