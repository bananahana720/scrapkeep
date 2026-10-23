extends PanelContainer

const Panels := preload("res://src/build/panels.gd")
const PanelShell := preload("res://src/build/panel_shell.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# The pause screen's build read (IL-01 card section 7; the ladder page, "One glance build
# read"): the ball turns in a little window with every held panel bolted where it sits and
# labelled by stack, and a stat line per panel reads in plain words ("Fire rate +25%: 5
# louvres"). It draws the same PanelShell under the same run seed as the ball in play, so
# what you read is what you roll. Built once, refreshed each time the pause menu opens; it
# turns while the tree is paused.

const VIEW := Vector2i(300, 240)
const TURN := 0.6
const LABEL_LIFT := 1.75

var shell
var lines: Array[String] = []
var _pivot: Node3D
var _labels: Node3D
var _list: VBoxContainer
var _ball: MeshInstance3D


func _init() -> void:
	name = "BuildRead"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW.x + 24, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "BUILD"
	title.add_theme_font_override("font", UiFonts.bold())
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Palette.AMBER)
	box.add_child(title)
	var frame := SubViewportContainer.new()
	frame.custom_minimum_size = Vector2(VIEW)
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	var view := SubViewport.new()
	view.size = VIEW
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	frame.add_child(view)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.6, 4.6)
	cam.look_at_from_position(cam.position, Vector3.ZERO)
	cam.fov = 40.0
	view.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0.0)
	view.add_child(sun)
	_pivot = Node3D.new()
	view.add_child(_pivot)
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_ball.mesh = sphere
	_ball.material_override = Palette.solid(Palette.CHARCOAL.lerp(Palette.SLATE, 0.4), 0.0)
	_pivot.add_child(_ball)
	shell = PanelShell.new()
	_pivot.add_child(shell)
	_labels = Node3D.new()
	_pivot.add_child(_labels)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)


# Reads the run: the plates and their labels, then the stat lines.
func refresh(run, overflow := 0, class_id := "") -> void:
	var held: Array = Array(run.panels) if run != null else []
	shell.show_panels(held, run.run_seed if run != null else 0)
	for child in _labels.get_children():
		child.queue_free()
	for child in _list.get_children():
		child.queue_free()
	lines.clear()
	var counts := Panels.counts(held)
	for id in Panels.ROWS:
		if not counts.has(id):
			continue
		var line := Panels.stat_line(id, int(counts[id]))
		lines.append(line)
		_list.add_child(_line(line))
		var at: Vector3 = shell.centroid(id)
		if at != Vector3.ZERO:
			var tag := Label3D.new()
			tag.text = "%s x%d" % [String(Panels.ROWS[id]["noun"]).to_upper(), int(counts[id])]
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.font_size = 40
			tag.pixel_size = 0.004
			tag.outline_size = 10
			tag.modulate = Palette.SAND
			tag.position = at * LABEL_LIFT
			_labels.add_child(tag)
	if overflow > 0:
		var to := Panels.overflow_of(class_id)
		var line := "Past the fire-rate cap, %d louvre%s became %s" % [overflow, "" if overflow == 1 else "s", String(Panels.ROWS[to]["words"]).to_lower()]
		lines.append(line)
		_list.add_child(_line(line))
	if held.is_empty():
		var line := "No panels yet. Machines drop them."
		lines.append(line)
		_list.add_child(_line(line))


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Palette.SAND)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = VIEW.x
	return label


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pivot.rotate_y(TURN * delta)
