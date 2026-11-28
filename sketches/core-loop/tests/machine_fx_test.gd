# smoke: solo
extends SceneTree

# Machine effects (presentation/machine_fx.gd): what enemies and bosses throw off. Headless,
# particles do not simulate (fx_library_test), so this pins what fires, when and in what
# class: arrival, wind-up and release, hits and their words, deaths, the four specials'
# moments and sound ids, a boss phase, the fall's timing and its wink, and the governor.
const T := preload("res://tests/support/t.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Density := preload("res://src/presentation/density.gd")

var t := T.new("machine_fx_test")


class FakeSpecial extends Node3D:
	signal attack_phase(facts: Dictionary)
	signal special_tell(moment: String)
	signal died(at: Vector3, scrap_value: int)
	var kind := "foreman"
	var faction := "fleet"
	var half_height := 1.2
	func cable_ends() -> Array:
		return [global_position, global_position + Vector3(6, 3, 0)]


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _moments(fx, name: String) -> Array:
	return fx.moments.filter(func(m: Array): return m[1] == name)


func _run() -> void:
	var game = preload("res://src/game.gd").new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	var waited := 0
	while not game.flow.in_stage() and waited < 120:
		waited += 1
		await physics_frame
	var fx = game.find_children("MachineFx", "", true, false)
	t.check("presentation builds one MachineFx", fx.size() == 1)
	fx = fx[0]
	Density.live().force(0.0)

	t.check("machine pools sum to the pinned ceiling", FxLibrary.ceiling("machine") == FxLibrary.MACHINE_CEILING, str(FxLibrary.ceiling("machine")))
	t.check("vfx ceiling unchanged by machine specs", FxLibrary.ceiling() == FxLibrary.ceiling("vfx") and FxLibrary.ceiling() <= FxLibrary.CEILING)
	t.check("every moment names machine specs", MachineFx.MOMENTS.values().all(func(f: Dictionary):
		return f.values().all(func(m: Dictionary): return m.keys().all(func(id): return FxLibrary.spec(id).get("owner", "") == "machine"))))
	t.eq("a reactor is ancient", MachineFx.family_of("reactor"), "ancient")
	t.eq("a chaser is fleet", MachineFx.family_of_kind("chaser"), "fleet")

	# Arrival and death of an ordinary crew unit.
	var ball: Vector3 = game.player.ball_position()
	var chaser: Node3D = game.ctx.spawner.spawn_enemy("chaser", ball + Vector3(14, 1, 0))
	await _frames(2)
	t.check("a spawned chaser arrives in steam and brass", _moments(fx, "arrive").any(func(m: Array): return m[2] == "fleet"))

	# Wind-up: a follow that builds, then a release puff on the strike.
	chaser.attack_phase.emit({"phase": "windup", "progress": 0.0, "row": "", "at": chaser.global_position})
	t.check("a wind-up starts a steam jet on the body", fx._windups.has(chaser.get_instance_id()) and fx.alive_follows() >= 1)
	chaser.attack_phase.emit({"phase": "strike", "progress": 1.0, "row": "", "at": chaser.global_position})
	t.check("the strike lets go: jet stopped, release fired", not fx._windups.has(chaser.get_instance_id()) and _moments(fx, "release").size() == 1)

	# Hits: a light one sparks, a heavy one stamps a word; a second hit inside the gap is dropped.
	var words_before: int = fx.spawned.get("word", 0)
	game.ctx.events.enemy_struck.emit(chaser, "ram", 50.0)
	var last_word: Array = _moments(fx, "word").back() if not _moments(fx, "word").is_empty() else [0, "", ""]
	t.check("a heavy hit stamps KLANG", fx.spawned.get("word", 0) == words_before + 1 and last_word[2] == "KLANG",
		str(_moments(fx, "word")))
	var sparks: int = fx.spawned.get("brass_spark", 0)
	game.ctx.events.enemy_struck.emit(chaser, "ram", 50.0)
	t.eq("a second hit on one body within the gap fires nothing", fx.spawned.get("brass_spark", 0), sparks)

	game.ctx.spawner.strike(chaser, "ram", 99999.0)
	await _frames(2)
	t.check("a dead crew unit sighs steam", _moments(fx, "death").size() >= 1)

	# A special: spawn, presence, a tell with its word and sound, then the break.
	var foreman := FakeSpecial.new()
	game.ctx.root.add_child(foreman)
	foreman.global_position = ball + Vector3(-12, 0, 6)
	game.ctx.events.enemy_spawned.emit(foreman, "lobber")
	t.check("the Foreman's spawn moment fires", _moments(fx, "foreman_spawn").size() == 1)
	t.check("its presence follows the body", fx._follows.any(func(f: Dictionary): return f["node"] == foreman))
	t.eq("its tell plays foreman_tell", fx.special_moment("foreman", "tell", foreman), "foreman_tell")
	t.eq("audio and picture read one row", SpecialCues.sound("foreman", "tell"), "foreman_tell")
	t.check("the tell is worded", _moments(fx, "word").back()[2] == "HOOONK")
	foreman.special_tell.emit("tell")
	t.eq("the body's own tell signal fires the moment", _moments(fx, "foreman_tell").size(), 2)
	foreman.died.emit(foreman.global_position, 6)
	t.check("the Foreman clocks out: SHIFT OVER", _moments(fx, "foreman_break").size() == 1 and _moments(fx, "word").back()[2] == "SHIFT OVER")
	foreman.queue_free()
	await _frames(1)
	t.check("its presence stops with it", not fx._follows.any(func(f: Dictionary): return f["node"] == foreman))

	for name in MachineFx.SPECIALS:
		var row: Dictionary = MachineFx.SPECIALS[name]
		t.check("%s has a spawn, a tell, a break and their sounds" % name, row.has("spawn") and row.has("tell")
			and (row.has("break") or (row.has("break_split") and row.has("break_clean")))
			and ["tell", "presence", "spawn"].all(func(m: String): return SpecialCues.sound(name, m) != ""))

	var splitter := FakeSpecial.new()
	splitter.kind = "splitter"
	game.ctx.root.add_child(splitter)
	game.ctx.events.enemy_spawned.emit(splitter, "splitter")
	splitter.set_meta("split", true)
	splitter.died.emit(splitter.global_position, 6)
	t.check("a rammed Splitter breaks the wrong way", _moments(fx, "splitter_break_split").size() == 1)
	splitter.queue_free()
	var linker := FakeSpecial.new()
	linker.kind = "linker"
	game.ctx.root.add_child(linker)
	fx.special_moment("linker", "tell", linker)
	t.check("the Linker's tell runs an arc down its cable", fx._cables.size() == 1)
	linker.queue_free()

	# The governor thins body effects but never a tell.
	Density.live().force(1.0)
	t.eq("at full density a crew hit's sparks are thinned", fx._thin(10, "P5"), int(round(10 * Density.live().band()["alpha"] / 0.9)))
	t.eq("a tell is never thinned", fx._thin(10, "P1"), 10)
	t.check("candy words are skipped at full density", not fx.word("KLANG", ball, Color.WHITE))
	t.check("forced words still stamp", fx.word("SHIFT OVER", ball, Color.WHITE, true))
	Density.live().force(0.0)

	# A word fits the view: a panel pickup's three-word pop is stamped at the ball, beside the
	# camera, and at its size in metres it was wider than the screen. Its room is a share of the
	# view's height, so its letters stand as tall on a wide screen. A short word far off is left alone.
	var cam := root.get_camera_3d()
	var view_h: float = root.get_visible_rect().size.y
	var near: Vector3 = cam.global_position - cam.global_basis.z * 8.0
	t.check("the pop stamps", fx.word("COLLAR +6% HARPOON RECOVERY", near, Color.WHITE, true, 1.2, 1.1))
	t.check("a far word stamps", fx.word("TONK", cam.global_position - cam.global_basis.z * 40.0, Color.WHITE, true))
	# Past the slam (the first WORD_SLAM seconds draw a word up to 1.6 times its held size), by
	# the words' own clocks: a frame count is no time on a fast machine.
	var newest: Dictionary = fx._words[posmod(fx._word_next - 1, fx._words.size())]
	var settle := 0
	while float(newest["t"]) <= MachineFx.WORD_SLAM and settle < 600:
		settle += 1
		await process_frame
	var widths := {}
	for slot in fx._words:
		var label: Label3D = slot["node"]
		if not label.visible:
			continue
		var at: Vector3 = slot["at"]
		var px_per_m: float = cam.unproject_position(at + cam.global_basis.x).distance_to(cam.unproject_position(at))
		widths[label.text] = [float(slot["width_px"]) * label.pixel_size * label.scale.x * px_per_m / view_h, label.scale.x]
	var pop: Array = widths.get("COLLAR +6% HARPOON RECOVERY", [9.0, 0.0])
	var far: Array = widths.get("TONK", [9.0, 0.0])
	t.check("a long pop beside the camera is held to the view", pop[0] <= MachineFx.WORD_FIT + 0.01 and pop[0] > MachineFx.WORD_FIT - 0.05 and pop[1] < 1.1, str(pop))
	t.check("a short word far off keeps its size", is_equal_approx(far[1], 1.0) and far[0] < MachineFx.WORD_FIT, str(far))

	# A boss phase, then the fall: blasts first, the wink one beat after the last.
	fx.boss_phase("waking", ball + Vector3(0, 0, 20))
	t.check("a boss phase fires its word", _moments(fx, "word").back()[2] == "KRAKK")
	# Brindle's turn is read from his plates and the glance, so no word stands over him (w37 film PF-26).
	var brindle_words := _moments(fx, "word").size()
	fx.boss_phase("brindle", ball + Vector3(0, 0, 20))
	t.eq("Brindle's phase fires its burst and no word", _moments(fx, "word").size(), brindle_words)
	var start: float = fx._clock
	# Brindle's rout says its word through the flourish row, so his fall queues no word of its own.
	fx.boss_fall("brindle", ball + Vector3(0, 0, 30))
	t.check("Brindle's fall queues its blasts and ring and no word", fx._queue.size() == MachineFx.FALL_BLASTS + 1 and not fx._queue.any(func(item): return item.has("word")))
	fx._queue.clear()
	fx.boss_fall("waking", ball + Vector3(0, 0, 30))
	t.check("the fall queues its blasts, ring and wink", fx._queue.size() == MachineFx.FALL_BLASTS + 2)
	var wink_at: float = fx._queue.back()["at"]
	t.check("the wink waits one beat after the last blast", is_equal_approx(wink_at - start, MachineFx.FALL_GAP * MachineFx.FALL_BLASTS + MachineFx.WINK_DELAY))
	var waited_frames := 0
	while not fx._queue.is_empty() and waited_frames < 600:
		waited_frames += 1
		await process_frame
	t.check("the fall ends on its wink word", _moments(fx, "word").back()[2] == "BACK TO SLEEP")

	# Pools: twenty wind-ups at once never error; the extras just skip.
	var bodies: Array = []
	for i in 20:
		var body := FakeSpecial.new()
		body.kind = "chaser"
		game.ctx.root.add_child(body)
		bodies.append(body)
		fx.follow("steam_jet", body, 10, 1.0)
	t.check("follows never exceed the pool", fx.alive_follows() <= int(FxLibrary.spec("steam_jet")["pool"]) + 6)
	for body in bodies:
		body.queue_free()
	await _frames(2)
	fx.clear()
	t.eq("clear stops every follow", fx.alive_follows(), 0)

	game.queue_free()
	await _frames(2)
	quit(t.verdict())
