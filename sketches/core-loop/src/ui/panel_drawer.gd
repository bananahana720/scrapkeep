extends CanvasLayer

const Panels := preload("res://src/build/panels.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

# The grey panels' debug drawer (IL-01 card section 8; dev only): it opens and closes with
# the F1 tuning panel, grants any panel at the ball with one click, and sets the kill-drop
# rate live as a multiple of the drop row, so a feel test takes seconds.

const SCALES := [0.0, 0.5, 1.0, 2.0, 5.0, 14.0]

var game
var tuning_panel
var _root: PanelContainer
var _scale_label: Label


func setup(game_ref, tuning_panel_ref) -> void:
	game = game_ref
	tuning_panel = tuning_panel_ref
	name = "PanelDrawer"
	layer = 20
	_root = PanelContainer.new()
	_root.position = Vector2(380.0, 96.0)
	add_child(_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_root.add_child(box)
	var title := Label.new()
	title.text = "Panels (F1)"
	title.add_theme_font_size_override("font_size", UiTokens.BODY)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for id in Panels.ROWS:
		var grant := Button.new()
		grant.text = "+ " + String(Panels.ROWS[id]["name"])
		grant.focus_mode = Control.FOCUS_NONE
		grant.pressed.connect(func(): grant_panel(id))
		grid.add_child(grant)
	_scale_label = Label.new()
	box.add_child(_scale_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	for scale in SCALES:
		var pick := Button.new()
		pick.text = "x%s" % str(scale)
		pick.focus_mode = Control.FOCUS_NONE
		pick.pressed.connect(func(): set_drop_scale(scale))
		row.add_child(pick)
	visible = false
	_refresh()


func grant_panel(id: String) -> void:
	if game != null and game.build != null and game.flow.in_play():
		game.build.grant_panel(id)


func set_drop_scale(scale: float) -> void:
	if game != null and game.build != null:
		game.build.dropper.scale = scale
	_refresh()


func _refresh() -> void:
	var scale: float = game.build.dropper.scale if game != null and game.build != null else 1.0
	var world: int = game.build.dropper.world if game != null and game.build != null else 1
	var chance: float = Panels.DROP_BY_WORLD.get(world, Panels.DROP)["chance"]
	_scale_label.text = "Kill drop rate x%s (world %d ordinary kill %.0f%%)" % [str(scale), world, chance * 100.0 * scale]


func _process(_delta: float) -> void:
	if tuning_panel != null:
		visible = tuning_panel.visible
