// The Sitting Kit's content: the 11 verdict areas of Andrew's world 1 sitting check (title, camp, dam, flume, Brindle)
// in the unparked three-world pre-alpha baseline (ruling ep).
// Sources: project-guide/handoff/DECISIONS.md (rulings), project-guide/handoff/shared/alpha-status/sitting-watch-list.md,
// ambition-map.md (what Accept means) and sketches/core-loop/BUG-BAR.md. Each ruling and call carries its source line.
// index.html reads window.SITTING and nothing else.
window.SITTING = {
  build:
    "The Linux sitting pack built from main (three worlds active under ruling ep), on a fresh profile that saves. Title, camp, dam, flume and Brindle in the Slag Bowl are checked here first.",
  build_hint: "main head",
  controls: [
    ["Roll", "W A S D"],
    ["Look", "Mouse"],
    ["Jump", "Space"],
    ["Fire", "Left mouse"],
    ["Bar slots", "1 2 3"],
    ["Harpoon", "Right mouse"],
    ["Haul", "Ctrl"],
    ["Boost", "Shift"],
    ["Ultimate", "Q"],
    ["Active", "F"],
    ["Consumable", "C"],
    ["Interact", "E"],
    ["Field notes", "Tab"],
    ["Pause", "P or Esc"],
    ["Restart", "Hold R"],
  ],
  areas: [
    {
      id: "core-feel",
      name: "Core feel",
      question:
        "Accept: rolling, ramming and grappling feel joyful and instant. The harpoon shows its tether at once and a slam from cruise speed throws foes far.",
      try: [
        "Roll with WASD and jump with Space until the ball feels like yours.",
        "Fire with left mouse. Press right mouse to bite a foe, hold to keep it, release to fling it.",
        "Hold right mouse on a foe, then press Ctrl to smash it.",
        "Slam with Ctrl in the air, then reel into a body within 3 s to cash the dunk. Watch the coil glow and listen for the jackpot.",
        "Boost with Shift and use your special with F.",
        "Ride a half-pipe wall above cruise speed and feel the grip.",
      ],
      where: [
        "Stage 1, the dam",
        "Any dam pack",
        "Any fight with an ordinary foe",
        "Any dam or flume pack",
        "Any run, any pilot",
        "Stage 2, the flume",
      ],
      rulings: [
        {
          text: "Walls grip automatically above cruise speed and let go when slow. There is an on/off toggle for the sitting.",
          src: "DECISIONS.md section 6",
        },
        {
          text: "Past 60 m/s the ball stops getting faster. Extra speed becomes hit damage and a blazing trail.",
          src: "DECISIONS.md section 6",
        },
        { text: "Bowling hits throw foes up to about 36 m.", src: "DECISIONS.md section 6" },
        {
          text: "Hitting on the beat pays off in sound only, with no gameplay bonus.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "Damage taken never shakes the camera. Events never stop the ball.",
          src: "DECISIONS.md, older rulings",
        },
        {
          text: "Rivet's heavy Breach: flat ground and Full Cut hit instantly. Slope Breaches land at about 0.18 s for now.",
          src: "DECISIONS.md section 9",
        },
      ],
      vetos: [],
      watch: [
        'The dunk tip shows on your first stored charge ("an air slam stores its hit; reel into a hooked body to cash it"). With it, the coil glow and the jackpot, did you start cashing dunks?',
      ],
    },
    {
      id: "wardens-bosses",
      name: "Wardens and bosses",
      question:
        "Accept: every Warden and boss is beatable and readable, and earns its first stagger in about 45 to 70 s for an ordinary pilot (60 to 85 s for the stage 3 hive Warden).",
      try: [
        "Fight the dam Warden. Break its clamp crews first, then note when it first staggers.",
        "Fight the flume Warden and note its first stagger.",
        "Fight Brindle through all three phases.",
        "Listen for the music change at each of Brindle's phases.",
        "Watch Brindle's arrival over the bowl rim and the rout at the end.",
        "Read Brindle's line for your pilot at the arena.",
      ],
      where: [
        "Stage 1, the dam beacon",
        "Stage 2, the flume beacon",
        "The Slag Bowl",
        "The Slag Bowl",
        "The Slag Bowl, first and last seconds",
        "The Slag Bowl",
      ],
      rulings: [
        {
          text: "Ordinary pilots take 45 to 70 s to first stagger a Warden. The stage 3 hive Warden takes 60 to 85 s.",
          src: "DECISIONS.md section 5",
        },
        {
          text: "Monster builds stagger Wardens faster: hits count up to 3x and the ultimate fills up to 70%.",
          src: "DECISIONS.md section 5",
        },
        { text: "The bosses are Brindle, the Waking and the Mind.", src: "DECISIONS.md section 7" },
        {
          text: "The Waking gets two or three attacks of its own: burrow lanes, cave-ins and bore breaches.",
          src: "DECISIONS.md section 7",
        },
        {
          text: "Eurodance boss versions play in the final phase only, and they play even over a pinned radio track.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "The Mind is a hand ('All hands'), shown by gloves, crew numbers and a HIRED stamp.",
          src: "DECISIONS.md section 7",
        },
        { text: "Each boss has one line for each pilot.", src: "DECISIONS.md section 7" },
      ],
      vetos: [
        {
          text: "Overpowered pays: the higher stagger ceiling (3.0x, ultimate 70) applies only to heft class III and up. Ordinary pilots keep 1.5x and 45.",
          src: "veto list, 18 Oct",
        },
      ],
      watch: [
        "Brindle's arrival in motion: does the Requisition's arc over the Slag Bowl rim land as an entrance? It plays inside the 3 s no-attack intro.",
        "Brindle's rout in motion: does the scooter's slow-motion flight read as a big comic beat, not a hitch?",
        "A Brindle fight that drags past about 2 minutes: note what the scooter and the ball are doing. Phase 3 has run 95 s on one bot seed.",
        "While the clamp is shut, a marker with the plate's glyph points at the crew nearest to lighting a pip. The clamp holds 13 to 65 s a run. Did the marker lead you to the crews?",
      ],
    },
    {
      id: "in-run-growth",
      name: "In-run growth",
      question:
        "Accept: a grown run clearly feels mightier than its first hit, through presence and new parts.",
      try: [
        "Collect parts through a run. Compare how your hits look and sound at the first dam pack and at Brindle.",
        "Take your start item from the start card with 1, 2 or 3.",
        "Watch the item panels climb the ladder: mint, then cobalt. Take a cobalt and read its FLEET GRADE stamp.",
        "Seat modules on the companion and watch SPIL-9 change.",
        "Open field notes with Tab and check what you hold.",
        "Shop at Moss's counter and open rib caches. Note which parts turn up.",
      ],
      where: [
        "Start to end of a world 1 run",
        "Stage 1, after the drop",
        "Wardens, Brindle, the shop",
        "The companion on your ball",
        "Any stage",
        "Moss's counter, rib caches in each park",
      ],
      rulings: [
        {
          text: "Late runs look mightier through presence: hotter colour, bigger comic words, ink edges and aura. Burst size stays the same, and warnings stay on top.",
          src: "DECISIONS.md section 6",
        },
        {
          text: "SPIL-9 grows with each module seated and gets a signature assist, called by the next ram when its gauge is full.",
          src: "DECISIONS.md section 6",
        },
        {
          text: "Bad matchups: counter items show up 1.5x as often.",
          src: "DECISIONS.md section 5",
        },
        {
          text: "All six actives and the maker sets on the 61 items come before the sitting.",
          src: "DECISIONS.md section 6",
        },
        {
          text: "Three-level parts exist on three neutral parts only.",
          src: "DECISIONS.md section 6",
        },
        {
          text: "Level-ups mean heft class-ups. There is no XP curve.",
          src: "DECISIONS.md, older rulings",
        },
      ],
      vetos: [
        {
          text: "The 1.5x loot nudge applies wherever parts roll: gates, shop, caches, fabricators, vault, hook.",
          src: "veto list, 18 Oct",
        },
        {
          text: "The loot nudge stays 1.5x. The alpha-Tally kit-share check uses a 20-seed mean against the unchanged 60 to 80% band.",
          src: "veto list, 18 Oct",
        },
      ],
      watch: ["Item label over the dunk coil: does a panel's label sit over the coil and hide it?"],
    },
    {
      id: "progression",
      name: "Progression across runs",
      question:
        "Accept: unlocks, secrets and cosmetics carry over, save, and give a reason to start another run.",
      try: [
        "Open the camp from the main menu and see what you have unlocked.",
        "Open Achievements from the main menu.",
        "Equip a cosmetic and a pilot paint, then start a run and check they show.",
        "Win a run, then check the shift board, Brindle's marks for your pilot and the time card.",
        "After a win, pick Tier 1 on the start card and feel the first HARD rung.",
        "Quit, relaunch and check the unlocks, cosmetics and paint saved.",
        "Finish a run and look for its comic page in the camp scrapbook.",
      ],
      where: [
        "Main menu, Camp",
        "Main menu, Achievements",
        "Camp, then a run",
        "The camp after a run",
        "Stage 1, the next run",
        "Quit, then relaunch",
        "The camp scrapbook",
      ],
      rulings: [
        {
          text: "Only unlocks carry over between runs. A run is three worlds, one retry per world, 30 to 45 minutes.",
          src: "DECISIONS.md, older rulings",
        },
        {
          text: "There are 18 cosmetics. Kest's Rigger Harness is cut.",
          src: "DECISIONS.md section 9",
        },
        {
          text: "New players start with Sable and earn the rest. Your sitting profile opens all six.",
          src: "DECISIONS.md section 9",
        },
        {
          text: "Tally unlocks by freeing her from the Fleet's INVENTORY cage on the sky islands, or by finding three ledger leaves.",
          src: "DECISIONS.md section 9",
        },
        {
          text: "Lore notes collect over runs: 7 to 17 per zone, about 7 per run.",
          src: "DECISIONS.md section 3",
        },
        {
          text: "The alpha holds a few secrets back until the first win.",
          src: "DECISIONS.md section 10",
        },
        {
          text: "Every run ends as a comic page, collected in a camp scrapbook. The camp reacts to the last run with one dry line.",
          src: "DECISIONS.md section 3",
        },
      ],
      vetos: [],
      watch: [
        "On a fresh profile the start card shows only the line that says how to unlock the first rung. After your first win, does the tier choice explain itself?",
      ],
    },
    {
      id: "pilots",
      name: "Pilots",
      question:
        "Accept: the six pilots play differently, win in bot play, and have a character you care about.",
      try: [
        "Open pilot select and watch each pilot's resting move.",
        "Start with Sable. Use its slingshot and its flight.",
        "Rout Brindle once and watch Tarn sign on.",
        "Pick each pilot you have unlocked. Use boost (Shift) and special (F) with each.",
      ],
      where: [
        "Main menu, Play, pilot select",
        "The dam and the flume",
        "The Slag Bowl victory, once per profile",
        "Any run",
      ],
      rulings: [
        {
          text: "Pilots climb out for two bars (about 3.7 s), do one signature bit, and hop back in. Sable balances, Rivet leans on it facing the wrong way, then turns, surprised, Kest hovers then drops, Tarn sits, Tally stamps PAID, the Cannon waves.",
          src: "DECISIONS.md section 3",
        },
        {
          text: "Movement belongs to the pilot. Shared parts change what a verb does, not how far or fast the ball moves.",
          src: "DECISIONS.md, older rulings",
        },
        {
          text: "Whether a cast keeps the ball rolling depends on the pilot.",
          src: "DECISIONS.md section 6",
        },
        {
          text: "Tarn and the Cannon ship on their current first-pass animations.",
          src: "DECISIONS.md section 9",
        },
        {
          text: "Sable is exempt from 'Wall pays' as a flyer in the sinkhole.",
          src: "DECISIONS.md section 8",
        },
      ],
      vetos: [
        {
          text: "Nemesis maps pilot to axis to every kind on that axis. The Cannon gains the burrower. Tally gains the deflector and the netcaster.",
          src: "veto list, 18 Oct",
        },
        {
          text: "Rivet's nemesis lean is near nil and nothing is tagged air yet. Widening it moves the bands.",
          src: "veto list, 18 Oct",
        },
      ],
      watch: [],
    },
    {
      id: "stage-world",
      name: "Stage and world design",
      question:
        "Accept: each of the six dressed parks tests one skill, has jungle-gym lines to ride, and leads into the next stage.",
      try: [
        "Play the dam, then the flume, then the Slag Bowl.",
        "Ride one grapple chain or half-pipe line in each park.",
        "Break the yard crew when the yard locks, then the clamp crews to open the Warden.",
        "Roll into a cracked face at speed and break it.",
        "Find a secret and a rib cache in each park.",
        "Roll along the eye_fin_east fin toward the Eye's mouth.",
        "Roll off the ledge 29 m before the flume's first gate.",
      ],
      where: [
        "Stages 1 and 2, then Brindle",
        "The dam and the flume",
        "Each park's beacon circle",
        "The dam and the flume",
        "The dam and the flume",
        "The dam, the Eye",
        "The flume, near (271, 0.4, 480)",
      ],
      rulings: [
        {
          text: "3D space is a jungle gym: grapple tricks, downforce and half-pipe carving.",
          src: "DECISIONS.md section 6",
        },
        {
          text: "Each park tests one skill. Each world owns one mechanical theme.",
          src: "DECISIONS.md sections 5 and 8",
        },
        {
          text: "Sinkhole: carving the tube walls is the fastest, safest line. The floor is slower and bites.",
          src: "DECISIONS.md section 8",
        },
        {
          text: "The sinkhole floor burns slowly after 1.5 s (4 hull/s) and never kills.",
          src: "DECISIONS.md section 8",
        },
        {
          text: "The flume butte gap stays open: you carry about 90 m of speed across the canal floor. No bridge.",
          src: "DECISIONS.md section 8",
        },
        {
          text: "The light changes over a run, dawn in the Spillway to dusk at the Mind. The game ends with a 60 s free roll around Meteor Crater.",
          src: "DECISIONS.md section 8",
        },
        {
          text: "Shortcuts stay optional and a ground route stays open.",
          src: "DECISIONS.md, older rulings",
        },
        {
          text: "A fall below a map's net deck lands on the deck, never death.",
          src: "DECISIONS.md, older rulings",
        },
      ],
      vetos: [
        {
          text: "The old lore.reach set and the 3-2 island and bridge notes are replaced by the new lore port.",
          src: "veto list, 18 Oct",
        },
        {
          text: "The sinkhole ring is closed with a visual-only timber trestle over the 41 degree tube-mouth trough.",
          src: "veto list, 19 Oct",
        },
      ],
      watch: [
        "The dam's 20 m eye_fin_east fin: does it read as a lane wall that sends you to the Eye's mouth?",
        "The flume ledge about 7 m above the terrain before the first gate: can you roll off it? Two bots wedged there.",
        "Cracked faces: held rolls from 10 m at 30 degrees top out at 11.5 to 11.8 m/s, just under the 11.9 m/s bar. From 14 m every square or 30 degree roll breaks. Does the margin feel fair?",
      ],
    },
    {
      id: "look",
      name: "Look",
      question:
        "Accept: models, terrain and effects read as soft toy (chunky, bevelled, smooth) at 80 to 90% of the concept art, with no placeholder on screen.",
      try: [
        "Look closely at a pilot on the title deck and at a dam enemy up close.",
        "Look at the hero landmark in the dam and in the flume.",
        "Hunt for plain spheres, grey posts or boxes.",
        "Look at the crowd in the Slag Bowl stands.",
        "Compare a late-run hit with the first hit: effects, ink edges, aura.",
        "Watch the dawn light across the run.",
      ],
      where: [
        "Main menu title deck, then any dam fight",
        "Each park",
        "The dam, the flume, the Slag Bowl",
        "The Slag Bowl",
        "Any run",
        "Whole run",
      ],
      rulings: [
        {
          text: "Soft toy: crews and round bodies go smooth, machines keep crisp bevelled edges.",
          src: "DECISIONS.md section 8",
        },
        {
          text: "Look targets: Arizona sandstone for world one, approved keyframes for worlds two and three, Southwest finish for parks. The bar is 80 to 90% of concept art.",
          src: "DECISIONS.md, older rulings",
        },
        {
          text: "Ancient light is uranium-glass green (#9dff3c).",
          src: "DECISIONS.md, older rulings",
        },
        { text: "Asset-forge test pieces stay out of the game.", src: "DECISIONS.md section 8" },
        {
          text: "Placeholders block exports from wave 20. The alpha target is zero.",
          src: "DECISIONS.md section 8",
        },
        {
          text: "Highdraft mesa edges count as ground. Narrower lips still get ride pieces.",
          src: "DECISIONS.md section 8",
        },
      ],
      vetos: [{ text: "The landmarks opt into the soft-toy polish.", src: "veto list, 19 Oct" }],
      watch: [
        "The Slag Bowl stand crowd is still recipe shapes, not smooth-shell crew. A Look note if it reads as placeholder.",
        "Orange and tan pilot colours: can you tell them apart under the game's light?",
      ],
    },
    {
      id: "sound-music",
      name: "Sound and music",
      question:
        "Accept: every track, loop and cue is present, seamless and on the beat, and each hit has a paired sound.",
      try: [
        "Listen to the roaming music on the dam and the flume as you speed up.",
        "Start a Warden fight and listen to the music handover.",
        "Listen to Brindle's anthem through all three phases.",
        "Listen to titles A and B, theme C on a won summary, and the camp.",
        "Use the in-game radio and skip a track with the period key.",
        "Land a long chain and whiff a smash. Listen for the extra sounds.",
        "Listen for loop seams and for a missing enemy or boss cue.",
      ],
      where: [
        "Stages 1 and 2",
        "Either Warden fight",
        "The Slag Bowl",
        "Main menu, run summary, camp",
        "In a run",
        "Any fight",
        "Whole run",
      ],
      rulings: [
        {
          text: "Roaming music ramps with speed: drums and bass build as you go faster, and the sax enters with combo.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "Hit sound lands within 5 ms. Musical answers land on the next beat.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "Warden fights take over from the radio with their own score, unless a track is pinned.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "Wordless vocals on the radio only. The game score stays vocal-free.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "Each special enemy has its own presence loop, wind-up tell and death sting. A missing cue counts as a placeholder.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "Theme C plays on a won run's summary and on the ending. A lost run keeps the jazz-club track.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "The music thread picked the better render for each of the 81 radio takes. You hear them at the sitting and can swap any.",
          src: "DECISIONS.md section 4",
        },
        {
          text: "Music never freezes: pause and the calm bay keep the band playing.",
          src: "DECISIONS.md, older rulings",
        },
      ],
      vetos: [
        {
          text: "The pilot radio stays off the pad. D-pad down keeps the active.",
          src: "veto list, 18 Oct",
        },
      ],
      watch: [
        "Radio on the pad: D-pad down fires the active and next-track is keyboard only (period key). Do you want the radio on the pad?",
        "Roam to Warden pivot: the bass and lead drop out over one beat and the drums carry in. A deliberate switch-up, or the music cutting out?",
        "Picked themes by ear: the Spillway roam loops, Brindle's opening, titles A and B, theme C, the camp. Listen for loop seams and the stretch on the world loop.",
      ],
    },
    {
      id: "clarity",
      name: "Clarity",
      question:
        "Accept: every mechanic is taught on screen before it is needed, warnings stay readable in a crowd, and no menu button is dead.",
      try: [
        "Start a fresh run and read every message in the first 11 s, with the start card up. The radio and active tips should wait for your pick.",
        "With a real mouse and the start card up, move the mouse: the camera should look before you pick.",
        "With the start card up, press Esc: pause opens and the card takes nothing under it.",
        "With a rung unlocked, press Esc at the tier card: pause opens over it, and the game does not quit.",
        "Leave the start pick untaken, pull up slowly to Moss, then press Esc or pad B: the counter closes.",
        "Finish a run and press Esc on the summary: you land in the camp.",
        "Read the plate while the yard is locked, and follow the crew marker while the Warden's clamp is shut.",
        "Press every main-menu item: Play, Camp, Settings, Help, Achievements, Quit. Note any dead button.",
        "Turn on the Reduce flashes toggle and fight a pack.",
      ],
      where: [
        "Stage 1, after the drop",
        "Stage 1, fresh profile",
        "Stage 1, fresh profile",
        "Stage 1, after a win",
        "Moss's counter, after the dam Warden",
        "The run summary",
        "Each park's beacon circle",
        "Main menu",
        "Main menu, Settings, then any fight",
      ],
      rulings: [
        {
          text: "Warnings never fall within 0.2 s between packs or kinds. One pack's warnings start together.",
          src: "DECISIONS.md section 5",
        },
        {
          text: "Near a live hive, defenders skip the 0.2 s gap, so their wind-ups can stack.",
          src: "DECISIONS.md section 5",
        },
        {
          text: "The alpha ships a Reduce flashes toggle, without an assist mode.",
          src: "DECISIONS.md section 10",
        },
        {
          text: "One global warning grammar. No per-world telegraph colours.",
          src: "DECISIONS.md, older rulings",
        },
        {
          text: "Every mechanic shows its cause on the object before you act and its effect when it lands.",
          src: "DECISIONS.md, older rulings",
        },
        {
          text: "You learn an enemy's weakness on the first hit against it.",
          src: "DECISIONS.md section 5",
        },
        {
          text: "Story stays short and skippable, intro cards included.",
          src: "DECISIONS.md, older rulings",
        },
      ],
      vetos: [],
      watch: [
        "The radio and active tips now wait until the start pick is taken. Does the drop still feel crowded with the card up?",
        "Moss's counter opens only if you pull up under 4 m/s, and nothing says so or what cogs buy. Scrap's weight is never put into words. Did a first visit open the counter naturally?",
        "With a rung unlocked, Esc, P or pad Start open pause over the tier choice. Check with a real mouse that closing pause leaves the cursor free on the card.",
        "Esc on the run summary now goes to the camp, as K does. Check it with a real keyboard after a win and after a loss.",
        "The F chip on a pad: the active is fired with D-pad down, but the bar still shows a keyboard F. Readable, or does it need a D-pad cap?",
        "Reduce flashes: with the Display toggle on, does every flash still read, and does every active's flash obey it?",
      ],
    },
    {
      id: "difficulty-pacing",
      name: "Difficulty and pacing",
      question:
        "Accept: fights are chaotic but learnable and fair, a world 1 run takes about 10 to 15 minutes, and doing everything takes about 30.",
      try: [
        "Play a straight run to each Warden and Brindle. Note your time and your deaths.",
        "Play a run that does everything: activities, secrets, rogues, rib caches. Note your time.",
        "Fight a pack with many attackers and judge whether it is fair.",
        "Hold the yard through every wave of its lock crew.",
        "Judge the flume's length by feel: does it feel short next to the dam, or right?",
        "Spend your one retry after a death.",
        "After a win, play a rung of the HARD ladder.",
      ],
      where: [
        "Whole world 1 run",
        "Whole world 1 run",
        "Any dam or flume pack",
        "Each park's beacon circle",
        "Stage 2, the flume, drop to exit",
        "Whole run",
        "Start card, then the run",
      ],
      rulings: [
        {
          text: "The attacker budget starts at 6, +1 per heft class, +2 per world, cap 12 in late Highdraft. Bosses are never limited.",
          src: "DECISIONS.md section 5",
        },
        {
          text: "A grown pilot clears hives at least 2x faster than a small one. The first Warden target is 1.85x.",
          src: "DECISIONS.md section 5",
        },
        { text: "Hive defenders skip the attacker budget.", src: "DECISIONS.md section 5" },
        {
          text: "Ranged-only pilots are not blocked from finishing a hive. The rare lucky ranged break stays in and is judged at the sitting.",
          src: "DECISIONS.md section 5",
        },
        {
          text: "Difficulty never raises enemy health. Run tier caps health at 1.6x and damage at 1.3x, Wardens excluded.",
          src: "DECISIONS.md, older rulings",
        },
        {
          text: "Normal difficulty is tuned toward winning 3 of 5 runs.",
          src: "DECISIONS.md, older rulings",
        },
        { text: "Resistances lean but never wall a build off.", src: "DECISIONS.md section 5" },
        {
          text: "Electric fields jam casts, charges and specials for 0.5 s. The ball keeps full speed.",
          src: "DECISIONS.md section 5",
        },
        { text: "One retry per world, spent only by death.", src: "DECISIONS.md, older rulings" },
      ],
      vetos: [
        {
          text: "HIVE-GRIND bar fill: option A, the queued card default.",
          src: "veto list, 18 Oct",
        },
      ],
      watch: [
        "Dispatcher left alone: is the climb to plated brutes fair? Unanswered drops climb chaser 8 s, hooker 4.5 s, brute 3 s.",
        "Your world 1 times against the bots: the skipper median is 434 bot-s (flume 154 s, under its 180 s band, recorded as a miss by ruling ax) and the completionist 1249 bot-s (wave 20 read). Your minutes over the bot median is the person-to-bot ratio that settles the 15 to 20 bot-min target (ruling ag).",
      ],
    },
    {
      id: "stability",
      name: "Stability",
      question:
        "Accept: no crash or blocker, frames hold 60 fps, and the AppImage and menus open cleanly.",
      try: [
        "Launch the AppImage from the app menu and time it to the main menu.",
        "Note whether the 2D title answers quickly before the 3D park title fades in.",
        "Watch the first drop into the dam after a cold launch for a hitch.",
        "Watch the drop into the flume: one beat, or a stutter?",
        "Watch the Slag Bowl entry and Brindle's phase changes for hitches.",
        "Pause with P or Esc and resume. Hold R to restart.",
        "Quit from the main menu, relaunch with the saved profile.",
        "Note any bug and rate it blocker, major or minor by the bug bar.",
      ],
      where: [
        "The desktop app menu",
        "Main menu",
        "Stage 1, first launch",
        "Dam to flume",
        "The Slag Bowl",
        "Any stage",
        "Main menu, Quit",
        "Whole run",
      ],
      rulings: [
        {
          text: "A frame p99 over 16.7 ms across a stage, or a repeating hitch over 33 ms, is a major bug. A crash, soft-lock, unbeatable boss, lost save or dead menu item is a blocker. A crash is a blocker even if it happened once. A hitch during the stage-swap launch flight is major.",
          src: "BUG-BAR.md; DECISIONS.md section 10",
        },
        {
          text: "Accepted at the sitting means 11 areas marked, none Not yet, no open blocker, frame times in budget, zero placeholders.",
          src: "DECISIONS.md section 1",
        },
        {
          text: "AppImage plus an app-menu entry. A gamepad is optional.",
          src: "DECISIONS.md section 1",
        },
        {
          text: "Launch screen: the 2D title is interactive in about 2 s and the 3D park title crossfades in. Cold boot measured 7.8 to 8.3 s against the 5 s target. Your ruling, not a veto.",
          src: "veto list, 18 Oct",
        },
      ],
      vetos: [],
      watch: [
        "Flume entry: the entry frame is about 58 ms (from about 120) and frames +1 to +5 run 20 to 34 ms. Does the drop read as one beat or a stutter?",
        "Cold launch: the stage 1 Warden setup takes 438 ms at boot, hidden under the boot frame today. Watch the first launch.",
        "Slag Bowl entry runs about 49 ms on the 4080. Does Brindle's bowl open cleanly?",
      ],
    },
  ],
};
