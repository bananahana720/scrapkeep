# Storyboard decisions (Andrew, 2026-10-16)

Andrew approved the seven boards as drawn (22:31Z) and answered the five fork cards in the project thread. These override the defaults in [LANDMARK-CARDS.md](../LANDMARK-CARDS.md) where they differ.

| Board | Call | Tap (UTC) | Differs from card default | Build consequence |
| --- | --- | --- | --- | --- |
| 3 Headframe | Legs solid to the ground | 22:36:58 | No (card left it open) | Lower legs get `-col`; re-run stage 3 lines and posture bands |
| 4 Sinkhole | Full gallery ring round the pool | 22:37:18 | Yes (card dressed the 70 m arc) | New ring floor rows (KD4 greybox change), then dressing; re-measure stage 4 |
| 5 Hanging Isle | Tip is a moving harpoon anchor | 22:36:43 | Yes (card default was visual only) | Tip collider on an `AnimatableBody3D` driven by `warden_mind.gd` tilt and sink (P5 plus collider); re-measure stage 5 |
| 6 Crown Spire | 30 m waist to 60 m, then 50 m | 22:37:46 | No | As card 6 |
| 7 Camp | Hub ring: plaza spawn, launch gate straight ahead at 70 m | 22:36:12 | n/a (no prior layout) | Stations on a 48 m ring; mint shortcut ramp |

Boards 1 (dam) and 2 (penstock tower) had no fork and were approved as drawn.

Andrew's one concern: keep exploring and interacting with each park before the boss. The landmark builds leave every park route row in place (shared test (e) in LANDMARK-CARDS.md), and the full ring adds route.
