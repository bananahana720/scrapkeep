extends SceneTree
# SCRATCH ONLY (job AU): does the Stocktake yard stand on a fresh park run, and where is the ball?
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await process_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = Intent.Scripted.new()
	for i in 300:
		await physics_frame
	var acts = game.world.activities
	print("YARD option=", game.tuning.option("stocktake"), " calm=", game.ctx.calm, " stage=", game.ctx.run.stage)
	for s in acts.sites:
		var id := String(s.id) if "id" in s else String(s.get("id", "?")) if s is Dictionary else str(s)
		if id.contains("stocktake"):
			print("YARD site ", id, " at ", s.at if "at" in s else s.get("at"))
	print("YARD sites=", acts.sites.size(), " ball=", game.player.global_position)
	quit(0)
