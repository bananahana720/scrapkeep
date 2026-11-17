extends "res://tools/bot_run.gd"

## Matched stage-two bot runs through the normal driver. Both arms preserve the stage
## director's seeded state. Only the test director can move the wasteway seats.
const CrewTrial := preload("res://tools/spillway_crew_trial.gd")

var observed_director
var stage_ticks := 0
var started_site := false
var queued := 0
var peak_crew := 0

func _physics_process(delta: float) -> bool:
	var finished := super._physics_process(delta)
	if finished or _game == null or _game.world == null or _game.world.director == null:
		return finished
	if _game.run.stage != 2 or _driver == null:
		return finished
	if observed_director != _game.world.director:
		var previous = _game.world.director
		observed_director = CrewTrial.Placement.new()
		for property in previous.get_script().get_script_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				observed_director.set(property.name, previous.get(property.name))
		observed_director.shift_home = _settings.get("home-seat", "stock") == "west"
		_game.world.director = observed_director
	if not started_site and _settings.get("sample-site", "") == "kicker":
		started_site = true
		var xz := Vector2(40, 255)
		var heading := xz.direction_to(Vector2(85, 335))
		var along := Vector3(heading.x, 0, heading.y)
		_game.player.reset_to(_game.ctx.terrain.drop_point(xz.x, xz.y, 1.3), along * 24)
		_game.camera.snap(along)
		var spot: Vector2 = observed_director.spawn_spot(xz, heading * 24, heading)
		if spot.is_finite():
			queued = observed_director._place_pack(spot, ["chaser", "lobber"], xz)
	peak_crew = maxi(peak_crew, get_nodes_in_group("enemy").size())
	stage_ticks += 1
	if stage_ticks == int(_settings.get("sample-ticks", "8100")):
		var row := {"band": _settings["band"], "arm": _settings["home-seat"], "seed": _seeds[_index],
				"ticks": stage_ticks, "hp": _game.run.hp, "seats": observed_director.wasteway_seats,
				"ball": str(_game.player.ball_position()), "phase": _game.flow.state_name(),
				"kills": _game.run.kills, "site": _settings.get("sample-site", "entry"),
				"queued": queued, "peak_crew": peak_crew, "attempt_time": _game.run.stage_time}
		var output := FileAccess.open(_out.path_join("window.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify(row))
		output.close()
		print("CREW_BAND ", row)
		quit(0)
		return true
	return finished
