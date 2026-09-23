extends CanvasLayer

const SpeedTier := preload("res://src/speed_tier.gd")
const Materials := preload("res://src/materials.gd")
const RunState := preload("res://src/run_state.gd")
const ExitCharge := preload("res://src/exit_charge.gd")

var stage

var _hp: Label
var _economy: Label
var _buffs: Label
var _speed: Label
var _prompt: Label
var _alert: Label


func setup(stage_ref) -> void:
	stage = stage_ref

	var top := VBoxContainer.new()
	top.position = Vector2(18.0, 14.0)
	add_child(top)
	_hp = _label(30)
	top.add_child(_hp)
	_economy = _label(22)
	top.add_child(_economy)
	_buffs = _label(18)
	top.add_child(_buffs)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(18.0, -128.0)
	add_child(bottom)
	_alert = _label(26)
	bottom.add_child(_alert)
	_prompt = _label(22)
	bottom.add_child(_prompt)
	_speed = _label(22)
	bottom.add_child(_speed)
	var hint := _label(15)
	hint.text = "WASD move  ·  mouse look  ·  Space jump  ·  Shift boost  ·  Ctrl brake  ·  E interact\nTab physics mode  ·  R restart  ·  Esc free mouse (again to quit)"
	bottom.add_child(hint)


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _process(_delta: float) -> void:
	if stage == null or stage.run == null:
		return
	var run = stage.run
	_hp.text = "HP %d / %d" % [int(ceil(run.hp)), int(run.max_hp)]
	_hp.add_theme_color_override("font_color", Materials.AMBER.lerp(Materials.RUST, 1.0 - run.hp / run.max_hp))

	var minutes := int(run.stage_time) / 60
	var seconds := int(run.stage_time) % 60
	var charge_text := ""
	if stage.exit_terminal.charge.phase == ExitCharge.CHARGING:
		charge_text = "  ·  exit %d%%" % int(stage.exit_terminal.charge.fraction() * 100.0)
	elif stage.exit_terminal.charge.phase == ExitCharge.READY:
		charge_text = "  ·  exit ready"
	_economy.text = "scrap %d  ·  %d:%02d  ·  tier %d  ·  %d enemies%s" % [
		run.scrap, minutes, seconds, run.tier(), stage.enemy_count(), charge_text,
	]
	_buffs.text = run.buff_summary()

	var state = stage.player.state
	var speed: float = state.velocity.length()
	_speed.text = "%s  ·  %.1f m/s  ·  %s%s" % [
		stage.player.mode_name(), speed, SpeedTier.label(state.tier),
		"" if state.grounded else "  ·  airborne",
	]
	_speed.add_theme_color_override("font_color", SpeedTier.COLORS[state.tier])

	_prompt.text = stage.prompt_text()
	_alert.text = stage.alert_text()
	_alert.add_theme_color_override("font_color", Materials.AMBER)
