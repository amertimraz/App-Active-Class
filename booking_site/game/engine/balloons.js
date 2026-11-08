// balloons.js — لعبة «فرقع البالونة» بمحرك Phaser: سما كرتونية بشمس مبتسمة
// وغيم وتلال، بالونات مضيئة بتتمايل، فرقعة بجسيمات (كونفيتي ونجوم وقصاصات).
import {
  skyTexture, sunTexture, cloudTexture, hillsTexture, treesTexture,
  balloonTexture, badgeTexture, BALLOON_W, BALLOON_H,
} from './art.js';
import { boot, setupScene, arText, fitText, fontsReady, BALLOON_COLORS } from './engine.js';

const W = 480, H = 380;

class BalloonScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.items = [];
    this.locked = false;
    this.buildBackdrop();
    badgeTexture(this, 'badge_ok', true);
    badgeTexture(this, 'badge_no', false);
    BALLOON_COLORS.forEach((c, i) => balloonTexture(this, `bal${i}`, c));
    data.onReady(this);
  }

  buildBackdrop() {
    skyTexture(this, 'sky', W, H);
    this.add.image(0, 0, 'sky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    sunTexture(this);
    const sun = this.add.image(W - 62, 58, 'sun').setScale(.5).setDepth(-9);
    if (!this.reduceMotion) this.tweens.add({ targets: sun, angle: 360, duration: 60000, repeat: -1 });
    [['c1', 130, 56, 1, 70, 40], ['c2', 110, 48, 2, 340, 78], ['c3', 150, 62, 3, 190, 150]].forEach(([k, w, h, seed, x, y], i) => {
      cloudTexture(this, k, w, h, seed);
      const c = this.add.image(x, y, k).setScale(.5).setAlpha(.92).setDepth(-8);
      if (!this.reduceMotion) {
        this.tweens.add({ targets: c, x: x + (i % 2 ? -1 : 1) * 46, duration: 9000 + i * 2500, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
      }
    });
    hillsTexture(this, 'hill_far', W, 120, '#8FE3B1', 18, 1, .6);
    hillsTexture(this, 'hill_near', W, 110, '#3CC47C', 14, 2, 2);
    treesTexture(this, 'trees', W, 70);
    this.add.image(0, H - 118, 'hill_far').setOrigin(0).setScale(.5).setDepth(-7).setDisplaySize(W, 120);
    this.add.image(0, H - 100, 'hill_near').setOrigin(0).setScale(.5).setDepth(-6).setDisplaySize(W, 110);
    this.add.image(0, H - 92, 'trees').setOrigin(0).setScale(.5).setDepth(-5).setDisplaySize(W, 70);
  }

  /** يعرض البالونات لسؤال جديد. options: [{text}] */
  show(options, onPick) {
    this.clear();
    this.locked = false;
    this.onPick = onPick;
    const n = options.length;
    const cols = n > 4 ? 3 : 2;
    const rows = Math.ceil(n / cols);
    const cellW = W / cols, cellH = (H - 24) / rows;
    const s = Math.min(cellW / 142, cellH / 190, 1.08);

    options.forEach((o, i) => {
      const col = i % cols, row = Math.floor(i / cols);
      const stagger = (row % 2 ? 1 : -1) * 8 * (col % 2 ? -1 : 1);
      const x = cellW * (col + .5) + stagger;
      const y = 14 + cellH * (row + .5) + (col % 2 ? 14 : -4) - 6;
      const colorIdx = i % BALLOON_COLORS.length;
      const body = this.add.image(0, 0, `bal${colorIdx}`).setScale(.5);
      body.setOrigin(.5, 68 / BALLOON_H * 1.0 + .0);
      body.y = 0;
      const txt = arText(this, 0, -2, o.text, 20, '#ffffff', {
        width: 86, stroke: 'rgba(30,20,80,.55)', strokeThickness: 3,
      });
      fitText(txt, 86, 66, 21, 11);
      const box = this.add.container(x, y, [body, txt]).setScale(s).setDepth(5);
      box.setSize(116, 132);
      // منطقة اللمس: إحداثيات الـContainer بتبدأ من ركنه العلوي الأيسر مش من مركزه،
      // فمركز القطع الناقص لازم يبقى (نص العرض، نص الطول) عشان يطابق جسم البالونة.
      box.setInteractive(new Phaser.Geom.Ellipse(58, 62, 112, 132), Phaser.Geom.Ellipse.Contains);
      box.on('pointerdown', () => this.pick(i));
      box.on('pointerover', () => { if (!this.locked) this.input.setDefaultCursor('pointer'); });
      box.on('pointerout', () => this.input.setDefaultCursor('default'));
      const item = { box, body, txt, i, baseY: y, baseX: x, s, color: BALLOON_COLORS[colorIdx] };
      this.items.push(item);

      // دخول من تحت بارتداد، وبعدها تمايل مستمر
      box.y = H + 180; box.setScale(s * .7); box.setAlpha(0);
      this.tweens.add({
        targets: box, y, scale: s, alpha: 1,
        duration: this.reduceMotion ? 1 : 650 + i * 110, delay: this.reduceMotion ? 0 : i * 90,
        ease: 'Back.easeOut',
        onComplete: () => this.startIdle(item),
      });
    });
  }

  startIdle(item) {
    if (this.reduceMotion || this.locked || !item.box.active) return;
    item.idleY = this.tweens.add({
      targets: item.box, y: item.baseY - Phaser.Math.Between(7, 13),
      duration: Phaser.Math.Between(1700, 2600), yoyo: true, repeat: -1, ease: 'Sine.easeInOut',
      delay: Phaser.Math.Between(0, 600),
    });
    item.idleR = this.tweens.add({
      targets: item.box, angle: { from: -3, to: 3 },
      duration: Phaser.Math.Between(1900, 2900), yoyo: true, repeat: -1, ease: 'Sine.easeInOut',
    });
  }

  pick(i) {
    if (this.locked) return;
    const it = this.items[i];
    // ضغطة محسوسة قبل ما المضيف يقرّر
    this.tweens.add({ targets: it.box, scale: it.s * .9, duration: 70, yoyo: true });
    this.onPick && this.onPick(i);
  }

  stopIdle() {
    this.items.forEach((it) => { it.idleY && it.idleY.stop(); it.idleR && it.idleR.stop(); });
  }

  /** النتيجة: chosen (رقم أو null لو الوقت خلص)، correct: الفهرس الصحيح. */
  reveal(chosen, correct) {
    this.locked = true;
    this.input.setDefaultCursor('default');
    this.stopIdle();
    this.items.forEach((it) => it.box.disableInteractive());
    const ok = chosen === correct;
    this.items.forEach((it) => {
      if (it.i === chosen) this.popBalloon(it, ok);
      else if (it.i === correct) this.glowCorrect(it);
      else this.floatAway(it);
    });
    if (ok) this.celebrate();
    else if (chosen !== null && !this.reduceMotion) this.cameras.main.shake(200, .006);
  }

  popBalloon(it, ok) {
    const { x, y } = it.box;
    const col = Phaser.Display.Color.HexStringToColor(it.color).color;
    it.box.setVisible(false);
    if (!this.reduceMotion) {
      this.add.particles(x, y, 'p_shred', {
        speed: { min: 140, max: 380 }, angle: { min: 0, max: 360 }, scale: { start: 1.1, end: .2 },
        rotate: { min: 0, max: 360 }, lifespan: 700, gravityY: 600, tint: col, emitting: false,
      }).setDepth(20).explode(ok ? 14 : 22);
      const ring = this.add.image(x, y, 'p_ring').setTint(0xffffff).setScale(.2).setDepth(19).setAlpha(.9);
      this.tweens.add({ targets: ring, scale: 1.4, alpha: 0, duration: 380, onComplete: () => ring.destroy() });
      this.add.particles(x, y, 'p_puff', {
        speed: { min: 20, max: 90 }, scale: { start: .8, end: 2.2 }, alpha: { start: .7, end: 0 },
        lifespan: 520, tint: 0xffffff, emitting: false,
      }).setDepth(18).explode(5);
    }
    const badge = this.add.image(x, y, ok ? 'badge_ok' : 'badge_no').setScale(0).setDepth(30);
    this.tweens.add({ targets: badge, scale: .62, duration: this.reduceMotion ? 1 : 420, ease: 'Back.easeOut' });
    it.badge = badge;
  }

  glowCorrect(it) {
    const { box } = it;
    box.setDepth(15);
    const halo = this.add.image(box.x, box.y, 'p_puff').setTint(0x7CFFB2).setScale(5).setAlpha(.0).setDepth(14);
    this.tweens.add({ targets: halo, alpha: .85, duration: 300 });
    if (!this.reduceMotion) {
      this.tweens.add({ targets: halo, scale: 6.2, duration: 700, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
      this.tweens.add({ targets: box, scale: it.s * 1.12, duration: 320, yoyo: true, repeat: 2, ease: 'Sine.easeInOut' });
    } else box.setScale(it.s * 1.12);
    const badge = this.add.image(box.x + 34 * it.s, box.y - 48 * it.s, 'badge_ok').setScale(0).setDepth(31);
    this.tweens.add({ targets: badge, scale: .5, duration: this.reduceMotion ? 1 : 420, delay: 160, ease: 'Back.easeOut' });
  }

  floatAway(it) {
    this.tweens.add({
      targets: it.box, y: it.box.y - (this.reduceMotion ? 0 : 60), alpha: .28, duration: this.reduceMotion ? 1 : 700, ease: 'Sine.easeOut',
    });
    it.body.setTint(0x9aa0c0);
  }

  celebrate() {
    if (this.reduceMotion) return;
    const colors = [0xffd15c, 0xf472b6, 0x34d399, 0x60a5fa, 0xfb923c, 0xffffff];
    this.add.particles(W / 2, -10, 'p_conf', {
      x: { min: 20, max: W - 20 }, speedY: { min: 90, max: 260 }, speedX: { min: -50, max: 50 },
      rotate: { min: 0, max: 360 }, scale: { min: .5, max: 1.1 }, lifespan: 1700, gravityY: 280,
      tint: colors, frequency: 18, quantity: 2, duration: 1000,
    }).setDepth(40);
  }

  clear() {
    this.stopIdle();
    this.tweens.killAll();
    this.items.forEach((it) => { it.box.destroy(); });
    this.children.list.filter((o) => o.depth >= 14 && o.depth !== undefined).forEach((o) => o.destroy());
    this.items = [];
  }
}

/** يركّب ساحة البالونات جوّه host. API: show / reveal / destroy */
export async function createBalloonStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, BalloonScene);
  return {
    show: (options, onPick) => scene.show(options, onPick),
    reveal: (chosen, correct) => scene.reveal(chosen, correct),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    aspect: W / H,
  };
}
