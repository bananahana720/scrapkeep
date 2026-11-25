extends RefCounted

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")

# The live run's seed; WorldFx sets it on each stage entry, 0 when no run is live.
static var run_seed := 0


static func reset_for_tests() -> void:
	run_seed = 0

# Run grain (WORLD-FX.md, Specs.GRAIN): one roll per spec per run, from the run seed and the spec id
# alone, so it draws nothing from any shared stream, a run replays its own look, and a spec added
# later never shifts another's roll. Seed 0 means "no run" (title, captures, tests): no grain, and the
# emitter keeps the kit's fixed seed. A rolled emitter also takes its own particle seed, so even the
# per-particle scatter differs between runs and repeats within one.


# The spec's dials for this run: {"amount", "size", "speed", "yaw", "tint_share", "pulse", "seed"}.
static func roll(seed: int, id: String) -> Dictionary:
	var out := {"amount": 1.0, "size": 1.0, "speed": 1.0, "yaw": 0.0, "tint_share": 0.0, "pulse": 1.0, "seed": Kit.SEED}
	var s: Dictionary = Specs.SPECS.get(id, {})
	if seed == 0 or s.is_empty() or float(s.get("ink", 0.0)) > 0.0:
		return out
	var row: Dictionary = Specs.GRAIN.get(id, Specs.GRAIN_DEFAULT)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [seed, id])
	# Every dial is drawn in a fixed order whether or not the row has it, so adding a dial to a row
	# changes that dial alone.
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


# The emitter's tint for this run: white (the authored colour) leaning toward the row's grain colour.
static func tint(id: String, dials: Dictionary, base := Color.WHITE) -> Color:
	var row: Dictionary = Specs.GRAIN.get(id, {})
	if not row.has("tint") or float(dials.get("tint_share", 0.0)) <= 0.0:
		return base
	var c := base * Color.WHITE.lerp(Specs.colour(String(row["tint"][0])), float(dials["tint_share"]))
	c.a = base.a
	return c


# Applies a roll to an emitter the kit built: its own process material is re-read from the spec and
# scaled, so applying twice (a new run on a kept emitter) never compounds. Stores the dials on the
# emitter (meta "grain") for share() and pulsed anchors.
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
	p.set_instance_shader_parameter("tint", tint(id, dials, base))
	return dials


# The share of an emitter's particles that emit: the preset and motion share times its run's amount.
static func share(p: GPUParticles3D, low: bool, reduced_motion: bool) -> float:
	var s: Dictionary = Specs.SPECS[p.get_meta("world_fx")]
	var dials: Dictionary = p.get_meta("grain", {})
	return Kit.share(s, low, reduced_motion) * float(dials.get("amount", 1.0))


# A pulsed spec's [period, on] for this emitter's run.
static func pulse(p: GPUParticles3D) -> Array:
	var s: Dictionary = Specs.SPECS[p.get_meta("world_fx")]
	var k := float((p.get_meta("grain", {}) as Dictionary).get("pulse", 1.0))
	return [float(s["pulse"][0]) * k, float(s["pulse"][1]) * k]
