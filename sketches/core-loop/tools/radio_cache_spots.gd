extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const OUT := "res://assets/radio/cache_spots.json"
const NOTE := "Signal cache positions by take id, [x, y, z] in the park's world space. The park-dressing work fills these in at the spots design-v3/sound/RADIO.md names; a take with no entry has no cache in the world yet."

const SPOTS := {
	"take-top-shelf-trio": {"stage": 1, "x": 0.0, "z": 655.0, "drop": 250.0},
	"take-piston-flip": {"stage": 1, "x": 120.0, "z": 515.0, "drop": 250.0},
	"take-dam-breaks": {"stage": 1, "x": -150.0, "z": 420.0, "drop": 120.0},
	"take-cable-reach-liquid": {"stage": 2, "x": -341.0, "z": -343.5, "at": 80.0},
	"take-flume-gauge-house": {"stage": 2, "x": -389.5, "z": -437.5, "drop": 250.0},
	"take-headframe-dubbed": {"stage": 3, "x": -75.0, "z": 215.0, "drop": 250.0},
	"take-pickaxe-flip": {"stage": 3, "x": 268.2, "z": 402.0, "drop": 250.0},
	"take-dust-devil-western": {"stage": 3, "x": -383.0, "z": 185.0, "drop": 250.0},
	"take-headframe-full-depth": {"stage": 3, "x": 0.0, "z": 268.0, "drop": -62.0},
	"take-sinkhole-trip": {"stage": 4, "x": 0.0, "z": 350.0, "drop": -40.0},
	"take-sinkhole-drain-dub": {"stage": 4, "x": 0.0, "z": 296.5, "drop": 250.0},
	"take-cave-in-version": {"stage": 4, "x": 73.0, "z": 350.0, "drop": -40.0},
	"take-hanging-isle-liquid": {"stage": 5, "x": 24.0, "z": 520.0, "at": 70.0},
	"take-islands-kite-chime": {"stage": 5, "x": -455.0, "z": 490.0, "drop": 250.0},
	"take-highdraft-first-light": {"stage": 5, "x": -420.0, "z": 470.0, "at": 185.0},
	"take-crown-last-call": {"stage": 6, "x": 145.0, "z": 470.0, "drop": 120.0},
	"take-crown-spire-fusion": {"stage": 6, "x": -17.0, "z": 470.0, "at": 18.0},
	"take-crown-footwork": {"stage": 6, "x": 280.0, "z": 175.0, "drop": 250.0},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	var doc := {"note": NOTE, "spots": {}}
	if FileAccess.file_exists(OUT):
		var old = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if old is Dictionary and old.get("spots") is Dictionary:
			doc["spots"] = old["spots"]
	var exclude := []
	var ball = game.player.body() if game.player.has_method("body") else null
	if ball is CollisionObject3D:
		exclude.append(ball.get_rid())
	var failed := 0
	for stage in range(1, 7):
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		var waited := 0
		while not game.ctx.terrain.rows_ready(stage) and waited < 1200:
			await physics_frame
			waited += 1
		for i in 4:
			await physics_frame
		var space := game.get_world_3d().direct_space_state
		for id in SPOTS:
			var spot: Dictionary = SPOTS[id]
			if int(spot["stage"]) != stage:
				continue
			var x := float(spot["x"])
			var z := float(spot["z"])
			if spot.has("at"):
				doc["spots"][id] = [x, float(spot["at"]), z]
				print("radio_cache_spots: %s %s at %.1f (rope)" % [id, game.ctx.terrain.map_for(stage).park["map"], float(spot["at"])])
				continue
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, float(spot["drop"]), z), Vector3(x, -400.0, z))
			query.exclude = exclude
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				failed += 1
				print("radio_cache_spots: %s no surface under the spot" % id)
				continue
			var at: Vector3 = hit["position"]
			doc["spots"][id] = [snappedf(at.x, 0.1), snappedf(at.y, 0.01), snappedf(at.z, 0.1)]
			print("radio_cache_spots: %s %s on %s at %.2f" % [id, game.ctx.terrain.map_for(stage).park["map"], hit["collider"].get_parent().name if hit["collider"] != null else "?", at.y])
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(doc, " ", true) + "\n")
	file.close()
	game.queue_free()
	await physics_frame
	quit(1 if failed > 0 else 0)
