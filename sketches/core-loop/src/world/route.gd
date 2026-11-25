extends RefCounted


var points := PackedVector2Array()
var lengths := PackedFloat32Array()
var total := 0.0


func _init(route_points := PackedVector2Array()) -> void:
	points = route_points
	lengths.resize(points.size())
	var run := 0.0
	for i in points.size():
		if i > 0:
			run += points[i].distance_to(points[i - 1])
		lengths[i] = run
	total = run


func at(distance: float) -> Vector2:
	var d := clampf(distance, 0.0, total)
	for i in range(1, points.size()):
		if d <= lengths[i]:
			var span := lengths[i] - lengths[i - 1]
			var t := (d - lengths[i - 1]) / span if span > 0.0 else 0.0
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]


func tangent(distance: float) -> Vector2:
	var d := clampf(distance, 0.0, total)
	for i in range(1, points.size()):
		if d <= lengths[i]:
			return (points[i] - points[i - 1]).normalized()
	return (points[points.size() - 1] - points[points.size() - 2]).normalized()


func project(p: Vector2) -> Vector2:
	var best_d := 0.0
	var best_off := INF
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var off := p.distance_to(a + ab * t)
		if off < best_off:
			best_off = off
			best_d = lengths[i - 1] + ab.length() * t
	return Vector2(best_d, best_off)
