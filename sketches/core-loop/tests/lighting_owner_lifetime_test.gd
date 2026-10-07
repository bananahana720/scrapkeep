extends SceneTree

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("lighting_owner_lifetime_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var first = await Probe.boot(self)
	var second = await Probe.boot(self)
	if not _t.check("both independent games booted", first.flow != null and second.flow != null):
		first.free()
		second.free()
		quit(_t.verdict())
		return
	var baseline := Probe.lighting(second)
	first.flow.enter_stage(5, Vector3.ZERO, false)
	Harness.enter_world(second, 2)
	var pit := Probe.lighting(second)
	_t.eq("two environments have independent lighting owners", Preset._lighting.size(), 2)
	first.free()
	Probe.check_lighting(_t, "disposing Highdraft leaves the other game's pit intact", second, pit)
	second.set_quality(1)
	Probe.check_lighting(_t, "remaining pit survives preset synchronization", second, pit)
	Harness.module(second, 2).exit_arena()
	Probe.check_lighting(_t, "remaining pit exit restores its own world", second, baseline)
	_t.check("arena exit releases the final lighting owner", Preset._lighting.is_empty())
	second.flow.enter_stage(5, Vector3.ZERO, false)
	Harness.enter_world(second, 3)
	_t.eq("Mind and Highdraft share one environment baseline", Preset._lighting.size(), 1)
	second.free()
	_t.check("disposing an active Mind game releases every lighting owner", Preset._lighting.is_empty())
	_t.check("disposing both games releases dressing registrations", Preset._dressing_hosts.is_empty())
	quit(_t.verdict())
