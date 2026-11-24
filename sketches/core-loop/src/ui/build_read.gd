extends PanelContainer

const Panels := preload("res://src/build/panels.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const PanelShell := preload("res://src/build/panel_shell.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# The pause screen's build read (IL-01 card section 7; the ladder page, "One glance build
# read"): the ball turns in a little window with every held panel bolted where it sits and
# labelled by stack, and a stat line per panel reads in plain words ("Fire rate +25%: 5
# louvres"). It draws the pilot's own shell (wear(): variant, paint and heft class as worn) and
# the same PanelShell under the same run seed as the ball in play, so what you read is what you
# roll. Built once, refreshed each time the pause menu opens; it turns while the tree is paused.

const VIEW := Vector2i(300, 240)
const TURN := 0.6
# The pod faces -Z; open on the pilot almost head-on before the turn shows the panels.
const OPEN_ANGLE := deg_to_rad(175.0)
const LABEL_LIFT := 1.75
# A panel tag's letter height in the view's world units.
const TAG_HEIGHT := 0.16
# Clearance from the screen's edge and from the pause column's left side (layout()).
const MARGIN := float(UiTokens.GAP_XL)
# The view shrinks no smaller than this share of VIEW when a long list needs the height.
const VIEW_MIN := 0.6

var shell
var lines: Array[String] = []
var _pivot: Node3D
var _labels: Node3D
var _list: VBoxContainer
# The stand-in sphere, built only while no shell is worn (_stand_in), so a run whose pilot wears one never holds it.
var _ball: MeshInstance3D
var _frame: SubViewportContainer
# The worn shell's record from HeroAssets.fit_worn_into, {} while the stand-in sphere shows.
var _worn := {}


func _init() -> void:
	name = "BuildRead"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW.x + UiTokens.GAP_XL, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTokens.GAP_XS)
	add_child(box)
	var frame := SubViewportContainer.new()
	frame.custom_minimum_size = Vector2(VIEW)
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	_frame = frame
	var view := SubViewport.new()
	view.size = VIEW
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	frame.add_child(view)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.6, 4.6)
	cam.look_at_from_position(cam.position, Vector3.ZERO)
	cam.fov = 41.5
	view.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0.0)
	view.add_child(sun)
	_pivot = Node3D.new()
	view.add_child(_pivot)
	shell = PanelShell.new()
	_pivot.add_child(shell)
	_labels = Node3D.new()
	_pivot.add_child(_labels)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	box.add_child(_list)


# Reads the run: the plates and their labels (as held), then the stat lines (as folded, after
# louvre overflow; `effective` empty means the held counts).
func refresh(run, overflow := 0, class_id := "", effective := {}) -> void:
	var held: Array = Array(run.panels) if run != null else []
	shell.show_panels(held, run.run_seed if run != null else 0)
	for child in _labels.get_children():
		child.queue_free()
	# Freed now, not queued, so layout() measures the new list in the same frame.
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	lines.clear()
	var counts := Panels.counts(held)
	var folded: Dictionary = effective if not effective.is_empty() else counts
	for id in Panels.ROWS:
		if int(folded.get(id, 0)) > 0:
			var line := Panels.stat_line(id, int(folded[id]))
			lines.append(line)
			_list.add_child(_line(line))
		if not counts.has(id):
			continue
		var at: Vector3 = shell.centroid(id)
		if at != Vector3.ZERO:
			var tag := Label3D.new()
			tag.text = "%s x%d" % [String(Panels.ROWS[id]["noun"]).to_upper(), int(counts[id])]
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.font_size = UiTokens.HEADING
			tag.pixel_size = TAG_HEIGHT / UiTokens.HEADING
			tag.outline_size = UiTokens.GAP_S
			tag.modulate = UiTokens.TEXT
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


# Fits the worn shell and its pilot. A missing painter, pilot or shell model shows the stand-in sphere instead.
func wear(painter, player) -> void:
	if painter != null and player != null:
		_worn = painter.fit_worn_into(_pivot, shell, player, _worn)
		_pivot.rotation.y = OPEN_ANGLE
	_stand_in(_worn.is_empty())


# Builds the stand-in sphere when it is wanted and frees it when the worn shell takes its place.
func _stand_in(wanted: bool) -> void:
	if not wanted:
		if _ball != null:
			_pivot.remove_child(_ball)
			_ball.queue_free()
			_ball = null
		return
	if _ball != null:
		return
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_ball.mesh = sphere
	_ball.material_override = Palette.solid(Palette.CHARCOAL.lerp(Palette.SLATE, 0.4), 0.0)
	_pivot.add_child(_ball)
	_pivot.move_child(_ball, 0)


# Seats the read in the screen's left gutter, centred on its height, clear of the pause
# column (its left edge at column_left). A list too tall for the screen shrinks the turning
# view (to VIEW_MIN of its height at the least) before anything leaves the screen.
func layout(screen: Vector2, column_left: float) -> void:
	_frame.custom_minimum_size = Vector2(VIEW)
	var room := screen.y - MARGIN * 2.0
	var over := get_combined_minimum_size().y - room
	if over > 0.0:
		_frame.custom_minimum_size.y = maxf(VIEW.y * VIEW_MIN, VIEW.y - over)
	var want := get_combined_minimum_size()
	size = want
	var x := clampf((column_left - want.x) * 0.5, MARGIN, maxf(MARGIN, column_left - MARGIN - want.x))
	position = Vector2(x, maxf(MARGIN, (screen.y - want.y) * 0.5))


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiTokens.BODY)
	label.add_theme_color_override("font_color", UiTokens.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = VIEW.x
	return label


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pivot.rotate_y(TURN * delta)
