// monster.js — «معركة الوحش»: وحش كرتوني قدّامك، كل إجابة صح بتضربه وتنقّص طاقته،
// وكل غلط أو وقت بيخلّص بيضربك وتخسر قلب (معاك 3). الساحة شغّالة طول الجولة.
import { skyTexture, hillsTexture, treesTexture } from './art.js';
import { heroTexture, swordTexture, monsterTexture } from './characters.js';
import { boot, setupScene, arText, fontsReady } from './engine.js';

const W = 480, H = 250;
const GROUND = 196;
const HERO_X = 112, MON_X = 372;

class MonsterScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.total = 1; this.monsterHp = 1; this.hearts = 3; this.timeFrac = 1; this.busy = 0;

    skyTexture(this, 'msky', W, H, '#5B3FD1', '#F9A8D4');
    this.add.image(0, 0, 'msky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    // نجوم صغيرة
    for (let i = 0; i < 14; i++) {
      const s = this.add.image(Phaser.Math.Between(10, W - 10), Phaser.Math.Between(8, 90), 'p_star')
        .setScale(Phaser.Math.FloatBetween(0.12, 0.25)).setAlpha(0.8).setDepth(-9);
      if (!this.reduceMotion) this.tweens.add({ targets: s, alpha: 0.25, duration: Phaser.Math.Between(700, 1600), yoyo: true, repeat: -1 });
    }
    hillsTexture(this, 'mh1', W, 120, '#7C5BE0', 16, 1, 0.8);
    hillsTexture(this, 'mh2', W, 110, '#3FBF7A', 12, 2, 2.2);
    treesTexture(this, 'mtr', W, 70);
    this.add.image(0, GROUND - 130, 'mh1').setOrigin(0).setDisplaySize(W, 120).setDepth(-8);
    this.add.image(0, GROUND - 92, 'mh2').setOrigin(0).setDisplaySize(W, 110).setDepth(-7);
    this.add.image(0, GROUND - 56, 'mtr').setOrigin(0).setDisplaySize(W, 70).setDepth(-6);
    const g = this.add.graphics().setDepth(-5);
    g.fillStyle(0x38B26B, 1); g.fillRect(0, GROUND, W, H - GROUND);
    g.fillStyle(0x2E9A5B, 1); g.fillRect(0, GROUND, W, 6);

    heroTexture(this, 'h_n', 'n'); heroTexture(this, 'h_h', 'happy'); heroTexture(this, 'h_x', 'hurt');
    swordTexture(this);
    this.monColor = '#22A06B';
    monsterTexture(this, 'm_n', this.monColor, 'n'); monsterTexture(this, 'm_a', this.monColor, 'angry'); monsterTexture(this, 'm_x', this.monColor, 'hurt');

    this.hero = this.add.image(HERO_X, GROUND - 30, 'h_n').setScale(0.5 * 0.95).setDepth(3);
    this.sword = this.add.image(HERO_X + 36, GROUND - 38, 'sword').setScale(0.5 * 0.9).setOrigin(0.15, 0.5).setDepth(4).setAngle(-50);
    this.mon = this.add.image(MON_X, GROUND - 50, 'm_n').setScale(0.5 * 0.78).setDepth(3);
    this.hud = this.add.graphics().setDepth(20);
    this.msg = arText(this, W / 2, 62, '', 24, '#FFD15C', { stroke: '#1B1747', strokeThickness: 5 }).setDepth(30).setAlpha(0);
    this.heroBase = { x: this.hero.x, y: this.hero.y };
    this.monBase = { x: this.mon.x, y: this.mon.y };
    if (!this.reduceMotion) {
      this.tweens.add({ targets: this.hero, y: this.hero.y - 4, duration: 700, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
      this.tweens.add({ targets: this.mon, scaleY: this.mon.scaleY * 1.04, scaleX: this.mon.scaleX * 0.98, duration: 900, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
    }
    this.drawHud();
    data.onReady(this);
  }

  drawHud() {
    const g = this.hud; g.clear();
    // طاقة الوحش
    const bx = 262, by = 16, bw = 196, bh = 14;
    const f = Phaser.Math.Clamp(this.monsterHp / this.total, 0, 1);
    g.fillStyle(0x000000, 0.35); g.fillRoundedRect(bx - 3, by - 3, bw + 6, bh + 6, 9);
    g.fillStyle(0x3A1A1A, 1); g.fillRoundedRect(bx, by, bw, bh, 7);
    const col = f > 0.5 ? 0x34D399 : f > 0.25 ? 0xFBBF24 : 0xF43F5E;
    if (f > 0) { g.fillStyle(col, 1); g.fillRoundedRect(bx, by, Math.max(10, bw * f), bh, 7); }
    g.fillStyle(0xffffff, 0.3); g.fillRoundedRect(bx + 3, by + 2, Math.max(0, bw * f - 6), 4, 2);
    // قلوب البطل
    for (let i = 0; i < 3; i++) this.heart(g, 24 + i * 30, 24, i < this.hearts);
  }

  heart(g, x, y, full) {
    g.fillStyle(full ? 0xF43F5E : 0x000000, full ? 1 : 0.35);
    g.fillCircle(x - 5, y - 3, 7); g.fillCircle(x + 5, y - 3, 7);
    g.fillTriangle(x - 12, y, x + 12, y, x, y + 14);
    if (full) { g.fillStyle(0xffffff, 0.5); g.fillCircle(x - 7, y - 5, 2.5); }
  }

  say(text, color = '#FFD15C') {
    this.msg.setText(text).setColor(color).setAlpha(1).setScale(0.3).setY(70);
    this.tweens.add({ targets: this.msg, scale: 1, duration: 220, ease: 'Back.easeOut' });
    this.tweens.add({ targets: this.msg, alpha: 0, y: 48, duration: 380, delay: 700 });
  }

  setTime(frac) {
    this.timeFrac = Phaser.Math.Clamp(frac, 0, 1);
    if (this.busy) return;
    const angry = this.timeFrac < 0.3;
    this.mon.setTexture(angry ? 'm_a' : 'm_n');
    this.mon.x = this.monBase.x + (angry && !this.reduceMotion ? Math.sin(this.time.now / 40) * 2.2 : 0);
  }

  hit() {
    this.busy++;
    const sw = this.sword;
    this.tweens.add({ targets: this.hero, x: MON_X - 96, duration: 170, ease: 'Cubic.easeIn' });
    this.tweens.add({ targets: sw, x: MON_X - 60, y: GROUND - 44, duration: 170, ease: 'Cubic.easeIn' });
    this.tweens.add({ targets: sw, angle: 60, duration: 220, delay: 120, ease: 'Cubic.easeIn' });
    this.time.delayedCall(260, () => {
      this.mon.setTexture('m_x');
      this.cameras.main.shake(180, 0.007);
      this.flash(this.mon, 0xffffff);
      this.add.particles(MON_X - 40, GROUND - 64, 'p_star', {
        speed: { min: 120, max: 320 }, angle: { min: 180, max: 360 }, scale: { start: 0.9, end: 0 },
        lifespan: 520, tint: [0xffd15c, 0xffffff, 0xff8a3d], emitting: false,
      }).setDepth(25).explode(10);
      this.add.particles(MON_X - 40, GROUND - 64, 'p_ring', { scale: { start: 0.1, end: 0.9 }, alpha: { start: 0.9, end: 0 }, lifespan: 360, emitting: false }).setDepth(24).explode(1);
      this.monsterHp = Math.max(0, this.monsterHp - 1);
      this.tweens.addCounter({ from: 0, to: 1, duration: 300, onUpdate: () => this.drawHud() });
      this.say('ضربة!');
      this.tweens.add({ targets: this.mon, x: this.monBase.x + 16, duration: 90, yoyo: true });
    });
    this.time.delayedCall(620, () => {
      this.tweens.add({ targets: this.hero, x: HERO_X, duration: 260, ease: 'Cubic.easeOut' });
      this.tweens.add({ targets: sw, x: HERO_X + 36, y: GROUND - 38, angle: -50, duration: 260 });
      this.mon.setTexture('m_n');
      this.busy--;
    });
  }

  getHit(timeout) {
    this.busy++;
    this.tweens.add({ targets: this.mon, x: HERO_X + 120, duration: 200, ease: 'Cubic.easeIn' });
    this.time.delayedCall(230, () => {
      this.hero.setTexture('h_x');
      this.cameras.main.shake(220, 0.01);
      this.flash(this.hero, 0xff5577);
      this.hearts = Math.max(0, this.hearts - 1);
      this.drawHud();
      this.add.particles(24 + this.hearts * 30, 24, 'p_conf', {
        speed: { min: 60, max: 180 }, angle: { min: 200, max: 340 }, scale: { start: 0.9, end: 0 },
        lifespan: 600, gravityY: 400, tint: 0xf43f5e, emitting: false,
      }).setDepth(25).explode(10);
      this.tweens.add({ targets: this.hero, x: HERO_X - 24, duration: 120, yoyo: true });
      this.say(timeout ? 'الوقت خلص!' : 'آخ!', '#FF8A8A');
    });
    this.time.delayedCall(700, () => {
      this.tweens.add({ targets: this.mon, x: this.monBase.x, duration: 300, ease: 'Cubic.easeOut' });
      this.hero.setTexture('h_n');
      this.busy--;
    });
  }

  flash(obj, color) {
    obj.setTintFill(color);
    this.time.delayedCall(90, () => obj.clearTint());
  }

  finish(win) {
    this.busy++;
    if (win) {
      this.hero.setTexture('h_h');
      this.mon.setTexture('m_x');
      this.tweens.add({ targets: this.mon, angle: 540, scale: 0, alpha: 0, duration: 900, ease: 'Cubic.easeIn' });
      this.add.particles(MON_X, GROUND - 60, 'p_conf', {
        speed: { min: 80, max: 320 }, angle: { min: 0, max: 360 }, scale: { start: 1, end: 0.2 },
        lifespan: 1200, gravityY: 300, tint: [0xffd15c, 0xf472b6, 0x34d399, 0x60a5fa], emitting: false,
      }).setDepth(25).explode(36);
      this.say('هزمت الوحش! 🏆');
    } else {
      this.hero.setTexture('h_x');
      this.mon.setTexture('m_n');
      this.tweens.add({ targets: this.mon, scale: this.mon.scale * 1.12, duration: 260, yoyo: true, repeat: 2 });
      this.say('الوحش كسب…', '#FF8A8A');
    }
  }
}

export async function createMonsterStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, MonsterScene);
  return {
    setup: (total) => { scene.total = Math.max(1, total); scene.monsterHp = scene.total; scene.hearts = 3; scene.drawHud(); },
    setTime: (f) => scene.setTime(f),
    answer: (ok, timeout) => (ok ? scene.hit() : scene.getHit(timeout)),
    finish: (win) => scene.finish(win),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
