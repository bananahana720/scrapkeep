extends RefCounted

# Geometry pins that hold on every platform. Godot's float32 sin and cos call the platform's sinf and cosf, and glibc's
# differ from Apple's in the last bit on a few percent of angles, so a hash of raw transforms differs between the Linux
# build and the Mac (artifacts/local/determinism, 16 Nov 2026: largest move 7.6e-6 m in a position, 6e-8 in a basis
# element).
#
# A pin stores the value's shape and every float rounded to STEP, and a check compares each float with a tolerance of
# half a step plus MARGIN_MIN platform differences: far above that difference, far below a change a person could see. A
# plain hash of the rounded floats is not enough: with thousands of floats some sit within a platform difference of a
# rounding boundary and can round the other way on Linux, and margin() measures that (it was under 1 for all five
# geometry pins on 16 Nov 2026).
#
# Record a pin with PIN_RECORD=1 in the environment; the check then writes the file instead of comparing.

const STEP := 0.001
const POS_DRIFT := 7.6e-6
const UNIT_DRIFT := 6e-8
const MARGIN_MIN := 10.0
const TOLERANCE := 0.5 + MARGIN_MIN * POS_DRIFT / STEP


# Empty when value matches the pin at path: the same ints, strings and nesting, and every float within TOLERANCE steps
# of its stored count. Otherwise the first difference.
static func check(path: String, value: Variant) -> String:
	var floats := _floats(value, [])
	var shape := hash(var_to_bytes(_shape(value)))
	if OS.get_environment("PIN_RECORD") == "1":
		var out := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		out.store_var([shape, PackedInt32Array(floats.map(func(x: float) -> int: return int(roundf(x / STEP))))])
		out.close()
		print("pin_hash: recorded %d floats to %s" % [floats.size(), path])
		return ""
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return "no pin at %s: record it with PIN_RECORD=1" % path
	var stored: Array = file.get_var()
	if stored[0] != shape:
		return "the ints, strings or nesting changed"
	var want: PackedInt32Array = stored[1]
	if floats.size() != want.size():
		return "%d floats, pinned %d" % [floats.size(), want.size()]
	for k in floats.size():
		if absf(floats[k] / STEP - want[k]) > TOLERANCE:
			return "float %d is %.4f, pinned %.4f" % [k, floats[k], want[k] * STEP]
	return ""


# The smallest distance of any float from a STEP rounding boundary, over the platform difference for its kind (a basis
# or quaternion element against UNIT_DRIFT, anything else against POS_DRIFT). A hash of rounded floats is safe across
# platforms only at MARGIN_MIN or more. INF when there is no float.
static func margin(value: Variant) -> float:
	var kinds := []
	var xs := _floats(value, kinds)
	var best := INF
	for k in xs.size():
		var q: float = xs[k] / STEP
		var distance := absf(q - floorf(q) - 0.5) * STEP
		best = minf(best, distance / (UNIT_DRIFT if kinds[k] else POS_DRIFT))
	return best


# Every float in value, in a fixed order; kinds gets true for a basis or quaternion element.
static func _floats(value: Variant, kinds: Array) -> Array:
	var out := []
	_collect(value, out, kinds, false)
	return out


static func _collect(value: Variant, out: Array, kinds: Array, unit: bool) -> void:
	match typeof(value):
		TYPE_FLOAT:
			out.append(value)
			kinds.append(unit)
		TYPE_VECTOR2:
			_collect([value.x, value.y], out, kinds, unit)
		TYPE_VECTOR3:
			_collect([value.x, value.y, value.z], out, kinds, unit)
		TYPE_VECTOR4, TYPE_QUATERNION:
			_collect([value.x, value.y, value.z, value.w], out, kinds, unit or value is Quaternion)
		TYPE_BASIS:
			_collect([value.x, value.y, value.z], out, kinds, true)
		TYPE_TRANSFORM3D:
			_collect(value.basis, out, kinds, true)
			_collect(value.origin, out, kinds, false)
		TYPE_AABB:
			_collect([value.position, value.size], out, kinds, false)
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var start := out.size()
			out.append_array(Array(value))
			kinds.resize(out.size())
			for k in range(start, out.size()):
				kinds[k] = unit
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_ARRAY:
			for item in value:
				_collect(item, out, kinds, unit)
		TYPE_DICTIONARY:
			for key in value:
				_collect(value[key], out, kinds, unit)


# value with every float-bearing leaf replaced by its float count, so the pin also covers the ints, strings and nesting.
static func _shape(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return value.map(_shape)
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[key] = _shape(value[key])
			return out
		TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_QUATERNION, TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_AABB, \
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			return "f%d" % _floats(value, []).size()
	return value
