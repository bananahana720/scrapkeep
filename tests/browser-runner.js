import { pointOnPath, PATH_LENGTH } from "../src/game.js";
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const waitFor = async (predicate, timeout = 10000) => {
  const deadline = performance.now() + timeout;
  while (!predicate()) {
    if (performance.now() > deadline)
      throw new Error("Timed out waiting for game state");
    await delay(50);
  }
};
export function installQA(api) {
  const panel = document.createElement("aside");
  panel.id = "qa-panel";
  panel.style.cssText =
    "position:fixed;right:12px;top:65px;z-index:100;color:#d9eddf;background:#0b2026e8;border:1px solid #83ab93;padding:10px;font:10px monospace;max-width:380px;max-height:45vh;overflow:auto;pointer-events:auto";
  panel.innerHTML =
    '<button id="qa-run">Run regression replay</button> <button id="qa-victory">Stage victory result</button> <button id="qa-upgrade">Stage upgrade choice</button> <button id="qa-stress">Combat stress scene</button> <button id="qa-visual">Concept comparison scene</button><button id="qa-fire">Freeze combat frame</button><button id="qa-close">Arsenal detail view</button><button id="qa-clean">Hide interface</button><pre id="qa-results">Ready</pre><details><summary>Live performance telemetry</summary><pre id="qa-telemetry"></pre></details>';
  document.body.appendChild(panel);
  const results = document.getElementById("qa-results"),
    telemetry = document.getElementById("qa-telemetry");
  let running = false,
    stressDriver = null,
    stressKey = null;
  const update = () => {
    telemetry.textContent = JSON.stringify(
      { state: api.snapshot(), performance: api.performance() },
      null,
      2,
    );
  };
  setInterval(update, 1000);
  const key = (code, type = "keydown") =>
    window.dispatchEvent(new KeyboardEvent(type, { code, bubbles: true }));
  const tap = (code) => {
    key(code);
    key(code, "keyup");
  };
  document.getElementById("qa-fire").onclick = () => {
    const g = api.game;
    g.mode = "playing";
    g.player.momentum = 1;
    for (const w of g.weapons) w.cooldown = 0;
    for (let i = 0; i < 4; i++) g.update(1 / 60);
    for (const e of g.drainEvents()) api.world.event(e);
    g.mode = "paused";
    results.textContent =
      "Frozen real combat step for visual comparison. Projectiles use normal targeting and 3D trajectories.";
  };
  document.getElementById("qa-close").onclick = () => {
    api.world.camera.zoom = api.world.camera.zoom === 1 ? 2 : 1;
    api.world.camera.updateProjectionMatrix();
  };
  document.getElementById("qa-clean").onclick = () => {
    document.getElementById("app").style.visibility = "hidden";
    panel.style.display = "none";
    const restore = document.createElement("button");
    restore.textContent = "Restore interface";
    restore.style.cssText =
      "position:fixed;bottom:8px;right:8px;opacity:.15;z-index:100";
    document.body.appendChild(restore);
    restore.onclick = () => {
      document.getElementById("app").style.visibility = "";
      panel.style.display = "";
      restore.remove();
    };
  };
  document.getElementById("qa-visual").onclick = () => {
    if (stressDriver) clearInterval(stressDriver);
    if (stressKey) key(stressKey, "keyup");
    api.goHome();
    api.start();
    const g = api.game;
    g.player.x = 1;
    g.player.z = -3;
    g.player.radius = 1.75;
    g.collected = 24;
    g.time = 10;
    g.wave = 4;
    g.waveState = "assault";
    g.spawnLeft = 0;
    g.waveTimer = 100;
    g.weapons = [];
    for (let i = 0; i < 18; i++)
      g.addWeapon(["bolt", "pipe", "coil", "bolt", "cactus"][i % 5]);
    g.enemies = [];
    for (const travel of [14, 17, 24, 29, 33, 38, 41, 46, 49, 53]) {
      const e = g.spawnEnemy("bug");
      e.travel = travel;
      Object.assign(e, pointOnPath(travel));
    }
    g.mode = "paused";
    api.clearPerformance();
    results.textContent =
      "Staged concept comparison: real game geometry, 18 turret arsenal, fixed enemy placements.";
  };
  document.getElementById("qa-victory").onclick = () => {
    api.start();
    const g = api.game;
    g.wave = 14;
    g.survived = 14;
    g.startWave();
    g.spawnLeft = 0;
    g.enemies = [];
    g.pickups = [];
    g.score = 45000;
    g.update(1 / 60);
    results.textContent =
      "Staged victory fixture. Normal clear and result code resolve wave 15; this is not an earned playthrough.";
  };
  document.getElementById("qa-upgrade").onclick = () => {
    api.start();
    api.game.startWave();
    api.game.spawnLeft = 0;
    api.game.enemies = [];
    api.game.update(1 / 60);
    results.textContent =
      "Staged wave-clear fixture through the normal update path.";
  };
  document.getElementById("qa-run").onclick = async () => {
    if (running) return;
    running = true;
    results.textContent = "Running real DOM/control regression replay…";
    const records = [];
    const check = (name, truth, details = "") => {
      records.push({ name, pass: !!truth, details });
      results.textContent = records
        .map(
          (r) =>
            `${r.pass ? "PASS" : "FAIL"} ${r.name}${r.details ? " — " + r.details : ""}`,
        )
        .join("\n");
      if (!truth) throw new Error(name);
    };
    try {
      api.goHome();
      await delay(100);
      document.querySelector('[data-class="engineer"]').click();
      document.getElementById("start").click();
      await delay(150);
      check(
        "Selected class starts",
        api.game.classId === "engineer" && api.game.mode === "playing",
      );
      const startPoint = { ...api.game.player };
      key("KeyD");
      await waitFor(
        () =>
          api.world.screenPoint(api.game.player.x, 0, api.game.player.z).x >
          api.world.screenPoint(startPoint.x, 0, startPoint.z).x + 10,
      );
      key("KeyD", "keyup");
      check(
        "D rolls screen-right",
        api.world.screenPoint(api.game.player.x, 0, api.game.player.z).x >
          api.world.screenPoint(startPoint.x, 0, startPoint.z).x + 10,
      );
      tap("Space");
      await delay(40);
      check("Space activates dash", api.game.player.dashCooldown > 1.8);
      tap("KeyE");
      await delay(30);
      check("Engineer overclock activates", api.game.player.overclock > 5);
      tap("Escape");
      await delay(80);
      const time = api.game.time;
      await delay(180);
      check(
        "Pause freezes simulation",
        api.game.mode === "paused" && api.game.time === time,
      );
      document.getElementById("help").click();
      await delay(80);
      document.getElementById("close-help").click();
      await delay(80);
      check("Help preserves an existing pause", api.game.mode === "paused");
      document.getElementById("resume").click();
      await waitFor(() => api.game.mode === "playing" && api.game.time > time);
      check(
        "Resume continues",
        api.game.mode === "playing" && api.game.time > time,
      );
      tap("KeyR");
      await delay(80);
      check(
        "R resets the current class",
        api.game.classId === "engineer" &&
          api.game.time < 0.3 &&
          api.game.wave === 0,
      );
      api.goHome();
      await delay(80);
      document.querySelector('[data-class="scavenger"]').click();
      document.getElementById("start").click();
      await delay(100);
      const collectedBeforeSurge = api.game.collected;
      tap("KeyE");
      await waitFor(() => api.game.collected > collectedBeforeSurge);
      check(
        "Magnetic scenery becomes turrets",
        api.game.collected > collectedBeforeSurge &&
          api.game.weapons.length === api.game.collected + 2,
      );
      // Fixtures put late-run conditions on the live renderer; normal update/input code resolves them.
      api.game.reset("engineer");
      api.world.clearDynamic();
      api.game.player.x = -11;
      api.game.player.z = -7;
      api.game.pickups = [];
      api.game.waveTimer = 50;
      api.game.weapons.forEach((w) => (w.angle = Math.PI));
      api.game.spawnEnemy("bug");
      await waitFor(() => api.game.kills >= 1, 30000);
      check(
        "Mounted weapons kill marching enemies",
        api.game.kills >= 1 && api.game.xp > 0,
      );
      api.game.reset("warden");
      api.world.clearDynamic();
      api.game.weapons = [];
      api.game.waveTimer = 50;
      const enemy = api.game.spawnEnemy();
      enemy.travel = PATH_LENGTH - 0.001;
      await waitFor(() => api.game.base === 117);
      check("Enemy breach damages core", api.game.base === 117);
      api.game.base = 1;
      api.game.spawnEnemy().travel = PATH_LENGTH - 0.001;
      await waitFor(
        () =>
          api.game.mode === "gameover" &&
          !!document.querySelector(".gameover-dialog"),
      );
      check(
        "Fatal breach opens game over",
        api.game.mode === "gameover" &&
          !!document.querySelector(".gameover-dialog"),
      );
      document.getElementById("restart").click();
      await delay(100);
      check(
        "Game-over restart works",
        api.game.mode === "playing" && api.game.base === api.game.maxBase,
      );
      api.game.startWave();
      api.game.spawnLeft = 0;
      api.game.enemies = [];
      await waitFor(
        () =>
          api.game.mode === "upgrade" &&
          document.querySelectorAll("[data-upgrade]").length === 3,
      );
      check(
        "Wave score and upgrade choices",
        api.game.mode === "upgrade" &&
          api.game.survived === 1 &&
          api.game.score >= 1100 &&
          document.querySelectorAll("[data-upgrade]").length === 3,
      );
      tap("Digit2");
      await delay(100);
      check(
        "Keyboard upgrade continues the run",
        api.game.mode === "playing" && api.game.waveState === "gather",
      );
      document.getElementById("risk-choice")?.click();
      api.game.wave = 14;
      api.game.survived = 14;
      api.game.startWave();
      api.game.spawnLeft = 0;
      api.game.enemies = [];
      await waitFor(
        () =>
          api.game.mode === "victory" &&
          !!document.querySelector(".expedition-result"),
      );
      check(
        "Wave 15 opens victory and awards class mastery",
        api.game.mode === "victory" &&
          !!document.querySelector(".expedition-result") &&
          api.collection.lastAward?.awarded === 200,
      );
      const xpBeforeReturn =
        api.collection.profile.classes[api.game.classId].xp;
      document.getElementById("result-figurine").click();
      await waitFor(() => document.querySelector(".collection-dialog").open);
      check(
        "Result opens the selected figurine with optional consent",
        document.querySelector(".collection-dialog").open &&
          document
            .querySelector('[data-hero="' + api.game.classId + '"]')
            .getAttribute("aria-pressed") === "true" &&
          !document.getElementById("consent-email").checked &&
          !document.getElementById("consent-sms").checked,
      );
      const runTime = api.game.time;
      const emailInput = document.getElementById("lead-email");
      emailInput.focus();
      emailInput.dispatchEvent(
        new KeyboardEvent("keydown", { code: "KeyR", bubbles: true }),
      );
      emailInput.dispatchEvent(
        new KeyboardEvent("keydown", { code: "KeyP", bubbles: true }),
      );
      emailInput.dispatchEvent(
        new KeyboardEvent("keydown", { code: "Space", bubbles: true }),
      );
      check(
        "Typing contact details cannot restart or resume game",
        api.game.mode === "victory" && api.game.time === runTime,
      );
      document.querySelector(".dialog-close").click();
      api.goHome();
      await delay(100);
      check(
        "Leaving results cannot settle mastery twice",
        api.collection.profile.classes[api.game.classId].xp === xpBeforeReturn,
      );
      check(
        "Back to title",
        api.game.mode === "menu" &&
          !document.getElementById("menu").classList.contains("hidden"),
      );
      results.textContent += `\n\nALL ${records.length} BROWSER CHECKS PASSED`;
    } catch (error) {
      records.push({
        name: error.message,
        pass: false,
        details: "Replay did not complete",
      });
      results.textContent += "\nSTOPPED: " + error.message;
    } finally {
      running = false;
      panel.dataset.result = records.every((r) => r.pass) ? "pass" : "fail";
      panel.dataset.records = JSON.stringify(records);
      update();
    }
  };
  document.getElementById("qa-stress").onclick = () => {
    if (stressDriver) clearInterval(stressDriver);
    if (stressKey) key(stressKey, "keyup");
    api.goHome();
    document.querySelector('[data-class="engineer"]').click();
    api.start();
    const g = api.game;
    g.wave = 8;
    g.waveState = "assault";
    g.spawnLeft = 0;
    g.spawnTimer = 0.18;
    g.base = g.maxBase = 10000;
    g.player.x = 0;
    g.player.z = -2;
    g.player.radius = 1.75;
    g.collected = 40;
    g.buffs.range = 1.4;
    g.buffs.damage = 0.6;
    g.weapons = [];
    for (let i = 0; i < 24; i++)
      g.addWeapon(["bolt", "pipe", "coil", "cactus"][i % 4]);
    for (let i = 0; i < 45; i++) {
      const e = g.spawnEnemy(
        i % 7 === 0 ? "tank" : i % 3 === 0 ? "runner" : "bug",
      );
      e.travel = 4 + i * 1.3;
      e.hp = e.maxHp = 1000000;
      e.speed = 0.12;
      Object.assign(e, pointOnPath(e.travel));
    }
    let direction = 0;
    stressDriver = setInterval(() => {
      if (stressKey) key(stressKey, "keyup");
      if (g.mode === "playing") {
        stressKey = ["KeyD", "KeyS", "KeyA", "KeyW"][direction++ % 4];
        key(stressKey);
      }
    }, 350);
    api.clearPerformance();
    results.textContent =
      "STRESS FIXTURE: 24 mounted turrets, 45 durable moving enemies, wave 8 scaling. Runs through the real renderer and simulation. This is not a normal achieved game state.";
  };
}
