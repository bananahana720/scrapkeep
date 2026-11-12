extends SceneTree

const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Palette := preload("res://src/core/palette.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const T := preload("res://tests/support/t.gd")

# FX-05 (effects critique E5): a hostile mark lands. When a hostile ground mark goes live it
# leaves an ink crack ring and a dust kick at its edge, drawn from the committed descriptor,
# and the attacker's body goes HAZARD for STRIKE_FRAMES physics frames on its strike.
# - INSTANT ring, LANE and PROJECTILE landings each leave one Flash with crack ink; the cracks
#   start on the committed edge (the radius contains() flips at, or a lane's rails and cap).
# - A wave, a harmless field, the player's own mark and an air-only net leave no crack (the
#   net keeps its solid fill flash, as before).
# - The same descriptor draws the same cracks; an open gap in a ring gets none.
# - Dust leaves the edge and is thrown DUST_KICK out; Reduced motion keeps it at the edge.
# - The Flash frees itself once its longest part is done.
# - The strike tint: HAZARD on the body for STRIKE_FRAMES frames, then the rest look; a hit
#   flash wins; Reduce flashes keeps the tint at its information share.
# Evidence limit: headless geometry and material state, not a rendered still or the feel.

const EPS := 0.02

class FlatGround:
	func height(_x: float, _z: float) -> float:
		return 0.0

var t := T.new("landing_mark_test")
var _world: Node3D
var _ground := FlatGround.new()


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_run.call_deferred()


func _run() -> void:
	_check_kinds()
	_check_edges()
	_check_dust()
	await _check_life()
	_check_strike()
	quit(t.verdict())


func _land(node: Node3D) -> Node:
	var before := _world.get_child_count()
	node.set_progress(1.0)
	return _world.get_child(_world.get_child_count() - 1) if _world.get_child_count() == before + 1 else null


func _crack_verts(flash: Node) -> int:
	return flash.vertex_count("crack") if flash != null else 0


func _check_kinds() -> void:
	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 0.0), 6.0)
	var ring_flash := _land(ring)
	t.check("instant landing", ring_flash != null and _crack_verts(ring_flash) > 0 and ring_flash.vertex_count("fill") > 0,
		"one Flash with %d crack and %d fill vertices" % [_crack_verts(ring_flash), ring_flash.vertex_count("fill") if ring_flash else 0])
	var lane: Node3D = Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(40.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), 12.0, 3.0)
	var lane_flash := _land(lane)
	t.check("lane landing", lane_flash != null and _crack_verts(lane_flash) > 0 and lane_flash.vertex_count("fill") == 0,
		"one Flash, %d crack vertices, no solid fill" % _crack_verts(lane_flash))
	var shell: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(80.0, 0.0, 0.0), 3.0)
	var shell_flash := _land(shell)
	t.check("shell landing", shell_flash != null and _crack_verts(shell_flash) > 0, "%d crack vertices" % _crack_verts(shell_flash))

	var wave: Node3D = Telegraph.wave(_world, _ground, Vector3(120.0, 0.0, 0.0), 8.0, 6.0, 1.0)
	t.check("wave leaves none", _land(wave) == null, "a wave's running front is its landing")
	var field: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(160.0, 0.0, 0.0), 6.0, 8.0, Palette.SAND)
	t.check("harmless leaves none", _land(field) == null, "a bone field")
	var mine: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(200.0, 0.0, 0.0), 3.0, 3.5, Palette.AMBER)
	t.check("own leaves none", _land(mine) == null, "the player's own amber ring")
	var net: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(240.0, 0.0, 0.0), 6.0)
	net.air_only = true
	var net_flash := _land(net)
	t.check("air net keeps fill only", net_flash != null and _crack_verts(net_flash) == 0 and net_flash.vertex_count("fill") > 0,
		"an air-only net: solid flash, no floor crack")


func _check_edges() -> void:
	var d := {"type": Threat.Type.INSTANT, "tone": Palette.HAZARD, "centre": Vector3(3.0, 0.0, -2.0), "form": "radial",
		"r_in": 0.0, "r_out": 6.0, "a0": 0.0, "a1": TAU, "live": true, "progress": 1.0, "reach": 2.0}
	var marks := Threat.landing(d)
	var crack: Dictionary = marks[0]
	var puffs: Array = marks[1]["puffs"]
	var worst := 0.0
	for p in puffs:
		worst = maxf(worst, absf((p[0] - d["centre"]).length() - 6.0))
	t.check("cracks on the edge", puffs.size() >= Threat.CRACK_MIN and puffs.size() <= Threat.CRACK_MAX and worst < EPS,
		"%d cracks, the furthest %.3f m off the 6 m edge" % [puffs.size(), worst])
	t.check("same every time", Threat.landing(d)[0]["tris"] == crack["tris"], "two landings of one descriptor draw the same ink")
	var outside := 0
	for v in crack["tris"]:
		if Vector2(v.x - 3.0, v.z + 2.0).length() > 6.0 + Threat.CRACK_LONG * 1.4:
			outside += 1
	t.check("cracks stay near", outside == 0, "%d ink vertices further out than the longest crack" % outside)

	var open := []
	for i in Threat.SEGMENTS:
		open.append(i < Threat.SEGMENTS / 2)
	var gapped := d.duplicate()
	gapped["open"] = open
	var in_gap := 0
	var gapped_puffs: Array = Threat.landing(gapped)[1]["puffs"]
	for p in gapped_puffs:
		var a := wrapf(atan2(p[0].z + 2.0, p[0].x - 3.0), 0.0, TAU)
		if a < PI - 0.01:
			in_gap += 1
	t.check("open gap stays clean", gapped_puffs.size() > 0 and in_gap == 0, "%d of %d cracks in the open half" % [in_gap, gapped_puffs.size()])

	var lane := {"type": Threat.Type.LANE, "tone": Palette.HAZARD, "centre": Vector3.ZERO, "form": "lane", "dir": Vector3(1.0, 0.0, 0.0),
		"back": 0.0, "length": 10.0, "half_width": 1.5, "live": true, "progress": 1.0, "reach": 2.0}
	var off := 0
	for p in Threat.landing(lane)[1]["puffs"]:
		var at: Vector3 = p[0]
		var on_rail := absf(absf(at.z) - 1.5) < EPS and at.x >= -EPS and at.x <= 10.0 + EPS
		var on_cap := absf(at.x - 10.0) < EPS and absf(at.z) <= 1.5 + EPS
		if not (on_rail or on_cap):
			off += 1
	t.check("lane cracks on rails and cap", off == 0, "%d lane cracks off the rails and far cap" % off)


func _check_dust() -> void:
	var puffs := [[Vector3(6.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]]
	var start: Dictionary = Threat.dust_at(puffs, 0.0)
	var late: Dictionary = Threat.dust_at(puffs, Threat.DUST_SECONDS)
	var x0 := _far_x(start["tris"])
	var x1 := _far_x(late["tris"])
	t.check("dust kicks out", x0 < 6.0 + Threat.DUST_SIZE + EPS and x1 > 6.0 + Threat.DUST_KICK and is_zero_approx(float(late["alpha"])),
		"far edge %.2f m at the landing, %.2f m at the end, faded to %.2f" % [x0, x1, late["alpha"]])
	EnemyMotion.motion_scale = 0.0
	var still := _far_x(Threat.dust_at(puffs, Threat.DUST_SECONDS)["tris"])
	EnemyMotion.motion_scale = 1.0
	t.check("reduced motion holds dust", still < 6.0 + Threat.DUST_SIZE * (1.0 + Threat.DUST_SWELL) + EPS,
		"far edge %.2f m with Reduced motion" % still)


func _far_x(tris: PackedVector3Array) -> float:
	var out := -INF
	for v in tris:
		out = maxf(out, v.x)
	return out


func _check_life() -> void:
	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 300.0), 4.0)
	var flash := _land(ring)
	var life := Threat.flash_life(true, true, true)
	t.near("flash life", life, maxf(Threat.CRACK_SECONDS, Threat.DUST_SECONDS))
	t.check("crack holds then fades", is_equal_approx(Threat.crack_alpha(0.0), Threat.CRACK_ALPHA) and is_equal_approx(Threat.crack_alpha(Threat.CRACK_HOLD), Threat.CRACK_ALPHA)
		and is_zero_approx(Threat.crack_alpha(Threat.CRACK_SECONDS)), "alpha %.2f held, %.2f at the end" % [Threat.crack_alpha(0.0), Threat.crack_alpha(Threat.CRACK_SECONDS)])
	var waited := 0.0
	while is_instance_valid(flash) and waited < life + 0.5:
		await process_frame
		waited += 1.0 / 60.0
	await process_frame
	t.check("flash frees itself", not is_instance_valid(flash), "gone after about %.2f s" % waited)


func _body() -> Node:
	var e = Enemy.new()
	e._base_color = Palette.RUST
	e._material = Palette.solid(Palette.RUST)
	_world.add_child(e)
	e._atk = {"instance": 1, "row": "E01", "phase": Enemy.PHASE_WINDUP, "managed": false, "tele": null, "geometry": {}, "progress": 1.0}
	return e


func _check_strike() -> void:
	var dt := 1.0 / 90.0
	var e = _body()
	e._facts_phase(Enemy.PHASE_STRIKE)
	var lit := []
	for i in Enemy.STRIKE_FRAMES + 2:
		e._update_flash(dt)
		lit.append(e._material.albedo_color.is_equal_approx(Palette.RUST.lerp(Palette.HAZARD, Enemy.STRIKE_TINT)) and e._material.emission == Palette.HAZARD)
	var want := []
	for i in Enemy.STRIKE_FRAMES + 2:
		want.append(i < Enemy.STRIKE_FRAMES)
	t.check("strike tint", lit == want and e._material.albedo_color.is_equal_approx(Palette.RUST) and not e._material.emission_enabled,
		"HAZARD per frame %s (want %s), then the rest look" % [lit, want])
	e.free()

	var hit = _body()
	hit.flash()
	hit._facts_phase(Enemy.PHASE_STRIKE)
	hit._update_flash(dt)
	t.check("hit flash wins", hit._material.emission != Palette.HAZARD and not hit.strike_flashing(), "a body flashing from a hit keeps the hit's look")
	hit.free()

	FlashGuard.on = true
	var dim = _body()
	dim._facts_phase(Enemy.PHASE_STRIKE)
	dim._update_flash(dt)
	var want_dim := Palette.RUST.lerp(Palette.HAZARD, Enemy.STRIKE_TINT * FlashGuard.INFO_SHARE)
	t.check("reduce flashes", dim._material.albedo_color.is_equal_approx(want_dim) and dim.strike_flashing(),
		"tint %s, want %s" % [dim._material.albedo_color, want_dim])
	FlashGuard.on = false
	dim.free()
