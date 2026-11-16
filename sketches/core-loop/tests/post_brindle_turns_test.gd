extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rows := preload("res://src/presentation/flourish_rows.gd")
const FlourishPlayer := preload("res://src/presentation/flourish_player.gd")
const T := preload("res://tests/support/t.gd")

# After Brindle falls, what the player reads takes turns (PF-19, W1-07). Two parts:
#   rows   inside the shift log row, no two written pieces (card, caption, panels,
#          stamp) are up at the same moment, in the full form and the short form
#   live   world 2's entry after the rout: the world card, the shift log card, the SHIFT COMPLETE
#          stamp, the shift log caption and a found B-side record card are each up alone, and every
#          one of them shows (nothing is dropped)
# Evidence limit: headless frames and the nodes' visibility, not how the order reads at the sitting.

const ROWS := ["spillway_clear"]
const LIVE_SECONDS := 22.0

var _t := T.new("post_brindle_turns_test")
var _game
var _clock := 0.0


func _initialize() -> void:
	_rows()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _rows() -> void:
	for id in ROWS:
		for short in [false, true]:
			var spans: Array = []
			for piece in Rows.pieces(id, short):
				if String(piece.kind) in FlourishPlayer.HOLDS_VOICES:
					spans.append([float(piece.at), float(piece.at) + float(piece["for"]), String(piece.kind)])
			var clashes: Array = []
			for i in spans.size():
				for j in range(i + 1, spans.size()):
					if spans[i][0] < spans[j][1] and spans[j][0] < spans[i][1]:
						clashes.append("%s with %s" % [spans[i][2], spans[j][2]])
			_t.eq("01 %s (%s) has no two written pieces up together" % [id, "short" if short else "full"], clashes, [])


func _kinds() -> Array[String]:
	var out: Array[String] = []
	var player = _game.presentation.flourish
	for node in player.live_nodes():
		var kind := String(node.get_meta("flourish_kind", ""))
		if kind in FlourishPlayer.HOLDS_VOICES and node is Control and node.is_visible_in_tree():
			out.append("flourish " + kind)
	return out


func _showing() -> Array[String]:
	var out := _kinds()
	if _game.hud.launch_card.showing():
		out.append("world card")
	if _game.hud._ach_panel.visible:
		out.append("record card")
	return out


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _settle(0.1)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.presentation.flourish.stop_all()
	await _settle(3.0)
	_t.check("02 the table has more than one world", _game.ctx.stages.worlds().size() > 1)
	_game.events.boss_defeated.emit()
	_game.hud.take_found("Closing Time", "Moss's Back Room", "b-side")
	_game.events.world_entered.emit(2)
	var seen := {}
	var worst: Array = []
	var frames := 0
	var until := _clock + LIVE_SECONDS
	while _clock < until:
		await _settle(0.0)
		frames += 1
		var now := _showing()
		for item in now:
			seen[item] = true
		if now.size() > 1 and worst.size() < now.size():
			worst = now
	_t.check("03 ran frames", frames > 100, str(frames))
	_t.eq("04 never two items in the same frame", worst, [])
	for item in ["world card", "record card", "flourish card", "flourish stamp", "flourish caption"]:
		_t.check("05 %s showed" % item, seen.has(item), str(seen.keys()))
	_game.free()
	await process_frame
	quit(_t.verdict())


func _settle(seconds: float) -> void:
	var until := _clock + seconds
	while _clock < until:
		await process_frame
		_clock += _game.get_process_delta_time()
	if seconds == 0.0:
		await process_frame
		_clock += _game.get_process_delta_time()
