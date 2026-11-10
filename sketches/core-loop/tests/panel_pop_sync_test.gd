extends SceneTree

const PanelFx := preload("res://src/presentation/panel_fx.gd")
const Panels := preload("res://src/build/panels.gd")
const T := preload("res://tests/support/t.gd")

# A pickup pop is on screen within 1.2 s of its sound (PF-19). Ten pickups in one tick, a frame
# at a time: every one is counted in a pop that shows inside the window, and the pile folds into
# one "+N" line. The planted control feeds the old unfolded queue: the tenth pop then shows 4.8 s
# after its sound and the check must fail.

const STEP := 1.0 / 60.0
const WINDOW := PanelFx.POP_LIFE

var _t := T.new("panel_pop_sync_test")


class Stub:
	var reduced_motion := false
	var shown: Array = []
	var clock := 0.0
	var player = self

	func shown_position() -> Vector3:
		return Vector3.ZERO

	func word(text: String, _at: Vector3, _tint: Color, _force := false, _life := 1.0, _size := 1.0) -> bool:
		shown.append([text, clock])
		return true

	func play(_id: String, _a := 0.0, _b := 1.0, _bus := "SFX", _c := "") -> void:
		pass


class Ctx:
	var run = null
	var player = null
	var events = null


# Runs ten pickups of `ids` in one tick and returns [latest show delay, count total, lines].
func _pile(ids: Array, fold: bool) -> Array:
	var stub := Stub.new()
	var ctx := Ctx.new()
	ctx.player = stub
	var fx = PanelFx.new()
	fx.ctx = ctx
	fx.audio = stub
	fx.machine_fx = stub
	for id in ids:
		if fold:
			fx._on_panel_gained(id, 1, Vector3.ZERO, false)
		else:
			# The planted control: the old queue, every pickup its own waiting pop.
			fx._waiting.append([id, false])
			fx._release()
	var steps := int(6.0 / STEP)
	for i in steps:
		stub.clock += STEP
		fx._process(STEP)
	var latest := 0.0
	var total := 0
	for pop in stub.shown:
		latest = maxf(latest, float(pop[1]))
		var text: String = pop[0]
		total += int(text.get_slice(" ", 0).trim_prefix("+")) if text.begins_with("+") and text.get_slice(" ", 0).trim_prefix("+").is_valid_int() and not text.contains("%") else 1
	fx.free()
	return [latest, total, stub.shown.map(func(p): return p[0])]


func _initialize() -> void:
	var id: String = Panels.ids()[0]
	var ten: Array = []
	ten.resize(10)
	ten.fill(id)
	var folded := _pile(ten, true)
	_t.check("ten pickups: every pop shows within 1.2 s of its sound", folded[0] <= WINDOW, "latest %.2f s, lines %s" % [folded[0], folded[2]])
	_t.eq("the pile is two pops, then two waiting lines, one folded", folded[2].size(), 4)
	_t.check("the folded line's count is right", String(folded[2][2]) == "+7 %s" % String(Panels.row(id)["noun"]).to_upper(), "line '%s'" % folded[2][2])
	_t.eq("all ten pickups are counted", folded[1], 10)
	var loose := _pile(ten, false)
	_t.check("planted control: with folding off the tenth pop is late", loose[0] > WINDOW, "latest %.2f s" % loose[0])
	# Mixed kinds fold into one generic line.
	var mixed: Array = []
	for i in 10:
		mixed.append(Panels.ids()[i % 3])
	var mix := _pile(mixed, true)
	_t.check("mixed kinds fold too, inside the window", mix[0] <= WINDOW and String(mix[2].back()).begins_with("+") and String(mix[2].back()).contains("PANELS"), "latest %.2f s, lines %s" % [mix[0], mix[2]])
	quit(_t.verdict())
