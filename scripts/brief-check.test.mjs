import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import {
  checkAll,
  checkSpec,
  exitCode,
  loadSpecs,
  phraseError,
  stretchedSeconds,
} from "./brief-check.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixtures = path.join(root, "tests/fixtures/brief-check");
const codes = (r) => r.findings.map((f) => f.code);
const clone = (o) => JSON.parse(JSON.stringify(o));

function wavBytes(seconds, sampleRate = 1000) {
  const n = Math.round(seconds * sampleRate);
  const b = Buffer.alloc(44 + n, 128);
  b.write("RIFF", 0);
  b.writeUInt32LE(36 + n, 4);
  b.write("WAVEfmt ", 8);
  b.writeUInt32LE(16, 16);
  b.writeUInt16LE(1, 20);
  b.writeUInt16LE(1, 22);
  b.writeUInt32LE(sampleRate, 24);
  b.writeUInt32LE(sampleRate, 28);
  b.writeUInt16LE(1, 32);
  b.writeUInt16LE(8, 34);
  b.write("data", 36);
  b.writeUInt32LE(n, 40);
  return b;
}

const cleanSpec = () => loadSpecs(path.join(fixtures, "clean"))[0];
const badSpec = () => loadSpecs(path.join(fixtures, "bad"))[0];

test("positive control: the planted bad brief is flagged by each of its three findings", () => {
  const r = checkSpec(badSpec());
  const by = (code) => r.findings.filter((f) => f.code === code);
  assert.equal(by("FILE_MISSING").length, 1, "wrong file");
  assert.equal(by("FILE_MISSING")[0].field, "sources[3].file");
  assert.equal(by("LENGTH_RAW").length, 1, "unstretched length");
  assert.equal(by("LENGTH_RAW")[0].field, "sources[0].to_s");
  assert.equal(by("OFF_PHRASE").length, 1, "off-phrase span");
  assert.equal(by("OFF_PHRASE")[0].field, "sources[1].to_s");
  assert.deepEqual([...new Set(codes(r))].sort(), ["FILE_MISSING", "LENGTH_RAW", "OFF_PHRASE"]);
  assert.ok(r.findings.every((f) => f.id === "bad-take"));
});

test("positive control through the CLI: bad dir exits 1 and lists the three findings", () => {
  const r = spawnSync(
    "node",
    ["scripts/brief-check.mjs", "--dir", "tests/fixtures/brief-check/bad"],
    { cwd: root, encoding: "utf8" },
  );
  assert.equal(r.status, 1);
  for (const code of ["FILE_MISSING", "LENGTH_RAW", "OFF_PHRASE"])
    assert.match(r.stdout, new RegExp(code));
});

test("clean fixture has zero findings and the CLI exits 0", () => {
  const r = checkAll(loadSpecs(path.join(fixtures, "clean")));
  assert.deepEqual(r.findings, []);
  assert.deepEqual(r.unchecked, []);
  const cli = spawnSync(
    "node",
    ["scripts/brief-check.mjs", "--dir", "tests/fixtures/brief-check/clean", "--strict"],
    { cwd: root, encoding: "utf8" },
  );
  assert.equal(cli.status, 0, cli.stdout);
});

test("phrase tolerance edges: on the boundary, within tolerance, just outside", () => {
  const spec = cleanSpec();
  assert.equal(phraseError(4, spec), 0);
  const edit = (t) => codes(checkSpec({ ...clone(spec), edits: [t] })).includes("OFF_PHRASE");
  assert.equal(edit(4), false, "exactly on");
  assert.equal(edit(4.12), false, "exactly at tolerance");
  assert.equal(edit(3.9), false, "within, before the boundary");
  assert.equal(edit(4.13), true, "just outside");
  assert.equal(edit(3.87), true, "just outside, before the boundary");
  const s = clone(spec);
  s.sources[1].to_s = 3.85;
  assert.ok(codes(checkSpec(s)).includes("OFF_PHRASE"), "a span end is checked too");
});

test("length is compared after tempo stretch, loop lets a span run past, gap does not", () => {
  const spec = clone(cleanSpec());
  spec.take_bpm = 128;
  spec.pick.native_bpm = 120;
  spec.phrase_bars = 1;
  spec.edits = [];
  assert.ok(Math.abs(stretchedSeconds(spec) - 3.75) < 1e-9);
  spec.sources = [{ part: "drums", from_s: 0, to_s: 5.625, action: "use" }];
  assert.ok(codes(checkSpec(spec)).includes("LENGTH_RAW"));
  spec.sources[0].loop = true;
  assert.ok(!codes(checkSpec(spec)).includes("LENGTH_RAW"));
  spec.sources[0] = { part: "drums", from_s: 0, to_s: 5.625, action: "use", gap: true };
  assert.ok(codes(checkSpec(spec)).includes("LENGTH_RAW"), "gap no longer skips the length check");
});

test("an unavailable root reports unchecked, never a pass", () => {
  const spec = {
    ...clone(cleanSpec()),
    pick: { ...clone(cleanSpec().pick), root: "music_direction", file: "spice/x.wav" },
  };
  const r = checkSpec(spec, {
    roots: { music_direction: path.join(os.tmpdir(), "brief-check-no-such-root") },
  });
  assert.deepEqual(codes(r), []);
  assert.equal(r.unchecked.length, 1);
  assert.equal(r.unchecked[0].field, "pick.file");
  assert.equal(exitCode(r, false), 0);
  assert.equal(exitCode(r, true), 2);
  const pack = checkSpec(
    { ...spec, pick: { ...spec.pick, root: "pack" } },
    { roots: { pack: path.join(os.tmpdir(), "brief-check-no-pack") } },
  );
  assert.equal(pack.unchecked.length, 1, "pack root without STEMS.sha256 on disk is unavailable");
});

test("hash: wrong spec hash, wrong STEMS.sha256 entry, and native length drift", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "brief-check-"));
  try {
    const wav = wavBytes(4);
    mkdirSync(path.join(dir, "pack/theme"), { recursive: true });
    writeFileSync(path.join(dir, "pack/theme/a.wav"), wav);
    writeFileSync(path.join(dir, "repo.wav"), wav);
    const good = createHash("sha256").update(wav).digest("hex");
    writeFileSync(path.join(dir, "pack/STEMS.sha256"), `${"0".repeat(64)}  theme/a.wav\n`);
    const roots = { repo: dir, pack: path.join(dir, "pack") };
    const base = clone(cleanSpec());
    base.edits = [];

    let spec = {
      ...base,
      pick: { ...base.pick, root: "repo", file: "repo.wav", sha256: "f".repeat(64) },
    };
    let r = checkSpec(spec, { roots });
    assert.deepEqual(codes(r), ["HASH_MISMATCH"]);
    spec = { ...base, pick: { ...base.pick, root: "repo", file: "repo.wav", sha256: good } };
    assert.deepEqual(codes(checkSpec(spec, { roots })), []);
    spec = { ...base, pick: { ...base.pick, root: "pack", file: "theme/a.wav", sha256: good } };
    r = checkSpec(spec, { roots });
    assert.deepEqual(codes(r), ["HASH_MISMATCH"]);
    assert.match(r.findings[0].message, /STEMS\.sha256/);
    writeFileSync(path.join(dir, "pack/STEMS.sha256"), `${good}  theme/a.wav\n`);
    assert.deepEqual(codes(checkSpec(spec, { roots })), []);
    spec = {
      ...base,
      pick: { ...base.pick, root: "repo", file: "repo.wav", sha256: good, native_seconds: 4.5 },
    };
    r = checkSpec(spec, { roots });
    assert.deepEqual(codes(r), ["LENGTH_RAW"]);
    assert.equal(r.findings[0].field, "pick.native_seconds");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("sections must chain, end at seconds, and match the journey", () => {
  const f = (edit) => {
    const s = clone(cleanSpec());
    edit(s);
    return codes(checkSpec(s)).filter((c) => c === "SECTIONS_SUM").length;
  };
  assert.equal(
    f(() => {}),
    0,
  );
  assert.equal(
    f((s) => (s.sections[1].start_s = 4.5)),
    1,
    "gap",
  );
  assert.equal(
    f((s) => (s.sections[1].start_s = 3.5)),
    1,
    "overlap",
  );
  assert.equal(
    f((s) => (s.sections[1].end_s = 7)),
    1,
    "short of seconds",
  );
  assert.equal(
    f((s) => s.journey.pop()),
    1,
    "journey misses a section",
  );
  assert.equal(
    f((s) => s.journey.reverse()),
    1,
    "journey out of order",
  );
});

test("span holes: over a bar flags, a mute covers, guide only exempts", () => {
  const holes = (edit) => {
    const s = clone(cleanSpec());
    edit(s);
    return checkSpec(s).findings.filter((x) => x.code === "SPAN_HOLE");
  };
  assert.equal(holes(() => {}).length, 0);
  const cut = holes((s) => (s.sources[3].to_s = 4));
  assert.equal(cut.length, 1);
  assert.equal(cut[0].field, "part:other");
  assert.equal(holes((s) => (s.sources[3].to_s = 6)).length, 0, "exactly one bar is allowed");
  assert.equal(holes((s) => (s.sources[1].action = "mute")).length, 0, "mute still covers");
  assert.equal(
    holes((s) => {
      s.sources = [{ part: "guide", from_s: 0, to_s: 8, action: "use", note: "guide only" }];
    }).length,
    0,
  );
});

test("a spec missing a required field reports BAD_SPEC", () => {
  const s = clone(cleanSpec());
  delete s.take_bpm;
  assert.deepEqual(codes(checkSpec(s)), ["BAD_SPEC"]);
});

const offsetSpec = (src) => {
  const s = clone(cleanSpec());
  s.take_bpm = 128;
  s.pick.native_bpm = 120;
  s.phrase_bars = 1;
  s.edits = [];
  s.sources = [src];
  return s;
};
const lengthFindings = (s) =>
  checkSpec(s).findings.filter((f) => f.code === "LENGTH_RAW" || f.code === "PICK_FROM_MISSING");

test("an offset stem is flagged when gap: true is the only thing hiding its length", () => {
  const src = { part: "drums", from_s: 3.75, to_s: 7.5, action: "use", pick_from_s: 3, gap: true };
  assert.deepEqual(
    lengthFindings(offsetSpec(src)).map((f) => f.code),
    ["LENGTH_RAW"],
  );
  const { pick_from_s, ...noPick } = src;
  assert.deepEqual(
    lengthFindings(offsetSpec(noPick)).map((f) => f.code),
    ["PICK_FROM_MISSING", "LENGTH_RAW"],
    "with gap and no pick_from_s it is still live",
  );
});

test("an offset stem with a correct pick_from_s passes, one over the stretched pick by pick_from_s flags", () => {
  const ok = { part: "drums", from_s: 3.75, to_s: 7.5, action: "use", pick_from_s: 0 };
  assert.deepEqual(lengthFindings(offsetSpec(ok)), []);
  const late = { ...ok, pick_from_s: 0.5 };
  const f = lengthFindings(offsetSpec(late));
  assert.equal(f.length, 1);
  assert.equal(f[0].code, "LENGTH_RAW");
  assert.equal(
    lengthFindings(offsetSpec({ ...ok, pick_from_s: 0.1 })).length,
    0,
    "within tolerance",
  );
  assert.equal(
    lengthFindings(offsetSpec({ ...ok, loop: true, pick_from_s: 0.5 })).length,
    0,
    "loop runs past",
  );
});

test("a guide span is exempt from the length check", () => {
  const src = { part: "guide", from_s: 0, to_s: 8, action: "use", note: "guide only" };
  assert.deepEqual(lengthFindings(offsetSpec(src)), []);
  assert.deepEqual(
    lengthFindings(offsetSpec({ ...src, from_s: 2 })),
    [],
    "no PICK_FROM_MISSING for a guide",
  );
});

test("PICK_FROM_MISSING: a use span from_s != 0 without pick_from_s; mute and from_s 0 are exempt", () => {
  const miss = { part: "drums", from_s: 1, to_s: 2, action: "use" };
  const f = lengthFindings(offsetSpec(miss));
  assert.deepEqual(
    f.map((x) => x.code),
    ["PICK_FROM_MISSING"],
  );
  assert.equal(f[0].field, "sources[0].pick_from_s");
  assert.deepEqual(lengthFindings(offsetSpec({ ...miss, action: "mute" })), []);
  assert.deepEqual(lengthFindings(offsetSpec({ ...miss, from_s: 0, to_s: 2 })), []);
  assert.deepEqual(codes(checkSpec(offsetSpec({ ...miss, pick_from_s: "x" }))), ["BAD_SPEC"]);
});

const leadFindings = (s) => checkSpec(s).findings.filter((f) => f.code === "OTHER_STEM_LEAD");
const withOther = (edit) => {
  const s = clone(cleanSpec());
  edit(s.sources[3], s);
  return s;
};

test("OTHER_STEM_LEAD positive control: 'other' kept with no guide_matches_pick is flagged", () => {
  const f = leadFindings(withOther((o) => delete o.guide_matches_pick));
  assert.equal(f.length, 1);
  assert.equal(f[0].field, "sources[3].guide_matches_pick");
  assert.equal(f[0].id, "clean-take");
});

test("OTHER_STEM_LEAD: 'other' inside a guide_matches_pick span passes, partly outside flags", () => {
  assert.deepEqual(leadFindings(cleanSpec()), [], "fixture span covers bars 0 to 4");
  const inside = (g, from, to) =>
    leadFindings(
      withOther((o) =>
        Object.assign(o, { guide_matches_pick: g, from_s: from, to_s: to, loop: true }),
      ),
    );
  assert.deepEqual(inside({ from_s: 0, to_s: 8 }, 0, 8), [], "seconds form, exactly equal");
  assert.deepEqual(inside({ from_bar: 1, to_bar: 3 }, 2, 6), [], "bars form, equal");
  assert.equal(inside({ from_bar: 1, to_bar: 3 }, 0, 6).length, 1, "starts before the span");
  assert.equal(inside({ from_bar: 1, to_bar: 3 }, 2, 8).length, 1, "ends after the span");
  assert.equal(inside({ from_s: 2, to_s: 6 }, 2, 6.1).length, 0, "within tolerance_s");
  assert.equal(inside({ from_s: 2, to_s: 6 }, 2, 6.2).length, 1, "past tolerance_s");
  assert.deepEqual(
    codes(checkSpec(withOther((o) => (o.guide_matches_pick = { from_bar: "x" })))),
    ["BAD_SPEC"],
    "malformed span",
  );
});

test("OTHER_STEM_LEAD leaves mute, guide, drums and bass alone", () => {
  const s = clone(cleanSpec());
  s.sources[3].action = "mute";
  s.sources[3].gap = true;
  s.sources.push({ part: "guide", from_s: 0, to_s: 8, action: "use" });
  assert.deepEqual(
    leadFindings(s),
    [],
    "a muted other, a guide, drums and bass (none carry guide_matches_pick)",
  );
  assert.deepEqual(leadFindings(badSpec()), [], "the planted bad brief mutes other");
});

test("gap: true marks a deliberate hole for SPAN_HOLE only", () => {
  const s = clone(cleanSpec());
  s.sources[3].to_s = 4;
  assert.equal(checkSpec(s).findings.filter((x) => x.code === "SPAN_HOLE").length, 1);
  s.sources[3].gap = true;
  assert.equal(checkSpec(s).findings.filter((x) => x.code === "SPAN_HOLE").length, 0);
});
