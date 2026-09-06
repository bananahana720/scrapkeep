import {
  HEROES,
  TOTAL_WAVES,
  createProfile,
  masteryFor,
  dailySeed,
  decodeChallenge,
  challengeUrl,
} from "./campaign.js";
import { heroPortrait } from "./heroes.js";
import { createProgressStore } from "./progress-store.js";

export const escapeHtml = (text) =>
  String(text).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const number = (n) => Math.floor(n).toLocaleString("en-US");
const clock = (n) =>
  `${Math.floor(n / 60)}:${String(Math.floor(n % 60)).padStart(2, "0")}`;

export class Collection {
  constructor(game, hooks) {
    this.game = game;
    this.hooks = hooks;
    this.storageKey = new URLSearchParams(location.search).has("qa")
      ? "scrapkeep.qa.collection.v1"
      : "scrapkeep.collection.v1";
    this.profile = createProfile();
    this.storageAvailable = true;
    let storage;
    try {
      storage = localStorage;
    } catch {}
    this.progress = createProgressStore(storage, this.storageKey);
    Object.assign(this, this.progress.read());
    window.addEventListener("storage", (e) => {
      if (
        e.key === this.storageKey ||
        e.key?.startsWith(this.storageKey + ".run.")
      ) {
        Object.assign(this, this.progress.read(this.profile));
        if (this.game.mode === "menu") this.hooks.redraw();
      }
    });
    this.challenge = decodeChallenge(
      new URLSearchParams(location.hash.slice(1)).get("challenge"),
    );
    this.daily = false;
    this.runId = null;
    this.lastAward = null;
    this.config = {
      brand: "Scrapkeep",
      storeUrl: null,
      captureEnabled: false,
      localOnly: true,
    };
    this.dialog = document.createElement("dialog");
    this.dialog.className = "collection-dialog";
    this.dialog.setAttribute("aria-labelledby", "collection-title");
    document.body.appendChild(this.dialog);
    this.dialog.addEventListener("close", () => this.returnFocus?.focus());
    this.dialog.addEventListener("click", (e) => {
      if (e.target === this.dialog) this.dialog.close();
    });
    this.configReady = fetch("/api/config", {
      signal: AbortSignal.timeout(8000),
    })
      .then(async (r) => {
        if (r.ok) this.config = await r.json();
      })
      .catch(() => {});
  }
  get open() {
    return this.dialog.open;
  }
  initialClass() {
    return this.challenge?.classId || "scavenger";
  }
  begin(classId) {
    this.finish("abandoned");
    this.runId = crypto.randomUUID();
    this.lastAward = null;
    const seed =
      this.challenge?.seed ??
      (this.daily
        ? dailySeed()
        : crypto.getRandomValues(new Uint32Array(1))[0]);
    this.game.reset(this.challenge?.classId || classId, true, { seed });
  }
  finish(outcome = this.game.mode) {
    if (
      !this.runId ||
      this.lastAward ||
      !["gameover", "victory", "abandoned"].includes(outcome)
    )
      return;
    this.lastAward = this.progress.record(
      {
        id: this.runId,
        classId: this.game.classId,
        seed: this.game.seed,
        score: this.game.score,
        survived: this.game.survived,
        outcome,
      },
      this.profile,
    );
    this.profile = this.lastAward.profile;
    this.storageAvailable = this.lastAward.storageAvailable;
  }
  classLabel(id) {
    const m = masteryFor(this.profile, id);
    return `${m.badge} · ${m.xp} mastery`;
  }
  menuMarkup(id) {
    const hero = HEROES[id],
      m = masteryFor(this.profile, id);
    return `<div class="hero-preview">${heroPortrait(id)}</div><div class="shelf-copy"><span class="eyebrow">MEET YOUR LITTLE HEAVY HITTER</span><h2>${hero.name}<span> / ${hero.title}</span></h2><p>${hero.story}</p><div class="mastery-caption"><span>${m.badge}</span><span>${m.xp}${m.nextXp ? ` / ${m.nextXp}` : ""} MASTERY</span></div><div class="mastery-track"><i style="width:${m.progress * 100}%"></i></div><button class="shelf-link" id="open-collection">YOUR FIELD COLLECTION <span>↗</span></button><small>Play your hero. Bring home the figurine.</small></div>`;
  }
  challengeMarkup() {
    if (this.challenge)
      return `<strong>A FRIEND LEFT YOU A CHALLENGE</strong><span>${HEROES[this.challenge.classId].name} · ${number(this.challenge.targetScore)} points to beat</span><button id="leave-challenge">PLAY A FRESH EXPEDITION</button>`;
    return `<strong>15 WAVES. THREE BOSSES. ONE LITTLE HERO.</strong><span>Master every class. Keep what you earn, even when the core goes dark.</span>`;
  }
  bindMenu(id) {
    document.getElementById("hero-shelf").innerHTML = this.menuMarkup(id);
    document.getElementById("open-collection").onclick = () => this.show(id);
    document.getElementById("expedition-brief").innerHTML =
      this.challengeMarkup();
    const leave = document.getElementById("leave-challenge");
    if (leave)
      leave.onclick = () => {
        this.challenge = null;
        history.replaceState(null, "", location.pathname + location.search);
        this.hooks.redraw();
      };
  }
  resultMarkup() {
    const g = this.game,
      hero = HEROES[g.classId],
      m = masteryFor(this.profile, g.classId),
      won = g.mode === "victory";
    const award = this.lastAward?.awarded || 0;
    const breakdown = g.scoreBreakdown || {};
    return `<section class="dialog gameover-dialog expedition-result"><div class="result-card"><span class="eyebrow">FIELD CARD / ${g.classId.toUpperCase()}</span>${heroPortrait(g.classId)}<h3>${hero.name}</h3><p>${m.badge}</p><div class="mastery-track"><i style="width:${m.progress * 100}%"></i></div><span class="earned">+${award} CLASS MASTERY</span><small>${m.nextXp ? `${m.xp} / ${m.nextXp} to the next title` : "Orchard legend earned"}<br>${m.blueprint ? `${m.blueprint} field card unlocked` : `${Math.max(0, 150 - m.xp)} mastery to unlock the field card`}</small></div><div class="result-details"><span class="eyebrow">${won ? "THE ORCHARD IS SAFE / EXPEDITION COMPLETE" : "CORE OFFLINE / MASTERY KEPT"}</span><h2>${won ? "SMALL HERO.<br>BIG SAVE." : "DUST YOURSELF OFF."}</h2><div class="end-score">${number(g.score)}<span>SALVAGE SCORE · ${clock(g.time)}</span></div><div class="end-stats"><div><strong>${g.survived}/${TOTAL_WAVES}</strong><span>WAVES</span></div><div><strong>${g.kills}</strong><span>TAKEDOWNS</span></div><div><strong>${g.bestStreak || 0}</strong><span>BEST STREAK</span></div></div><p class="score-explanation">${number(breakdown.clears || 0)} wave points · ${number((breakdown.risk || 0) + (breakdown.objectives || 0))} bonus points<br>${this.challenge ? (g.score > this.challenge.targetScore ? "You beat your friend’s score." : `${number(Math.max(0, this.challenge.targetScore - g.score + 1))} more points to beat your friend.`) : "Send a friend this exact yard, hero and score to beat."}</p><div class="mobile-mastery"><strong>+${award} CLASS MASTERY · ${hero.name}</strong><span>${m.badge} · ${m.xp} mastery${m.blueprint ? ` · ${m.blueprint} unlocked` : ` · ${Math.max(0, 150 - m.xp)} to the field card`}</span></div><div class="result-actions"><button class="primary-button" id="restart">${won ? "ANOTHER EXPEDITION" : "ONE MORE ROLL"} ↗</button><button class="secondary-button" id="share-challenge">CHALLENGE A FRIEND ↗</button></div><div id="share-status" class="form-status" role="status"></div><div class="result-product"><span><strong>Make room for ${hero.name}.</strong><small>Your playable hero, as a cute 3D printed figurine.</small></span><button id="result-figurine">MEET THE FIGURINE ↗</button></div><button class="text-button" id="menu-button">CHANGE HERO / VIEW MASTERY</button><small class="storage-note">${this.storageAvailable ? "Mastery saved on this browser. No signup needed." : "Browser storage unavailable. Mastery lasts for this visit only."}</small></div></section>`;
  }
  bindResult() {
    document.getElementById("result-figurine").onclick = () =>
      this.show(this.game.classId, "run-result");
    document.getElementById("share-challenge").onclick = async () => {
      const url = challengeUrl(location.origin + location.pathname, {
        seed: this.game.seed,
        classId: this.game.classId,
        targetScore: this.game.score,
      });
      const status = document.getElementById("share-status");
      try {
        await navigator.clipboard.writeText(url);
        status.textContent =
          "Challenge link copied. Same seed, same hero. Your score is the target.";
      } catch {
        status.innerHTML = `<label for="challenge-url">Copy your challenge link</label><input id="challenge-url" readonly value="${escapeHtml(url)}">`;
        document.getElementById("challenge-url").select();
      }
    };
  }
  async show(id, source = "collection") {
    await this.configReady;
    if (this.game.mode === "playing") this.hooks.pause();
    if (!this.dialog.open) this.returnFocus = document.activeElement;
    const hero = HEROES[id],
      m = masteryFor(this.profile, id);
    this.dialog.innerHTML = `<button class="dialog-close" aria-label="Close collection">×</button><div class="collection-header"><span class="eyebrow">THE SCRAPKEEP FIELD COLLECTION</span><h2 id="collection-title">LITTLE HEROES.<br>ROOM ON YOUR SHELF.</h2><p>The classes you play become the figurines you keep.</p></div><nav class="collection-tabs" aria-label="Choose a figurine">${Object.entries(
      HEROES,
    )
      .map(
        ([key, h]) =>
          `<button data-hero="${key}" aria-pressed="${key === id}">${h.name}<span>${h.title}</span></button>`,
      )
      .join(
        "",
      )}</nav><div class="collection-body"><section class="figurine-display">${heroPortrait(id)}<span class="eyebrow">${hero.title.toUpperCase()} / FIELD EDITION</span><h3>${hero.name}</h3><p>${hero.story}</p><span class="badge-label">${m.badge} · ${m.xp} MASTERY</span><div class="mastery-track"><i style="width:${m.progress * 100}%"></i></div><small>${m.blueprint ? `${m.blueprint} field card collected` : `Field card unlocks at 150 mastery. ${Math.max(0, 150 - m.xp)} to go.`}</small><button class="secondary-button" id="download-card">SAVE FIELD CARD ↓</button><small class="concept-note">Game character concept. Physical finish may differ.</small></section><section class="figurine-capture"><span class="eyebrow">FROM THE YARD TO YOUR DESK</span><h3>Bring ${hero.name} home.</h3><p>Get news about the cute 3D printed ${hero.title.toLowerCase().replace("the ", "")} figurine. Choose email, text, or both.</p>${this.config.storeUrl ? `<a class="primary-button store-link" href="${escapeHtml(this.config.storeUrl)}" target="_blank" rel="noopener noreferrer">EXPLORE THE FIGURINES ↗</a>` : ""}<form id="lead-form"><label for="lead-email">Email <span>optional</span></label><input id="lead-email" name="email" type="email" autocomplete="email" maxlength="254" placeholder="you@example.com"><label class="consent"><input id="consent-email" type="checkbox" name="email-consent"><span id="email-consent-copy"></span></label><label for="lead-phone">Mobile number <span>optional, with country code</span></label><input id="lead-phone" name="phone" type="tel" autocomplete="tel" inputmode="tel" maxlength="20" placeholder="+1 555 123 4567" aria-describedby="phone-hint"><small id="phone-hint">Include + and your country code.</small><label class="consent"><input id="consent-sms" type="checkbox" name="sms-consent"><span id="sms-consent-copy"></span></label><label class="website-trap" aria-hidden="true">Website<input name="website" tabindex="-1" autocomplete="off"></label><button type="submit" class="primary-button" id="lead-submit">KEEP ME IN THE LOOP ↗</button><p id="lead-status" class="form-status" role="status" aria-live="polite"></p><p class="privacy-copy">${this.config.localOnly ? "Local preview: your choice is saved on this server. No email or text is sent." : "Your contact details and hero preference are used for the updates you choose."} All heroes and game rewards stay free to play. No purchase required. ${this.config.privacyUrl ? `<a href="${escapeHtml(this.config.privacyUrl)}" target="_blank" rel="noopener noreferrer">Privacy details</a>` : '<button type="button" id="privacy-details">How your details are stored</button>'}</p></form></section></div>`;
    this.dialog.querySelector(".dialog-close").onclick = () =>
      this.dialog.close();
    this.dialog
      .querySelectorAll("[data-hero]")
      .forEach(
        (button) =>
          (button.onclick = () => this.show(button.dataset.hero, source)),
      );
    const consent = this.config.consentText || {
      email: `Email me ${this.config.brand} figurine news and launch updates.`,
      sms: `I agree to receive marketing texts about ${this.config.brand} figurines. Message frequency varies. Message and data rates may apply. Consent is not a condition of purchase. Reply STOP to opt out when messaging is enabled.`,
    };
    document.getElementById("email-consent-copy").textContent = consent.email;
    document.getElementById("sms-consent-copy").textContent = consent.sms;
    document.getElementById("download-card").onclick = () =>
      this.downloadCard(id);
    const privacy = document.getElementById("privacy-details");
    if (privacy)
      privacy.onclick = () => {
        document.getElementById("lead-status").textContent =
          "The server stores your selected contact channels, consent wording and time, hero interest, and run score. Contact details are not stored in your browser or included in challenge links. In this preview, no messaging service receives them.";
      };
    const form = document.getElementById("lead-form");
    form.addEventListener(
      "invalid",
      (e) => e.target.setAttribute("aria-invalid", "true"),
      true,
    );
    form.addEventListener("input", (e) =>
      e.target.removeAttribute("aria-invalid"),
    );
    form.onsubmit = (e) => this.submit(e, id, source);
    if (!this.config.captureEnabled || !this.config.consentText) {
      document.getElementById("lead-submit").disabled = true;
      document.getElementById("lead-status").textContent =
        "Signups are unavailable right now. You can keep playing and save your field card.";
    }
    if (!this.dialog.open) this.dialog.showModal();
  }
  async submit(event, id, source) {
    event.preventDefault();
    const form = event.currentTarget,
      status = document.getElementById("lead-status"),
      button = document.getElementById("lead-submit");
    const email = form.elements.email.value.trim(),
      phone = form.elements.phone.value.replace(/[\s()-]/g, "");
    const consent = {
      email: document.getElementById("consent-email").checked,
      sms: document.getElementById("consent-sms").checked,
    };
    if ((!email || !consent.email) && (!phone || !consent.sms)) {
      status.textContent =
        "Enter a contact detail and tick its permission box to choose your updates.";
      return;
    }
    if (
      (email && !consent.email) ||
      (phone && !consent.sms) ||
      (consent.email && !email) ||
      (consent.sms && !phone)
    ) {
      status.textContent =
        "Each contact detail needs its own permission. Clear a detail if you do not want updates there.";
      return;
    }
    if (phone && !/^\+[1-9]\d{7,14}$/.test(phone)) {
      status.textContent =
        "Use a mobile number with + and country code, such as +15551234567.";
      document
        .getElementById("lead-phone")
        .setAttribute("aria-invalid", "true");
      return;
    }
    button.disabled = true;
    status.textContent = "Saving your preferences…";
    try {
      const response = await fetch("/api/leads", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        signal: AbortSignal.timeout(12000),
        body: JSON.stringify({
          email: email || undefined,
          phone: phone || undefined,
          consent,
          heroClass: id,
          source,
          run: {
            seed: this.game.seed,
            score: this.game.score,
            wave: this.game.survived,
            outcome: ["gameover", "victory"].includes(this.game.mode)
              ? this.game.mode
              : "in-progress",
          },
          website: form.elements.website.value,
        }),
      });
      const data = await response.json();
      if (!response.ok || data.ok !== true)
        throw new Error(
          data.error ||
            "Your preferences could not be saved. Please try again.",
        );
      form.reset();
      status.textContent = this.config.localOnly
        ? `Saved. Your interest in ${HEROES[id].name} is on this server. No messages have been sent.`
        : `Saved. You chose updates about ${HEROES[id].name}.`;
    } catch (error) {
      status.textContent =
        error.name === "TimeoutError"
          ? "Saving took too long. Please retry; a repeated request will not add a duplicate."
          : error instanceof TypeError || error instanceof SyntaxError
            ? "The signup service is unavailable. Your details have not been confirmed saved. Please try again."
            : error.message;
    } finally {
      button.disabled = false;
    }
  }
  downloadCard(id) {
    const hero = HEROES[id],
      m = masteryFor(this.profile, id);
    const art = heroPortrait(id).replace(
      /<svg[^>]*>/,
      '<svg x="50" y="80" width="380" height="380" viewBox="0 0 268 240">',
    );
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="480" height="640" viewBox="0 0 480 640"><rect width="480" height="640" rx="28" fill="#102a30"/><rect x="18" y="18" width="444" height="604" rx="20" fill="none" stroke="#86ae9c"/><text x="240" y="60" text-anchor="middle" fill="#a4ead1" font-family="monospace" font-size="15">SCRAPKEEP / FIELD COLLECTION</text>${art}<text x="240" y="478" text-anchor="middle" fill="#ffab72" font-family="sans-serif" font-weight="bold" font-size="48">${hero.name}</text><text x="240" y="513" text-anchor="middle" fill="#e9e8dc" font-family="sans-serif" font-size="19">${hero.title}</text><text x="240" y="552" text-anchor="middle" fill="#a4ead1" font-family="monospace" font-size="15">${m.badge} · ${m.xp} mastery</text><text x="240" y="588" text-anchor="middle" fill="#b6c6be" font-family="sans-serif" font-size="13">${m.blueprint ? escapeHtml(m.blueprint) : "Recruit field card"}</text></svg>`;
    const url = URL.createObjectURL(new Blob([svg], { type: "image/svg+xml" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `scrapkeep-${hero.name.toLowerCase()}-field-card.svg`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}
