extends SceneTree

const Game := preload("res://src/game.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# The beacon ring, its mast bulb and its edge marker read one fact, the beacon's state
# (LEGIBILITY section 1): sealed by the Warden is the "not yet" colour, open is the "the world
# is offering" colour, and at no point is any part within 20 CIE76 of the live or hazard colour,
# so mint keeps meaning "your move works on this now".

const MIN_GAP := 20.0

var _t := T.new("beacon_colour_test")
var _game
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_run()
	_game.free()
	quit(_t.verdict())
	return false


func _parts(beacon) -> Dictionary:
	return {"ring": beacon._ring_material.albedo_color, "bulb": beacon._core_material.albedo_color,
		"bulb glow": beacon._core_material.emission}


func _clear_of(label: String, colour: Color) -> void:
	var live := _cie76(colour, Palette.live())
	var hazard := _cie76(colour, Palette.HAZARD)
	_t.check(label + " clear of live and hazard", live >= MIN_GAP and hazard >= MIN_GAP,
		"%s is %.1f from live, %.1f from hazard (floor %.0f)" % [colour.to_html(false), live, hazard, MIN_GAP])


func _same(a: Color, b: Color) -> bool:
	return a.is_equal_approx(Color(b, a.a))


func _run() -> void:
	var flow = _game.flow
	var beacon = _game.beacon
	var markers := EdgeMarkers.new()
	root.add_child(markers)
	markers.setup(_game)
	_t.check("the Warden seals the stage", flow.sealed and beacon.sealed and flow.state_name() == "stage", "sealed %s, beacon %s" % [flow.sealed, beacon.sealed])
	var not_yet := EventKinds.role_color("slate")
	var offering := EventKinds.role_color("amber")
	for name in _parts(beacon):
		var c: Color = _parts(beacon)[name]
		_t.check("sealed: " + name + " is the not-yet colour", _same(c, not_yet), "%s, want %s" % [c.to_html(false), not_yet.to_html(false)])
		_clear_of("sealed " + name, c)
	var edge_sealed := EventKinds.state_color(beacon.state_id())
	_t.check("sealed: the edge marker's source is the not-yet colour", edge_sealed == not_yet, "%s" % edge_sealed.to_html(false))
	_clear_of("sealed edge marker", edge_sealed)

	beacon.open()
	flow.sealed = false
	flow.warden = null
	for name in _parts(beacon):
		var c: Color = _parts(beacon)[name]
		_t.check("open: " + name + " is the offering colour", _same(c, offering), "%s, want %s" % [c.to_html(false), offering.to_html(false)])
		_clear_of("open " + name, c)
	var seen := 0
	for target in markers.targets():
		if target["kind"] == "beacon_charge_changed":
			seen += 1
			var c: Color = EventKinds.state_color(target["state"])
			_t.check("open: the edge marker is the offering colour", c == offering, "%s" % c.to_html(false))
			_clear_of("open edge marker", c)
	_t.eq("open: the beacon has an edge marker", seen, 1)


static func _cie76(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))


static func _lab(c: Color) -> Vector3:
	var r := _linear(c.r)
	var g := _linear(c.g)
	var b := _linear(c.b)
	var x := (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
	var y := r * 0.2126729 + g * 0.7151522 + b * 0.0721750
	var z := (b * 0.9503041 + g * 0.1191920 + r * 0.0193339) / 1.08883
	return Vector3(116.0 * _f(y) - 16.0, 500.0 * (_f(x) - _f(y)), 200.0 * (_f(y) - _f(z)))


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
