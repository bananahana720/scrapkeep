extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Audio := preload("res://src/presentation/audio.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Harmony := preload("res://src/presentation/harmony.gd")

# v2 W5b: threat_rose, vent_charging/vent_erupted, run_started and bay_entered/bay_left
# each move one music layer (DESIGN-V2 section 11 audio rulings; SOUND-STORY section 8).
# Engine state after the bus fires, not ears.

class FakeCtx:
	extends RefCounted
	var events: Node
	var player = null
	var run = null
	var flow = null
	var spawner = null
	var calm = false

var _failures := 0


func _initialize() -> void:
	_fleet_ticks()
	_reactor_pedal()
	_class_motif()
	_lounge()
	_pedal_off_at_run_end()
	print("audio_music_layers_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# A bare Audio node, wired to a bus of its own, on the dummy driver. Not added to
# the tree: no bake, no _process, only the setters the bus fires reaching the engine.
func _rig() -> Dictionary:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Audio.new()
	audio.setup(ctx)
	var engine: MusicEngine = audio.engine
	engine.schedule_restart(0, MusicEngine.PLAY, 0)
	engine.render(1)
	return {"events": events, "engine": engine, "audio": audio}


func _fleet_ticks() -> void:
	var rig := _rig()
	var events = rig["events"]
	var engine: MusicEngine = rig["engine"]
	events.threat_rose.emit(2)
	engine.render(Harmony.BAR * 2)
	var risen := engine.fleet_ticks
	events.run_started.emit("sable")
	engine.render(Harmony.BAR * 2)
	var reset := engine.fleet_ticks
	_check("fleet ticks follow threat_rose and reset on run_started", risen == 2 and reset == 0,
		"threat_rose(2) raised fleet_ticks to %d; run_started reset it to %d" % [risen, reset])
	(rig["audio"] as Node).free()
	(rig["events"] as Node).free()


func _reactor_pedal() -> void:
	var rig := _rig()
	var events = rig["events"]
	var engine: MusicEngine = rig["engine"]
	events.vent_charging.emit(Vector3.ZERO, 2.4)
	var on := engine.reactor_pedal
	events.vent_erupted.emit(Vector3.ZERO)
	var off := engine.reactor_pedal
	_check("reactor pedal follows the vent", on and not off, "vent_charging set the pedal to %s; vent_erupted cleared it to %s" % [on, off])
	(rig["audio"] as Node).free()
	(rig["events"] as Node).free()


func _class_motif() -> void:
	var rig := _rig()
	var events = rig["events"]
	var engine: MusicEngine = rig["engine"]
	events.run_started.emit("rivet")
	_check("class motif follows run_started", engine.class_motif == "rivet", "run_started(rivet) set class_motif to '%s'" % engine.class_motif)
	(rig["audio"] as Node).free()
	(rig["events"] as Node).free()


func _lounge() -> void:
	var rig := _rig()
	var events = rig["events"]
	var engine: MusicEngine = rig["engine"]
	events.bay_entered.emit(6.0)
	engine.render(Harmony.BAR * 2)
	var entered := engine.lounge
	events.bay_left.emit(Vector3.FORWARD * 5.0)
	engine.render(Harmony.BAR * 2)
	var left := engine.lounge
	_check("lounge follows the bay", entered and not left, "bay_entered set lounge to %s; bay_left cleared it to %s" % [entered, left])
	(rig["audio"] as Node).free()
	(rig["events"] as Node).free()


func _pedal_off_at_run_end() -> void:
	var rig := _rig()
	var events = rig["events"]
	var engine: MusicEngine = rig["engine"]
	events.vent_charging.emit(Vector3.ZERO, 2.4)
	var charging := engine.reactor_pedal
	events.run_ended.emit(true)
	var after := engine.reactor_pedal
	_check("the pedal never sticks past a run", charging and not after, "a vent charging into run_ended left reactor_pedal at %s" % after)
	(rig["audio"] as Node).free()
	(rig["events"] as Node).free()


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", name, detail])
