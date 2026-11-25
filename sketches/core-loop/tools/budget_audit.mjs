#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { inspectGlb, webpSide } from "../../../scripts/asset-inspect.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const SKETCH = "sketches/core-loop";

const ENEMY_BONES_MAX = 40;
const PENDING_MARK = /no member yet/;

const REFERENCE = [
  {
    group: "pilot (hero)",
    game: "Risk of Rain 2",
    tris: [1928, 11278],
    bones: [77, 136],
    clip_s: [0.67, 1.83],
    tex: "2,048 (0 over)",
    src: "ror2/production-budgets.md:37,52,65,79 (survivor, per piece)",
  },
  {
    group: "pilot (hero)",
    game: "Gunfire Reborn",
    tris: [1430, 4773],
    bones: [17, 20],
    clip_s: [0.8, 2.66],
    tex: "2,048",
    src: "gunfire/production-budgets.md:36,53,68,84 (hero, per piece)",
  },
  {
    group: "pilot (hero)",
    game: "Roboquest",
    tris: [34098, 35479],
    bones: [47, 62],
    clip_s: [0.48, 1.72],
    tex: "4,096",
    src: "roboquest/production-budgets.md:50,66,77,91 (whole asset)",
  },
  {
    group: "enemy",
    game: "Risk of Rain 2",
    tris: [528, 4814],
    bones: [35, 155],
    clip_s: [0.95, 2.85],
    tex: "2,048 (0 over)",
    src: "ror2/production-budgets.md:38,53,66,80 (monster, per piece)",
  },
  {
    group: "enemy",
    game: "Gunfire Reborn",
    tris: [443, 3691],
    bones: [6, 49],
    clip_s: [1.07, 3.0],
    tex: "1,024",
    src: "gunfire/production-budgets.md:37,54,69,85 (monster, per piece)",
  },
  {
    group: "enemy",
    game: "Roboquest",
    tris: [14152, 24357],
    bones: [27, 55],
    clip_s: [0.71, 1.62],
    tex: "4,096",
    src: "roboquest/production-budgets.md:51,67,78,92 (whole asset)",
  },
  {
    group: "prop",
    game: "Risk of Rain 2",
    tris: [188, 3503],
    bones: [44, 141],
    clip_s: [3.33, 5.0],
    tex: ">2,048 (3)",
    src: "ror2/production-budgets.md:41,55,68,82 (prop or stage)",
  },
  {
    group: "prop",
    game: "Gunfire Reborn",
    tris: [232, 1261],
    bones: [2, 27],
    clip_s: null,
    tex: "8,192 (environment)",
    src: "gunfire/production-budgets.md:41,56,71 (prop)",
  },
  {
    group: "prop",
    game: "Roboquest",
    tris: [844, 12080],
    bones: null,
    clip_s: null,
    tex: "4,096",
    src: "roboquest/production-budgets.md:36,81 (prop, per piece)",
  },
];
const GROUP_CATEGORY = { "pilot (hero)": "pilot", enemy: "enemy", prop: "prop" };

export function summarize(values) {
  const v = [...values].sort((a, b) => a - b);
  if (!v.length) return { median: 0, p90: 0, max: 0 };
  const mid = v.length >> 1;
  const median = v.length % 2 ? v[mid] : (v[mid - 1] + v[mid]) / 2;
  const p90 = v[Math.max(0, Math.ceil(0.9 * v.length) - 1)];
  return { median, p90, max: v[v.length - 1] };
}

export function loadBudgets(root, file) {
  return JSON.parse(
    fs.readFileSync(file ?? path.join(root, SKETCH, "assets/asset_budgets.json"), "utf8"),
  );
}

function textureSide(file, bytes) {
  const ext = path.extname(file).toLowerCase();
  if (ext === ".png" && bytes.length >= 24)
    return Math.max(bytes.readUInt32BE(16), bytes.readUInt32BE(20));
  if (ext === ".webp") return webpSide(bytes);
  if (ext === ".hdr") {
    const m = /-Y (\d+) \+X (\d+)/.exec(bytes.subarray(0, 256).toString("latin1"));
    return m ? Math.max(Number(m[1]), Number(m[2])) : 0;
  }
  return 0;
}

export function measureRegistry(root) {
  const sketch = path.join(root, SKETCH);
  const registry = JSON.parse(fs.readFileSync(path.join(sketch, "assets/registry.json"), "utf8"));
  return registry.assets.map((row) => {
    const rel = String(row.path).replace(/^res:\/\//, "");
    const file = path.join(sketch, rel);
    const out = {
      id: row.id ?? path.basename(rel),
      path: row.path,
      class: row.class,
      ships: row.ships !== false,
      tris: 0,
      verts: 0,
      draws: 0,
      bones: 0,
      clips: 0,
      longest_clip_s: 0,
      texture_side: 0,
      exception: row.exception ?? null,
    };
    try {
      const bytes = fs.readFileSync(file);
      if (path.extname(file).toLowerCase() === ".glb") {
        const inv = inspectGlb(bytes, { textureLenient: true }).inventory;
        Object.assign(out, {
          tris: inv.triangles,
          verts: inv.welded_vertices,
          draws: inv.primitives,
          bones: inv.bones,
          clips: inv.clips,
          longest_clip_s: inv.longest_clip_s,
          texture_side: inv.texture_max_side,
        });
      } else out.texture_side = textureSide(file, bytes);
    } catch (e) {
      out.error = `${e.message}`;
      for (const k of [
        "tris",
        "verts",
        "draws",
        "bones",
        "clips",
        "longest_clip_s",
        "texture_side",
      ])
        out[k] = Number.NaN;
    }
    return out;
  });
}

const FIELDS = ["tris", "verts", "draws", "bones", "clips", "longest_clip_s", "texture_side"];

export function evaluate(assets, budgets) {
  const failures = [];
  const notes = [];
  const classes = budgets.classes ?? {};
  const counted = (a) => a.ships !== false || a.class === "texture";
  const maxSide = budgets.texture?.max_side ?? 2048;
  const names = [...Object.keys(classes), "texture"];
  const rows = names.map((category) => {
    const members = assets.filter((a) => a.class === category && counted(a));
    const pending =
      category !== "texture" &&
      members.length === 0 &&
      PENDING_MARK.test(classes[category]?.set_by ?? "");
    if (!members.length && !pending)
      failures.push(`${category}: no assets (category empty, run fails)`);
    return {
      category,
      count: members.length,
      pending,
      cap: classes[category] ?? null,
      stats: Object.fromEntries(
        FIELDS.map((f) => [f, summarize(members.map((a) => a[f]).filter(Number.isFinite))]),
      ),
    };
  });
  for (const a of assets) {
    if (!counted(a)) {
      const own = evaluate([{ ...a, ships: true }], {
        ...budgets,
        classes: { [a.class]: classes[a.class] ?? {} },
      });
      for (const f of own.failures.filter((x) => !/no assets|no budget row/.test(x)))
        notes.push(`not shipped: ${f}`);
      continue;
    }
    if (a.error) failures.push(`${a.id}: cannot measure (${a.error})`);
    for (const f of FIELDS) if (!Number.isFinite(a[f])) failures.push(`${a.id}: ${f} not finite`);
    const cap = classes[a.class];
    if (a.class !== "texture") {
      if (!cap) {
        failures.push(`${a.id}: class ${a.class} has no budget row`);
        continue;
      }
      for (const key of ["tris", "verts", "draws"]) {
        const limit = a.exception?.[key] ?? cap[key];
        if (a[key] > limit)
          failures.push(
            `${a.id}: ${key} ${a[key]} over cap ${limit} (${a.class}${a.exception?.[key] !== undefined ? ", exception" : ""})`,
          );
      }
    }
    if (a.class === "enemy") {
      const limit = a.exception?.bones ?? ENEMY_BONES_MAX;
      if (a.bones > limit) failures.push(`${a.id}: bones ${a.bones} over ${limit} (enemy)`);
    }
    const side = a.exception?.max_side;
    if (a.texture_side > maxSide && !(side >= a.texture_side))
      failures.push(
        `${a.id}: texture side ${a.texture_side} over ${maxSide} without an exception field`,
      );
  }
  return { rows, failures, notes };
}

export function characters(assets) {
  const stem = (a) => path.basename(String(a.path)).replace(/\.glb$/, "");
  const live = assets.filter((a) => a.ships !== false);
  const out = [];
  for (const pilot of live.filter((a) => a.class === "pilot")) {
    const m = /^pilot_(.+)_anim$/.exec(stem(pilot));
    if (!m) continue;
    const name = m[1];
    const parts = [
      pilot,
      ...live.filter((a) => {
        const s = stem(a);
        return (
          (a.class === "shell" && s === `shell_${name}`) ||
          (a.class === "detail" && new RegExp(`^shell_${name}_c\\d+$`).test(s))
        );
      }),
    ];
    const sum = (k) => parts.reduce((n, a) => n + a[k], 0);
    out.push({
      name,
      parts: parts.length,
      tris: sum("tris"),
      verts: sum("verts"),
      draws: sum("draws"),
      bones: pilot.bones,
      clips: pilot.clips,
      longest_clip_s: pilot.longest_clip_s,
    });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

const n0 = (x) => (Number.isInteger(x) ? x.toLocaleString("en-US") : x.toFixed(2));
const pair = (s, f = n0) => `${f(s.median)} / ${f(s.p90)}`;
function table(head, rows) {
  const all = [head, ...rows];
  const w = head.map((_, i) => Math.max(...all.map((r) => String(r[i]).length)));
  return all
    .map(
      (r, i) =>
        r.map((c, j) => (j === 0 ? String(c).padEnd(w[j]) : String(c).padStart(w[j]))).join("  ") +
        (i === 0 ? "\n" + w.map((x) => "-".repeat(x)).join("  ") : ""),
    )
    .join("\n");
}

export function render(assets, result, chars) {
  const lines = [];
  lines.push(
    `Promoted assets measured: ${assets.length} (${assets.filter((a) => a.ships === false && a.class !== "texture").length} models not shipped, checked as notes only)`,
    "",
    "Per category (median / p90 over the category's assets):",
  );
  lines.push(
    table(
      [
        "category",
        "n",
        "tris",
        "verts",
        "bones",
        "clips",
        "longest clip s",
        "tex side",
        "cap tris",
      ],
      result.rows.map((r) => [
        r.category + (r.pending ? " (pending)" : ""),
        r.count,
        r.count ? pair(r.stats.tris) : "-",
        r.count ? pair(r.stats.verts) : "-",
        r.count ? pair(r.stats.bones) : "-",
        r.count ? pair(r.stats.clips) : "-",
        r.count ? pair(r.stats.longest_clip_s) : "-",
        r.count ? pair(r.stats.texture_side) : "-",
        r.cap ? n0(r.cap.tris) : "2,048 side",
      ]),
    ),
  );
  lines.push("", "Reference rows from the three comps notes (median / p90; not re-measured here):");
  const ref = (v, f = n0) => (v ? `${f(v[0])} / ${f(v[1])}` : "-");
  lines.push(
    table(
      ["group", "game", "tris", "bones", "clip length s", "texture max side"],
      REFERENCE.map((r) => [r.group, r.game, ref(r.tris), ref(r.bones), ref(r.clip_s), r.tex]),
    ),
  );
  lines.push(
    "Reference units differ: Roboquest rows are whole assets, the others per piece; their clip rows are clip lengths, ours are each asset's longest clip.",
  );
  lines.push("Reference sources: " + REFERENCE.map((r) => r.src).join("; "));
  lines.push("", "Scrapkeep beside the reference (same groups):");
  for (const [group, category] of Object.entries(GROUP_CATEGORY)) {
    const r = result.rows.find((x) => x.category === category);
    lines.push(
      `  ${group}: n ${r.count}, tris ${r.count ? pair(r.stats.tris) : "-"}, bones ${r.count ? pair(r.stats.bones) : "-"}, longest clip s ${r.count ? pair(r.stats.longest_clip_s) : "-"}`,
    );
  }
  lines.push("", "Per whole character (pilot body + shell + heft layers, shipped copies summed):");
  lines.push(
    table(
      ["character", "parts", "tris", "verts", "draws", "bones", "clips", "longest clip s"],
      chars.map((c) => [
        c.name,
        c.parts,
        n0(c.tris),
        n0(c.verts),
        c.draws,
        c.bones,
        c.clips,
        n0(c.longest_clip_s),
      ]),
    ),
  );
  const t = summarize(chars.map((c) => c.tris));
  lines.push(
    `per whole character tris median / p90: ${pair(t)}; reference whole-asset hero tris: Roboquest 34,098 / 35,479.`,
  );
  return lines.join("\n");
}

export function main(argv) {
  const opt = { root: path.resolve(here, "../../.."), budgets: undefined };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--root") opt.root = path.resolve(argv[++i]);
    else if (argv[i] === "--budgets") opt.budgets = path.resolve(argv[++i]);
    else {
      console.error(`Unknown argument ${argv[i]}`);
      return 1;
    }
  }
  const assets = measureRegistry(opt.root);
  const result = evaluate(assets, loadBudgets(opt.root, opt.budgets));
  console.log(render(assets, result, characters(assets)));
  console.log("");
  for (const note of result.notes) console.log(`NOTE ${note}`);
  if (result.notes.length) console.log("");
  if (result.failures.length) {
    console.log(`BUDGET AUDIT FAIL: ${result.failures.length} problem(s)`);
    for (const f of result.failures) console.log(`  ${f}`);
    return 1;
  }
  console.log(
    `BUDGET AUDIT PASS: ${assets.length} assets, ${result.rows.filter((r) => !r.pending).length} counted categories, zero over cap.`,
  );
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exitCode = main(process.argv.slice(2));
