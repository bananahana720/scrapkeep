export const TOTAL_WAVES = 15;
export const HEROES = {
  scavenger: {
    name: "Pip",
    title: "The scavenger",
    story: "If it rattles, Pip can probably make it shoot.",
    blueprint: "Sunburst repeater",
  },
  engineer: {
    name: "Rivet",
    title: "The engineer",
    story: "One more wire. One less problem.",
    blueprint: "Copperwork mortar",
  },
  warden: {
    name: "Moss",
    title: "The warden",
    story: "The little garden behind the core is worth protecting.",
    blueprint: "Garden arc coil",
  },
};
export const SECTORS = [
  {
    id: "rust",
    index: 1,
    name: "Rustwater Yard",
    boss: "The Cancrusher",
    text: "A scrap heap with a pulse.",
  },
  {
    id: "glass",
    index: 2,
    name: "Glasswind Flats",
    boss: "Glassjaw",
    text: "Fast feet in a storm of broken glass.",
  },
  {
    id: "heart",
    index: 3,
    name: "The Iron Orchard",
    boss: "Old Ironroot",
    text: "Bring the last seed home.",
  },
];
export const MODIFIERS = [
  {
    id: "march",
    name: "Scrap march",
    text: "A steady march. Keep rolling and gather scrap.",
    hp: 1,
    speed: 1,
  },
  {
    id: "rush",
    name: "Rust rush",
    text: "Enemies move 12% faster.",
    hp: 1,
    speed: 1.12,
  },
  {
    id: "armor",
    name: "Iron shells",
    text: "Enemies have 18% more health.",
    hp: 1.18,
    speed: 1,
  },
  {
    id: "swarm",
    name: "Yard swarm",
    text: "Six extra raiders join the wave.",
    hp: 0.9,
    speed: 1,
    extra: 6,
  },
  {
    id: "boss",
    name: "Heavy weather",
    text: "A named heavy leads the assault.",
    hp: 1,
    speed: 1,
  },
];
export function sectorFor(wave) {
  return SECTORS[Math.min(2, Math.max(0, Math.floor((wave - 1) / 5)))];
}
export function modifierFor(wave) {
  return MODIFIERS[Math.max(0, wave - 1) % 5];
}
const badges = [
  { xp: 0, name: "New wheels" },
  { xp: 50, name: "Yard regular" },
  { xp: 150, name: "Scrap keeper" },
  { xp: 350, name: "Storm rider" },
  { xp: 700, name: "Orchard legend" },
];
const integer = (n, max = Number.MAX_SAFE_INTEGER) =>
  Number.isSafeInteger(n) && n >= 0 && n <= max;
export function createProfile() {
  return {
    version: 1,
    classes: Object.fromEntries(
      Object.keys(HEROES).map((id) => [
        id,
        { xp: 0, runs: 0, wins: 0, bestScore: 0, bestWave: 0 },
      ]),
    ),
    settled: [],
    blueprints: [],
  };
}
export function parseProfile(raw) {
  const result = createProfile();
  try {
    const data = typeof raw === "string" ? JSON.parse(raw) : raw;
    if (!data || data.version !== 1 || typeof data.classes !== "object")
      return result;
    for (const id of Object.keys(HEROES)) {
      for (const key of Object.keys(result.classes[id])) {
        const value = data.classes?.[id]?.[key];
        if (
          integer(
            value,
            key === "bestWave" ? TOTAL_WAVES : Number.MAX_SAFE_INTEGER,
          )
        )
          result.classes[id][key] = value;
      }
    }
    result.settled = [
      ...new Set(
        Array.isArray(data.settled)
          ? data.settled.filter(
              (id) =>
                typeof id === "string" && /^[a-zA-Z0-9_-]{1,100}$/.test(id),
            )
          : [],
      ),
    ];
    result.blueprints = Object.keys(HEROES)
      .filter((id) => result.classes[id].xp >= 150)
      .map((id) => HEROES[id].blueprint);
  } catch {
    return result;
  }
  return result;
}
export function serializeProfile(profile) {
  return JSON.stringify(parseProfile(profile));
}
export function masteryFor(profile, classId) {
  const stats =
    parseProfile(profile).classes[classId] || createProfile().classes.scavenger;
  const level = badges.findLastIndex((badge) => stats.xp >= badge.xp);
  const next = badges[level + 1];
  return {
    ...stats,
    level,
    badge: badges[level].name,
    nextXp: next?.xp ?? null,
    progress: next
      ? (stats.xp - badges[level].xp) / (next.xp - badges[level].xp)
      : 1,
    blueprint: stats.xp >= 150 ? HEROES[classId]?.blueprint : null,
  };
}
export function settleRun(profile, run) {
  const next = parseProfile(profile);
  const valid =
    run &&
    typeof run.id === "string" &&
    /^[a-zA-Z0-9_-]{1,100}$/.test(run.id) &&
    Object.hasOwn(HEROES, run.classId) &&
    integer(run.seed, 0xffffffff) &&
    integer(run.score, 1000000000) &&
    integer(run.survived, TOTAL_WAVES) &&
    ["victory", "gameover", "abandoned"].includes(run.outcome) &&
    (run.outcome !== "victory" || run.survived === TOTAL_WAVES);
  if (!valid || next.settled.includes(run.id))
    return {
      profile: next,
      awarded: 0,
      mastery: valid ? masteryFor(next, run.classId) : null,
      unlocks: [],
    };
  const stats = next.classes[run.classId];
  const awarded = run.survived * 10 + (run.outcome === "victory" ? 50 : 0);
  stats.xp += awarded;
  stats.runs++;
  stats.wins += Number(run.outcome === "victory");
  stats.bestScore = Math.max(stats.bestScore, run.score);
  stats.bestWave = Math.max(stats.bestWave, run.survived);
  next.settled.push(run.id);
  const unlocks = [];
  const blueprint = HEROES[run.classId].blueprint;
  if (stats.xp >= 150 && !next.blueprints.includes(blueprint)) {
    next.blueprints.push(blueprint);
    unlocks.push(blueprint);
  }
  return {
    profile: next,
    awarded,
    mastery: masteryFor(next, run.classId),
    unlocks,
  };
}
export function dailySeed(date = new Date()) {
  const text =
    typeof date === "string"
      ? date.slice(0, 10)
      : date.toISOString().slice(0, 10);
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(text) ||
    !Number.isFinite(Date.parse(`${text}T00:00:00Z`)) ||
    new Date(`${text}T00:00:00Z`).toISOString().slice(0, 10) !== text
  )
    throw new TypeError("Use an ISO date for the daily expedition.");
  let seed = 2166136261;
  for (const char of `scrapkeep-v1-${text}`)
    seed = Math.imul(seed ^ char.charCodeAt(0), 16777619) >>> 0;
  return seed;
}
export function encodeChallenge(challenge) {
  if (
    !challenge ||
    !integer(challenge.seed, 0xffffffff) ||
    !Object.hasOwn(HEROES, challenge.classId) ||
    !integer(challenge.targetScore, 1000000000)
  )
    throw new TypeError("Invalid expedition challenge.");
  return `1.${challenge.seed}.${challenge.classId}.${challenge.targetScore}`;
}
export function decodeChallenge(raw) {
  if (typeof raw !== "string" || raw.length > 100) return null;
  const match = /^1\.(\d{1,10})\.(scavenger|engineer|warden)\.(\d{1,10})$/.exec(
    raw,
  );
  if (!match) return null;
  const value = {
    seed: Number(match[1]),
    classId: match[2],
    targetScore: Number(match[3]),
  };
  try {
    encodeChallenge(value);
    return value;
  } catch {
    return null;
  }
}
export function challengeUrl(base, challenge) {
  const url = new URL(base);
  url.hash = new URLSearchParams({
    challenge: encodeChallenge(challenge),
  }).toString();
  return url.href;
}
