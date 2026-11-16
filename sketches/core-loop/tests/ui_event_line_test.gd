extends SceneTree

# W1-110: a world event's warning line reads as that event and nothing else. It wears the colour
# its edge marker wears (never the hazard red, which is for what hurts the ball now), it stays up
# for the event's lead (capped), and the marker is up while the line is.

const Game := preload("res://src/game.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

const EVENT_LINE_CAP := 12.0
var _t := T.new("ui_event_line_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


# Seconds of stepping until the line is gone, up to a limit; -1 if it never goes.
func _life(hud, limit: float) -> float:
	var spent := 0.0
	var dt := 1.0 / 60.0
	while spent < limit:
		if hud.toast_on_screen() == "":
			return spent
		hud._step_toast(dt)
		spent += dt
	return -1.0


func _step(hud, seconds: float) -> void:
	var spent := 0.0
	while spent < seconds:
		hud._step_toast(1.0 / 60.0)
		spent += 1.0 / 60.0


func _announce(hud, id: String, lead: float) -> void:
	hud.clear_toasts()
	hud.edge_markers._incoming.clear()
	_game.events.event_announced.emit(id, lead, Vector3(40.0, 3.0, -12.0))


func _run() -> void:
	for i in 5:
		await process_frame
	var hud = _game.hud
	_announce(hud, "dome_lightning", 4.0)
	var shown: Array = hud.edge_markers.incoming_targets()
	_t.eq("a world event's announcement puts its edge marker up", shown.size(), 1)
	_t.check("the line is up with the marker", hud.toast_on_screen() != "", hud.toast_on_screen())
	if shown.size() == 1:
		var marker: Color = EdgeMarkers.marker_color(shown[0])
		_t.check("the line is slate, the colour law's not yet", hud._toast["color"] == Palette.SLATE, str(hud._toast["color"]))
		_t.check("the edge marker stays hazard red and differs from the line", marker == Palette.HAZARD and marker != hud._toast["color"], str(marker))
	var short := _life(hud, 20.0)
	_announce(hud, "powerhouse_boiler", 9.0)
	var long := _life(hud, 20.0)
	_t.check("a 4 s lead keeps the line up for about 4 s", absf(short - 4.0) < 0.1, "%.3f" % short)
	_t.check("a 9 s lead keeps the line up for about 9 s", absf(long - 9.0) < 0.1, "%.3f" % long)
	_announce(hud, "dome_lightning", 40.0)
	var capped := _life(hud, 60.0)
	_t.check("a lead past the cap holds at the cap", absf(capped - EVENT_LINE_CAP) < 0.1, "%.3f" % capped)
	_announce(hud, "dome_lightning", 6.0)
	_step(hud, 4.5)
	hud.edge_markers.step_incoming(4.5)
	_t.eq("the marker is still up 4.5 s into a 6 s lead", hud.edge_markers.incoming_targets().size(), 1)
	_t.check("and the line is still up", hud.toast_on_screen() != "", hud.toast_on_screen())
	_announce(hud, "dome_lightning", 9.0)
	_step(hud, 1.0)
	_game.events.event_started.emit("powerhouse_boiler")
	_step(hud, 0.05)
	_t.check("another event's start leaves the line up", hud.toast_on_screen() != "", hud.toast_on_screen())
	_game.events.event_started.emit("dome_lightning")
	var after := _life(hud, 20.0)
	_t.check("its own event's start ends the line well before the hold", after >= 0.0 and after < 0.5, "%.3f" % after)
	_announce(hud, "dome_lightning", 9.0)
	_step(hud, 1.0)
	_game.events.event_ended.emit("dome_lightning", "won")
	var ended := _life(hud, 20.0)
	_t.check("its own event's end ends the line too", ended >= 0.0 and ended < 0.5, "%.3f" % ended)
	_t.eq("the announcement row stays hazard red for the arena cue and the marker", EventKinds.color("event_announced"), Palette.HAZARD)
	_game.queue_free()
	quit(_t.verdict())
