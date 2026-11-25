extends RefCounted

const Palette := preload("res://src/core/palette.gd")


static func polar(parent: Node3D, name: String, centre: Vector3, r0: float, r1: float, rings: int, segments: int,
		height: Callable, base: Callable, tint: Color) -> StaticBody3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for i in rings + 1:
		var r := lerpf(r0, r1, float(i) / rings)
		for j in segments:
			var a := TAU * float(j) / segments
			var x := centre.x + cos(a) * r
			var z := centre.z + sin(a) * r
			var y := float(base.call(x, z)) + float(height.call(r, a))
			verts.append(Vector3(x, y, z) - centre)
			colors.append(tint)
	var indices := PackedInt32Array()
	for i in rings:
		for j in segments:
			var a := i * segments + j
			var b := i * segments + (j + 1) % segments
			var c := a + segments
			var d := b + segments
			indices.append_array([a, c, b, c, d, b])
	return _body(parent, name, centre, verts, colors, indices)


static func grid(parent: Node3D, name: String, size: Vector2, step: float, height: Callable, tint: Callable) -> StaticBody3D:
	var nx := int(ceil(size.x / step))
	var nz := int(ceil(size.y / step))
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for j in nz + 1:
		var v := -size.y * 0.5 + j * size.y / nz
		for i in nx + 1:
			var u := -size.x * 0.5 + i * size.x / nx
			verts.append(Vector3(u, float(height.call(u, v)), v))
			colors.append(tint.call(u, v))
	var indices := PackedInt32Array()
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	return _body(parent, name, Vector3.ZERO, verts, colors, indices)


static func _body(parent: Node3D, name: String, origin: Vector3, verts: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array) -> StaticBody3D:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for k in range(0, indices.size(), 3):
		var a := indices[k]
		var b := indices[k + 1]
		var c := indices[k + 2]
		var n := (verts[c] - verts[a]).cross(verts[b] - verts[a])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for k in normals.size():
		normals[k] = normals[k].normalized() if normals[k].length() > 0.0 else Vector3.UP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var body := StaticBody3D.new()
	body.name = name
	body.position = origin
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = Palette.ground_material()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.add_child(view)
	parent.add_child(body)
	return body
