import "@fontsource/barlow-condensed/latin-700.css";
import "@fontsource/barlow-condensed/latin-800.css";
import "@fontsource/dm-sans/latin-400.css";
import "@fontsource/dm-sans/latin-500.css";
import "@fontsource/dm-sans/latin-700.css";
import "./styles.css";
import { OrchardGame, groundHeight } from "./simulation.js";
import { OrchardScene } from "./scene.js";

const $ = (id) => document.getElementById(id);
const icon = (name) =>
  ({ pause: "Ⅱ", play: "▶", arrow: "↗", sound: "♪", mute: "×", close: "×" })[
    name
  ] || "●";
$("orchard-app").innerHTML = `
  <header class="orchard-top">
    <a href="/" class="wordmark"><span class="brand-mark">S</span> SCRAPKEEP</a>
    <div class="chapter"><i></i><span>FIELD EXPEDITION</span><b>THE IRON ORCHARD</b></div>
    <nav aria-label="Game controls"><button id="audio-toggle" aria-label="Enable sound">♪ OFF</button><button id="guide" aria-label="Open field guide">?</button><button id="pause" aria-label="Pause" hidden>Ⅱ</button><a class="old-yard" href="/">ORIGINAL YARD ↗</a></nav>
  </header>
  <section id="welcome" class="welcome">
    <div class="eyebrow"><span></span> A LITTLE HERO. A VERY BIG PROBLEM.</div>
    <h1>MAKE A<br><em>LITTLE</em><br>CHAOS.</h1>
    <p class="lead">The orchard has a mind of its own.<br>Take its tools for a spin.</p>
    <div class="pilot-card"><span class="pilot-symbol">◉</span><div><b>PIP / SCRAP PILOT</b><p>One tiny hamster. Whatever the yard gives you.</p></div></div>
    <button id="start" class="primary">ROLL INTO THE ORCHARD <span>↗</span></button>
    <div class="welcome-controls"><span><kbd>WASD</kbd> ROLL</span><span><kbd>SPACE</kbd> RAM</span><span><kbd>HOLD F</kbd> CHARGE</span></div>
    <p class="build-note">FIRST PLAYABLE STUDY · A SHORT COMBAT EXPEDITION</p>
  </section>
  <div id="play-hud" hidden>
    <section class="objective"><span class="eyebrow">YOUR NEXT GOOD IDEA</span><h2 id="objective-title">Borrow their tools.</h2><p id="objective-text">Roll up loose scrap. Bait a cut, then hit the open housing.</p><div class="route"><i id="route-1"></i><i id="route-2"></i><i id="route-3"></i><span id="route-label">CUTTINGS → SUPPORT ROW → SEEDHOUSE</span></div></section>
    <section id="boss-card" class="boss-card" hidden><span>THE GRAND PRUNER</span><b>THE RIGHT HAND OF THE ORCHARD</b><div><i id="boss-fill"></i></div></section>
    <div id="reticle" class="reticle" aria-hidden="true"><i></i><span></span></div>
    <div id="target-label" class="target-label"></div>
    <div id="threat" class="threat" role="status" aria-live="polite"></div>
    <section class="pilot-status"><div class="micro">PIP <span id="hull-value">100 / 100</span></div><div class="hull-track"><i id="hull-fill"></i></div><div class="pilot-stats"><span><b id="speed">0</b> SPEED</span><span><b id="scrap">0</b> SCRAP</span><span><b id="size">1.0</b> SCALE</span></div></section>
    <section class="action-dock">
      <button id="ram-button" class="action"><kbd>SPACE</kbd><div><b>RAM BURST</b><span id="ram-state">READY</span></div><i id="ram-fill"></i></button>
      <div class="pulse-action"><div><span>HOLD <kbd>F</kbd> OR <kbd>LMB</kbd></span><b id="pulse-state">CHARGE PULSE</b></div><div class="charge-track"><i id="charge-fill"></i></div><small>RELEASE TO FIRE</small></div>
      <button id="buddy-button" class="action"><kbd>E</kbd><div><b>SHEAR BUDDY</b><span id="buddy-state">FIND A LINKAGE</span></div></button>
    </section>
    <section class="mechanisms"><span class="micro">MADE FROM YOUR ADVENTURE</span><div id="shear-part" class="part"><span>⌁</span><div><b>SHEAR LINKAGE</b><small>Find one on a Snipcart</small></div></div><div id="brace-part" class="part"><span>Ⅱ</span><div><b>ADJUSTABLE BRACE</b><small>Find one on a Spreadleg</small></div></div></section>
    <div class="control-hint"><kbd>SHIFT</kbd> BRAKE <span>·</span> MOUSE / ARROWS AIM <span>·</span> <kbd>C</kbd> FACE FORWARD</div>
    <div id="enemy-labels"></div>
  </div>
  <div id="toast" class="toast" role="status" aria-live="polite"><small id="toast-kicker"></small><strong id="toast-message"></strong></div>
  <div id="hurt-flash"></div>
  <section id="overlay" class="overlay" hidden aria-modal="true" role="dialog" aria-labelledby="overlay-title"><div class="overlay-card"><span id="overlay-kicker" class="eyebrow"></span><h2 id="overlay-title"></h2><div id="overlay-copy"></div><div id="overlay-buttons"></div></div></section>
  <div class="touch-pad" id="touch-controls" hidden><div id="touch-stick"><i></i></div><div class="touch-actions"><button id="touch-fire">PULSE</button><button id="touch-ram">RAM</button><button id="touch-brake">BRAKE</button><button id="touch-buddy">BUDDY</button></div></div>
`;
const canvas = $("orchard-world"),
  game = new OrchardGame();
let world;
try {
  world = new OrchardScene(canvas);
} catch (error) {
  $("orchard-app").innerHTML =
    '<section class="fatal"><h1>The orchard could not start.</h1><p>This build needs WebGL 2. Reload or try a browser with 3D acceleration enabled.</p><button onclick="location.reload()">RELOAD</button><a href="/">Original yard</a></section>';
  throw error;
}
const keys = new Set();
const input = {
  fire: false,
  dash: false,
  deploy: false,
  brake: false,
  touchX: 0,
  touchZ: 0,
};
let last = performance.now(),
  accumulator = 0,
  toastLife = 0,
  hudTimer = 0,
  guideOpen = false,
  guideWasPlaying = false,
  mouseDown = false,
  rightDrag = false,
  lastPointer = null;
let lastMode = game.mode,
  samples = [],
  frameCount = 0;
const audio = { ctx: null, enabled: false };
function sound(type, amount = 1) {
  if (!audio.enabled || !audio.ctx) return;
  const ctx = audio.ctx,
    t = ctx.currentTime;
  const settings = {
    shoot: [185, 620, 0.12, "triangle"],
    hit: [210, 85, 0.09, "square"],
    ram: [130, 40, 0.18, "sawtooth"],
    collect: [500, 900, 0.14, "sine"],
    hurt: [95, 45, 0.2, "triangle"],
    deploy: [290, 580, 0.2, "sine"],
    win: [440, 880, 0.7, "sine"],
    companion: [500, 700, 0.05, "sine"],
  }[type];
  if (!settings) return;
  const [f0, f1, dur, wave] = settings,
    osc = ctx.createOscillator(),
    gain = ctx.createGain();
  osc.type = wave;
  osc.frequency.setValueAtTime(f0, t);
  osc.frequency.exponentialRampToValueAtTime(f1, t + dur);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.linearRampToValueAtTime(type === "hurt" ? 0.05 : 0.025, t + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  osc.connect(gain).connect(ctx.destination);
  osc.start(t);
  osc.stop(t + dur + 0.02);
}
function enableSound() {
  if (!audio.ctx)
    audio.ctx = new (window.AudioContext || window.webkitAudioContext)();
  audio.ctx.resume();
  audio.enabled = !audio.enabled;
  $("audio-toggle").textContent = audio.enabled ? "♪ ON" : "♪ OFF";
  $("audio-toggle").setAttribute(
    "aria-label",
    audio.enabled ? "Mute sound" : "Enable sound",
  );
}
$("audio-toggle").onclick = enableSound;
function clearInput() {
  keys.clear();
  input.fire = false;
  input.dash = false;
  input.deploy = false;
  input.brake = false;
  input.touchX = input.touchZ = 0;
  mouseDown = false;
  rightDrag = false;
  lastPointer = null;
  $("touch-stick").firstElementChild.style.transform = "translate(0,0)";
}
function toast(kicker, message, duration = 3) {
  $("toast-kicker").textContent = kicker;
  $("toast-message").textContent = message;
  $("toast").classList.add("show");
  toastLife = duration;
}
function lockPointer() {
  if (
    document.pointerLockElement !== canvas &&
    window.matchMedia("(pointer:fine)").matches
  ) {
    try {
      canvas.requestPointerLock?.()?.catch(() => {});
    } catch {}
  }
}
function releasePointer() {
  if (document.pointerLockElement === canvas) document.exitPointerLock();
}
function start() {
  clearInput();
  guideOpen = false;
  game.reset();
  game.start();
  world.clear();
  world.resetCamera();
  accumulator = 0;
  $("welcome").hidden = true;
  $("overlay").hidden = true;
  $("play-hud").hidden = false;
  $("pause").hidden = false;
  $("touch-controls").hidden = !window.matchMedia("(pointer:coarse)").matches;
  lastMode = game.mode;
  canvas.focus();
  lockPointer();
  toast("WELCOME TO THE IRON ORCHARD", "Read the tool. Keep your exit.", 3.2);
  updateHUD();
}
$("start").onclick = start;
function pause() {
  if (game.mode === "playing") {
    game.pause();
    clearInput();
    releasePointer();
    showPause();
  } else if (game.mode === "paused" && !guideOpen) {
    game.resume();
    $("overlay").hidden = true;
    canvas.focus();
    lockPointer();
  }
}
$("pause").onclick = pause;
function overlay(kicker, title, copy, buttons) {
  $("overlay-kicker").textContent = kicker;
  $("overlay-title").textContent = title;
  $("overlay-copy").innerHTML = copy;
  $("overlay-buttons").innerHTML = buttons;
  $("overlay").hidden = false;
  $("overlay-buttons").querySelector("button")?.focus();
}
function showPause() {
  overlay(
    "TAKE A BREATHER",
    "PARKED, FOR NOW.",
    "<p>The orchard will wait. Your roll continues right here.</p>",
    '<button class="primary" id="resume">KEEP ROLLING <span>↗</span></button><button class="secondary" id="restart">START FRESH</button>',
  );
  $("resume").onclick = pause;
  $("restart").onclick = start;
}
function guide() {
  if (guideOpen) {
    guideOpen = false;
    $("overlay").hidden = true;
    if (guideWasPlaying) {
      game.resume();
      canvas.focus();
      lockPointer();
    } else if (game.mode === "paused") showPause();
    else if (["won", "lost"].includes(game.mode)) finish();
    return;
  }
  guideWasPlaying = game.mode === "playing";
  guideOpen = true;
  if (guideWasPlaying) game.pause();
  clearInput();
  releasePointer();
  overlay(
    "FIELD NOTES",
    "A LITTLE KNOW-HOW.",
    '<div class="guide-grid"><p><kbd>WASD</kbd><b>ROLL</b>Steer your momentum. Shift brakes for a tighter turn.</p><p><kbd>MOUSE / ARROWS</kbd><b>AIM</b>Click the world to capture the mouse, or hold right mouse to look around. C faces your travel direction.</p><p><kbd>SPACE</kbd><b>RAM BURST</b>A short burst. Hit a retracted housing for a stronger counter.</p><p><kbd>HOLD F / LMB</kbd><b>CHARGE PULSE</b>Release an aimed shot. A full charge hits hard. Ordinary shots work on every machine.</p><p><kbd>E</kbd><b>SHEAR BUDDY</b>Collect a Shear Linkage to deploy your own little support machine.</p><p><kbd>ESC / P</kbd><b>PAUSE</b>Restart from the pause or results screen.</p></div><p class="guide-note">Snipcart closes its jaws. Spreadleg pushes its feet outward. The giant arm repeats a familiar commitment. Amber shows preparation; the tool movement tells you where to go.</p><p class="guide-note">Gamepad: left stick roll, right stick aim, A ram, LT brake, hold/release RT pulse, X buddy, Start pause.</p>',
    '<button class="primary" id="close-guide">BACK TO IT <span>↗</span></button>',
  );
  $("close-guide").onclick = guide;
}
$("guide").onclick = guide;
window.addEventListener("keydown", (e) => {
  if (
    ["Space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(
      e.code,
    )
  )
    e.preventDefault();
  if (e.code === "KeyH") {
    if (!e.repeat) guide();
    return;
  }
  if (e.code === "Tab" && !$("overlay").hidden) {
    const items = [...$("overlay").querySelectorAll("button,a[href]")];
    if (e.shiftKey && document.activeElement === items[0]) {
      e.preventDefault();
      items.at(-1)?.focus();
    } else if (!e.shiftKey && document.activeElement === items.at(-1)) {
      e.preventDefault();
      items[0]?.focus();
    }
    return;
  }
  if (e.code === "Escape" || e.code === "KeyP") {
    if (!e.repeat) {
      if (guideOpen) guide();
      else pause();
    }
    return;
  }
  if (e.code === "KeyR" && game.mode !== "ready") {
    if (!e.repeat) start();
    return;
  }
  if (e.code === "Enter" && game.mode === "ready") {
    e.preventDefault();
    start();
    return;
  }
  if (e.code === "KeyM" && !e.repeat) {
    enableSound();
    return;
  }
  if (game.mode !== "playing") return;
  keys.add(e.code);
  if (e.code === "Space" && !e.repeat) input.dash = true;
  if (e.code === "KeyE" && !e.repeat) input.deploy = true;
  if (e.code === "KeyC" && !e.repeat) {
    const p = game.player;
    if (Math.hypot(p.vx, p.vz) > 0.4) world.yaw = Math.atan2(p.vx, -p.vz);
    else world.yaw = p.yaw;
  }
});
window.addEventListener("keyup", (e) => keys.delete(e.code));
canvas.addEventListener("contextmenu", (e) => e.preventDefault());
canvas.addEventListener("pointerdown", (e) => {
  if (game.mode !== "playing") return;
  if (e.pointerType === "mouse") {
    if (e.button === 0) {
      mouseDown = true;
      if (document.pointerLockElement !== canvas) lockPointer();
    }
    if (e.button === 2) {
      rightDrag = true;
      lastPointer = { x: e.clientX, y: e.clientY };
    }
  }
});
window.addEventListener("pointerup", (e) => {
  if (e.button === 0) mouseDown = false;
  if (e.button === 2) {
    rightDrag = false;
    lastPointer = null;
  }
});
window.addEventListener("pointermove", (e) => {
  if (game.mode !== "playing") return;
  if (document.pointerLockElement === canvas)
    world.orbit(e.movementX, e.movementY);
  else if (rightDrag && lastPointer) {
    world.orbit(e.clientX - lastPointer.x, e.clientY - lastPointer.y);
    lastPointer = { x: e.clientX, y: e.clientY };
  }
});
document.addEventListener("pointerlockchange", () => {
  if (document.pointerLockElement !== canvas) {
    mouseDown = false;
  }
});
window.addEventListener("blur", () => {
  clearInput();
  if (game.mode === "playing") {
    game.pause();
    showPause();
    releasePointer();
  }
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden && game.mode === "playing") {
    clearInput();
    game.pause();
    showPause();
  }
});
window.addEventListener("resize", () => world.resize());
$("ram-button").onclick = () => {
  if (game.mode === "playing") input.dash = true;
};
$("buddy-button").onclick = () => {
  if (game.mode === "playing") input.deploy = true;
};
$("touch-ram").onclick = () => {
  input.dash = true;
};
$("touch-buddy").onclick = () => {
  input.deploy = true;
};
for (const [id, field] of [
  ["touch-fire", "fire"],
  ["touch-brake", "brake"],
]) {
  $(id).addEventListener("pointerdown", (e) => {
    e.preventDefault();
    input[field] = true;
    $(id).setPointerCapture(e.pointerId);
  });
  for (const event of ["pointerup", "pointercancel"])
    $(id).addEventListener(event, () => (input[field] = false));
}
let stickId = null;
$("touch-stick").addEventListener("pointerdown", (e) => {
  stickId = e.pointerId;
  $("touch-stick").setPointerCapture(e.pointerId);
  moveStick(e);
});
$("touch-stick").addEventListener("pointermove", (e) => {
  if (e.pointerId === stickId) moveStick(e);
});
for (const event of ["pointerup", "pointercancel"])
  $("touch-stick").addEventListener(event, () => {
    stickId = null;
    input.touchX = input.touchZ = 0;
    $("touch-stick").firstElementChild.style.transform = "translate(0,0)";
  });
function moveStick(e) {
  const b = $("touch-stick").getBoundingClientRect(),
    x = e.clientX - b.left - b.width / 2,
    z = e.clientY - b.top - b.height / 2,
    d = Math.max(40, Math.hypot(x, z));
  input.touchX = x / d;
  input.touchZ = z / d;
  $("touch-stick").firstElementChild.style.transform =
    `translate(${(x / d) * 30}px,${(z / d) * 30}px)`;
}
let padPrevious = [];
function controls(dt) {
  let sx = Number(keys.has("KeyD")) - Number(keys.has("KeyA")) + input.touchX;
  let sz = Number(keys.has("KeyS")) - Number(keys.has("KeyW")) + input.touchZ;
  world.yaw +=
    (Number(keys.has("ArrowRight")) - Number(keys.has("ArrowLeft"))) * dt * 1.6;
  world.pitch = Math.max(
    0.06,
    Math.min(
      0.72,
      world.pitch +
        (Number(keys.has("ArrowDown")) - Number(keys.has("ArrowUp"))) *
          dt *
          0.8,
    ),
  );
  let fire = mouseDown || keys.has("KeyF") || input.fire,
    brake = keys.has("ShiftLeft") || keys.has("ShiftRight") || input.brake;
  const pad = navigator.getGamepads?.()[0];
  if (pad) {
    const dead = (n) => (Math.abs(n) > 0.16 ? n : 0);
    sx += dead(pad.axes[0]);
    sz += dead(pad.axes[1]);
    world.yaw += dead(pad.axes[2] || 0) * dt * 2;
    world.pitch = Math.max(
      0.06,
      Math.min(0.72, world.pitch + dead(pad.axes[3] || 0) * dt * 1.2),
    );
    fire = fire || pad.buttons[7]?.value > 0.2;
    brake = brake || pad.buttons[6]?.value > 0.2;
    if (pad.buttons[0]?.pressed && !padPrevious[0]) input.dash = true;
    if (pad.buttons[2]?.pressed && !padPrevious[2]) input.deploy = true;
    if (pad.buttons[9]?.pressed && !padPrevious[9]) pause();
    padPrevious = pad.buttons.map((b) => b.pressed);
  }
  const d = Math.max(1, Math.hypot(sx, sz));
  sx /= d;
  sz /= d;
  const c = Math.cos(world.yaw),
    s = Math.sin(world.yaw);
  const result = {
    x: c * sx - s * sz,
    z: s * sx + c * sz,
    aimYaw: world.yaw,
    fire,
    brake,
    dash: input.dash,
    deploy: input.deploy,
  };
  input.dash = false;
  input.deploy = false;
  return result;
}
function events() {
  for (const e of game.drainEvents()) {
    world.event(e);
    sound(e.type, e.amount);
    if (e.type === "collect") {
      if (e.kind === "shear")
        toast(
          "NEW MECHANISM",
          "Shear Linkage · harder rams + your own buddy",
          4,
        );
      if (e.kind === "brace")
        toast(
          "NEW MECHANISM",
          "Adjustable Brace · recover your burst sooner",
          4,
        );
    }
    if (e.type === "hurt") {
      $("hurt-flash").classList.remove("hit");
      void $("hurt-flash").offsetWidth;
      $("hurt-flash").classList.add("hit");
    }
    if (e.type === "deploy")
      toast("A LITTLE HELP", "Shear buddy is on the job.", 2);
    if (e.type === "hit" && e.text === "Housing counter!")
      toast("YOU READ THAT PERFECTLY", "HOUSING COUNTER", 1.2);
  }
}
function finish() {
  clearInput();
  releasePointer();
  $("pause").hidden = true;
  const won = game.mode === "won";
  overlay(
    won ? "THE ORCHARD CAN BREATHE AGAIN" : "SOME GOOD SCRAP IN THERE",
    won ? "SMALL HERO.<br>BIG DENT." : "ONE MORE ROLL?",
    `<p>${won ? "You learned the little machines. Then took a piece of the giant." : "That tool had your number. Try a wider exit, then bank back into the opening."}</p><div class="result-stats"><div><b>${game.stats.counters || 0}</b><span>COUNTERS</span></div><div><b>${game.stats.collected || 0}</b><span>PARTS COLLECTED</span></div><div><b>${Math.round(game.time)}s</b><span>IN THE ORCHARD</span></div></div>`,
    '<button class="primary" id="play-again">TAKE ANOTHER SPIN <span>↗</span></button><a class="secondary" href="/">VISIT THE ORIGINAL YARD ↗</a>',
  );
  // The outcome title is fixed trusted copy, not player data.
  $("overlay-title").innerHTML = won
    ? "SMALL HERO.<br>BIG DENT."
    : "ONE MORE ROLL?";
  $("play-again").onclick = start;
}
function updateHUD() {
  const p = game.player,
    speed = Math.hypot(p.vx, p.vz);
  $("hull-value").textContent = `${Math.ceil(p.hp)} / ${p.maxHp}`;
  $("hull-fill").style.width = `${Math.max(0, (p.hp / p.maxHp) * 100)}%`;
  $("pilot-status")?.classList.toggle("critical", p.hp / p.maxHp < 0.3);
  $("speed").textContent = speed.toFixed(1);
  $("scrap").textContent = p.scrap;
  $("size").textContent = (p.radius || 1).toFixed(2);
  $("ram-state").textContent =
    p.dashCooldown > 0 ? `${p.dashCooldown.toFixed(1)}s` : "READY";
  $("ram-fill").style.transform =
    `scaleX(${Math.min(1, p.dashCooldown / 1.45)})`;
  $("charge-fill").style.width = `${(p.charge || 0) * 100}%`;
  $("pulse-state").textContent =
    p.charge >= 0.98
      ? "FULL CHARGE"
      : p.charge > 0.02
        ? "CHARGING"
        : "CHARGE PULSE";
  $("reticle").classList.toggle("charged", p.charge >= 0.98);
  $("buddy-state").textContent = p.shear
    ? game.companion?.active
      ? "FOLLOWING YOU"
      : "READY TO DEPLOY"
    : "FIND A LINKAGE";
  for (const [key, name, effect] of [
    ["shear", "SHEAR LINKAGE", "Harder rams · buddy unlocked"],
    ["brace", "ADJUSTABLE BRACE", "Faster burst recovery"],
  ]) {
    const count = p[key] || 0,
      el = $(key + "-part");
    el.classList.toggle("found", count > 0);
    el.querySelector("b").textContent = name + (count > 1 ? ` ×${count}` : "");
    el.querySelector("small").textContent = count
      ? effect
      : key === "shear"
        ? "Find one on a Snipcart"
        : "Find one on a Spreadleg";
  }
  const boss = game.enemies.find((e) => e.kind === "pruner");
  const bossNear = boss && p.z < -16 && game.mode === "playing";
  $("boss-card").hidden = !bossNear;
  if (boss)
    $("boss-fill").style.width =
      `${Math.max(0, (boss.hp / boss.maxHp) * 100)}%`;
  if (p.z < -16) {
    $("objective-title").textContent = "You know this move.";
    $("objective-text").textContent =
      "The same fork. A much bigger arm. Leave the sweep and hit the housing.";
  } else if (p.z < 3) {
    $("objective-title").textContent = "Watch the feet.";
    $("objective-text").textContent =
      "Spreadleg pushes outward. Stay beyond its feet, then return to the exposed housing.";
  } else if (p.shear) {
    $("objective-title").textContent = "Make it work for you.";
    $("objective-text").textContent =
      "Press E to deploy your shear buddy. Follow the service road uphill.";
  } else {
    $("objective-title").textContent = "Borrow their tools.";
    $("objective-text").textContent =
      "Bait Snipcart's closing jaws. Roll clear, then ram the retracted housing.";
  }
  [1, 2, 3].forEach((n, i) =>
    $("route-" + n).classList.toggle("passed", p.z < [12, 0, -18][i]),
  );
  const aimed = game.enemies
    .filter((e) => e.hp > 0)
    .map((e) => {
      const dx = e.x - p.x,
        dz = e.z - p.z,
        d = Math.hypot(dx, dz),
        a = Math.atan2(dx, -dz) - world.yaw;
      return { e, d, a: Math.atan2(Math.sin(a), Math.cos(a)) };
    })
    .filter((t) => t.d < 28 && Math.abs(t.a) < 0.16)
    .sort((a, b) => a.d - b.d)[0];
  $("target-label").textContent = aimed
    ? (aimed.e.state === "recovery" ? "HOUSING EXPOSED · " : "") +
      (aimed.e.kind === "snipcart"
        ? "SNIPCART"
        : aimed.e.kind === "spreadleg"
          ? "SPREADLEG"
          : "GRAND PRUNER")
    : "";
  $("target-label").classList.toggle("exposed", aimed?.e.state === "recovery");
  const aim = world.aimPoint(p);
  $("reticle").style.left = aim.x + "px";
  $("reticle").style.top = aim.y + "px";
  $("target-label").style.left = aim.x + "px";
  $("target-label").style.top = aim.y + 24 + "px";
  const threatening = game.enemies
    .filter((e) => e.hp > 0 && ["windup", "active"].includes(e.state))
    .sort(
      (a, b) =>
        Math.hypot(a.x - p.x, a.z - p.z) - Math.hypot(b.x - p.x, b.z - p.z),
    )[0];
  $("threat").classList.toggle(
    "show",
    !!threatening && game.mode === "playing",
  );
  if (threatening) {
    const a =
      Math.atan2(threatening.x - p.x, -(threatening.z - p.z)) - world.yaw;
    const relative = Math.atan2(Math.sin(a), Math.cos(a));
    const direction =
      Math.abs(relative) > 1.8
        ? "BEHIND YOU"
        : relative < -0.65
          ? "LEFT"
          : relative > 0.65
            ? "RIGHT"
            : "AHEAD";
    $("threat").textContent =
      `${direction} · ${threatening.kind === "spreadleg" ? "FEET SPREADING" : threatening.attackStyle === "toss" ? "OFFCUT INCOMING" : threatening.kind === "pruner" ? "ARM COMMITTING" : "SHEARS CLOSING"}`;
  }
  $("enemy-labels").innerHTML = game.enemies
    .filter(
      (e) => e.hp > 0 && e.active && Math.hypot(e.x - p.x, e.z - p.z) < 24,
    )
    .map((e) => {
      const pt = world.screenPoint(
        e.x,
        e.y + (e.kind === "pruner" ? 6 : 3.1),
        e.z,
      );
      if (
        !pt.visible ||
        pt.x < 20 ||
        pt.x > innerWidth - 20 ||
        pt.y < 90 ||
        pt.y > innerHeight - 190
      )
        return "";
      return `<div class="enemy-label ${e.state === "recovery" ? "open" : ""}" style="left:${pt.x}px;top:${pt.y}px"><span>${e.kind === "snipcart" ? "SNIPCART" : e.kind === "spreadleg" ? "SPREADLEG" : "PRUNER ARM"}</span><div><i style="width:${(e.hp / e.maxHp) * 100}%"></i></div>${e.state === "recovery" ? "<b>OPEN</b>" : ""}</div>`;
    })
    .join("");
}
function frame(now) {
  const elapsed = Math.max(0, (now - last) / 1000),
    dt = Math.min(0.05, elapsed);
  last = now;
  if (elapsed > 0) {
    samples.push(1 / elapsed);
    if (samples.length > 120) samples.shift();
  }
  if (game.mode !== "playing") {
    const pad = navigator.getGamepads?.()[0];
    if (pad) {
      const startPressed = pad.buttons[9]?.pressed && !padPrevious[9];
      const confirmPressed = pad.buttons[0]?.pressed && !padPrevious[0];
      if (game.mode === "paused" && startPressed) {
        if (guideOpen) guide();
        else pause();
      } else if (
        ["ready", "won", "lost"].includes(game.mode) &&
        (startPressed || confirmPressed)
      )
        start();
      padPrevious = pad.buttons.map((b) => b.pressed);
    }
  }
  if (game.mode === "playing") {
    accumulator += dt;
    while (accumulator >= 1 / 120) {
      game.update(1 / 120, controls(1 / 120));
      events();
      accumulator -= 1 / 120;
      if (game.mode !== "playing") {
        accumulator = 0;
        break;
      }
    }
  } else accumulator = 0;
  world.update(game, game.mode === "paused" ? 0 : dt);
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
    if (["won", "lost"].includes(game.mode)) finish();
  }
  frameCount++;
  requestAnimationFrame(frame);
}
updateHUD();
requestAnimationFrame(frame);
if (new URLSearchParams(location.search).has("qa")) {
  window.__orchard = {
    game,
    world,
    start,
    pause,
    snapshot: () => game.snapshot(),
    performance: () => ({
      frames: frameCount,
      fps: samples.length
        ? samples.reduce((a, b) => a + b, 0) / samples.length
        : 0,
      drawCalls: world.renderer.info.render.calls,
      triangles: world.renderer.info.render.triangles,
    }),
    controls: () => ({ keys: [...keys], ...input }),
  };
  import("../../tests/orchard-browser-runner.js").then(
    ({ installOrchardQA }) => {
      installOrchardQA(window.__orchard);
    },
  );
}
