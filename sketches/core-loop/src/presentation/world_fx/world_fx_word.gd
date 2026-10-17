extends Label3D

const Palette := preload("res://src/core/palette.gd")

# A drawn sound word (TONE-BIBLE pillar 2): SPLOSH, KA-CHUNK, OOH. It stamps in with three frames of
# overshoot, holds, and slides off on a diagonal (the do-and-don't table's card motion). It floats
# LIFT_M over the moment, never sits on the ball, and is gone inside LIFE seconds, so it never
# covers a telegraph for longer than a glance.
const LIFE := 0.75
const LIFT_M := 2.6
const FONT_PATH := "res://assets/fonts/NotoSans-Bold.ttf"

var _age := 0.0
var _drift := Vector3.ZERO


static func stamp(parent: Node, word: String, at: Vector3, fill := Palette.LEDGER) -> Label3D:
	var w: Label3D = load("res://src/presentation/world_fx/world_fx_word.gd").new()
	w.text = word
	w.name = "Word_%s" % word
	w.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	w.fixed_size = true
	w.pixel_size = 0.0011
	w.font_size = 72
	w.outline_size = 22
	w.modulate = fill
	w.outline_modulate = Palette.CHARCOAL
	w.shaded = false
	w.double_sided = true
	w.no_depth_test = false
	if ResourceLoader.exists(FONT_PATH):
		w.font = load(FONT_PATH)
	parent.add_child(w)
	w.global_position = at + Vector3(0, LIFT_M, 0)
	# Words alternate their exit diagonal so two in a row read as two.
	w._drift = Vector3(1.4 if word.hash() % 2 == 0 else -1.4, 1.0, 0)
	w.scale = Vector3.ONE * 0.01
	return w


func _process(delta: float) -> void:
	_age += delta
	var t := _age / LIFE
	# 0-0.07 s: slam to 125 %, settle to 100 % by 0.1 s (three frames at 30 fps), hold, slide off.
	if _age < 0.07:
		scale = Vector3.ONE * lerpf(0.01, 1.25, _age / 0.07)
	elif _age < 0.1:
		scale = Vector3.ONE * lerpf(1.25, 1.0, (_age - 0.07) / 0.03)
	elif t > 0.7:
		var k := (t - 0.7) / 0.3
		position += _drift * delta * 3.0 * k
		modulate.a = 1.0 - k
		outline_modulate.a = 1.0 - k
	if _age >= LIFE:
		queue_free()
