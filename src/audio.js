export class AudioEngine {
  constructor() {
    this.ctx = null;
    this.muted = false;
    this.lastShot = 0;
    this.step = 0;
    this.nextNote = 0;
  }
  init() {
    if (!this.ctx) {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.26;
      this.master.connect(this.ctx.destination);
    }
    if (this.ctx.state === "suspended") this.ctx.resume();
  }
  toggle() {
    this.muted = !this.muted;
    if (this.master)
      this.master.gain.setTargetAtTime(
        this.muted ? 0 : 0.26,
        this.ctx.currentTime,
        0.06,
      );
    return this.muted;
  }
  note(freq, duration = 0.1, type = "sine", volume = 0.2, delay = 0, slide) {
    if (!this.ctx || this.muted) return;
    const now = this.ctx.currentTime + delay,
      o = this.ctx.createOscillator(),
      g = this.ctx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, now);
    if (slide) o.frequency.exponentialRampToValueAtTime(slide, now + duration);
    g.gain.setValueAtTime(0, now);
    g.gain.linearRampToValueAtTime(volume, now + 0.008);
    g.gain.exponentialRampToValueAtTime(0.001, now + duration);
    o.connect(g);
    g.connect(this.master);
    o.start(now);
    o.stop(now + duration + 0.02);
  }
  event(e) {
    if (!this.ctx) return;
    if (e.type === "collect") {
      const f = 330 * Math.pow(1.122, Math.min(e.combo, 12));
      this.note(f, 0.13, "sine", 0.35);
      this.note(f * 1.5, 0.2, "triangle", 0.12, 0.045);
    }
    if (e.type === "shot" && this.ctx.currentTime - this.lastShot > 0.065) {
      this.lastShot = this.ctx.currentTime;
      this.note(e.kind === "pipe" ? 140 : 600, 0.05, "triangle", 0.09, 0, 80);
    }
    if (e.type === "kill") {
      this.note(160, 0.1, "triangle", 0.22, 0, 65);
      this.note(650, 0.07, "sine", 0.1);
    }
    if (e.type === "dash") this.note(110, 0.2, "sawtooth", 0.12, 0, 600);
    if (e.type === "ability") {
      [220, 330, 440, 660].forEach((n, i) =>
        this.note(n, 0.3, "triangle", 0.25, i * 0.045),
      );
    }
    if (e.type === "wave") {
      this.note(130, 0.3, "triangle", 0.3);
      this.note(195, 0.4, "triangle", 0.3, 0.13);
    }
    if (e.type === "clear" || e.type === "level") {
      [330, 440, 550, 660].forEach((n, i) =>
        this.note(n, 0.35, "sine", 0.3, i * 0.08),
      );
    }
    if (e.type === "breach") {
      this.note(110, 0.3, "sawtooth", 0.25, 0, 40);
    }
    if (e.type === "gameover") {
      [220, 196, 165, 110].forEach((n, i) =>
        this.note(n, 0.45, "triangle", 0.3, i * 0.13),
      );
    }
  }
  tick(playing) {
    if (!playing || !this.ctx || this.muted) return;
    const now = this.ctx.currentTime;
    if (now < this.nextNote) return;
    this.nextNote = now + 0.24;
    const bass = [
      55, 55, 0, 82.41, 55, 0, 73.42, 0, 65.41, 65.41, 0, 98, 65.41, 0, 82.41,
      0,
    ];
    const n = bass[this.step % 16];
    if (n) this.note(n, 0.19, "triangle", 0.12);
    if (this.step % 4 === 0) this.note(100, 0.12, "sine", 0.22, 0, 35);
    if (this.step % 4 === 2) this.note(900, 0.025, "triangle", 0.035, 0, 300);
    if (this.step % 8 === 3)
      this.note(
        [440, 523.25, 659.25, 587.33][Math.floor(this.step / 8) % 4],
        0.35,
        "sine",
        0.07,
      );
    this.step++;
  }
}
