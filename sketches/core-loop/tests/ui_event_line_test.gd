extends SceneTree

# W1-110: a world event's warning line reads as that event and nothing else. It wears the colour
# its edge marker wears (never the hazard red, which is for what hurts the ball now), it stays up
# for the event's lead (capped), and the marker is up while the line is.

const Game := preload("res://src/game.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
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
		_t.check("the line wears its marker's colour", hud._toast["color"] == marker, "%s vs %s" % [hud._toast["color"], marker])
		_t.check("that colour is not the hazard red", marker != Palette.HAZARD and hud._toast["color"] != Palette.HAZARD, str(marker))
	var short := _life(hud, 20.0)
	_announce(hud, "powerhouse_boiler", 9.0)
	var long := _life(hud, 20.0)
	_t.check("a 4 s lead keeps the line up for about 4 s", absf(short - 4.0) < 0.1, "%.3f" % short)
	_t.check("a 9 s lead keeps the line up for about 9 s", absf(long - 9.0) < 0.1, "%.3f" % long)
	_announce(hud, "dome_lightning", 40.0)
	var capped := _life(hud, 60.0)
	_t.check("a lead past the cap holds at the cap", absf(capped - EVENT_LINE_CAP) < 0.1, "%.3f" % capped)
	_announce(hud, "dome_lightning", 6.0)
	hud.edge_markers.step_incoming(5.0)
	_t.eq("the marker is still up while the line is", hud.edge_markers.incoming_targets().size(), 1)
	_t.check("and the line is still up", hud.toast_on_screen() != "")
	_game.queue_free()
	quit(_t.verdict())
