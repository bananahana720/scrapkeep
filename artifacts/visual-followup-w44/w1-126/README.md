# The Spillway's working tools

The mag trapper raises a disc on its mast, then leaves the same tool at the centre of its live pit. The deployed casing sits on the floor and reads above the warning paint. It has no collider. The pit takes the disc with it when it ends.

## Read the magnet and the disc together

The normal trapper loop provided the poses, transforms and committed geometry. Godot ran headless. Blender in background mode drew the exported meshes against the sampled park floor. The thin outline traces the committed radius. The first two sheets isolate the tool silhouette. The live-fill sheet adds the exported static area, full warning fill and live scorch at their shipped opacity. Blender applies the game’s 0.30 m depth pull to those layers. The plates omit effects, surrounding scenery and HUD. The neutral sphere shows the ball’s radius for scale.

| Place | Near views in reading order | Distant control |
| --- | --- | --- |
| Dam powerhouse toe apron | Stock wind-up, stock live, raised disc, original 0.20 m seated disc. The lens is 14 m from the pit and 25 m from the cart. | 33 m to the pit, 44 m to the cart. |
| Flume bench landing | Same four states. The lens is 16 m from the pit and 25 m from the cart. | 33 m to the pit, 43 m to the cart. |

[Dam silhouette study](dam.jpg) · [Flume silhouette study](flume.jpg) · [Live fill, near](live-fill.jpg) · [Live fill, distant](distant.jpg)

Stock loses the hoisted disc at release. Its live ring marks the danger, but there is no working tool on the ground. Raising the deployed disc by 0.92 m makes its profile stronger and leaves a visible space beneath it. It suggests a raised object the ball must clear. The original seated disc lost its dark casing under the live paint. At 0.25 m the core emerged before the casing. The 0.30 m profile is the first tested height that shows the dark rim and light centre together on both floors near the rider. The 0.35 m profile adds height without a clearer read. The shipped candidate scales the mesh vertically by 1.5 and leaves the underside on the ground. The disk’s width and the pit’s radius stay fixed.

The near live-fill sheet shows stock, the 0.20 m version and the final 0.30 m version from left to right. The distant sheet shows stock and the final version. In both sheets the dam is the top row. The distant read is a thin dark rim under a bright centre. These are Blender comparisons of rendered geometry and composited warning layers. Godot’s final blend and movement through live cover still need a drawn game pass.

Headless Godot drove light and grown balls into the committed pit at the same 16 m/s approach, using a regular spawner beside `(124, 481)` on the dam and `(-290, 442)` on the flume. The four runs entered the 4.5 m ring. It caught each light ball once and neither grown ball. The matching presentation-disabled runs reproduced all 36 sampled positions, velocities and hold states exactly. The live mark kept its 1.1 s warning, 3 s live time and 1.4 m reach. The approach test stages a single trapper at each worksite. It does not measure reinforcement placement or a live pack.

## Keep the other shipped tools and placements

Each headless site probe staged one ordinary enemy and let it run its warning and release on the regular physics loop. The row gives wind-up and strike ticks from the spawn. The linked drawn captures and moving comparisons are earlier park trials.

| Worksite | Headless sample | Decision and evidence |
| --- | --- | --- |
| Dam west wash | Scraper at `(-100, -76)`, pilot uphill at `(-91, -85)`. Ticks 51 and 106. | Keep the low sprung head and the existing committed lane. The earlier moving pair gave both chasers a separate answer in stock. [Rider views and moving cases](https://github.com/bananahana720/scrapkeep/blob/e5ec6cff0/artifacts/visual-audit-w44/crew-trials/README.md#the-scrapers-working-end) |
| Dam lobber ledge | Lobber at `(-185, 455)`, pilot above the apron at `(-184, 440)`. Ticks 207 and 324. | Keep the working arm and the landed shell marker. The oblique spawn previously released behind the fast rider. Keep that change out. [Moving placement comparison](https://github.com/bananahana720/scrapkeep/blob/e5ec6cff0/artifacts/visual-audit-w44/crew-trials/README.md#which-moving-encounters-earned-their-placement) |
| Flume trestle | Drone and pilot at deck height near `(-115, 5.5)` and `(-117, -10)`. Ticks 0 and 91. | Keep the drum above the trough. The pose sheet shows the drum, and the headless probe confirms the release. A drawn tether view past the trestle and moving bank shadows remain open. [Drone pose sheet](https://github.com/bananahana720/scrapkeep/blob/a678c3636/artifacts/visual-audit-w44/images/pose-winch-drone.jpg) |
| Flume wasteway and forecourt | Chaser at `(85, 335)`, ticks 52 and 107. Brute at `(150, 420)`, ticks 75 and 175. Both pilot spots were above their approach floors. | Keep the low scraper and wide stoplog plates. The earlier west seat revealed the chaser sooner, but the matched novice sample took less damage there. Keep stock seating. [Home comparison](https://github.com/bananahana720/scrapkeep/blob/e5ec6cff0/artifacts/visual-audit-w44/crew-trials/README.md#who-arrives-beside-the-flume) · [Brute pose sheet](https://github.com/bananahana720/scrapkeep/blob/a678c3636/artifacts/visual-audit-w44/images/pose-plated-brute.jpg) |
| Late dam yard | Roller and flap probed at `(-10, 513)`. Both warned at tick 20 and struck at 111 in the isolated probe. | Keep the mat and hinged plate cues and the stock wave order. Centering the odd tool in the earlier formation experiment raised the opening damage against the stationary rider from 54 to 72 HP. [Stock and alternate yard waves](https://github.com/bananahana720/scrapkeep/blob/e5ec6cff0/artifacts/visual-audit-w44/crew-trials/README.md#who-attacks-first-in-the-dam-yard) |
| Lower flume return | Tender at `(46, 262)`, pilot at `(44, 256)`. Ticks 0 and 100. | Keep the reel and five floats. A previously primed crossing popped five floats at 28 m/s, but the unprimed moving approaches missed the warning. Keep the special placement out. [Crossing and placement comparison](https://github.com/bananahana720/scrapkeep/blob/e5ec6cff0/artifacts/visual-audit-w44/crew-trials/README.md#which-moving-encounters-earned-their-placement) |

The single-enemy samples establish when each existing tool reached its attack state at the sampled coordinates. A new drawn play pass with combat fill, shifting cover and normal encounter arrivals remains open. No windowed Godot run was used for this change.
