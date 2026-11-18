extends SceneTree

# Run grain and the ball's wake (WORLD-FX.md, Specs.GRAIN, world_fx_grain.gd; unit 14, principle 21):
# a run's seed rolls each effect's dials, the same seed gives the same look, another seed a different
# one, no roll ever raises a particle count, and re-rolling a kept emitter never compounds. The wake
# throws spray only while the ball rolls through water, splashes once on a fast entry, and rests on
# menus. Headless simulates no particles, so this pins configuration and the emitting flags.
const T := preload("res://tests/support/t.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const Grain := preload("res://src/presentation/world_fx/world_fx_grain.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const Anchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const Natural := preload("res://src/world/events/natural.gd")

const SEEDS := 24

var t := T.new("world_fx_grain_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_rolls()
	_apply()
	await _runtime()
	await _wake()
	await _foam()
	Grain.run_seed = 0
	quit(t.verdict())


func _rolls() -> void:
	for id in Specs.GRAIN:
		t.check("grain row %s names a spec" % id, Specs.SPECS.has(id))
		for dial in Specs.GRAIN[id]:
			t.check("grain row %s dial %s is known" % [id, dial], ["amount", "size", "speed", "wind_deg", "tint", "pulse"].has(dial))
		if Specs.GRAIN[id].has("pulse"):
			t.check("grain row %s pulses a pulsed spec" % id, Specs.SPECS[id].has("pulse"))
		if Specs.GRAIN[id].has("tint"):
			t.check("grain row %s tint colour resolves and is not reserved" % id, not Specs.RESERVED.has(Specs.GRAIN[id]["tint"][0])
				and Specs.colour(String(Specs.GRAIN[id]["tint"][0])) != Color())
	t.eq("seed 0 is no grain", Grain.roll(0, "spill_mist")["amount"], 1.0)
	t.eq("seed 0 keeps the kit's particle seed", Grain.roll(0, "spill_mist")["seed"], Kit.SEED)
	t.eq("ceremony effects never change between runs", Grain.roll(77, "summary_win_confetti")["size"], 1.0)
	t.eq("the same seed rolls the same dials", Grain.roll(4242, "spill_mist"), Grain.roll(4242, "spill_mist"))
	t.check("another seed rolls other dials", Grain.roll(4242, "spill_mist") != Grain.roll(4243, "spill_mist"))
	t.check("two specs on one seed roll apart", Grain.roll(4242, "spill_mist")["amount"] != Grain.roll(4242, "spill_falls_mist")["amount"])
	var over := []
	var outside := []
	for k in SEEDS:
		var seed := hash("grain-%d" % k)
		for id in Specs.SPECS:
			var d := Grain.roll(seed, id)
			if d["amount"] > 1.0 or d["amount"] < 0.0:
				over.append(id)
			var row: Dictionary = Specs.GRAIN.get(id, Specs.GRAIN_DEFAULT)
			for dial in ["size", "speed", "pulse"]:
				if row.has(dial) and float(Specs.SPECS[id].get("ink", 0.0)) == 0.0 and (d[dial] < float(row[dial][0]) - 0.0001 or d[dial] > float(row[dial][1]) + 0.0001):
					outside.append("%s %s %s" % [id, dial, d[dial]])
	t.check("no roll raises a particle count over %d seeds" % SEEDS, over.is_empty(), str(over.slice(0, 4)))
	t.check("every dial lands inside its row's range", outside.is_empty(), str(outside.slice(0, 4)))
	var looks := {}
	for k in SEEDS:
		var d := Grain.roll(hash("look-%d" % k), "spill_mist")
		looks["%.2f/%.2f/%.2f" % [d["amount"], d["size"], d["yaw"]]] = true
	t.check("the Spillway mist looks different run to run", looks.size() >= SEEDS - 2, "%d distinct of %d" % [looks.size(), SEEDS])


func _apply() -> void:
	var p := Kit.build("lm_penstock_vent")
	root.add_child(p)
	var first := Grain.apply(p, 1001)
	var pm := p.process_material as ParticleProcessMaterial
	var scale := pm.scale_max
	var dir := pm.direction
	Grain.apply(p, 2002)
	Grain.apply(p, 1001)
	t.check("re-rolling a kept emitter never compounds", is_equal_approx(pm.scale_max, scale) and pm.direction.is_equal_approx(dir))
	t.eq("the emitter takes its run's particle seed", p.seed, first["seed"])
	t.check("wind turns the emitter's direction, not its tilt", is_equal_approx(pm.direction.y, (Specs.SPECS["lm_penstock_vent"]["dir"] as Vector3).y))
	var beat := Grain.pulse(p)
	t.check("the vent breathes at its run's pace", is_equal_approx(beat[0], float(Specs.SPECS["lm_penstock_vent"]["pulse"][0]) * first["pulse"]))
	t.check("grain share never exceeds the preset share", Grain.share(p, false, false) <= Kit.share(Specs.SPECS["lm_penstock_vent"], false, false)
		and Grain.share(p, true, true) <= Kit.share(Specs.SPECS["lm_penstock_vent"], true, true))
	Grain.apply(p, 0)
	t.check("seed 0 restores the authored spec", is_equal_approx(pm.scale_max, float(Specs.SPECS["lm_penstock_vent"]["size"][1])) and p.seed == Kit.SEED)
	p.free()


func _runtime() -> void:
	Grain.run_seed = 0
	var stage := Node3D.new()
	root.add_child(stage)
	var fx := WorldFx.install(stage, 1)
	await process_frame
	var anchor := Anchor.make("spill_powerhouse")
	stage.add_child(anchor)
	await process_frame
	t.eq("before a run the air takes no grain", fx.ambient[0].seed, Kit.SEED)
	fx.set_run_seed(555)
	var mist: GPUParticles3D = fx.ambient[0]
	t.eq("a run's seed reaches the air", mist.seed, Grain.roll(555, "spill_mist")["seed"])
	t.eq("and the dressing's anchors", anchor.emitters[0].seed, Grain.roll(555, String(anchor.emitters[0].get_meta("world_fx")))["seed"])
	t.check("the air's share is its run's amount", is_equal_approx(mist.amount_ratio, Grain.share(mist, fx.low, fx.reduced_motion)))
	var late := Anchor.make("spill_powerhouse")
	stage.add_child(late)
	await process_frame
	t.eq("an anchor placed mid-run takes the live run's grain", late.emitters[0].seed, anchor.emitters[0].seed)
	fx.set_run_seed(556)
	t.check("the next run looks different", mist.seed != Grain.roll(555, "spill_mist")["seed"])
	fx.set_run_seed(555)
	t.eq("the same seed again gives the same look", mist.seed, Grain.roll(555, "spill_mist")["seed"])
	stage.queue_free()
	await process_frame


func _wake() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var fx := WorldFx.install(stage, 1)
	await process_frame
	t.eq("the wake is the Spillway wake set", fx.wake.map(func(p): return p.get_meta("world_fx")), Specs.SETS[WorldFx.WAKE_SET])
	fx.steer_wake(Vector3(0, 1, 0), NAN, Vector3(12, 0, 0))
	t.check("dry ground throws no spray", fx.wake.all(func(p): return not p.emitting) and not fx.wet)
	fx.world = 2
	fx.steer_wake(Vector3(0, 0.9, 0), 0.0, Vector3(12, 0, 0))
	t.check("the Dig's water throws no Spillway wake", fx.wake.all(func(p): return not p.emitting) and not fx.wet)
	fx.world = 1
	fx.steer_wake(Vector3(0, 0.9, 0), 0.0, Vector3(12, 0, 0))
	t.check("a fast roll into water splashes", fx._bursts.has("spill_splash_crown") and fx._bursts["spill_splash_crown"].any(func(p): return p.emitting))
	t.check("rolling through water throws the wake", fx.wet and fx.wake.all(func(p): return p.emitting))
	var spray: GPUParticles3D = fx.wake[0]
	t.check("the spray sits at the waterline under the ball", spray.global_position.is_equal_approx(Vector3(0, 0.1, 0)))
	t.check("the spray throws back off the ball", (spray.process_material as ParticleProcessMaterial).direction.x < 0.0)
	var fast := spray.amount_ratio
	fx.steer_wake(Vector3(0, 0.9, 0), 0.0, Vector3(5, 0, 0))
	t.check("a slower roll throws less", spray.amount_ratio < fast and spray.emitting)
	fx.steer_wake(Vector3(0, 0.9, 0), 0.0, Vector3(1, 0, 0))
	t.check("rolling slowly in water throws none", not spray.emitting and fx.wet)
	for p in fx._bursts["spill_splash_crown"]:
		p.emitting = false
	fx.steer_wake(Vector3(0, 0.9, 0), 0.0, Vector3(14, 0, 0))
	t.check("staying in the water does not splash again", fx._bursts["spill_splash_crown"].all(func(p): return not p.emitting))
	fx.steer_wake(Vector3(0, 6.0, 0), 0.0, Vector3(14, 0, 0))
	t.check("a jump over water leaves it", not fx.wet and not spray.emitting)
	fx.set_quality(false, true)
	fx.steer_wake(Vector3(0, 0.9, 0), 0.0, Vector3(16, 0, 0))
	t.check("reduced motion halves the wake", is_equal_approx(spray.amount_ratio, Grain.share(spray, false, true)) and Grain.share(spray, false, true) <= 0.5)
	fx.set_resting(true)
	t.check("a menu rests the wake", fx.wake.all(func(p): return not p.emitting) and not fx.wet)
	fx._splash_cool = 0.0
	for p in fx._bursts["spill_splash_crown"]:
		p.emitting = false
	fx.steer_wake(Vector3(0, 0.9, 0), 0.0, Vector3(16, 0, 0))
	t.check("and it stays rested, no splash either", fx.wake.all(func(p): return not p.emitting)
		and fx._bursts["spill_splash_crown"].all(func(p): return not p.emitting))
	fx.set_run_seed(77)
	fx._on_flow_changed("title")
	t.eq("the title wears the authored look", Grain.run_seed, 0)
	stage.queue_free()
	await process_frame


class FakeSurface:
	# A wash falling 0.1 m per metre east, with nothing west of x = -60.
	func height(p: Vector2) -> float:
		return -INF if p.x < -60.0 else -0.1 * p.x


# Flood foam (natural.gd): pieces along the footprint's long axis, each on its own surface height,
# fitted to its piece, thick while the water climbs, hidden over no surface and on drained water.
func _foam() -> void:
	var natural: Node3D = Natural.new()
	root.add_child(natural)
	var holder := _FakeWater.new()
	holder.surface = FakeSurface.new()
	natural.add_child(holder)
	var pieces: Array = natural._foam(holder, {"half": Vector2(50.0, 8.0), "yaw": 0.0, "at": Vector3(0, 0, 0)})
	t.eq("a 100 m flood foams in four pieces", pieces.size(), Natural.FOAM_PIECES)
	t.check("each piece stands on its own surface height", pieces.all(func(a): return is_equal_approx(a.position.y, -0.1 * a.position.x + 1.2 + 0.05)))
	t.check("the pieces run along the long axis", pieces.all(func(a): return is_zero_approx(a.position.z)) and pieces[0].position.x < pieces[3].position.x)
	var box: Vector3 = (pieces[0].emitters[0].process_material as ParticleProcessMaterial).emission_box_extents
	t.check("each piece's foam covers its own stretch of water", is_equal_approx(box.x, 12.5 * 0.9) and is_equal_approx(box.z, 8.0 * 0.85), str(box))
	Natural._ride_foam({"water": holder, "foam": pieces}, 1.0)
	var thick: float = pieces[1].emitters[0].amount_ratio
	Natural._ride_foam({"water": holder, "foam": pieces}, 0.0)
	t.check("foam calms once the water is up", pieces[1].emitters[0].amount_ratio < thick)
	var west: Array = natural._foam(holder, {"half": Vector2(90.0, 8.0), "yaw": 0.0, "at": Vector3(0, 0, 0)})
	t.check("a piece over no surface hides", not west[0].visible and west[3].visible)
	holder.depth_m = 0.0
	Natural._ride_foam({"water": holder, "foam": pieces}, 0.0)
	t.check("drained water carries no foam", pieces.all(func(a): return not a.visible))
	var turned: Array = natural._foam(holder, {"half": Vector2(50.0, 8.0), "yaw": PI / 2.0, "at": Vector3(0, 0, 0)})
	t.check("a turned footprint turns its foam", absf(turned[0].position.z) > 30.0 and absf(turned[0].position.x) < 0.01)
	natural.free()
	await process_frame


class _FakeWater extends Node3D:
	var surface
	var depth_m := 1.2
