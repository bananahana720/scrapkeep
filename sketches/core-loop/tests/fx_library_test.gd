extends SceneTree

# W12 VX-FX: the one effect table. Headless, the dummy rendering server simulates no
# particles (a one-shot drops `emitting` on its first processed frame and never emits
# `finished`; probe 2026-10-09), so this test pins configuration and the synchronous
# `emitting` flag right after restart(), and recycling is round-robin, never on `finished`.
const T := preload("res://tests/support/t.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

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
		t.check("%s shares its blend material" % id, e.draw_pass_1.material == FxLibrary._material(s["blend"]))
		FxLibrary.fire(e, id, "enemy_struck", 4, Vector3(1, 2, 3))
		t.check("%s emitting right after restart" % id, e.emitting and e.global_position.is_equal_approx(Vector3(1, 2, 3)))
		e.free()
	t.check("ceiling at most the pinned 648", FxLibrary.ceiling() <= FxLibrary.CEILING and FxLibrary.CEILING == 648, str(FxLibrary.ceiling()))
	var struck := FxLibrary.effects("enemy_struck")
	var crit := FxLibrary.effects("enemy_struck", "crit")
	t.check("a crit differs in count and size, not only tint", crit["crit_core"] > struck["spark_core"]
		and FxLibrary.SPECS["crit_core"]["size"].z > FxLibrary.SPECS["spark_core"]["size"].z)
	var row := EventKinds.juice("enemy_struck")
	t.check("one home for sparks: no CPU spark counts left", not row.has("sparks") and not row["crit"].has("sparks"))
	quit(t.verdict())
