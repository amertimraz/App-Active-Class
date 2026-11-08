// catcher.js — «اصطياد الإجابة»: الإجابات على صناديق بتنزل من فوق، وإنت بتحرّك
// السلّة (بالصباع أو الماوس أو الأسهم) وتلقط الصندوق اللي عليه الإجابة الصح.
// الصناديق بتلف تنزل تاني لحد ما تلقط واحد أو الوقت يخلص.
import { skyTexture, sunTexture, cloudTexture, hillsTexture, treesTexture, badgeTexture } from './art.js';
import { basketTexture, crateTexture } from './characters.js';
import { boot, setupScene, arText, fitText, fontsReady, BALLOON_COLORS } from './engine.js';

const W = 480, H = 380;
const BASKET_Y = H - 44;

class CatcherScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.items = [];
    this.locked = true;
    this.targetX = W / 2;
    skyTexture(this, 'csky', W, H, '#46B6FF', '#D3F1FF');
    this.add.image(0, 0, 'csky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    sunTexture(this);
    this.add.image(W - 58, 54, 'sun').setScale(0.45).setDepth(-9);
    [['cc1', 130, 56, 1, 90, 60], ['cc2', 110, 48, 2, 330, 120]].forEach(([k, w, h, seed, x, y], i) => {
      cloudTexture(this, k, w, h, seed);
      const c = this.add.image(x, y, k).setScale(0.5).setAlpha(0.9).setDepth(-8);
      if (!this.reduceMotion) this.tweens.add({ targets: c, x: x + (i ? -50 : 50), duration: 9000 + i * 2500, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
    });
    hillsTexture(this, 'chill', W, 120, '#8FE3B1', 16, 1, 0.5);
    hillsTexture(this, 'chill2', W, 110, '#3CC47C', 12, 2, 1.8);
    treesTexture(this, 'ctrees', W, 70);
    this.add.image(0, H - 118, 'chill').setOrigin(0).setDisplaySize(W, 120).setDepth(-7);
    this.add.image(0, H - 94, 'chill2').setOrigin(0).setDisplaySize(W, 110).setDepth(-6);
    this.add.image(0, H - 84, 'ctrees').setOrigin(0).setDisplaySize(W, 70).setDepth(-5);
    basketTexture(this);
    badgeTexture(this, 'badge_ok', true); badgeTexture(this, 'badge_no', false);
    BALLOON_COLORS.forEach((c, i) => crateTexture(this, `crate${i}`, c));
    this.basket = this.add.image(W / 2, BASKET_Y, 'basket').setScale(0.5).setDepth(10);

    this.input.on('pointermove', (p) => { this.targetX = Phaser.Math.Clamp(p.x / this.S, 40, W - 40); });
    this.input.on('pointerdown', (p) => { this.targetX = Phaser.Math.Clamp(p.x / this.S, 40, W - 40); });
    this.cursors = this.input.keyboard ? this.input.keyboard.createCursorKeys() : null;
    data.onReady(this);
  }

  /** options: [{text}] */
  show(options, onPick) {
    this.clear();
    this.onPick = onPick;
    const n = options.length;
    const lane = W / n;
    options.forEach((o, i) => {
      const body = this.add.image(0, 0, `crate${i % BALLOON_COLORS.length}`).setScale(0.42);
      const txt = arText(this, 0, 2, o.text, 18, '#ffffff', { width: 80, stroke: 'rgba(30,20,80,.55)', strokeThickness: 3 });
      fitText(txt, 80, 40, 18, 10);
      const box = this.add.container(lane * (i + 0.5), -50 - i * 95, [body, txt]).setDepth(6);
      const it = { box, i, lane, vy: Phaser.Math.Between(78, 118), done: false };
      this.items.push(it);
    });
    this.locked = false;
  }

  update(_, dtMs) {
    const dt = Math.min(dtMs, 50) / 1000;
    // السلّة بتلحق الصباع/الماوس بسلاسة (والأسهم للكمبيوتر)
    if (this.cursors && !this.locked) {
      if (this.cursors.left.isDown) this.targetX -= 340 * dt;
      if (this.cursors.right.isDown) this.targetX += 340 * dt;
      this.targetX = Phaser.Math.Clamp(this.targetX, 40, W - 40);
    }
    const prev = this.basket.x;
    this.basket.x += (this.targetX - this.basket.x) * Math.min(1, dt * 14);
    this.basket.angle = Phaser.Math.Clamp((this.basket.x - prev) * 0.5, -8, 8);
    if (this.locked) return;
    for (const it of this.items) {
      if (it.done) continue;
      const b = it.box;
      b.y += it.vy * dt;
      b.angle = Math.sin((this.time.now + it.i * 400) / 380) * 5;
      // التقاط: الصندوق نزل على فتحة السلّة
      if (b.y > BASKET_Y - 34 && b.y < BASKET_Y + 6 && Math.abs(b.x - this.basket.x) < 54) {
        this.catch(it);
        return;
      }
      // عدّى تحت: يرجع من فوق في مكان جديد
      if (b.y > H + 50) {
        b.y = -50;
        b.x = Phaser.Math.Clamp(it.lane * (it.i + 0.5) + Phaser.Math.Between(-30, 30), 70, W - 70);
        it.vy = Phaser.Math.Between(78, 118);
      }
    }
  }

  catch(it) {
    this.locked = true;
    this.tweens.add({ targets: this.basket, scaleY: 0.42, duration: 90, yoyo: true });
    this.onPick && this.onPick(it.i);
  }

  reveal(chosen, correct) {
    this.locked = true;
    const ok = chosen === correct;
    this.items.forEach((it) => {
      const b = it.box;
      if (it.i === chosen) {
        b.setDepth(12);
        this.tweens.add({ targets: b, x: this.basket.x, y: BASKET_Y - 14, scale: 0.8, duration: 160 });
        const badge = this.add.image(this.basket.x, BASKET_Y - 70, ok ? 'badge_ok' : 'badge_no').setScale(0).setDepth(30);
        this.tweens.add({ targets: badge, scale: 0.62, duration: this.reduceMotion ? 1 : 380, ease: 'Back.easeOut' });
        if (!this.reduceMotion) {
          this.add.particles(this.basket.x, BASKET_Y - 20, ok ? 'p_star' : 'p_shred', {
            speed: { min: 120, max: 320 }, angle: { min: 200, max: 340 }, scale: { start: 0.9, end: 0 },
            lifespan: 700, gravityY: 500, tint: ok ? [0xffd15c, 0xffffff, 0x34d399] : 0xf43f5e, emitting: false,
          }).setDepth(25).explode(ok ? 14 : 10);
          if (!ok) this.cameras.main.shake(180, 0.006);
        }
      } else if (it.i === correct) {
        // الصندوق الصح بينزل ويستقر مضيء
        this.tweens.add({ targets: b, y: BASKET_Y - 150, x: Phaser.Math.Clamp(b.x, 80, W - 80), duration: 400, ease: 'Cubic.easeOut' });
        const halo = this.add.image(b.x, BASKET_Y - 150, 'p_puff').setTint(0x7CFFB2).setScale(4).setAlpha(0.8).setDepth(5);
        this.tweens.add({ targets: halo, scale: 5, alpha: 0.4, duration: 600, yoyo: true, repeat: -1 });
        const badge = this.add.image(b.x + 34, BASKET_Y - 190, 'badge_ok').setScale(0).setDepth(31);
        this.tweens.add({ targets: badge, scale: 0.5, duration: this.reduceMotion ? 1 : 380, delay: 200, ease: 'Back.easeOut' });
        b.setDepth(15);
      } else {
        this.tweens.add({ targets: b, alpha: 0.25, y: b.y + 30, duration: 400 });
      }
    });
  }

  clear() {
    this.tweens.killTweensOf(this.basket);
    this.items.forEach((it) => it.box.destroy());
    this.children.list.filter((o) => o.depth >= 5 && o !== this.basket && o.depth !== 10).forEach((o) => o.destroy());
    this.items = [];
    this.basket.setScale(0.5);
  }
}

export async function createCatcherStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, CatcherScene);
  return {
    show: (options, onPick) => scene.show(options, onPick),
    reveal: (chosen, correct) => scene.reveal(chosen, correct),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
