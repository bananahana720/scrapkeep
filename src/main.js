import "@fontsource/barlow-condensed/latin-700.css";
import "@fontsource/barlow-condensed/latin-800.css";
import "@fontsource/dm-sans/latin-400.css";
import "@fontsource/dm-sans/latin-500.css";
import "@fontsource/dm-sans/latin-700.css";
import "@fontsource/ibm-plex-mono/latin-400.css";
import "./style.css";
import "./collection.css";
import { Game, CLASSES, WEAPONS, pointOnPath } from "./game.js";
import { World } from "./world.js";
import { AudioEngine } from "./audio.js";
import { Collection } from "./collection.js";
import { HEROES, sectorFor, modifierFor, decodeChallenge } from "./campaign.js";
import { heroPortrait } from "./heroes.js";
const icons = {
  magnet:
    '<path d="M5 4v8a7 7 0 0 0 14 0V4h-4v8a3 3 0 0 1-6 0V4z"/><path d="M5 8h4m6 0h4"/>',
  gear: '<path d="m9 3-1 3-3 1-2 4 2 2v4l4 2 3-1 3 1 4-2v-4l2-2-2-4-3-1-1-3z"/><circle cx="12" cy="11" r="3"/>',
  spark: '<path d="m13 2-9 12h7l-1 8 10-13h-7z"/>',
  arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>',
  pause: '<path d="M8 5v14M16 5v14"/>',
  play: '<path d="m8 4 12 8-12 8z"/>',
  reset: '<path d="M4 9a8 8 0 1 1 0 6M4 3v6h6"/>',
  sound:
    '<path d="m11 4-6 5H2v6h3l6 5zM15 8a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14"/>',
  muted: '<path d="m11 4-6 5H2v6h3l6 5zM16 9l6 6m0-6-6 6"/>',
  crosshair:
    '<circle cx="12" cy="12" r="7"/><path d="M12 1v7m0 8v7M1 12h7m8 0h7"/>',
  scope: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/>',
  heart:
    '<path d="M12 20S2 14 2 8a5 5 0 0 1 10-1 5 5 0 0 1 10 1c0 6-10 12-10 12z"/>',
  close: '<path d="m5 5 14 14M5 19 19 5"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9 9a3 3 0 1 1 4 3v2m-1 3h.01"/>',
  bolt: '<path d="M8 3h8v5l3 3v8H5v-8l3-3zM8 14h8m-4-7v4"/>',
  pipe: '<path d="M5 20V9a5 5 0 0 1 5-5h8v6h-6v10zM3 16h11M16 2v10"/>',
  coil: '<path d="M12 3v18M6 7h12M5 12h14M6 17h12"/>',
  cactus: '<path d="M10 21V5a2 2 0 0 1 4 0v16M5 8v5h5m9-6v6h-5M7 21h10"/>',
};
const icon = (name, cls = "") =>
  `<svg class="icon ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.spark}</svg>`;
const $ = (id) => document.getElementById(id);
const format = (n) => Math.floor(n).toLocaleString("en-US");
const bestKey = new URLSearchParams(location.search).has("qa")
  ? "scrapkeep.qa.best"
  : "scrapkeep.best";
let best = 0;
try {
  best = Number(localStorage.getItem(bestKey)) || 0;
} catch {}
let selected = "scavenger",
  helpOpen = false,
  helpWasPlaying = false,
  lastMode = "",
  lastClass = "",
  toastTimer = 0,
  hudTime = 0,
  labelsTime = 0,
  frameSamples = [],
  renderSamples = [],
  fps = 60,
  tipTimer = 14;
const game = new Game(),
  audio = new AudioEngine();
let world;
function preview() {
  game.player.radius = 1.23;
  game.collected = 17;
  game.pickups = game.pickups.filter(
    (p) => Math.hypot(p.x - game.player.x, p.z - game.player.z) > 2.1,
  );
  for (let i = 0; i < 15; i++) game.addWeapon(Object.keys(WEAPONS)[i % 4]);
  for (const travel of [5, 7, 9.5, 29, 31.5, 34, 48, 50]) {
    const enemy = game.spawnEnemy("bug");
    Object.assign(enemy, pointOnPath(travel), { travel });
  }
}
preview();
try {
  world = new World($("world"));
} catch (e) {
  $("app").innerHTML =
    '<div class="fatal"><h1>THE YARD COULDN’T START.</h1><p>Reload to try again. If this keeps happening, check that your browser supports WebGL 2.</p><button onclick="location.reload()">Reload</button></div>';
  throw e;
}
$("app").innerHTML = `
<header class="topbar"><a class="wordmark" href="#" id="home" aria-label="Scrapkeep title screen"><span class="brand-symbol">${icon("spark")}</span>SCRAPKEEP</a><div class="wave-hud hidden" id="wave-hud"><span class="live-dot"></span><span id="wave-label">GET ROLLING</span><span class="wave-separator"></span><span id="enemy-count">COLLECT SCRAP</span></div><div class="top-actions"><span class="map-name">DUST YARD <span>/ 01</span></span><button id="quality" class="quality-button" aria-label="Toggle visual effects">FX ON</button><button id="sound" class="icon-button" aria-label="Mute sound" title="Mute sound (M)">${icon("sound")}</button><button id="help" class="icon-button" aria-label="How to play" title="How to play">${icon("help")}</button><button id="pause" class="icon-button hidden" aria-label="Pause game" title="Pause (Esc)">${icon("pause")}</button></div></header>
<div id="menu" class="start-screen"><section class="start-content"><div class="eyebrow"><span class="tiny-square"></span> A LITTLE HERO. A LONG WAY HOME.</div><h1>SCRAP<br><span>KEEP.</span></h1><p class="tagline">Small heroes. Serious scrap.</p><p class="intro">Roll up the yard. Turn junk into turrets.<br>Keep your core in one piece.</p><div id="expedition-brief" class="expedition-brief"></div><div class="class-heading"><span>PICK YOUR LITTLE HERO</span><span>01 — 03</span></div><div id="class-options" class="class-options"></div><button class="primary-button" id="start">START EXPEDITION <span>${icon("arrow")}</span></button><a class="orchard-entry" href="/orchard.html">PLAY THE IRON ORCHARD <span>NEW THIRD-PERSON STUDY ↗</span></a><button class="daily-button" id="daily-start">TODAY’S SHARED YARD <span>↗</span></button><div class="start-meta"><span><kbd>W A S D</kbd> TO MOVE</span><span>AUTO-FIRING TURRETS</span></div></section><aside id="hero-shelf" class="hero-shelf"></aside><div class="menu-footer"><span>ROLL. COLLECT. DEFEND.</span><span id="menu-best">PERSONAL BEST &nbsp; ${format(best)}</span><span>NO SIGNUP NEEDED TO PLAY.</span></div></div>
<div id="hud" class="hidden"><aside class="mission-panel"><span id="sector-label" class="eyebrow"></span><strong id="mission-title"></strong><p id="mission-text"></p><div class="expedition-track" id="expedition-track"></div><span id="mission-bonus"></span></aside><div class="boss-hud hidden" id="boss-hud"><span id="boss-name"></span><div><i id="boss-health"></i></div></div><section class="core-card"><div class="micro-label">${icon("heart")} CORE INTEGRITY <span id="core-value">100 / 100</span></div><div class="health-track"><div id="core-fill"></div></div><div class="core-sub"><span id="core-state">KEEP THE LIGHT ON</span><span id="fps">60 FPS</span></div></section><div id="world-labels"><div class="world-label entry-label" id="entry-label"><span>↓</span> INCOMING</div><div class="world-label entry-label" id="flank-label"><span>↓</span> FLANK GATE · WAVE 3</div><div class="world-label base-label" id="base-label"><span class="live-dot"></span> YOUR CORE</div><div class="player-label" id="player-label">YOU <span>▾</span></div></div><div class="arsenal-panel"><div class="arsenal-title"><span class="micro-label">YOUR ROLLING ARSENAL</span><b id="turret-count">02</b></div><div class="weapon-counts" id="weapon-counts"></div><div class="level-row"><span id="class-level">SCAVENGER · LV. 1</span><span id="xp-label">0 / 65 XP</span></div><div class="xp-track"><div id="xp-fill"></div></div></div><div class="momentum-dock"><span id="momentum-text">ROLL TO CHARGE TURRETS</span><div><i id="momentum-fill"></i></div></div><div class="ability-dock"><button id="dash" class="ability-button"><kbd>SPACE</kbd><div><strong>Dash</strong><span id="dash-state">READY</span></div><span id="dash-fill" class="cooldown-fill"></span></button><span class="dock-divider"></span><button id="ability" class="ability-button special"><kbd>E</kbd><div><strong id="ability-name">Scrap surge</strong><span id="ability-state">READY</span></div><span id="ability-fill" class="cooldown-fill"></span></button></div><div class="score-panel"><div class="micro-label">SALVAGE SCORE</div><strong id="score">000000</strong><div><span id="survived">0 WAVES SURVIVED</span><span id="best-label">BEST ${format(best)}</span></div></div><div id="tip" class="game-tip">${icon("magnet")} COLLECT SCRAP. KEEP ROLLING TO CHARGE TURRETS.<span><kbd>WASD</kbd> move &nbsp; <kbd>SPACE</kbd> dash &nbsp; <kbd>E</kbd> ability</span></div><div class="mobile-controls"><div id="joystick"><span></span></div></div></div>
<div id="toast" class="toast"><span id="toast-small"></span><strong id="toast-title"></strong></div><div id="floaters"></div>
<div id="modal" class="modal hidden" role="dialog" aria-modal="true"><div id="modal-content"></div></div>`;
const collection = new Collection(game, { pause, redraw: () => drawClasses() });
selected = collection.initialClass();
game.reset(selected, false);
preview();
world.clearDynamic();
function drawClasses() {
  $("class-options").innerHTML = Object.entries(CLASSES)
    .map(
      ([id, c], i) =>
        `<button class="class-card ${selected === id ? "selected" : ""}" data-class="${id}" ${collection.challenge && id !== collection.challenge.classId ? "disabled" : ""} aria-pressed="${selected === id}"><span class="class-portrait">${heroPortrait(id)}</span><span class="class-copy"><strong>${HEROES[id].name} <small>${c.name}</small></strong><span>${c.passive}</span><span class="class-mastery">${collection.classLabel(id)}</span></span><span class="class-radio">${selected === id ? "●" : String(i + 1).padStart(2, "0")}</span></button>`,
    )
    .join("");
  document.querySelectorAll("[data-class]").forEach(
    (b) =>
      (b.onclick = () => {
        if (
          collection.challenge &&
          b.dataset.class !== collection.challenge.classId
        )
          return;
        selected = b.dataset.class;
        game.reset(selected, false);
        preview();
        world.clearDynamic();
        drawClasses();
        audio.note(330, 0.06, "sine", 0.1);
      }),
  );
  collection.bindMenu(selected);
}
drawClasses();
function start() {
  saveBest();
  audio.init();
  helpOpen = false;
  collection.begin(selected);
  selected = game.classId;
  world.clearDynamic();
  keys.clear();
  pointer.active = false;
  tipTimer = 14;
  world.shake = 0;
  syncMode();
  $("world").focus();
  showToast("A LITTLE SCRAP. A LOT OF TROUBLE.", "GET ROLLING", 2.5);
}
function saveBest() {
  if (game.score > best) {
    best = game.score;
    try {
      localStorage.setItem(bestKey, String(best));
    } catch {}
  }
}
function showToast(small, title, time = 2.2) {
  $("toast-small").textContent = small;
  $("toast-title").textContent = title;
  $("toast").classList.add("visible");
  toastTimer = time;
}
function pause() {
  if (helpOpen) return;
  game.pause();
  keys.clear();
  pointer.active = false;
  syncMode();
}
function goHome() {
  saveBest();
  toastTimer = 0;
  $("toast").classList.remove("visible");
  helpOpen = false;
  collection.finish("abandoned");
  game.reset(selected, false);
  preview();
  world.clearDynamic();
  keys.clear();
  syncMode();
  drawClasses();
  $("menu-best").textContent = `PERSONAL BEST   ${format(best)}`;
}
function help() {
  if (helpOpen) {
    helpOpen = false;
    if (helpWasPlaying && game.mode === "paused") game.pause();
    lastMode = "";
    syncMode();
    return;
  }
  helpOpen = true;
  helpWasPlaying = game.mode === "playing";
  if (helpWasPlaying) game.pause();
  keys.clear();
  $("modal").classList.remove("hidden");
  $("modal-content").innerHTML =
    `<section class="dialog help-dialog"><span class="eyebrow">FIELD MANUAL / 01</span><h2>YOU ARE THE TOWER.</h2><p>Enemies follow the orange-edged road to your core. Roll into loose machinery and plants to attach outward-facing turrets. They fire automatically at nearby enemies. Keep rolling to charge them for full fire rate; stopping slows their reload.</p><div class="manual-grid"><div><kbd>WASD / ↑←↓→</kbd><strong>Roll around</strong><span>Screen-relative movement. Or hold the mouse where you want to go.</span></div><div><kbd>SPACE</kbd><strong>Dash & smash</strong><span>Burst through enemies for extra impact damage. Recharges in 2 seconds.</span></div><div><kbd>E</kbd><strong>Class ability</strong><span>${CLASSES[selected].ability}: ${CLASSES[selected].abilityText}</span></div><div><kbd>ESC / P</kbd><strong>Take a breath</strong><span>Pause any time. R instantly restarts. M toggles sound.</span></div></div><p class="manual-note">Clear waves to earn most of your score and choose an upgrade. Kills grant XP and damage for this run. Class mastery stays with you across runs. Fresh scrap appears throughout the run. From wave 3, a flank gate opens on the lower lane. Named bosses guard waves 5, 10 and 15. Clear all 15 to save the orchard. Between waves, take an optional hazard for +50% wave points against enemies with +80% health and +25% speed. Class field cards unlock at 150 mastery. All play and progression are free.</p><button id="close-help" class="primary-button">GOT IT ${icon("arrow")}</button></section>`;
  $("close-help").onclick = help;
  $("close-help").focus();
}
function syncMode() {
  if (helpOpen) return;
  const mode = game.mode;
  if (mode === lastMode && selected === lastClass) return;
  lastMode = mode;
  lastClass = selected;
  const menu = mode === "menu";
  $("menu").classList.toggle("hidden", !menu);
  $("hud").classList.toggle("hidden", menu);
  $("wave-hud").classList.toggle("hidden", menu);
  $("pause").classList.toggle("hidden", menu);
  $("modal").classList.toggle(
    "hidden",
    !["paused", "upgrade", "gameover", "victory"].includes(mode),
  );
  document.body.dataset.mode = mode;
  queueMicrotask(() => {
    if (["paused", "upgrade", "gameover", "victory"].includes(mode))
      $("modal-content").querySelector("button")?.focus();
  });
  if (mode === "paused") {
    $("modal-content").innerHTML =
      `<section class="dialog compact"><span class="eyebrow">THE YARD CAN WAIT</span><h2>TAKE A BREATHER.</h2><p>Wave ${game.wave || 1} · ${format(game.score)} points<br>Your core is right where you left it.</p><button class="primary-button" id="resume">KEEP ROLLING ${icon("play")}</button><button class="secondary-button" id="restart">${icon("reset")} RESTART RUN <kbd>R</kbd></button><button class="text-button" id="menu-button">BACK TO CLASS SELECT</button></section>`;
    $("resume").onclick = pause;
    $("restart").onclick = start;
    $("menu-button").onclick = goHome;
  }
  if (mode === "upgrade") {
    saveBest();
    $("modal-content").innerHTML =
      `<section class="dialog upgrade-dialog"><span class="eyebrow">WAVE ${String(game.survived).padStart(2, "0")} SURVIVED · +${format(game.waveBonus?.total || 1000 + game.wave * 100)} POINTS</span><h2>JUNK. WITH POTENTIAL.</h2><p>Next: ${sectorFor(game.wave + 1).name} · ${modifierFor(game.wave + 1).text}</p><label class="risk-choice"><input type="checkbox" id="risk-choice" ${game.risk ? "checked" : ""}><span><strong>TAKE THE HAZARDOUS ROUTE</strong><small>+50% wave-clear points. Enemies gain +80% health and +25% speed. Your call.</small></span></label><div class="upgrade-options">${game.options.map((u, i) => `<button class="upgrade-card" data-upgrade="${i}"><span class="upgrade-number">0${i + 1} <kbd>${i + 1}</kbd></span>${icon(u.icon)}<span class="upgrade-stat">${u.stat}</span><strong>${u.title}</strong><span class="upgrade-copy">${u.text}</span><span class="upgrade-select">TAKE IT ${icon("arrow")}</span></button>`).join("")}</div><div class="upgrade-footer"><span>CORE PATCHED +8</span><span>FRESH SCRAP HAS ARRIVED</span></div></section>`;
    $("risk-choice").onchange = (e) => game.setRisk(e.target.checked);
    document
      .querySelectorAll("[data-upgrade]")
      .forEach((b) => (b.onclick = () => choose(Number(b.dataset.upgrade))));
  }
  if (["gameover", "victory"].includes(mode)) {
    saveBest();
    collection.finish(mode);
    $("modal-content").innerHTML = collection.resultMarkup();
    $("restart").onclick = start;
    $("menu-button").onclick = goHome;
    collection.bindResult();
  }
}
function choose(i) {
  if (game.chooseUpgrade(i)) {
    keys.clear();
    pointer.active = false;
    syncMode();
    $("world").focus();
  }
}
window.addEventListener("hashchange", () => {
  collection.challenge = decodeChallenge(
    new URLSearchParams(location.hash.slice(1)).get("challenge"),
  );
  collection.daily = false;
  if (collection.challenge) {
    selected = collection.challenge.classId;
    if (collection.open) collection.dialog.close();
    goHome();
  } else if (game.mode === "menu") drawClasses();
});
$("start").onclick = () => {
  collection.daily = false;
  start();
};
$("daily-start").onclick = () => {
  collection.challenge = null;
  history.replaceState(null, "", location.pathname + location.search);
  collection.daily = true;
  start();
};
$("pause").onclick = pause;
$("sound").onclick = () => {
  audio.init();
  const muted = audio.toggle();
  $("sound").innerHTML = icon(muted ? "muted" : "sound");
  $("sound").setAttribute("aria-label", muted ? "Enable sound" : "Mute sound");
};
$("help").onclick = help;
function syncQuality() {
  $("quality").textContent = world.lowQuality ? "FX OFF" : "FX ON";
  $("quality").setAttribute("aria-pressed", String(!world.lowQuality));
}
$("quality").onclick = () => {
  world.setQuality(!world.lowQuality);
  syncQuality();
};
syncQuality();
$("home").onclick = (e) => {
  e.preventDefault();
  if (game.mode === "menu") return;
  if (game.mode === "playing") pause();
  else goHome();
};
$("dash").onclick = () => game.dash();
$("ability").onclick = () => game.ability();
const keys = new Set(),
  pointer = { active: false, id: null, x: 0, y: 0 },
  stick = { active: false, id: null, x: 0, z: 0 };
window.addEventListener("keydown", (e) => {
  if (collection.open) return;
  if (
    e.target instanceof HTMLElement &&
    e.target.matches("input, textarea, select")
  )
    return;
  if (e.code === "Tab" && !$("modal").classList.contains("hidden")) {
    const buttons = [
      ...$("modal").querySelectorAll(
        "button, input, a[href], select, textarea",
      ),
    ];
    if (buttons.length) {
      const first = buttons[0],
        last = buttons.at(-1);
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }
  }
  if (
    ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(
      e.code,
    )
  )
    e.preventDefault();
  if (e.repeat) return;
  if (e.code === "KeyM") {
    $("sound").click();
    return;
  }
  if (e.code === "Escape" || e.code === "KeyP") {
    if (helpOpen) help();
    else pause();
    return;
  }
  if (helpOpen) return;
  if (e.code === "KeyR" && game.mode !== "menu") {
    start();
    return;
  }
  if (
    game.mode === "upgrade" &&
    ["Digit1", "Digit2", "Digit3"].includes(e.code)
  ) {
    choose(Number(e.code.at(-1)) - 1);
    return;
  }
  if (
    game.mode === "menu" &&
    e.code === "Enter" &&
    e.target.tagName !== "BUTTON"
  ) {
    e.preventDefault();
    start();
    return;
  }
  keys.add(e.code);
  if (e.code === "Space") game.dash();
  if (e.code === "KeyE") game.ability();
});
window.addEventListener("keyup", (e) => keys.delete(e.code));
window.addEventListener("blur", () => {
  keys.clear();
  pointer.active = false;
  stick.active = false;
  if (game.mode === "playing") pause();
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden && game.mode === "playing") pause();
});
$("world").addEventListener("pointerdown", (e) => {
  if (e.button !== 0 || game.mode !== "playing") return;
  pointer.active = true;
  pointer.id = e.pointerId;
  pointer.x = e.clientX;
  pointer.y = e.clientY;
  $("world").setPointerCapture(e.pointerId);
});
window.addEventListener("pointermove", (e) => {
  if (e.pointerId === pointer.id) {
    pointer.x = e.clientX;
    pointer.y = e.clientY;
  }
});
function releasePointer(e) {
  if (e.pointerId === pointer.id) {
    pointer.active = false;
    pointer.id = null;
  }
  if (e.pointerId === stick.id) {
    stick.active = false;
    stick.id = null;
    stick.x = stick.z = 0;
    $("joystick").firstElementChild.style.transform = "translate(0,0)";
  }
}
window.addEventListener("pointerup", releasePointer);
window.addEventListener("pointercancel", releasePointer);
$("joystick").addEventListener("pointerdown", (e) => {
  e.preventDefault();
  stick.active = true;
  stick.id = e.pointerId;
  $("joystick").setPointerCapture(e.pointerId);
  moveStick(e);
});
$("joystick").addEventListener("pointermove", (e) => {
  if (stick.active && stick.id === e.pointerId) moveStick(e);
});
function moveStick(e) {
  const r = $("joystick").getBoundingClientRect();
  const x = e.clientX - (r.left + r.width / 2),
    y = e.clientY - (r.top + r.height / 2),
    d = Math.max(36, Math.hypot(x, y));
  stick.x = x / d;
  stick.z = y / d;
  $("joystick").firstElementChild.style.transform =
    `translate(${stick.x * 30}px,${stick.z * 30}px)`;
}
function input() {
  let x =
      Number(keys.has("KeyD") || keys.has("ArrowRight")) -
      Number(keys.has("KeyA") || keys.has("ArrowLeft")),
    z =
      Number(keys.has("KeyS") || keys.has("ArrowDown")) -
      Number(keys.has("KeyW") || keys.has("ArrowUp"));
  if (stick.active) {
    x = stick.x;
    z = stick.z;
  }
  if (pointer.active && !x && !z) {
    const point = world.floorPoint(pointer.x, pointer.y);
    if (point) {
      const dx = point.x - game.player.x,
        dz = point.z - game.player.z,
        d = Math.hypot(dx, dz);
      return d > 0.2
        ? { x: dx / Math.max(1, d), z: dz / Math.max(1, d) }
        : { x: 0, z: 0 };
    }
  }
  return world.screenDirection(x, z);
}
function float(e, text, color) {
  const pt = world.screenPoint(e.x, 1.8, e.z);
  const el = document.createElement("div");
  el.className = "floater";
  el.textContent = text;
  el.style.cssText = `left:${pt.x}px;top:${pt.y}px;color:${color}`;
  $("floaters").appendChild(el);
  setTimeout(() => el.remove(), 950);
}
function handleEvents() {
  for (const e of game.drainEvents()) {
    world.event(e);
    audio.event(e);
    if (e.type === "collect") {
      float(e, `+ ${WEAPONS[e.kind].short}`, WEAPONS[e.kind].color);
      if (e.combo >= 3)
        showToast(`${e.combo} SCRAP CHAIN`, "KEEP IT ROLLING", 0.8);
    }
    if (e.type === "wave")
      showToast(
        e.boss
          ? "HEAVY INBOUND. MAKE ROOM."
          : e.wave === 3
            ? "FLANK GATE OPEN. COVER THE LOWER LANE."
            : "KEEP THEM AWAY FROM THE CORE",
        `WAVE ${String(e.wave).padStart(2, "0")}`,
        2.4,
      );
    if (e.type === "level")
      showToast("+4% ARSENAL DAMAGE", `LEVEL ${e.level}`, 1.8);
    if (e.type === "breach") {
      document.body.classList.remove("breach");
      void document.body.offsetWidth;
      document.body.classList.add("breach");
      showToast(`CORE LOST ${e.damage} INTEGRITY`, "BREACH", 1.3);
    }
    if (["gameover", "victory"].includes(e.type)) {
      saveBest();
      collection.finish(e.type);
    }
  }
}
function hud() {
  const p = game.player;
  $("sector-label").textContent =
    `${game.sector.index} / 3 · ${game.sector.name}`;
  $("mission-title").textContent = game.waveModifier.name;
  $("mission-text").textContent = game.waveModifier.text;
  $("mission-bonus").textContent =
    `${game.risk ? "HAZARD ACTIVE · " : ""}${game.objective?.text || "Gather scrap before the first assault."}`;
  $("expedition-track").innerHTML = Array.from(
    { length: 15 },
    (_, i) =>
      `<i class="${i < game.survived ? "cleared" : i === game.wave - 1 ? "current" : ""} ${i % 5 === 4 ? "boss-mark" : ""}"></i>`,
  ).join("");
  const boss = game.enemies.find((e) => e.type === "boss" && e.hp > 0);
  $("boss-hud").classList.toggle("hidden", !boss);
  if (boss) {
    $("boss-name").textContent = boss.name || "HEAVY INBOUND";
    $("boss-health").style.width = `${(boss.hp / boss.maxHp) * 100}%`;
  }
  $("momentum-fill").style.width = `${p.momentum * 100}%`;
  $("momentum-text").textContent =
    p.momentum > 0.8
      ? "FULL CHARGE · +25% FIRE RATE"
      : "ROLL TO CHARGE TURRETS";
  $("core-value").textContent = `${Math.ceil(game.base)} / ${game.maxBase}`;
  $("core-fill").style.width = `${(game.base / game.maxBase) * 100}%`;
  $("core-fill").classList.toggle("critical", game.base < 30);
  $("core-state").textContent =
    game.base < 30 ? "CORE CRITICAL" : "KEEP THE LIGHT ON";
  $("fps").textContent = `${fps} FPS`;
  $("wave-label").textContent =
    game.waveState === "gather"
      ? `WAVE ${String(game.wave + 1).padStart(2, "0")} IN ${Math.ceil(Math.max(0, game.waveTimer))}s`
      : `WAVE ${String(game.wave).padStart(2, "0")}`;
  $("enemy-count").textContent =
    game.waveState === "gather"
      ? "GATHER SCRAP"
      : `${game.enemies.length + game.spawnLeft} HOSTILES`;
  $("score").textContent = String(game.score).padStart(6, "0");
  $("survived").textContent = `${game.survived} WAVES SURVIVED`;
  $("best-label").textContent = collection.challenge
    ? `TARGET ${format(collection.challenge.targetScore)}`
    : `BEST ${format(Math.max(best, game.score))}`;
  $("turret-count").textContent = String(game.weapons.length).padStart(2, "0");
  $("class-level").textContent =
    `${game.role.name.toUpperCase()} · LV. ${game.level}`;
  $("xp-label").textContent = `${game.xp} / ${game.xpNext} XP`;
  $("xp-fill").style.width = `${(game.xp / game.xpNext) * 100}%`;
  $("ability-name").textContent = game.role.ability;
  $("ability-state").textContent =
    p.overclock > 0
      ? `ACTIVE ${p.overclock.toFixed(1)}s`
      : p.abilityCooldown > 0
        ? `${p.abilityCooldown.toFixed(1)}s`
        : "READY";
  $("dash-state").textContent =
    p.dashCooldown > 0 ? `${p.dashCooldown.toFixed(1)}s` : "READY";
  $("ability-fill").style.width =
    `${(1 - p.abilityCooldown / game.role.cooldown) * 100}%`;
  $("dash-fill").style.width = `${(1 - p.dashCooldown / 2.2) * 100}%`;
  $("ability").classList.toggle("ready", p.abilityCooldown === 0);
  const counts = Object.keys(WEAPONS).map((type) => [
    type,
    game.weapons.filter((w) => w.type === type).length,
  ]);
  const signature = counts.map((p) => p.join(":")).join("|");
  if ($("weapon-counts").dataset.signature !== signature) {
    $("weapon-counts").dataset.signature = signature;
    $("weapon-counts").innerHTML = counts
      .map(
        ([type, n]) =>
          `<div class="weapon-slot ${n ? "" : "empty"}" style="--weapon-color:${WEAPONS[type].color}" title="${WEAPONS[type].name}">${icon(type)}<span>×${n}</span></div>`,
      )
      .join("");
  }
}
function labels() {
  for (const [id, x, y, z] of [
    ["entry-label", -12, 2.5, -7],
    ["flank-label", -11.4, 2.6, 5.5],
    ["base-label", 3, 4.3, 8],
    ["player-label", game.player.x, game.player.radius + 2, game.player.z],
  ]) {
    const pos = world.screenPoint(x, y, z);
    $(id).style.transform =
      `translate(${pos.x}px,${pos.y}px) translate(-50%,-100%)`;
  }
}
let then = performance.now();
let simulationTime = 0;
let fpsTime = 0,
  frames = 0;
const perf = { frames: [], renders: [], renderer: "" };
function frame(now) {
  const raw = (now - then) / 1000;
  then = now;
  const dt = Math.min(raw, 0.05);
  const before = performance.now();
  simulationTime =
    game.mode === "playing" ? Math.min(simulationTime + raw, 0.1) : 0;
  const movement = input();
  while (simulationTime >= 1 / 60) {
    game.update(1 / 60, movement);
    simulationTime -= 1 / 60;
    if (game.mode !== "playing") {
      simulationTime = 0;
      break;
    }
  }
  handleEvents();
  syncMode();
  world.render(game, dt);
  const renderTime = performance.now() - before;
  audio.tick(game.mode === "playing");
  if (raw > 0 && raw < 0.25) {
    frameSamples.push(raw * 1000);
    renderSamples.push(renderTime);
    if (frameSamples.length > 1200) {
      frameSamples.shift();
      renderSamples.shift();
    }
  }
  frames++;
  fpsTime += raw;
  if (fpsTime >= 0.75) {
    fps = Math.min(999, Math.round(frames / fpsTime));
    fpsTime = 0;
    frames = 0;
  }
  hudTime += dt;
  if (hudTime > 0.1) {
    hudTime = 0;
    if (game.mode !== "menu") hud();
  }
  if (game.mode !== "menu") labels();
  toastTimer -= dt;
  if (toastTimer <= 0) $("toast").classList.remove("visible");
  if (game.mode === "playing") tipTimer -= dt;
  $("tip").classList.toggle("hidden", tipTimer <= 0);
  requestAnimationFrame(frame);
}
syncMode();
requestAnimationFrame(frame);
const qaApi = {
  game,
  world,
  start,
  goHome,
  pause,
  choose,
  performance: () => {
    const sorted = [...frameSamples].sort((a, b) => a - b),
      r = [...renderSamples].sort((a, b) => a - b);
    const gl = world.renderer.getContext(),
      ext = gl.getExtension("WEBGL_debug_renderer_info");
    return {
      samples: sorted.length,
      medianFrameMs: sorted[Math.floor(sorted.length * 0.5)],
      p95FrameMs: sorted[Math.floor(sorted.length * 0.95)],
      medianRenderMs: r[Math.floor(r.length * 0.5)],
      p95RenderMs: r[Math.floor(r.length * 0.95)],
      fps,
      drawCalls: world.renderer.info.render.calls,
      triangles: world.renderer.info.render.triangles,
      pixelRatio: world.renderer.getPixelRatio(),
      renderer: ext
        ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)
        : gl.getParameter(gl.RENDERER),
    };
  },
  clearPerformance: () => {
    frameSamples = [];
    renderSamples = [];
  },
  collection,
  snapshot: () => ({
    mode: game.mode,
    classId: game.classId,
    wave: game.wave,
    survived: game.survived,
    score: game.score,
    base: game.base,
    kills: game.kills,
    collected: game.collected,
    turrets: game.weapons.length,
    player: { ...game.player },
    enemies: game.enemies.length,
    pickups: game.pickups.length,
    level: game.level,
  }),
};

if (import.meta.env.DEV) {
  window.__scrapkeep = qaApi;
  if (new URLSearchParams(location.search).has("qa"))
    import("../tests/browser-runner.js").then(({ installQA }) =>
      installQA(qaApi),
    );
}
