extends RefCounted

const CATEGORY := "enemy"
const OWNER := "A combat"

const ENTRIES := [
	{
		"id": "shell_return", "name": "Return to Sender",
		"hint": "Lobbers hate their own mail.",
		"clue": "a lobber's shell + something that meets it in the air",
		"text": "Shoot a shell in flight, or roll through it, and it goes back to the lobber that fired it. The return blast is yours.",
	},
	{
		"id": "counter_ram", "name": "Counter-ram",
		"hint": "A chaser crouching to lunge is not braced for you.",
		"clue": "a chaser's wind-up + a ram",
		"text": "Ram a chaser while its lunge lane is still filling and the lunge never happens.",
	},
	{
		"id": "chain", "name": "Chain",
		"hint": "Why let go of the floor when the next machine is right there?",
		"clue": "a hooked machine + a wall + another machine, feet off the floor",
		"text": "Hook a machine, swing off a wall, hook another and stay in the air. A smash pays 30% more per link past the first, up to six links.",
	},
	{
		"id": "crush_chain", "name": "Rolling Tide",
		"hint": "Heavy enough, and they stop being obstacles.",
		"clue": "heft + three rams in a heartbeat",
		"text": "Crush three unplated machines with rams inside one second, without breaking stride.",
	},
	{
		"id": "parting_shot", "name": "Parting Shot",
		"hint": "Leaving a pylon is a good time to be shooting.",
		"clue": "a slingshot + a kill",
		"text": "Kill a machine within a second of slingshotting off a pylon.",
	},
	{
		"id": "tether_snap", "name": "Slingshot Snap",
		"hint": "A line is only as strong as what it holds.",
		"clue": "a hooker's tether + more speed than it can take",
		"text": "Outrun or boost against a hooker's tether and it snaps, slinging you forward.",
	},
	{
		"id": "shield_vault", "name": "Off the Dish",
		"hint": "What throws you back can throw you up.",
		"clue": "a deflector's bounce + a jump",
		"text": "Jump the instant a deflector's dish throws you back and the bounce becomes a vault, whatever you pilot.",
	},
	{
		"id": "awaiting_operator", "name": "Awaiting Operator",
		"hint": "Scattered drones look for something to follow.",
		"clue": "a scattered swarm + another machine",
		"text": "Bowl through a swarm and its drones follow you for two seconds, seams dark. Lead them into another machine and they hit it like pins.",
	},
	{
		"id": "plate_drop", "name": "Maintenance Crew",
		"hint": "Someone is patching the machine behind your back.",
		"clue": "a fitter at a hatch + a reel impact",
		"text": "Those drones are the Waking's maintenance crew, still patching the Mind's excavator. Knock one off its plate and the seam stays open.",
	},
	{
		"id": "what_it_learned", "name": "What It Learned",
		"hint": "Something is keeping count.",
		"clue": "one of the Mind's hands + your favourite move",
		"text": "The Mind's hands brace against the move you use most this run, and show you which. Change verbs while its lens is open.",
	},
	{
		"id": "burrow_lane", "name": "Off the Floor",
		"hint": "The floor gives away what is coming through it.",
		"clue": "a burrower's swelling ring + a wall or a jump",
		"text": "Hunts a slow ball on the floor and bursts up under it; carve the wall or take the air, or slam its marker from above.",
	},
	{
		"id": "bore_breach", "name": "Stop the Bore",
		"hint": "A drill making a hole cannot brace for a falling ball.",
		"clue": "a drill crew mid-bore + a smash",
		"text": "Bores a breach where you will be and the floor caves in; smash the rig mid-bore to stop it.",
	},
	{
		"id": "lure_bloom", "name": "Through the Light",
		"hint": "The lamps want your steering. Give them your speed.",
		"clue": "a lamp swarm's blooming ring + a straight boost",
		"text": "Blooms a ring of lure lamps that bends your steering toward the light; boost straight through the wave.",
	},
	{
		"id": "jaw_slam", "name": "Shut Its Mouth",
		"hint": "A jaw in the floor can't bite what lands on it.",
		"clue": "a pit jaw's open ring + a slam from above",
		"text": "A jaw in the floor that bites a ball rolling over it; carve round it on the wall, or slam it shut from above.",
	},
	{
		"id": "mat_slip", "name": "Slip the Mat",
		"hint": "A live mat only bites a ball that dawdles.",
		"clue": "a jolt layer's live mat + speed, the air or a line as it pulses",
		"text": "A jolt layer's pulse misses a fast ball, a ball in the air and a ball on a line. Laid on flood water, the mat spreads half as wide again.",
	},
	{
		"id": "flap_ride", "name": "Ride the Flap",
		"hint": "A sluice flap tips over what is slow. What is fast, it launches.",
		"clue": "a ramp flipper's tilting flap + top speed, or a jump on the tilt",
		"text": "Reach a sluice flap fast, or jump as it tilts, and it throws you up and forward along your own line instead of off it.",
	},
	{
		"id": "hook_out", "name": "Hook Out",
		"hint": "A tether holds you to one post. Any other post will do.",
		"clue": "a hooker's tether + a harpoon hook on a post or a wall",
		"text": "Hook another post while a hooker holds you and its line snaps, kicking you along your own.",
	},
	{
		"id": "boom_pop", "name": "Bowl Through",
		"hint": "A boom pins what is slow. What is fast goes through it.",
		"clue": "a boom tender's sweep + top speed through its floats",
		"text": "Cross a boom tender's sweep at top speed and every float you touch bursts and pays scrap; slower, and the boom pins you to its hull.",
	},
	{
		"id": "boom_strike", "name": "Strike",
		"hint": "Five floats in a row, like pins.",
		"clue": "a boom tender's fresh boom + all five floats in one pass",
		"text": "Burst all five of a boom tender's floats in one sweep. The tug never refloats them.",
	},
	{
		"id": "line_cut", "name": "Under the Cutter",
		"hint": "A spinning blade leaves room beneath its arc.",
		"clue": "a cutter crossing your line over a gap + a glide under it, or a fresh hook at once",
		"text": "Throws a spinning cutter that severs your line over a gap. Hook a fresh line within half a second and the swing keeps a kick.",
	},
	{
		"id": "deck_winch", "name": "Slip the Hook",
		"hint": "A deck crew needs you on its cable before it can reel.",
		"clue": "an anchor crew's cable lane + a jump before the cinch",
		"text": "Hooks you down a cable lane and winches you onto its deck; jump to slip the hook before it cinches.",
	},
	{
		"id": "thermal_dive", "name": "Leave the Mark",
		"hint": "The kite commits to a spot. You do not have to.",
		"clue": "a circling kite + an air ram off its thermal, or a dive mark + a roll away",
		"text": "Circles high in a thermal and dives on the spot it marks; ride the same thermal up and ram it in the air to kill it outright.",
	},
	{
		"id": "ring_out", "name": "Over the Edge",
		"hint": "Nothing that heavy can be worn down. Everything that heavy can fall.",
		"clue": "a ballast heavy on the rim + a ram while it braces",
		"text": "A slab crew posted on the island rim that no damage wears down; ram it off the edge, hardest while it braces to slam.",
	},
	{
		"id": "gap_sling", "name": "Faster Than the Net",
		"hint": "A net holds what it can hold.",
		"clue": "a live net across a gap + a crossing at full swing",
		"text": "Strings a live net across a gap that slings a slow crossing back the way it came; cross faster than it can hold and you rip it.",
	},
	{
		"id": "cable_cut", "name": "Cut the Line",
		"hint": "A shield is only as good as what holds it up.",
		"clue": "a Linker's taut cable + a cut",
		"text": "It never attacks. It braces a dish over a partner on a taut cable, and the dish takes every hit it faces. Cut the cable, come over the rim or round the back, or drop the Linker first.",
	},
	{
		"id": "shift_over", "name": "Shift Over",
		"hint": "Every crew has someone blowing the whistle.",
		"clue": "a Shift Boss's horn + the Shift Boss down first",
		"text": "It never attacks. Every 5 s it horns and wipes the damage you have done to its crew's plating. Knock it out first and the whole crew holds its attacks for a breath.",
	},
	{
		"id": "roof_drop", "name": "Bring Down the Roof",
		"hint": "One timber holds up everything over that crew.",
		"clue": "a prop crew's shored roof + a ram from the wall",
		"text": "Shores a cracked roof over its pack; ram the prop from the wall side and the roof comes down on them, and on you if you are on the floor.",
	},
	{
		"id": "split_pop", "name": "Clean Break",
		"hint": "Some scrap comes apart the way you hit it.",
		"clue": "a Splitter + a smash from above, or a shot from far off",
		"text": "Chases you and keeps budding fuse pods that run at you and blow up. Kill it to stop them, by a smash from above or a shot from 15 m. A ram pops it into three more.",
	},
	{
		"id": "fuse_pod", "name": "Out of the Ring",
		"hint": "A lit fuse is a promise, not a hit.",
		"clue": "a Splitter pod + rolling out of its ring",
		"text": "A torn-off Splitter pod runs at you, lights a one-second fuse ring and blows up. Roll out of the ring.",
	},
	{
		"id": "cup_break", "name": "Out of the Cup",
		"hint": "A cup only keeps what sits still.",
		"clue": "a catch trap's cup + a boost or smash out of it",
		"text": "Sets a spring-jawed cup where you will roll and holds you dead still inside it; boost or smash out, or take down the crew before the jaws close.",
	},
	{
		"id": "stream_cut", "name": "Cut the Stream",
		"hint": "Ignore the chute and the chute never stops.",
		"clue": "a Dispatcher's mast + a kill after it has dropped a chaser",
		"text": "Perched on a mast, it never attacks but drops a chaser at you every 8 s. Reach it by harpoon, vault or a long gun and the stream stops.",
	},
	{
		"id": "paddle_ride", "name": "Ride the Swat",
		"hint": "A knock is only a shove if you let it be one.",
		"clue": "a swatter's paddle + a boost while it has you",
		"text": "The paddle never hurts. It bats you along its sweep. Boost inside the knock and the knock becomes your speed, or jump the low paddle.",
	},
	{
		"id": "heavy_roll", "name": "Too Heavy to Hold",
		"hint": "A pit sized for a pebble cannot hold a boulder.",
		"clue": "a mag trapper's pit + heft past its rating, or a jump",
		"text": "Grow past the disc's rating and roll straight through its pit; a jump or a smash shatters the disc.",
	},
	{
		"id": "plate_peel", "name": "Second Coat",
		"hint": "The brute wears one plate more than anyone else.",
		"clue": "a plated brute's outer plate + a second breaking hit",
		"text": "Its outer plate takes the first breaking hit whole and pops off; hit it hard again and the body cracks.",
	},
	{
		"id": "cable_snap", "name": "Snap the Cable",
		"hint": "A winch can only reel what stays on its cable.",
		"clue": "a winch drone's cable + a jump, boost or smash",
		"text": "Hovers out of ramming reach and winches you toward its pack; jump, boost or smash to snap the cable.",
	},
	{
		"id": "warden_shatter", "name": "Crack the Clamp",
		"hint": "Every guard has a breaking point.",
		"clue": "a Warden's full posture bar + a hit on the open core",
		"text": "Hit a Warden until its guard bar fills and it staggers open, then smash the core before it seals.",
	},
	{
		"id": "slag_hop", "name": "Over the Slag",
		"hint": "Slag only burns what rolls in it.",
		"clue": "a meltdown Warden's slag lane + a jump across it",
		"text": "A meltdown Warden's pulse leaves a slag lane that burns a rolling ball; jump the lane instead of rolling through.",
	},
	{
		"id": "brood_dark", "name": "Lights Out",
		"hint": "A brood keeps its lamps close. Put them out.",
		"clue": "a brood Warden's lamp guard + every lamp down",
		"text": "A brood Warden hides behind a lamp swarm; put the lamps out and its guard stays dark for ten seconds.",
	},
	{
		"id": "choir_switch", "name": "Change the Tune",
		"hint": "The choir learns your favourite song. Play another.",
		"clue": "a choir Warden's open lens + a move it has not braced",
		"text": "A staggered choir Warden braces against your most-used move; hit it with a different one while its lens is open.",
	},
	{
		"id": "loaded_line", "name": "Loaded Line",
		"hint": "A skill can wait for the rope.",
		"clue": "a cast with no line out + the next hook",
		"text": "Cast your line skill with no line out, then hook something inside four seconds. The skill fires through the hook.",
	},
	{
		"id": "set_piece", "name": "First Ultimate",
		"hint": "A full meter is a stage direction.",
		"clue": "a full ultimate meter",
		"text": "Fill the meter and fire your ultimate. The ball rides a drawn path and the landing strikes everything at its end.",
	},
	{
		"id": "set_piece_core", "name": "Curtain Call",
		"hint": "An open core is an open door.",
		"clue": "a Warden's open core + an ultimate landing",
		"text": "Stagger a Warden until its core opens, then land an ultimate on it. The core shatters.",
	},
	{
		"id": "set_piece_cash_in", "name": "Cash In",
		"hint": "A long chain wants a bigger finish.",
		"clue": "a chain of three or more + an ultimate landing",
		"text": "Land an ultimate with three or more links on your chain. The landing pays the whole chain.",
	},
	{
		"id": "set_piece_breakout", "name": "Breakout",
		"hint": "Nothing holds a ball with a plan.",
		"clue": "a hostile hold + your ultimate",
		"text": "Fire your ultimate while a machine holds you. The hold breaks as it starts.",
	},
	{
		"id": "armour_plated", "name": "Plated",
		"hint": "Some crews shrug off a plain hit.",
		"clue": "any hit on a plated crew",
		"text": "Plated crews take 60% from rams, smashes and weapon fire. Arc and your abilities do 125%.",
	},
	{
		"id": "armour_wet", "name": "Soaked",
		"hint": "The Spillway crews work in the water. Water carries a spark.",
		"clue": "an arc hit on a Spillway crew",
		"text": "Spillway crews come out of the channel soaked. Arc does 125% to them and everything else lands as normal.",
	},
	# --- P-C Sable entries ---
	{"id": "bank_shot", "name": "Bank Shot", "hint": "The line can turn you as well as pull you.", "clue": "a standing line + pick 3", "text": "Pick 3 and click while a line stands. You whip round the anchor and leave toward your aim, faster than you came."},
	{"id": "cable_run", "name": "Cable Run", "hint": "Everything she drives into the air is somewhere to hook.", "clue": "a full ring", "text": "Your ultimate rides a cable and drives a stake on every beat. The stakes hold a line for six seconds after landing."},
	{"id": "switchback", "name": "Switchback", "hint": "Your own stakes hold a line as well as any wall.", "clue": "a standing stake + Bank Shot", "text": "Bank Shot off a stake your Cable Run left behind."},
	{"id": "sable_cable_runs", "name": "Cable Runner", "hint": "A good route is worth repeating.", "clue": "three Cable Run landings in one run", "text": "Land three Cable Runs in one run to earn Cable Stitch."},
	# --- end Sable ---
	# --- P-C Rivet entries ---
	{"id": "rivet_line_drive", "name": "Line Drive", "hint": "The cable carries more than you.",
		"clue": "Rivet + pick 3 + a line on a machine", "text": "Pick 3 and click with a line on a machine. The winch throws it into whatever stands behind. On a wall it hauls you in and nothing holds you. With no line, the next hook carries it."},
	{"id": "rivet_foundry_cutter", "name": "Foundry Cutter", "hint": "Measured twice. Firing once.",
		"clue": "Rivet + a full ring", "text": "Your ultimate drives you to where you aim. The lens cuts wherever you look, on every beat. The middle beat sweeps wide. The landing skids on, and you keep the speed."},
	{"id": "rivet_line_true", "name": "Line True", "hint": "Ten straight answers.",
		"clue": "ten Line Drive punches + one stage", "text": "Land ten Line Drive punches in one stage to earn the Swarf Curl."},
	{"id": "rivet_shrugged", "name": "Shrugged Off", "hint": "Crowd control is fuel.",
		"clue": "Rivet + thirty ignored holds and knocks + one run", "text": "Shrug off thirty holds and knocks in one run to earn the Welding Hood."},
	# --- end Rivet ---
	# --- P-C Kest entries ---
	{"id": "kest_cable_charge", "name": "Cable Charge", "hint": "Your line can carry more than you.", "clue": "pick 3 + a click while hooked, or just before the hook", "text": "Pick 3 and click. A charge runs down your line and sets on what the hook caught. Let go and it blows. With no line out, the next hook carries it."},
	{"id": "kest_windhover", "name": "Windhover", "hint": "There. Give it a moment.", "clue": "a full ring + open sky over where you aim", "text": "Your ultimate lobs you up over where you aim. You hang there for two beats while your mortar shells the ground below, then you stoop straight down onto it."},
	{"id": "kest_blast_vault", "name": "Blast Vault", "hint": "The wall you blow can throw you.", "clue": "a Cable Charge on a wall + let go close + jump held", "text": "Charge a wall through your line, reel in, and let go within a few metres holding jump. The blast throws you up and away, and your chain keeps its grace."},
	{"id": "kest_homecoming", "name": "Homecoming", "hint": "The wind knows your feathers.", "clue": "Kest + the Highdraft", "text": "Fly Kest into her home roosts in world three."},
	{"id": "kest_tick_tick_boom", "name": "Tick, Tick, Boom", "hint": "Watch the whole pack before you commit.", "clue": "Windhover + eight different machines", "text": "Strike eight different machines with the charges and landing of one Windhover."},
	# --- end Kest ---
	# --- P-C Tarn entries ---
	{"id": "tarn_claw_drag", "name": "Claw Drag", "hint": "Why go to them when the line can bring them?",
		"clue": "a hooked machine + pick 3 + a click", "text": "Pick 3 and click to send a claw down the cable. Light machines arrive clamped in claw reach. Too heavy, and you climb it instead. On a wall it rips a slab loose."},
	{"id": "tarn_redjaw_rend", "name": "Redjaw Rend", "hint": "A full ring and a line to ride. Take company.",
		"clue": "a full ring + machines near the line", "text": "Your ultimate climbs claw over claw, snatching and towing nearby machines. The catch lands with you, rent and clamped. A heavier ball tows heavier machines."},
	{"id": "tarn_dragged", "name": "Ten in the Claws", "hint": "Bring the workshop to your teeth.",
		"clue": "ten different machines + claw drag + one stage", "text": "Drag ten machines into claw reach in one stage to earn Claw Marks."},
	{"id": "tarn_hold_still", "name": "Hold Still", "hint": "The machine, I mean.",
		"clue": "three hostile holds + Redjaw Rend + one run", "text": "Break three hostile holds with Redjaw Rend in one run to earn the Steady Cap."},
	# --- end Tarn ---
	# --- P-C Tally entries ---
	{"id": "tally_skim", "name": "Live Tap", "hint": "One splice wires three machines onto a live circuit.",
		"clue": "a harpoon hook + Jumper Splice on three machines", "text": "Cast Jumper Splice on a standing line, or load it before the hook. Clips three machines for one pressure each. Hit one and the circuit arcs to the rest."},
	{"id": "tally_books_balanced", "name": "Circuit Settled", "hint": "Every clip stays wired. Land and discharge the circuit.",
		"clue": "six clips + one Hostile Audit landing", "text": "Clip machines on the ride in, then land Hostile Audit. The landing settles every clip you wired, wherever it ran, and refills your pressure to full."},
	{"id": "tally_punch_tape", "name": "Punch Tape", "hint": "Keep the tape reels turning.",
		"clue": "Jumper Splice + ten casts + one stage", "text": "Fire Jumper Splice ten times in one stage to earn Punch Tape."},
	{"id": "tally_eyeshade", "name": "Eyeshade", "hint": "Twenty wired clips, one hostile audit at a time.",
		"clue": "twenty settled clips + Hostile Audit + one run", "text": "Settle twenty clips with Hostile Audit in one run to earn the Eyeshade."},
	# --- end Tally ---
	# --- P-C Cannon entries ---
	{"id": "cannon_lane_charge", "name": "Lane Charge", "hint": "The cable already shows where it goes.", "clue": "a standing line + pick 3", "text": "Pick 3 while the harpoon holds something. The cable becomes a lane that fires through the machine and twelve metres on, or out of a wall. Chains make it hit harder."},
	{"id": "cannon_fire_mission", "name": "Fire Mission", "hint": "A gun can fire itself.", "clue": "a full ring + open ground ahead", "text": "Your ultimate fires you along an arc. Each beat calls a family below you. Every call lands on the same beat as you."},
	{"id": "cannon_creeping_barrage", "name": "Creeping Barrage", "hint": "Some fire walks ahead of you.", "clue": "a line + the barrage", "text": "Ride a line. Every beat lays a lane across your path one beat before you reach it."},
	{"id": "cannon_plate_mortar", "name": "Plate Mortar", "hint": "Brace them from above.", "clue": "a high lob + plates + the landing", "text": "The lob drops plates. Your slam landing hits every exposed machine at 1.4 times."},
	{"id": "cannon_recital", "name": "Recital", "hint": "The gun hums four notes when it is happy.", "clue": "lane, split, rush, plate", "text": "Land the four families in the order the Cannon hums them and the tune plays whole."},
	{"id": "cannon_time_on_target", "name": "Time on Target", "hint": "Everything at once.", "clue": "Fire Mission + a crowd", "text": "Every shell you called landed on the same beat, on eight machines."},
	{"id": "cannon_old_tune", "name": "Old Tune", "hint": "It got your tune wrong all fight.", "clue": "the Mind + its own gun", "text": "The Mind played your tune back wrong. Its own gun played it right."},
	{"id": "mind_quiet_gun", "name": "The Quiet Gun", "hint": "One of its guns never fired.", "clue": "the Mind's rim, listening", "text": "A gun on the rim never fired. It learned one note each time the Mind showed a new attack."},
	# --- end Cannon ---
]


const DETECTORS := {
	"rivet_line_drive": {"kind": "", "script": "res://src/combat/rivet_kit.gd"},
	"rivet_foundry_cutter": {"kind": "", "script": "res://src/combat/rivet_kit.gd"},
	"rivet_line_true": {"kind": "", "script": "res://src/combat/rivet_kit.gd"},
	"rivet_shrugged": {"kind": "", "script": "res://src/combat/rivet_kit.gd"},
	"bank_shot": {"kind": "", "script": "res://src/combat/combat.gd"},
	"switchback": {"kind": "", "script": "res://src/combat/combat.gd"},
	"cable_run": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"sable_cable_runs": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"tarn_claw_drag": {"kind": "", "script": "res://src/combat/tarn_claw.gd"},
	"tarn_redjaw_rend": {"kind": "", "script": "res://src/combat/tarn_claw.gd"},
	"tarn_dragged": {"kind": "", "script": "res://src/combat/tarn_claw.gd"},
	"tarn_hold_still": {"kind": "", "script": "res://src/combat/tarn_claw.gd"},
	"tally_skim": {"kind": "", "script": "res://src/combat/combat.gd"},
	"tally_books_balanced": {"kind": "", "script": "res://src/combat/combat.gd"},
	"tally_punch_tape": {"kind": "", "script": "res://src/combat/combat.gd"},
	"tally_eyeshade": {"kind": "", "script": "res://src/combat/combat.gd"},
	"shell_return": {"kind": "lobber", "script": "res://src/combat/combat.gd"},
	"counter_ram": {"kind": "chaser", "script": "res://src/combat/combat.gd"},
	"chain": {"kind": "", "script": "res://src/combat/combat.gd"},
	"crush_chain": {"kind": "", "script": "res://src/combat/combat.gd"},
	"parting_shot": {"kind": "", "script": "res://src/combat/combat.gd"},
	"tether_snap": {"kind": "hooker", "script": "res://src/combat/hooker.gd"},
	"hook_out": {"kind": "hooker", "script": "res://src/combat/hooker.gd"},
	"mat_slip": {"kind": "jolt_layer", "script": "res://src/combat/jolt_layer.gd"},
	"flap_ride": {"kind": "ramp_flipper", "script": "res://src/combat/ramp_flipper.gd"},
	"boom_pop": {"kind": "boom_tender", "script": "res://src/combat/boom_tender.gd"},
	"boom_strike": {"kind": "boom_tender", "script": "res://src/combat/boom_tender.gd"},
	"shield_vault": {"kind": "deflector", "script": "res://src/combat/deflector.gd"},
	"awaiting_operator": {"kind": "swarm_remnant", "script": "res://src/combat/fleet.gd"},
	"plate_drop": {"kind": "crew_fitter", "script": "res://src/boss/waking.gd"},
	"what_it_learned": {"kind": "mind_hand", "script": "res://src/combat/fleet.gd"},
	"burrow_lane": {"kind": "burrower", "script": "res://src/combat/burrower.gd"},
	"bore_breach": {"kind": "drill_crew", "script": "res://src/combat/drill_crew.gd"},
	"lure_bloom": {"kind": "lamp_swarm", "script": "res://src/combat/lamp_swarm.gd"},
	"jaw_slam": {"kind": "pit_jaw", "script": "res://src/combat/pit_jaw.gd"},
	"line_cut": {"kind": "line_cutter", "script": "res://src/combat/line_cutter.gd"},
	"deck_winch": {"kind": "anchor_crew", "script": "res://src/combat/anchor_crew.gd"},
	"thermal_dive": {"kind": "kite_drone", "script": "res://src/combat/kite_drone.gd"},
	"cable_cut": {"kind": "linker", "script": "res://src/combat/linker.gd"},
	"shift_over": {"kind": "foreman", "script": "res://src/combat/foreman.gd"},
	"roof_drop": {"kind": "prop_crew", "script": "res://src/combat/prop_crew.gd"},
	"split_pop": {"kind": "splitter", "script": "res://src/combat/splitter.gd"},
	"fuse_pod": {"kind": "splitter_pod", "script": "res://src/combat/splitter_pod.gd"},
	"cup_break": {"kind": "catch_trap", "script": "res://src/combat/catch_trap.gd"},
	"stream_cut": {"kind": "dispatcher", "script": "res://src/combat/dispatcher.gd"},
	"paddle_ride": {"kind": "swatter", "script": "res://src/combat/swatter.gd"},
	"ring_out": {"kind": "ballast_heavy", "script": "res://src/combat/ballast_heavy.gd"},
	"gap_sling": {"kind": "gap_net", "script": "res://src/combat/gap_net.gd"},
	"heavy_roll": {"kind": "mag_trapper", "script": "res://src/combat/mag_trapper.gd"},
	"plate_peel": {"kind": "plated_brute", "script": "res://src/combat/plated_brute.gd"},
	"cable_snap": {"kind": "winch_drone", "script": "res://src/combat/winch_drone.gd"},
	"warden_shatter": {"kind": "warden", "script": "res://src/combat/warden.gd"},
	"slag_hop": {"kind": "warden", "variant": "meltdown", "script": "res://src/combat/warden.gd"},
	"brood_dark": {"kind": "warden", "variant": "brood", "script": "res://src/combat/warden.gd"},
	"choir_switch": {"kind": "warden", "variant": "choir", "script": "res://src/combat/warden.gd"},
	"loaded_line": {"kind": "", "script": "res://src/combat/combat.gd"},
	"set_piece": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"set_piece_core": {"kind": "", "script": "res://src/combat/combat.gd"},
	"set_piece_cash_in": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"set_piece_breakout": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"armour_plated": {"kind": "drill_crew", "script": "res://src/combat/combat.gd"},
	"armour_wet": {"kind": "chaser", "script": "res://src/combat/combat.gd"},
	"cannon_lane_charge": {"kind": "", "script": "res://src/combat/cannon_kit.gd"},
	"cannon_fire_mission": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"cannon_creeping_barrage": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"cannon_plate_mortar": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"cannon_recital": {"kind": "", "script": "res://src/combat/cannon_kit.gd"},
	"cannon_time_on_target": {"kind": "", "script": "res://src/combat/ultimate.gd"},
	"cannon_old_tune": {"kind": "", "script": "res://src/boss/mind.gd"},
	"mind_quiet_gun": {"kind": "", "script": "res://src/boss/mind.gd"},
	"kest_cable_charge": {"kind": "", "script": "res://src/combat/kest_kit.gd"},
	"kest_windhover": {"kind": "", "script": "res://src/combat/kest_kit.gd"},
	"kest_blast_vault": {"kind": "", "script": "res://src/combat/kest_kit.gd"},
	"kest_homecoming": {"kind": "", "script": "res://src/combat/kest_kit.gd"},
	"kest_tick_tick_boom": {"kind": "", "script": "res://src/combat/kest_kit.gd"},
}


const DETECTOR_PENDING := []

const FLAVOUR := {
	"shell_return": {"speaker": "pump_crew", "text": "Stamped return to sender at forty metres per second."},
	"counter_ram": {"speaker": "rivet", "text": "Crouched for a dramatic lunge and met a steel sphere instead."},
	"chain": {"speaker": "sable", "text": "The floor is strictly optional if the walls keep cooperating."},
	"crush_chain": {"speaker": "tarn", "text": "Said excuse me three times inside a single second."},
	"parting_shot": {"speaker": "sable", "text": "Left the pylon so fast the shot had to sign the guestbook."},
	"tether_snap": {"speaker": "rivet", "text": "Fleet cable rated for standard traffic. Not whatever we are doing."},
	"shield_vault": {"speaker": "kest", "text": "Borrowed their dish as a springboard. Zero paperwork filed."},
	"awaiting_operator": {"speaker": "dig_crew", "text": "Scattered triangles will follow whoever rolls loudest. Very polite, honestly."},
	"plate_drop": {"speaker": "caisson_crew", "text": "Caught the repair drone mid-patch. Seam stays open on our count."},
	"what_it_learned": {"speaker": "mind", "text": "Pattern alignment updated. Please continue repeating your favourite habit."},
	"burrow_lane": {"speaker": "dig_crew", "text": "Floor bites slow boots. Wall minds its own business."},
	"bore_breach": {"speaker": "kest", "text": "Dropped straight onto a live drill rig. Saved us two timber props."},
	"lure_bloom": {"speaker": "caisson_crew", "text": "Nice lamps, terrible steering advice. Boost straight through."},
	"jaw_slam": {"speaker": "tarn", "text": "Closed the pit jaw from above. Gently, all things considered."},
	"boom_pop": {"speaker": "flume_crew", "text": "Five floats strung across the channel, popped like polite bubble wrap."},
	"boom_strike": {"speaker": "tally", "text": "Full sweep logged on one line. Tug declined a rematch."},
	"line_cut": {"speaker": "roost_crew", "text": "Cut our cable mid-gap and we hooked the next post anyway."},
	"thermal_dive": {"speaker": "kest", "text": "Rode its own updraft and met it upstairs. My sky."},
	"ring_out": {"speaker": "roost_crew", "text": "Too heavy to dent, light enough for gravity. Cloud net got it."},
	"gap_sling": {"speaker": "sable", "text": "Net crew builds tough knots. Faster wheels still win."},
	"cable_cut": {"speaker": "patch", "text": "Snipped the brace line and watched the whole shield lose interest."},
	"shift_over": {"speaker": "mind", "text": "Quick sync cancelled due to sudden supervisor unavailability."},
	"roof_drop": {"speaker": "dig_crew", "text": "Pulled one prop and let the ceiling handle the rest of the shift."},
	"split_pop": {"speaker": "moss", "text": "Do not ram what splits. Drop on it and save the broom."},
	"warden_shatter": {"speaker": "pump_crew", "text": "Four chunks of cast iron, cracked open on our count."},
	"slag_hop": {"speaker": "flume_crew", "text": "Hot floor, easy jump. Boots stayed dry for once."},
	"brood_dark": {"speaker": "caisson_crew", "text": "Put every lamp out and the Warden forgot its own guard."},
	"choir_switch": {"speaker": "cannon", "text": "It expected the chorus again. Switched instruments mid-bar."},
	"set_piece_core": {"speaker": "sable", "text": "Open core, full ring, dramatic finish. Credits roll right here."},
	"cannon_old_tune": {"speaker": "cannon", "text": "Played the stolen melody right back in the crew's key."},
	"mind_quiet_gun": {"speaker": "patch", "text": "Even the Foreman's own turret got tired of the quarterly memos."},
}


static func flavour(id: String) -> Dictionary:
	return FLAVOUR.get(id, {})


static func flavour_text(id: String) -> String:
	return String(FLAVOUR.get(id, {}).get("text", ""))


static func flavour_ids() -> Array:
	return FLAVOUR.keys()


static func all() -> Array:
	var out := []
	for row in ENTRIES:
		var entry: Dictionary = row.duplicate()
		entry["category"] = CATEGORY
		entry["owner"] = OWNER
		entry["participants"] = ["player"]
		out.append(entry)
	return out


static func ids() -> Array:
	var out := []
	for row in ENTRIES:
		out.append(row["id"])
	return out
