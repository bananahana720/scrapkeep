extends SceneTree

const Layout := preload("res://src/layout.gd")

# Prints the geometry the tests assert against. Not a check: a place to read the
# stage's numbers when a bench, road or kicker moves.


func _initialize() -> void:
	print("spawn ", Layout.spawn_point(), " yaw ", Layout.spawn_yaw())
	for k in Layout.CLIFF_Z.size():
		var x: float = Layout.ROAD_X[k]
		var cz: float = Layout.CLIFF_Z[k]
		var line := "road %d at x=%.0f:" % [k, x]
		for dz in [-8.0, 0.0, 8.0, 16.0, 24.0, 34.0, 42.0]:
			line += " %.0f:%.1f" % [cz + dz, Layout.height(x, cz + dz)]
		print(line)
		print("   off-road wall at x=%.0f: %.1f -> %.1f" % [x + 70.0,
			Layout.height(x + 70.0, cz + 6.0), Layout.height(x + 70.0, cz - 6.0)])
	for i in Layout.MESAS.size():
		var m: Dictionary = Layout.MESAS[i]
		var c: Vector2 = m["centre"]
		var xform := Layout.kicker_transform(i)
		var lip: Vector3 = xform.origin + xform.basis * Vector3(0.0, Layout.KICKER_SIZE.y * 0.5, Layout.KICKER_SIZE.z * 0.5)
		print("mesa %d %s centre=%s top=%.2f bench=%.2f" % [i, m["name"], c, Layout.mesa_top(i), Layout.height(c.x + 30.0, c.y)])
		print("   kicker origin=%s lip=%s entry=%s" % [xform.origin, lip, Layout.kicker_entry(i)])
	print("forge ", Layout.forge_point(), " secret ", Layout.drop_at(Layout.SECRET))
	for sz in Layout.SIDING_Z:
		print("siding z=%.0f: floor %.1f  lip %.1f" % [sz, Layout.height(0.0, sz), Layout.height(0.0, sz + Layout.SIDING_HALF)])
	quit(0)
