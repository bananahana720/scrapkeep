extends RefCounted


const WORLD_REACH := 60.0


static func count(root: Node, camera: Camera3D = null) -> Dictionary:
	var out := {"hud": 0, "world": 0, "items": []}
	_walk(root, camera, out)
	return out


static func words_in(text: String) -> int:
	var n := 0
	for token in text.split(" ", false):
		for part in token.split("\n", false):
			if _has_alnum(part):
				n += 1
	return n


static func _has_alnum(token: String) -> bool:
	for i in token.length():
		var c := token.unicode_at(i)
		if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			return true
	return false


static func _walk(node: Node, camera: Camera3D, out: Dictionary) -> void:
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	if node is CanvasItem:
		var item := node as CanvasItem
		if not _shown(item):
			return
		var text := ""
		if item.has_method("drawn_words"):
			text = " ".join(item.drawn_words())
		elif item is Label:
			var label := item as Label
			text = label.text if label.visible_characters < 0 else label.text.left(label.visible_characters)
		elif item is Button:
			text = (item as Button).text
		elif item is RichTextLabel:
			text = (item as RichTextLabel).get_parsed_text()
		_add(out, "hud", node, text)
	elif node is Label3D and camera != null:
		var label3 := node as Label3D
		if label3.is_visible_in_tree() and _in_view(camera, label3.global_position):
			_add(out, "world", node, label3.text)
	for child in node.get_children():
		_walk(child, camera, out)


static func _add(out: Dictionary, kind: String, node: Node, text: String) -> void:
	var n := words_in(text)
	if n == 0:
		return
	out[kind] += n
	out["items"].append({"kind": kind, "node": String(node.name), "words": n, "text": text.replace("\n", " / ")})


static func _shown(item: CanvasItem) -> bool:
	if not item.is_visible_in_tree():
		return false
	var alpha := item.self_modulate.a
	var node: Node = item
	while node != null:
		if node is CanvasItem:
			alpha *= (node as CanvasItem).modulate.a
		elif node is CanvasLayer and not (node as CanvasLayer).visible:
			return false
		node = node.get_parent()
	return alpha > 0.05


static func _in_view(camera: Camera3D, at: Vector3) -> bool:
	if camera.is_position_behind(at) or camera.global_position.distance_to(at) > WORLD_REACH:
		return false
	var p := camera.unproject_position(at)
	return Rect2(Vector2.ZERO, camera.get_viewport().get_visible_rect().size).has_point(p)
