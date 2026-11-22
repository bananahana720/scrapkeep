extends SceneTree
# W46-13 evidence (not shipped): chase-camera stills of the dam with Night Shift forced on the command line
# (--shift-variant=dam_night_shift[,crew_short]). --row=A|B|C lays a candidate night light row over the game's
# own (head only); --row=none keeps what the build draws. Writes <out>/<shot>.png and, for the telegraph,
# <shot>-plain.png with the shell's ring hidden (the same held frame), plus shots.json.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
var WorldLook = preload("res://src/presentation/world_look.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")

const SIZE := Vector2i(1600, 900)
const CANDIDATES := {
	"A": {"sun_rotation": Vector3(-40.0, 150.0, 0.0), "sun_color": Color("8fa8dc"), "sun_energy": 0.45,
		"ambient": Color("4e6394"), "energy": 0.26, "fog_tint": Color("1f3152"), "fog_color": Color("24344f"),
		"fill": 0.22, "fill_color": Color("5a72a8"),
		"grade": {"top": Color("0c1630"), "horizon": Color("24405e"), "recolor": 0.8, "highlight": 1.0, "glow": Color("152436"), "energy": 0.35}},
	"B": {"sun_rotation": Vector3(-40.0, 150.0, 0.0), "sun_color": Color("a9bde8"), "sun_energy": 0.6,
		"ambient": Color("6a7fb0"), "energy": 0.34, "fog_tint": Color("2e4468"), "fog_color": Color("34486a"),
		"fill": 0.3, "fill_color": Color("7088c0"),
		"grade": {"top": Color("142446"), "horizon": Color("3a6488"), "recolor": 0.75, "highlight": 1.0, "glow": Color("24405a"), "energy": 0.5}},
	"C": {"sun_rotation": Vector3(-14.0, -100.0, 0.0), "sun_color": Color("c2b8d8"), "sun_energy": 0.7,
		"ambient": Color("7186b4"), "energy": 0.36, "fog_tint": Color("3c5070"), "fog_color": Color("40506c"),
		"fill": 0.32, "fill_color": Color("7c8cc0"),
		"grade": {"top": Color("1c2c52"), "horizon": Color("c88a5a"), "recolor": 0.7, "highlight": 1.0, "glow": Color("6a3818"), "energy": 0.55}},
}
const SHOTS := {
	"spawn": {"at": Vector2(-150, -690), "to": Vector2(-60, -450)},
	"domes": {"at": Vector2(-70, -560), "to": Vector2(-60, -420)},
	"telegraph": {"at": Vector2(-70, -560), "to": Vector2(-60, -420), "lobber": 14.0},
	"telegraph_lit": {"at": Vector2(-44, -486), "to": Vector2(-30, -440), "lobber": 14.0},
	"telegraph_yard": {"at": Vector2(20, 466), "to": Vector2(36, 520), "lobber": 14.0},
	"cage": {"at": Vector2(-215, -470), "to": Vector2(-260, -430)},
	"mid": {"at": Vector2(-12, 120), "to": Vector2(0, 640)},
	"yard": {"at": Vector2(-40, 395), "to": Vector2(0, 600)},
	"cache": {"at": Vector2(14, 436), "to": Vector2(40, 462)},
	"cache_near": {"at": Vector2(22, 470), "to": Vector2(38, 456)},
	"dam_face": {"at": Vector2(-20, 560), "to": Vector2(0, 700)},
}

var out := ""
var row := "none"
var only: Array = []
var game
var report := {}
var dam_energy := -1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		elif arg.begins_with("--row="): row = arg.trim_prefix("--row=")
		elif arg.begins_with("--dam-energy="): dam_energy = float(arg.trim_prefix("--dam-energy="))
		elif arg.begins_with("--shots="): only = Array(arg.trim_prefix("--shots=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_main.call_deferred()


func _main() -> void:
	seed(4613)
	GraphicsPreset.apply("high")
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 900:
		await physics_frame
		if game.ctx.terrain.is_ready(1) and game.flow.in_play() and i > 240:
			break
	report["look_id"] = game.flow.stage_look_id() if game.flow.has_method("stage_look_id") else "(no seam)"
	if row != "none":
		var look: Dictionary = (WorldLook as Script).callv("stage_look", [1, 1, "park_dam", {}, "dam_night"])
		var cand: Dictionary = CANDIDATES[row]
		look.merge(cand, true)
		if cand.has("fog_color"):
			look["fog"] = {"density": look.fog.density, "color": cand.fog_color}
		GraphicsPreset.enter_world(game.ctx.terrain.geometry_root(1), game.ctx.terrain.environment, look)
	report["row"] = row
	if dam_energy >= 0.0:
		for l in root.find_children("NightDamLamp*", "SpotLight3D", true, false):
			l.light_energy = dam_energy
		report["dam_energy"] = dam_energy
	game.presentation.hide_ui()
	for i in 120:
		await process_frame
	var ground = game.ctx.spawner.ground
	for id in SHOTS:
		if not only.is_empty() and not (id in only):
			continue
		var shot: Dictionary = SHOTS[id]
		var at := Vector3(shot.at.x, 0.0, shot.at.y)
		at.y = Telegraph.ground_under(ground, at) + 0.8
		var to := Vector3(shot.to.x, 0.0, shot.to.y)
		var heading := Vector3(to.x - at.x, 0.0, to.z - at.z).normalized()
		await _place(at, heading)
		if shot.has("lobber"):
			game.ctx.calm = false
			var stand := at + heading * float(shot.lobber)
			stand.y = Telegraph.ground_under(ground, stand) + 1.0
			var lobber = game.ctx.spawner.spawn_enemy("lobber", stand)
			var shell = null
			for i in 1800:
				for node in get_nodes_in_group("enemy_shot"):
					if is_instance_valid(node) and is_instance_valid(node.get("ring")):
						shell = node
				if shell != null:
					break
				await physics_frame
			if shell == null:
				report[id] = "no shell"
				continue
			await _ticks(20)
			await _place(at, heading, 4)
			paused = true
			await _save(id)
			shell.ring.visible = false
			await _save(id + "-plain")
			paused = false
			if is_instance_valid(shell.ring): shell.ring.free()
			if is_instance_valid(shell): shell.free()
			if is_instance_valid(lobber): lobber.queue_free()
			game.ctx.calm = true
		else:
			await _save(id)
		report[id] = {"ball": at, "heading": heading}
	var f := FileAccess.open(out.path_join("shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	quit(0)


func _place(point: Vector3, heading: Vector3, settle := 60) -> void:
	var body = game.player.body()
	body.freeze = false
	game.player.reset_to(point)
	await _ticks(2)
	body.freeze = true
	game.camera.snap(heading)
	for i in settle:
		await process_frame


func _save(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
