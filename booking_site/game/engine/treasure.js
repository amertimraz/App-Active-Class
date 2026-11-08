// treasure.js — «حفر الكنز»: صناديق مدفونة في الرمل، كل صندوق عليه إجابة.
// اختار الصندوق اللي فاكره صح: الصح بيفتح على دهب وجواهر، والغلط فيه فخ.
import { skyTexture, makeTexture, roundRect, lighten, darken, badgeTexture } from './art.js';
import { boot, setupScene, arText, fitText, fontsReady } from './engine.js';

const W = 480, H = 330;

function chestTexture(scene, key, open) {
  return makeTexture(scene, key, 140, 120, (c) => {
    c.fillStyle = 'rgba(0,0,0,.2)'; c.beginPath(); c.ellipse(70, 112, 52, 7, 0, 0, 7); c.fill();
    // الجسم
    const g = c.createLinearGradient(0, 56, 0, 108);
    g.addColorStop(0, '#B45309'); g.addColorStop(1, '#78350F');
    c.fillStyle = g; roundRect(c, 14, 56, 112, 52, 8); c.fill();
    c.strokeStyle = '#451A03'; c.lineWidth = 3; c.stroke();
    c.fillStyle = '#FBBF24'; c.fillRect(14, 74, 112, 8);
    c.fillRect(30, 56, 8, 52); c.fillRect(102, 56, 8, 52);
    if (!open) {
      // الغطا مقفول
      const g2 = c.createLinearGradient(0, 22, 0, 60);
      g2.addColorStop(0, '#D97706'); g2.addColorStop(1, '#92400E');
      c.fillStyle = g2; c.beginPath(); c.moveTo(14, 58); c.quadraticCurveTo(70, 4, 126, 58); c.closePath(); c.fill();
      c.strokeStyle = '#451A03'; c.lineWidth = 3; c.stroke();
      c.fillStyle = '#FBBF24'; c.fillRect(66, 58, 8, 0);
      c.fillStyle = '#FDE68A'; roundRect(c, 62, 62, 16, 20, 4); c.fill();
      c.strokeStyle = '#78350F'; c.lineWidth = 2; c.stroke();
      c.fillStyle = '#78350F'; c.beginPath(); c.arc(70, 70, 3, 0, 7); c.fill();
    } else {
      // الغطا مفتوح وراه
      c.fillStyle = '#92400E'; c.beginPath(); c.moveTo(18, 54); c.lineTo(34, 8); c.lineTo(106, 8); c.lineTo(122, 54); c.closePath(); c.fill();
      c.strokeStyle = '#451A03'; c.lineWidth = 3; c.stroke();
      c.fillStyle = '#1C0A02'; roundRect(c, 20, 52, 100, 14, 6); c.fill();
    }
  });
}

class TreasureScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.items = [];
    this.locked = true;
    skyTexture(this, 'zsky', W, H, '#0EA5E9', '#FDE68A');
    this.add.image(0, 0, 'zsky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    const g = this.add.graphics().setDepth(-9);
    g.fillStyle(0xFCD34D, 1); g.fillRect(0, 120, W, H - 120);
    g.fillStyle(0xFBBF24, 1);
    for (let i = 0; i < 9; i++) g.fillEllipse(30 + i * 56, 124 + (i % 3) * 5, 90, 20);
    g.fillStyle(0xD97706, 0.25);
    for (let i = 0; i < 14; i++) g.fillCircle(20 + (i * 83) % 460, 170 + (i * 47) % 140, 3 + (i % 3));
    // شمس وسحابتين ديكور
    this.add.circle(W - 56, 46, 26, 0xFFF176).setDepth(-8);
    chestTexture(this, 'chest_c', false); chestTexture(this, 'chest_o', true);
    badgeTexture(this, 'badge_ok', true); badgeTexture(this, 'badge_no', false);
    makeTexture(this, 'tz_coin', 24, 24, (c) => {
      c.fillStyle = '#FDE047'; c.beginPath(); c.arc(12, 12, 10, 0, 7); c.fill();
      c.strokeStyle = '#A16207'; c.lineWidth = 2; c.stroke();
      c.fillStyle = '#CA8A04'; c.fillRect(10, 6, 4, 12);
    });
    makeTexture(this, 'tz_gem', 24, 24, (c) => {
      c.fillStyle = '#38BDF8'; c.beginPath(); c.moveTo(12, 2); c.lineTo(22, 10); c.lineTo(12, 22); c.lineTo(2, 10); c.closePath(); c.fill();
      c.strokeStyle = '#075985'; c.lineWidth = 2; c.stroke();
    });
    data.onReady(this);
  }

  show(options, onPick) {
    this.clear();
    this.onPick = onPick;
    const n = options.length;
    const cols = n <= 3 ? n : 2, rows = Math.ceil(n / cols);
    options.forEach((o, i) => {
      const col = i % cols, row = Math.floor(i / cols);
      const rowN = row === rows - 1 && n % cols ? n % cols : cols;
      const lane = W / rowN;
      const x = lane * ((rowN === cols ? col : col) + 0.5);
      const y = rows === 1 ? 210 : 156 + row * 104;
      const sc = rows === 1 ? 0.4 : 0.32;           // 280px texture → ~112 / 90 منطقي
      const signY = -(120 * sc + 12);
      const chest = this.add.image(0, 0, 'chest_c').setScale(sc);
      // لافتة خشب فوق الصندوق عليها الإجابة
      const sign = this.add.graphics();
      sign.fillStyle(0x7C2D12, 1); sign.fillRoundedRect(-62, signY - 22, 124, 44, 8);
      sign.fillStyle(0xFEF3C7, 1); sign.fillRoundedRect(-58, signY - 18, 116, 36, 6);
      const txt = arText(this, 0, signY, o.text, 16, '#3B1D06', { width: 108 });
      fitText(txt, 106, 32, 16, 8);
      const box = this.add.container(x, y, [chest, sign, txt]).setDepth(6);
      box.setSize(260 * sc, 240 * sc + 70);
      box.setInteractive({ useHandCursor: true });
      box.on('pointerdown', () => { if (!this.locked) { this.locked = true; this.onPick && this.onPick(i); } });
      box.on('pointerover', () => { if (!this.locked) box.setScale(1.05); });
      box.on('pointerout', () => box.setScale(1));
      this.items.push({ box, chest, i, sc });
      box.setScale(0.3).setAlpha(0);
      this.tweens.add({ targets: box, scale: 1, alpha: 1, duration: this.reduceMotion ? 1 : 340, delay: i * 80, ease: 'Back.easeOut' });
    });
    this.locked = false;
  }

  openChest(it, good) {
    it.chest.setTexture('chest_o');
    const x = it.box.x, y = it.box.y - 10;
    if (this.reduceMotion) { return; }
    if (good) {
      this.add.particles(x, y, 'tz_coin', {
        speed: { min: 120, max: 320 }, angle: { min: 230, max: 310 }, scale: { start: 1, end: 0.5 },
        lifespan: 1000, gravityY: 600, rotate: { min: 0, max: 360 }, emitting: false,
      }).setDepth(25).explode(14);
      this.add.particles(x, y, 'tz_gem', {
        speed: { min: 100, max: 260 }, angle: { min: 240, max: 300 }, scale: { start: 0.9, end: 0.4 },
        lifespan: 900, gravityY: 500, emitting: false,
      }).setDepth(25).explode(6);
      this.add.particles(x, y, 'p_star', {
        speed: { min: 60, max: 200 }, scale: { start: 0.8, end: 0 }, lifespan: 800,
        tint: [0xffd15c, 0xffffff], emitting: false,
      }).setDepth(26).explode(10);
    } else {
      this.add.particles(x, y, 'p_puff', {
        speed: { min: 30, max: 120 }, scale: { start: 0.8, end: 3 }, alpha: { start: 0.9, end: 0 },
        lifespan: 900, tint: 0x3f3a52, emitting: false,
      }).setDepth(25).explode(10);
      this.cameras.main.shake(200, 0.007);
    }
  }

  reveal(chosen, correct) {
    this.locked = true;
    this.items.forEach((it) => it.box.disableInteractive());
    const ok = chosen !== null && chosen === correct;
    const mine = chosen === null ? null : this.items[chosen];
    const right = this.items[correct];
    if (mine) {
      this.tweens.add({ targets: mine.box, y: mine.box.y - 8, duration: 120, yoyo: true });
      this.time.delayedCall(this.reduceMotion ? 1 : 200, () => {
        this.openChest(mine, ok);
        const badge = this.add.image(mine.box.x, mine.box.y - (120 * mine.sc + 62), ok ? 'badge_ok' : 'badge_no').setScale(0).setDepth(30);
        this.tweens.add({ targets: badge, scale: 0.55, duration: this.reduceMotion ? 1 : 360, ease: 'Back.easeOut' });
        if (!ok && mine.chest) {
          const skull = arText(this, mine.box.x, mine.box.y - 6, '💀', 34).setDepth(26).setScale(0.2);
          this.tweens.add({ targets: skull, scale: 1, y: skull.y - 22, duration: 360, ease: 'Back.easeOut' });
        }
      });
    }
    this.time.delayedCall(this.reduceMotion ? 1 : (mine ? 700 : 100), () => {
      if (right && right !== mine) {
        this.openChest(right, true);
        const badge = this.add.image(right.box.x, right.box.y - (120 * right.sc + 62), 'badge_ok').setScale(0).setDepth(31);
        this.tweens.add({ targets: badge, scale: 0.5, duration: this.reduceMotion ? 1 : 340, ease: 'Back.easeOut' });
      }
      this.items.forEach((it) => { if (it !== right && it !== mine) it.box.setAlpha(0.4); });
    });
  }

  clear() {
    this.items.forEach((it) => it.box.destroy());
    this.children.list.filter((o) => o.depth >= 25).forEach((o) => o.destroy());
    this.items = [];
  }
}

export async function createTreasureStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, TreasureScene);
  return {
    show: (options, onPick) => scene.show(options, onPick),
    reveal: (chosen, correct) => scene.reveal(chosen, correct),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
