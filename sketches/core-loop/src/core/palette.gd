extends RefCounted

const SAND := Color("d2c5a5")
const SANDSTONE := Color("c6a274")
const RUST := Color("9b513a")
const COPPER := Color("b77843")
const CHARCOAL := Color("242a28")
const INK_DEEP := Color(0.07, 0.07, 0.08)
const VERDIGRIS := Color("365754")
const AMBER := Color("e5a044")
const ARC := Color("8bf0d3")
const COBALT := Color("3d8bff")
const ANCIENT := Color("9dff3c")
const CABLE := Color("2a3231")
const HAZARD := Color("ff5a3c")
const BRASS := Color("d9b44a")
const LEDGER := Color("e6d9b8")
const SLATE := Color("6f7f8f")
const SLATE_INK := Color("a3b3c3")
const STEEL := Color("9aa0a0")
const MAST_STEEL := Color("b7b6a3")
const ICE := Color("c8f0ff")
const REDJAW_ASH := Color("5e5a54")
const LEDGER_CREAM := Color("f7f1e3")
const OLD_VERDIGRIS := Color("4f7f7a")
const KINDNESS := Color("d936b0")
const SODIUM := Color("ffc070")
const DAWN_VIOLET := Color("a8a4de")
const APRICOT := Color("ffac74")
const TURQUOISE := Color("a4d6d0")


static func live(_class_def = null) -> Color:
	return ARC


static func water_tone() -> Color:
	return VERDIGRIS.lerp(ARC, 0.35)
