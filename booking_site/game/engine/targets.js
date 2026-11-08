// targets.js — «الرماية على الأهداف»: لوحات رماية متحركة عليها الإجابات، وإنت
// بتضغط على اللوحة اللي فاكرها صح فينطلق سهم يصيبها. الصح بيطلّع نجوم، والغلط بينكسر.
import { skyTexture, hillsTexture, makeTexture, lighten, darken, badgeTexture, roundRect } from './art.js';
import { boot, setupScene, arText, fitText, fontsReady, BALLOON_COLORS } from './engine.js';

const W = 480, H = 380;
const R_T = 46;                      // نصف قطر اللوحة (منطقي)

function targetTexture(scene, key, color) {
  return makeTexture(scene, key, 120, 120, (c) => {
    c.fillStyle = 'rgba(0,0,0,.18)'; c.beginPath(); c.arc(64, 66, 54, 0, 7); c.fill();
    const rings = [[54, '#FFFFFF'], [44, color], [34, '#FFFFFF'], [24, darken(color, 0.15)]];
    rings.forEach(([r, col]) => { c.fillStyle = col; c.beginPath(); c.arc(60, 60, r, 0, 7); c.fill(); });
    c.strokeStyle = darken(color, 0.5); c.lineWidth = 3; c.beginPath(); c.arc(60, 60, 54, 0, 7); c.stroke();
    c.fillStyle = 'rgba(255,255,255,.25)'; c.beginPath(); c.ellipse(40, 34, 18, 9, -0.6, 0, 7); c.fill();
  });
}

function arrowTexture(scene) {
  return makeTexture(scene, 'tg_arrow', 22, 90, (c) => {
    c.fillStyle = '#92400E'; roundRect(c, 9.5, 14, 3, 66, 1.5); c.fill();
    c.fillStyle = '#F8FAFC'; c.beginPath(); c.moveTo(11, 2); c.lineTo(19, 20); c.lineTo(3, 20); c.closePath(); c.fill();
    c.strokeStyle = '#64748B'; c.lineWidth = 1.5; c.stroke();
    c.fillStyle = '#EF4444'; c.beginPath(); c.moveTo(11, 66); c.lineTo(20, 88); c.lineTo(11, 80); c.lineTo(2, 88); c.closePath(); c.fill();
  });
}

class TargetScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.items = [];
    this.locked = true;
    skyTexture(this, 'tsky2', W, H, '#38BDF8', '#FEF3C7');
    this.add.image(0, 0, 'tsky2').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    hillsTexture(this, 'thill', W, 130, '#86EFAC', 18, 1, 0.8);
    hillsTexture(this, 'thill2', W, 110, '#22C55E', 12, 2, 2.2);
    this.add.image(0, H - 140, 'thill').setOrigin(0).setDisplaySize(W, 130).setDepth(-8);
    this.add.image(0, H - 100, 'thill2').setOrigin(0).setDisplaySize(W, 110).setDepth(-7);
    arrowTexture(this); badgeTexture(this, 'badge_ok', true); badgeTexture(this, 'badge_no', false);
    BALLOON_COLORS.forEach((c, i) => targetTexture(this, `tgt${i}`, c));
    // القوس تحت (ديكور)
    const g = this.add.graphics().setDepth(5);
    g.lineStyle(5, 0x92400E, 1); g.beginPath(); g.arc(W / 2, H + 30, 56, Math.PI * 1.1, Math.PI * 1.9); g.strokePath();
    g.lineStyle(2, 0xffffff, 0.8); g.lineBetween(W / 2 - 52, H - 12, W / 2 + 52, H - 12);
    data.onReady(this);
  }

  show(options, onPick) {
    this.clear();
    this.onPick = onPick;
    const n = options.length;
    options.forEach((o, i) => {
      const body = this.add.image(0, 0, `tgt${i % BALLOON_COLORS.length}`).setScale(0.5);
      // النص على شريط أبيض في نص اللوحة عشان يتقري
      const bar = this.add.graphics();
      bar.fillStyle(0xffffff, 0.92); bar.fillRoundedRect(-36, -13, 72, 26, 8);
      const txt = arText(this, 0, 0, o.text, 14, '#1B1747', { width: 66 });
      fitText(txt, 64, 24, 14, 8);
      const y = 70 + (i % 2) * 104 + (n > 3 ? 0 : 20);
      const x0 = (W / n) * (i + 0.5);
      const box = this.add.container(x0, y, [body, bar, txt]).setDepth(6);
      box.setSize(R_T * 2, R_T * 2);
      box.setInteractive({ useHandCursor: true });
      box.on('pointerdown', () => { if (!this.locked) { this.locked = true; this.onPick && this.onPick(i); } });
      const it = { box, i, x0, amp: Phaser.Math.Between(46, 80), spd: Phaser.Math.FloatBetween(0.9, 1.5), ph: i * 1.7, frozen: false };
      this.items.push(it);
    });
    this.locked = false;
  }

  update(_, dtMs) {
    if (!this.items.length) return;
    const t = this.time.now / 1000;
    for (const it of this.items) {
      if (it.frozen) continue;
      const k = this.reduceMotion ? 0.15 : 1;
      it.box.x = Phaser.Math.Clamp(it.x0 + Math.sin(t * it.spd + it.ph) * it.amp * k, R_T + 4, W - R_T - 4);
    }
  }

  reveal(chosen, correct) {
    this.locked = true;
    this.items.forEach((it) => it.box.disableInteractive());
    const ok = chosen !== null && chosen === correct;
    const mine = chosen === null ? null : this.items[chosen];
    const finish = () => {
      this.items.forEach((it) => { it.frozen = true; });
      const right = this.items[correct];
      if (right && right !== mine) {
        const badge = this.add.image(right.box.x, right.box.y - 54, 'badge_ok').setScale(0).setDepth(30);
        this.tweens.add({ targets: badge, scale: 0.46, duration: this.reduceMotion ? 1 : 340, ease: 'Back.easeOut' });
        this.tweens.add({ targets: right.box, scale: 1.12, duration: 240, yoyo: true, repeat: 2 });
      }
      this.items.forEach((it) => { if (it !== right && it !== mine) it.box.setAlpha(0.35); });
    };
    if (!mine) { finish(); return; }
    mine.frozen = true;
    const tx = mine.box.x, ty = mine.box.y;
    const arrow = this.add.image(W / 2, H - 24, 'tg_arrow').setScale(0.5).setDepth(14);
    arrow.rotation = Math.atan2(tx - W / 2, -(ty - (H - 24)));
    const done = () => {
      const burst = this.add.image(tx, ty, 'p_ring').setTint(ok ? 0x34d399 : 0xf43f5e).setScale(0.3).setDepth(20);
      this.tweens.add({ targets: burst, scale: 1.5, alpha: 0, duration: 520, onComplete: () => burst.destroy() });
      const badge = this.add.image(tx, ty - 56, ok ? 'badge_ok' : 'badge_no').setScale(0).setDepth(30);
      this.tweens.add({ targets: badge, scale: 0.55, duration: this.reduceMotion ? 1 : 360, ease: 'Back.easeOut' });
      if (!this.reduceMotion) {
        this.add.particles(tx, ty, ok ? 'p_star' : 'p_shred', {
          speed: { min: 100, max: 300 }, scale: { start: 0.9, end: 0 }, lifespan: 700, gravityY: 400,
          tint: ok ? [0xffd15c, 0xffffff, 0x34d399] : 0xf43f5e, emitting: false,
        }).setDepth(25).explode(ok ? 16 : 12);
        if (ok) this.tweens.add({ targets: mine.box, scale: 1.18, duration: 160, yoyo: true });
        else { this.cameras.main.shake(160, 0.005); this.tweens.add({ targets: mine.box, angle: 25, alpha: 0.5, duration: 400 }); }
      }
      finish();
    };
    if (this.reduceMotion) { arrow.setPosition(tx, ty); done(); return; }
    this.tweens.add({ targets: arrow, x: tx, y: ty + 6, duration: 260, ease: 'Quad.easeIn', onComplete: done });
  }

  clear() {
    this.items.forEach((it) => it.box.destroy());
    this.children.list.filter((o) => o.depth >= 14).forEach((o) => o.destroy());
    this.items = [];
  }
}

export async function createTargetsStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, TargetScene);
  return {
    show: (options, onPick) => scene.show(options, onPick),
    reveal: (chosen, correct) => scene.reveal(chosen, correct),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
