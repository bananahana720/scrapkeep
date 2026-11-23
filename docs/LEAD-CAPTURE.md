# Lead capture reference

> **Frozen legacy reference, 6 September 2026.** The lead-capture server is preserved evidence, not a live verification dependency. `npm run verify` and `npm test` no longer exercise it; run `npm run test:leads` and `npm run test:leads:browser` explicitly. See ADR 0001, amendment 2026-09-06 (`docs/adr/0001-two-playable-entries.md`, archived in git history).

The Node service stores email and SMS opt-ins on this machine. It sends no email, text message, webhook, or CRM request. `delivery: "stored"` means the server completed a durable local write. It does not mean a message was delivered or that the contact belongs to the person who submitted it.

## Commands

The service uses Node built-ins. The project must use ES modules and Node 22 or later. This implementation was tested with Node 26.8.1 on Linux.

| Command                                | Behavior                                                                                                       |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `node server/index.js`                 | Starts the API and serves existing `dist` files on `127.0.0.1:8787`.                                           |
| `node --env-file=.env server/index.js` | Loads explicitly configured environment values from `.env`. The service does not automatically load that file. |
| `npm run test:leads`                   | Tests HTTP capture using synthetic contacts and temporary directories.                                         |

During development, Vite proxies `/api` to `http://127.0.0.1:8787`. Vite must deny access to `**/.private/**`, `**/leads.json`, `**/leads-*.tmp`, and `**/leads.lock`, in addition to its default deny rules. These rules prevent the development server from exposing local contact records. The Node production server serves only `dist`, rejects hidden paths and static symlink escapes, and never exposes a lead-list endpoint.

The production command requires a prior Vite build. `vite preview` alone does not implement capture. It needs the Node API through the preview proxy.

## Environment

| Variable          | Default                                        | Meaning                                                                                                                                   |
| ----------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `BRAND_NAME`      | `Scrapkeep`                                    | Brand returned by config and used in consent text.                                                                                        |
| `STORE_URL`       | Empty                                          | Optional HTTP or HTTPS shop link.                                                                                                         |
| `PRIVACY_URL`     | Empty                                          | Optional HTTP or HTTPS privacy notice link.                                                                                               |
| `CAPTURE_ENABLED` | `true`                                         | Set exactly `false` to pause signups.                                                                                                     |
| `HOST`            | `127.0.0.1`                                    | Listening address.                                                                                                                        |
| `PORT`            | `8787`                                         | Listening port.                                                                                                                           |
| `APP_ORIGIN`      | Localhost and 127.0.0.1 on ports 5173 and 4173 | Comma-separated allowed browser origins. Also accepts the API's own localhost origin.                                                     |
| `LEADS_DATA_DIR`  | Project `.private/leads`                       | Private directory containing records and the single-process lock. A relative configured path resolves from the process working directory. |

Store and privacy links remain absent until configured. There are no fake checkout links or provider credentials. In a hosted setup, an HTTPS reverse proxy must forward `/api` to this service and `APP_ORIGIN` must contain the public site's origin. Proxy forwarding headers do not affect the in-memory IP limit. Requests arriving through one proxy share that limit, so a public deployment requires an intentional proxy and abuse-control configuration.

## API

`GET /api/config` returns `brand`, nullable `storeUrl`, nullable `privacyUrl`, `captureEnabled`, `localOnly: true`, `consentVersion`, and `consentText` containing `email` and `sms`. The form must display those authoritative consent strings next to separate unchecked opt-ins. Local-mode confirmation must say that details were saved locally and no messages were sent.

`POST /api/leads` requires `Content-Type: application/json` and an allowed `Origin`. Request fields are:

```json
{
  "email": "synthetic@example.test",
  "phone": "+14155550123",
  "consent": { "email": true, "sms": true },
  "heroClass": "engineer",
  "source": "run-result",
  "run": { "seed": 42, "score": 120, "wave": 3, "outcome": "gameover" },
  "website": ""
}
```

At least one contact must be supplied. Omit unused contact fields rather than sending empty strings. Every supplied contact requires its matching consent flag to be true. The other flag must be false. Phone numbers use E.164-style notation with a leading `+` and 8 to 15 digits. Email is trimmed and lowercased. This syntax check does not verify ownership or deliverability.

`heroClass` accepts `scavenger`, `engineer`, or `warden`. `source` accepts `collection` or `run-result`. Run values must be integers. Seed is 0 through 4294967295, score is 0 through 1000000000000, and wave is 0 through 1000000. Outcome accepts `victory`, `defeat`, `gameover`, `abandoned`, or `in-progress`. `website` is the honeypot and must be an empty string. Unknown fields are rejected.

Successful new records return HTTP 201. Submissions matching an existing email or phone return HTTP 200. Both return only `{"ok":true,"id":"…","delivery":"stored"}`. Errors return `{"ok":false,"error":"safe text"}`. Validation errors use 400, origin failures use 403, oversized bodies use 413, unsupported content types use 415, and rate limits use 429 with `Retry-After`. Disabled capture and storage failures use 503. The request limit is 20 attempts per remote IP per minute. Bodies are limited to 8192 bytes.

## Local records

`leads.json` contains versioned JSON with a `leads` array. Each lead stores an ID, creation and update timestamps, contact arrays for email and SMS, deduplicated figurine interests and submission sources, the latest run, and `delivery: "stored"`. Each contact has its own granted-consent timestamp, exact text, and version `2026-09-05-v1`. Repeat submissions preserve the original contact consent evidence. Adding a channel records new evidence for that channel. Run metadata is visitor-supplied and is not trusted as a verified score.

Matching contacts merge into one record. A submission connecting existing email and phone records preserves their contacts and interests. A false checkbox does not withdraw a past opt-in. This endpoint only accepts new affirmative opt-ins. No unsubscribe or ownership verification service is implemented.

The store serializes updates in one process. Each update writes a complete temporary snapshot with mode `0600`, flushes it, atomically renames it, and flushes the directory before reporting success. Newly created data directories use `0700`. Existing directory permissions are retained. These permissions do not encrypt the data. Backups and copies require the same access restrictions.

`leads.lock` prevents multiple server processes from writing the same directory. Normal shutdown removes it. An unclean process exit leaves the lock and may leave an unused `leads-*.tmp` file. After verifying that the recorded PID is no longer running this service, the operator can remove the stale lock and restart. Startup reads only `leads.json`; it ignores temporary snapshots. A corrupt committed file stops startup without overwriting that file. Whole-file snapshots are intended for a small local collection, not a multi-process campaign service.

## Unconfigured messaging

No messaging-provider or CRM integration is configured. A later integration needs verified account credentials, an approved sender, contact ownership and unsubscribe handling, a published privacy notice, and provider-specific consent review. Existing local opt-ins require review before any export or campaign. None of those services are simulated by this backend.

The implementation uses the documented Node [file system promises](https://nodejs.org/api/fs.html#promises-api) and [HTTP server API](https://nodejs.org/api/http.html#class-httpserver).
