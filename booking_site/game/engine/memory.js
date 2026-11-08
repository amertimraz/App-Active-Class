// memory.js — «ذاكرة الكروت»: كروت مقلوبة، نص منها سؤال ونصها إجابته الصح.
// اقلب كارتين وطابقهم. الصفحة بتحسب النقاط والوقت، والساحة بترسم وتحرّك.
import { skyTexture } from './art.js';
import { cardTexture } from './characters.js';
import { boot, setupScene, arText, fitText, fontsReady } from './engine.js';

const W = 480, H = 520;
const CW = 140, CH = 108;

class MemoryScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    skyTexture(this, 'msky2', W, H, '#6D28D9', '#F472B6');
    this.add.image(0, 0, 'msky2').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    if (!this.reduceMotion) {
      this.add.particles(0, 0, 'p_dot', {
        x: { min: 0, max: W }, y: H + 10, speedY: { min: -40, max: -90 }, speedX: { min: -12, max: 12 },
        scale: { min: 0.4, max: 1.4 }, alpha: { start: 0.55, end: 0 }, lifespan: 6000, frequency: 260, tint: 0xffffff,
      }).setDepth(-9);
    }
    cardTexture(this, 'card_back', 'back'); cardTexture(this, 'card_q', 'q'); cardTexture(this, 'card_a', 'a');
    this.cards = [];
    this.open = [];
    this.locked = true;
    data.onReady(this);
  }

  start(pairs, handlers) {
    this.clear();
    this.h = handlers;
    const list = [];
    pairs.forEach((p, i) => {
      list.push({ pair: i, kind: 'q', text: p.q });
      list.push({ pair: i, kind: 'a', text: p.a });
    });
    Phaser.Utils.Array.Shuffle(list);
    const cols = 3, rows = Math.ceil(list.length / cols);
    const gapX = 16, gapY = 14;
    const totalH = rows * CH + (rows - 1) * gapY;
    const x0 = (W - (cols * CW + (cols - 1) * gapX)) / 2 + CW / 2;
    const y0 = (H - totalH) / 2 + CH / 2;
    list.forEach((c, idx) => {
      const col = idx % cols, row = Math.floor(idx / cols);
      const x = x0 + col * (CW + gapX), y = y0 + row * (CH + gapY);
      const sc = CW / 300; // الـtexture 300px (150 منطقي × دقة 2)
      const back = this.add.image(0, 0, 'card_back').setScale(sc);
      const face = this.add.image(0, 0, c.kind === 'q' ? 'card_q' : 'card_a').setScale(sc).setVisible(false);
      const txt = arText(this, 0, 2, c.text, 20, '#14172B', { width: 108 }).setVisible(false);
      fitText(txt, 108, 74, 20, 10);
      const box = this.add.container(x, y, [back, face, txt]).setDepth(5).setSize(CW, CH);
      box.setInteractive();
      const card = { box, back, face, txt, pair: c.pair, kind: c.kind, up: false, done: false };
      box.on('pointerdown', () => this.flip(card));
      this.cards.push(card);
      // دخول متتالي
      box.setScale(0).setAlpha(0);
      this.tweens.add({ targets: box, scale: 1, alpha: 1, duration: this.reduceMotion ? 1 : 300, delay: this.reduceMotion ? 0 : idx * 45, ease: 'Back.easeOut' });
    });
    this.time.delayedCall(this.reduceMotion ? 0 : list.length * 45 + 300, () => { this.locked = false; });
  }

  turn(card, up, cb) {
    const dur = this.reduceMotion ? 1 : 110;
    this.tweens.add({
      targets: card.box, scaleX: 0, duration: dur, ease: 'Sine.easeIn',
      onComplete: () => {
        card.up = up;
        card.back.setVisible(!up); card.face.setVisible(up); card.txt.setVisible(up);
        this.tweens.add({ targets: card.box, scaleX: 1, duration: dur, ease: 'Sine.easeOut', onComplete: cb });
      },
    });
  }

  flip(card) {
    if (this.locked || card.up || card.done || this.open.length >= 2) return;
    this.open.push(card);
    this.turn(card, true, () => {
      if (this.open.length < 2 || this.open.some((c) => !c.up)) return;
      this.judge();
    });
  }

  judge() {
    const [a, b] = this.open;
    if (a.pair === b.pair && a.kind !== b.kind) {
      a.done = b.done = true;
      this.open = [];
      [a, b].forEach((c) => {
        c.face.setTint(0xb7f7d0);
        this.tweens.add({ targets: c.box, scale: 1.1, duration: 140, yoyo: true });
        if (!this.reduceMotion) {
          this.add.particles(c.box.x, c.box.y, 'p_star', {
            speed: { min: 80, max: 220 }, scale: { start: 0.7, end: 0 }, lifespan: 600,
            tint: [0xffd15c, 0xffffff, 0x34d399], emitting: false,
          }).setDepth(20).explode(7);
        }
      });
      this.h.onMatch && this.h.onMatch(a.pair);
      if (this.cards.every((c) => c.done)) this.h.onComplete && this.h.onComplete();
    } else {
      this.locked = true;
      [a, b].forEach((c) => {
        c.face.setTint(0xffc2cc);
        if (!this.reduceMotion) this.tweens.add({ targets: c.box, x: c.box.x + 6, duration: 55, yoyo: true, repeat: 3 });
      });
      this.h.onMiss && this.h.onMiss();
      this.time.delayedCall(this.reduceMotion ? 300 : 800, () => {
        this.open = [];
        let left = 2;
        [a, b].forEach((c) => this.turn(c, false, () => {
          c.face.clearTint();
          if (--left === 0) this.locked = false;
        }));
      });
    }
  }

  /** الوقت خلص: قفل اللعب وقلب الكروت اللي لسه مقفولة عشان يشوف الإجابات */
  timeUp() {
    this.locked = true;
    this.cards.filter((c) => !c.done && !c.up).forEach((c, i) => {
      this.time.delayedCall(i * 60, () => { this.turn(c, true, () => c.face.setTint(0xfff1b0)); });
    });
  }

  clear() {
    this.tweens.killAll();
    this.cards.forEach((c) => c.box.destroy());
    this.children.list.filter((o) => o.depth >= 20).forEach((o) => o.destroy());
    this.cards = []; this.open = [];
  }
}

export async function createMemoryStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, MemoryScene);
  return {
    start: (pairs, handlers) => scene.start(pairs, handlers),
    timeUp: () => scene.timeUp(),
    lock: () => { scene.locked = true; },
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
