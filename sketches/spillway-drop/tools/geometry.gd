extends SceneTree

const Terrain := preload("res://src/terrain.gd")

# Prints the stage's key heights and grades straight from the height field, which
# is how the chute pitch and the bypass grade were checked without launching.


func _initialize() -> void:
	print("shelves: top %.1f  mid %.1f  basin %.1f" % [Terrain.TOP_H, Terrain.MID_H, Terrain.BASIN_H])
	for spot in [
		["spawn", Terrain.SPAWN], ["pump house", Terrain.PUMP_HOUSE], ["hatch", Terrain.HATCH],
		["bypass foot", Terrain.BYPASS_FOOT], ["bypass top", Terrain.BYPASS_TOP],
	]:
		var p: Vector2 = spot[1]
		print("%-12s (%6.1f, %6.1f)  ground %.2f" % [spot[0], p.x, p.y, Terrain.height(p.x, p.y)])

	for i in Terrain.CHUTES.size():
		var c: Dictionary = Terrain.CHUTES[i]
		var top := Terrain.height(c["x"], c["z0"])
		var bottom := Terrain.height(c["x"], c["z1"])
		var run: float = absf(c["z1"] - c["z0"])
		print("chute %d at x %.0f: %.1f m -> %.1f m over %.0f m, mean %.1f deg, entry %s"
			% [i, c["x"], top, bottom, run, rad_to_deg(atan((top - bottom) / run)), Terrain.chute_entry(i)])
		var steep := 0.0
		for j in 40:
			var z: float = lerpf(c["z0"], c["z1"], j / 39.0)
			var dz := 2.0
			var grade := absf(Terrain.height(c["x"], z + dz) - Terrain.height(c["x"], z)) / dz
			steep = maxf(steep, rad_to_deg(atan(grade)))
		print("        steepest 2 m sample on the centreline: %.1f deg" % steep)

	var worst := 0.0
	for j in 120:
		var z: float = lerpf(130.0, -110.0, j / 119.0)
		var here := Terrain.height(Terrain.BYPASS_X, z)
		var next := Terrain.height(Terrain.BYPASS_X, z - 2.0)
		worst = maxf(worst, rad_to_deg(atan(absf(next - here) / 2.0)))
	print("bypass: steepest 2 m sample from z 130 to -110: %.1f deg" % worst)
	quit(0)
