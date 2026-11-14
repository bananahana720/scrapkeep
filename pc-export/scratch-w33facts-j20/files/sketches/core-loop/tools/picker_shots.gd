extends SceneTree
# Scratch only, never committed (job 20): open the camp dispatch box picker on the real camp walk with every
# kind met, focus each row in turn, and save a still per kind plus one TSV row: kind, note line count, note
# text height, page rect, viewport size, whether the page fits the viewport, the note text.
#   godot --path sketches/core-loop --resolution WxH --script res://tools/picker_shots.gd -- --out=<abs dir>

const Game := preload("res://src/game.gd")
const Sandbox := preload("res://src/world/camp_sandbox.gd")

var _out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await _frames(30)
	var hub = game.camp_hub
	hub.ensure_built()
	var sandbox: Node = hub.root.get_node("CampSandbox")
	sandbox.met_override = Sandbox.kinds()
	game.screens.toggle_camp()
	await _frames(60)
	sandbox.open_picker()
	await _frames(20)
	var page = sandbox._page
	var rows := PackedStringArray(["kind\tlines\tnote_h\tpage_rect\tviewport\tfits\tnote"])
	if page == null:
		rows.append("picker did not open")
	else:
		var vp := root.get_visible_rect().size
		for kind in page.kinds():
			page.row(kind).grab_focus()
			await _frames(4)
			var note: Label = page._note
			var r: Rect2 = page.get_global_rect()
			var fits := r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= vp.x and r.end.y <= vp.y
			rows.append("%s\t%d\t%.0f\t%s\t%s\t%s\t%s" % [kind, note.get_line_count(), note.size.y, str(r), str(vp), fits, note.text])
			root.get_texture().get_image().save_png(_out.path_join("%s.png" % kind))
	var f := FileAccess.open(_out.path_join("rows.tsv"), FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	quit(0)
