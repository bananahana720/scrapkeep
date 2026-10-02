extends RefCounted

const WardenDrop := preload("res://src/combat/warden_drop.gd")

# Only a real strike is a ledgered contact. combat.would_crush asks the Warden's rule the
# same question a strike does, every tick from the player's bow recheck, so asking must
# leave contacts and last_contact alone; the strike's own on_struck ledgers it.

class StubPlayer:
	var pos := Vector3(0.0, 0.0, 40.0)

	func ball_position() -> Vector3:
		return pos

	func pre_contact_velocity(_toward: Vector3) -> Vector3:
		return Vector3(0.0, -10.0, 20.0)


class StubWarden:
	var CORE_WINDOW := 2.5
	var HALF_HEIGHT := 4.0
	var FAMILY_REACH := 3.0
	var max_hp := 400.0
	var hp := 400.0
	var plating := 0.0
	var _open_left := 0.0
	var target := StubPlayer.new()
	var global_position := Vector3.ZERO

	func family_open() -> bool:
		return _open_left > 0.0


func run(t) -> void:
	var warden := StubWarden.new()
	var drop := WardenDrop.new(warden, {"gun_role": "hold"})
	for i in 3:
		drop.rule("ram", "core", 25.0, 1.0)
	t.check("queries are not contacts", drop.contacts == 0 and drop.last_contact.is_empty(),
		"after 3 queries: contacts %d, last_contact %s (needs 0, empty)" % [drop.contacts, str(drop.last_contact)])

	var result := drop.rule("ram", "core", 25.0, 1.0)
	drop.on_struck("ram", result)
	t.check("a strike is one contact", drop.contacts == 1 and String(drop.last_contact.get("kind", "")) == "ram" and drop.last_contact.has("verdict"),
		"after 1 strike: contacts %d, last_contact %s (needs 1, a ram verdict)" % [drop.contacts, str(drop.last_contact)])
