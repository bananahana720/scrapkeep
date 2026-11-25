extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")


const R := 44.0
const ICON := 46.0
const FONT := UiTokens.BODY
const NODES := {
	"scrap": {"at": Vector2(90.0, 84.0), "icon": "res_mass", "kind": "scrap_collected", "words": "roll scrap"},
	"heft": {"at": Vector2(390.0, 84.0), "icon": "res_heft", "kind": "heft_class_changed", "words": "heft grows"},
	"punch": {"at": Vector2(690.0, 84.0), "icon": "cat_damage", "kind": "beacon_unsealed", "words": "outpunch plating"},
	"warden": {"at": Vector2(990.0, 84.0), "icon": "obj_warden", "kind": "warden_engaged", "words": "break Warden"},
	"parts": {"at": Vector2(240.0, 250.0), "icon": "obj_gate", "kind": "part_gained", "words": "gate parts"},
	"moss": {"at": Vector2(540.0, 250.0), "icon": "", "kind": "bay_entered", "words": "Moss trades"},
	"tree": {"at": Vector2(840.0, 250.0), "icon": "", "kind": "tree_offered", "words": "pick one"},
}
const LINKS := [["scrap", "heft"], ["heft", "punch"], ["punch", "warden"], ["parts", "heft"], ["tree", "punch"], ["moss", "parts"]]

var clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(1080.0, 340.0)


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	for id in NODES:
		out.append(NODES[id]["words"])
	return out


func _process(delta: float) -> void:
	if is_visible_in_tree():
		clock += delta
		queue_redraw()


func _draw() -> void:
	for link in LINKS:
		_link(NODES[link[0]], NODES[link[1]])
	for id in NODES:
		_node(id, NODES[id])


func _link(a: Dictionary, b: Dictionary) -> void:
	var from: Vector2 = a["at"]
	var to: Vector2 = b["at"]
	var dir := (to - from).normalized()
	var start := from + dir * (R + 8.0)
	var end := to - dir * (R + 12.0)
	var color := EventKinds.color(a["kind"])
	draw_line(start, end, Color(color, 0.35), 3.0)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([end + dir * 10.0, end - dir * 4.0 + side * 8.0, end - dir * 4.0 - side * 8.0]), Color(color, 0.8))
	for i in 3:
		var f := fmod(clock * 0.6 + i / 3.0, 1.0)
		draw_circle(start.lerp(end, f), 4.0, Color(color, sin(f * PI)))


func _node(id: String, node: Dictionary) -> void:
	var at: Vector2 = node["at"]
	var color := EventKinds.color(node["kind"])
	var beat := 1.0 + 0.06 * sin(clock * 3.0 + at.x * 0.01)
	draw_circle(at, R * beat, Color(Palette.CHARCOAL, 0.95))
	draw_arc(at, R * beat, 0.0, TAU, 48, color, 3.0)
	match id:
		"tree":
			for side in [-1.0, 1.0]:
				_card(at + Vector2(side * 12.0, 2.0), side * 0.26 + 0.05 * sin(clock * 2.0), color)
		"moss":
			_bubble(at, color)
		_:
			var icon: String = node["icon"]
			draw_texture_rect(Icons.texture(icon), Rect2(at - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), false, Icons.tint(icon, color))
	var shape: String = EventKinds.row(node["kind"]).get("shape", "none")
	if shape != "none":
		draw_texture_rect(Icons.shape(shape), Rect2(at + Vector2(R * 0.55, -R * 1.05), Vector2(18.0, 18.0)), false, color)
	var font := UiFonts.bold()
	var words: String = node["words"]
	var below: bool = at.y > 150.0
	ScrapFrame.stamp(self, words, font, FONT, Palette.SAND, Color(color, 0.55), id.hash(), Vector2(at.x, at.y + (R + 22.0 if below else -R - 24.0)))


func _card(at: Vector2, tilt: float, color: Color) -> void:
	draw_set_transform(at, tilt, Vector2.ONE)
	var rect := Rect2(Vector2(-13.0, -19.0), Vector2(26.0, 38.0))
	draw_rect(rect, Color(Palette.CHARCOAL, 0.95))
	draw_rect(rect, color, false, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)]), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _bubble(at: Vector2, color: Color) -> void:
	var rect := Rect2(at - Vector2(24.0, 20.0), Vector2(48.0, 32.0))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.25)
	box.border_color = color
	box.set_border_width_all(2)
	box.set_corner_radius_all(UiTokens.RADIUS)
	draw_style_box(box, rect)
	draw_colored_polygon(PackedVector2Array([rect.end - Vector2(18.0, 1.0), rect.end - Vector2(8.0, 1.0), rect.end + Vector2(-16.0, 12.0)]), color)
	draw_texture_rect(Icons.texture("res_scrap"), Rect2(rect.get_center() - Vector2(12.0, 12.0), Vector2(24.0, 24.0)), false, Icons.tint("res_scrap", Palette.ARC))
