extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Sequence := preload("res://src/ui/ending_sequence.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const DigFx := preload("res://src/presentation/dig_fx.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const WakingDress := preload("res://src/boss/waking_dress.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const RadioDial := preload("res://src/ui/radio_dial.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("visual_polish_regression_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _run() -> void:
	_check_vfx_and_contraptions()
	await _check_park_game()
	quit(_t.verdict())


func _check_vfx_and_contraptions() -> void:
	_t.eq("mod_announce_burst carries zero ink outline", float(Specs.SPECS["mod_announce_burst"].get("ink", 0.0)), 0.0)
	_t.eq("DunkGlow ink constant is disabled", PlayerFx.DUNK_INK, 0.0)
	var contraptions := Contraptions.new()
	var freed_dev := Node3D.new()
	var freed_haz := Node3D.new()
	contraptions.sluice_valves.append({"device": freed_dev, "hazard": freed_haz, "state": "ready", "wheel": null})
	root.add_child(contraptions)
	freed_dev.free()
	freed_haz.free()
	root.remove_child(contraptions)
	contraptions.free()
	_t.check("contraptions _exit_tree handles previously freed device and hazard without error", true)


func _check_park_game() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.ctx.profile.earn("brindle_mark_sable", 300.0)
	game.flow.press_start()
	await _frames(4)
	var cards: Array = game.screens.class_cards()
	var sable = cards[0]
	var preview_rect: Rect2 = sable.preview.get_global_rect()
	var alt_row: Control = sable._alt_row
	var alt_rect: Rect2 = alt_row.get_global_rect()
	_t.check("pilot select alt loadout pill never overlaps Sable 3D cutaway preview",
		alt_row.visible and not preview_rect.intersects(alt_rect),
		"preview=%s alt=%s" % [preview_rect, alt_rect])
	var discharge_cell: Dictionary = sable._cells[1]
	var discharge_label: Label = discharge_cell["label_node"]
	_t.check("Sable ability 2 label disables wrapping so arc discharge never truncates",
		discharge_label.text == "arc\ndischarge" and discharge_label.autowrap_mode == TextServer.AUTOWRAP_OFF
		and discharge_label.get_parent().custom_minimum_size.x >= 60.0,
		"text=%s wrap=%d w=%.1f" % [discharge_label.text, discharge_label.autowrap_mode, discharge_label.get_parent().custom_minimum_size.x])

	game.flow.choose_class(0)
	await _frames(4)
	var dunk_glow: MeshInstance3D = game.presentation.player_fx._dunk_glow
	_t.check("DunkGlow has no Ink child rim meshes and carries no_ink metadata",
		dunk_glow != null and dunk_glow.get_meta("no_ink", false)
		and dunk_glow.find_children("Ink", "MeshInstance3D", true, false).is_empty())

	game.flow.enter_stage(3, Vector3.ZERO, false)
	await _frames(3)
	var dig_root: Node3D = game.ctx.terrain.geometry_root(3)
	var dig_fx = dig_root.get_node_or_null("DigScenery/DigFx")
	if dig_fx != null and is_instance_valid(dig_fx._card_root):
		var dig_panel: Control = dig_fx._card_root.get_child(0)
		_t.check("Dig cold-open card sits cleanly above bottom HUD band", dig_panel.offset_bottom <= -170.0, str(dig_panel.offset_bottom))

	Harness.enter_world(game, 2)
	await _frames(3)
	var waking_plate = game.hud.boss_plate
	_t.eq("Waking boss plate title is The Waking", waking_plate.plate_name(), "The Waking")
	var waking_obj: Dictionary = game.hud.objective_reading()
	_t.eq("Waking boss sub-bar uses Waking objective instead of Brindle", waking_obj["words"], "Break the Waking's plates")
	var waking_mod = Harness.module(game, 2)
	if waking_mod != null and is_instance_valid(waking_mod._dress) and is_instance_valid(waking_mod._dress._intro_root):
		var waking_panel: Control = waking_mod._dress._intro_root.get_child(0)
		_t.check("Waking intro strip sits cleanly above bottom HUD bar", waking_panel.offset_bottom <= -170.0, str(waking_panel.offset_bottom))
	if dig_fx != null:
		_t.check("Dig cold-open card clears on boss entry", not is_instance_valid(dig_fx._card_layer))

	game.flow.enter_stage(6, Vector3.ZERO, false)
	await _frames(3)
	var crown_root: Node3D = game.ctx.terrain.geometry_root(6)
	var hd_fx = crown_root.get_node_or_null("HighdraftScenery/WindEffects")
	if hd_fx != null and is_instance_valid(hd_fx._card_layer):
		var hd_panel: Control = hd_fx._card_layer.get_node_or_null("ColdOpen")
		_t.check("Highdraft cold-open card sits cleanly above bottom HUD band", hd_panel != null and hd_panel.offset_bottom <= -170.0,
			str(hd_panel.offset_bottom if hd_panel != null else 0.0))

	Harness.enter_world(game, 3)
	await _frames(3)
	if hd_fx != null:
		_t.check("Highdraft CROWN WORKS card clears on Mind boss entry", not is_instance_valid(hd_fx._card_layer))
	var mind_plate = game.hud.boss_plate
	_t.eq("Mind boss plate title is The Mind", mind_plate.plate_name(), "The Mind")
	var mind_obj: Dictionary = game.hud.objective_reading()
	_t.eq("Mind boss sub-bar uses Mind objective instead of Brindle", mind_obj["words"], "Break the Mind's guard")
	var mind_mod = Harness.module(game, 3)
	if mind_mod != null and is_instance_valid(mind_mod._dress) and is_instance_valid(mind_mod._dress._call_in):
		var foreman_panel: Control = mind_mod._dress._call_in.get_child(0).get_child(0)
		_t.check("Foreman call-in card sits cleanly below KEEP radio box",
			foreman_panel.offset_top >= RadioDial.SWOLLEN.y + 16.0, str(foreman_panel.offset_top))

	game.flow.victory_lap = false
	game.flow._set_state(game.flow.BOSS)
	game.events.boss_defeated.emit()
	game.flow.physics_step(game.flow.VICTORY_SECONDS + 0.01)
	await _frames(2)
	var seq = game.screens.ending_sequence
	_t.check("park Stage 6 win starts EndingSequence on World 3 Highdraft with Mind copy",
		is_instance_valid(seq) and seq.world_index == 2 and seq._world_label.text.contains("The Highdraft"),
		"%s" % [seq._world_label.text if is_instance_valid(seq) else "none"])
	if is_instance_valid(seq):
		seq.set_process(false)
		seq.elapsed = 2.5
		seq.advance(0.0)
		_t.check("Stage 6 ending copy names the Mind", seq._copy.text.contains("Mind"), seq._copy.text)
		var vp_h := float(seq.viewport.size.y)
		var w3_px: Vector2 = seq.camera.unproject_position(seq.shell.global_position)
		_t.check("World 3 park_crown ending frames Sable cleanly inside letterbox opening",
			not seq.camera.is_position_behind(seq.shell.global_position)
			and w3_px.y > vp_h * 0.16 and w3_px.y < vp_h * 0.68,
			"px=%s vp_h=%.0f" % [w3_px, vp_h])
		seq.elapsed = Sequence.WORLD_SECONDS * 2.0 + 2.5
		seq.advance(0.0)
		var cam_pos: Vector3 = seq.camera.position
		var cam_ground: float = seq._park_height(seq._active_heights, cam_pos.x, cam_pos.z)
		var w1_px: Vector2 = seq.camera.unproject_position(seq.shell.global_position)
		_t.check("park_dam ending shot places ground, hero dam, and frames Sable cleanly inside letterbox",
			seq.world_index == 0 and seq.shell.position.z > 400.0 and cam_pos.y > cam_ground + 1.0
			and not seq.camera.is_position_behind(seq.shell.global_position)
			and w1_px.y > vp_h * 0.16 and w1_px.y < vp_h * 0.68
			and seq.worlds[0].find_children("*", "MeshInstance3D", true, false).size() >= 2,
			"shell=%s cam=%s ground=%.1f px=%s" % [seq.shell.position, cam_pos, cam_ground, w1_px])
		seq.skip()
	game.free()
