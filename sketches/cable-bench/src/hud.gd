extends CanvasLayer

const SpeedTier := preload("res://src/speed_tier.gd")
const Palette := preload("res://src/palette.gd")
const RunState := preload("res://src/run_state.gd")
const Rules := preload("res://src/rules.gd")

var player
var tuning
var run
var loadout

var _tier: Label
var _clock: Label
var _vitals: Label
var _buffs: Label
var _speed: Label
var _prompt: Label
var _charge: Label

var _flash := 0.0


func setup(player_ref, tuning_ref, run_ref, loadout_ref) -> void:
	player = player_ref
	tuning = tuning_ref
	run = run_ref
	loadout = loadout_ref

	var top := VBoxContainer.new()
	top.position = Vector2(20.0, 14.0)
	add_child(top)
	# The tier is the pressure clock, so it is the biggest thing on screen.
	_tier = _label(40, Palette.AMBER)
	top.add_child(_tier)
	_clock = _label(20, Palette.SAND)
	top.add_child(_clock)
	_vitals = _label(26, Palette.SAND)
	top.add_child(_vitals)
	_charge = _label(24, Palette.ARC)
	top.add_child(_charge)

	var right := VBoxContainer.new()
	right.position = Vector2(20.0, 140.0)
	add_child(right)
	_buffs = _label(18, Palette.ARC)
	right.add_child(_buffs)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(20.0, -96.0)
	add_child(bottom)
	_speed = _label(24, Palette.SAND)
	bottom.add_child(_speed)
	_prompt = _label(22, Palette.AMBER)
	bottom.add_child(_prompt)
	var hint := _label(15, Palette.SAND)
	hint.text = "WASD move · mouse look · Space jump/double jump · Shift boost · Ctrl brake · E open cache / start forge · Tab physics mode · R restart · Esc free mouse"
	bottom.add_child(hint)


func say(text: String) -> void:
	_prompt.text = text
	_flash = 2.5


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 7)
	return label


func _process(delta: float) -> void:
	if player == null:
		return
	var tier: int = run.tier()
	_tier.text = "DIFFICULTY  %d" % tier
	var next: float = Rules.TIER_SECONDS * (1.0 - run.tier_progress())
	_clock.text = "stage %02d:%05.2f   ·   tier %d in %ds   ·   cache cost %d scrap" % [
		int(run.stage_time / 60.0), fmod(run.stage_time, 60.0), tier + 1, int(next), Rules.cache_cost(tier)]
	_vitals.text = "HP %d/%d   ·   scrap %d" % [int(ceil(run.hp)), int(run.hp_max), run.scrap]
	_vitals.add_theme_color_override("font_color",
		Palette.SAND if run.hp > run.hp_max * 0.35 else Palette.RUST.lerp(Color.WHITE, 0.3))

	if run.phase == RunState.Phase.CHARGING:
		_charge.text = "FORGE CHARGE %d%%   ·   stay inside the ring" % int(run.charge_fraction() * 100.0)
	elif run.phase == RunState.Phase.READY:
		_charge.text = "FORGE READY   ·   roll into the rig"
	else:
		_charge.text = ""

	_buffs.text = "buffs: none" if loadout.total_stacks() == 0 else "buffs:\n  " + "\n  ".join(loadout.held_lines())

	var speed: float = player.state.velocity.length()
	var tier_index: int = player.state.tier
	_speed.text = "%.1f m/s  ·  %s  ·  %s" % [speed, SpeedTier.label(tier_index), player.mode_name()]
	_speed.add_theme_color_override("font_color", SpeedTier.COLORS[tier_index])

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		if _flash <= 0.0:
			_prompt.text = ""
