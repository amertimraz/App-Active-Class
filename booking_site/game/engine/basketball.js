// basketball.js — «كرة السلة»: كل إجابة على كورة، وإنت بتضغط على الكورة اللي
// فاكرها صح فتتشوّط ناحية السلة. الصح بيدخل (swish)، والغلط بيخبط الحلقة وبيرجع.
import { skyTexture, makeTexture, roundRect, lighten, darken, badgeTexture } from './art.js';
import { boot, setupScene, arText, fitText, fontsReady, BALLOON_COLORS } from './engine.js';

const W = 480, H = 380;
const HOOP_X = W / 2, HOOP_Y = 96;       // مركز الحلقة
const BALL_Y = 296;

function ballTexture(scene, key, color) {
  return makeTexture(scene, key, 120, 120, (c) => {
    c.fillStyle = 'rgba(0,0,0,.16)'; c.beginPath(); c.ellipse(60, 112, 40, 6, 0, 0, 7); c.fill();
    const g = c.createRadialGradient(44, 40, 6, 60, 60, 56);
    g.addColorStop(0, lighten(color, 0.45)); g.addColorStop(1, darken(color, 0.25));
    c.fillStyle = g; c.beginPath(); c.arc(60, 58, 54, 0, 7); c.fill();
    c.strokeStyle = darken(color, 0.55); c.lineWidth = 3; c.stroke();
    // خطوط الكورة
    c.lineWidth = 2.2; c.strokeStyle = 'rgba(40,20,0,.45)';
    c.beginPath(); c.moveTo(6, 58); c.lineTo(114, 58); c.stroke();
    c.beginPath(); c.moveTo(60, 4); c.lineTo(60, 112); c.stroke();
    c.beginPath(); c.arc(-6, 58, 50, -0.9, 0.9); c.stroke();
    c.beginPath(); c.arc(126, 58, 50, Math.PI - 0.9, Math.PI + 0.9); c.stroke();
  });
}

function hoopTextures(scene) {
  makeTexture(scene, 'bb_board', 180, 120, (c) => {
    c.fillStyle = 'rgba(0,0,0,.18)'; roundRect(c, 8, 10, 168, 106, 10); c.fill();
    c.fillStyle = '#F8FAFC'; roundRect(c, 4, 4, 168, 106, 10); c.fill();
    c.strokeStyle = '#475569'; c.lineWidth = 5; c.stroke();
    c.strokeStyle = '#EF4444'; c.lineWidth = 4; roundRect(c, 56, 40, 64, 52, 4); c.stroke();
  });
  makeTexture(scene, 'bb_net', 90, 60, (c) => {
    c.strokeStyle = 'rgba(255,255,255,.95)'; c.lineWidth = 2.2;
    for (let i = 0; i <= 6; i++) {
      const x0 = 4 + i * 13.7, x1 = 18 + i * 9.2;
      c.beginPath(); c.moveTo(x0, 2); c.lineTo(x1, 56); c.stroke();
    }
    for (let y = 14; y < 56; y += 14) {
      const inset = (y / 56) * 12;
      c.beginPath(); c.moveTo(4 + inset, y); c.lineTo(86 - inset, y); c.stroke();
    }
  });
  makeTexture(scene, 'bb_rim', 100, 14, (c) => {
    c.fillStyle = '#F97316'; roundRect(c, 2, 2, 96, 9, 4.5); c.fill();
    c.strokeStyle = '#9A3412'; c.lineWidth = 2; c.stroke();
  });
}

class BasketScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.items = [];
    this.locked = true;
    skyTexture(this, 'bsky', W, H, '#7C3AED', '#FDBA74');
    this.add.image(0, 0, 'bsky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    // أرضية الملعب
    const g = this.add.graphics().setDepth(-9);
    g.fillStyle(0xB45309, 1); g.fillRect(0, H - 70, W, 70);
    g.fillStyle(0xD97706, 1); g.fillRect(0, H - 70, W, 6);
    g.lineStyle(3, 0xffffff, 0.35); g.strokeCircle(W / 2, H - 20, 64);
    // جمهور بسيط
    for (let i = 0; i < 14; i++) {
      const x = 16 + i * 34 + (i % 2) * 6;
      g.fillStyle(Phaser.Display.Color.GetColor(60 + (i * 37) % 120, 40 + (i * 53) % 120, 120 + (i * 29) % 100), 0.55);
      g.fillCircle(x, 150 + (i % 3) * 6, 11);
    }
    hoopTextures(this); badgeTexture(this, 'badge_ok', true); badgeTexture(this, 'badge_no', false);
    this.add.image(HOOP_X, HOOP_Y - 18, 'bb_board').setScale(0.5).setDepth(1);
    this.net = this.add.image(HOOP_X, HOOP_Y + 22, 'bb_net').setScale(0.5).setDepth(3);
    this.rim = this.add.image(HOOP_X, HOOP_Y + 4, 'bb_rim').setScale(0.5).setDepth(4);
    BALLOON_COLORS.forEach((c, i) => ballTexture(this, `ball${i}`, '#F97316'));
    data.onReady(this);
  }

  /** options: [{text}] */
  show(options, onPick) {
    this.clear();
    this.onPick = onPick;
    const n = options.length, lane = W / n;
    const k = Math.min(0.86, (lane - 16) / 120);   // نسبة من حجم الكورة المنطقي (120)
    options.forEach((o, i) => {
      const ball = this.add.image(0, 0, 'ball0').setScale(0.5 * k);
      const txt = arText(this, 0, -2 * k, o.text, 18, '#fff', { width: 84 * k, stroke: 'rgba(60,20,0,.7)', strokeThickness: 4 });
      fitText(txt, 76 * k, 56 * k, 18, 8);
      const box = this.add.container(lane * (i + 0.5), BALL_Y, [ball, txt]).setDepth(6);
      box.setSize(110 * k, 110 * k);
      box.setInteractive({ useHandCursor: true });
      box.on('pointerdown', () => { if (!this.locked) { this.locked = true; this.onPick && this.onPick(i); } });
      box.on('pointerover', () => { if (!this.locked) box.setScale(1.07); });
      box.on('pointerout', () => box.setScale(1));
      this.items.push({ box, i, ball });
      box.setScale(0.2).setAlpha(0);
      this.tweens.add({ targets: box, scale: 1, alpha: 1, duration: this.reduceMotion ? 1 : 320, delay: i * 70, ease: 'Back.easeOut' });
    });
    this.locked = false;
  }

  reveal(chosen, correct) {
    this.locked = true;
    this.items.forEach((it) => it.box.disableInteractive());
    const ok = chosen !== null && chosen === correct;
    const mine = chosen === null ? null : this.items[chosen];
    const done = () => {
      // علّم الصح
      const right = this.items[correct];
      if (right && right !== mine) {
        const badge = this.add.image(right.box.x, right.box.y - 62, 'badge_ok').setScale(0).setDepth(30);
        this.tweens.add({ targets: badge, scale: 0.46, duration: this.reduceMotion ? 1 : 340, ease: 'Back.easeOut' });
        this.tweens.add({ targets: right.box, y: right.box.y - 8, duration: 260, yoyo: true, repeat: 2 });
      }
      this.items.forEach((it) => { if (it !== right && it !== mine) it.box.setAlpha(0.4); });
    };
    if (!mine) { done(); return; }                        // الوقت خلص
    const b = mine.box.setDepth(12);
    const sx = b.x, sy = b.y;
    if (this.reduceMotion) { b.setPosition(HOOP_X, ok ? HOOP_Y + 30 : HOOP_Y + 80); this.finishShot(ok, b, done); return; }
    // قوس الشوط: x خطي، y بقوس
    const missX = HOOP_X + (sx < HOOP_X ? -42 : 42);
    const tx = ok ? HOOP_X : missX, ty = HOOP_Y + 2;
    const prog = { t: 0 };
    this.tweens.add({
      targets: prog, t: 1, duration: 720, ease: 'Sine.easeInOut',
      onUpdate: () => {
        const t = prog.t;
        b.x = sx + (tx - sx) * t;
        b.y = sy + (ty - sy) * t - Math.sin(Math.PI * t) * 90;
        b.setScale(1 - 0.5 * t);
        b.angle = t * 540;
      },
      onComplete: () => this.finishShot(ok, b, done),
    });
  }

  finishShot(ok, b, done) {
    const mid = this.add.image(b.x, b.y, 'p_ring').setTint(ok ? 0x34d399 : 0xf43f5e).setScale(0.3).setDepth(20).setAlpha(0.9);
    this.tweens.add({ targets: mid, scale: 1.4, alpha: 0, duration: 500, onComplete: () => mid.destroy() });
    if (ok) {
      // سووش: الكورة بتنزل جوّه الشبكة
      this.tweens.add({ targets: this.net, scaleY: 0.62, duration: 120, yoyo: true, repeat: 1 });
      this.tweens.add({ targets: b, y: HOOP_Y + 52, alpha: 0.0, duration: 340, ease: 'Quad.easeIn' });
      if (!this.reduceMotion) {
        this.add.particles(HOOP_X, HOOP_Y + 20, 'p_star', {
          speed: { min: 80, max: 260 }, angle: { min: 200, max: 340 }, scale: { start: 0.8, end: 0 },
          lifespan: 800, gravityY: 400, tint: [0xffd15c, 0xffffff, 0x34d399], emitting: false,
        }).setDepth(25).explode(16);
      }
      const badge = this.add.image(HOOP_X, HOOP_Y + 90, 'badge_ok').setScale(0).setDepth(30);
      this.tweens.add({ targets: badge, scale: 0.55, duration: 360, ease: 'Back.easeOut' });
    } else {
      // بتخبط الحلقة وبترجع تقع
      this.tweens.add({ targets: this.rim, angle: 6, duration: 70, yoyo: true, repeat: 3 });
      this.tweens.add({ targets: b, x: b.x + (b.x < HOOP_X ? -50 : 50), y: H - 40, angle: b.angle + 300, duration: 620, ease: 'Bounce.easeOut' });
      if (!this.reduceMotion) this.cameras.main.shake(160, 0.005);
      const badge = this.add.image(b.x, HOOP_Y + 74, 'badge_no').setScale(0).setDepth(30);
      this.tweens.add({ targets: badge, scale: 0.55, duration: 360, ease: 'Back.easeOut' });
    }
    this.time.delayedCall(ok ? 250 : 350, done);
  }

  clear() {
    this.items.forEach((it) => it.box.destroy());
    this.children.list.filter((o) => o.depth >= 12).forEach((o) => o.destroy());
    this.items = [];
    this.rim.setAngle(0);
    this.net.setScale(0.5);
  }
}

export async function createBasketStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, BasketScene);
  return {
    show: (options, onPick) => scene.show(options, onPick),
    reveal: (chosen, correct) => scene.reveal(chosen, correct),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
