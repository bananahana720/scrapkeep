extends SceneTree
# KF0 2026-10-10: the striped mantles (meltdown, brood) now sit on stages 2 and 4.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const WardenDress := preload("res://src/presentation/warden_dress.gd")
const Warden := preload("res://src/combat/warden.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("warden_mantle_surface_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hook := HeroAssets.new()
	root.add_child(hook)
	for stage in WardenDress.MANTLES:
		var row: Dictionary = WardenDress.MANTLES[stage]
		var warden := Warden.new()
		warden.stage = stage
		warden.family = row.family
		warden._posture = BossPosture.new()
		var kit := hook._warden_scene("res://assets/models/warden_kit_%s.glb" % WardenDress.KITS[row.family])
		root.add_child(kit)
		var rec := {"warden": warden, "materials": {}, "mantle": null, "mantle_tool": null}
		hook._mount_mantle(warden, kit, rec)
		var tool := rec.mantle_tool as StandardMaterial3D
		_t.check("stage %d mounts tool" % stage, tool != null and rec.mantle != null)
		if tool != null:
			var surfaces := 0
			for group in rec.mantle:
				for mesh in group.find_children("*", "MeshInstance3D", true, false):
					for i in mesh.mesh.get_surface_count():
						if HeroAssets.slot_of(mesh.mesh, i) != "mantle_tool":
							continue
						surfaces += 1
						_t.check("tool override", mesh.get_surface_override_material(i) == tool)
						var authored := mesh.mesh.surface_get_material(i) as StandardMaterial3D
						if stage in [2, 4]:
							_t.check("authored stripes reach albedo and emission", authored != null and authored.albedo_texture != null
								and tool.albedo_texture == authored.albedo_texture and tool.emission_texture == authored.albedo_texture)
			_t.check("tool surfaces present", surfaces > 0)
			if stage in [2, 4] and tool.albedo_texture != null:
				var image := tool.albedo_texture.get_image()
				_t.check("stripe texture has distinct bands", absf(image.get_pixel(8, 8).r - image.get_pixel(72, 8).r) > 0.4)
				_t.eq("stripe bands run diagonally", image.get_pixel(8, 8), image.get_pixel(16, 16))
			for fraction in [0.0, 0.25, 0.5, 1.0]:
				warden._charging = fraction > 0.0
				warden._charge_time = warden._charge_len * fraction
				WardenDress.update_mantle(rec)
				_t.near("stage %d emission follows charge %.2f" % [stage, fraction], tool.emission_energy_multiplier, warden.charge_fraction() * 2.0)
				if stage in [2, 4]:
					_t.eq("texture hue is not multiplied by hazard", tool.emission, Color.WHITE)
					_t.near("stripe brightness follows charge", tool.albedo_color.r, lerpf(0.03, 1.0, fraction))
			warden._posture.staggered = true
			WardenDress.update_mantle(rec)
			_t.near("stagger turns tools dark", tool.emission_energy_multiplier, 0.0)
		kit.free()
		warden.free()
	hook.free()
	quit(_t.verdict())
