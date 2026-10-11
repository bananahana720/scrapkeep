# Roboquest enemy design grammar (comps note, separable extra for the asset forge)

Evidence: shipped data tables (level 4 at measurement, scripts outside the repo; level 2 from the repo alone) for enemy classes and flags; asset metadata measured by the production-budget report (counts and dimensions only, triangle counts are LOD0 whole assets, bones are per whole rig); wiki (public) read at file:line (level 2) for boss mechanics and respawn rules. The wiki does not state why a silhouette reads, so those lines are labeled inference. Squad-anchor wave counts are not decoded. This note feeds the asset forge's enemy kit and is separate from the telegraph note; it carries no geometry, only relationships and counts.

## What it does

**Families by chassis and movement.** The wiki groups enemies in six categories by chassis (bots, pawns, flies, workers, pods, minibosses); the asset folders add a big-unit family. Movement class is a separate axis in the tables: static on 58 rows, walking on 45, flying on 36. Read as one rule per family (inference from table classes and wiki one-line attacks):

- **Ground pawn:** walks, shoots a blaster, throws a grenade; the stable infantry read. Health median 135.
- **Flying:** hovers or dives; its attacks are a charge-up then a dive, a slow-tracking ray, or a flash. Health median 120, speed up to 1,600 cm/s.
- **Turret:** static, health median 120, speed 400 cm/s where it moves at all; the read is "it stays where it is", and the anchor placement decides the threat.
- **Bot:** short-range walker, health median 60, the smallest body; chase-and-explode.
- **Worker:** rail-bound, health median 80, speed 400 cm/s; the rail is the read, and some spawn a fixed child type so the spawner is the target.
- **Big:** seven flagged rows, median health 1,050; fewer, slower to kill, longer to read.

**Production bands per family.** From the asset report (whole-asset LOD0 triangles; bones per whole rig):

| Family | Bones median | Triangles median | Clips (median seconds) |
|---|---|---|---|
| Pod | 16 | 12,331 | 288 (0.04) |
| Fly | 16 | 9,691 | 304 (0.46) |
| Bot | 37 | 11,442 | 283 (0.71) |
| Pawn | 54 | 19,767 | 211 (0.62) |
| Worker | 24 | 15,038 | 57 (0.46) |
| Big | 46 | 24,320 | 127 (0.62) |

Across all enemies, bones have a median of 27 and a 90th percentile of 55; bosses run a median of 59 and up to 143.

**What makes a silhouette read (inference).** The wiki and tables do not say; the pattern across the one-line attack texts is that each enemy has one threat feature and that feature is also its warning: a lens or light that charges before a flash or beam, a body that hides then strikes, a rail that declares its path. Each boss is described by one signature mechanic that changes its arena or rules: proximity detonation, burrowing, rail-bound movement, a forcefield, floor collapse (Bosses.txt:11, 25, 54, 68, 86). Boss time-to-kill was tuned to be similar across bosses (Updates.txt:1190).

**Squad anchors.** Arena and corridor pieces carry enemy anchors with a facing direction and a type; the type is flying (1,892 placements) or turret (1,091). The anchor fixes the chassis class, and the spawner picks the specific enemy (inference). Wave counts per anchor are not decoded.

**Respawn rule.** Arena respawns lower the chance of the type just killed (Updates.txt:1180-1181), spreading families across the arena.

```mermaid
flowchart TD
    C[Chassis class: ground, flying, turret, bot, worker, big] --> M[Movement class: static, walking, flying]
    C --> B[Production band: bones and triangles]
    C --> F[One threat feature = its warning]
    F --> K[Skill list: 0 to 6 attacks]
    A[Squad anchor: direction and type] --> C
    K --> Z[Respawn avoids the type just killed]
```

## Parameters

| Parameter | Value | Source |
|---|---|---|
| Enemy rows by class | flying 36, turret 34, bot 14, pawn 10, worker 6, unlabelled 39 | tables (level 4 at measurement), enemy statistics |
| Movement class | static 58, walking 45, flying 36 | tables, summary |
| Wiki categories | bots 14, pawns 5, flies 12, workers 3, pods 18, minibosses 2 (54 rows) | wiki (public), Enemies.txt:7-323 |
| Health median by class | bot 60, worker 80, flying 120, turret 120, pawn 135 | tables, per-class summary |
| Big units | 7 rows, median health 1,050 | tables |
| Bones median per family | pod 16, fly 16, bot 37, pawn 54, worker 24, big 46 | asset report (whole rigs) |
| Bones, all enemies / bosses | median 27, 90th 55 / median 59, 90th 99, max 143 | asset report |
| LOD0 triangles median per family | pod 12,331, fly 9,691, bot 11,442, pawn 19,767, worker 15,038, big 24,320 | asset report (whole assets) |
| Triangles 90th percentile per family | pod 17,877, fly 14,508, bot 15,272, pawn 31,912, worker 19,051, big 40,593 | asset report |
| Clips per family | pod 288, fly 304, bot 283, pawn 211, worker 57, big 127 | asset report |
| Clip median seconds | 0.04 to 0.71 by family | asset report |
| Squad anchor type | flying 1,892, turret 1,091 | pieces report, placements |
| Skills per enemy | 0 to 6; 41 none, 54 one | tables |
| Boss signature mechanics | five described, one each | wiki (public), Bosses.txt:11, 25, 54, 68, 86 |
| Summoner spawns a fixed child type | stated | wiki (public), Enemies.txt:259, 299 |
| Respawn rule | lowers chance of the type just killed | wiki (public), Updates.txt:1180-1181 |
| Why a silhouette reads | not stated | gap |
| Wave counts per anchor | not decoded | gap |

## Why it works

- **One read per family.** A player sorts any enemy into a handful of classes by movement before learning its attacks.
- **Threat feature equals warning feature** (inference). The part that hurts is the part the player watches.
- **One signature mechanic per boss** makes each fight a single new question.
- **Production bands stay narrow:** every family median sits between 9,691 and 24,320 triangles and 16 to 54 bones, so a family is a size class, not a bespoke asset.
- **Respawn variety** keeps classes mixed in a fight.

## What Scrapkeep borrows

- **A family is a chassis class plus a movement class plus one read** (principle: readability first). Refines BIBLE.md "A silhouette has a job" (line 719), which asks for behavior-driven construction; this supplies a way to sort a roster.
- **Threat feature equals warning feature** (principle: readability first). Refines BIBLE.md "A committed attack means what it shows" (line 489).
- **One signature mechanic per boss and miniboss** (principle: harmonize apparent contradictions). Refines BIBLE.md "Encounters, waves and enemies" (line 517) and TADR-010 (the director places minibosses).
- **Family budget bands for the forge:** bones and triangles per class as ranges to test, with the ratios below. The forge authors from a free base, so the bands only size the work.
- **Proportion ratios, numbers only.** Relative to the flying family's median triangles (1.00): pod 1.27, bot 1.18, worker 1.55, pawn 2.04, big 2.51. Relative to the pod and fly bone median (1.00): worker 1.5, big 2.9, bot 2.3, pawn 3.4. Health relative to the pawn median (1.00): bot 0.44, worker 0.59, flying and turret 0.89, big 7.8.
- **A forge recipe, as a relationship:** pick a free base, assign it a chassis class, give it one lens or light as its threat feature, set budget and rig size from the family band, and let the telegraph note's four fields describe its attacks.
- **Anchors that fix class and the spawner that picks the member** (principle: opt-in layers). Anchor: TADR-010's director.
- **Respawns that avoid the type just killed.** Anchor: line 517.

### Base mesh sources

Andrew asked whether a shipped enemy mesh could be ripped and resculpted. No: a resculpt of a copyrighted model stays a derivative, and one such file would break the forge's provenance guarantee for every asset downstream. The clean version of the same workflow starts from a public-domain or attribution-licensed base and reshapes it to the grammar above. A web scout checked the sources on 11 October 2026 without downloading anything (study report, outside the repo); rows marked snippet rest on search-result text because the page did not load.

| Rank | Source | License (as read) | What it offers | Format |
| --- | --- | --- | --- | --- |
| 1 | Quaternius on Poly Pizza, a flying robot enemy | CC0, verified on the page | one drone-like robot | FBX, glTF |
| 2 | Quaternius, an animated low-poly robot on OpenGameArt | CC0, verified | one robot with about 14 clips (snippet) | zip; check for glTF inside |
| 3 | Quaternius, the same robot and the animated monsters and animals packs on itch | CC0 per snippet; pages returned errors, verify first | robots; simple creatures | not verified |
| 4 | Daniel Darko, a low-poly robot on Sketchfab (mirrored) | CC BY 4.0, verified; attribution text given | one stylized robot, about 3,250 faces | GLB, glTF |
| 5 | Cough-E, a low-poly robot on OpenGameArt | CC0, verified | one untextured robot, shape reference | Blender file only |
| For blockouts | Kay Lousberg, prototype bits | free commercial use, no attribution, no resale of unmodified copies (snippet) | 64 or more blockout pieces, no robots | not verified |

Not usable as bases: Kenney ships no 3D robots (its robot pack is 2D); Mixamo is humanoid-only and not a Creative Commons license; Blender Studio's security-bot rig is a finished CC-BY character, a reference rather than a base. Not checked: Polyhaven, ambientCG, the Unity Asset Store.

Provenance recipe for the forge (TADR-003 admission): one sidecar per fetched base with the source URL and exact title, the license name and version as printed plus the saved license line, the access date, the file list with sizes and a SHA-256 per archive, the creator and any attribution text, and the commercial-use statement; re-check the license line before a build ships and keep the sidecar beside the asset.

## What it must not copy

- Any enemy or boss mesh, texture, rig or animation, including resculpted or retopologized versions: a derivative stays a derivative and would taint forge provenance.
- Enemy, boss, family and attack names, wiki text and descriptions.
- Silhouettes, colors and arena layouts, or a one-to-one map of the six classes onto Scrapkeep creatures; the class idea is borrowed, not the roster.
- The per-family numbers as targets; they size the study, Scrapkeep sets its own from the lab.

## Lab measure

Run the forge's first family from a CC0 base and record bones, triangles, authored clips and threat-feature visibility. Pass: bones and triangles within the band for its chassis class (set in the lab config, starting from the ratios above), and in a blind silhouette test of 20 stills at game camera distance, three reviewers name the chassis class and the threat feature correctly for at least 18 of 20, with zero stills where the threat feature is hidden.
