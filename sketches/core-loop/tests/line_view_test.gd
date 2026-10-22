extends SceneTree

const T := preload("res://tests/support/t.gd")
const LineView := preload("res://src/presentation/line_view.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const AimStyle := preload("res://src/movement/aim_style.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Augments := preload("res://src/movement/augments.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The harpoon line's sights (HLv): the cable's width on screen, lock against latch, the dry
# fire and the reticle's readiness ring. It steps the view with fixed deltas; no wall clock.

const FRAME := 1.0 / 60.0
const DEPTH := 45.0
# The chase camera's widest lens (FOV_CAP), where a cable is thinnest on screen.
const WIDEST_FOV := 88.0
const SOURCES := ["res://src/presentation/line_view.gd", "res://src/movement/aim_style.gd"]
const BLACK_BACKING := "Color(0.0, 0.0, 0.0, 0.55)"

var _t


class FakePlayer extends Node3D:
	var kit := AugmentKit.new()
	var events := GameEvents.new()
	var tuning := Tuning.new()

	func shown_position() -> Vector3:
		return global_position

	func ball_position() -> Vector3:
		return global_position

	func grapple_range() -> float:
		return 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_t = T.new("line_view_test")
	var camera := Camera3D.new()
	camera.fov = WIDEST_FOV
	root.add_child(camera)
	camera.position = Vector3(0.0, 0.0, DEPTH)
	camera.current = true
	var player := FakePlayer.new()
	root.add_child(player)
	player.position = Vector3(-4.0, 0.0, 0.0)
	var view := LineView.new()
	root.add_child(view)
	view.setup(player, camera, player.events)
	_cable(view, player, camera)
	_fairlead(view, player)
	_carriage()
	_latch(view, player, camera)
	_lock(view, player)
	_transients(view, player)
	_reticle(player)
	_colours()
	view.free()
	player.events.free()
	player.free()
	camera.free()
	quit(_t.verdict())


# MOTION-SPEC swing row: the drawn rope leaves the collar fairlead, 1.06 m from the centre on the
# anchor's planar side, never inside the 1.0 collider; overhead it holds the last yaw.
# The hero's Fairlead carriage turns RopeExit to the anchor's side, through a yawed pod.
func _carriage() -> void:
	var hook := HeroAssets.new()
	var pod := Node3D.new()
	pod.position = Vector3(2.0, 1.0, 3.0)
	pod.rotation.y = 0.7
	var exit := Node3D.new()
	exit.name = "RopeExit"
	pod.add_child(exit)
	root.add_child(pod)
	HeroAssets.add_fairlead(pod)
	var anchor := pod.position + Vector3(-9.0, 5.0, 4.0)
	for i in 40:
		hook.steer_fairlead(pod, anchor, FRAME)
	var off := exit.global_position - pod.position
	var flat := Vector3(-9.0, 0.0, 4.0).normalized()
	_t.check("FL-5 RopeExit rides the carriage to the anchor's side", exit.get_parent().name == "Fairlead" and absf(off.length() - 1.06) <= 0.001 and absf(off.y) <= 0.001 and off.normalized().distance_to(flat) <= 0.001,
		"RopeExit %s from the pod, want 1.06 m toward %s" % [off, flat])
	pod.free()
	hook.free()


func _settle(view, frames := 30) -> void:
	for i in frames:
		view.step(FRAME)


func _fairlead(view, player) -> void:
	var kit = player.kit
	kit.hooked = true
	kit.on_body = false
	kit.rope = 30.0
	var centre: Vector3 = player.global_position
	kit.anchor = centre + Vector3(6.0, 8.0, -8.0)
	_settle(view)
	var flat := Vector3(6.0, 0.0, -8.0).normalized()
	var off: Vector3 = view.cable_origin - centre
	_t.check("FL-1 starts 1.06 m out on the anchor's side", absf(off.length() - 1.06) <= 0.001 and off.normalized().distance_to(flat) <= 0.001 and absf(off.y) <= 0.001,
		"first point %s from the centre, want 1.06 m toward %s" % [off, flat])
	_t.check("FL-1 never inside the collider", off.length() > 1.0, "%.3f m from the centre, collider 1.0" % off.length())
	kit.anchor = centre + Vector3(0.0, 12.0, 0.0)
	_settle(view, 10)
	var held: Vector3 = view.cable_origin - centre
	_t.check("FL-2 overhead holds the last yaw", held.distance_to(off) <= 0.001 and absf(held.length() - 1.06) <= 0.001,
		"overhead first point %s, last %s" % [held, off])
	kit.anchor = centre + Vector3(-5.0, -3.0, 0.0)
	_settle(view)
	var west: Vector3 = view.cable_origin - centre
	_t.check("FL-3 turns with the anchor", west.distance_to(Vector3(-1.06, 0.0, 0.0)) <= 0.001, "first point %s, want (-1.06, 0, 0)" % west)
	# FL-4: the anchor flips to the far side in one step (a swing's bottom); the origin turns at a
	# finite rate by the shorter arc instead of jumping across the collar.
	kit.anchor = centre + Vector3(5.0, -3.0, 0.0)
	var worst := 0.0
	var prev: Vector3 = view.cable_origin - centre
	var steps := 0
	for i in 40:
		view.step(FRAME)
		var now: Vector3 = view.cable_origin - centre
		worst = maxf(worst, prev.angle_to(now))
		prev = now
		steps += 1
	# Independent of the constant: a half turn must take at least 0.15 s, so under 0.35 rad a step.
	var limit := PI / (0.15 * 60.0)
	_t.check("FL-4 turn rate is limited", worst <= limit + 0.0001,
		"largest per-step arc %.4f rad, limit %.4f rad (jump would be %.2f rad)" % [worst, limit, PI])
	_t.check("FL-4 arrives", prev.distance_to(Vector3(1.06, 0.0, 0.0)) <= 0.001, "settled at %s after %d steps" % [prev, steps])
	# FL-6: a new hook on the far side leaves from the anchor's side on its first frame; the rate limit
	# is for a live rope only, or the fresh line would cross the ball while the collar turned.
	kit.hooked = false
	_settle(view, 120)
	kit.hooked = true
	kit.anchor = centre + Vector3(-5.0, 2.0, 0.0)
	view.step(FRAME)
	var fresh: Vector3 = view.cable_origin - centre
	_t.check("FL-6 a new hook starts on the anchor's side", fresh.distance_to(Vector3(-1.06, 0.0, 0.0)) <= 0.001, "first frame %s, want (-1.06, 0, 0)" % fresh)
	kit.hooked = false


func _cable(view, player, camera) -> void:
	var kit = player.kit
	kit.hooked = true
	kit.on_body = false
	kit.anchor = Vector3(4.0, 0.0, 0.0)
	kit.rope = 12.0
	view.step(FRAME)
	var slack_colour: Color = view._cable_material.albedo_color
	var slack_radius: float = view.cable_radius
	var slack_px := _measured_px(view, camera)
	kit.rope = 8.0
	view.step(FRAME)
	var taut_colour: Color = view._cable_material.albedo_color
	var taut_px := _measured_px(view, camera)
	_t.check("HL-1 5 px at 45 m", slack_px >= 5.0 - 0.01 and taut_px >= 5.0 - 0.01,
		"slack %.2f px and taut %.2f px wide at %.0f m at %.0f p" % [slack_px, taut_px, DEPTH, LineView.REF_HEIGHT])
	_t.check("HL-1 slack differs from taut", view.cable_taut and not is_equal_approx(slack_radius, view.cable_radius)
		and taut_colour.get_luminance() > slack_colour.get_luminance(),
		"radius %.2f m slack, %.2f m taut; luminance %.2f slack, %.2f taut" % [slack_radius, view.cable_radius, slack_colour.get_luminance(), taut_colour.get_luminance()])
	_t.check("HL-1 radii", is_equal_approx(slack_radius, 0.09) and is_equal_approx(view.cable_radius, 0.14), "0.09 and 0.14 m")
	camera.position = Vector3(0.0, 0.0, 10.0)
	kit.rope = 12.0
	view.step(FRAME)
	var near_slack := _measured_px(view, camera)
	kit.rope = 8.0
	view.step(FRAME)
	var near_taut := _measured_px(view, camera)
	_t.check("HL-1 radius shows near", near_taut > near_slack, "at 10 m %.1f px slack, %.1f px taut" % [near_slack, near_taut])
	camera.position = Vector3(0.0, 0.0, DEPTH)
	kit.line_state = Augments.LINE_SMASH
	view.step(FRAME)
	var flash: Color = view._cable_material.albedo_color
	for i in 12:
		view.step(FRAME)
	_t.check("smash flashes white", flash.get_luminance() > taut_colour.get_luminance() and view._cable_material.albedo_color.get_luminance() <= flash.get_luminance(),
		"luminance %.2f at the commit, %.2f after" % [flash.get_luminance(), view._cable_material.albedo_color.get_luminance()])
	kit.line_state = Augments.LINE_LATCHED
	kit.hooked = false
	view.step(FRAME)


# The widest cross-section of the cable's mesh, in pixels at the reference height.
func _measured_px(view, camera) -> float:
	var arrays: Array = view.cable.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var widest := 0.0
	for i in range(0, verts.size() - 1, 2):
		var mid := (verts[i] + verts[i + 1]) * 0.5
		var depth := absf(camera.global_position.z - mid.z)
		var focal: float = LineView.REF_HEIGHT * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
		widest = maxf(widest, verts[i].distance_to(verts[i + 1]) * focal / depth)
	return widest


func _latch(view, player, camera) -> void:
	var kit = player.kit
	kit.hooked = true
	kit.on_body = true
	kit.line_state = Augments.LINE_LATCHED
	kit.anchor = Vector3(4.0, 0.0, 0.0)
	var seen_barb := true
	var seen_collar := true
	var radii: Array[float] = []
	var scales: Array[float] = []
	for i in 40:
		player.position.x = -4.0 + float(i) * 0.15
		view.step(FRAME)
		seen_barb = seen_barb and view.barb != null and view.barb.visible
		seen_collar = seen_collar and view.collar != null and view.collar.visible
		radii.append(view.collar_radius)
		scales.append(view.collar_scale)
	_t.check("HL-2 barb and collar stand", seen_barb and seen_collar, "both present on all 40 ticks of a body latch")
	_t.check("HL-2 collar tightens", radii[-1] < radii[0], "radius %.2f m at the bite, %.2f m with the gap closed" % [radii[0], radii[-1]])
	_t.check("HL-2 collar steady", scales.min() == scales.max(), "scale %.3f to %.3f over 40 ticks" % [scales.min(), scales.max()])
	_t.eq("HL-2 row motions", [EventKinds.line_row("latched_body")["motion"], EventKinds.line_row("locked")["motion"]], ["steady", "pulse"])
	var barb = view.barb
	var collar = view.collar
	kit.hooked = false
	kit.on_body = false
	view.step(FRAME)
	_t.check("HL-2 freed within one tick", view.barb == null and view.collar == null and not is_instance_valid(barb) and not is_instance_valid(collar),
		"barb and collar freed on the first step after the line ended")
	kit.hooked = true
	kit.anchor = Vector3(4.0, 0.0, 0.0)
	player.position = Vector3(-4.0, 0.0, 0.0)
	view.step(FRAME)
	_t.check("anchor ring on a world latch", view.post_ring.visible and view.barb == null, "ring up, no barb")
	kit.hooked = false
	view.step(FRAME)
	_t.check("anchor ring gone", not view.post_ring.visible, "ring down with the line")


func _lock(view, player) -> void:
	player.kit.aim = {"state": Augments.AIM_REACH, "point": Vector3(4.0, 0.0, 0.0), "normal": Vector3.UP}
	player.events.line_state_changed.emit("locked", null, Vector3(4.0, 0.0, 0.0), "")
	var scales: Array[float] = []
	for i in 60:
		view.step(FRAME)
		if i >= 10:
			scales.append(view.lock_scale)
	_t.check("HL-2 brackets pulse", view.brackets.visible and scales.max() - scales.min() > 0.1,
		"scale %.3f to %.3f over a second after closing" % [scales.min(), scales.max()])
	player.events.line_state_changed.emit("searching", null, Vector3.ZERO, "")
	view.step(FRAME)
	_t.check("brackets gone with the lock", not view.brackets.visible, "hidden once searching")


func _transients(view, player) -> void:
	player.events.line_state_changed.emit("dry_fire", null, player.global_position, "")
	var visible_at := -1.0
	var gone_at := -1.0
	var clock := 0.0
	for i in 30:
		view.step(FRAME)
		clock += FRAME
		if view.cable.visible and visible_at < 0.0:
			visible_at = clock
		if visible_at >= 0.0 and not view.cable.visible and gone_at < 0.0:
			gone_at = clock
	_t.check("HL-5 dry fire gone in 0.35 s", visible_at > 0.0 and gone_at > 0.0 and gone_at <= 0.35,
		"a slack line appeared at %.3f s and was gone at %.3f s" % [visible_at, gone_at])
	player.events.line_state_changed.emit("broke", null, Vector3(4.0, 0.0, 0.0), "out_of_reach")
	view.step(FRAME)
	var pieces: int = view.cable.mesh.get_surface_count()
	var rust: Color = view._cable_material.albedo_color
	for i in 24:
		view.step(FRAME)
	_t.check("broke: two pieces in rust, then gone", pieces == 2 and is_equal_approx(rust.r, EventKinds.line_color("broke").r) and not view.cable.visible,
		"%d pieces, red %.2f (rust %.2f), cable hidden after the beat" % [pieces, rust.r, EventKinds.line_color("broke").r])
	player.events.line_state_changed.emit("let_go", null, Vector3(4.0, 0.0, 0.0), "")
	view.step(FRAME)
	var shown: bool = view.cable.visible
	for i in 12:
		view.step(FRAME)
	_t.check("let go retracts in 0.15 s", shown and not view.cable.visible, "cable shown on the let-go, gone 0.2 s later")


func _reticle(player) -> void:
	var reticle := AimReticle.new()
	root.add_child(reticle)
	reticle.setup(player, null)
	var body_style: Dictionary = AimStyle.of({"state": Augments.AIM_BODY})
	player.kit.hooked = false
	var free_shape: String = reticle.drawn_shape(body_style)
	player.kit.hooked = true
	var held_shape: String = reticle.drawn_shape(body_style)
	player.kit.hooked = false
	_t.check("the reticle is a dot while a line stands", free_shape == "brackets" and held_shape == "dot",
		"aimed at a body: %s with no line, %s with one" % [free_shape, held_shape])
	player.kit.rewind_left = 0.4
	var fill: float = reticle.harpoon_readiness()
	_t.near("HL-5 harpoon ring fill", fill, 1.0 - 0.4 / player.tuning.f("harpoon_rewind"))
	player.kit.rewind_left = 0.0
	_t.near("HL-5 a refund fills at once", reticle.harpoon_readiness(), 1.0)
	_t.check("HL-5 own variable", reticle.gauge == 0.0 and reticle.get("harpoon_fill") != null and AimReticle.HARPOON_RING != AimReticle.GAUGE_RING,
		"gauge untouched at %.1f; harpoon ring radius %.0f against the special's %.0f" % [reticle.gauge, AimReticle.HARPOON_RING, AimReticle.GAUGE_RING])
	player.events.line_state_changed.emit("dry_fire", null, Vector3.ZERO, "")
	var widest := 0.0
	for i in 15:
		reticle.step(FRAME)
		widest = maxf(widest, reticle.shake_offset().length())
	for i in 5:
		reticle.step(FRAME)
	_t.check("dry fire shakes 3 px", widest > 1.0 and widest <= 3.0 + 0.001 and reticle.shake_offset() == Vector2.ZERO,
		"widest offset %.2f px, still after 0.33 s" % widest)
	reticle.free()


func _colours() -> void:
	for path in SOURCES + ["res://src/ui/aim_reticle.gd"]:
		var text := FileAccess.get_file_as_string(path)
		var literal := RegEx.create_from_string("Color\\(\\s*[0-9.]+\\s*,|Color\\(\"|Color\\(0x")
		var offenders := 0
		for line in text.split("\n"):
			if literal.search(line) != null and line.find(BLACK_BACKING) < 0:
				offenders += 1
		_t.check("HL-3 no colour literal in " + path.get_file(), offenders == 0 and text.find("Palette.") < 0 and text.find("Palette\"") < 0,
			"%d colour literals, no Palette reads" % offenders)
	var slate: Color = AimStyle.of({"state": Augments.AIM_NONE}, true)["color"]
	_t.check("HL-3 out of range is slate", slate == EventKinds.role_color("slate") and AimStyle.of({"state": Augments.AIM_NONE}, true)["shape"] == "hollow_ring",
		"hollow ring in the slate role colour")
	_t.check("HL-3 searching is a neutral cross", AimStyle.of({"state": Augments.AIM_NONE})["color"] == EventKinds.line_color("searching")
		and AimStyle.of({"state": Augments.AIM_NONE})["shape"] == "cross", "cross in the searching row's colour")
	_t.check("HL-3 locked colour", AimStyle.of({"state": Augments.AIM_BODY})["color"] == EventKinds.line_color("locked"), "brackets in the locked row's colour")
