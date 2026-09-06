import {
  groundHeight,
  ENEMY_CONFIG,
  LIGHTNING_CONFIG,
} from "../src/orchard/simulation.js";

export function installOrchardQA(api) {
  const panel = document.createElement("details");
  panel.id = "orchard-qa";
  panel.innerHTML =
    '<summary>Playtest verification</summary><p>QA uses synthetic DOM input. Mouse capture is checked separately in normal play.</p><button id="qa-controls">Run DOM input replay</button><button id="qa-fixtures">Run state fixtures</button><button id="qa-expedition">Run input expedition</button><button id="qa-stress">Run 60-second bounded stress</button><button id="qa-windup">View low / tall attack fixture</button><button id="qa-boss">View final wave fixture</button><button id="qa-hero">View airborne caster fixture</button><pre id="qa-results" aria-live="polite">Ready. Fixtures and earned progression are recorded separately.</pre><a id="qa-download" hidden>Download evidence JSON</a>';
  document.body.appendChild(panel);
  const results = panel.querySelector("#qa-results"),
    canvas = document.getElementById("orchard-world");
  let running = false,
    records = [],
    downloadUrl;
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const key = (code, type = "keydown") =>
    window.dispatchEvent(new KeyboardEvent(type, { code, bubbles: true }));
  const pointer = (type, button = 0, extra = {}) =>
    (type === "pointerdown" ? canvas : window).dispatchEvent(
      new PointerEvent(type, {
        pointerType: "mouse",
        button,
        bubbles: true,
        ...extra,
      }),
    );
  const tap = async (code) => {
    key(code);
    await wait(24);
    key(code, "keyup");
  };
  const until = async (predicate, limit = 12000) => {
    const deadline = performance.now() + limit;
    while (!predicate()) {
      if (performance.now() > deadline)
        throw new Error("Timed out waiting for game condition");
      await wait(16);
    }
  };
  const advance = async (seconds) => {
    const target = api.game.time + seconds;
    await until(
      () =>
        api.game.time >= target ||
        ["won", "lost", "intermission"].includes(api.game.mode),
    );
  };
  const check = (name, pass, details = "") => {
    records.push({ name, pass: !!pass, details });
    results.textContent = records
      .map(
        (r) =>
          `${r.pass ? "PASS" : "FAIL"} ${r.name}${r.details ? " · " + r.details : ""}`,
      )
      .join("\n");
    if (!pass) throw new Error(name);
  };
  const begin = (kind) => {
    running = true;
    records = [];
    panel.dataset.kind = kind;
    panel.dataset.result = "running";
    results.textContent = "Running " + kind;
    for (const button of panel.querySelectorAll("button"))
      button.disabled = true;
  };
  const finish = (error, extra = {}) => {
    running = false;
    panel.dataset.result = error ? "fail" : "pass";
    panel.dataset.records = JSON.stringify(records);
    if (error) results.textContent += "\nERROR " + error.message;
    const report = {
      kind: panel.dataset.kind,
      result: panel.dataset.result,
      records,
      ...extra,
    };
    panel.dataset.report = JSON.stringify(report);
    if (downloadUrl) URL.revokeObjectURL(downloadUrl);
    downloadUrl = URL.createObjectURL(
      new Blob([JSON.stringify(report, null, 2)], { type: "application/json" }),
    );
    const link = panel.querySelector("#qa-download");
    link.href = downloadUrl;
    link.download =
      "orchard-" +
      panel.dataset.kind.replaceAll(" ", "-").toLowerCase() +
      ".json";
    link.hidden = false;
    link.textContent = "Download evidence JSON";
    for (const button of panel.querySelectorAll("button"))
      button.disabled = false;
  };
  const park = () => {
    api.clearInput();
    if (api.game.mode === "playing") api.game.pause();
  };
  const aimAt = (target) => {
    const world = api.world,
      p = api.game.player;
    const desired = Math.atan2(target.x - p.x, p.z - target.z),
      delta = Math.atan2(
        Math.sin(desired - world.yaw),
        Math.cos(desired - world.yaw),
      );
    const point = world.screenPoint(target.x, target.y, target.z);
    const focal =
      innerHeight / (2 * Math.tan((world.camera.fov * Math.PI) / 360));
    const dx =
      point.behind || Math.abs(delta) > 1.2
        ? delta
        : Math.atan((point.x - innerWidth / 2) / focal) * 0.65;
    const dy = point.behind
      ? 0
      : Math.atan((point.y - innerHeight / 2) / focal) * 0.65;
    pointer("pointermove", 0, {
      movementX: dx / (0.003 * world.view.sensitivity || 0.003),
      movementY: dy / (0.002 * world.view.sensitivity || 0.002),
    });
  };
  panel.querySelector("#qa-controls").onclick = async () => {
    if (running) return;
    begin("DOM input replay");
    try {
      api.start();
      await advance(0.08);
      check(
        "Fresh run starts with no queued attacks",
        api.game.mode === "playing" && api.game.stats.shots === 0,
      );
      const z = api.game.player.z;
      key("KeyW");
      await advance(0.6);
      key("KeyW", "keyup");
      check("W rolls with the camera", api.game.player.z < z - 1);
      key("ControlLeft");
      await advance(0.3);
      key("ControlLeft", "keyup");
      check(
        "Ctrl brakes horizontal motion",
        Math.hypot(api.game.player.vx, api.game.player.vz) < 2,
      );
      await tap("Space");
      await advance(0.08);
      check("Space jumps", !api.game.player.grounded && api.game.player.vy > 0);
      await tap("Space");
      await advance(0.04);
      check(
        "Second Space consumes the only air jump",
        api.game.player.airJumps === 0 && api.game.player.vy > 0,
      );
      const vy = api.game.player.vy;
      await tap("Space");
      await advance(0.025);
      check(
        "Third Space does not grant another jump",
        api.game.player.airJumps === 0 && api.game.player.vy < vy,
      );
      pointer("pointerdown", 2);
      await advance(0.03);
      check("RMB enters focused aim", api.controls().mouseAim);
      pointer("pointerup", 2);
      const shots = api.game.stats.shots;
      pointer("pointerdown", 0);
      await advance(0.75);
      pointer("pointerup", 0);
      check("Held LMB repeats aimed bolts", api.game.stats.shots >= shots + 2);
      key("KeyQ");
      await advance(0.04);
      check(
        "Held Q prepares a circular strike",
        api.game.preparedAbility === "strike" &&
          api.game.targeting.kind === "strike",
      );
      await tap("Escape");
      key("KeyQ", "keyup");
      await advance(0.04);
      check(
        "Escape cancels preparation without casting or pausing",
        api.game.mode === "playing" &&
          !api.game.preparedAbility &&
          api.game.player.strikeCooldown === 0,
      );
      await until(() => api.game.player.grounded);
      key("KeyQ");
      await advance(0.06);
      const valid = api.game.targeting.valid;
      key("KeyQ", "keyup");
      await advance(0.04);
      check(
        "Q release commits valid preview or preserves cooldown when invalid",
        valid
          ? api.game.player.strikeCooldown > 0
          : api.game.player.strikeCooldown === 0,
      );
      key("KeyE");
      await advance(0.06);
      const conductorValid = api.game.targeting.valid;
      key("KeyE", "keyup");
      await advance(0.04);
      check(
        "E release places valid conductor or preserves cooldown",
        conductorValid
          ? api.game.conductors.length === 1
          : api.game.player.conductorCooldown === 0,
      );
      await tap("ShiftLeft");
      await advance(0.025);
      check(
        "Shift triggers directional ram burst",
        api.game.player.dashTime > 0,
      );
      key("KeyW");
      key("KeyQ");
      pointer("pointerdown", 0);
      await advance(0.03);
      await tap("KeyI");
      const frozen = api.game.time,
        shotsBefore = api.game.stats.shots;
      await wait(120);
      check(
        "Dashboard pauses simulation and clears pending targeting",
        api.game.mode === "paused" &&
          api.game.time === frozen &&
          !api.game.preparedAbility &&
          document.getElementById("dashboard").open,
      );
      for (const name of [
        "Character",
        "Equipment",
        "Companion",
        "Map",
        "Settings",
      ]) {
        document.querySelector(`[data-tab="${name}"]`).click();
        check(
          "Dashboard section " + name + " opens",
          document.getElementById("dialog-body").textContent.length > 25,
        );
      }
      document.querySelector('[data-tab="Equipment"]').click();
      check(
        "Combat equipment controls are disabled",
        [...document.querySelectorAll("[data-item]")].every(
          (node) => node.disabled,
        ),
      );
      document.getElementById("resume").click();
      await advance(0.16);
      check(
        "Resume does not fire or release the queued strike",
        api.game.stats.shots === shotsBefore &&
          !api.game.preparedAbility &&
          !api.controls().keys.length,
      );
      key("KeyW", "keyup");
      key("KeyQ", "keyup");
      pointer("pointerup", 0);
      await tap("KeyR");
      check("R is an ultimate input, never a restart", api.game.time > frozen);
      await tap("KeyI");
      document.getElementById("restart").click();
      await advance(0.04);
      check(
        "Menu restart clears run power and attacks",
        api.game.player.scrap === 0 &&
          api.game.stats.shots === 0 &&
          api.game.inventory.acquired.length === 0,
      );
      park();
      finish(null, { snapshot: api.snapshot() });
    } catch (error) {
      park();
      finish(error);
    }
  };
  panel.querySelector("#qa-fixtures").onclick = async () => {
    if (running) return;
    begin("State fixtures - staged progression");
    try {
      api.start();
      await advance(0.04);
      const g = api.game,
        p = g.player;
      g.pickups = [
        {
          id: "qa-shear",
          x: p.x,
          y: p.y,
          z: p.z,
          kind: "shear",
          collected: false,
        },
        {
          id: "qa-brace",
          x: p.x,
          y: p.y,
          z: p.z,
          kind: "brace",
          collected: false,
        },
      ];
      await advance(0.06);
      check(
        "Automatic parts unlock and equip companion",
        p.shear === 1 && p.brace === 1 && g.companion?.enabled,
      );
      p.ultimateCharge = 100;
      await tap("KeyR");
      await advance(0.03);
      check(
        "Charged R activates eight-second ultimate",
        p.ultimateTime > 7.8 &&
          p.ultimateTime <= LIGHTNING_CONFIG.ultimate.duration,
      );
      g._waveQueue = [];
      g.wave.entries = [];
      for (const enemy of g.enemies) {
        enemy.hp = 0;
        enemy.state = "dead";
      }
      await until(() => g.mode === "intermission");
      await wait(100);
      check(
        "Wave one displays an explicit safe reward break",
        document.getElementById("continue-wave")?.disabled &&
          g.rewards.length === 2,
      );
      const first = g.rewards.find((r) => r.id === "ground-loop");
      check("First reward offers Ground Loop", !!first);
      document.querySelector('[data-reward="ground-loop"]').click();
      check(
        "Ground Loop acquired once",
        g.inventory.acquired.includes("ground-loop") &&
          g.inventory.equipped.includes("ground-loop"),
      );
      document.getElementById("reward-equipment").click();
      const toggle = document.querySelector('[data-item="ground-loop"]');
      check("Intermission enables equipment changes", !toggle.disabled);
      toggle.click();
      check(
        "Item disable is functional",
        !g.inventory.equipped.includes("ground-loop"),
      );
      document.querySelector('[data-item="ground-loop"]').click();
      check(
        "Item can be re-enabled",
        g.inventory.equipped.includes("ground-loop"),
      );
      document.querySelector('[data-tab="Companion"]').click();
      document.getElementById("companion-enabled").click();
      check("Companion disable is functional", !g.companion.enabled);
      document.getElementById("companion-enabled").click();
      check("Companion can be re-enabled", g.companion.enabled);
      document.getElementById("resume").click();
      document.getElementById("continue-wave").click();
      await advance(0.03);
      check(
        "Explicit continue starts wave two",
        g.wave.index === 2 && g.mode === "playing",
      );
      g._waveQueue = [];
      g.wave.entries = [];
      for (const enemy of g.enemies) {
        enemy.hp = 0;
        enemy.state = "dead";
      }
      await until(() => g.mode === "intermission");
      await wait(100);
      document.querySelector('[data-reward="echo"]').click();
      check(
        "Second reward permits full modifier combination",
        g.inventory.equipped.includes("echo") &&
          g.inventory.equipped.includes("ground-loop"),
      );
      document.getElementById("continue-wave").click();
      await advance(0.03);
      check("Wave three begins with chosen build", g.wave.index === 3);
      g._waveQueue = [];
      g.wave.entries = [];
      for (const enemy of g.enemies) {
        enemy.hp = 0;
        enemy.state = "dead";
      }
      await until(() => g.mode === "won");
      await wait(100);
      check(
        "Cleared final fixture renders victory",
        document.getElementById("dialog-title").textContent.includes("yours") &&
          !!document.getElementById("play-again"),
      );
      document.getElementById("play-again").click();
      await advance(0.03);
      check(
        "Results restart clears modifiers and companion",
        g.inventory.acquired.length === 0 && p !== g.player && !g.companion,
      );
      g.player.hurtTime = 0;
      g._hurt(g.player.maxHp * 2, { kind: "snipcart" });
      await advance(0.03);
      await wait(100);
      check(
        "Loss renders recoverable results",
        g.mode === "lost" && !!document.getElementById("play-again"),
      );
      document.getElementById("play-again").click();
      await advance(0.03);
      park();
      finish(null);
    } catch (error) {
      finish(error);
    }
  };
  panel.querySelector("#qa-expedition").onclick = async () => {
    if (running) return;
    begin("DOM input expedition - no state fixtures");
    const held = new Set();
    const press = (code, down) => {
      if (down && !held.has(code)) {
        held.add(code);
        key(code);
      } else if (!down && held.has(code)) {
        held.delete(code);
        key(code, "keyup");
      }
    };
    try {
      api.start();
      await advance(0.06);
      const g = api.game;
      const deadline = performance.now() + 300000;
      let nextJump = 2,
        nextStrike = 1,
        nextConductor = 2,
        strikeRelease = 0,
        conductorRelease = 0,
        intermissions = 0;
      pointer("pointerdown", 0);
      while (!["won", "lost"].includes(g.mode)) {
        if (performance.now() > deadline)
          throw new Error("Input expedition exceeded five real minutes");
        if (g.mode === "intermission") {
          for (const code of [...held]) press(code, false);
          pointer("pointerup", 0);
          await wait(120);
          const reward = g.wave.index === 1 ? "ground-loop" : "echo";
          document.querySelector(`[data-reward="${reward}"]`).click();
          check(
            "Earned wave " + g.wave.index + " reward",
            g.inventory.acquired.includes(reward),
            `HP ${Math.ceil(g.player.hp)}, t=${g.time.toFixed(1)}`,
          );
          document.getElementById("continue-wave").click();
          intermissions++;
          await wait(80);
          pointer("pointerdown", 0);
          continue;
        }
        const p = g.player,
          enemies = g.enemies
            .filter((e) => e.hp > 0)
            .sort(
              (a, b) =>
                Math.hypot(a.x - p.x, a.z - p.z) -
                Math.hypot(b.x - p.x, b.z - p.z),
            );
        const target = enemies[0];
        if (target) {
          const d = Math.hypot(target.x - p.x, target.z - p.z);
          aimAt({
            x: target.x,
            y: target.y + target.bodyHeight * 0.55,
            z: target.z,
          });
          press("KeyW", d > 17);
          press("KeyS", d < 8);
          press(
            "KeyD",
            d <= 17 && d >= 8 && Math.abs(p.x) < 16 && p.z > -32 && p.z < 22,
          );
          if (g.time > nextJump) {
            press("Space", true);
            nextJump = g.time + 1.5;
          } else press("Space", false);
          if (
            g.time > nextStrike &&
            p.strikeCooldown === 0 &&
            !g.preparedAbility
          ) {
            press("KeyQ", true);
            strikeRelease = g.time + 0.08;
            nextStrike = g.time + LIGHTNING_CONFIG.strike.cooldown + 0.2;
          }
          if (strikeRelease && g.time > strikeRelease) {
            press("KeyQ", false);
            strikeRelease = 0;
          }
          if (
            g.time > nextConductor &&
            p.conductorCooldown === 0 &&
            !g.preparedAbility
          ) {
            press("KeyE", true);
            conductorRelease = g.time + 0.08;
            nextConductor = g.time + LIGHTNING_CONFIG.conductor.cooldown + 0.4;
          }
          if (conductorRelease && g.time > conductorRelease) {
            press("KeyE", false);
            conductorRelease = 0;
          }
          press("KeyR", p.ultimateCharge >= 100);
        } else {
          for (const code of [...held]) press(code, false);
        }
        await wait(16);
      }
      for (const code of [...held]) press(code, false);
      pointer("pointerup", 0);
      check(
        "Input-only expedition reaches final victory",
        g.mode === "won",
        JSON.stringify({ time: g.time, hp: g.player.hp, stats: g.stats }),
      );
      check("Both earned intermissions were continued", intermissions === 2);
      check(
        "Full chosen build survives into victory",
        g.inventory.equipped.includes("ground-loop") &&
          g.inventory.equipped.includes("echo"),
      );
      check(
        "All final enemies are defeated",
        g.enemies.every((e) => e.hp <= 0) && g.wave.remaining === 0,
      );
      const report = {
        snapshot: api.snapshot(),
        performance: api.performance(),
      };
      document.getElementById("play-again").click();
      await advance(0.02);
      park();
      finish(null, report);
    } catch (error) {
      for (const code of [...held]) press(code, false);
      pointer("pointerup", 0);
      park();
      finish(error, { snapshot: api.snapshot() });
    }
  };
  function stagePopulation(stress = false) {
    api.start();
    const g = api.game,
      p = g.player;
    g._beginWave(3);
    g._waveQueue = [];
    g.wave.entries = [];
    g.enemies = [];
    for (let i = 0; i < 14; i++) {
      const angle = (i / 14) * Math.PI * 2,
        e = g._makeEnemy(
          i % 4 === 0 ? "spreadleg" : "snipcart",
          Math.sin(angle) * 12,
          Math.cos(angle) * 12,
          0.3 + i * 0.08,
        );
      e.id = "qa-worker-" + i;
      e.active = true;
      e.state = "approach";
      g.enemies.push(e);
    }
    const boss = g._makeEnemy("pruner", 0, -24, 0.8);
    boss.id = "qa-boss";
    boss.active = true;
    boss.state = "approach";
    g.enemies.push(boss);
    Object.assign(p, {
      x: 0,
      z: 0,
      y: groundHeight(0, 0) + p.radius,
      vx: 0,
      vy: 0,
      vz: 0,
      shear: 1,
      brace: 1,
      grounded: true,
    });
    g.inventory.acquired = ["ground-loop", "echo"];
    g.inventory.equipped = ["ground-loop", "echo"];
    g.companion = {
      id: "qa-companion",
      active: true,
      enabled: true,
      x: 2,
      y: groundHeight(2, 2),
      z: 2,
      yaw: 0,
      cooldown: 0,
      flash: 0,
    };
    g.conductors = [
      {
        id: "qa-conductor-1",
        x: -3,
        y: groundHeight(-3, -3),
        z: -3,
        cooldown: 0,
        flash: 0,
      },
      {
        id: "qa-conductor-2",
        x: 3,
        y: groundHeight(3, -3),
        z: -3,
        cooldown: 0.2,
        flash: 0,
      },
    ];
    if (stress) {
      p.hp = p.maxHp = 1e8;
      for (const e of g.enemies) e.hp = e.maxHp = 1e8;
    }
    api.world.resetCamera();
    return g;
  }
  panel.querySelector("#qa-stress").onclick = async () => {
    if (running) return;
    begin("60 second bounded rendered stress fixture");
    try {
      const g = stagePopulation(true);
      await advance(0.1);
      const before = api.performance(),
        start = performance.now();
      let maximumWorkers = 0,
        minimumWorkers = Infinity,
        maximumBosses = 0,
        maxCalls = 0,
        maxTriangles = 0;
      const counters = [];
      pointer("pointerdown", 0);
      key("KeyW");
      while (performance.now() - start < 60000) {
        const elapsed = (performance.now() - start) / 1000;
        results.textContent = `STRESS FIXTURE ${elapsed.toFixed(1)} / 60.0 seconds\n14 durable workers + boss; both modifiers; two conductors; companion.\nNormal requestAnimationFrame rendering; no fast-forward.`;
        const target = g.enemies[Math.floor(elapsed / 3) % 14];
        aimAt({
          x: target.x,
          y: target.y + target.bodyHeight * 0.5,
          z: target.z,
        });
        const p = g.player;
        if (Math.hypot(p.x, p.z) > 10) {
          key("KeyW", "keyup");
          key("KeyS");
        } else if (Math.hypot(p.x, p.z) < 5) {
          key("KeyS", "keyup");
          key("KeyW");
        }
        if (Math.floor(elapsed * 4) % 8 === 0) {
          key("Space");
        } else key("Space", "keyup");
        if (Math.floor(elapsed * 4) % 20 === 0) {
          key("ShiftLeft");
        } else key("ShiftLeft", "keyup");
        if (p.ultimateCharge >= 100) key("KeyR");
        else key("KeyR", "keyup");
        if (Math.floor(elapsed * 4) % 16 === 0) key("KeyQ");
        else key("KeyQ", "keyup");
        const workers = g.enemies.filter(
            (e) => e.hp > 0 && e.kind !== "pruner",
          ).length,
          bosses = g.enemies.filter(
            (e) => e.hp > 0 && e.kind === "pruner",
          ).length;
        maximumWorkers = Math.max(maximumWorkers, workers);
        minimumWorkers = Math.min(minimumWorkers, workers);
        maximumBosses = Math.max(maximumBosses, bosses);
        const perf = api.performance();
        maxCalls = Math.max(maxCalls, perf.drawCalls);
        maxTriangles = Math.max(maxTriangles, perf.triangles);
        counters.push({
          t: elapsed,
          drawCalls: perf.drawCalls,
          triangles: perf.triangles,
          geometries: perf.geometries,
        });
        await wait(100);
      }
      for (const code of ["KeyW", "KeyS", "Space", "ShiftLeft", "KeyQ", "KeyR"])
        key(code, "keyup");
      pointer("pointerup", 0);
      const after = api.performance(),
        samples = after.frameTimes.slice(-(after.frames - before.frames)),
        sorted = [...samples].sort((a, b) => a - b),
        quantile = (q) =>
          sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * q))],
        gl = api.world.renderer.getContext(),
        debug = gl.getExtension("WEBGL_debug_renderer_info");
      const report = {
        durationMs: performance.now() - start,
        viewport: {
          width: innerWidth,
          height: innerHeight,
          dpr: devicePixelRatio,
        },
        userAgent: navigator.userAgent,
        graphics: {
          vendor: gl.getParameter(gl.VENDOR),
          renderer: gl.getParameter(gl.RENDERER),
          unmaskedVendor: debug
            ? gl.getParameter(debug.UNMASKED_VENDOR_WEBGL)
            : null,
          unmaskedRenderer: debug
            ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL)
            : null,
        },
        population: { minimumWorkers, maximumWorkers, maximumBosses },
        frameCount: samples.length,
        frameTimesMs: samples,
        frameSummaryMs: {
          mean: samples.reduce((a, b) => a + b, 0) / samples.length,
          p50: quantile(0.5),
          p95: quantile(0.95),
          p99: quantile(0.99),
          max: Math.max(...samples),
        },
        renderer: {
          maxCalls,
          maxTriangles,
          initialGeometries: before.geometries,
          finalGeometries: after.geometries,
          counters,
        },
        errors: after.errors.slice(before.errors.length),
        events: api.events(),
        fixture:
          "Durable HP and staged equipment/population; normal simulation, real DOM input, real animation-frame rendering.",
      };
      check(
        "Sixty seconds rendered at the worker cap",
        report.durationMs >= 60000 &&
          minimumWorkers === 14 &&
          maximumWorkers === 14 &&
          maximumBosses === 1,
      );
      check(
        "Both modifiers, two conductors and companion remain active",
        g.inventory.equipped.length === 2 &&
          g.conductors.length === 2 &&
          g.companion?.enabled,
      );
      check("No browser errors during stress", report.errors.length === 0);
      check(
        "Real frame samples recorded",
        samples.length > 100,
        JSON.stringify(report.frameSummaryMs),
      );
      results.textContent +=
        "\nGRAPHICS " +
        JSON.stringify(report.graphics) +
        "\nVIEWPORT " +
        JSON.stringify(report.viewport) +
        "\nRENDERER " +
        JSON.stringify({
          maxCalls,
          maxTriangles,
          initialGeometries: before.geometries,
          finalGeometries: after.geometries,
        });
      park();
      finish(null, { performance: report });
    } catch (error) {
      api.clearInput();
      park();
      finish(error);
    }
  };
  panel.querySelector("#qa-windup").onclick = () => {
    if (running) return;
    const g = stagePopulation();
    g.player.z = 8;
    for (const [i, enemy] of g.enemies.entries()) {
      enemy.x = (i % 2 ? 1 : -1) * 4;
      enemy.z = -4 - Math.floor(i / 2) * 4;
      enemy.y = groundHeight(enemy.x, enemy.z);
      enemy.yaw = Math.PI;
      enemy.state = "windup";
      enemy.stateTime = ENEMY_CONFIG[enemy.kind].windup * 0.5;
      enemy.phase = 0.5;
      enemy.attackStyle = "sweep";
    }
    g._updateEnemies(0);
    park();
    api.world.update(g, 0);
    panel.open = false;
    results.textContent =
      "VISUAL FIXTURE: staged worker/boss attack warnings. Low and tall attacks must be visually distinct.";
  };
  panel.querySelector("#qa-boss").onclick = () => {
    if (running) return;
    const g = stagePopulation();
    g.player.z = -13;
    g.player.y = groundHeight(0, -13) + g.player.radius;
    park();
    api.world.update(g, 0);
    panel.open = false;
    results.textContent =
      "VISUAL FIXTURE: full final-wave population, equipment and conductors staged.";
  };
  panel.querySelector("#qa-hero").onclick = () => {
    if (running) return;
    const g = stagePopulation();
    g.player.y += 3;
    g.player.grounded = false;
    g.player.vy = 0;
    api.world.yaw = Math.PI;
    api.world.pitch = 0.12;
    api.world.cameraReady = false;
    park();
    api.world.update(g, 0);
    panel.open = false;
    results.textContent =
      "VISUAL FIXTURE: airborne caster and lightning equipment. State is staged.";
  };
}
