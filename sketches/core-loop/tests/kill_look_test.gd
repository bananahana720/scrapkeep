extends SceneTree

# FX-01: a kill has its own punctuation, so it never reads as a bigger hit. The kill mark is a
# filled inked burst in the pilot's colour (kill_mark.gd), thrown with the body's shards and
# ink debris; the hit keeps its thin copper star.
# Andrew picked this look on 12 Nov 2026, with the elite's clock-out card. Headless: this pins the
# composition and the timing curve, not the pixels (tools/fx_capture.gd measures those).
const T := preload("res://tests/support/t.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const KillMark := preload("res://src/presentation/kill_mark.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Density := preload("res://src/presentation/density.gd")

var t := T.new("kill_look_test")


func _initialize() -> void:
	_run.call_deferred()


func _vfx() -> Vfx:
	var vfx := Vfx.new()
	vfx.root = Node3D.new()
	root.add_child(vfx)
	root.add_child(vfx.root)
	vfx._build_glyphs()
	vfx._build_bursts()
	vfx._build_fx()
	return vfx


func _run() -> void:
	var mark := KillMark.new()
	root.add_child(mark)
	t.check("the mark draws below every hostile warning", KillMark.RENDER_PRIORITY < Threat.LINE_UNDER_PRIORITY)
	mark.card(Vector3.ZERO)
	t.check("an elite's clock-out card stamps on its own slot", mark.spawned["card"] == 1 and mark._slots[KillMark.POOL]["t"] < 1.0
		and int(mark._slots[KillMark.POOL]["mode"]) == 1)
	t.check("the kill look has no launch switch left (Andrew picked it)", not Tuning.FLAGS.has("kill-look"))
	var peak := KillMark.shape_at(KillMark.POP, 0)
	t.check("the mark pops past full size, then settles", is_equal_approx(float(peak["scale"]), KillMark.OVERSHOOT)
		and is_equal_approx(float(KillMark.shape_at(0.999, 0)["scale"]), 1.0) and float(KillMark.shape_at(0.05, 0)["scale"]) < KillMark.OVERSHOOT)
	t.check("the mark starts hot and is cool once popped", float(KillMark.shape_at(0.0, 0)["heat"]) > 0.0 and float(peak["heat"]) == 0.0)
	FlashGuard.on = true
	t.check("Reduce flashes cools the mark's start", float(KillMark.shape_at(0.0, 0)["heat"]) < FlashGuard.whiten(KillMark.HEAT) + 0.001
		and float(KillMark.shape_at(0.0, 0)["heat"]) < KillMark.HEAT)
	FlashGuard.on = false
	t.check("Reduced motion drops the overshoot and the card's slam", is_equal_approx(float(KillMark.shape_at(KillMark.POP, 0, true)["scale"]), 1.0)
		and is_equal_approx(float(KillMark.shape_at(0.0, 1, true)["scale"]), 1.0))
	t.check("the mark holds, then fades out", float(KillMark.shape_at(0.4, 0)["alpha"]) == 1.0 and float(KillMark.shape_at(0.999, 0)["alpha"]) < 0.01)
	mark.queue_free()

	var vfx := _vfx()
	var sable: Color = ClassDef.SABLE_COLOR
	vfx.kill_look(Vector3.ZERO, 1.0, sable)
	var slot: Dictionary = vfx.kill_mark._slots[0]
	t.check("an ink kill draws the mark, not the hit star", vfx.kill_mark.spawned["burst"] == 1 and vfx.spawned.get("enemy_killed", 0) == 1
		and _live_glyphs(vfx) == 0)
	t.check("the mark wears the pilot's colour", (slot["mat"] as ShaderMaterial).get_shader_parameter("tint") == sable)
	t.check("the mark's ink is the palette's charcoal, handed over as a colour", (slot["mat"] as ShaderMaterial).get_shader_parameter("INK") == Palette.CHARCOAL)
	Density.live().force(1.0)
	vfx.kill_look(Vector3.ZERO, 1.0, sable)
	var dense: Dictionary = vfx.kill_mark._slots[1]
	t.check("a dense fight caps the mark's alpha and life like any player effect", float(dense["alpha"]) < 1.0 and float(dense["life"]) < KillMark.LIFE)
	Density.live().reset()
	FlashGuard.on = true
	vfx.kill_look(Vector3.ZERO, 1.0, sable)
	t.check("Reduce flashes keeps the information share of the mark's alpha", is_equal_approx(float(vfx.kill_mark._slots[2]["alpha"]),
		FlashGuard.info(Density.live().apply(Density.class_of_kind("enemy_killed"), 1.0, 1.0, 1.0).x)) and float(vfx.kill_mark._slots[2]["alpha"]) < 0.9)
	FlashGuard.on = false
	vfx.kill_mark.clear()
	vfx.spawned.clear()
	vfx.kill_mark.spawned = {"burst": 0, "card": 0}
	vfx.kill_look(Vector3.ZERO, 1.0, sable)
	t.check("the mark stands clear of a crit's star", float(slot["size"]) * 2.0 >= Vfx.KILL_MARK_M - 0.001 and Vfx.KILL_MARK_M > 1.6)
	t.check("a kill throws the body's shards, and the old puff is gone", vfx.spawned.get("fx_kill_shards", 0) == 1 and not Vfx.BURSTS.has("pop"))
	var debris: CPUParticles3D = vfx._bursts["debris"][0]
	t.check("kill debris is ink, never the lost-scrap colour", debris.color == Palette.CHARCOAL and debris.color != EventKinds.color("scrap_lost"))
	t.check("the shards are their own matter", FxLibrary.look("kill_shards") == "chunk" and FxLibrary.spec("kill_shards")["colour"] == "row")
	t.check("the shards are the kill row's own effect", FxLibrary.effects("enemy_killed").has("kill_shards")
		and not FxLibrary.effects("enemy_struck").has("kill_shards"))
	quit(t.verdict())


func _live_glyphs(vfx: Vfx) -> int:
	var n := 0
	for g in vfx._glyphs:
		if g["t"] < 1.0:
			n += 1
	return n
