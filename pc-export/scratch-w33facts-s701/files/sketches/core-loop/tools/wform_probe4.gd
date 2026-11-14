extends "res://tools/wform_probe3.gd"
# Scratch only, never committed (dam fight capture, PR 701 fe4ffe76). wform_probe3 plus, at every posture reading of
# the Warden: posture, staggered, real chunks, phase_chunks_left (the dam's quarter count), the run's heft class,
# the ball's heft, and whether a mount driver exists. Written to <out>.dam.json.

var _dam_rows: Array = []
var _dam_hooked := false


func _physics_process(delta: float) -> bool:
	var out := super(delta)
	if _driver != null and _taken and not _dam_hooked:
		_dam_hooked = true
		_game.events.posture_changed.connect(_on_dam_row)
	return out


func _on_dam_row(enemy: Node3D, posture: float, staggered: bool) -> void:
	var audio = _game.presentation.audio
	var w = _game.flow.get("warden") if _game.flow != null else null
	var is_w: bool = is_instance_valid(w) and w == enemy
	var heft := -1.0
	var hc := -1
	if _game.ctx.get("run") != null and _game.ctx.run.has_method("heft_class"):
		hc = _game.ctx.run.heft_class()
	if _game.player != null and _game.player.get("heft_of") != null and _game.player.heft_of is Callable:
		heft = float(_game.player.heft_of.call())
	var phase := -1
	var real := -1
	var mounted := false
	if is_instance_valid(enemy):
		real = enemy.chunks_left() if enemy.has_method("chunks_left") else -1
		phase = enemy.phase_chunks_left() if enemy.has_method("phase_chunks_left") else -1
		mounted = enemy.get("mount_driver") != null
	_dam_rows.append([snappedf(_now(), 0.001), audio.engine.clock - _base_sample, posture, staggered, real, phase, hc, heft, mounted, is_w])


func _finish() -> void:
	var f := FileAccess.open("%s/%s.dam.json" % [String(_settings["out"]).get_base_dir(), String(_settings["out"]).get_file().get_basename()], FileAccess.WRITE)
	f.store_string(JSON.stringify({"cols": ["wall_s", "transport_sample", "posture", "staggered", "chunks", "phase_chunks_left", "heft_class", "ball_heft", "mounted", "is_warden"], "rows": _dam_rows}))
	f.close()
	super()
