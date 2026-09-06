import assert from "node:assert/strict";
import http from "node:http";
import { readFile, realpath, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const distDirectory = path.join(root, "dist");
const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".png": "image/png",
  ".woff2": "font/woff2",
};

function isWithin(parent, target) {
  const relative = path.relative(parent, target);
  return (
    relative === "" ||
    (!relative.startsWith(`..${path.sep}`) &&
      relative !== ".." &&
      !path.isAbsolute(relative))
  );
}

async function resolveFile(distRealpath, pathname) {
  let decoded;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return null;
  }
  if (
    decoded.includes("\\") ||
    decoded.split("/").some((part) => part.startsWith("."))
  )
    return null;
  const file = path.resolve(
    distRealpath,
    `.${decoded === "/" ? "/index.html" : decoded}`,
  );
  if (!isWithin(distRealpath, file)) return null;
  let actual;
  try {
    actual = await realpath(file);
  } catch {
    return null;
  }
  if (!isWithin(distRealpath, actual)) return null;
  if (!(await stat(actual)).isFile()) return null;
  return actual;
}

async function createStaticServer(directory) {
  const distRealpath = await realpath(directory);
  const server = http.createServer(async (request, response) => {
    if (!["GET", "HEAD"].includes(request.method)) {
      response.writeHead(405).end();
      return;
    }
    const pathname = new URL(request.url, "http://127.0.0.1").pathname;
    const file = await resolveFile(distRealpath, pathname);
    if (!file) {
      response.writeHead(404).end();
      return;
    }
    const body = await readFile(file);
    response.writeHead(200, {
      "Content-Type":
        contentTypes[path.extname(file)] ?? "application/octet-stream",
      "X-Content-Type-Options": "nosniff",
      "Content-Length": body.length,
    });
    response.end(request.method === "HEAD" ? undefined : body);
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  return server;
}

for (const file of ["index.html", "orchard.html"])
  await readFile(path.join(distDirectory, file));
const server = await createStaticServer(distDirectory);
const results = [];
try {
  const origin = "http://127.0.0.1:" + server.address().port;
  const get = (route) =>
    fetch(new URL(route, origin), { signal: AbortSignal.timeout(10000) });
  for (const [route, title] of [
    ["/", "Small heroes. Serious scrap."],
    ["/orchard.html", "The Iron Orchard"],
  ]) {
    const response = await get(route);
    assert.equal(response.status, 200, route);
    const html = await response.text();
    assert.ok(html.includes(title), "Wrong entry served for " + route);
    const assets = [
      ...new Set(
        [...html.matchAll(/(?:src|href)="([^"]+)"/g)].map((m) => m[1]),
      ),
    ];
    assert.ok(
      assets.some(
        (asset) => asset.includes("/assets/") && asset.endsWith(".js"),
      ),
      "Missing entry bundle",
    );
    for (const asset of assets) {
      const url = new URL(asset, origin);
      assert.equal(
        url.origin,
        origin,
        "Unexpected remote HTML dependency: " + asset,
      );
      const result = await get(asset);
      assert.equal(result.status, 200, asset);
      assert.ok(
        (await result.arrayBuffer()).byteLength > 0,
        "Empty asset: " + asset,
      );
    }
    results.push({
      route,
      status: response.status,
      linkedAssets: assets.length,
    });
  }
  for (const route of [
    "/api/config",
    "/.git/HEAD",
    "/../package.json",
    "/%2e%2e/package.json",
    "/assets\\..\\package.json",
    "/assets/",
  ])
    assert.equal((await get(route)).status, 404, route);
  console.log(
    JSON.stringify(
      { result: "pass", records: results, apiConfigStatus: 404 },
      null,
      2,
    ),
  );
} finally {
  await new Promise((resolve) => server.close(resolve));
}
