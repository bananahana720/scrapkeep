import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createLeadServer } from "../server/index.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
for (const file of ["index.html", "orchard.html"])
  await readFile(path.join(root, "dist", file));
const app = await createLeadServer({
  captureEnabled: false,
  distDirectory: path.join(root, "dist"),
});
const results = [];
try {
  await new Promise((resolve, reject) => {
    app.server.once("error", reject);
    app.server.listen(0, "127.0.0.1", resolve);
  });
  const origin = "http://127.0.0.1:" + app.server.address().port;
  for (const [route, title] of [
    ["/", "Small heroes. Serious scrap."],
    ["/orchard.html", "The Iron Orchard"],
  ]) {
    const response = await fetch(origin + route, {
      signal: AbortSignal.timeout(10000),
    });
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
      const result = await fetch(url, { signal: AbortSignal.timeout(10000) });
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
  const config = await (
    await fetch(origin + "/api/config", { signal: AbortSignal.timeout(10000) })
  ).json();
  assert.equal(config.captureEnabled, false);
  console.log(
    JSON.stringify(
      { result: "pass", records: results, captureEnabled: false },
      null,
      2,
    ),
  );
} finally {
  await app.close();
}
