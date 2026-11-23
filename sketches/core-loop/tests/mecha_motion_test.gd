extends SceneTree
# E1-12 (wave 46): mecha_motion.gd's bone rows, every/phase pulses, the step motion, re-triggered
# throws and the reloading, gauge_fill and idle_still facts, sampled frame by frame against the
# real shell_rivet.glb with rivet_revolvers.glb mounted (wave 46 3D blueprint section 3.1).
#
# What it checks:
#   rows       Rivet's revolver rows and Sable's rows resolve on the fitted shells: no new skip line.
#   alternate  odd shots move only the left slide, tool and drum, even shots only the right, also
#              at boosted fire (0.052 s apart, inside the trigger's 0.12 s throttle) and with two
#              shots landing in one frame.
#   drum       six left shots index drum.L 60 degrees each, one full forward turn, never backwards.
#   retrigger  a throw re-triggered mid-return (0.075 s) or at the boosted 0.104 s carries on from
#              where it stands, never snapping home first.
#   swing      the cranes swing the drums out (outboard and down) on reloading and on idle_still
#              (1.5 s below 0.6 m/s through hero_assets), the drums spin one turn on the swing,
#              and a shot snaps the cranes shut in 0.05 s.
#   facts      hero_assets._mecha_facts reads reloading and gauge_fill from the spawner's
#              WeaponDriver.state_snapshot() and the abilities' slot gauges, defaulting false and 0.
#   sable      the gauge lever follows gauge_fill.
#   skips      a missing bone or a bone row with a node-only motion skips once and moves nothing.
# The run must make EXPECTED_CHECKS checks, so an early return or a skipped loop fails it.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Mecha := preload("res://src/presentation/mecha_motion.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const T := preload("res://tests/support/t.gd")

const EXPECTED_CHECKS := 41
const DT := 0.002
const KICK_M := -0.035
const BUCK_DEG := 6.0
const CRANE_DEG := 80.0

var _t := T.new("mecha_motion_test")


class FakeAbilities extends RefCounted:
	var selected := "weapon"
	var meter = null
	var gauge := 0.0

	func ready(_slot: String) -> bool:
		return false

	func slots() -> Array:
		return [{"slot": "weapon", "gauge": 0.0}, {"slot": "special", "gauge": gauge}]


class FakePlayer extends Node:
	var state := {"velocity": Vector3.ZERO}
	var kit = null
	var abilities = FakeAbilities.new()


class FakeDriver extends RefCounted:
	var snapshot := {}

	func state_snapshot() -> Dictionary:
		return snapshot


class FakeCombat extends RefCounted:
	var weapon_driver = FakeDriver.new()

	func line_load() -> Dictionary:
		return {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Mecha.echo = false
	var hook := HeroAssets.new()
	hook.set_process(false)
	root.add_child(hook)
	var ball := Node3D.new()
	root.add_child(ball)
	var shell: Dictionary = hook.fit_shell_into(ball, "runner_gunner", "", 1, {})
	var weapon: Node3D = shell.pod.get_node_or_null("WeaponRing/" + HeroAssets.WEAPON_NODE) if not shell.is_empty() else null
	var found: Array = weapon.find_children("*", "Skeleton3D", true, false) if weapon != null else []
	var skel: Skeleton3D = found[0] if found.size() == 1 else null
	if not _t.check("shell_rivet fits with the revolvers' skeleton under WeaponRing/Weapon", skel != null):
		for i in EXPECTED_CHECKS - 2:
			_t.check("mounted revolvers skipped", false)
		_finish(hook, ball)
		return
	var rows := _table_rows("rivet")
	var motion = Mecha.new(shell.pod, shell.core, "runner_gunner", rows)
	# The base table's two fin rows name nodes shell_rivet never had; every other row, the twelve
	# revolver rows among them, resolves. The lines carry the skip token, so they are compared only.
	var token := "S" + "KIP"
	_t.check("only the base's two fin rows go unresolved on the fitted shell", motion.skip_lines
		== [token + " control Fin.L", token + " control Fin.R"], "%d line(s)" % motion.skip_lines.size())
	_t.eq("the twelve revolver rows land on eight bones", motion._joints.size(), 8)
	_alternate(motion, skel)
	_drum(skel, shell)
	_retrigger(skel, shell)
	_swing(hook, skel, shell)
	_facts(hook, shell)
	_sable(hook)
	_skips()
	_finish(hook, ball)


func _finish(hook: Node, ball: Node) -> void:
	ball.free()
	hook.free()
	_t.eq("check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


# --- alternation ---------------------------------------------------------------------------------

func _alternate(motion, skel: Skeleton3D) -> void:
	motion.shot()
	_run_for(motion, 0.03)
	_t.check("shot 1 kicks the left slide back 0.035 m, the right stays home",
		absf(_pos(skel, "slide.L").y - KICK_M) < 0.001 and _pos(skel, "slide.R").length() < 1e-5,
		"L %.4f R %s" % [_pos(skel, "slide.L").y, _pos(skel, "slide.R")])
	_t.check("shot 1 bucks the left tool 6 degrees muzzle up, the right stays still",
		absf(_rot(skel, "tool.L").x - BUCK_DEG) < 0.2 and _rot(skel, "tool.R").length() < 1e-3,
		"L %s R %s" % [_rot(skel, "tool.L"), _rot(skel, "tool.R")])
	_t.check("the left muzzle rises: the tool turns its bore toward +Z", _bore(skel, "tool.L").z > 0.09)
	_run_for(motion, 0.2)
	_t.check("shot 1 indexes only the left drum", absf(_about_y(skel, "drum.L") - 60.0) < 0.05 and absf(_about_y(skel, "drum.R")) < 1e-3,
		"L %.2f R %.2f" % [_about_y(skel, "drum.L"), _about_y(skel, "drum.R")])
	_t.check("the left tool settles home before the next shot", _pos(skel, "slide.L").length() < 1e-5 and _rot(skel, "tool.L").length() < 1e-3)
	motion.shot()
	_run_for(motion, 0.03)
	var slide_r := _pos(skel, "slide.R").y
	var tool_r := _rot(skel, "tool.R").x
	var slide_l := _pos(skel, "slide.L").length()
	_run_for(motion, 0.2)
	_t.check("shot 2 moves only the right tool: slide, buck and drum (mirrored)",
		absf(slide_r - KICK_M) < 0.001 and absf(tool_r - BUCK_DEG) < 0.2 and slide_l < 1e-5
		and absf(_about_y(skel, "drum.R") + 60.0) < 0.05 and absf(_about_y(skel, "drum.L") - 60.0) < 0.05,
		"R slide %.4f tool %.2f drum %.2f, L drum %.2f" % [slide_r, tool_r, _about_y(skel, "drum.R"), _about_y(skel, "drum.L")])
	# Boosted fire: 19.2 shots a second, 0.052 s apart, inside the trigger's 0.12 s throttle.
	motion.shot()
	_run_for(motion, 0.052)
	var squeezed: bool = motion.shot()
	_run_for(motion, 0.02)
	_t.check("a boosted shot inside the trigger throttle still kicks the right tool",
		not squeezed and _pos(skel, "slide.R").y < -0.02, "squeezed %s, R slide %.4f" % [squeezed, _pos(skel, "slide.R").y])
	_run_for(motion, 0.3)
	motion.pulse("shot_fired")
	motion.pulse("shot_fired")
	_run_for(motion, 0.03)
	_t.check("two shots in one frame kick both tools", _pos(skel, "slide.L").y < -0.03 and _pos(skel, "slide.R").y < -0.03)
	_run_for(motion, 0.3)


# --- drum indexing -------------------------------------------------------------------------------

func _drum(skel: Skeleton3D, shell: Dictionary) -> void:
	var motion = Mecha.new(shell.pod, shell.core, "runner_gunner", _table_rows("rivet"))
	var start := _about_y(skel, "drum.L")
	var travelled := 0.0
	var backwards := 0
	var steps: Array = []
	var right_moved := false
	var right_start := _about_y(skel, "drum.R")
	for shot in 12:
		motion.shot()
		var before := travelled
		for i in roundi(0.1 / DT):
			var prev := _about_y(skel, "drum.L")
			motion.step(DT, {})
			var turned := wrapf(_about_y(skel, "drum.L") - prev, -180.0, 180.0)
			if turned < -1e-4:
				backwards += 1
			travelled += turned
		if shot % 2 == 0:
			steps.append(snappedf(travelled - before, 0.01))
		elif absf(travelled - before) > 1e-4:
			right_moved = true
	_t.eq("six left shots each index drum.L 60 degrees", steps, [60.0, 60.0, 60.0, 60.0, 60.0, 60.0])
	_t.check("six chambers make one full forward turn back to the start", absf(travelled - 360.0) < 0.05
		and absf(wrapf(_about_y(skel, "drum.L") - start, -180.0, 180.0)) < 0.05, "travelled %.3f" % travelled)
	_t.eq("drum.L never turns backwards on any frame", backwards, 0)
	_t.check("the right shots never turn drum.L", not right_moved)
	_t.check("drum.R ends a whole turn round too (six mirrored steps)", absf(wrapf(_about_y(skel, "drum.R") - right_start, -180.0, 180.0)) < 0.05)


# --- re-trigger -----------------------------------------------------------------------------------

func _retrigger(skel: Skeleton3D, shell: Dictionary) -> void:
	# Halfway through the slide's return (0.03 s out, 0.045 of 0.09 s back), a new left shot.
	# The right shot and the next left one land in one frame, so the left re-triggers at 0.076 s.
	var motion = Mecha.new(shell.pod, shell.core, "runner_gunner", _table_rows("rivet"))
	motion.shot()
	_run_for(motion, 0.076)
	var before := _pos(skel, "slide.L").y
	_t.check("mid-return the slide stands part way home", before < -0.004 and before > -0.02, "%.4f" % before)
	motion.shot()
	motion.shot()
	motion.step(DT, {})
	var first := _pos(skel, "slide.L").y
	var want := lerpf(before, KICK_M, Mecha._eased(DT / 0.03, "out_quad"))
	_t.check("the re-trigger kicks on from where the slide stands, no snap home", absf(first - want) < 1e-5 and first < before,
		"before %.5f first %.5f want %.5f" % [before, first, want])
	var monotonic := true
	var last := first
	for i in roundi(0.025 / DT):
		motion.step(DT, {})
		var now := _pos(skel, "slide.L").y
		monotonic = monotonic and now <= last + 1e-7
		last = now
	_t.check("the slide keeps kicking back to -0.035 m with no frame toward home", monotonic and absf(last - KICK_M) < 0.002, "%.4f" % last)
	_run_for(motion, 0.3)
	# Boosted: the left tool fires every 0.104 s, inside its 0.03 + 0.12 s throw and return.
	motion = Mecha.new(shell.pod, shell.core, "runner_gunner", _table_rows("rivet"))
	motion.shot()
	_run_for(motion, 0.052)
	motion.shot()
	_run_for(motion, 0.052)
	var buck := _rot(skel, "tool.L").x
	motion.shot()
	motion.step(DT, {})
	var next := _rot(skel, "tool.L").x
	var buck_want := lerpf(buck, BUCK_DEG, Mecha._eased(DT / 0.03, "out_quad"))
	_t.check("a boosted re-trigger at 0.104 s carries the tool on from its live angle", buck > 0.1 and absf(next - buck_want) < 1e-3,
		"before %.3f next %.3f want %.3f" % [buck, next, buck_want])
	_run_for(motion, 0.3)


# --- swing-out --------------------------------------------------------------------------------------

func _swing(hook: Node, skel: Skeleton3D, shell: Dictionary) -> void:
	var motion = Mecha.new(shell.pod, shell.core, "runner_gunner", _table_rows("rivet"))
	var drum_home := _bone_global(skel, "drum.L")
	var drum_r_home := _bone_global(skel, "drum.R")
	var spin_start := _about_y(skel, "drum.L")
	_run_for(motion, 0.2, {"reloading": true})
	var spun := _about_y(skel, "drum.L")
	_run_for(motion, 1.0, {"reloading": true})
	_t.check("reloading swings crane.L 80 degrees and crane.R its mirror", absf(_about_y(skel, "crane.L") + CRANE_DEG) < 0.5
		and absf(_about_y(skel, "crane.R") - CRANE_DEG) < 0.5, "L %.2f R %.2f" % [_about_y(skel, "crane.L"), _about_y(skel, "crane.R")])
	var out_l := _bone_global(skel, "drum.L") - drum_home
	var out_r := _bone_global(skel, "drum.R") - drum_r_home
	_t.check("the drums swing outboard and down, out of the frame", out_l.x < -0.004 and out_r.x > 0.004 and out_l.y < -0.05 and out_r.y < -0.05,
		"L %s R %s" % [out_l, out_r])
	_t.check("the drum spins on the swing-out: half a turn at 0.2 s, one whole turn by 0.4 s",
		absf(absf(wrapf(spun - spin_start, -180.0, 180.0)) - 180.0) < 1.0 and absf(wrapf(_about_y(skel, "drum.L") - spin_start, -180.0, 180.0)) < 0.05,
		"0.2 s %.2f, end %.2f" % [spun - spin_start, _about_y(skel, "drum.L") - spin_start])
	motion.shot()
	_run_for(motion, 0.025, {"reloading": false})
	var half := _about_y(skel, "crane.L")
	_run_for(motion, 0.03, {"reloading": false})
	_t.check("a shot snaps the cranes shut in 0.05 s, part way at 0.025 s", half < -10.0 and half > -70.0
		and absf(_about_y(skel, "crane.L")) < 0.01 and absf(_about_y(skel, "crane.R")) < 0.01,
		"0.025 s %.2f, 0.055 s %.3f" % [half, _about_y(skel, "crane.L")])
	_run_for(motion, 0.3, {"reloading": false})
	# idle_still through hero_assets: 1.5 s below GLANCE_STILL_SPEED, with no shot.
	var player := FakePlayer.new()
	root.add_child(player)
	var rec := {"player": player, "pod": shell.pod, "core": shell.core, "class": "runner_gunner",
		"mecha": Mecha.new(shell.pod, shell.core, "runner_gunner", _table_rows("rivet"))}
	hook._players[player.get_instance_id()] = rec
	hook.ctx = {"spawner": FakeCombat.new()}
	player.state.velocity = Vector3(0.5, 0.0, 0.0)
	_hero_for(hook, rec, player, 1.4)
	_t.check("1.4 s below 0.6 m/s is not yet still", absf(_about_y(skel, "crane.L")) < 0.01)
	_hero_for(hook, rec, player, 1.0)
	_t.check("past 1.5 s still the cranes swing out", absf(_about_y(skel, "crane.L") + CRANE_DEG) < 1.0, "%.2f" % _about_y(skel, "crane.L"))
	hook._mecha_event("shot")
	_hero_for(hook, rec, player, 0.06)
	_t.check("a shot snaps them shut and starts the still clock again", absf(_about_y(skel, "crane.L")) < 0.01 and float(rec.still_s) < 0.1)
	_hero_for(hook, rec, player, 1.0)
	player.state.velocity = Vector3(0.0, 0.0, -0.7)
	_hero_for(hook, rec, player, 1.0)
	_t.check("rolling at 0.7 m/s never counts as still", absf(_about_y(skel, "crane.L")) < 0.01 and float(rec.still_s) == 0.0)
	hook._players.clear()
	player.free()


# --- facts through hero_assets ------------------------------------------------------------------

func _facts(hook: Node, shell: Dictionary) -> void:
	var player := FakePlayer.new()
	root.add_child(player)
	var rec := {"player": player, "pod": shell.pod, "core": shell.core, "class": "runner_gunner"}
	hook.ctx = null
	var facts: Dictionary = hook._mecha_facts(rec, player)
	_t.check("with no spawner, reloading is false and gauge_fill 0", facts.get("reloading") == false and is_equal_approx(float(facts.get("gauge_fill", -1.0)), 0.0)
		and facts.get("idle_still") == false)
	var combat := FakeCombat.new()
	hook.ctx = {"spawner": combat}
	combat.weapon_driver.snapshot = {"reloading": true, "charge": 0.4}
	player.abilities.gauge = 0.7
	facts = hook._mecha_facts(rec, player)
	_t.check("reloading comes from the weapon's state_snapshot", facts.reloading == true)
	_t.near("gauge_fill is the fuller of a slot gauge and the weapon charge", float(facts.gauge_fill), 0.7)
	combat.weapon_driver.snapshot = {"reloading": false, "charge": 0.9}
	facts = hook._mecha_facts(rec, player)
	_t.check("a fuller weapon charge wins, and reloading clears", facts.reloading == false and is_equal_approx(float(facts.gauge_fill), 0.9))
	combat.weapon_driver = WeaponDriver.new()
	player.abilities.gauge = 0.0
	facts = hook._mecha_facts(rec, player)
	_t.check("the real WeaponDriver's snapshot reads idle: not reloading, no charge", facts.reloading == false and is_equal_approx(float(facts.gauge_fill), 0.0))
	rec["still_s"] = Mecha.IDLE_STILL_S
	_t.check("idle_still is true from 1.5 s still", hook._mecha_facts(rec, player).idle_still == true)
	hook.ctx = null
	player.free()


# --- Sable --------------------------------------------------------------------------------------------

func _sable(hook: Node) -> void:
	var ball := Node3D.new()
	root.add_child(ball)
	var shell: Dictionary = hook.fit_shell_into(ball, "pylon_engineer", "", 1, {})
	if not _t.check("shell_sable fits", not shell.is_empty()):
		for i in 2:
			_t.check("sable skipped", false)
		ball.free()
		return
	var motion = Mecha.new(shell.pod, shell.core, "pylon_engineer", _table_rows("sable"))
	_t.check("every Sable row resolves on the fitted shell", motion.skip_lines.is_empty(), "%d line(s)" % motion.skip_lines.size())
	var lever: Node3D = shell.pod.find_child("Control_GaugeLever", true, false)
	var rest := lever.rotation_degrees.x
	_run_for(motion, 1.0, {"gauge_fill": 0.5})
	var half := lever.rotation_degrees.x - rest
	_run_for(motion, 1.0, {"gauge_fill": 1.0})
	var full := lever.rotation_degrees.x - rest
	_run_for(motion, 1.0, {"gauge_fill": 0.0})
	_t.check("the gauge lever follows the charge: half way at half, 35 degrees full, home on release",
		absf(half - 17.5) < 0.2 and absf(full - 35.0) < 0.2 and absf(lever.rotation_degrees.x - rest) < 0.01, "half %.2f full %.2f" % [half, full])
	ball.free()


# --- skips -----------------------------------------------------------------------------------------

func _skips() -> void:
	var ball := Node3D.new()
	var pod := Node3D.new()
	pod.name = "Pod"
	ball.add_child(pod)
	var core := Node3D.new()
	core.name = "Core"
	ball.add_child(core)
	var holder := Node3D.new()
	holder.name = "Gun"
	pod.add_child(holder)
	var skel := Skeleton3D.new()
	holder.add_child(skel)
	skel.add_bone("barrel")
	skel.set_bone_rest(0, Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.1, 0.2, 0.3)))
	skel.reset_bone_poses()
	root.add_child(ball)
	var rows := [
		{"node": "Gun", "bone": "nope", "fact": "shot_fired", "motion": "throw", "start": {"deg": 10.0}},
		{"node": "Gun", "bone": "nope", "fact": "meter_fill", "motion": "turn", "start": {"deg": 10.0}},
		{"node": "Gun", "bone": "barrel", "fact": "meter_fill", "motion": "show", "start": {}},
		{"node": "Gun", "bone": "barrel", "fact": "gauge_fill", "motion": "slide", "start": {"axis": "z", "m": 0.1, "rate": 1000.0}},
	]
	var motion = Mecha.new(pod, core, "runner_gunner", rows)
	# The lines carry the harness's skip token, so they are compared, never printed.
	var token := "S" + "KIP"
	_t.check("a missing bone skips once, a node-only motion on a bone skips once", motion.skip_lines
		== [token + " bone Gun nope", token + " machinery Gun barrel: motion 'show' does not move a bone"], "%d line(s)" % motion.skip_lines.size())
	_run_for(motion, 0.2, {"meter_fill": 1.0, "gauge_fill": 1.0})
	var rest := skel.get_bone_rest(0)
	var want := rest.origin + rest.basis * Vector3(0.0, 0.0, 0.1)
	_t.check("a bone slides in its own rest frame, from its rest pose", skel.get_bone_pose_position(0).is_equal_approx(want)
		and skel.get_bone_pose_rotation(0).is_equal_approx(rest.basis.get_rotation_quaternion()), "%s want %s" % [skel.get_bone_pose_position(0), want])
	skel.free()
	_run_for(motion, 0.1, {"gauge_fill": 0.0})
	_t.check("a freed skeleton's rows stop without an error", motion._rows.size() == 1 and motion.skip_lines.size() == 2)
	ball.free()


# --- helpers ------------------------------------------------------------------------------------------

func _run_for(motion, seconds: float, facts := {}) -> void:
	for i in roundi(seconds / DT):
		motion.step(DT, facts)


func _hero_for(hook: Node, rec: Dictionary, player, seconds: float) -> void:
	for i in roundi(seconds / DT):
		hook._step_mecha(rec, player, DT)


static func _table_rows(pilot: String) -> Array:
	var table = JSON.parse_string(FileAccess.get_file_as_string("res://src/presentation/clips/%s.json" % pilot))
	return Array(table.get("machinery", [])) if table is Dictionary else []


# A bone's pose offset from its rest, in its own rest frame: degrees (YXZ Euler) and metres.
static func _rot(skel: Skeleton3D, bone: String) -> Vector3:
	var i := skel.find_bone(bone)
	var off := skel.get_bone_rest(i).basis.get_rotation_quaternion().inverse() * skel.get_bone_pose_rotation(i)
	return off.get_euler() * (180.0 / PI)


static func _pos(skel: Skeleton3D, bone: String) -> Vector3:
	var i := skel.find_bone(bone)
	var rest := skel.get_bone_rest(i)
	return rest.basis.orthonormalized().inverse() * (skel.get_bone_pose_position(i) - rest.origin)


# The turn about the bone's own Y (the bore), degrees: where its +Z lands in the rest frame.
static func _about_y(skel: Skeleton3D, bone: String) -> float:
	var i := skel.find_bone(bone)
	var off := skel.get_bone_rest(i).basis.get_rotation_quaternion().inverse() * skel.get_bone_pose_rotation(i)
	var up := off * Vector3(0, 0, 1)
	return rad_to_deg(atan2(up.x, up.z))


# Where the bone's bore (+Y) points in its rest frame after its pose.
static func _bore(skel: Skeleton3D, bone: String) -> Vector3:
	var i := skel.find_bone(bone)
	var off := skel.get_bone_rest(i).basis.get_rotation_quaternion().inverse() * skel.get_bone_pose_rotation(i)
	return off * Vector3(0, 1, 0)


# The bone's world position (shell space; the ball sits at the origin): x right, y up.
static func _bone_global(skel: Skeleton3D, bone: String) -> Vector3:
	return (skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone))).origin
