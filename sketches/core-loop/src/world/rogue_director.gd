extends RefCounted


const ParkSchema := preload("res://src/world/park/park_schema.gd")

const SCHEMA := "scrapkeep-sites/1"
const KINDS := {1: "rogue_crane", 2: "rogue_skip", 3: "rogue_tender"}
const TRIGGER_PAD_M := 25.0


static func sites_path(map_id: String) -> String:
	return "res://assets/park/%s/sites.json" % map_id


static func read_sites(map_id: String) -> Dictionary:
	if map_id == "" or not FileAccess.file_exists(sites_path(map_id)):
		return {}
	return ParkSchema.read_file(sites_path(map_id))["data"]


static func plan(seed_value: int, world: int, sites_doc: Dictionary) -> Dictionary:
	if not KINDS.has(world) or sites_doc.get("schema") != SCHEMA:
		return {}
	var sites: Array = sites_doc.get("miniboss_sites", [])
	if sites.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var site: Dictionary = sites[rng.randi_range(0, sites.size() - 1)]
	var radius := float(site.get("radius_m", 20.0))
	return {"kind": KINDS[world], "site": String(site.get("id", "")),
		"at": Vector2(float(site.at[0]), float(site.at[1])), "radius_m": radius,
		"trigger_m": radius + TRIGGER_PAD_M}


static func wakes(plan_row: Dictionary, ball: Vector3) -> bool:
	if plan_row.is_empty():
		return false
	var at: Vector2 = plan_row.at
	return Vector2(ball.x, ball.z).distance_to(at) <= float(plan_row.trigger_m)
