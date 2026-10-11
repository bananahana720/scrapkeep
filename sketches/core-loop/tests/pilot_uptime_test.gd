extends SceneTree

const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# SQ7 Uptime table (W13-INTEGRATION-3.md, unit sq7-uptime-table). Every timed movement or
# speed buff states duration over cooldown and whether its cooldown starts at activation or
# at expiry. The band comes from comps/roboquest/movement-and-feel.md: a Roboquest buff
# sits at 25% to 75% uptime (stealth about 27%, overdrive 43% to 75%).
#
# Reports now. The band is printed for every row and asserted only once PC-PACK flips
# GATE_BAND; until then the test asserts the structure (rows exist, numbers finite, the
# start rule measured, every buff row in ability_state.gd tabled) and fails loud on that.

const BAND_LOW := 0.25
const BAND_HIGH := 0.75
const GATE_BAND := false # PC-PACK flips this to true.
# Specials that grant the fire boost through _overdrive_blast with boost left true
# (combat.gd:2180 default, :2194-2195 grants _boost(OVERDRIVE_SECONDS)): _fire_point_blank
# (combat.gd:1489-1493) is one. They carry no "duration" key, so the scan below names them.
const BOOST_SPECIALS := ["overdrive_blast", "point_blank"]


# One row per timed buff. duration is read from the source the game reads, never retyped:
# a row's "duration" (the sprint) or the Weapons constant (blast, cloak). slot is where the
# ability sits on its pilot's bar.
func _buffs() -> Array:
	var rows: Dictionary = AbilityState.ABILITIES
	return [
		{"pilot": "Rivet", "id": "overdrive_sprint", "slot": AbilityState.MOVEMENT,
			"duration": float(rows["overdrive_sprint"].get("duration", 0.0))},
		{"pilot": "Rivet", "id": "overdrive_blast", "slot": AbilityState.SPECIAL,
			"duration": Weapons.OVERDRIVE_SECONDS},
		{"pilot": "Rivet", "id": "point_blank", "slot": AbilityState.SPECIAL,
			"duration": Weapons.OVERDRIVE_SECONDS},
		{"pilot": "Kest", "id": "smoke_blink", "slot": AbilityState.MOVEMENT,
			"duration": Weapons.CLOAK_SECONDS},
	]


# Reads when the cooldown starts from AbilityState itself: spend the slot, mark it active
# (the buff running), tick one cooldown. Ready again while still active means the cooldown
# ran during the buff, so it starts at activation; still cooling means it waits for expiry.
func _start_rule(b: Dictionary) -> String:
	var a := AbilityState.new()
	a.swap(b["slot"], b["id"])
	if not a.spend(b["slot"]):
		return "unspendable"
	a.slot(b["slot"]).active = true
	a.tick(a.cooldown_of(b["slot"]) + 0.01)
	return "activation" if a.ready(b["slot"]) else "expiry"


func _initialize() -> void:
	var t := T.new("pilot_uptime_test")
	var buffs := _buffs()
	t.check("buff table has rows", buffs.size() >= 3, "%d rows" % buffs.size())

	# Every row in ability_state.gd that is a timed buff must be tabled, so a new buff row
	# cannot dodge the report.
	var tabled := {}
	for b in buffs:
		tabled[b["id"]] = true
	var must: Array = []
	for id in AbilityState.ABILITIES:
		var row: Dictionary = AbilityState.ABILITIES[id]
		if row.has("duration") or row.get("cloak", false):
			must.append(id)
	for id in must:
		t.check("buff row %s is in the uptime table" % id, tabled.has(id), "")
	for id in BOOST_SPECIALS:
		t.check("boost special %s is in the uptime table" % id, tabled.has(id), "")
		t.check("boost special %s exists in ABILITIES" % id, AbilityState.ABILITIES.has(id), "")
	t.check("the scan found the tabled buff rows", must.size() >= 2, "%d scanned" % must.size())

	print("")
	print("UPTIME  pilot  ability  duration/cooldown  uptime  cooldown starts  band")
	for b in buffs:
		var id: String = b["id"]
		t.check("%s has an ability row" % id, AbilityState.ABILITIES.has(id), "")
		if not AbilityState.ABILITIES.has(id):
			continue
		var a := AbilityState.new()
		a.swap(b["slot"], id)
		var cd: float = a.cooldown_of(b["slot"])
		var dur: float = b["duration"]
		t.check("%s duration is finite and positive" % id, is_finite(dur) and dur > 0.0, str(dur))
		t.check("%s cooldown is finite and positive" % id, is_finite(cd) and cd > 0.0, str(cd))
		if not (is_finite(dur) and is_finite(cd) and cd > 0.0):
			continue
		var start := _start_rule(b)
		t.check("%s cooldown start rule is measured" % id, start == "activation" or start == "expiry", start)
		# If the cooldown waits for expiry, the cycle is duration plus cooldown.
		var uptime := dur / cd if start == "activation" else dur / (dur + cd)
		var inside := uptime >= BAND_LOW and uptime <= BAND_HIGH
		print("UPTIME  %s  %s  %.2f s / %.2f s  %.1f%%  %s  %s" % [b["pilot"], id, dur, cd,
			uptime * 100.0, start, "inside 25-75" if inside else "OUTSIDE 25-75"])
		if GATE_BAND:
			t.check("%s uptime inside 25%% to 75%%" % id, inside, "%.3f" % uptime)

	# PILOTS.md carries the same table: an uptime column in the roster, one cell per pilot.
	var text := FileAccess.get_file_as_string("res://design-v3/PILOTS.md")
	t.check("PILOTS.md is readable", text.length() > 0, "")
	var header := ""
	var rows_md: Dictionary = {}
	for line in text.split("\n"):
		if line.begins_with("| Pilot |") and header == "":
			header = line
		for p in ["Sable", "Rivet", "Kest", "Tarn", "Tally", "The Cannon"]:
			if line.begins_with("| **%s**" % p) and not rows_md.has(p):
				rows_md[p] = line
	t.check("roster table has an Uptime column", header.contains("| Uptime "), header.substr(0, 40))
	t.eq("roster table has six pilot rows", rows_md.size(), 6)
	var col := -1
	var head_cells := header.split("|")
	for i in head_cells.size():
		if head_cells[i].strip_edges().begins_with("Uptime"):
			col = i
	for p in rows_md:
		var cells: PackedStringArray = (rows_md[p] as String).split("|")
		var cell := cells[col].strip_edges() if col > 0 and col < cells.size() else ""
		t.check("%s uptime cell is filled" % p, cell != "", cell.substr(0, 50))
		if cell != "" and not cell.begins_with("none"):
			t.check("%s uptime cell names its cooldown start" % p, cell.contains("activation") or cell.contains("expiry"), cell.substr(0, 50))
	quit(t.verdict())
