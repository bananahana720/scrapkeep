extends SceneTree

# Writes assets/radio/cache_spots.json (radio_cache.gd, PR #66 schema): each Signal cache's [x, y, z]
# in its park's world space, at the spot design-v3/sound/RADIO.md names. SPOTS below holds each spot's
# x and z and where its height comes from: "drop" casts a ray down from that height onto the first
# surface (terrain, a row's collider or a landmark), "at" is an absolute height (a point on a rope).
# The heights come from the live colliders, so a rebake moves them: rerun after any park ground change.
#   godot --headless --path sketches/core-loop --script res://tools/radio_cache_spots.gd
# The crown and islands spots come from the crown pass; any other rows already in the file are kept.
# Brindle's Bolero (the penstock tower's cap, park_flume) waits for the tower's landmark collider: no
# surface stands at the cap yet, so it has no row and no cache until the landmark lands.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const OUT := "res://assets/radio/cache_spots.json"
const NOTE := "Signal cache positions by take id, [x, y, z] in the park's world space. The park-dressing work fills these in at the spots design-v3/sound/RADIO.md names; a take with no entry has no cache in the world yet."

# take id -> {stage, x, z, and drop (ray start height) or at (absolute height)}, with why it is there.
const SPOTS := {
	# The dam: the crest rail runs over the gate row; you grind the crest to reach it.
	"take-top-shelf-trio": {"stage": 1, "x": 0.0, "z": 655.0, "drop": 250.0},
	# The powerhouse roof at the dam's toe, up its roof ramp.
	"take-piston-flip": {"stage": 1, "x": 120.0, "z": 515.0, "drop": 250.0},
	# Legend: the spillway tunnel's floor just before the outlet bucket, past the falls.
	"take-dam-breaks": {"stage": 1, "x": -150.0, "z": 420.0, "drop": 120.0},
	# The flume: the middle of the mesa zip, the longest cable span; you take it on the line.
	"take-cable-reach-liquid": {"stage": 2, "x": -341.0, "z": -343.5, "at": 80.0},
	# The foot of the mesa zip's first pylon.
	"take-flume-gauge-house": {"stage": 2, "x": -389.5, "z": -437.5, "drop": 250.0},
	# The pit: the hoist house roof beside the headframe.
	"take-headframe-dubbed": {"stage": 3, "x": -75.0, "z": 215.0, "drop": 250.0},
	# Behind the sealed portal at the deep adit, the pit's one cracked wall.
	"take-pickaxe-flip": {"stage": 3, "x": 268.2, "z": 402.0, "drop": 250.0},
	# The pit's west rim at the top bench, looking west over the slickrock.
	"take-dust-devil-western": {"stage": 3, "x": -383.0, "z": 185.0, "drop": 250.0},
	# Legend: the pit floor under the headframe's tipple deck, the bottom of the shaft.
	"take-headframe-full-depth": {"stage": 3, "x": 0.0, "z": 268.0, "drop": -62.0},
	# The sinkhole: the caisson bowl's centre, its drain.
	"take-sinkhole-trip": {"stage": 4, "x": 0.0, "z": 350.0, "drop": -40.0},
	# Over the gallery ring, under the lip. The ring itself (y -107.74) lies under this bake's ground until
	# the gallery rebake (PR #29) opens it; rerun then, and this lands on the first open surface.
	"take-sinkhole-drain-dub": {"stage": 4, "x": 0.0, "z": 300.0, "drop": 250.0},
	# Legend: the pump gallery ledge on the bowl's east wall, reached by carving up the bowl.
	"take-cave-in-version": {"stage": 4, "x": 60.0, "z": 350.0, "drop": -40.0},
	# The islands and the crown, from the crown pass.
	"take-hanging-isle-liquid": {"stage": 5, "x": 24.0, "z": 520.0, "at": 70.0},
	"take-islands-kite-chime": {"stage": 5, "x": -455.0, "z": 490.0, "drop": 250.0},
	"take-highdraft-first-light": {"stage": 5, "x": -420.0, "z": 470.0, "at": 185.0},
	# The Fleet collector ledge at 64 m: the park spire has no bell frames.
	"take-crown-last-call": {"stage": 6, "x": 145.0, "z": 470.0, "drop": 120.0},
	# "at": the spire landmark has no collider yet; rerun after it lands, like Brindle's Bolero.
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
	var ball = game.player.active_body() if game.player.has_method("active_body") else null
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
