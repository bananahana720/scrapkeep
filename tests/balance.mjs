import { Game, PATH } from "../src/game.js";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
const artifactDirectory = path.resolve(
  process.env.ARTIFACT_DIR || "artifacts/local",
);
await mkdir(artifactDirectory, { recursive: true });
const results = [];
for (const policy of ["stationary", "patrol"])
  for (const role of ["scavenger", "engineer", "warden"]) {
    const g = new Game();
    g.reset(role);
    let elapsed = 0,
      waypoint = 3,
      direction = 1;
    for (let i = 0; i < 60 * 540; i++) {
      if (g.mode === "gameover" || g.survived >= 8) break;
      if (g.mode === "upgrade") g.chooseUpgrade(0);
      g.ability();
      let input = { x: 0, z: 0 };
      if (policy === "patrol") {
        const [x, z] = PATH[waypoint],
          dx = x - g.player.x,
          dz = z - g.player.z,
          d = Math.hypot(dx, dz);
        if (d < 0.65) {
          if (waypoint === PATH.length - 1) direction = -1;
          if (waypoint === 0) direction = 1;
          waypoint += direction;
        } else input = { x: dx / d, z: dz / d };
        if (d > 3) g.dash();
      }
      g.update(1 / 60, input);
      g.drainEvents();
      elapsed += 1 / 60;
    }
    results.push({
      policy,
      role,
      seconds: Math.round(elapsed),
      wave: g.wave,
      survived: g.survived,
      base: g.base,
      collected: g.collected,
      turrets: g.weapons.length,
      score: g.score,
    });
  }
console.table(results);
await writeFile(
  path.join(artifactDirectory, "balance.json"),
  JSON.stringify(
    {
      method:
        "Deterministic seed 745, first upgrade, active ability on cooldown. Patrol follows the actual maze path and dashes when far from a corner. This is a balance probe, not human play evidence.",
      results,
    },
    null,
    2,
  ),
);
