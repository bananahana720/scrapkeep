import { groundHeight, ENEMY_CONFIG } from "../src/orchard/simulation.js";

export function installOrchardQA(api) {
  const panel = document.createElement("details");
  panel.id = "orchard-qa";
  panel.style.cssText =
    "position:fixed;right:12px;top:65px;z-index:30;max-width:420px;max-height:65vh;overflow:auto;color:#efe7d0;background:#163d35ed;border:1px solid #b1caab;padding:8px;font:10px monospace;pointer-events:auto";
  panel.innerHTML =
    '<summary>Build verification</summary><button id="qa-controls">Run DOM input replay</button><button id="qa-fixtures">Run state fixtures</button><button id="qa-expedition">Run input expedition</button><button id="qa-windup">View cut fixture</button><button id="qa-boss">View boss fixture</button><button id="qa-hero">View enclosed pilot</button><pre id="qa-results">Ready. Fixtures are labelled; no human playthrough claim.</pre>';
  document.body.appendChild(panel);
  const results = panel.querySelector("#qa-results"),
    records = [];
  let running = false;
  const key = (code, type = "keydown") =>
    window.dispatchEvent(new KeyboardEvent(type, { code, bubbles: true }));
  const tap = (code) => {
    key(code);
    key(code, "keyup");
  };
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const until = async (predicate, limit = 12000) => {
    const end = performance.now() + limit;
    while (!predicate()) {
      if (performance.now() > end)
        throw new Error("Timed out waiting for game condition");
      await wait(16);
    }
  };
  const advance = async (seconds) => {
    const target = api.game.time + seconds;
    await until(
      () => api.game.time >= target || ["won", "lost"].includes(api.game.mode),
    );
  };
  const check = (name, pass, details = "") => {
    records.push({ name, pass: !!pass, details });
    results.textContent = records
      .map(
        (r) =>
          (r.pass ? "PASS " : "FAIL ") +
          r.name +
          (r.details ? " · " + r.details : ""),
      )
      .join("\n");
    if (!pass) throw new Error(name);
  };
  const begin = () => {
    records.length = 0;
    delete panel.dataset.result;
    panel.dataset.records = "[]";
    running = true;
  };
  const finish = (mode, error) => {
    running = false;
    panel.dataset.result = error ? "fail" : "pass";
    panel.dataset.kind = mode;
    panel.dataset.records = JSON.stringify(records);
    if (error) results.textContent += "\nERROR " + error.message;
  };
  panel.querySelector("#qa-controls").onclick = async () => {
    if (running) return;
    begin();
    try {
      api.start();
      document.exitPointerLock?.();
      await advance(0.08);
      check(
        "UI starts a fresh playing run",
        api.game.mode === "playing" && api.game.stats.shots === 0,
      );
      const startZ = api.game.player.z;
      key("KeyW");
      await advance(0.8);
      key("KeyW", "keyup");
      check(
        "W rolls forward relative to initial chase camera",
        api.game.player.z < startZ - 3 && Math.abs(api.game.player.x) < 0.5,
      );
      key("ShiftLeft");
      await advance(0.2);
      key("ShiftLeft", "keyup");
      check(
        "brake sheds momentum",
        Math.hypot(api.game.player.vx, api.game.player.vz) < 1,
      );
      key("KeyF");
      await advance(1.14);
      check("held fire reaches full charge", api.game.player.charge > 0.99);
      key("KeyF", "keyup");
      await advance(0.05);
      check(
        "release fires one pulse",
        api.game.stats.shots === 1 && api.game.player.charge === 0,
      );
      tap("Space");
      await advance(0.06);
      check(
        "ram key produces a short high-speed burst",
        api.game.player.dashTime > 0 &&
          Math.hypot(api.game.player.vx, api.game.player.vz) > 12,
      );
      tap("KeyP");
      await until(() => api.game.mode === "paused");
      const frozen = api.game.time;
      await wait(200);
      check(
        "pause freezes simulation and displays resume",
        api.game.time === frozen &&
          !document.getElementById("overlay").hidden &&
          !!document.getElementById("resume"),
      );
      document.getElementById("resume").click();
      document.exitPointerLock?.();
      await advance(0.08);
      check("resume continues the same run", api.game.time > frozen);
      tap("KeyR");
      document.exitPointerLock?.();
      await advance(0.04);
      check(
        "restart resets position, growth and combat stats",
        api.game.stats.shots === 0 &&
          api.game.player.scrap === 0 &&
          api.game.player.radius === 1 &&
          Math.abs(api.game.player.z - 21) < 0.1,
      );
      key("ArrowRight");
      await advance(0.42);
      key("ArrowRight", "keyup");
      const x = api.game.player.x,
        z = api.game.player.z,
        yaw = api.world.yaw;
      key("KeyW");
      await advance(0.7);
      key("KeyW", "keyup");
      check(
        "right aim turns right and W follows the new camera",
        yaw > 0.5 && api.game.player.x > x + 1 && api.game.player.z < z - 1,
      );
      tap("KeyP");
      await wait(50);
      check(
        "input replay ends in a recoverable paused state",
        api.game.mode === "paused",
      );
      finish("DOM input replay", null);
    } catch (error) {
      finish("DOM input replay", error);
    }
  };
  panel.querySelector("#qa-fixtures").onclick = async () => {
    if (running) return;
    begin();
    try {
      api.start();
      document.exitPointerLock?.();
      await advance(0.02);
      api.game.pause();
      const g = api.game,
        p = g.player;
      g.pickups = [
        {
          id: "fixture-shear",
          x: p.x,
          y: 0,
          z: p.z,
          kind: "shear",
          collected: false,
        },
        {
          id: "fixture-brace",
          x: p.x,
          y: 0,
          z: p.z,
          kind: "brace",
          collected: false,
        },
      ];
      g.resume();
      await advance(0.03);
      check(
        "fixture pickups apply both mechanism effects",
        p.shear === 1 && p.brace === 1 && p.radius > 1,
      );
      tap("KeyE");
      await advance(0.04);
      check(
        "collected linkage enables visible autonomous companion",
        !!g.companion?.active && api.world.companion.visible,
      );
      g.pause();
      p.radius = 1.65;
      p.y = 1.65;
      api.world.update(g, 0);
      const cabin = api.world.hero.userData.cockpit;
      check(
        "largest hero has a cockpit inside the rolling body",
        cabin.position.y < 0 && api.world.hero.scale.x === 1.65,
      );
      g.mode = "won";
      await wait(80);
      check(
        "victory renders restart",
        !!document.getElementById("play-again") &&
          !document.getElementById("overlay").hidden,
      );
      document.getElementById("guide").click();
      document.getElementById("close-guide").click();
      check(
        "guide returns to victory results",
        !!document.getElementById("play-again") &&
          !document.getElementById("overlay").hidden,
      );
      document.getElementById("play-again").click();
      document.exitPointerLock?.();
      await advance(0.03);
      check(
        "victory restart clears companion and parts",
        !g.companion && g.player.shear === 0 && g.player.brace === 0,
      );
      g.mode = "lost";
      await wait(80);
      document.getElementById("guide").click();
      document.getElementById("close-guide").click();
      check(
        "guide returns to defeat results",
        !!document.getElementById("play-again") &&
          !document.getElementById("overlay").hidden,
      );
      finish("State fixtures, not earned progression", null);
    } catch (error) {
      finish("State fixtures, not earned progression", error);
    }
  };
  function stage(kind) {
    if (running) return;
    api.start();
    document.exitPointerLock?.();
    const g = api.game,
      e = g.enemies.find((e) => e.kind === kind),
      p = g.player;
    const x = kind === "pruner" ? 5.8 : 0,
      z = kind === "pruner" ? -21.5 : 13.1;
    Object.assign(p, {
      x,
      z,
      y: groundHeight(x, z) + 1.15,
      radius: 1.15,
      vx: 0,
      vz: 0,
      shear: 1,
      brace: 1,
    });
    Object.assign(e, {
      active: true,
      state: "windup",
      phase: 0.75,
      stateTime: ENEMY_CONFIG[kind].windup * 0.75,
      yaw: Math.PI,
      attackId: 2,
      attackStyle: "sweep",
    });
    api.world.yaw = kind === "pruner" ? -0.42 : -0.55;
    api.world.cameraReady = false;
    g._updateEnemies(0);
    g.pause();
    api.world.update(g, 0);
    results.textContent =
      "VISUAL FIXTURE: " +
      kind +
      " windup. Positions/state are staged, not an earned combat frame.";
    panel.open = false;
  }
  panel.querySelector("#qa-windup").onclick = () => stage("snipcart");
  panel.querySelector("#qa-boss").onclick = () => stage("pruner");
  panel.querySelector("#qa-hero").onclick = () => {
    api.start();
    document.exitPointerLock?.();
    api.game.pause();
    api.world.yaw = Math.PI;
    api.world.pitch = 0.14;
    api.world.cameraReady = false;
    api.world.update(api.game, 0);
    panel.open = false;
    results.textContent =
      "VISUAL FIXTURE: front view of enclosed pilot. Camera staged for inspection.";
  };
  panel.querySelector("#qa-expedition").onclick = async () => {
    if (running) return;
    begin();
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
    const aimAt = (target) => {
      const p = api.game.player,
        desired = Math.atan2(target.x - p.x, p.z - target.z);
      const delta = Math.atan2(
        Math.sin(desired - api.world.yaw),
        Math.cos(desired - api.world.yaw),
      );
      const canvas = document.getElementById("orchard-world");
      canvas.dispatchEvent(
        new PointerEvent("pointerdown", {
          pointerType: "mouse",
          button: 2,
          clientX: 0,
          clientY: 0,
          bubbles: true,
        }),
      );
      window.dispatchEvent(
        new PointerEvent("pointermove", {
          pointerType: "mouse",
          clientX: delta / 0.003,
          clientY: 0,
          bubbles: true,
        }),
      );
      window.dispatchEvent(
        new PointerEvent("pointerup", {
          pointerType: "mouse",
          button: 2,
          bubbles: true,
        }),
      );
    };
    try {
      api.start();
      document.exitPointerLock?.();
      await advance(0.02);
      const g = api.game;
      let target = g.enemies[0],
        collecting = null,
        nextFire = 0,
        completed = 0;
      const deadline = performance.now() + 180000;
      while (g.mode === "playing" && g.time < 160) {
        if (performance.now() > deadline)
          throw new Error("Input expedition exceeded real-time limit");
        if (target.hp <= 0 && !collecting) {
          completed++;
          check(
            "input combat dismantled " + target.kind,
            true,
            "HP " + Math.round(g.player.hp) + ", t=" + g.time.toFixed(1),
          );
          collecting = g.pickups.find(
            (p) =>
              !p.collected &&
              p.kind === (target.kind === "spreadleg" ? "brace" : "shear") &&
              Math.hypot(p.x - target.x, p.z - target.z) < 1,
          );
        }
        if (collecting?.collected) {
          if (g.player.shear) tap("KeyE");
          collecting = null;
          target = g.enemies.find((e) => e.hp > 0);
          if (!target) break;
        }
        const p = g.player,
          goal = collecting || target,
          d = Math.hypot(goal.x - p.x, goal.z - p.z);
        aimAt(goal);
        const combat = !collecting && d < 15;
        press("KeyW", collecting ? d > p.radius * 0.7 : d > 10);
        press("KeyS", combat && d < 6);
        press("KeyD", combat && d <= 10 && d >= 6);
        press("ShiftLeft", !!collecting && d < 2.8);
        if (combat && g.time >= nextFire) {
          press("KeyF", true);
          if (p.charge >= 0.999) {
            press("KeyF", false);
            nextFire = g.time + 0.08;
          }
        } else press("KeyF", false);
        await wait(16);
      }
      for (const code of [...held]) press(code, false);
      check(
        "input-only expedition reaches victory",
        g.mode === "won",
        JSON.stringify({ time: g.time, hp: g.player.hp, stats: g.stats }),
      );
      check(
        "earned both mechanisms and deployed companion",
        g.player.shear > 0 && g.player.brace > 0 && g.companion?.active,
      );
      check(
        "all worker types and giant arm dismantled",
        g.enemies.every((e) => e.hp <= 0),
      );
      panel.dataset.snapshot = JSON.stringify(g.snapshot());
      panel.dataset.performance = JSON.stringify(api.performance());
      finish("DOM input expedition; no state fixtures", null);
    } catch (error) {
      for (const code of [...held]) press(code, false);
      finish("DOM input expedition; no state fixtures", error);
    }
  };
}
