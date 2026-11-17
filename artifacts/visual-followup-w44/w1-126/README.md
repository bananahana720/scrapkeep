# The Spillway's working tools

The mag trapper now leaves a physical-looking disc at the centre of its live pit. The original warning and the two discs on the cart still carry their separate jobs. The planted disc is a mesh with no collider. The cart still hoists its top disc before release, and the pit takes the deployed mesh with it when it ends.

## Read the magnet and the disc together

The normal trapper loop provided the poses, transforms and committed geometry. Godot ran headless. Blender in background mode drew the exported meshes against the sampled park floor. The thin outline traces the committed radius. The plates omit the game's hazard fill, effects, other scenery and HUD. The sphere shows the ball's radius for scale.

| Place | Near views in reading order | Distant control |
| --- | --- | --- |
| Dam powerhouse toe apron | Stock wind-up, stock live, raised disc, seated disc. The lens is 14 m from the pit and 25 m from the cart. | 33 m to the pit, 44 m to the cart. |
| Flume bench landing | Same four states. The lens is 16 m from the pit and 25 m from the cart. | 33 m to the pit, 43 m to the cart. |

[Dam comparison](dam.jpg) · [Flume comparison](flume.jpg) · [Distant stock and seated, dam above flume](distant.jpg)

Stock loses the hoisted disc at release. Its live ring marks the danger, but there is no working tool on the ground. Raising the deployed disc by 0.92 m makes its profile stronger and leaves a visible space beneath it. It suggests a raised object the ball must clear. The seated disc reads as part of the floor and leaves the ring to carry the hazard's reach. The distant comparison keeps the low silhouette, though the final blend with the actual live fill still needs a drawn game pass.

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
