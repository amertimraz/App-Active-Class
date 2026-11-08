// truefalse.js — «صح ولا غلط»: زرّين ضخمين 3D (صح أخضر وغلط أحمر) وجنبهم
// شخصية بتتفاعل: بتفرح لو صح وتتألّم لو غلط. نص الجملة نفسه بيفضل في الصفحة.
import { skyTexture, badgeTexture } from './art.js';
import { heroTexture, bigButtonTexture } from './characters.js';
import { boot, setupScene, arText, fontsReady } from './engine.js';

const W = 480, H = 250;

class TfScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.locked = true;
    skyTexture(this, 'tsky', W, H, '#0EA5E9', '#A7F3D0');
    this.add.image(0, 0, 'tsky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    const g = this.add.graphics().setDepth(-9);
    g.fillStyle(0x34D399, 0.5); g.fillCircle(60, H + 30, 120); g.fillCircle(430, H + 40, 130);
    bigButtonTexture(this, 'btn_ok', '#10B981'); bigButtonTexture(this, 'btn_no', '#F43F5E');
    badgeTexture(this, 'badge_ok', true); badgeTexture(this, 'badge_no', false);
    heroTexture(this, 'th_n', 'n'); heroTexture(this, 'th_h', 'happy'); heroTexture(this, 'th_x', 'hurt');
    this.hero = this.add.image(W / 2, 66, 'th_n').setScale(0.5 * 0.85).setDepth(4);
    if (!this.reduceMotion) this.tweens.add({ targets: this.hero, y: 60, duration: 800, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
    this.btns = [
      // الصفحة RTL: «صح» على اليمين زي الأزرار العادية.
      this.makeBtn(W * 0.73, 170, 'btn_ok', 'صح', true),
      this.makeBtn(W * 0.27, 170, 'btn_no', 'خطأ', false),
    ];
    data.onReady(this);
  }

  makeBtn(x, y, key, label, value) {
    const img = this.add.image(0, 0, key).setScale(0.5 * 0.82);
    const t = arText(this, 0, -8, label, 40, '#FFFFFF', { stroke: 'rgba(0,0,0,.35)', strokeThickness: 5 });
    // أيقونة صح/غلط صغيرة فوق
    const box = this.add.container(x, y, [img, t]).setDepth(5);
    box.setSize(172, 118);
    box.setInteractive({ useHandCursor: true });
    box.on('pointerdown', () => { if (!this.locked) this.press(box, value); });
    box.on('pointerover', () => { if (!this.locked) box.setScale(1.04); });
    box.on('pointerout', () => box.setScale(1));
    return { box, img, value };
  }

  show(onPick) {
    this.onPick = onPick;
    this.locked = false;
    this.hero.setTexture('th_n');
    this.btns.forEach((b) => { b.box.setAlpha(1).setScale(0.6); b.img.clearTint(); b.box.setInteractive();
      this.tweens.add({ targets: b.box, scale: 1, duration: this.reduceMotion ? 1 : 320, ease: 'Back.easeOut' }); });
    this.children.list.filter((o) => o.depth >= 20).forEach((o) => o.destroy());
  }

  press(box, value) {
    this.locked = true;
    this.tweens.add({ targets: box, scale: 0.93, y: box.y + 6, duration: 70, yoyo: true });
    this.onPick && this.onPick(value);
  }

  /** chosen: true/false/null (الوقت خلص)، truth: الإجابة الصح */
  reveal(chosen, truth) {
    this.locked = true;
    const ok = chosen === truth;
    this.hero.setTexture(ok ? 'th_h' : 'th_x');
    this.btns.forEach((b) => {
      b.box.disableInteractive();
      const isTruth = b.value === truth;
      if (isTruth) {
        const badge = this.add.image(b.box.x + 62, b.box.y - 50, 'badge_ok').setScale(0).setDepth(30);
        this.tweens.add({ targets: badge, scale: 0.5, duration: this.reduceMotion ? 1 : 360, ease: 'Back.easeOut' });
        if (!this.reduceMotion) this.tweens.add({ targets: b.box, scale: 1.08, duration: 260, yoyo: true, repeat: 2 });
      } else {
        b.box.setAlpha(0.45);
        if (b.value === chosen) {
          const badge = this.add.image(b.box.x + 62, b.box.y - 50, 'badge_no').setScale(0).setDepth(30);
          this.tweens.add({ targets: badge, scale: 0.5, duration: this.reduceMotion ? 1 : 360, ease: 'Back.easeOut' });
        }
      }
    });
    if (!this.reduceMotion) {
      if (ok) {
        this.add.particles(this.hero.x, this.hero.y, 'p_star', {
          speed: { min: 100, max: 280 }, scale: { start: 0.8, end: 0 }, lifespan: 700,
          tint: [0xffd15c, 0xffffff, 0x34d399], emitting: false,
        }).setDepth(25).explode(14);
      } else {
        this.cameras.main.shake(180, 0.006);
        this.tweens.add({ targets: this.hero, x: this.hero.x + 8, duration: 60, yoyo: true, repeat: 3 });
      }
    }
  }
}

export async function createTfStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, TfScene);
  return {
    show: (onPick) => scene.show(onPick),
    reveal: (chosen, truth) => scene.reveal(chosen, truth),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
