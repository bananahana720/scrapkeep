extends RefCounted

const WorldLook := preload("res://src/presentation/world_look.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
# Quality knobs only; each world's light and air numbers live in world_look.gd. The shipped high
# takes the parked target look (wave 12): 4096 shadow atlas, the SSAO tuning, the sun's shadow
# properties and the surface swap to VX-SURF's slots (palette.target_surface_material). R1's -28 degree sun put play ground in the western rim's shadow, so
# the sun direction stays the world row's -36 degree pin. No global shaft veil: world air is the
# per-world volumetric row, entered with the world.
const HIGH := {"ssao": true, "glow": true, "shadow_distance": 180.0, "shadow_mode": 1,
	"scenery_distance": 780.0, "lod_threshold": 1.0, "msaa": 2, "ssao_quality": 2, "air": true,
	"sdfgi": false, "ssil": false, "volumetric_fog": false,
	"shadow_atlas": 4096, "sdfgi_rays": 1, "ssil_quality": 2,
	"fog_volume_size": 64, "fog_volume_depth": 64,
	"material_detail": true, "material_relief": true,
	"set_dressing": true, "air_motes": true, "air_streaks": true,
	"material_ground": true, "material_rock": true, "material_dam": true,
	"environment": {"ssao_radius": 0.55, "ssao_intensity": 1.25, "ssao_detail": 0.40},
	"sun_properties": {"light_angular_distance": 0.0, "shadow_normal_bias": 0.65,
		"directional_shadow_split_1": 0.18},
	"sky_properties": {},
}
# Settings are applied on bind or an explicit preset change, never polled each frame.
# target is the lab name the shipped high grew from; it stays an alias so --preset=target and the
# files that still gate on the name keep working.
const PRESETS := {
	"high": HIGH,
	"low": {"ssao": false, "glow": false, "shadow_distance": 95.0, "shadow_mode": 1,
		"scenery_distance": 520.0, "lod_threshold": 4.0, "msaa": 1, "ssao_quality": 0, "air": false},
	"target": HIGH,
}
static var current := "high"
static var _worlds: Array = []
static var _scenery: Array = []
static var _target_server_active := false
static var _materials: Array = []
static var _dressing_hosts: Array[WeakRef] = []
static var _lighting: Array[Dictionary] = []


static func reset_for_tests() -> void:
	_worlds.clear()
	_scenery.clear()
	_materials.clear()
	_dressing_hosts.clear()
	_lighting.clear()
	if _target_server_active:
		_restore_target_server()
	current = "high"

static func apply(preset: String) -> bool:
	if not PRESETS.has(preset):
		return false
	current = preset
	_worlds = _worlds.filter(func(w): return w.sun.get_ref() != null)
	for world in _worlds:
		_apply_world(world)
	_scenery = _scenery.filter(func(w): return w.get_ref() != null)
	for ref in _scenery:
		_apply_scenery(ref.get_ref())
	_materials = _materials.filter(func(w): return w.view.get_ref() != null)
	for binding in _materials:
		_apply_material(binding)
	_dressing_hosts = _dressing_hosts.filter(func(ref): return ref.get_ref() != null)
	for ref in _dressing_hosts:
		ref.get_ref()._sync_dressing()
	return true

static func register_dressing_host(host: Node) -> void:
	if not _dressing_hosts.any(func(ref): return ref.get_ref() == host):
		_dressing_hosts.append(weakref(host))
		var on_exit := _unregister_dressing_host.bind(host.get_instance_id())
		if not host.tree_exiting.is_connected(on_exit):
			host.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
	host._sync_dressing()

static func _unregister_dressing_host(id: int) -> void:
	_dressing_hosts = _dressing_hosts.filter(func(ref):
		var host = ref.get_ref()
		return host != null and host.get_instance_id() != id)


# Restore one shared baseline, then compose live overrides in entry order. An older
# arena can leave after a new stage has entered without restoring over that stage.
static func set_lighting(owner: Node, environment: Environment, values: Dictionary,
		lights: Array = [], slot: String = "", look: Dictionary = {}) -> Dictionary:
	var world := _lighting_for(environment)
	if world.is_empty():
		world = {"environment": weakref(environment), "defaults": [], "overrides": []}
		_lighting.append(world)
	var previous := {}
	for key in values:
		previous[key] = environment.get(key)
	_capture_lighting_changes(world)
	var properties := []
	for row in world.overrides:
		if not slot.is_empty() and row.slot == slot:
			properties = row.properties
	_restore_lighting(world)
	var id := owner.get_instance_id()
	world.overrides = world.overrides.filter(func(row):
		return row.id != id and (slot.is_empty() or row.slot != slot))
	if properties.is_empty():
		_lighting_defaults(world, environment, values)
		properties.append({"object": weakref(environment), "values": values})
		for light in lights:
			_lighting_defaults(world, light.object, light.values)
			properties.append({"object": weakref(light.object), "values": light.values})
	world.overrides.append({"id": id, "slot": slot, "properties": properties, "look": look})
	var on_exit := release_lighting.bind(id)
	if not owner.tree_exiting.is_connected(on_exit):
		owner.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
	_apply_lighting(world)
	return previous


static func release_lighting(id: int) -> void:
	for world in _lighting.duplicate():
		if world.overrides.any(func(row): return row.id == id):
			world.overrides = world.overrides.filter(func(row): return row.id != id)
			_update_lighting(world)


static func clear_lighting(environment: Environment, slot: String) -> void:
	var world := _lighting_for(environment)
	if not world.is_empty():
		world.overrides = world.overrides.filter(func(row): return row.slot != slot)
		_update_lighting(world)


# A stage or arena enters its world look row: light, fog and, on presets with air, the world's
# volumetric air. The row lives on the owner's own WorldLook node (set_lighting replaces every row
# of one owner, P-LIGHT's fix round), so it leaves with the owner. Stage rows use slot "world",
# arena rows slot "arena": both write the same keys, so an arena covers its stage and uncovers it.
static func enter_world(owner: Node, environment: Environment, look: Dictionary, slot := "world") -> void:
	clear_lighting(environment, slot)
	if look.is_empty() or environment == null:
		return
	var holder := owner.get_node_or_null(WorldLook.NODE) as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = WorldLook.NODE
		owner.add_child(holder)
	var sun: DirectionalLight3D = null
	for world in _worlds:
		if world.environment == environment and world.sun.get_ref() != null:
			sun = world.sun.get_ref()
	set_lighting(holder, environment, WorldLook.environment(look, PRESETS[current].air),
		WorldLook.lights(look, sun) + WorldLook.sky_rows(look), slot, look)


static func _lighting_for(environment: Environment) -> Dictionary:
	for world in _lighting:
		if world.environment.get_ref() == environment:
			return world
	return {}


static func _lighting_defaults(world: Dictionary, object: Object, values: Dictionary) -> void:
	var saved := {}
	for row in world.defaults:
		if row.object.get_ref() == object:
			saved = row.values
			break
	if saved.is_empty():
		world.defaults.append({"object": weakref(object), "values": saved})
	for key in values:
		if not saved.has(key):
			saved[key] = object.get(key)


static func _write_lighting(properties: Array) -> void:
	for row in properties:
		var object = row.object.get_ref()
		if object != null:
			for key in row.values:
				object.set(key, row.values[key])


# Explicit edits to the live light belong to the active override, or to the baseline
# when that property has no override. Re-entering a named world keeps those edits.
static func _capture_lighting_changes(world: Dictionary) -> void:
	for row in world.defaults:
		var object = row.object.get_ref()
		if object == null:
			continue
		for key in row.values:
			var values: Dictionary = row.values
			for override in world.overrides:
				for properties in override.properties:
					if properties.object.get_ref() == object and properties.values.has(key):
						values = properties.values
			values[key] = object.get(key)


static func _restore_lighting(world: Dictionary) -> void:
	_write_lighting(world.defaults)


static func _apply_lighting(world: Dictionary) -> void:
	for row in world.overrides:
		_write_lighting(row.properties)


static func _update_lighting(world: Dictionary) -> void:
	_restore_lighting(world)
	_apply_lighting(world)
	if world.overrides.is_empty():
		_lighting.erase(world)


static func bind(environment: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset=") and PRESETS.has(arg.trim_prefix("--preset=")):
			current = arg.trim_prefix("--preset=")
	var world := {"environment": environment, "sun": weakref(sun), "viewport": weakref(viewport)}
	_worlds.append(world)
	_apply_world(world)

static func register_scenery(view: GeometryInstance3D) -> void:
	_scenery.append(weakref(view))
	_apply_scenery(view)
	_bind_scenery_material.call_deferred(weakref(view))

static func _apply_scenery(view: GeometryInstance3D) -> void:
	if view.has_meta(RecipeProps.META_FADE):
		return
	view.visibility_range_end = PRESETS[current].scenery_distance
	view.visibility_range_end_margin = 30.0
	view.lod_bias = 1.0 / PRESETS[current].lod_threshold

static func _apply_world(world: Dictionary) -> void:
	var lighting := _lighting_for(world.environment)
	if not lighting.is_empty():
		_capture_lighting_changes(lighting)
		_restore_lighting(lighting)
	_restore_target(world)
	var spec: Dictionary = PRESETS[current]
	for row in lighting.get("overrides", []):
		if not row.look.is_empty():
			WorldLook.follow_air(row.properties[0].values, row.look, spec.air)
			_lighting_defaults(lighting, row.properties[0].object.get_ref(), row.properties[0].values)
	var look: Dictionary = WorldLook.ROWS[1]
	if not spec.has("shadow_atlas") and _target_server_active:
		_restore_target_server()
	var env: Environment = world.environment
	var sun: DirectionalLight3D = world.sun.get_ref()
	var viewport: Viewport = world.viewport.get_ref()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = look.ambient
	env.ambient_light_sky_contribution = 0.25
	env.ambient_light_energy = look.energy
	# AgX with a fixed exposure; auto exposure and SDFGI/SSIL/SSR stay off.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = look.exposure
	env.tonemap_agx_white = 16.29
	env.tonemap_agx_contrast = 1.25
	env.ssao_enabled = spec.ssao
	env.ssao_radius = 0.45
	env.ssao_intensity = 1.15
	env.ssao_power = 1.25
	env.ssao_detail = 0.35
	env.ssao_sharpness = 0.85
	env.ssao_light_affect = 0.05
	env.ssao_ao_channel_affect = 0.0
	RenderingServer.environment_set_ssao_quality(spec.ssao_quality, true, 0.5, 2.0, 50.0, 300.0)
	env.adjustment_enabled = true
	env.adjustment_saturation = look.saturation
	env.sdfgi_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.glow_enabled = spec.glow
	env.glow_intensity = 0.18
	env.glow_hdr_threshold = 1.5
	env.fog_enabled = true
	env.fog_density = look.fog.density
	env.fog_light_color = look.fog.color
	env.fog_light_energy = 0.75
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.0
	env.fog_sun_scatter = 0.25
	env.volumetric_fog_enabled = false
	sun.rotation_degrees = look.sun_rotation
	sun.light_color = look.sun_color
	sun.directional_shadow_split_1 = 0.18
	# PCSS (angular distance above 0) samples the hoop's shadow on the pilot's head with visible
	# noise; the smooth high-quality filter blurs it without any.
	sun.light_angular_distance = 0.0
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	sun.shadow_blur = 1.0
	_apply_fill(sun, look)
	sun.light_energy = look.sun_energy
	sun.directional_shadow_max_distance = spec.shadow_distance
	sun.directional_shadow_mode = spec.shadow_mode
	sun.shadow_normal_bias = 0.65
	sun.directional_shadow_blend_splits = true
	if viewport != null:
		viewport.msaa_3d = spec.msaa
		viewport.mesh_lod_threshold = spec.lod_threshold
	if spec.has("shadow_atlas"):
		_apply_target(world, spec, env, sun)
	if not lighting.is_empty():
		for row in lighting.defaults:
			var object = row.object.get_ref()
			if object != null:
				for key in row.values:
					row.values[key] = object.get(key)
		_apply_lighting(lighting)


# One shadowless cool directional fill opposite the sun (LIGHTING-TARGETS: elevation 50,
# azimuth 298). It is a sibling of the world sun, so the sun stays the only shadow caster.
static func _apply_fill(sun: DirectionalLight3D, look: Dictionary) -> void:
	var parent := sun.get_parent()
	if parent == null:
		return
	var fill := parent.get_node_or_null("SkyFill") as DirectionalLight3D
	if fill == null:
		fill = DirectionalLight3D.new()
		fill.name = "SkyFill"
		fill.shadow_enabled = false
		fill.rotation_degrees = Vector3(look.fill_pitch, look.sun_rotation.y + 180.0, 0.0)
		fill.light_color = look.fill_color
		fill.light_specular = 0.0
		parent.add_child(fill)
	# Opposite the sun's yaw, so the wall faces the key misses get cool light.
	fill.rotation_degrees = Vector3(look.fill_pitch, look.sun_rotation.y + 180.0, 0.0)
	fill.light_energy = look.fill


# Snapshot only the renderer properties target overrides. Returning to either established
# preset restores untouched defaults too, including the terrain's existing sky resource.
static func _target_properties(world: Dictionary, object: Object, values: Dictionary) -> void:
	if object == null:
		return
	var saved := {}
	for key in values:
		saved[key] = object.get(key)
		object.set(key, values[key])
	world.target_defaults.append({"object": object, "values": saved})


static func _restore_target(world: Dictionary) -> void:
	for row in world.get("target_defaults", []):
		if is_instance_valid(row.object):
			for key in row.values:
				row.object.set(key, row.values[key])
	world.erase("target_defaults")


static func _apply_target(world: Dictionary, spec: Dictionary, env: Environment, sun: DirectionalLight3D) -> void:
	world.target_defaults = []
	_target_properties(world, env, spec.environment)
	_target_properties(world, env, {"sdfgi_enabled": spec.sdfgi,
		"ssil_enabled": spec.ssil, "volumetric_fog_enabled": spec.volumetric_fog})
	_target_properties(world, sun, spec.sun_properties)
	_target_properties(world, env.sky, spec.sky_properties)
	RenderingServer.directional_shadow_atlas_set_size(spec.shadow_atlas, true)
	RenderingServer.environment_set_sdfgi_ray_count(spec.sdfgi_rays)
	RenderingServer.environment_set_ssil_quality(spec.ssil_quality, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(spec.fog_volume_size, spec.fog_volume_depth)
	_target_server_active = true


static func _restore_target_server() -> void:
	var shadows := "rendering/lights_and_shadows/directional_shadow/"
	RenderingServer.directional_shadow_atlas_set_size(ProjectSettings.get_setting(shadows + "size"), ProjectSettings.get_setting(shadows + "16_bits"))
	RenderingServer.environment_set_sdfgi_ray_count(ProjectSettings.get_setting("rendering/global_illumination/sdfgi/probe_ray_count"))
	var ssil := "rendering/environment/ssil/"
	RenderingServer.environment_set_ssil_quality(ProjectSettings.get_setting(ssil + "quality"), ProjectSettings.get_setting(ssil + "half_size"), ProjectSettings.get_setting(ssil + "adaptive_target"), ProjectSettings.get_setting(ssil + "blur_passes"), ProjectSettings.get_setting(ssil + "fadeout_from"), ProjectSettings.get_setting(ssil + "fadeout_to"))
	var fog := "rendering/environment/volumetric_fog/"
	RenderingServer.environment_set_volumetric_fog_volume_size(ProjectSettings.get_setting(fog + "volume_size"), ProjectSettings.get_setting(fog + "volume_depth"))
	_target_server_active = false


# Bind after the scenery builder's opaque merge. Changing the input materials before
# that merge would split its batch and change the scene's geometry/draw structure.
static func _bind_scenery_material(ref: WeakRef) -> void:
	var view := ref.get_ref() as MeshInstance3D
	if view == null:
		return
	match String(view.name):
		"SandstoneShoulders":
			_bind_material(view, "rock")
		"DamAndLedgeDressing", "DamDetail":
			_bind_material(view, "dam")


static func register_ground(view: MeshInstance3D) -> void:
	_bind_material(view, "ground")


# Keep a world-specific ground finish through preset changes, including target.
static func set_ground_material(view: MeshInstance3D, material: Material) -> void:
	for binding in _materials:
		if binding.view.get_ref() == view:
			binding.override = material
			binding.originals = [material]
			binding.target_override = material
			_apply_material(binding)
			return
	view.material_override = material
	register_ground(view)
	_materials.back().target_override = material
	_apply_material(_materials.back())


static func _bind_material(view: MeshInstance3D, role: String) -> void:
	var surfaces := []
	var originals := []
	for i in view.mesh.get_surface_count():
		surfaces.append(view.get_surface_override_material(i))
		originals.append(view.get_active_material(i))
	var binding := {"view": weakref(view), "role": role,
		"override": view.material_override, "surfaces": surfaces, "originals": originals}
	_materials.append(binding)
	_apply_material(binding)


static func _apply_material(binding: Dictionary) -> void:
	var view := binding.view.get_ref() as MeshInstance3D
	if view == null:
		return
	var spec: Dictionary = PRESETS[current]
	if not spec.get("material_" + binding.role, false):
		view.material_override = binding.override
		for i in binding.surfaces.size():
			view.set_surface_override_material(i, binding.surfaces[i])
		return
	if binding.has("target_override"):
		view.material_override = binding.target_override
		return
	var palette := preload("res://src/core/palette.gd")
	# A prebuilt slot resource a dressing host put on the view (the Dig's stone beds) is already the
	# shipped surface; swapping it for the binding's original role would erase the Dig's strata.
	for material in [view.material_override, binding.override]:
		if material != null and palette.is_slot_resource(material):
			view.material_override = material
			return
	for i in binding.originals.size():
		var material := palette.target_surface_material(binding.role, binding.originals[i])
		material.set_shader_parameter("detail_enabled", spec.material_detail)
		material.set_shader_parameter("relief_enabled", spec.material_relief)
		if binding.override != null:
			view.material_override = material
			break
		view.set_surface_override_material(i, material)
