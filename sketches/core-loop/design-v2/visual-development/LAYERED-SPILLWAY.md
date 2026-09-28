# Layered Spillway concept study

Andrew asked to use pinball's map logic as inspiration, without making a pinball machine. He selected a concept study on 2026-09-27. This is a proposed map iteration, not a change to the current playable slice.

## Every landing sets up another choice

The gorge has a fast lower channel, a middle combat shelf and an optional upper reach. All three belong to one place, oriented by the same dam tower. Terrain shapes the motion; repaired waterworks add selective acceleration, redirection and ascent.

The existing [vertical-stage proposal](../I3-vertical-stage.md) already provides the right foundation: shelves on a heightfield, overhead structures as separate prop geometry, chutes, barges and an upward launch. The new idea makes the connections and encounter placements the unit of design. A device succeeds when it makes the next route choice readable and useful.

| Space | Movement decision | Encounter use | Recovery |
| --- | --- | --- | --- |
| Middle shelf | Bank toward combat, descend into channel, or take long ascent | Lobber tests lateral movement; deflector offers an optional rebound shortcut | Broad landing apron before attacks, side bypass |
| Lower channel | Ride the smooth fall line; choose an acceleration strip or ordinary channel | Threats seen around open bends; no controller at a blind roof exit | Wide runout and return route, no drain |
| Upper reach | Ride barge, grapple shortcut, or arrive by long approach | Better view and angle at the cost of exposed approach | Miss lands on middle recovery slope |
| Pressure return | Choose launch or continue lower circuit | Brief view of next encounter before committing | Missed landing rejoins lower bank |

The default loop is middle shelf → banked descent → lower channel → broad recovery bowl → pressure return → middle landing. The upper reach is an optional branch with an ordinary approach available to every class. A skilled player may turn an enemy rebound into a shortcut, but completing the loop must not depend on that enemy remaining alive.

## Contraptions and enemies share the route

- Express acceleration as maintained drive rollers or a waterworks launch, with a clear approach, operating cue and visible destination. Keep an ordinary route beside it.
- Express redirection as stone banking, a sprung service buffer or a deflector enemy. Use a natural bank before adding a mechanical device.
- Separate a safe landing apron from the first hostile warning. Size it from measured arrival speed, braking/steering distance and camera visibility; concept art cannot supply those numbers.
- Let controller/punisher pairs pressure a route choice, not cover every exit. A warning must be visible before the player loses the ability to choose.
- Keep useful devices and active threats distinct in shape, motion and sound. Permanent hazard-painted ramps would undermine that distinction.

## Image critique

[The generated study](images/12-layered-spillway.png) establishes the three elevations, tower landmark, optional machinery and routes viewed from ball height. It also introduces unresolved geometry: the central water basin dominates the lower route; the launch arrow points close to a shelf edge; the ordinary upper approach is not continuously visible; the rollers look like a bottleneck; and enemy warnings are generic rings. None is a collision or attack specification.

The next geometry study should extend the gorge beyond the composition, make a dry lower recovery line unmistakable, widen and expose the middle landing, show the full ordinary upper approach, and place the accelerator beside a visible bypass. The map should remain a piece of working landscape rather than an enclosed circuit board.

## What a later playable experiment must answer

1. Can every class complete the full loop without class upgrades or surviving enemies as mandatory infrastructure?
2. At the actual chase camera and arrival speeds, can the player see both alternatives and each launch destination before commitment?
3. Does a missed upper line produce a useful lower line while preserving steerable motion?
4. Can a player deliberately use a deflector or swatter to gain position, while retaining a safe independent route?
5. Do multi-level warnings identify their true elevation and avoid leaking through floors?
6. Does the representative dense encounter retain p99 ≤16.7 ms at 1920×1080 on Andrew's PC?

These are the acceptance questions for a separately authorized map experiment. Current visual work preserves the existing map and physics. Human play still decides whether the loop feels good.
