extends SceneTree

# CUSTOMIZE.md sections 2, 3 and 9: the eight slots, who wears each, the one ownership rule
# (owner_for, fits, worn), the new validate rules and the page's equip refusals.

const Cosmetics := preload("res://src/core/cosmetics.gd")
const CosmeticWear := preload("res://src/core/cosmetic_wear.gd")
const Profile := preload("res://src/core/profile.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const T := preload("res://tests/support/t.gd")

const SABLE := "pylon_engineer"
const RIVET := "runner_gunner"

var _t := T.new("customize_slots_test")
var _serial := 0


func _initialize() -> void:
	_slots_and_owners()
	_fits()
	_worn()
	_validate_rules()
	_equip_refusals()
	quit(_t.verdict())


func _fresh() -> Profile:
	_serial += 1
	var store := Profile.new("user://cslot-%d-%d.json" % [OS.get_process_id(), _serial])
	store.load_profile()
	return store


func _pilots() -> Array:
	return ClassDef.all().map(func(d): return d.id)


# A table with rows of the four new slots, so fits and worn are tested on real ids.
func _with_new_slots() -> Dictionary:
	var rows := Cosmetics.ROWS.duplicate(true)
	rows["shell_sable_test"] = {"slot": "shell", "pilot": SABLE, "name": "Test Rig", "starter": false, "tint": Color("3f6b4f"), "asset": "shell_sable_test"}
	rows["outfit_rivet_test"] = {"slot": "outfit", "pilot": RIVET, "name": "Test Hood", "starter": false, "tint": Color("3f6b4f"), "asset": "outfit_rivet_test"}
	rows["bay_decor_test"] = {"slot": "bay_decor", "pilot": "", "name": "Test Trophy", "starter": false, "tint": Color("3f6b4f"), "asset": "bay_decor_test"}
	return rows


func _slots_and_owners() -> void:
	_t.eq("eight slots", Cosmetics.SLOTS, ["paint", "trail", "decal", "companion_paint", "outfit", "shell", "companion_skin", "bay_decor"])
	var want := {"paint": SABLE, "trail": SABLE, "decal": SABLE, "companion_paint": "spil9", "outfit": SABLE, "shell": SABLE, "companion_skin": "spil9", "bay_decor": "bay"}
	for slot in Cosmetics.SLOTS:
		_t.eq("owner_for %s" % slot, Cosmetics.owner_for(SABLE, slot), want[slot])
	_t.eq("16 decal tiles", Cosmetics.MASK_TILES, 16)
	_t.eq("cosmetics validate", Cosmetics.validate(Cosmetics.ROWS, _pilots()), [])
	_t.eq("a table with all eight slots validates", Cosmetics.validate(_with_new_slots(), _pilots()), [])


func _fits() -> void:
	# fits reads the shipped table; the companion skin row is shipped (pending art).
	_t.check("companion skin fits spil9", Cosmetics.fits("companion_skin_till_bell", "spil9", "companion_skin"))
	_t.check("companion skin refuses a pilot", not Cosmetics.fits("companion_skin_till_bell", SABLE, "companion_skin"))
	_t.check("companion skin refuses the bay", not Cosmetics.fits("companion_skin_till_bell", "bay", "companion_skin"))
	_t.check("companion paint fits spil9", Cosmetics.fits("companion_paint_night", "spil9", "companion_paint"))
	_t.check("companion paint refuses a pilot", not Cosmetics.fits("companion_paint_night", SABLE, "companion_paint"))
	_t.check("an any-pilot trail fits a pilot", Cosmetics.fits("trail_any_downbeat", RIVET, "trail"))
	_t.check("a pilot trail refuses spil9", not Cosmetics.fits("trail_salt_skip", "spil9", "trail"))
	_t.check("a pilot trail refuses the bay", not Cosmetics.fits("trail_salt_skip", "bay", "trail"))
	_t.check("a pilot paint fits its pilot", Cosmetics.fits("paint_sable_lagoon", SABLE, "paint"))
	_t.check("a pilot paint refuses another pilot", not Cosmetics.fits("paint_sable_lagoon", RIVET, "paint"))
	_t.check("a row refuses the wrong slot", not Cosmetics.fits("decal_fern", SABLE, "trail"))
	_t.check("an unknown id fits nothing", not Cosmetics.fits("not_a_row", SABLE, "paint"))
	_t.check("a pilot slot refuses an empty owner", not Cosmetics.fits("trail_salt_skip", "", "trail"))


func _worn() -> void:
	var store := _fresh()
	_t.eq("nothing equipped wears nothing", CosmeticWear.worn(store, SABLE, "trail"), "")
	_t.eq("a null profile wears nothing", CosmeticWear.worn(null, SABLE, "trail"), "")
	store.equip(SABLE, "trail", "trail_salt_skip")
	_t.eq("an unowned equipped id is not worn", CosmeticWear.worn(store, SABLE, "trail"), "")
	store.unlock_cosmetic("trail_salt_skip")
	_t.eq("an owned fitting id is worn", CosmeticWear.worn(store, SABLE, "trail"), "trail_salt_skip")
	store.equip(SABLE, "paint", "paint_rivet_moss")
	_t.eq("a starter paint for another pilot is not worn", CosmeticWear.worn(store, SABLE, "paint"), "")
	store.equip(SABLE, "paint", "paint_sable_lagoon")
	_t.eq("a starter paint is worn without an unlock", CosmeticWear.worn(store, SABLE, "paint"), "paint_sable_lagoon")
	store.unlock_cosmetic("companion_skin_till_bell")
	store.equip("spil9", "companion_skin", "companion_skin_till_bell")
	_t.eq("spil9 wears an owned companion skin", CosmeticWear.worn(store, "spil9", "companion_skin"), "companion_skin_till_bell")
	store.equip(SABLE, "companion_skin", "companion_skin_till_bell")
	_t.eq("a pilot key never wears a companion skin", CosmeticWear.worn(store, SABLE, "companion_skin"), "")
	store.equip("bay", "bay_decor", "trail_salt_skip")
	_t.eq("the bay never wears a trail", CosmeticWear.worn(store, "bay", "bay_decor"), "")
	store.equip(SABLE, "trail", "unknown_trail")
	_t.eq("an unknown saved id is not worn and stays saved", CosmeticWear.worn(store, SABLE, "trail"), "")
	_t.eq("the unknown id is kept in the file", store.equipped(SABLE, "trail"), "unknown_trail")


func _bad(rows: Dictionary, id: String, change: Dictionary) -> Dictionary:
	var out := rows.duplicate(true)
	var r: Dictionary = out.get(id, {}).duplicate(true)
	for key in change:
		if change[key] == null:
			r.erase(key)
		else:
			r[key] = change[key]
	out[id] = r
	return out


func _validate_rules() -> void:
	var pilots := _pilots()
	var rows := _with_new_slots()
	var cases := {
		"an unknown slot": _bad(rows, "trail_salt_skip", {"slot": "hat"}),
		"a shell with no pilot": _bad(rows, "shell_sable_test", {"pilot": ""}),
		"an outfit with a pilot that does not exist": _bad(rows, "outfit_rivet_test", {"pilot": "nobody"}),
		"a companion skin naming a pilot": _bad(rows, "companion_skin_till_bell", {"pilot": SABLE}),
		"a bay decoration naming a pilot": _bad(rows, "bay_decor_test", {"pilot": SABLE}),
		"a decal mask of 16": _bad(rows, "decal_fern", {"mask": 16}),
		"a starter trail": _bad(rows, "trail_salt_skip", {"starter": true}),
		"a shell with no asset": _bad(rows, "shell_sable_test", {"asset": null}),
	}
	for label in cases:
		var problems := Cosmetics.validate(cases[label], pilots)
		_t.check("validate rejects %s" % label, not problems.is_empty(), str(problems))
	_t.eq("a decal mask of 15 is valid", Cosmetics.validate(_bad(rows, "decal_fern", {"mask": 15}), pilots), [])
	# PENDING_ART is a const; validate reads it, so a table missing a pending id is the typo case.
	# The pending id is read at runtime, as achievement_rows_case does for PENDING_PILOTS.
	var pending_ids: Array = Cosmetics.PENDING_ART.duplicate()
	if pending_ids.is_empty():
		_t.check("no pending art, so the real table has no pending typo", Cosmetics.validate(rows, pilots).is_empty())
		# Plant one through the test seam so the table checks below still run.
		Cosmetics._test_pending = ["outfit_rivet_hood"]
		pending_ids = ["outfit_rivet_hood"]
		_t.check("a planted pending id that is a row validates", Cosmetics.validate(rows, pilots).is_empty(), str(Cosmetics.validate(rows, pilots)))
	var waiting: String = pending_ids[0]
	var missing := rows.duplicate(true)
	missing.erase(waiting)
	var problems := Cosmetics.validate(missing, pilots)
	_t.check("validate rejects a PENDING_ART id that is not a row", problems.any(func(p): return String(p).contains("PENDING_ART id %s is not a row" % waiting)), str(problems))
	var starter_pending := _bad(rows, waiting, {"slot": "paint", "starter": true, "mask": null})
	problems = Cosmetics.validate(starter_pending, pilots)
	_t.check("validate rejects a PENDING_ART id that is a starter", problems.any(func(p): return String(p).contains("is a starter")), str(problems))
	Cosmetics._test_pending = []


func _equip_refusals() -> void:
	var store := _fresh()
	store.unlock_cosmetic("trail_salt_skip")
	store.unlock_cosmetic("companion_paint_night")
	store.unlock_cosmetic("companion_skin_till_bell")
	_t.check("an owned trail equips for a pilot", Customize.equip(store, SABLE, "trail", "trail_salt_skip"))
	_t.check("a locked item is refused", not Customize.equip(store, SABLE, "decal", "decal_fern"))
	_t.check("a wrong slot is refused", not Customize.equip(store, SABLE, "decal", "trail_salt_skip"))
	_t.check("an unknown slot is refused", not Customize.equip(store, SABLE, "hat", ""))
	_t.check("an unknown pilot is refused", not Customize.equip(store, "nobody", "trail", "trail_salt_skip"))
	_t.check("an empty owner is refused", not Customize.equip(store, "", "trail", ""))
	_t.check("companion paint refuses a pilot owner", not Customize.equip(store, SABLE, "companion_paint", "companion_paint_night"))
	_t.check("a pilot slot refuses spil9", not Customize.equip(store, "spil9", "trail", "trail_salt_skip"))
	_t.check("bay decoration refuses spil9", not Customize.equip(store, "spil9", "bay_decor", ""))
	_t.check("bay decoration clears for the bay", Customize.equip(store, "bay", "bay_decor", ""))
	# With PENDING_ART empty, the test seam plants the Till Bell so the refusal path still runs.
	var waiting_ids: Array = Cosmetics.PENDING_ART.duplicate()
	if waiting_ids.is_empty():
		Cosmetics._test_pending = ["companion_skin_till_bell"]
		waiting_ids = ["companion_skin_till_bell"]
	for waiting in waiting_ids:
		store.unlock_cosmetic(waiting)
		var row := Cosmetics.row(waiting)
		_t.check("a pending-art item is refused even when owned: " + waiting, not Customize.equip(store, Cosmetics.OWNERS.get(row["slot"], row["pilot"]), row["slot"], waiting))
	Cosmetics._test_pending = []
	_t.check("the delivered Till Bell equips for spil9", Customize.equip(store, "spil9", "companion_skin", "companion_skin_till_bell"))
	_t.check("companion skin clears for spil9", Customize.equip(store, "spil9", "companion_skin", ""))
	_t.check("outfit clears for a pilot", Customize.equip(store, SABLE, "outfit", ""))
	_t.check("shell clears for a pilot", Customize.equip(store, SABLE, "shell", ""))
	var reload := Profile.new(store.path)
	reload.load_profile()
	_t.eq("the equipped trail survives reload", CosmeticWear.worn(reload, SABLE, "trail"), "trail_salt_skip")
