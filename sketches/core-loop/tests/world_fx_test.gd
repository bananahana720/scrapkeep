extends SceneTree

# World and event effects (WORLD-FX.md): the table resolves, every ambient effect obeys the
# readability rule, the budgets hold, and the runtime's hooks, anchors and cables behave. Headless
# simulates no particles, so this pins configuration and the synchronous emitting flags.
const T := preload("res://tests/support/t.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const Anchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const Cable := preload("res://src/presentation/world_fx/world_fx_cable.gd")
const Word := preload("res://src/presentation/world_fx/world_fx_word.gd")

var t := T.new("world_fx_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_table()
	_readability()
	_budgets()
	await _runtime()
	await _wiring()
	_anchors()
	_cable()
	quit(t.verdict())


func _table() -> void:
	var used := {}
	for set_id in Specs.SETS:
		for id in Specs.SETS[set_id]:
			t.check("set %s names a spec: %s" % [set_id, id], Specs.SPECS.has(id))
			used[id] = true
	for kind in Specs.OVERLAYS:
		for id in Specs.OVERLAYS[kind]:
			t.check("overlay %s names a spec: %s" % [kind, id], Specs.SPECS.has(id))
			used[id] = true
	for hook in Specs.HOOKS:
		for id in Specs.HOOKS[hook]["effects"]:
			t.check("hook %s names a burst spec: %s" % [hook, id], Specs.SPECS.has(id) and Specs.SPECS[id]["attach"] == "burst")
			used[id] = true
	for w in Specs.WORLD_SETS:
		t.check("world %d has an ambient set" % w, Specs.SETS.has(Specs.WORLD_SETS[w]))
	for id in Specs.SPECS:
		var s: Dictionary = Specs.SPECS[id]
		t.check("%s is played by a set, overlay or hook" % id, used.has(id))
		t.check("%s has a known shape and attach" % id, Kit.SHAPES.has(s["shape"])
			and ["camera", "ball", "wake", "anchor", "burst"].has(s["attach"]))
		for c in Specs.colour_names(id):
			t.check("%s colour %s resolves" % [id, c], Specs.KIT.has(c) or (load("res://src/core/palette.gd") as Script).get_script_constant_map().has(c))
		var e := Kit.build(id)
		root.add_child(e)
		t.check("%s built from its spec" % id, e.amount == int(s["max"]) and is_equal_approx(e.lifetime, s["life"])
			and e.use_fixed_seed and e.seed == Kit.SEED and not e.emitting)
		t.check("%s one-shot exactly when it is a burst" % id, e.one_shot == (s["attach"] == "burst"))
		t.check("%s casts no shadow and owns no light" % id, e.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and e.find_children("*", "Light3D", true, false).is_empty())
		e.free()


# Air never reads as play: every following effect joins the clear zone, stays translucent and wears
# no colour that means a threat, a live target or the ancients.
func _readability() -> void:
	for id in Specs.SPECS:
		var s: Dictionary = Specs.SPECS[id]
		if s["attach"] == "camera" or s["attach"] == "ball":
			t.check("%s follows the view, so it is ambient" % id, s.get("ambient", false))
		if not s.get("ambient", false):
			continue
		var reserved := Specs.colour_names(id).filter(func(c): return Specs.RESERVED.has(c))
		t.check("%s wears no reserved colour" % id, reserved.is_empty(), str(reserved))
		t.check("%s stays translucent unless it is a speck" % id, float(s.get("alpha", 1.0)) <= 0.5 or float(s["size"][1]) <= 0.5,
			"alpha %s size %s" % [s.get("alpha", 1.0), s["size"]])
		t.check("%s carries no ink (the comic sits on top of the world, not in it)" % id, float(s.get("ink", 0.0)) == 0.0)
		var e := Kit.build(id)
		var mat := e.draw_pass_1.material as ShaderMaterial
		t.check("%s material fades in the clear zone" % id, mat.get_shader_parameter("clear_zone") == true
			and is_equal_approx(mat.get_shader_parameter("clear_radius"), Kit.CLEAR_RADIUS))
		e.free()
	Kit.set_clear(Vector3(4, 5, 6))
	t.check("set_clear moves every ambient material's centre", Kit.ambient_materials().all(
		func(m): return m.get_shader_parameter("clear_center") == Vector3(4, 5, 6)))
	t.check("ink only on ceremony and comic effects", Specs.SPECS.keys().filter(
		func(id): return Specs.SPECS[id].get("ink", 0.0) > 0.0 and not ["summary", "title", "mod_announce", "secret_found"].any(
			func(p): return id.begins_with(p))).is_empty())
	t.check("a word is gone inside a second", Word.LIFE <= 1.0)


func _ambient_cost(world: int, low: bool, reduced := false) -> int:
	var total := 0
	for id in Specs.SETS[Specs.WORLD_SETS[world]]:
		total += Kit.cost(id, low, reduced)
	var worst := 0
	for kind in Specs.OVERLAYS:
		var c := 0
		for id in Specs.OVERLAYS[kind]:
			c += Kit.cost(id, low, reduced)
		worst = maxi(worst, c)
	return total + worst


func _budgets() -> void:
	for w in Specs.WORLD_SETS:
		var high := _ambient_cost(w, false)
		var low := _ambient_cost(w, true)
		t.check("world %d air plus its worst overlay within %d" % [w, Specs.AMBIENT_CEILING], high <= Specs.AMBIENT_CEILING, str(high))
		t.check("world %d low preset at most half its high air" % w, low * 2 <= high, "%d of %d" % [low, high])
		t.check("world %d reduced motion lighter than full" % w, _ambient_cost(w, false, true) < high)
	var anchor_sets: Array = []
	for set_id in Specs.SETS:
		var c := 0
		var anchored := true
		for id in Specs.SETS[set_id]:
			anchored = anchored and Specs.SPECS[id]["attach"] == "anchor"
			c += Kit.cost(id)
		if anchored:
			anchor_sets.append(c)
	anchor_sets.sort()
	anchor_sets.reverse()
	var worst := 0
	for i in mini(Specs.ANCHOR_SLOTS, anchor_sets.size()):
		worst += anchor_sets[i]
	t.check("the %d costliest anchors together within %d" % [Specs.ANCHOR_SLOTS, Specs.ANCHOR_CEILING], worst <= Specs.ANCHOR_CEILING, str(worst))
	for id in Specs.SPECS:
		if not Specs.SPECS[id].get("motion", true):
			t.check("%s drops under reduced motion" % id, Kit.cost(id, false, true) == 0)


func _runtime() -> void:
	WorldFx.fire("relay_full", Vector3.ZERO)
	t.check("fire with nothing installed is a no-op", WorldFx.current == null)
	var stage := Node3D.new()
	root.add_child(stage)
	var fx := WorldFx.install(stage, 3)
	t.check("install makes it current", WorldFx.current == fx)
	t.eq("the Highdraft's air installs", fx.ambient.map(func(p): return p.get_meta("world_fx")), Specs.SETS["highdraft"])
	t.check("ambient emits at the high preset", fx.ambient.all(func(p): return p.emitting and is_equal_approx(p.amount_ratio, 1.0)))
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.global_position = Vector3(10, 20, 30)
	cam.rotation.y = PI * 0.5
	var ball := Node3D.new()
	stage.add_child(ball)
	ball.global_position = Vector3(10, 2, 20)
	fx.bind(cam, ball)
	var wind: GPUParticles3D = fx.ambient[0]
	var offset: Vector3 = Specs.SPECS["hd_wind_streaks"]["offset"]
	t.check("camera air sits at the lens plus its yawed offset, basis untouched",
		wind.global_position.is_equal_approx(cam.global_position + Basis(Vector3.UP, PI * 0.5) * offset)
		and wind.global_transform.basis.is_equal_approx(Basis.IDENTITY))
	fx.set_overlay("storm_build")
	t.eq("a weather sky adds its overlay", fx.overlay.map(func(p): return p.get_meta("world_fx")), Specs.OVERLAYS["storm_build"])
	fx.set_overlay("hidden")
	t.check("a modifier overlay replaces the last", fx.overlay.size() == 1 and fx.overlay[0].get_meta("world_fx") == "mod_hidden_haze"
		and fx.overlay[0].global_position.is_equal_approx(ball.global_position + Specs.SPECS["mod_hidden_haze"]["offset"]))
	fx.set_quality(true, false)
	t.check("low preset trims the air", fx.ambient.all(func(p): return p.amount_ratio <= 0.5))
	t.check("low preset drops the specks", not fx.ambient[2].emitting)
	fx.set_quality(false, false)
	WorldFx.fire("relay_full", Vector3(1, 0, 1))
	var burst: Array = fx._bursts["relay_full_burst"]
	t.check("a hook fires its bursts where it is told", burst[0].emitting and burst[0].global_position.is_equal_approx(Vector3(1, 0, 1)))
	t.check("a hook stamps its word", fx.find_children("Word_KA-CHUNK", "", false, false).size() == 1)
	WorldFx.fire("relay_full", Vector3(2, 0, 2))
	t.check("bursts recycle round-robin", burst[1].emitting and burst[1].global_position.is_equal_approx(Vector3(2, 0, 2)))
	fx.set_quality(false, true)
	WorldFx.fire("secret_found", Vector3.ZERO)
	t.check("reduced motion stamps no word", fx.find_children("Word_OOH", "", false, false).is_empty())
	fx.play("no_such_hook", Vector3.ZERO)
	t.check("an unknown hook warns and fires nothing", not fx._bursts.has("no_such_hook"))
	stage.queue_free()
	await process_frame
	t.check("current clears when the stage goes", WorldFx.current == null)


class FakeEvents extends Node:
	signal stage_entered(stage: int, retry: bool)
	signal flow_changed(state: String)
	signal event_started(event_id: String)
	signal event_ended(event_id: String, outcome: String)
	signal event_progress(event_id: String, fraction: float)


class FakeRelay:
	var relay := Vector2(30, -40)
	var ring_radius := 12.0
	var inside := true


class FakeDirector:
	var relay := FakeRelay.new()
	func offer(id: String) -> Dictionary:
		return {"id": id, "model": relay} if id == "hold_the_relay" else {}


class FakeTerrain:
	func height(_x: float, _z: float) -> float:
		return 5.0


class FakeGame extends Node3D:
	var world := {"events": FakeDirector.new()}


class FakeStages:
	static func world_of(stage: int) -> int:
		return [1, 1, 2, 2, 3, 3][stage - 1]


# The game's wiring (game.gd calls WorldFx.hook): the air follows the stage's world, weather lays its
# overlay, and menus rest it.
func _wiring() -> void:
	for d in load("res://src/core/park_defs.gd").DEFS:
		t.check("park world %s has air" % d["world"], Specs.WORLD_SETS.has(int(d["world"])))
	var game := FakeGame.new()
	root.add_child(game)
	var events := FakeEvents.new()
	game.add_child(events)
	var cam := Camera3D.new()
	game.add_child(cam)
	var ball := Node3D.new()
	game.add_child(ball)
	var ctx := {"root": game, "events": events, "stages": FakeStages, "camera": cam, "player": ball, "terrain": FakeTerrain.new()}
	var fx := WorldFx.hook(ctx)
	t.check("hook installs one WorldFx under the game", fx.get_parent() == game and WorldFx.current == fx)
	events.stage_entered.emit(3, false)
	t.eq("stage 3 breathes the Dig's air", fx.ambient.map(func(p): return p.get_meta("world_fx")), Specs.SETS["dig"])
	var first: GPUParticles3D = fx.ambient[0]
	events.stage_entered.emit(4, true)
	t.check("a stage in the same world keeps its emitters", fx.ambient[0] == first)
	WorldFx.lay_overlay("storm_build")
	t.check("weather lands its overlay", fx.overlay_kind == "storm_build" and fx.overlay.size() == 1)
	WorldFx.lay_overlay("")
	t.check("weather ending clears it", fx.overlay.is_empty())
	events.flow_changed.emit("summary")
	t.check("the summary rests the air", not fx.visible and fx.ambient.all(func(p): return not p.emitting))
	fx.set_quality(false, false)
	t.check("a preset change while resting keeps it resting", fx.ambient.all(func(p): return not p.emitting))
	events.stage_entered.emit(5, false)
	t.check("the next stage wakes the Highdraft's air", fx.visible and fx.world == 3
		and fx.ambient.all(func(p): return p.emitting))
	events.event_started.emit("hold_the_relay")
	var relay: Node3D = fx._relay
	t.check("the relay starting drops its anchor at the mast foot, sized to the ring", relay != null
		and relay.global_position.is_equal_approx(Vector3(30, 5, -40)) and is_equal_approx(relay.scale.x, 0.5))
	events.event_progress.emit("hold_the_relay", 0.3)
	t.check("progress feeds the charge level", is_equal_approx(relay.level, 0.3) and not relay.paused)
	t.check("crossing a quarter traces the ring", fx._bursts.has("relay_ring_tick")
		and fx._bursts["relay_ring_tick"][0].emitting)
	game.world["events"].relay.inside = false
	events.event_progress.emit("hold_the_relay", 0.35)
	t.check("out of the ring the charge effects pause", relay.paused)
	events.event_ended.emit("hold_the_relay", "won")
	t.check("a win fires the full burst at the mast", fx._bursts["relay_full_burst"][0].emitting
		and fx._bursts["relay_full_burst"][0].global_position.is_equal_approx(Vector3(30, 5, -40)) and fx._relay == null)
	events.event_started.emit("flood")
	t.check("other events place no relay", fx._relay == null)
	game.queue_free()
	await process_frame


func _anchors() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var relay := Anchor.make("relay")
	stage.add_child(relay)
	t.check("a dropped anchor emits with no WorldFx", relay.emitters.all(func(p): return p.emitting))
	relay.set_level(0.0)
	var empty: float = relay.emitters[0].amount_ratio
	relay.set_level(1.0)
	t.check("the relay's motes thicken as it charges", relay.emitters[0].amount_ratio > empty * 3.0
		and relay.emitters[1].speed_scale > 1.0)
	relay.set_level(0.5, true)
	t.check("an empty ring pauses the charge effects", relay.emitters.all(func(p): return not p.emitting))
	var dam := Anchor.make("landmark_dam")
	stage.add_child(dam)
	t.check("the dam carries its rainbow", dam.find_children("Extra_arc", "", false, false).size() == 1)
	dam.set_range(dam.lod_m() + 1.0, true)
	t.check("past lod_m the dam rests and shows its impostor", dam.emitters.all(func(p): return not p.emitting)
		and dam.impostors.all(func(q): return q.visible))
	dam.set_range(50.0, false)
	t.check("without a slot it rests too", dam.emitters.all(func(p): return not p.emitting))
	dam.set_range(50.0, true)
	t.check("near and slotted it emits, impostor hidden", dam.emitters.all(func(p): return p.emitting)
		and dam.impostors.all(func(q): return not q.visible))
	var head := Anchor.make("landmark_headframe")
	stage.add_child(head)
	head.set_quality(false, true)
	t.check("reduced motion silences the sheave sparks", head.emitters[1].amount_ratio == 0.0)
	stage.free()


func _cable() -> void:
	var a := Vector3(0, 10, 0)
	var b := Vector3(20, 8, 0)
	var c := Cable.make(a, b, 3.0)
	var verts: PackedVector3Array = c.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lowest := INF
	for v in verts:
		lowest = minf(lowest, v.y)
	t.check("a cable hangs from a to b and sags", verts[0].distance_to(a) < 0.1 and verts[verts.size() - 1].distance_to(b) < 0.1
		and lowest < 9.0 - 2.5)
	var sway: float = (c.material_override as ShaderMaterial).get_shader_parameter("sway_m")
	t.near("a 20 m span sways about 0.4 m", sway, 0.4, 0.05)
	c.set_motion(false)
	t.check("reduced motion stills the cable", (c.material_override as ShaderMaterial).get_shader_parameter("motion_enabled") == false)
	c.free()
