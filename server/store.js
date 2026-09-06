import { randomUUID } from "node:crypto";
import { mkdir, open, readFile, rename, unlink } from "node:fs/promises";
import path from "node:path";
import { CONSENT_VERSION } from "./validation.js";

export async function openLeadStore(directory, copy) {
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const filename = path.join(directory, "leads.json");
  const lockPath = path.join(directory, "leads.lock");
  let lock;
  try {
    lock = await open(lockPath, "wx", 0o600);
  } catch (error) {
    if (error.code === "EEXIST")
      throw new Error(
        "Lead storage is locked. Stop the other server or follow the recovery instructions.",
      );
    throw error;
  }
  let state = { version: 1, leads: [] };
  try {
    await lock.writeFile(String(process.pid));
    await lock.sync();
    try {
      state = JSON.parse(await readFile(filename, "utf8"));
      if (state.version !== 1 || !Array.isArray(state.leads))
        throw new Error("Invalid lead storage format.");
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  } catch (error) {
    await lock.close();
    await unlink(lockPath);
    throw error;
  }
  let queue = Promise.resolve();
  let closed = false;

  async function save(lead) {
    const now = new Date().toISOString();
    const matches = state.leads.filter(
      (entry) =>
        (lead.email &&
          entry.contacts.email.some(
            (contact) => contact.value === lead.email,
          )) ||
        (lead.phone &&
          entry.contacts.sms.some((contact) => contact.value === lead.phone)),
    );
    const merged = {
      id: matches[0]?.id ?? randomUUID(),
      createdAt: matches.map((entry) => entry.createdAt).sort()[0] ?? now,
      updatedAt: now,
      contacts: { email: [], sms: [] },
      interests: [],
      sources: [],
      latestRun: lead.run,
      delivery: "stored",
    };
    for (const entry of matches) {
      for (const channel of ["email", "sms"]) {
        for (const contact of entry.contacts[channel]) {
          if (
            !merged.contacts[channel].some(
              (item) => item.value === contact.value,
            )
          ) {
            merged.contacts[channel].push(contact);
          }
        }
      }
      merged.interests.push(...entry.interests);
      merged.sources.push(...entry.sources);
    }
    for (const [channel, value] of [
      ["email", lead.email],
      ["sms", lead.phone],
    ]) {
      if (
        value &&
        !merged.contacts[channel].some((item) => item.value === value)
      ) {
        merged.contacts[channel].push({
          value,
          consent: {
            granted: true,
            at: now,
            version: CONSENT_VERSION,
            text: copy[channel],
          },
        });
      }
    }
    merged.interests = [...new Set([...merged.interests, lead.heroClass])];
    merged.sources = [...new Set([...merged.sources, lead.source])];
    const next = {
      version: 1,
      leads: [
        ...state.leads.filter((entry) => !matches.includes(entry)),
        merged,
      ],
    };
    const temporary = path.join(directory, `leads-${randomUUID()}.tmp`);
    let handle;
    try {
      handle = await open(temporary, "wx", 0o600);
      await handle.writeFile(JSON.stringify(next) + "\n");
      await handle.sync();
      await handle.close();
      handle = undefined;
      await rename(temporary, filename);
      state = next;
      const directoryHandle = await open(directory, "r");
      try {
        await directoryHandle.sync();
      } finally {
        await directoryHandle.close();
      }
    } finally {
      if (handle) await handle.close();
      await unlink(temporary).catch((error) => {
        if (error.code !== "ENOENT") throw error;
      });
    }
    return { id: merged.id, created: matches.length === 0 };
  }

  return {
    upsert(lead) {
      if (closed) return Promise.reject(new Error("Lead storage is closed."));
      const result = queue.then(() => save(lead));
      queue = result.catch(() => {});
      return result;
    },
    async close() {
      if (closed) return;
      closed = true;
      await queue;
      await lock.close();
      await unlink(lockPath);
    },
  };
}
