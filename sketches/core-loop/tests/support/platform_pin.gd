extends RefCounted

# A pinned number that differs between the Linux gate and the Mac gate (ruling eb, 17 Nov 2026). Godot's float32 sin
# and cos call the platform's sinf and cosf, and glibc's differ from Apple's in the last bit on a few percent of angles
# (pin_hash.gd), so a seeded fight or a run replays exactly on each machine but plays a different fight on each. Where a
# tolerance cannot absorb that (a run hash, a bot fight median), the test keeps both pins: the Linux value as before and
# the Mac value recorded beside it. Tolerances and bands stay the same on both.


# mac on macOS, linux everywhere else.
static func pick(linux: Variant, mac: Variant) -> Variant:
	return mac if OS.get_name() == "macOS" else linux
