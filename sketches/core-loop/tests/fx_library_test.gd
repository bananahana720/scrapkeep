extends SceneTree

# W12 VX-FX: the one effect table. Headless, the dummy rendering server simulates no
# particles (a one-shot drops `emitting` on its first processed frame and never emits
# `finished`; probe 2026-10-09), so this test pins configuration and the synchronous
# `emitting` flag right after restart(), and recycling is round-robin, never on `finished`.
const T := preload("res://tests/support/t.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")

var t := T.new("fx_library_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for kind in EventKinds.JUICE:
		for variant in ["", "crit", "low"]:
			for id in FxLibrary.effects(kind, variant):
				t.check("%s %s fx names a spec: %s" % [kind, variant, id], FxLibrary.SPECS.has(id))
	for id in FxLibrary.SPECS:
		var s: Dictionary = FxLibrary.SPECS[id]
		var e := FxLibrary.build(id)
		root.add_child(e)
		var pm := e.process_material as ParticleProcessMaterial
		t.check("%s built from its spec" % id, e.amount == int(s["max"]) and is_equal_approx(e.lifetime, s["life"])
			and is_equal_approx(pm.gravity.y, float(s["gravity"])) and is_equal_approx(pm.spread, s["spread"]))
		t.check("%s fixed seed, no light" % id, e.use_fixed_seed and e.seed == FxLibrary.SEED
			and e.find_children("*", "Light3D", true, false).is_empty())
		t.check("%s one-shot unless it follows the ball or persists" % id, e.one_shot == (s["attach"] == "world"))
		t.check("%s shares its look material" % id, FxLibrary.material_of(e) == FxLibrary._material(id))
		FxLibrary.fire(e, id, "enemy_struck", 4, Vector3(1, 2, 3))
		t.check("%s emitting right after restart" % id, e.emitting and e.global_position.is_equal_approx(Vector3(1, 2, 3)))
		e.free()
	t.check("ceiling at most the pinned 800 (FX-01: the kill's body shards, 3 x 16; was 752 after FX-FIX's latch halo, ember pool, wisp; was 648)", FxLibrary.ceiling() <= FxLibrary.CEILING and FxLibrary.CEILING == 800, str(FxLibrary.ceiling()))
	var struck := FxLibrary.effects("enemy_struck")
	var crit := FxLibrary.effects("enemy_struck", "crit")
	t.check("a crit differs in count and size, not only tint", crit["crit_core"] > struck["spark_core"]
		and FxLibrary.SPECS["crit_core"]["size"].z > FxLibrary.SPECS["spark_core"]["size"].z)
	var row := EventKinds.juice("enemy_struck")
	t.check("one home for sparks: no CPU spark counts left", not row.has("sparks") and not row["crit"].has("sparks"))
	# FX-FIX: the latch is a ring that closes on the bite, a halo, and a pulse down the cable.
	var latch := FxLibrary.effects("harpoon_bit")
	var ring: Dictionary = FxLibrary.spec("latch_ring")
	var closes: float = float(ring["ring_m"]) / absf(float(ring["radial"][1]))
	t.check("latch ring spec in the row and closes within 0.2 s (15 ticks at 90)", latch.has("latch_ring") and closes <= 0.2 and ring["blend"] == "mix", str(closes))
	t.check("latch halo is additive on the same ring", latch.has("latch_halo") and FxLibrary.spec("latch_halo")["blend"] == "add"
		and FxLibrary.spec("latch_halo")["ring_m"] == ring["ring_m"])
	var pulse: Dictionary = FxLibrary.spec("latch_pulse")
	t.check("latch pulse covers a metre of cable in about 9 ticks", pulse["forward"] and float(pulse["speed"][1]) * 9.0 / 90.0 >= 0.9 and float(pulse["life"]) <= 0.15)
	# FX-FIX: a spent cache reads at range.
	var ember: Dictionary = FxLibrary.spec("cache_ember")
	t.check("ember holds 24 live particles and its row asks for them", int(ember["max"]) >= 24 and int(FxLibrary.effects("cache_spent")["cache_ember"]) >= 24 and ember["blend"] == "add")
	var warm_ember := FxLibrary.build("cache_ember")
	var warm_wisp := FxLibrary.build("cache_wisp")
	t.check("ember and wisp start warm: a full cloud at once, not a trickle", warm_ember.preprocess >= 1.0 and warm_wisp.preprocess >= 2.0)
	warm_ember.free()
	warm_wisp.free()
	t.check("ember has a charcoal smoke wisp (sandstone vanishes on the sand)", FxLibrary.effects("cache_spent").has("cache_wisp") and FxLibrary.spec("cache_wisp")["colour"] == "CHARCOAL")
	# FX-FIX: the net catch puff is reachable from the row highdraft_fx reads.
	t.check("net_dust is reachable from the net_caught row", FxLibrary.effects("net_caught").has("net_dust") and FxLibrary.spec("net_dust")["owner"] == "highdraft")
	# FX look pass: matter and light draw as their own shapes, never a flat ball or box.
	var looks := {}
	for id in FxLibrary.SPECS:
		looks[FxLibrary.look(id)] = looks.get(FxLibrary.look(id), []) + [id]
		var e := FxLibrary.build(id)
		t.check("%s draws on its look's mesh, not a primitive ball or box" % id,
			not (e.draw_pass_1 is SphereMesh) and not (e.draw_pass_1 is BoxMesh))
		e.free()
	t.check("every look in use: puff, glow, streak, chunk, bead, star", looks.size() == 6, str(looks.keys()))
	# FX-02: hits and stuns read on sand. The solid hit and crit sparks wear a charcoal rim, the
	# additive ones stay pure light, and a stun is a ring of solid inked stars twice the old glow's size.
	t.check("a solid spark wears an ink rim", FxLibrary.look("spark_core") == "streak"
		and FxLibrary.look_material("streak", "mix").shader.code.contains("ALBEDO = mix(ALBEDO, ink_colour,"))
	t.check("an additive spark stays pure light", not FxLibrary.look_material("streak", "add").shader.code.contains("ALBEDO = mix(ALBEDO, ink_colour,"))
	t.check("the ink is the palette's charcoal, handed over as a colour so it converts to linear light",
		FxLibrary.look_material("star").get_shader_parameter("ink_colour") == Palette.CHARCOAL
		and FxLibrary.look_material("star").shader.code.contains("uniform vec3 ink_colour : source_color"))
	t.check("the stun halo is solid inked stars", looks["star"] == ["daze_halo"] and FxLibrary.spec("daze_halo")["blend"] == "mix"
		and FxLibrary.look_material("star").shader.code.contains("mix(fill, ink_colour,"))
	t.check("the stun stars are twice the old glow's size", is_equal_approx(float(FxLibrary.spec("daze_halo")["size"]), 0.6))
	t.check("ink stars never flash", FxLibrary.HEAT["star"] == 0.0)
	t.check("dust and steam are puffs", "slam_dust" in looks["puff"] and "steam_puff" in looks["puff"])
	t.check("debris is lit chunks", "crack_debris" in looks["chunk"] and not FxLibrary.look_material("chunk").shader.code.contains("unshaded"))
	var spark := FxLibrary.build("spark_halo")
	root.add_child(spark)
	FlashGuard.on = false
	FxLibrary.fire(spark, "spark_halo", "enemy_struck", 4, Vector3.ZERO)
	var hot_off: float = spark.get_instance_shader_parameter("heat")
	FlashGuard.on = true
	FxLibrary.fire(spark, "spark_halo", "enemy_struck", 4, Vector3.ZERO)
	var hot_on: float = spark.get_instance_shader_parameter("heat")
	FlashGuard.on = false
	t.check("a spark starts hot, and reduce flashes cuts its push toward white", hot_off > 0.0 and hot_on < hot_off * 0.5, "%s %s" % [hot_off, hot_on])
	t.check("a fired emitter joins the heat group, so the toggle reaches it while it runs", spark.is_in_group(FxLibrary.HEAT_GROUP))
	FlashGuard.on = true
	FxLibrary.set_heat(spark)
	t.check("re-reading heat from the emitter's own look follows the toggle", is_equal_approx(spark.get_instance_shader_parameter("heat"), hot_on))
	FlashGuard.on = false
	spark.free()
	var holder := Node3D.new()
	root.add_child(holder)
	holder.global_position = Vector3(4.0, 1.0, -2.0)
	holder.scale = Vector3(1.0, 1.0, 0.15)
	var iso := FxLibrary.burst(holder, "steam_puff", Vector3(10.0, 2.0, -5.0), 6, Color.TRANSPARENT, Vector3.ZERO, true)
	t.check("isolated burst keeps unit scale and exact world position under a scaled parent",
		iso != null and iso.top_level and iso.global_position.is_equal_approx(Vector3(10.0, 2.0, -5.0))
		and iso.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE))
	holder.free()
	quit(t.verdict())
