extends Control

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const ThreatGrammar := preload("res://src/combat/threat_grammar.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")


const TILE := Vector2(260.0, 300.0)
const GAP := 24.0
const STAGE := 190.0
const LOOP := 1.8
const WARN := 1.3
const STRIPE := 11.0
const WORDS := {
	"threat_instant": "leave ring",
	"threat_wave": "jump wave",
	"threat_projectile": "dodge shell",
	"threat_lane": "exit lane",
	"own": "yours, harmless",
}
const ICONS := {
	"threat_instant": "thr_instant", "threat_wave": "thr_wave", "threat_projectile": "thr_projectile", "threat_lane": "thr_lane",
}

var clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(tiles().size() * (TILE.x + GAP) - GAP, TILE.y)


static func tiles() -> Array[String]:
	var out: Array[String] = []
	for kind in ThreatGrammar.KINDS:
		out.append(kind)
	out.append("own")
	return out


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	for id in tiles():
		out.append(WORDS[id])
	return out


func _process(delta: float) -> void:
	if is_visible_in_tree():
		clock += delta
		queue_redraw()


func _draw() -> void:
	var list := tiles()
	for i in list.size():
		var id: String = list[i]
		var rect := Rect2(Vector2(i * (TILE.x + GAP), 0.0), TILE)
		var tone := Palette.AMBER if id == "own" else Palette.HAZARD
		var tape := ScrapFrame.quirk(i, 9) if ScrapFrame.quirk(i, 8) > 0.45 else -1.0
		draw_style_box(ScrapFrame.plate(Color(tone, 0.8), i + 11, Color(Palette.CHARCOAL, 0.95), 2.0, tape), rect)
		var stage := Rect2(rect.position + Vector2(10.0, 10.0), Vector2(TILE.x - 20.0, STAGE))
		var p := fmod(clock + i * 0.23, LOOP) / WARN
		match id:
			"threat_instant":
				_instant(stage.get_center(), p)
			"threat_wave":
				_wave(stage.get_center(), p)
			"threat_projectile":
				_projectile(stage, p)
			"threat_lane":
				_lane(stage, p)
			"own":
				_own(stage.get_center(), p)
		var row_y := stage.end.y + 14.0
		var mid := rect.position.x + TILE.x * 0.5
		if ICONS.has(id):
			draw_texture_rect(Icons.texture(ICONS[id]), Rect2(Vector2(mid - 34.0, row_y), Vector2(30.0, 30.0)), false, Icons.tint(ICONS[id], tone))
			var shape: String = EventKinds.THREAT_ROWS[id]["shape"]
			draw_texture_rect(Icons.shape(shape), Rect2(Vector2(mid + 6.0, row_y + 4.0), Vector2(22.0, 22.0)), false, tone)
		else:
			draw_texture_rect(Icons.shape("ring"), Rect2(Vector2(mid - 13.0, row_y + 2.0), Vector2(26.0, 26.0)), false, tone)
		var font := UiFonts.bold()
		var words: String = WORDS[id]
		ScrapFrame.stamp(self, words, font, 20, Palette.SAND, Color(tone, 0.6), i + 11, Vector2(mid, row_y + 56.0))


func _instant(at: Vector2, p: float) -> void:
	var r := 62.0
	_keyline_circle(at, r, Palette.HAZARD)
	if p < 1.0:
		_stripes(at, r, r * (1.0 - p), Palette.HAZARD)
	elif p < 1.2:
		draw_circle(at, r, Color(Palette.HAZARD, 0.9))


func _wave(at: Vector2, p: float) -> void:
	var reach := 72.0
	for i in 24:
		var a := TAU * i / 24.0
		draw_arc(at, reach, a, a + TAU / 48.0, 4, Color(Palette.HAZARD, 0.5), 2.0)
	var front := reach * clampf(p, 0.0, 1.0)
	if p < 1.0:
		_stripes(at, front, 0.0, Color(Palette.HAZARD, 0.4))
		draw_arc(at, front, 0.0, TAU, 48, Palette.CHARCOAL, 7.0)
		draw_arc(at, front, 0.0, TAU, 48, Palette.HAZARD.lightened(0.35), 4.0)
		for i in 6:
			var dir := Vector2.RIGHT.rotated(TAU * i / 6.0)
			_chevron(at + dir * (front + 9.0), dir, Palette.HAZARD)


func _projectile(stage: Rect2, p: float) -> void:
	var from := stage.position + Vector2(18.0, stage.size.y - 18.0)
	var land := stage.get_center() + Vector2(30.0, -6.0)
	var r := 34.0
	var f := clampf(p, 0.0, 1.0)
	for i in 14:
		var s := float(i) / 13.0
		if s < f:
			continue
		draw_circle(_lob(from, land, s), 2.5, Color(Palette.HAZARD, 0.85))
	if p < 1.0:
		draw_circle(_lob(from, land, f), 6.0, Palette.CHARCOAL)
		draw_circle(_lob(from, land, f), 4.5, Palette.HAZARD.lightened(0.3))
	_keyline_circle(land, r, Color(Palette.HAZARD, 0.8))
	var open := lerpf(1.6, 0.72, clampf(p, 0.0, 1.0)) * r
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var c := land + Vector2.RIGHT.rotated(a) * open
		draw_arc(c, 10.0, a + PI * 0.75, a + PI * 1.25, 6, Palette.HAZARD, 3.0)
	if p >= 1.0 and p < 1.2:
		draw_circle(land, r, Color(Palette.HAZARD, 0.9))


func _lane(stage: Rect2, p: float) -> void:
	var strip := Rect2(stage.position + Vector2(14.0, stage.size.y * 0.5 - 24.0), Vector2(stage.size.x - 28.0, 48.0))
	for y in [strip.position.y, strip.end.y]:
		draw_line(Vector2(strip.position.x, y), Vector2(strip.end.x, y), Palette.CHARCOAL, 6.0)
		draw_line(Vector2(strip.position.x, y), Vector2(strip.end.x, y), Palette.HAZARD, 3.0)
	draw_rect(Rect2(strip.position - Vector2(10.0, 4.0), Vector2(10.0, strip.size.y + 8.0)), Palette.HAZARD)
	var run := Rect2(strip.position, Vector2(strip.size.x * clampf(p, 0.0, 1.0), strip.size.y))
	if p < 1.0:
		_rect_stripes(run, Palette.HAZARD)
	elif p < 1.2:
		draw_rect(strip, Color(Palette.HAZARD, 0.9))


func _own(at: Vector2, p: float) -> void:
	var r := 30.0 + 34.0 * clampf(p, 0.0, 1.0)
	draw_circle(at, r, Color(Palette.AMBER, 0.25))
	draw_arc(at, r, 0.0, TAU, 48, Palette.AMBER, 3.0)


func _keyline_circle(at: Vector2, r: float, color: Color) -> void:
	draw_arc(at, r, 0.0, TAU, 56, Palette.CHARCOAL, 7.0)
	draw_arc(at, r, 0.0, TAU, 56, color, 3.5)


func _stripes(at: Vector2, r_out: float, r_in: float, color: Color) -> void:
	var along := Vector2(1.0, 1.0).normalized()
	var normal := Vector2(1.0, -1.0).normalized()
	var s := -r_out
	while s <= r_out:
		var outer := sqrt(maxf(r_out * r_out - s * s, 0.0))
		var base := at + normal * s
		if absf(s) >= r_in:
			draw_line(base - along * outer, base + along * outer, color, 4.0)
		else:
			var inner := sqrt(r_in * r_in - s * s)
			draw_line(base - along * outer, base - along * inner, color, 4.0)
			draw_line(base + along * inner, base + along * outer, color, 4.0)
		s += STRIPE


func _rect_stripes(rect: Rect2, color: Color) -> void:
	if rect.size.x < 1.0:
		return
	var poly := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var x := rect.position.x - rect.size.y
	while x < rect.end.x:
		var line := PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + rect.size.y, rect.position.y)])
		for piece in Geometry2D.intersect_polyline_with_polygon(line, poly):
			draw_line(piece[0], piece[piece.size() - 1], color, 4.0)
		x += STRIPE * 1.4


func _chevron(at: Vector2, dir: Vector2, color: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	draw_polyline(PackedVector2Array([at - dir * 4.0 + side * 6.0, at + dir * 3.0, at - dir * 4.0 - side * 6.0]), color, 3.0)


static func _lob(from: Vector2, to: Vector2, s: float) -> Vector2:
	return from.lerp(to, s) + Vector2(0.0, -70.0 * 4.0 * s * (1.0 - s))
