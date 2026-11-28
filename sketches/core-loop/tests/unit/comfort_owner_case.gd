extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const Comfort := preload("res://src/core/comfort.gd")

const OWNER := "res://src/core/comfort.gd"
const STATIC_COPY := "(?m)^\\s*(?:@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*static\\s+(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*(?:var|func)\\s+(?:reduced_motion|motion_scale)\\b"
const FIELD_COPY := "(?m)^\\s*(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*var\\s+reduced_motion\\b"
const FIELD_HOLDERS := [
	OWNER,
	"res://src/presentation/launch_take.gd",
	"res://src/presentation/title_intro_player.gd",
	"res://src/presentation/world_fx/world_fx.gd",
	"res://src/presentation/world_fx/world_fx_anchor.gd",
]
const OLD_COPIES := "EnemyMotion\\.motion_scale|(?:HighdraftFx|WorldFx)\\.preferred|(?:UiTokens|AbilityBar|AimReticle|RewardView|MossBubble|CallerTile|ClassCard|PilotAntics|ClassPreview|BossPlate|FlourishPlayer|WorldFxKit)\\.reduced_motion"


func run(t) -> void:
	t.eq("only Comfort declares a static reduced_motion or motion_scale under src",
		SourceScan.matching(t, ["res://src"], STATIC_COPY), [OWNER])
	t.eq("the files under src and tools that declare a var named reduced_motion are exactly the owner and the known holders",
		SourceScan.matching(t, ["res://src", "res://tools"], FIELD_COPY), FIELD_HOLDERS)
	t.eq("no file under src or tools names a deleted copy of the setting",
		SourceScan.matching(t, ["res://src", "res://tools"], OLD_COPIES), [])
	var was: bool = Comfort.reduced_motion
	Comfort.reduced_motion = true
	t.eq("the scale follows the setting when on", Comfort.motion_scale(), 0.0)
	Comfort.reduced_motion = false
	t.eq("the scale follows the setting when off", Comfort.motion_scale(), 1.0)
	Comfort.reduced_motion = was
