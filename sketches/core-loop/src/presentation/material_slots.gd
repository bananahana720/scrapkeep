extends RefCounted

const SLOTS := {
	"ground": {"kind": "shader", "shader": "res://src/presentation/sandstone.gdshader", "params": {"cliff_only": false},
		"triplanar_scale": 6.0, "textures": {"strata_map": "sandstone-strata", "floor_map": "packed-sand-floor"}, "worlds": [1]},
	"rock": {"kind": "shader", "shader": "res://src/presentation/sandstone.gdshader", "params": {"cliff_only": true},
		"triplanar_scale": 6.0, "textures": {"strata_map": "sandstone-strata", "floor_map": "packed-sand-floor"}, "worlds": [1]},
	"dam": {"kind": "shader", "shader": "res://assets/shaders/target_dam.gdshader", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [1]},
	"concrete": {"kind": "shader", "shader": "res://assets/materials/gpw_workshop.gdshader", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [1]},
	"clutter": {"kind": "shader", "shader": "res://src/presentation/clutter.gdshader", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [1, 2, 3]},
	"dressing": {"kind": "shader", "shader": "res://assets/shaders/target_dressing.gdshader", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [1, 2, 3]},
	"air": {"kind": "shader", "shader": "res://assets/shaders/target_air.gdshader", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [1, 2, 3]},
	"hazard_stripe": {"kind": "standard", "params": {"stripe_a": "HAZARD", "stripe_b": "CHARCOAL", "roughness": 0.75, "checker_meta": true},
		"triplanar_scale": 4.0, "textures": {}, "worlds": [1, 2, 3]},
	"nosing": {"kind": "standard", "params": {"stripe_a": "AMBER", "stripe_b": "CHARCOAL", "roughness": 0.85},
		"triplanar_scale": 2.0, "textures": {}, "worlds": [3]},
	"cable": {"kind": "standard", "params": {"albedo": "CABLE", "roughness": 0.55, "metallic": 0.15},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [1, 2, 3]},
	"stone": {"kind": "resource", "path": "res://assets/materials/dig_stone/stone.tres", "params": {},
		"triplanar_scale": 11.0, "textures": {}, "worlds": [2]},
	"steel": {"kind": "resource", "path": "res://assets/materials/dig_mechanical/steel.tres", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [2]},
	"enamel": {"kind": "resource", "path": "res://assets/materials/dig_mechanical/enamel.tres", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [2]},
	"elastomer": {"kind": "resource", "path": "res://assets/materials/dig_mechanical/elastomer.tres", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [2]},
	"glass": {"kind": "resource", "path": "res://assets/materials/dig_mechanical/glass.tres", "params": {},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [2]},
	"ancient_lens": {"kind": "shader", "shader": "res://assets/materials/wog_signal.gdshader", "params": {"finish_kind": 0},
		"triplanar_scale": 0.0, "textures": {}, "worlds": [1], "ancient": true, "pattern": "chevron_ribs"},
}

const SHIPPED_AS_SLOT := ["ground", "rock"]


static func row(role: String) -> Dictionary:
	return SLOTS.get(role, {})


static func ancient_roles() -> Array:
	var roles := []
	for role in SLOTS:
		if SLOTS[role].get("ancient", false):
			roles.append(role)
	return roles
