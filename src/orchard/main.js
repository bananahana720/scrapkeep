import "@fontsource/barlow-condensed/latin-700.css";
import "@fontsource/barlow-condensed/latin-800.css";
import "@fontsource/dm-sans/latin-400.css";
import "@fontsource/dm-sans/latin-500.css";
import "@fontsource/dm-sans/latin-700.css";
import "./styles.css";
import { OrchardGame, ARENA, LIGHTNING_CONFIG, ITEM_CONFIG } from "./simulation.js";
import { OrchardScene } from "./scene.js";

const $ = (id) => document.getElementById(id);
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
const qaEnabled = new URLSearchParams(location.search).has("qa");
const settings = { sensitivity: 1, audio: 0.45, uiScale: 1, impactShake: 0.35 };
try {
  const saved = JSON.parse(localStorage.getItem("orchard-settings") || "{}");
  for (const [name, lo, hi] of [
    ["sensitivity", 0.25, 2],
    ["audio", 0, 1],
    ["uiScale", 0.85, 1.25],
    ["impactShake", 0, 1],
  ]) {
    if (Number.isFinite(saved[name])) settings[name] = clamp(saved[name], lo, hi);
  }
} catch {}
const controlCopy = `<dl class="controls-list"><div><dt>Mouse + WASD</dt><dd>Look freely; roll with the camera.</dd></div><div><dt>Hold LMB / RMB</dt><dd>Repeat lightning / focused aim.</dd></div><div><dt>Hold, release Q / E</dt><dd>Preview, then cast strike / conductor.</dd></div><div><dt>Space / Shift / Ctrl</dt><dd>Double jump / ram burst / brake.</dd></div><div><dt>R / I / Escape</dt><dd>Ultimate / dashboard / cancel or pause.</dd></div></dl>`;
$("orchard-app").innerHTML = `
<header class="orchard-top"><a href="/" class="wordmark"><span>ϟ</span> SCRAPKEEP</a><span class="chapter">THE IRON ORCHARD</span><button id="dashboard-button" hidden><kbd>I</kbd> Dashboard</button></header>
<main id="welcome" class="welcome"><span class="eyebrow">LIGHTNING CASTER · PLAYTEST 01</span><h1>A LITTLE<br>THUNDER.</h1><p class="lead">Roll in. Light up the orchard.<br>Build something a little unreasonable.</p><button id="start" class="primary">Enter the orchard <span>↗</span></button><p class="capture-note">Click to capture your mouse. Escape pauses and releases it.</p><div class="welcome-controls">${controlCopy}</div><p id="device-note" class="secondary-text">One arena. Three waves. Rebuild between fights.</p></main>
<div id="play-hud" hidden>
<section class="wave-panel"><span id="wave-title" class="eyebrow">WAVE 1 / 3</span><strong id="wave-objective">Clear the orchard</strong><span id="wave-count" class="secondary-text"></span></section>
<div id="reticle" class="reticle" aria-hidden="true"><i></i><b></b></div><div id="target-feedback" class="target-feedback"></div>
<div id="threat" class="threat" role="status"></div><div id="entry-labels"></div><div id="enemy-labels"></div>
<div class="combat-bottom"><section id="pilot-status" class="pilot-status"><div class="health-caption"><strong>HULL</strong><span id="hull-value"></span></div><div class="hull-track"><i id="hull-fill"></i></div><div class="pilot-meta"><span id="air-state"></span><span id="scrap-value"></span></div></section>
<section class="ability-bar" aria-label="Abilities">${[
  ["bolt", "LMB", "ϟ", "Lightning"],
  ["strike", "Q", "◎", "Strike"],
  ["conductor", "E", "♜", "Conductor"],
  ["dash", "SHIFT", "➜", "Ram"],
  ["ultimate", "R", "✦", "Overcharge"],
]
  .map(
    ([id, key, symbol, name]) =>
      `<div id="ability-${id}" class="ability"><kbd>${key}</kbd><span class="ability-symbol" aria-hidden="true">${symbol}</span><strong>${name}</strong><span id="state-${id}" class="ability-state">Ready</span><i></i></div>`,
  )
  .join(
    "",
  )}</section><p class="combat-hint"><kbd>SPACE</kbd> double jump <span>·</span> <kbd>RMB</kbd> focus <span>·</span> <kbd>I</kbd> dashboard</p></div></div>
<div id="toast" class="toast" role="status" aria-live="polite"></div><div id="hurt-flash"></div>
<dialog id="dashboard" aria-labelledby="dialog-title"><div class="dialog-heading"><div><span id="dialog-kicker" class="eyebrow"></span><h2 id="dialog-title"></h2></div><button id="close-dialog" class="icon-button" aria-label="Close dashboard">×</button></div><nav id="dashboard-tabs" aria-label="Dashboard sections"></nav><div id="dialog-body"></div><footer id="dialog-footer"></footer></dialog>`;

const canvas = $("orchard-world"),
  game = new OrchardGame();
let world;
try {
  world = new OrchardScene(canvas);
} catch (error) {
  $("orchard-app").innerHTML =
    '<main class="fatal"><h1>The orchard could not start.</h1><p>This playtest needs WebGL 2 and 3D acceleration.</p><button onclick="location.reload()">Reload</button><a href="/">Original yard</a></main>';
  throw error;
}
const dialog = $("dashboard"),
  keys = new Set(),
  pulses = new Set(),
  blockedKeys = new Set();
let mouseFire = false,
  mouseAim = false,
  cancelNext = false,
  qaInput = false;
let dialogKind = null,
  selectedTab = "Character",
  previousFocus = null,
  capturePending = false;
let last = performance.now(),
  accumulator = 0,
  hudTimer = 0,
  lastMode = game.mode,
  toastLife = 0;
let eventSequence = 0;
let frames = 0,
  padPrevious = [],
  padBlocked = true;
const frameTimes = [],
  errorLog = [],
  eventLog = [];
const audio = { ctx: null };
window.addEventListener("error", (event) => errorLog.push(event.message));
window.addEventListener("unhandledrejection", (event) => errorLog.push(String(event.reason)));
function applySettings() {
  document.documentElement.style.setProperty("--ui-scale", settings.uiScale);
  world.setView({
    aiming: mouseAim,
    sensitivity: settings.sensitivity,
    impactShake: settings.impactShake,
  });
  try {
    localStorage.setItem("orchard-settings", JSON.stringify(settings));
  } catch {}
}
applySettings();
function enableAudio() {
  if (!settings.audio) return;
  try {
    audio.ctx ||= new (window.AudioContext || window.webkitAudioContext)();
    audio.ctx.resume().catch(() => {});
  } catch {}
}
function sound(type) {
  if (!audio.ctx || !settings.audio) return;
  const tone = {
    attack: [450, 150, 0.08],
    hit: [190, 80, 0.08],
    ram: [110, 40, 0.16],
    land: [85, 35, 0.13],
    bounce: [180, 360, 0.13],
    collect: [500, 850, 0.13],
    hurt: [95, 40, 0.2],
    win: [440, 880, 0.6],
    wave: [350, 550, 0.2],
  }[type];
  if (!tone) return;
  const t = audio.ctx.currentTime,
    oscillator = audio.ctx.createOscillator(),
    gain = audio.ctx.createGain();
  oscillator.type = type === "attack" ? "triangle" : "sine";
  oscillator.frequency.setValueAtTime(tone[0], t);
  oscillator.frequency.exponentialRampToValueAtTime(tone[1], t + tone[2]);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.linearRampToValueAtTime(settings.audio * 0.07, t + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + tone[2]);
  oscillator.connect(gain).connect(audio.ctx.destination);
  oscillator.start(t);
  oscillator.stop(t + tone[2] + 0.01);
}
function clearInput() {
  for (const code of keys) blockedKeys.add(code);
  keys.clear();
  pulses.clear();
  mouseFire = false;
  mouseAim = false;
  padBlocked = true;
  cancelNext = true;
  game.cancelActions();
  applySettings();
}
function releasePointer() {
  if (document.pointerLockElement === canvas) document.exitPointerLock();
}
function closeModal() {
  if (dialog.open) dialog.close();
  dialogKind = null;
  previousFocus?.focus?.();
}
function showModal(kind, title, kicker) {
  clearInput();
  releasePointer();
  dialogKind = kind;
  $("dialog-title").textContent = title;
  $("dialog-kicker").textContent = kicker;
  $("close-dialog").hidden = kind !== "dashboard";
  $("dashboard-tabs").hidden = kind !== "dashboard";
  if (!dialog.open) {
    previousFocus = document.activeElement;
    dialog.showModal();
  }
}
function captureFailure(reason) {
  const detail = {
    name: reason?.name || reason?.type || "CaptureTimeout",
    message: reason?.message || "The browser did not confirm pointer capture.",
    documentFocused: document.hasFocus(),
    visibility: document.visibilityState,
    supported: typeof canvas.requestPointerLock === "function",
  };
  canvas.dataset.captureError = JSON.stringify(detail);
  if ($("capture-detail")) $("capture-detail").textContent = `${detail.name}: ${detail.message}`;
  capturePending = false;
  if (qaInput || game.mode !== "playing") return;
  game.pause();
  showModal("capture", "Click to take control", "MOUSE CAPTURE NEEDED");
  $("dialog-body").innerHTML =
    '<p>Your browser did not capture the mouse. Click below to try again. If it keeps failing, focus this browser tab and check its pointer-lock permission.</p><p id="capture-detail" class="secondary-text"></p>';
  $("capture-detail").textContent = `${detail.name}: ${detail.message}`;
  $("dialog-footer").innerHTML =
    '<button id="capture-retry" class="primary">Capture mouse & resume</button><button id="capture-settings">Open dashboard</button>';
  $("capture-retry").onclick = resume;
  $("capture-settings").onclick = () => openDashboard();
}
function acquirePointer() {
  if (qaInput) return;
  if (document.pointerLockElement === canvas) return;
  capturePending = true;
  try {
    const request = canvas.requestPointerLock();
    request?.catch(captureFailure);
    setTimeout(() => {
      if (capturePending && document.pointerLockElement !== canvas) captureFailure();
    }, 1000);
  } catch (error) {
    captureFailure(error);
  }
}
function start(options = {}) {
  qaInput = qaEnabled && options.qa === true;
  closeModal();
  clearInput();
  game.reset();
  game.start();
  world.clear();
  world.resetCamera();
  accumulator = 0;
  $("welcome").hidden = true;
  $("play-hud").hidden = false;
  $("dashboard-button").hidden = false;
  lastMode = game.mode;
  canvas.focus();
  enableAudio();
  acquirePointer();
  updateHUD();
}
function resume() {
  closeModal();
  clearInput();
  game.resume();
  accumulator = 0;
  canvas.focus();
  enableAudio();
  if (game.mode === "playing") acquirePointer();
  else showRewards();
}
function openDashboard(tab = selectedTab) {
  if (game.mode === "ready") return;
  if (game.mode === "playing") game.pause();
  selectedTab = tab;
  showModal(
    "dashboard",
    "Your lightning caster",
    game.mode === "intermission" ? "BETWEEN WAVES · RECONFIGURE" : "PAUSED · INSPECT YOUR BUILD",
  );
  $("dashboard-tabs").innerHTML = ["Character", "Equipment", "Companion", "Map", "Settings"]
    .map(
      (name) =>
        `<button data-tab="${name}" aria-current="${name === tab ? "page" : "false"}">${name}</button>`,
    )
    .join("");
  for (const button of $("dashboard-tabs").querySelectorAll("button"))
    button.onclick = () => {
      selectedTab = button.dataset.tab;
      renderDashboard();
      for (const b of $("dashboard-tabs").children)
        b.setAttribute("aria-current", b === button ? "page" : "false");
    };
  $("dialog-footer").innerHTML =
    `<button id="resume" class="primary">${game.mode === "intermission" ? "Back to rewards" : "Resume play"}</button><button id="restart">Restart run</button><a href="/">Original yard ↗</a>`;
  $("resume").onclick = resume;
  $("restart").onclick = () => start({ qa: qaInput });
  renderDashboard();
}
function renderDashboard() {
  const p = game.player,
    equipped = game.inventory.equipped,
    editable = game.mode === "intermission",
    config = LIGHTNING_CONFIG;
  const movement = config.movement;
  const ramDamage =
    movement.ramDamage + Math.min(p.shear, movement.maxShearBonus) * movement.shearRamBonus;
  const ramCooldown = Math.max(
    movement.minRamCooldown,
    movement.ramCooldown - p.brace * movement.braceCooldownBonus,
  );
  const protection = Math.min(movement.maxBraceProtection, p.brace * movement.braceProtection);
  const stats = (rows) =>
    `<dl class="stat-grid">${rows.map(([name, value]) => `<div><dt>${name}</dt><dd>${value}</dd></div>`).join("")}</dl>`;
  if (selectedTab === "Character")
    $("dialog-body").innerHTML = `${stats([
      ["Hull", `${Math.ceil(p.hp)} / ${p.maxHp}`],
      ["Ball radius", `${p.radius.toFixed(2)} m`],
      ["Lightning bolt", `${config.bolt.damage} damage / ${config.bolt.interval}s`],
      ["Bolt reach", `${config.bolt.range} m`],
      ["Ram burst", `${ramDamage} damage / ${ramCooldown.toFixed(2)}s`],
      ["Brace protection", `${Math.round(protection * 100)}% less incoming damage`],
      [
        "Chain reach",
        `${(config.bolt.chainRange * (p.ultimateTime > 0 ? config.ultimate.chainMultiplier : 1)).toFixed(1)} m${p.ultimateTime > 0 ? " · overcharged" : ""}`,
      ],
      ["Ground strike", `${config.strike.damage} damage · ${config.strike.radius} m radius`],
      [
        "Conductor",
        `${config.conductor.damage} damage / ${(config.conductor.interval / (p.ultimateTime > 0 ? config.ultimate.conductorMultiplier : 1)).toFixed(2)}s · ${config.conductor.max} active`,
      ],
      [
        "Overcharge",
        `${config.ultimate.duration} seconds · ${Math.floor(p.ultimateCharge)}% ready`,
      ],
    ])}<p>${equipped.includes("echo") ? "Echo repeats compatible lightning, conductor and companion attacks once at half strength." : "Earn ultimate charge by hitting multiple enemies with lightning."} ${equipped.includes("ground-loop") ? "Ground Loop adds lightning chains to body impacts." : "Descending onto smaller workers damages them and restores an air jump."}</p><details class="controls-details"><summary>Controls</summary>${controlCopy}<p>Controller: left stick move, right stick look, A jump, B ram, RT lightning, LT focus, LB strike, RB conductor, Y ultimate, View dashboard, Start pause.</p></details>`;
  if (selectedTab === "Equipment") {
    $("dialog-body").innerHTML =
      `<p class="section-note">${editable ? "Enable or disable acquired items before continuing." : "Equipment changes unlock between waves."}</p><div class="equipment-grid">${Object.values(
        ITEM_CONFIG,
      )
        .map((item) => {
          const acquired = game.inventory.acquired.includes(item.id);
          return `<article class="item-card"><span class="eyebrow">${acquired ? "ACQUIRED" : "NOT ACQUIRED"}</span><h3>${item.name}</h3><p>${item.description}</p><label class="toggle-row"><input type="checkbox" data-item="${item.id}" ${equipped.includes(item.id) ? "checked" : ""} ${!editable || !acquired ? "disabled" : ""}> Enabled</label></article>`;
        })
        .join("")}</div>${stats([
        ["Shear Linkage", `${p.shear} collected · ${ramDamage} ram damage`],
        [
          "Adjustable Brace",
          `${p.brace} collected · ${ramCooldown.toFixed(2)}s burst recovery · ${Math.round(protection * 100)}% protection`,
        ],
        ["Scrap", `${p.scrap} collected · automatic growth`],
      ])}`;
    for (const toggle of $("dialog-body").querySelectorAll("[data-item]"))
      toggle.onchange = () => {
        game.setItemEnabled(toggle.dataset.item, toggle.checked);
        renderDashboard();
      };
  }
  if (selectedTab === "Companion") {
    const buddy = game.companion,
      unlocked = p.shear > 0;
    $("dialog-body").innerHTML =
      `<div class="companion-card"><span class="companion-symbol" aria-hidden="true">⌁</span><div><span class="eyebrow">ONE MAIN COMPANION</span><h3>Shear buddy</h3><p>${unlocked ? "Your priming companion follows and attacks nearby workers. The first Shear Linkage equipped it automatically." : "Collect a Shear Linkage from defeated workers to unlock and equip your priming companion."}</p><label class="toggle-row"><input id="companion-enabled" type="checkbox" ${buddy?.enabled ? "checked" : ""} ${!editable || !unlocked ? "disabled" : ""}> Companion enabled</label></div></div><p>${config.companion.damage} damage every ${config.companion.interval}s · ${config.companion.range} m reach. Hits prime enemy housings.</p><p>${equipped.includes("echo") ? "Echo is equipped: compatible companion attacks repeat once at half strength." : "Shared compatible modifiers apply automatically to your companion."}</p><p class="secondary-text">${editable ? "Companion changes are available now." : "Reconfigure your companion between waves."}</p>`;
    $("companion-enabled").onchange = (event) => {
      game.setCompanionEnabled(event.target.checked);
      renderDashboard();
    };
  }
  if (selectedTab === "Map") {
    const sx = (x) => ((x - ARENA.minX) / (ARENA.maxX - ARENA.minX)) * 380 + 10,
      sy = (z) => ((z - ARENA.minZ) / (ARENA.maxZ - ARENA.minZ)) * 400 + 10;
    $("dialog-body").innerHTML =
      `<div class="map-layout"><svg class="arena-map" viewBox="0 0 400 420" role="img" aria-label="Arena map showing your position, live enemies, conductors and available pickups"><rect x="10" y="10" width="380" height="400" rx="12" fill="#102b2a" stroke="#52776e"/><path d="M140 12 V408 M260 12 V408" stroke="#2c4a3d" stroke-width="32"/><text x="200" y="35" text-anchor="middle" fill="#b9d4c5" font-size="16">SEEDHOUSE</text>${game.pickups
        .filter((v) => !v.collected)
        .map((v) => `<circle cx="${sx(v.x)}" cy="${sy(v.z)}" r="3" fill="#e6c96e"/>`)
        .join("")}${game.enemies
        .filter((v) => v.hp > 0)
        .map(
          (v) =>
            `<circle cx="${sx(v.x)}" cy="${sy(v.z)}" r="${v.kind === "pruner" ? 8 : 4}" fill="#ff907a"/>`,
        )
        .join(
          "",
        )}${game.conductors.map((v) => `<rect x="${sx(v.x) - 4}" y="${sy(v.z) - 4}" width="8" height="8" fill="#7ceded"/>`).join("")}<circle cx="${sx(p.x)}" cy="${sy(p.z)}" r="7" fill="#fff" stroke="#5ce6db" stroke-width="3"/></svg><div><h3>The Iron Orchard</h3><p>White / cyan: you and conductors</p><p>Coral: live enemies</p><p>Gold: uncollected parts</p><p class="secondary-text">Safe reward breaks begin after every cleared wave. The final wave includes the Pruner arm.</p></div></div>`;
  }
  if (selectedTab === "Settings") {
    $("dialog-body").innerHTML = `<div class="settings-list">${[
      ["sensitivity", "Mouse sensitivity", 0.25, 2, 0.05],
      ["audio", "Audio volume", 0, 1, 0.05],
      ["uiScale", "Interface scale", 0.85, 1.25, 0.05],
      ["impactShake", "Impact shake", 0, 1, 0.05],
    ]
      .map(
        ([id, name, min, max, step]) =>
          `<label for="setting-${id}"><span>${name}<output id="value-${id}">${Math.round(settings[id] * 100)}%</output></span><input id="setting-${id}" type="range" min="${min}" max="${max}" step="${step}" value="${settings[id]}"></label>`,
      )
      .join(
        "",
      )}</div><p class="secondary-text">Preferences save on this browser. Run equipment and rewards reset with each new run.</p>`;
    for (const name of Object.keys(settings))
      $("setting-" + name).oninput = (event) => {
        settings[name] = Number(event.target.value);
        $("value-" + name).textContent = Math.round(settings[name] * 100) + "%";
        applySettings();
        if (name === "audio") enableAudio();
      };
  }
}
function showRewards() {
  if (game.mode !== "intermission") return;
  showModal("rewards", "Make the next wave yours", `WAVE ${game.wave.index} CLEARED`);
  $("dialog-body").innerHTML =
    `<p>A safe moment to collect your reward and adjust your equipment.</p><div class="reward-grid">${game.rewards.map((reward) => `<button class="reward-card" data-reward="${reward.id}" ${game.wave.rewardChosen ? "disabled" : ""}><span class="eyebrow">CHOOSE ONE</span><strong>${reward.name}</strong><span>${reward.description}</span></button>`).join("")}</div><p id="reward-confirmation" role="status">${game.wave.rewardChosen ? "Reward acquired. Your equipment is ready to reconfigure." : "Choose one reward to continue."}</p>`;
  $("dialog-footer").innerHTML =
    `<button id="continue-wave" class="primary" ${game.wave.rewardChosen ? "" : "disabled"}>Continue to wave ${game.wave.index + 1}</button><button id="reward-equipment">Equipment & companion</button>`;
  for (const button of $("dialog-body").querySelectorAll("[data-reward]"))
    button.onclick = () => {
      if (game.chooseReward(button.dataset.reward)) showRewards();
    };
  $("continue-wave").onclick = () => {
    if (game.continueWave()) {
      closeModal();
      clearInput();
      lastMode = game.mode;
      canvas.focus();
      acquirePointer();
    }
  };
  $("reward-equipment").onclick = () => openDashboard("Equipment");
}
function finish() {
  const won = game.mode === "won";
  showModal(
    "results",
    won ? "The orchard is yours." : "One more spark?",
    won ? "ALL THREE WAVES CLEARED" : "RUN ENDED",
  );
  $("dialog-body").innerHTML =
    `<p>${won ? "You cleared every worker and the Pruner arm." : "Jump through low attacks, keep moving, and use your conductors to hold the crowd."}</p><dl class="stat-grid"><div><dt>Wave</dt><dd>${game.wave.index} / 3</dd></div><div><dt>Time</dt><dd>${Math.round(game.time)}s</dd></div><div><dt>Scrap collected</dt><dd>${game.player.scrap}</dd></div></dl>`;
  $("dialog-footer").innerHTML =
    '<button id="play-again" class="primary">Start a fresh run</button><a href="/">Original yard ↗</a>';
  $("play-again").onclick = () => start({ qa: qaInput });
}
function dismiss() {
  if (dialogKind === "dashboard") resume();
  else if (game.mode === "playing") {
    if (game.preparedAbility || keys.has("KeyQ") || keys.has("KeyE")) {
      clearInput();
    } else openDashboard();
  }
}
$("start").onclick = () => start();
$("dashboard-button").onclick = () => openDashboard();
$("close-dialog").onclick = dismiss;
dialog.addEventListener("cancel", (event) => {
  event.preventDefault();
  dismiss();
});
window.addEventListener("keydown", (event) => {
  if (event.code === "Escape") {
    if (!dialog.open) {
      event.preventDefault();
      if (!event.repeat) dismiss();
    }
    return;
  }
  if (event.code === "KeyI" && !event.repeat) {
    event.preventDefault();
    if (dialogKind === "dashboard") resume();
    else if (!dialog.open) openDashboard();
    return;
  }
  if (dialog.open || game.mode !== "playing") return;
  if (["Space", "ControlLeft", "ControlRight"].includes(event.code)) event.preventDefault();
  if (!event.repeat && !blockedKeys.has(event.code)) {
    keys.add(event.code);
    pulses.add(event.code);
  }
});
window.addEventListener("keyup", (event) => {
  keys.delete(event.code);
  blockedKeys.delete(event.code);
});
canvas.addEventListener("contextmenu", (event) => event.preventDefault());
canvas.addEventListener("pointerdown", (event) => {
  if (game.mode !== "playing" || event.pointerType !== "mouse") return;
  if (document.pointerLockElement !== canvas && !qaInput) {
    clearInput();
    acquirePointer();
    return;
  }
  if (event.button === 0) mouseFire = true;
  if (event.button === 2) mouseAim = true;
});
window.addEventListener("pointerup", (event) => {
  if (event.button === 0) mouseFire = false;
  if (event.button === 2) mouseAim = false;
});
window.addEventListener("pointermove", (event) => {
  if (
    game.mode === "playing" &&
    (document.pointerLockElement === canvas || (qaInput && !event.isTrusted))
  )
    world.orbit(event.movementX, event.movementY);
});
document.addEventListener("pointerlockchange", () => {
  if (document.pointerLockElement === canvas) {
    capturePending = false;
    clearInput();
    canvas.focus();
  } else if (game.mode === "playing" && !qaInput && !dialog.open) openDashboard();
});
document.addEventListener("pointerlockerror", captureFailure);
window.addEventListener("blur", () => {
  clearInput();
  if (game.mode === "playing" && !qaInput) openDashboard();
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden && game.mode === "playing") {
    clearInput();
    openDashboard();
  }
});
window.addEventListener("resize", () => world.resize());
if (matchMedia("(pointer:coarse)").matches)
  $("device-note").textContent =
    "This playtest needs a keyboard and mouse, or a controller. Touch controls are not available.";
function controls(dt) {
  const down = (...codes) => codes.some((code) => keys.has(code) || pulses.has(code));
  let sx = Number(down("KeyD")) - Number(down("KeyA")),
    sz = Number(down("KeyS")) - Number(down("KeyW"));
  const state = {
    fire: mouseFire,
    strike: down("KeyQ"),
    conductor: down("KeyE"),
    dash: down("ShiftLeft", "ShiftRight"),
    jump: down("Space"),
    ultimate: down("KeyR"),
    brake: down("ControlLeft", "ControlRight"),
  };
  let focus = mouseAim;
  const pad = navigator.getGamepads?.()[0];
  if (pad) {
    const dead = (n) => (Math.abs(n || 0) > 0.16 ? n : 0),
      pressed = (i) => !!pad.buttons[i]?.pressed;
    if (
      padBlocked &&
      !pad.buttons.some((b) => b.pressed) &&
      !pad.axes.some((n) => Math.abs(n) > 0.16)
    )
      padBlocked = false;
    if (!padBlocked) {
      sx += dead(pad.axes[0]);
      sz += dead(pad.axes[1]);
      world.orbit(dead(pad.axes[2]) * dt * 650, dead(pad.axes[3]) * dt * 500);
      state.fire ||= pad.buttons[7]?.value > 0.2;
      focus ||= pad.buttons[6]?.value > 0.2;
      state.jump ||= pressed(0);
      state.dash ||= pressed(1);
      state.strike ||= pressed(4);
      state.conductor ||= pressed(5);
      state.ultimate ||= pressed(3);
      if ((pressed(9) && !padPrevious[9]) || (pressed(8) && !padPrevious[8])) openDashboard();
    }
    padPrevious = pad.buttons.map((b) => b.pressed);
  }
  world.setView({
    aiming: focus,
    sensitivity: settings.sensitivity,
    impactShake: settings.impactShake,
  });
  const length = Math.max(1, Math.hypot(sx, sz)),
    c = Math.cos(world.yaw),
    s = Math.sin(world.yaw);
  pulses.clear();
  const cancel = cancelNext;
  cancelNext = false;
  return {
    x: (c * sx - s * sz) / length,
    z: (s * sx + c * sz) / length,
    aim: world.aimRay(),
    ...state,
    cancel,
  };
}
function processEvents() {
  for (const event of game.drainEvents()) {
    world.event(event);
    sound(event.type);
    eventLog.push({
      sequence: ++eventSequence,
      type: event.type,
      kind: event.attack?.kind,
      source: event.source,
      echo: event.echo,
      time: game.time,
    });
    if (eventLog.length > 600) eventLog.shift();
    if (event.type === "collect" && ["shear", "brace"].includes(event.kind))
      toast(
        event.kind === "shear"
          ? "Shear Linkage · stronger rams + companion"
          : "Adjustable Brace · faster ram recovery",
      );
    if (event.type === "spawn") toast(event.text || "Workers entering the orchard", 2);
    if (event.type === "hurt") {
      $("hurt-flash").classList.remove("hit");
      void $("hurt-flash").offsetWidth;
      $("hurt-flash").classList.add("hit");
    }
  }
}
function toast(message, life = 3) {
  $("toast").textContent = message;
  $("toast").classList.add("show");
  toastLife = life;
}
function updateHUD() {
  const p = game.player,
    w = game.wave,
    targeting = game.targeting;
  $("hull-value").textContent = `${Math.ceil(p.hp)} / ${p.maxHp}`;
  $("hull-fill").style.width = `${clamp((p.hp / p.maxHp) * 100, 0, 100)}%`;
  $("pilot-status").classList.toggle("critical", p.hp / p.maxHp < 0.3);
  $("air-state").textContent = p.grounded
    ? "Double jump ready"
    : `${p.airJumps} air jump${p.airJumps === 1 ? "" : "s"}`;
  $("scrap-value").textContent = `${p.scrap} scrap`;
  $("wave-title").textContent = `WAVE ${w.index} / ${w.total}`;
  $("wave-objective").textContent = w.index === 3 ? "Clear the workers & Pruner" : "Clear the wave";
  $("wave-count").textContent = `${w.remaining} remaining · ${w.queued} incoming`;
  const cooldowns = {
    bolt: p.shotCooldown,
    strike: p.strikeCooldown,
    conductor: p.conductorCooldown,
    dash: p.dashCooldown,
    ultimate: p.ultimateTime,
  };
  for (const [id, cooldown] of Object.entries(cooldowns)) {
    $("state-" + id).textContent =
      id === "ultimate"
        ? p.ultimateTime > 0
          ? `${p.ultimateTime.toFixed(1)}s active`
          : `${Math.floor(p.ultimateCharge)}%`
        : cooldown > 0
          ? `${cooldown.toFixed(1)}s`
          : id === "conductor"
            ? `${game.conductors.length} / 2 · ready`
            : "Ready";
    $("ability-" + id).classList.toggle("cooling", cooldown > 0);
    $("ability-" + id).classList.toggle(
      "prepared",
      game.preparedAbility === id || (id === "ultimate" && p.ultimateCharge >= 100),
    );
  }
  $("reticle").classList.toggle("focused", world.view.aiming);
  $("reticle").classList.toggle("invalid", !!targeting && !targeting.valid);
  $("target-feedback").textContent = game.preparedAbility
    ? `${game.preparedAbility === "strike" ? "Ground strike" : "Storm conductor"} · ${targeting?.valid ? "release to cast" : "invalid placement"} · Esc cancel`
    : targeting?.blocked
      ? "Blocked"
      : "";
  $("entry-labels").innerHTML = (w.entries || [])
    .map((entry) => {
      const point = world.screenPoint(entry.x, 3, entry.z);
      const bearing = Math.atan2(entry.x - p.x, p.z - entry.z) - world.yaw;
      const relative = Math.atan2(Math.sin(bearing), Math.cos(bearing));
      const x = point.visible
        ? clamp(point.x, 100, innerWidth - 100)
        : relative < 0
          ? 110
          : innerWidth - 110;
      const y = point.visible ? clamp(point.y, 200, innerHeight - 230) : innerHeight * 0.42;
      return `<div class="entry-label" style="left:${x}px;top:${y}px"><b>${point.visible ? "◇" : Math.abs(relative) > 2 ? "↓" : relative < 0 ? "←" : "→"} ${entry.kinds.length} incoming</b><span>${Math.max(0, entry.time - game.time).toFixed(1)}s · ${entry.z < -16 ? "seedhouse" : entry.x < 0 ? "west rows" : "east rows"}</span></div>`;
    })
    .join("");
  const aimed = new Set(targeting?.targetIds || []);
  $("enemy-labels").innerHTML = game.enemies
    .filter(
      (e) =>
        e.hp > 0 &&
        (aimed.has(e.id) ||
          e.hitFlash > 0 ||
          ((e.state === "windup" || e.state === "active") &&
            Math.hypot(e.x - p.x, e.z - p.z) < 15)),
    )
    .map((e) => {
      const pt = world.screenPoint(e.x, e.y + (e.bodyHeight || 3) + 0.6, e.z);
      if (
        !pt.visible ||
        pt.y < 100 ||
        pt.y > innerHeight - 190 ||
        pt.x < 30 ||
        pt.x > innerWidth - 30
      )
        return "";
      return `<div class="enemy-label" style="left:${pt.x}px;top:${pt.y}px"><span>${e.kind === "pruner" ? "PRUNER ARM" : e.kind.toUpperCase()}${e.state === "recovery" ? " · EXPOSED" : ""}</span><div><i style="width:${clamp((e.hp / e.maxHp) * 100, 0, 100)}%"></i></div></div>`;
    })
    .join("");
  const threat = game.hazards
    .filter(
      (hazard) =>
        ["windup", "active"].includes(hazard.state) &&
        Math.hypot(hazard.x - p.x, hazard.z - p.z) <=
          hazard.range + (hazard.radius || 0) + p.radius,
    )
    .map((hazard) => ({
      hazard,
      distance: Math.hypot(hazard.x - p.x, hazard.z - p.z),
      a: Math.atan2(
        Math.sin(Math.atan2(hazard.x - p.x, p.z - hazard.z) - world.yaw),
        Math.cos(Math.atan2(hazard.x - p.x, p.z - hazard.z) - world.yaw),
      ),
    }))
    .filter((candidate) => Math.abs(candidate.a) > 0.8)
    .sort((a, b) => a.distance - b.distance)[0];
  $("threat").hidden = !threat || game.mode !== "playing";
  if (threat) {
    const direction = Math.abs(threat.a) > 2 ? "↓ Behind" : threat.a < 0 ? "← Left" : "Right →";
    const attack = threat.hazard.kind === "offcut" ? "offcut incoming" : "tool attack";
    $("threat").textContent =
      `${direction} · ${attack} · ${threat.hazard.jumpable ? "low · jump clear" : "tall · move clear"}`;
  }
}
function frame(now) {
  const elapsed = Math.max(0, now - last),
    dt = Math.min(0.05, elapsed / 1000);
  last = now;
  frameTimes.push(elapsed);
  if (frameTimes.length > 30000) frameTimes.shift();
  frames++;
  if (game.mode === "playing") {
    accumulator += dt;
    while (accumulator >= 1 / 120) {
      const input = controls(1 / 120);
      if (game.mode !== "playing") break;
      game.update(1 / 120, input);
      processEvents();
      accumulator -= 1 / 120;
      if (game.mode !== "playing") {
        accumulator = 0;
        break;
      }
    }
  } else accumulator = 0;
  world.update(game, game.mode === "paused" || game.mode === "intermission" ? 0 : dt);
  if (toastLife > 0) {
    toastLife -= dt;
    if (toastLife <= 0) $("toast").classList.remove("show");
  }
  hudTimer += dt;
  if (hudTimer > 0.06) {
    updateHUD();
    hudTimer = 0;
  }
  if (game.mode !== lastMode) {
    lastMode = game.mode;
    if (game.mode === "intermission") showRewards();
    else if (["won", "lost"].includes(game.mode)) finish();
  }
  requestAnimationFrame(frame);
}
updateHUD();
requestAnimationFrame(frame);
if (qaEnabled) {
  window.__orchard = {
    game,
    world,
    start: () => start({ qa: true }),
    pause: openDashboard,
    resume,
    clearInput,
    snapshot: () => game.snapshot(),
    controls: () => ({
      keys: [...keys],
      pulses: [...pulses],
      mouseFire,
      mouseAim,
      qaInput,
    }),
    performance: () => ({
      frames,
      frameTimes: [...frameTimes],
      drawCalls: world.renderer.info.render.calls,
      triangles: world.renderer.info.render.triangles,
      geometries: world.renderer.info.memory.geometries,
      textures: world.renderer.info.memory.textures,
      errors: [...errorLog],
    }),
    events: () => [...eventLog],
  };
  import("../../tests/orchard-browser-runner.js").then(({ installOrchardQA }) =>
    installOrchardQA(window.__orchard),
  );
}
