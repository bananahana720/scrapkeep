import http from "node:http";
import { readFile, realpath, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { openLeadStore } from "./store.js";
import {
  CONSENT_VERSION,
  consentText,
  parseLead,
  RequestError,
} from "./validation.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
  ".glb": "model/gltf-binary",
  ".gltf": "model/gltf+json",
  ".mp3": "audio/mpeg",
  ".wav": "audio/wav",
  ".ogg": "audio/ogg",
};

function optionalUrl(value) {
  if (!value) return null;
  const url = new URL(value);
  if (
    !["https:", "http:"].includes(url.protocol) ||
    url.username ||
    url.password
  )
    throw new Error(
      "Store and privacy URLs must be HTTP or HTTPS URLs without credentials.",
    );
  return url.href;
}

function isWithin(parent, target) {
  const relative = path.relative(parent, target);
  return (
    relative === "" ||
    (!relative.startsWith(`..${path.sep}`) &&
      relative !== ".." &&
      !path.isAbsolute(relative))
  );
}

async function prospectiveRealpath(filename) {
  try {
    return await realpath(filename);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
    const parent = path.dirname(filename);
    if (parent === filename) throw error;
    return path.join(
      await prospectiveRealpath(parent),
      path.basename(filename),
    );
  }
}

function json(response, status, body) {
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  response.end(JSON.stringify(body));
}

async function readJson(request) {
  if (
    !/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(
      request.headers["content-type"] ?? "",
    )
  ) {
    throw new RequestError(415, "Send the form as JSON.");
  }
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 8192) throw new RequestError(413, "The form is too large.");
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new RequestError(400, "The form could not be read.");
  }
}

export async function createLeadServer(options = {}) {
  const brand = options.brand ?? process.env.BRAND_NAME ?? "Scrapkeep";
  if (!brand.trim() || brand.length > 80 || /[\u0000-\u001f]/.test(brand))
    throw new Error("BRAND_NAME must contain 1 to 80 printable characters.");
  const config = {
    brand,
    storeUrl: optionalUrl(options.storeUrl ?? process.env.STORE_URL),
    privacyUrl: optionalUrl(options.privacyUrl ?? process.env.PRIVACY_URL),
    captureEnabled:
      options.captureEnabled ?? process.env.CAPTURE_ENABLED !== "false",
    localOnly: true,
    consentVersion: CONSENT_VERSION,
    consentText: consentText(brand),
  };
  const distDirectory = path.resolve(
    options.distDirectory ?? path.join(root, "dist"),
  );
  const dataDirectory = path.resolve(
    options.dataDirectory ??
      process.env.LEADS_DATA_DIR ??
      path.join(root, ".private", "leads"),
  );
  const publicDirectory = path.join(root, "public");
  for (const publicPath of [distDirectory, publicDirectory]) {
    const actualPublic = await prospectiveRealpath(publicPath);
    const actualData = await prospectiveRealpath(dataDirectory);
    if (
      isWithin(actualPublic, actualData) ||
      isWithin(publicPath, dataDirectory)
    ) {
      throw new Error("Lead storage must be outside public and dist.");
    }
  }
  const origins = new Set(
    options.allowedOrigins ??
      (process.env.APP_ORIGIN
        ? process.env.APP_ORIGIN.split(",").map(
            (value) => new URL(value.trim()).origin,
          )
        : [
            "http://localhost:5173",
            "http://127.0.0.1:5173",
            "http://localhost:4173",
            "http://127.0.0.1:4173",
          ]),
  );
  const store = config.captureEnabled
    ? await openLeadStore(dataDirectory, config.consentText)
    : null;
  const limits = new Map();
  const rateLimit = options.rateLimit ?? 20;
  let server;

  server = http.createServer(async (request, response) => {
    try {
      const pathname = new URL(request.url, "http://localhost").pathname;
      if (pathname === "/api/config" && request.method === "GET")
        return json(response, 200, config);
      if (pathname === "/api/leads" && request.method === "POST") {
        if (!config.captureEnabled)
          throw new RequestError(
            503,
            "Signups are paused. Please try again later.",
          );
        const origin = request.headers.origin;
        const port = server.address().port;
        const localOrigins = [
          `http://127.0.0.1:${port}`,
          `http://localhost:${port}`,
        ];
        if (!origin || (!origins.has(origin) && !localOrigins.includes(origin)))
          throw new RequestError(
            403,
            "Open the signup form on this site and try again.",
          );
        const now = Date.now();
        for (const [key, limit] of limits)
          if (limit.reset <= now) limits.delete(key);
        const address = request.socket.remoteAddress;
        const limit = limits.get(address) ?? { count: 0, reset: now + 60000 };
        if (limits.size >= 10000 && !limits.has(address))
          throw new RequestError(
            429,
            "Too many attempts. Try again in a minute.",
          );
        limit.count += 1;
        limits.set(address, limit);
        if (limit.count > rateLimit) {
          response.setHeader(
            "Retry-After",
            String(Math.ceil((limit.reset - now) / 1000)),
          );
          throw new RequestError(
            429,
            "Too many attempts. Try again in a minute.",
          );
        }
        const lead = parseLead(await readJson(request));
        let saved;
        try {
          saved = await store.upsert(lead);
        } catch {
          throw new RequestError(
            503,
            "Your details could not be saved. Please try again later.",
          );
        }
        return json(response, saved.created ? 201 : 200, {
          ok: true,
          id: saved.id,
          delivery: "stored",
        });
      }
      if (pathname.startsWith("/api/"))
        throw new RequestError(404, "Not found.");
      if (!["GET", "HEAD"].includes(request.method))
        throw new RequestError(405, "Method not allowed.");
      let decoded;
      try {
        decoded = decodeURIComponent(pathname);
      } catch {
        throw new RequestError(400, "Invalid path.");
      }
      if (
        decoded.split("/").some((part) => part.startsWith(".")) ||
        decoded.includes("\\")
      )
        throw new RequestError(404, "Not found.");
      const file = path.resolve(
        distDirectory,
        `.${decoded === "/" ? "/index.html" : decoded}`,
      );
      if (!isWithin(distDirectory, file))
        throw new RequestError(404, "Not found.");
      let actual;
      try {
        actual = await realpath(file);
      } catch {
        throw new RequestError(404, "Not found.");
      }
      const actualDist = await realpath(distDirectory);
      if (!isWithin(actualDist, actual) || isWithin(dataDirectory, actual))
        throw new RequestError(404, "Not found.");
      if (!(await stat(actual)).isFile())
        throw new RequestError(404, "Not found.");
      const body = await readFile(actual);
      response.writeHead(200, {
        "Content-Type":
          mimeTypes[path.extname(file)] ?? "application/octet-stream",
        "X-Content-Type-Options": "nosniff",
        "Cache-Control": "no-cache",
        "Content-Length": body.length,
      });
      response.end(request.method === "HEAD" ? undefined : body);
    } catch (error) {
      if (!response.headersSent && !response.destroyed)
        json(response, error instanceof RequestError ? error.status : 500, {
          ok: false,
          error:
            error instanceof RequestError
              ? error.message
              : "Something went wrong. Please try again.",
        });
      else response.destroy();
    }
  });
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  return {
    server,
    async close() {
      if (server.listening)
        await new Promise((resolve, reject) =>
          server.close((error) => (error ? reject(error) : resolve())),
        );
      await store?.close();
    },
  };
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  const port = Number(process.env.PORT ?? 8787);
  if (!Number.isInteger(port) || port < 1 || port > 65535)
    throw new Error("PORT must be between 1 and 65535.");
  const app = await createLeadServer();
  app.server.on("error", async () => {
    await app.close();
    process.exitCode = 1;
  });
  app.server.listen(port, process.env.HOST ?? "127.0.0.1", () => {
    console.log(
      `Scrapkeep server listening on port ${port}. Lead capture stores locally; no messages are sent.`,
    );
  });
  for (const signal of ["SIGINT", "SIGTERM"])
    process.once(signal, async () => {
      await app.close();
    });
}
