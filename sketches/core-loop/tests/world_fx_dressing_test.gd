extends SceneTree

# World dressing on the one table (BACKLOG.md FX-22): the Dig's and the Highdraft's own shader and
# multimesh effects read their quality and colours from WorldFxSpecs.DRESSING through WorldFxKit.
# This pins that the rows give the values the two files used before the fold (so the look and the
# quality behaviour do not move), that every row is read by some effect and every id an effect asks
# for is a row, and that the reduced-motion setting has one store.

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Comfort := preload("res://src/core/comfort.gd")
const Palette := preload("res://src/core/palette.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")

const READERS := ["res://src/presentation/dig_fx.gd", "res://src/presentation/highdraft_fx.gd"]

var _t := T.new("world_fx_dressing_test")


func _initialize() -> void:
	_same_as_before()
	_rows_and_readers()
	_one_store()
	quit(_t.verdict())


# The values dig_fx.gd and highdraft_fx.gd wrote in code on cand/w40 f4e04867.
func _same_as_before() -> void:
	_t.eq("Dig spent tint is slate", Kit.dressing_colour("dig_spent"), Palette.SLATE)
	_t.eq("thermal edge is verdigris", Kit.dressing_colour("hd_thermal_edge"), Palette.VERDIGRIS)
	_t.eq("net ring glow is sand", Kit.dressing_colour("hd_net_ring"), Palette.SAND)
	_t.near("thermal idle opacity", Kit.dressing_alpha("hd_thermal_idle"), 0.72)
	_t.near("thermal occupied opacity", Kit.dressing_alpha("hd_thermal_occupied"), 0.92)
	for id in ["dig_lamp_motion", "dig_cut_grit"]:
		_t.eq("%s stops on low" % id, Kit.dressing_share(id, true), 0.0)
		_t.eq("%s plays on high" % id, Kit.dressing_share(id, false), 1.0)
		_t.eq("%s keeps playing under reduced motion" % id, Kit.dressing_share(id, false, true), 1.0)
	var counts_match := true
	for n in 129:
		for id in ["hd_thermal_motes", "hd_thermal_streaks"]:
			counts_match = counts_match and Kit.dressing_count(id, n, true) == n / 3 and Kit.dressing_count(id, n, false) == n
	_t.check("thermal counts are a third on low, whole on high (was amount / 3)", counts_match)
	_t.near("cloud drift steps every 0.2 s on low", HighdraftFx.CLOUD_STEP / Kit.dressing_share("hd_cloud_drift", true), 0.2)
	_t.near("cloud drift steps every 0.1 s on high", HighdraftFx.CLOUD_STEP / Kit.dressing_share("hd_cloud_drift", false), 0.1)
	for id in ["hd_net_ring", "hd_net_dust"]:
		_t.eq("%s goes quiet under reduced motion" % id, Kit.dressing_share(id, false, true), 0.0)
		_t.eq("%s plays without it" % id, Kit.dressing_share(id, true, false), 1.0)
	var before := Preset.current
	for preset in Preset.PRESETS:
		Preset.current = preset
		for pair in [["hd_thermal_motes", "air_motes"], ["hd_thermal_streaks", "air_streaks"]]:
			_t.eq("%s shown on %s as the preset row says" % [pair[0], preset], Kit.dressing_shown(pair[0]),
				bool(Preset.PRESETS[preset].get(pair[1], true)))
	Preset.current = before


func _rows_and_readers() -> void:
	var source := ""
	for path in READERS:
		source += FileAccess.get_file_as_string(path)
	for id in Specs.DRESSING:
		_t.check("dressing row %s is read" % id, source.contains("\"%s\"" % id), id)
	var re := RegEx.new()
	re.compile("Kit\\.dressing_\\w+\\(\"(\\w+)\"")
	for m in re.search_all(source):
		_t.check("asked-for row %s exists" % m.get_string(1), Specs.DRESSING.has(m.get_string(1)), m.get_string(1))
	for id in Specs.DRESSING:
		var row: Dictionary = Specs.DRESSING[id]
		if row.has("colour"):
			_t.check("%s colour names a palette or kit colour" % id,
				Specs.KIT.has(row.colour) or (Palette as GDScript).get_script_constant_map().get(row.colour) is Color, row.colour)
	# No world dressing file reads the preset or the palette on its own any more.
	for path in READERS:
		var text := FileAccess.get_file_as_string(path)
		_t.check("%s reads quality only through the kit" % path, not text.contains(".current ==") and not text.contains("register_dressing_host"), path)
		_t.check("%s takes no palette colour of its own" % path, not text.contains("Palette."), path)


func _one_store() -> void:
	var was := Comfort.reduced_motion
	var holder := Node3D.new()
	root.add_child(holder)
	var events := GameEvents.new()
	for on in [true, false]:
		Comfort.reduced_motion = on
		var fx: Node3D = WorldFx.hook({"root": holder, "events": events})
		_t.check("WorldFx takes its setting from Comfort (%s)" % on, fx.reduced_motion == on)
		fx.free()
	Comfort.reduced_motion = was
	events.free()
	holder.free()
