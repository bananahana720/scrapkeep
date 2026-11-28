extends RefCounted

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

static var run_seed := 0


static func reset_for_tests() -> void:
	run_seed = 0


static func roll(seed: int, id: String) -> Dictionary:
	var out := {"amount": 1.0, "size": 1.0, "speed": 1.0, "yaw": 0.0, "tint_share": 0.0, "pulse": 1.0, "seed": Kit.SEED}
	var s: Dictionary = Specs.SPECS.get(id, {})
	if seed == 0 or s.is_empty() or float(s.get("ink", 0.0)) > 0.0:
		return out
	var row: Dictionary = Specs.GRAIN.get(id, Specs.GRAIN_DEFAULT)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [seed, id])
	var draws := {}
	for dial in ["amount", "size", "speed", "wind_deg", "tint", "pulse"]:
		draws[dial] = rng.randf()
	out["seed"] = rng.randi() & 0x7fffffff
	for dial in ["amount", "size", "speed", "pulse"]:
		if row.has(dial):
			out[dial] = lerpf(float(row[dial][0]), float(row[dial][1]), draws[dial])
	out["amount"] = clampf(out["amount"], 0.0, 1.0)
	if row.has("wind_deg"):
		out["yaw"] = deg_to_rad(lerpf(-float(row["wind_deg"]), float(row["wind_deg"]), draws["wind_deg"]))
	if row.has("tint"):
		out["tint_share"] = float(row["tint"][1]) * draws["tint"]
	return out


static func tint(id: String, dials: Dictionary, base := Color.WHITE) -> Color:
	var row: Dictionary = Specs.GRAIN.get(id, {})
	if not row.has("tint") or float(dials.get("tint_share", 0.0)) <= 0.0:
		return base
	var c := base * Color.WHITE.lerp(Specs.colour(String(row["tint"][0])), float(dials["tint_share"]))
	c.a = base.a
	return c


static func apply(p: GPUParticles3D, seed: int) -> Dictionary:
	var id := String(p.get_meta("world_fx", ""))
	var s: Dictionary = Specs.SPECS.get(id, {})
	if s.is_empty():
		return {}
	var dials := roll(seed, id)
	var pm := p.process_material as ParticleProcessMaterial
	pm.scale_min = float(s["size"][0]) * dials["size"]
	pm.scale_max = float(s["size"][1]) * dials["size"]
	pm.initial_velocity_min = float(s["speed"][0]) * dials["speed"]
	pm.initial_velocity_max = float(s["speed"][1]) * dials["speed"]
	var turn := Basis(Vector3.UP, dials["yaw"])
	pm.direction = turn * (s.get("dir", Vector3.UP) as Vector3)
	var g = s.get("gravity", 0.0)
	pm.gravity = turn * g if g is Vector3 else Vector3(0.0, float(g), 0.0)
	p.seed = dials["seed"]
	p.set_meta("grain", dials)
	var base: Color = p.get_meta("tint") if p.has_meta("tint") else Color.WHITE
	p.set_instance_shader_parameter(FxLibrary.TINT, tint(id, dials, base))
	return dials


static func share(p: GPUParticles3D, low: bool, reduced_motion: bool) -> float:
	var s: Dictionary = Specs.SPECS[p.get_meta("world_fx")]
	var dials: Dictionary = p.get_meta("grain", {})
	return Kit.share(s, low, reduced_motion) * float(dials.get("amount", 1.0))


static func pulse(p: GPUParticles3D) -> Array:
	var s: Dictionary = Specs.SPECS[p.get_meta("world_fx")]
	var k := float((p.get_meta("grain", {}) as Dictionary).get("pulse", 1.0))
	return [float(s["pulse"][0]) * k, float(s["pulse"][1]) * k]
