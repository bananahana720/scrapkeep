import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtemp,
  mkdir,
  readFile,
  rename,
  rm,
  stat,
  symlink,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createLeadServer } from "../../server/index.js";

const submission = (overrides = {}) => ({
  email: "synthetic@example.test",
  consent: { email: true, sms: false },
  heroClass: "scavenger",
  source: "collection",
  run: { seed: 42, score: 120, wave: 3, outcome: "gameover" },
  website: "",
  ...overrides,
});

async function fixture(t, options = {}) {
  const directory = await mkdtemp(
    path.join(os.tmpdir(), "scrapkeep-leads-test-"),
  );
  const dataDirectory = path.join(directory, "private");
  const distDirectory = path.join(directory, "dist");
  await mkdir(distDirectory);
  await writeFile(
    path.join(distDirectory, "index.html"),
    "<!doctype html><title>Scrapkeep test</title>",
  );
  let app;
  let base;
  async function start() {
    app = await createLeadServer({
      dataDirectory,
      distDirectory,
      rateLimit: 100,
      ...options,
    });
    await new Promise((resolve) => app.server.listen(0, "127.0.0.1", resolve));
    base = `http://127.0.0.1:${app.server.address().port}`;
  }
  await start();
  t.after(async () => {
    await app.close();
    await rm(directory, { recursive: true, force: true });
  });
  return {
    directory,
    dataDirectory,
    distDirectory,
    get base() {
      return base;
    },
    async restart() {
      await app.close();
      await start();
    },
    async post(body, headers = {}) {
      const response = await fetch(`${base}/api/leads`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Origin: base,
          ...headers,
        },
        body: typeof body === "string" ? body : JSON.stringify(body),
      });
      return {
        status: response.status,
        body: await response.json(),
        headers: response.headers,
      };
    },
    async leads() {
      return JSON.parse(
        await readFile(path.join(dataDirectory, "leads.json"), "utf8"),
      ).leads;
    },
  };
}

test("HTTP capture persists consent, contact, interest and run metadata across restart", async (t) => {
  const f = await fixture(t);
  const result = await f.post(
    submission({ email: " Synthetic@Example.Test " }),
  );
  assert.equal(result.status, 201);
  assert.equal(result.body.delivery, "stored");
  assert.deepEqual(Object.keys(result.body).sort(), ["delivery", "id", "ok"]);
  await f.restart();
  const [lead] = await f.leads();
  assert.equal(lead.id, result.body.id);
  assert.equal(lead.contacts.email[0].value, "synthetic@example.test");
  assert.equal(lead.contacts.email[0].consent.granted, true);
  assert.equal(lead.contacts.email[0].consent.version, "2026-09-05-v1");
  assert.equal(
    lead.contacts.email[0].consent.text,
    "Email me Scrapkeep figurine news and launch updates.",
  );
  assert.ok(Number.isFinite(Date.parse(lead.contacts.email[0].consent.at)));
  assert.deepEqual(lead.interests, ["scavenger"]);
  assert.deepEqual(lead.latestRun, submission().run);
  assert.equal(
    (await stat(path.join(f.dataDirectory, "leads.json"))).mode & 0o777,
    0o600,
  );
  assert.equal((await f.post(submission())).body.id, result.body.id);
});

test("retries and concurrent submissions merge interests and separately opted-in channels", async (t) => {
  const f = await fixture(t);
  const first = await f.post(submission());
  const responses = await Promise.all(
    Array.from({ length: 18 }, (_, index) =>
      f.post(
        submission({
          phone: "+14155550123",
          consent: { email: true, sms: true },
          heroClass: ["scavenger", "engineer", "warden"][index % 3],
        }),
      ),
    ),
  );
  assert.ok(
    responses.every(
      (response) =>
        response.status === 200 && response.body.id === first.body.id,
    ),
  );
  const [lead] = await f.leads();
  assert.equal((await f.leads()).length, 1);
  assert.deepEqual(lead.interests.sort(), ["engineer", "scavenger", "warden"]);
  assert.equal(lead.contacts.email.length, 1);
  assert.equal(lead.contacts.sms.length, 1);
  assert.equal(lead.contacts.sms[0].consent.granted, true);
  assert.match(lead.contacts.sms[0].consent.text, /when messaging is enabled/);
});

test("a submission bridging existing email and phone records retains all preferences", async (t) => {
  const f = await fixture(t);
  await f.post(submission());
  await f.post(
    submission({
      email: undefined,
      phone: "+14155550124",
      consent: { email: false, sms: true },
      heroClass: "warden",
    }),
  );
  assert.equal((await f.leads()).length, 2);
  await f.post(
    submission({
      phone: "+14155550124",
      consent: { email: true, sms: true },
      heroClass: "engineer",
    }),
  );
  const leads = await f.leads();
  assert.equal(leads.length, 1);
  assert.equal(leads[0].contacts.email.length, 1);
  assert.equal(leads[0].contacts.sms.length, 1);
  assert.deepEqual(leads[0].interests.sort(), [
    "engineer",
    "scavenger",
    "warden",
  ]);
});

test("malformed, unconsented and bot submissions cannot reach storage", async (t) => {
  const f = await fixture(t);
  const invalid = [
    "{broken",
    null,
    [],
    submission({ consent: undefined }),
    submission({ consent: { email: "true", sms: false } }),
    submission({ consent: { email: false, sms: false } }),
    submission({ email: "" }),
    submission({ email: "not-an-email" }),
    submission({ email: "a..b@example.test" }),
    submission({ email: 123 }),
    submission({ phone: "+14155550123" }),
    submission({
      email: undefined,
      phone: "4155550123",
      consent: { email: false, sms: true },
    }),
    submission({
      email: undefined,
      phone: "+14155550123",
      consent: { email: false, sms: false },
    }),
    submission({ heroClass: "wizard" }),
    submission({ website: "bot.example" }),
    submission({ source: "unknown" }),
    submission({ run: { seed: -1, score: 1, wave: 1, outcome: "victory" } }),
    submission({ extra: true }),
  ];
  for (const body of invalid)
    assert.equal((await f.post(body)).status, 400, JSON.stringify(body));
  await assert.rejects(readFile(path.join(f.dataDirectory, "leads.json")), {
    code: "ENOENT",
  });
});

test("origin, content type, body size and rate limits return safe errors", async (t) => {
  const f = await fixture(t, { rateLimit: 3 });
  assert.equal(
    (await f.post(submission(), { Origin: "https://foreign.example" })).status,
    403,
  );
  assert.equal((await f.post(submission(), { Origin: "" })).status, 403);
  assert.equal(
    (await f.post(submission(), { "Content-Type": "text/plain" })).status,
    415,
  );
  assert.equal(
    (await f.post(JSON.stringify({ pad: "a".repeat(9000) }))).status,
    413,
  );
  assert.equal((await f.post(submission())).status, 201);
  const limited = await f.post(submission());
  assert.equal(limited.status, 429);
  assert.ok(Number(limited.headers.get("retry-after")) > 0);
  assert.deepEqual(Object.keys(limited.body).sort(), ["error", "ok"]);
});

test("failed durable writes return 503 and retry can save after storage recovers", async (t) => {
  const f = await fixture(t);
  const relocated = path.join(f.directory, "moved-private");
  await rename(f.dataDirectory, relocated);
  try {
    const result = await f.post(submission());
    assert.equal(result.status, 503);
    assert.equal(result.body.ok, false);
    assert.equal(result.body.id, undefined);
    assert.doesNotMatch(result.body.error, /ENOENT|private|leads\.json/);
  } finally {
    await rename(relocated, f.dataDirectory);
  }
  assert.equal((await f.post(submission())).status, 201);
  assert.equal((await f.leads()).length, 1);
});

test("private records, directory traversal and static symlinks are not served", async (t) => {
  const f = await fixture(t);
  await f.post(submission());
  await symlink(
    path.join(f.dataDirectory, "leads.json"),
    path.join(f.distDirectory, "stolen.json"),
  );
  assert.match(await (await fetch(f.base)).text(), /Scrapkeep test/);
  for (const url of [
    "/api/leads",
    "/.private/leads/leads.json",
    "/leads.json",
    "/%2e%2e%2fprivate/leads.json",
    "/stolen.json",
  ]) {
    assert.equal((await fetch(f.base + url)).status, 404, url);
  }
});

test("config contains public settings and accurate delivery and consent copy", async (t) => {
  const f = await fixture(t, {
    brand: "Test Workshop",
    storeUrl: "https://example.test/shop",
    privacyUrl: "https://example.test/privacy",
  });
  const config = await (await fetch(f.base + "/api/config")).json();
  assert.equal(config.brand, "Test Workshop");
  assert.equal(config.localOnly, true);
  assert.equal(config.captureEnabled, true);
  assert.equal(config.storeUrl, "https://example.test/shop");
  assert.equal(config.privacyUrl, "https://example.test/privacy");
  assert.equal(
    config.consentText.email,
    "Email me Test Workshop figurine news and launch updates.",
  );
  assert.equal(config.dataDirectory, undefined);
});

test("disabled capture does not create lead storage", async (t) => {
  const f = await fixture(t, { captureEnabled: false });
  assert.equal((await f.post(submission())).status, 503);
  assert.equal(
    (await (await fetch(f.base + "/api/config")).json()).captureEnabled,
    false,
  );
  await assert.rejects(stat(f.dataDirectory), { code: "ENOENT" });
});

test("second writer cannot open a live store", async (t) => {
  const f = await fixture(t);
  await assert.rejects(
    createLeadServer({
      dataDirectory: f.dataDirectory,
      distDirectory: f.distDirectory,
    }),
    /locked/,
  );
});

test("storage cannot be placed under static output", async (t) => {
  const f = await fixture(t);
  await assert.rejects(
    createLeadServer({
      dataDirectory: path.join(f.distDirectory, "private"),
      distDirectory: f.distDirectory,
    }),
    /outside public and dist/,
  );
  const alias = path.join(f.directory, "public-alias");
  await symlink(f.distDirectory, alias);
  await assert.rejects(
    createLeadServer({
      dataDirectory: path.join(alias, "new", "private"),
      distDirectory: f.distDirectory,
    }),
    /outside public and dist/,
  );
});

test("orphaned temporary snapshots do not replace the last committed data", async (t) => {
  const f = await fixture(t);
  const result = await f.post(submission());
  await writeFile(
    path.join(f.dataDirectory, "leads-interrupted.tmp"),
    "{unfinished",
  );
  await f.restart();
  assert.equal((await f.leads())[0].id, result.body.id);
  assert.equal((await f.post(submission())).status, 200);
});

test("corrupt committed storage fails startup without overwriting it", async (t) => {
  const directory = await mkdtemp(
    path.join(os.tmpdir(), "scrapkeep-corrupt-test-"),
  );
  t.after(() => rm(directory, { recursive: true, force: true }));
  const dataDirectory = path.join(directory, "private");
  await mkdir(dataDirectory);
  const filename = path.join(dataDirectory, "leads.json");
  await writeFile(filename, "{corrupt");
  await assert.rejects(createLeadServer({ dataDirectory }), SyntaxError);
  assert.equal(await readFile(filename, "utf8"), "{corrupt");
  await assert.rejects(stat(path.join(dataDirectory, "leads.lock")), {
    code: "ENOENT",
  });
});
