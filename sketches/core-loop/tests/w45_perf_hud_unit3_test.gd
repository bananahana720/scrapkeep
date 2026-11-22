extends SceneTree

const RunStatus := preload("res://src/ui/run_status.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const AimStyle := preload("res://src/movement/aim_style.gd")
const Augments := preload("res://src/movement/augments.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const Hud := preload("res://src/ui/hud.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const Companion := preload("res://src/core/companion.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w45_perf_hud_unit3_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await _run_status()
	await _reticle()
	await _edge_markers()
	_companion()
	await _ability_bar()
	quit(_t.verdict())


class _Counter:
	var n := 0

	func hit() -> void:
		n += 1


func _counted(item: CanvasItem) -> _Counter:
	var c := _Counter.new()
	item.draw.connect(c.hit)
	return c


func _run_status() -> void:
	var status := RunStatus.new()
	root.add_child(status)
	var draws := _counted(status)
	await _frames(2)
	var before := draws.n
	status.set_status(1, 3, false, false, 0)
	await _frames(2)
	_t.check("status: the first status draws even when it matches the defaults", draws.n > before, "%d draws" % (draws.n - before))
	before = draws.n
	for i in 5:
		status.set_status(1, 3, false, false, 0)
		await process_frame
	_t.eq("status: an identical status draws nothing", draws.n - before, 0)
	status.set_status(2, 3, false, false, 0)
	await _frames(2)
	_t.check("status: a new stage redraws", draws.n > before and status.stage == 2, "%d draws, stage %d" % [draws.n - before, status.stage])
	status.set_status(2, 3, false, false, 1)
	_t.check("status: a threat rise blinks", status.rising() and status.threat == 1 and status.steps_lit() == 2)
	before = draws.n
	await _frames(3)
	_t.check("status: the blink redraws every frame", draws.n - before >= 3, "%d draws" % (draws.n - before))
	status.set_status(2, 3, false, false, 1)
	_t.check("status: an identical status keeps the blink", status.rising())
	status.queue_free()


class _Kit:
	var aim := {"state": Augments.AIM_NONE}
	var hooked := false
	var rewind_left := 0.0
	var grapple := true

	func on(key: String) -> bool:
		return grapple and key == Augments.GRAPPLE


class _Tuning:
	func harpoon_rewind() -> float:
		return 1.0


class _Player:
	var kit := _Kit.new()
	var tuning := _Tuning.new()
	var at := Vector3.ZERO
	var reach := 30.0

	func shown_position() -> Vector3:
		return at

	func grapple_range() -> float:
		return reach


class _CountedReticle extends AimReticle:
	var casts := 0

	func _out_of_range(aim: Dictionary) -> bool:
		casts += 1
		return super(aim)


func _reticle() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0.0, 1.0, 0.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = Augments.WORLD_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 40.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = Vector3(0.0, 0.0, -60.0)
	var player := _Player.new()
	var reticle := _CountedReticle.new()
	root.add_child(reticle)
	reticle.setup(player, cam)
	var draws := _counted(reticle)
	await _physics(3)
	await _frames(3)
	var aim: Dictionary = player.kit.aim
	_t.check("reticle: a wall past the line's reach reads out of range", reticle._out_of_range_cached and reticle._out_of_range(aim),
		"cached %s, direct %s" % [reticle._out_of_range_cached, reticle._out_of_range(aim)])
	_t.eq("reticle: out of range is the hollow ring", reticle.drawn_shape(AimStyle.of(aim, reticle._out_of_range_cached)), "hollow_ring")

	var d0 := draws.n
	var c0 := reticle.casts
	var p0 := Engine.get_physics_frames()
	await _frames(30)
	var physics := Engine.get_physics_frames() - p0
	_t.eq("reticle: a still reticle is not redrawn", draws.n - d0, 0)
	_t.check("reticle: a still view casts at most once per six physics frames", reticle.casts - c0 <= physics / AimReticle.OUT_OF_RANGE_FRAMES + 1,
		"%d casts over %d physics frames" % [reticle.casts - c0, physics])

	wall.position = Vector3(0.0, 0.0, -10.0)
	await _physics(AimReticle.OUT_OF_RANGE_FRAMES + 2)
	await _frames(2)
	_t.check("reticle: a wall moved into reach under a still camera clears the out-of-range ring", not reticle._out_of_range_cached and not reticle._out_of_range(aim))
	_t.check("reticle: that change redraws", draws.n > d0, "%d draws" % (draws.n - d0))
	wall.position = Vector3(0.0, 0.0, -60.0)
	await _physics(2)
	await _frames(1)
	var c1 := reticle.casts
	cam.rotate_y(0.01)
	await _frames(1)
	_t.check("reticle: a turned camera recasts at once", reticle.casts > c1 and reticle._out_of_range_cached, "%d casts" % (reticle.casts - c1))
	await _frames(2)

	var changes := [
		["gauge", func(): reticle.gauge = 0.5],
		["gauge colour", func(): reticle.gauge_color = Color.RED],
		["harpoon ring", func(): player.kit.rewind_left = 0.5],
		["meter", func(): reticle.meter = 0.4],
		["aim", func(): player.kit.aim = {"state": Augments.AIM_REACH}],
		["hook", func(): player.kit.hooked = true],
		["grapple off", func(): player.kit.grapple = false],
	]
	for change in changes:
		await _frames(2)
		var before := draws.n
		change[1].call()
		await _frames(1)
		_t.check("reticle: a %s change redraws at once" % change[0], draws.n > before, "%d draws" % (draws.n - before))
		await _frames(2)
		before = draws.n
		await _frames(3)
		_t.eq("reticle: then it goes still after the %s change" % change[0], draws.n - before, 0)
	player.kit.grapple = true
	player.kit.hooked = false
	player.kit.aim = {"state": Augments.AIM_NONE}
	_t.eq("reticle: unhooked, a body aim is the brackets again", reticle.drawn_shape(AimStyle.of({"state": Augments.AIM_BODY})), "brackets")
	await _frames(3)

	var before := draws.n
	reticle._on_line_state("dry_fire", null, Vector3.ZERO, "")
	await _frames(6)
	_t.check("reticle: a dry fire redraws every frame of the shake", draws.n - before >= 6, "%d draws in 6 frames" % (draws.n - before))
	for i in 2000:
		if reticle.shake_offset() == Vector2.ZERO:
			break
		await process_frame
	await _frames(2)
	before = draws.n
	await _frames(3)
	_t.eq("reticle: still once the shake ends", draws.n - before, 0)
	_t.eq("reticle: the shake leaves the reticle centred", reticle.rect().get_center(), reticle.get_viewport_rect().size * 0.5)

	reticle.meter = 1.0
	reticle.meter_full = true
	reticle.hide_q = false
	await _frames(2)
	before = draws.n
	await _frames(5)
	_t.check("reticle: a full meter breathes every frame", draws.n - before >= 5, "%d draws in 5 frames" % (draws.n - before))
	_t.check("reticle: the Q keycap shows on a full meter", reticle.q_shown() and not reticle.drawn_words().is_empty())
	reticle.hide_q = true
	_t.check("reticle: the Q prompt hides the keycap", not reticle.q_shown())
	reticle.meter_full = false
	reticle.meter = 0.0
	await _frames(3)
	before = draws.n
	await _frames(3)
	_t.eq("reticle: still after the breath stops", draws.n - before, 0)
	var r := AimReticle.GAUGE_RING + AimReticle.METER_GAP + AimReticle.METER_WIDTH
	_t.eq("reticle: rect is the meter's outer ring", reticle.rect().size, Vector2(r, r) * 2.0)
	reticle.queue_free()
	world.queue_free()
	await _frames(1)


class _Map:
	var contraptions: Array

	func _init(rows: Array) -> void:
		contraptions = rows


class _Ground:
	var calls := 0
	var ridge := false

	func height(_x: float, z: float) -> float:
		calls += 1
		return 60.0 if ridge and z < -20.0 and z > -40.0 else 0.0


class _Terrain:
	var ground := _Ground.new()
	var current: _Map
	var stage := 1

	func map() -> RefCounted:
		return current

	func height(x: float, z: float) -> float:
		return ground.height(x, z)


class _Doors:
	var valves: Array = []
	var walls: Array = []


class _World:
	var terrain := _Terrain.new()
	var contraptions := {1: _Doors.new()}


class _Flow:
	func in_play() -> bool:
		return true


class _CameraRig:
	var cam: Camera3D


class _Game:
	var world := _World.new()
	var player := _Player.new()
	var flow := _Flow.new()
	var camera := _CameraRig.new()


func _edge_markers() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0.0, 3.0, 0.0)
	var game := _Game.new()
	game.camera.cam = cam
	var valve := {"kind": "valve", "id": "v1", "at": Vector2(0.0, -95.0), "door": {"at": Vector2(0.0, -100.0)}}
	var wall := {"kind": "cracked_wall", "id": "w1", "at": Vector3(8.0, 0.0, -100.0)}
	var map := _Map.new([valve, wall])
	game.world.terrain.current = map
	var markers := EdgeMarkers.new()
	markers.game = game
	var ground: _Ground = game.world.terrain.ground
	var size := Vector2(1920.0, 1080.0)

	var doors: Array = markers._doors_of(map)
	_t.eq("pockets: the cache holds the map's doors", doors, EdgeMarkers.pocket_doors(map))
	_t.check("pockets: the same map reuses its doors", is_same(markers._doors_of(map), doors))

	ground.ridge = true
	markers.note_pockets(size)
	_t.check("pockets: a door behind a ridge is not found", markers.discovered.is_empty(), str(markers.discovered))
	var marched := ground.calls
	ground.calls = 0
	for i in 5:
		markers.note_pockets(size)
	_t.check("pockets: a still ball and camera skip the sight march", marched > 10 and ground.calls == 0,
		"%d ground reads on the first pass, %d on five still ones" % [marched, ground.calls])
	game.player.at = Vector3(0.0, 0.0, 0.1)
	markers.note_pockets(size)
	_t.check("pockets: a hair of movement under the threshold stays skipped", ground.calls == 0, "%d reads" % ground.calls)

	ground.ridge = false
	game.player.at = Vector3(0.0, 0.0, 1.0)
	markers.note_pockets(size)
	_t.check("pockets: moving into sight finds both doors", markers.discovered.size() == 2, str(markers.discovered))
	ground.calls = 0
	game.player.at = Vector3(5.0, 0.0, 5.0)
	cam.rotate_y(0.2)
	markers.note_pockets(size)
	_t.eq("pockets: with every door found nothing is marched", ground.calls, 0)

	markers.discovered.clear()
	markers.note_pockets(size)
	_t.check("pockets: a cleared run finds the doors again from the same spot", markers.discovered.size() == 2, str(markers.discovered))

	cam.rotation = Vector3(0.0, PI, 0.0)
	markers.discovered.clear()
	markers.note_pockets(size)
	_t.check("pockets: a door behind the camera is not found", markers.discovered.is_empty(), str(markers.discovered))
	cam.rotation = Vector3.ZERO
	markers.note_pockets(size)
	_t.eq("pockets: turning the camera to it finds it", markers.discovered.size(), 2)

	var shown := markers._pocket_targets_now().map(func(t): return t["pocket"])
	_t.eq("pockets: both discovered doors are targets", shown, ["v1", "w1"])
	game.world.contraptions[1].valves = [{"spec": {"id": "v1"}, "open": true}]
	shown = markers._pocket_targets_now().map(func(t): return t["pocket"])
	_t.eq("pockets: an opened door drops out", shown, ["w1"])
	_t.check("pockets: the cached doors are left as built", markers._doors_of(map).all(func(d): return not d.has("done")))
	markers.discovered.clear()
	markers.note_pockets(size)
	_t.check("pockets: an opened door is still latched once seen, as before", markers.discovered.has(doors[0]["key"]), str(markers.discovered))

	var moved := _Map.new([{"kind": "cracked_wall", "id": "w2", "at": Vector3(-8.0, 0.0, -90.0)}])
	game.world.terrain.current = moved
	var fresh: Array = markers._doors_of(moved)
	_t.check("pockets: a new map rebuilds the doors", fresh.size() == 1 and fresh[0]["id"] == "w2", str(fresh))
	markers.note_pockets(size)
	_t.check("pockets: a new map is checked without moving", markers.discovered.has(fresh[0]["key"]), str(markers.discovered))
	game.world.terrain.current = _Map.new([])
	_t.check("pockets: a map without doors has no targets", markers._pocket_targets_now().is_empty())
	markers.free()
	cam.queue_free()
	await _frames(1)


class _Audio:
	var played: Array[String] = []

	func play(kind: String, _a: float, _b: float, _bus: String) -> void:
		played.append(kind)


class _Run:
	var companion := {}


class _HudGame:
	var run := _Run.new()
	var sound := _Audio.new()

	func audio():
		return sound


func _escape_doc(ready: bool) -> Dictionary:
	var m := Companion.new()
	m.acquire("escape_vent")
	m.acquire("ram_prow")
	m.assemble(["escape_vent", "ram_prow"])
	if not ready:
		m.spend_escape()
	return m.to_dict()


func _companion() -> void:
	var hud := Hud.new()
	var game := _HudGame.new()
	hud.game = game
	var pip := TextureRect.new()
	hud._companion = pip
	var step := func(n: int):
		for i in n:
			hud._step_companion(true)

	step.call(3)
	_t.check("companion: an empty record is none, hidden and silent", hud.companion_state() == "none" and not pip.visible and hud.companion_cues().is_empty())
	var ready := _escape_doc(true)
	var spent := _escape_doc(false)
	_t.eq("companion: the ready record reads ready", Hud.companion_state_of(ready), "ready")
	if not _t.check("companion: the spent record reads spent", Hud.companion_state_of(spent) == "spent", Hud.companion_state_of(spent)):
		hud.free()
		return
	game.run.companion = ready.duplicate(true)
	step.call(3)
	_t.check("companion: ready shows the pip and does not chirp from none",
		hud.companion_state() == "ready" and pip.visible and hud.companion_cues().is_empty()
			and pip.modulate == EventKinds.UI_ROWS["companion_ready"]["color"])
	hud._step_companion(false)
	_t.check("companion: out of play the pip hides", not pip.visible)
	var doc: Dictionary = game.run.companion
	doc.clear()
	doc.merge(spent.duplicate(true))
	step.call(3)
	_t.check("companion: a record spent in place chirps once", hud.companion_state() == "spent"
		and hud.companion_cues() == (["companion_spent"] as Array[String]) and game.sound.played == (["companion_spent"] as Array[String]),
		"%s, cues %s, played %s" % [hud.companion_state(), hud.companion_cues(), game.sound.played])
	game.run.companion = ready.duplicate(true)
	step.call(2)
	_t.eq("companion: refilled chirps ready", hud.companion_cues(), ["companion_spent", "companion_ready"] as Array[String])
	game.run.companion = {}
	step.call(2)
	_t.check("companion: emptied goes none, hidden and silent", hud.companion_state() == "none" and not pip.visible and hud.companion_cues().size() == 2)
	game.run.companion = ready.duplicate(true)
	step.call(1)
	_t.check("companion: the same record back after none reads ready again silently", hud.companion_state() == "ready" and hud.companion_cues().size() == 2)
	pip.free()
	hud.free()


func _slot(slot: String, state: String, extra := {}) -> Dictionary:
	var entry := {"slot": slot, "id": slot, "icon": "ab_sable_special", "key": "key_2", "cooldown_frac": 0.0,
		"charges": 1, "max_charges": 1, "number": 2, "group": "bar", "select_left": 1.0, "state": state, "selected": false}
	entry.merge(extra, true)
	return entry


func _ability_bar() -> void:
	var tint := Color(0.85, 0.45, 0.2)
	var list := [_slot("a", "ready"), _slot("b", "cooling", {"cooldown_frac": 0.5}), _slot("c", "active"),
		_slot("d", "unavailable"), _slot("e", "ready", {"selected": true, "key": "key_3"})]
	var headless := DisplayServer.get_name() == "headless"
	var view := SubViewport.new()
	view.size = Vector2i(1600, 900)
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var bar := AbilityBar.new()
	bar.position = Vector2(40.0, 80.0)
	view.add_child(bar)
	bar.update_slots(list, tint)
	bar.step(1.0)
	var draws := _counted(bar)
	var alone: Array = []
	for i in list.size():
		var one := AbilityBar.new()
		one.position = Vector2(40.0 + 300.0 * i, 480.0)
		view.add_child(one)
		one.update_slots([list[i]], tint)
		one.step(1.0)
		alone.append(one)
	await _frames(3)
	_t.check("bar: every slot state draws", draws.n > 0 and bar.slot_rects().size() == list.size(), "%d draws" % draws.n)
	bar.set_piece = true
	await _frames(2)
	_t.check("bar: the set piece draws with its plates", bar.plates_shown())
	bar.set_piece = false
	await _frames(2)
	if headless:
		print("[bar pixels] SKIP: headless runs the dummy renderer; run windowed for the per-slot pixel match")
	else:
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		var rects: Dictionary = bar.slot_rects()
		for i in list.size():
			var name: String = list[i]["slot"]
			var own: Rect2 = (alone[i] as Control).slot_rects()[name]
			var full: Rect2 = rects[name]
			var a := Rect2i(Vector2i((bar.position + full.position).round()) + Vector2i(1, -8), Vector2i(full.size) + Vector2i(-2, 70))
			var shift := Vector2i(((alone[i] as Control).position + own.position).round()) - Vector2i((bar.position + full.position).round())
			var diff := 0
			for y in range(a.position.y, a.end.y):
				for x in range(a.position.x, a.end.x):
					if not _same_pixel(image.get_pixel(x, y), image.get_pixel(x + shift.x, y + shift.y)):
						diff += 1
			_t.eq("bar pixels: the %s slot in the full bar matches it drawn alone" % list[i]["state"] + (" (selected)" if list[i]["selected"] else ""), diff, 0)
	view.queue_free()
	await _frames(1)


# Within two steps of 255 a channel: a keycap's digit drawn at another x rounds its edge a step apart.
static func _same_pixel(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 2.0 / 255.0 and absf(a.g - b.g) <= 2.0 / 255.0 and absf(a.b - b.b) <= 2.0 / 255.0 and absf(a.a - b.a) <= 2.0 / 255.0
