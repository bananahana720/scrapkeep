import { createServer } from "node:http";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { isMain } from "../../../scripts/lib/cli.mjs";
import { git } from "../../../scripts/lib/git.mjs";

// npm run sitting-kit: serves the Sitting Kit page on localhost and keeps Andrew's verdicts on disk.
// GET  /                 the page (index.html and the files beside it)
// GET  /api/build        { sha, short, subject, dirty } of the checkout, so the page names the build he plays
// GET  /api/verdicts     the saved verdicts, or {}
// POST /api/verdicts     replaces the saved verdicts (a JSON object, 256 KB at most)
// The saved file is artifacts/local/sitting-kit/verdicts.json (gitignored). The page also keeps a copy in
// localStorage, so it works from a plain file too; the server adds the file the coordinator reads.
// Run: node project-guide/handoff/sitting-kit/serve.mjs [--port 8765] [--verdicts <file>]

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "..", "..", "..");
export const VERDICT_FILE = path.join(repo, "artifacts", "local", "sitting-kit", "verdicts.json");
export const MAX_BODY = 256 * 1024;
export const HOST = "127.0.0.1";
const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".md": "text/markdown; charset=utf-8",
  ".svg": "image/svg+xml",
};
const SERVED = new Set(["index.html", "areas.js", "README.md"]);

export function readBuild(cwd = repo) {
  const read = (...args) => git(args, { cwd, stdio: ["ignore", "pipe", "ignore"] });
  try {
    return {
      sha: read("rev-parse", "HEAD"),
      short: read("rev-parse", "--short=8", "HEAD"),
      subject: read("log", "-1", "--format=%s"),
      dirty: read("status", "--porcelain").length > 0,
    };
  } catch {
    return { sha: "", short: "unknown", subject: "", dirty: false };
  }
}

export function readVerdicts(file = VERDICT_FILE) {
  if (!existsSync(file)) {
    return {};
  }
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return {};
  }
}

// Write through a temp file, so a crash mid-write leaves the last good copy.
export function writeVerdicts(value, file = VERDICT_FILE) {
  mkdirSync(path.dirname(file), { recursive: true });
  const temp = `${file}.tmp`;
  writeFileSync(temp, `${JSON.stringify(value, null, 2)}\n`);
  renameSync(temp, file);
}

function send(res, status, body, type = "application/json; charset=utf-8") {
  res.writeHead(status, {
    "content-type": type,
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
  });
  res.end(typeof body === "string" || Buffer.isBuffer(body) ? body : JSON.stringify(body));
}

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let refused = false;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > limit) {
        // Answer 413 at once and keep draining the rest, so the client sees the status and not a reset.
        if (!refused) {
          refused = true;
          chunks.length = 0;
          reject(new Error("too large"));
        }
      } else if (!refused) {
        chunks.push(chunk);
      }
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

// A page on another origin must not write his verdicts: only a request from this server's own origin passes.
export function sameOrigin(req) {
  const origin = req.headers.origin;
  if (origin === undefined) {
    return true;
  }
  const port = req.socket.localPort;
  return origin === `http://localhost:${port}` || origin === `http://${HOST}:${port}`;
}

// The Host header must name this machine, which closes DNS rebinding: a page on another name cannot read the verdicts.
export function localHost(req) {
  const host = String(req.headers.host ?? "").replace(/:\d+$/, "");
  return host === "localhost" || host === HOST;
}

export function createKitServer({
  port = 8765,
  verdictFile = VERDICT_FILE,
  buildOf = readBuild,
} = {}) {
  return createServer(async (req, res) => {
    try {
      await handle(req, res);
    } catch (error) {
      send(res, 500, { error: String(error.message) });
    }
  });

  async function handle(req, res) {
    if (!localHost(req)) {
      send(res, 403, { error: "host not allowed" });
      return;
    }
    let url;
    try {
      url = new URL(req.url ?? "/", `http://${HOST}:${port}`);
    } catch {
      send(res, 400, { error: "bad request target" });
      return;
    }
    if (url.pathname === "/api/build" && req.method === "GET") {
      send(res, 200, buildOf());
    } else if (url.pathname === "/api/verdicts" && req.method === "GET") {
      send(res, 200, readVerdicts(verdictFile));
    } else if (url.pathname === "/api/verdicts" && req.method === "POST") {
      if (!sameOrigin(req)) {
        send(res, 403, { error: "cross-origin write refused" });
        return;
      }
      let parsed;
      try {
        parsed = JSON.parse(await readBody(req, MAX_BODY));
      } catch (error) {
        send(res, error.message === "too large" ? 413 : 400, { error: String(error.message) });
        return;
      }
      if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
        send(res, 400, { error: "body must be a JSON object" });
      } else {
        writeVerdicts(parsed, verdictFile);
        send(res, 200, { ok: true, saved: new Date().toISOString() });
      }
    } else if (req.method === "GET") {
      const name = url.pathname === "/" ? "index.html" : url.pathname.slice(1);
      if (!SERVED.has(name) || !existsSync(path.join(here, name))) {
        send(res, 404, "not found", "text/plain; charset=utf-8");
      } else {
        send(
          res,
          200,
          readFileSync(path.join(here, name)),
          TYPES[path.extname(name)] ?? "application/octet-stream",
        );
      }
    } else {
      send(res, 405, { error: "method not allowed" });
    }
  }
}

if (isMain(import.meta.url)) {
  const at = process.argv.indexOf("--port");
  const port = at >= 0 ? Number(process.argv[at + 1]) : 8765;
  const at2 = process.argv.indexOf("--verdicts");
  const verdictFile = at2 >= 0 ? path.resolve(process.argv[at2 + 1]) : VERDICT_FILE;
  const server = createKitServer({ port, verdictFile });
  server.listen(port, HOST, () => {
    console.log(`Sitting Kit on http://localhost:${port}/  (verdicts: ${verdictFile})`);
  });
}
