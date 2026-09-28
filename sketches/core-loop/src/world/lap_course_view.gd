extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EventView := preload("res://src/world/event_view.gd")

# Draws the laps course (lap_course.gd) from its model and nothing else: the surge
# run's gate ring at each checkpoint, standing from the stage's first frame so the
# course reads from the drop deck. Before the bell the rings are dim bone; the bell
# lights them in the lap colour, the next ring pulses, and a passed ring pops.

const DIM := 0.35
const LIT := 1.1
const NEXT := 2.4
const PULSE_HZ := 1.6
const POP_SECONDS := 0.3
const POP_SCALE := 0.45

var course
var _rings: Array[MeshInstance3D] = []
var _pops: Array[float] = []
var _clock := 0.0


func show_course(course_ref, ground: Callable) -> void:
	clear()
	course = course_ref
	if course == null:
		return
	for i in course.count():
		var at: Vector3 = course.rings[i]
		var ring := EventView.gate_ring(ground.call(at.x, at.z), course.facing(i))
		add_child(ring)
		_rings.append(ring)
		_pops.append(0.0)


func clear() -> void:
	course = null
	for ring in _rings:
		ring.queue_free()
	_rings.clear()
	_pops.clear()


# The checkpoint's pop (LOOP-REDESIGN section 7, the lap notch): the ring swells and
# settles as the ball goes through it.
func pop(index: int) -> void:
	if index >= 0 and index < _pops.size():
		_pops[index] = POP_SECONDS


func _process(delta: float) -> void:
	if course == null:
		return
	_clock += delta
	var lap := EventKinds.color("lap_ring_passed")
	var pulse := 0.5 + 0.5 * sin(_clock * TAU * PULSE_HZ)
	for i in _rings.size():
		var mat: StandardMaterial3D = _rings[i].material_override
		var next: bool = course.bell_rung and i == course.next_ring
		mat.albedo_color = lap if course.bell_rung else Palette.SAND
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = (NEXT + pulse * 2.0) if next else (LIT if course.bell_rung else DIM)
		_pops[i] = maxf(0.0, _pops[i] - delta)
		var swell := 1.0 + POP_SCALE * sin(PI * _pops[i] / POP_SECONDS) if _pops[i] > 0.0 else 1.0
		_rings[i].scale = Vector3.ONE * swell
