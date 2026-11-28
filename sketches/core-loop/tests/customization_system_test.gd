extends SceneTree

const Cosmetics := preload("res://src/core/cosmetics.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Events := preload("res://src/core/game_events.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Registry := preload("res://tests/support/content_registry.gd")
const T := preload("res://tests/support/t.gd")

const PILOT := "pylon_engineer"
const ITEMS := {"paint": "paint_any_night", "trail": "trail_salt_skip", "decal": "decal_fern", "companion_paint": "companion_paint_night"}

var _t := T.new("customization_system_test")
var _serial := 0


func _initialize() -> void:
	_roundtrip()
	_unlocks()
	_backfill()
	_assets()
	_validation()
	for table in ["achievements.ROWS", "cosmetics.ROWS"]:
		print("CUS hash %s: %s" % [table, Registry.digest(Registry.snapshot()[table])])
	quit(_t.verdict())


func _fresh() -> Profile:
	_serial += 1
	var store := Profile.new("user://cus-%d-%d.json" % [OS.get_process_id(), _serial])
	_t.check("fresh store loads", store.load_profile())
	return store


func _roundtrip() -> void:
	var store := _fresh()
	for slot in ITEMS:
		var id: String = ITEMS[slot]
		var owner := Cosmetics.owner_for(PILOT, slot)
		_t.check("locked %s cannot equip" % slot, not Customize.equip(store, owner, slot, id))
		_t.eq("refusal leaves %s empty" % slot, store.equipped(owner, slot), "")
		store.unlock_cosmetic(id)
		_t.check("owned %s equips and saves" % slot, Customize.equip(store, owner, slot, id))
	var reload := Profile.new(store.path)
	_t.check("fresh store reloads", reload.load_profile())
	for slot in ITEMS:
		_t.eq("CUS-1 reload %s" % slot, reload.equipped(Cosmetics.owner_for(PILOT, slot), slot), ITEMS[slot])
	_t.eq("SPIL-9 paint is not stored on pilot", reload.equipped(PILOT, "companion_paint"), "")
	_t.check("wrong slot refused", not Customize.equip(reload, PILOT, "decal", "trail_salt_skip"))
	_t.check("wrong pilot refused", not Customize.equip(reload, "runner_gunner", "paint", "paint_sable_lagoon"))
	_t.check("unknown owner refused", not Customize.equip(reload, "not_a_pilot", "trail", "trail_salt_skip"))
	_t.check("companion slot refuses pilot", not Customize.equip(reload, PILOT, "companion_paint", "companion_paint_night"))
	for slot in ITEMS:
		_t.check("clear %s saves" % slot, Customize.equip(reload, Cosmetics.owner_for(PILOT, slot), slot, ""))
	var cleared := Profile.new(store.path)
	cleared.load_profile()
	for slot in ITEMS:
		_t.eq("clear %s reloads" % slot, cleared.equipped(Cosmetics.owner_for(PILOT, slot), slot), "")
	_t.check("starter paint needs no unlock", Customize.equip(cleared, PILOT, "paint", "paint_sable_lagoon"))


func _trigger(events, row: Dictionary, amount := 1) -> void:
	match row["on"]:
		"run_ended": events.run_ended.emit(false)
		"harpoon_smashed": events.harpoon_smashed.emit(null, Vector3.ZERO, 24.0)
		"slammed": events.slammed.emit(Vector3.ZERO, 1.0, 1.0)
		"enemy_killed": events.enemy_killed.emit("machine", Vector3.ZERO, 1)
		"synergy_discovered": events.synergy_discovered.emit("cus", "combat", true)
		"milestone_won": events.milestone_won.emit("cus")
		"rescue_completed": events.rescue_completed.emit("rivet")
		"grapple_released": events.grapple_released.emit()
		"cogs_collected": events.cogs_collected.emit(amount, amount)
		"world_entered": events.world_entered.emit(row["where"]["world"])
		"jumped": events.jumped.emit(false)
		"scrap_collected": events.scrap_collected.emit(amount, Vector3.ZERO, amount)
		"escape_window": events.escape_window.emit(2.0)
		"special_used": events.special_used.emit("cus", Vector3.ZERO)
		"beacon_unsealed": events.beacon_unsealed.emit(0)
		_: _t.check("known trigger", false, row["on"])


func _unlocks() -> void:
	var tested := 0
	for id in Achievements.ids():
		if not id.begins_with("ach_d7_"):
			continue
		tested += 1
		var store := _fresh()
		var bus := Events.new()
		var listener := Progress.new()
		var row := Achievements.row(id)
		listener.rows = {id: row}
		listener.setup(bus, null, store, func(): return 1234.0)
		var reward: String = row["reward"]["cosmetic"]
		var slot: String = Cosmetics.row(reward)["slot"]
		var owner := Cosmetics.owner_for(PILOT, slot)
		_t.check("%s is locked" % reward, not Customize.equip(store, owner, slot, reward))
		if row.has("where"):
			match row["on"]:
				"synergy_discovered": bus.synergy_discovered.emit("repeat", "combat", false)
				"rescue_completed": bus.rescue_completed.emit("dig")
				"world_entered": bus.world_entered.emit(1)
			_t.eq("%s ignores other facts" % id, listener.count_of(id), 0.0)
		var threshold := int(row["count"])
		if row.has("sum"):
			_trigger(bus, row, threshold - 1)
		else:
			for i in threshold - 1:
				_trigger(bus, row)
		_t.check("%s stays locked below threshold" % id, not store.earned(id) and not store.has_cosmetic(reward))
		_trigger(bus, row)
		_t.check("CUS-2 %s earns mapped item through real bus" % id, store.earned(id) and store.has_cosmetic(reward))
		_t.check("%s equips after earn" % reward, Customize.equip(store, owner, slot, reward))
		var saved := Profile.new(store.path)
		saved.load_profile()
		_t.check("%s reward and earn survive reload" % id, saved.earned(id) and saved.has_cosmetic(reward))
		listener.free()
		bus.free()
	_t.eq("all twenty new triggers exercised", tested, 20)


func _backfill() -> void:
	var store := _fresh()
	var bus := Events.new()
	var listener := Progress.new()
	listener.setup(bus, null, store)
	_t.eq("no history means no retroactive grants", Customize.backfill(store, listener), 0)
	store.earn("kills_1000", 10.0)
	store.earn("highdraft_reached", 10.0)
	_t.eq("earned ids without recorded counters do not invent stats", Customize.backfill(store, listener), 0)
	store.set_stat("ach.kills_1000", 500.0)
	store.set_stat("ach.codex_keeper", 5.0)
	store.set_stat("ach.rivet_rescued", 1.0)
	store.set_stat("ach.highdraft_reached", 1.0)
	_t.eq("recorded lower bounds grant five proven rows", Customize.backfill(store, listener), 5)
	_t.check("250 and 500 kill rewards backfill", store.has_cosmetic("trail_forge_chips") and store.has_cosmetic("companion_paint_forge"))
	_t.check("five discoveries backfill only the five row", store.has_cosmetic("trail_moth_tuft") and not store.has_cosmetic("companion_paint_moth"))
	_t.check("recorded rescue and world backfill", store.has_cosmetic("decal_fern") and store.has_cosmetic("decal_moth"))
	_t.check("no guessed Dig or five-run grant", not store.has_cosmetic("decal_mushroom") and not store.has_cosmetic("decal_patch"))
	_t.eq("retroactive grants are idempotent", Customize.backfill(store, listener), 0)
	_t.eq("partial recorded progress seeds new counter", store.stat("ach.ach_d7_moth_grey"), 5.0)
	listener.free()
	bus.free()


func _assets() -> void:
	var resolver := Cosmetics.new()
	var paths := Cosmetics.asset_paths()
	for slot in ["trail", "decal", "companion_paint"]:
		var id: String = ITEMS[slot]
		var asset: String = Cosmetics.row(id)["asset"]
		_t.eq("CUS-5 missing %s falls back" % slot, resolver.resolve(id, {}), {})
		var warnings: int = resolver._warned.size()
		resolver.resolve(id, {})
		_t.eq("CUS-5 repeated %s warns once" % slot, resolver._warned.size(), warnings)
		_t.check("missing %s names its asset" % slot, resolver._warned.has(Cosmetics.row(id)["asset"]))
		var resource = load(paths[asset])
		_t.check("delivered %s resolves by art id" % slot, resolver.resolve(id, paths).get("resource") == resource)
		_t.eq("malformed %s resource falls back" % slot, resolver.resolve(id, {asset: Gradient.new()}), {})
	_t.eq("missing resource path falls back", resolver.resolve("trail_salt_skip", {"trail_salt_skip": "res://missing-art.tres"}), {})
	_t.eq("empty selection has no warning", resolver.resolve("", {}), {})
	_t.eq("only three absent asset ids warned", resolver._warned.size(), 3)
	_t.eq("existing paint needs no art", resolver.resolve("paint_any_salt", {}), Cosmetics.row("paint_any_salt"))
	_t.eq("empty trail scene falls back without instantiation errors", resolver.resolve("trail_salt_skip", {"trail_salt_skip": PackedScene.new()}), {})
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	mesh.owner = root
	var malformed := PackedScene.new()
	malformed.pack(root)
	root.free()
	_t.eq("materialless trail falls back without a crash", resolver.resolve("trail_salt_skip", {"trail_salt_skip": malformed}), {})
	_t.eq("malformed asset keeps the same one warning", resolver._warned.size(), 3)
	var second_resolver := Cosmetics.new()
	second_resolver.resolve("trail_salt_skip", {})
	_t.eq("multiple consumers emit one warning for the same asset", Cosmetics._warning_counts["trail_salt_skip"], 1)
	# Re-pinned 2026-10-10 (w13 B5, CUSTOMIZE.md section 9): PENDING_ART rows have no art yet and are exempt;
	# every other non-paint row still resolves to delivered art.
	var delivered := 0
	for id in Cosmetics.ids():
		if Cosmetics.row(id)["slot"] != "paint" and not Cosmetics.PENDING_ART.has(id):
			delivered += 1
			_t.check("every delivered item resolves: " + id, not resolver.resolve(id, paths).is_empty())
	_t.check("delivered rows were checked", delivered >= 20, str(delivered))


# 2026-10-11 (w13 KF3 kf3-swarm): event_kinds.WORLD_ROWS gains hoist_ride and pool_swell; its digest moves
# f3da5b1a -> 9e6705954294b3b6a5ec228be59a94df7aa6e64c9bc31b7353a96a8ded8cce4e. The pin is
# content_registry.gd GOLDEN_HASHES, outside this unit's fence, for the coordinator's merge re-pin.
func _validation() -> void:
	var snapshot := Registry.snapshot()
	for table in Registry.GOLDEN_HASHES:
		_t.eq("content pin unchanged or explicitly authorized: " + table, Registry.digest(snapshot[table]), Registry.GOLDEN_HASHES[table])
	var pilots: Array = ClassDef.all().map(func(d): return d.id)
	_t.eq("cosmetics validate", Cosmetics.validate(Cosmetics.ROWS, pilots), [])
	_t.eq("achievements validate", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots, Cosmetics.ids()), [])
	for slot in ["trail", "decal", "companion_paint"]:
		var bad := Cosmetics.ROWS.duplicate(true)
		bad[ITEMS[slot]].erase("asset")
		_t.check("%s without asset is rejected" % slot, not Cosmetics.validate(bad, pilots).is_empty())
	# Re-pinned 2026-10-10 (w13 B5, CUSTOMIZE.md section 3): the atlas grows to 16 tiles, so 8 is valid and 16 is not.
	var bad := Cosmetics.ROWS.duplicate(true)
	bad["decal_fern"]["mask"] = 16
	_t.check("invalid decal tile rejected", not Cosmetics.validate(bad, pilots).is_empty())
	var eight := Cosmetics.ROWS.duplicate(true)
	eight["decal_fern"]["mask"] = 8
	_t.eq("decal tile 8 is valid", Cosmetics.validate(eight, pilots), [])
