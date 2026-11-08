// race.js — «سباق الأسئلة» بمحرك Phaser: طريق بخلفيات متحرّكة (parallax)،
// عربيتك الحمرا ضد روبوت بنفسجي بيطاردك — كل ما الوقت يخلص بيقرّب منك،
// وكل إجابة صح بتديك نيترو. الساحة بتفضل شغّالة طول الجولة (مش بتتعمل كل سؤال).
import {
  skyTexture, cloudTexture, hillsTexture, treesTexture, roadTexture, carTexture,
  wheelTexture, flagTexture, makeTexture,
} from './art.js';
import { boot, setupScene, arText, fontsReady } from './engine.js';

const W = 480, H = 190;
const ROAD_Y = 150, ROAD_H = 40, LANE_Y = 172;
const START_X = 112, END_X = W - 118;

class RaceScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.speed = 160; this.targetSpeed = 160;
    this.progress = 0; this.timeFrac = 1; this.total = 1;
    this.bumpT = 0; this.finished = false;

    skyTexture(this, 'rsky', W, H, '#34B2FF', '#CDEFFF');
    this.add.image(0, 0, 'rsky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    cloudTexture(this, 'rc1', 130, 56, 1);
    this.clouds = this.add.tileSprite(0, 18, W, 60, makeTexture(this, 'rclouds', W, 60, (c) => {
      [[40, 28, 1], [190, 18, .8], [330, 34, 1.1], [440, 14, .7]].forEach(([x, y, s]) => {
        c.fillStyle = 'rgba(255,255,255,.95)';
        [[0, 0, 15], [14, -6, 19], [30, 0, 15], [14, 6, 14]].forEach(([dx, dy, r]) => { c.beginPath(); c.arc(x + dx * s, y + dy * s, r * s, 0, 7); c.fill(); });
      });
    })).setOrigin(0).setTileScale(.5, .5).setDepth(-9);

    hillsTexture(this, 'rhill1', W, 120, '#93E6B6', 16, 1, .4);
    hillsTexture(this, 'rhill2', W, 110, '#45C985', 12, 2, 1.6);
    treesTexture(this, 'rtrees', W, 70);
    this.hill1 = this.add.tileSprite(0, ROAD_Y - 78, W, 120, 'rhill1').setOrigin(0).setTileScale(.5, .5).setDepth(-8);
    this.hill2 = this.add.tileSprite(0, ROAD_Y - 62, W, 110, 'rhill2').setOrigin(0).setTileScale(.5, .5).setDepth(-7);
    this.trees = this.add.tileSprite(0, ROAD_Y - 36, W, 70, 'rtrees').setOrigin(0).setTileScale(.5, .5).setDepth(-6);
    roadTexture(this, 'rroad', W, ROAD_H);
    this.road = this.add.tileSprite(0, ROAD_Y, W, ROAD_H, 'rroad').setOrigin(0).setTileScale(.5, .5).setDepth(-5);

    flagTexture(this, 'rflag');
    this.flag = this.add.image(W - 30, ROAD_Y - 18, 'rflag').setScale(.5).setDepth(-4).setAlpha(.0);

    carTexture(this, 'carMe', '#FF4D6D'); carTexture(this, 'carRival', '#8B5CF6', '#FFB3D9');
    wheelTexture(this);
    this.me = this.makeCar('carMe', 1);
    this.rival = this.makeCar('carRival', .78);
    this.me.box.setPosition(START_X, LANE_Y - 4);
    this.rival.box.setPosition(START_X - 150, LANE_Y);

    this.exhaust = this.add.particles(0, 0, 'p_puff', {
      follow: this.me.box, followOffset: { x: -50, y: 10 },
      speed: { min: 10, max: 40 }, angle: { min: 170, max: 190 },
      scale: { start: .35, end: 1 }, alpha: { start: .55, end: 0 }, lifespan: 520, frequency: 60, tint: 0xffffff,
    }).setDepth(2);
    this.flames = this.add.particles(0, 0, 'p_puff', {
      follow: this.me.box, followOffset: { x: -52, y: 12 },
      speed: { min: 80, max: 200 }, angle: { min: 172, max: 188 }, scale: { start: .5, end: .05 },
      alpha: { start: 1, end: 0 }, lifespan: 300, frequency: -1, tint: [0xffd15c, 0xff8a3d, 0xff4d6d],
    }).setDepth(2);

    this.lines = this.add.graphics().setDepth(3);
    this.hud = this.add.graphics().setDepth(10);
    this.drawHud();
    data.onReady(this);
  }

  makeCar(key, s) {
    const body = this.add.image(0, 0, key).setScale(.5);
    const w1 = this.add.image(-28, 17, 'wheel').setScale(.5);
    const w2 = this.add.image(28, 17, 'wheel').setScale(.5);
    const box = this.add.container(0, 0, [body, w1, w2]).setScale(s * 1.0).setDepth(2);
    return { box, body, w1, w2, wob: 0 };
  }

  drawHud() {
    const g = this.hud; g.clear();
    const x0 = 28, x1 = W - 28, y = 12;
    g.fillStyle(0x000000, .22); g.fillRoundedRect(x0, y - 4, x1 - x0, 8, 4);
    const px = x0 + (x1 - x0) * this.progress;
    g.fillStyle(0xffd15c, 1); g.fillRoundedRect(x0, y - 4, Math.max(8, px - x0), 8, 4);
    g.fillStyle(0xffffff, 1); g.fillCircle(px, y, 7);
    g.fillStyle(0xff4d6d, 1); g.fillCircle(px, y, 4.5);
    g.fillStyle(0x14172b, 1); g.fillRect(x1 - 1, y - 10, 3, 20);
    g.fillStyle(0xffffff, 1); g.fillRect(x1 + 2, y - 10, 9, 5); g.fillStyle(0x14172b, 1); g.fillRect(x1 + 2, y - 5, 9, 5);
  }

  update(_, dtMs) {
    const dt = Math.min(dtMs, 50) / 1000;
    const k = this.reduceMotion ? 0.25 : 1;
    this.speed += (this.targetSpeed - this.speed) * Math.min(1, dt * 5);
    const v = this.speed * dt * k;
    this.clouds.tilePositionX += v * .05 / .5;
    this.hill1.tilePositionX += v * .18 / .5;
    this.hill2.tilePositionX += v * .35 / .5;
    this.trees.tilePositionX += v * .7 / .5;
    this.road.tilePositionX += v * 1.4 / .5;
    const spin = this.speed * dt * 0.09 * k;
    [this.me, this.rival].forEach((c) => { c.w1.rotation += spin; c.w2.rotation += spin; });
    const t = this.time.now / 1000;
    // العربية بتهتز هزّة طريق خفيفة
    this.me.box.y = LANE_Y - 4 + (this.reduceMotion ? 0 : Math.sin(t * 14) * .8 * (this.speed / 300));
    this.me.box.angle = Math.sin(t * 6) * .6 + this.me.wob;
    // الروبوت: بيقرّب كل ما الوقت يقل
    const gap = 46 + 150 * Math.pow(this.timeFrac, .85);
    const rx = this.me.box.x - gap + (this.bumpT > 0 ? 36 : 0);
    this.rival.box.x += (rx - this.rival.box.x) * Math.min(1, dt * 6);
    this.rival.box.y = LANE_Y + 6 + Math.sin(t * 13 + 1) * .9;
    if (this.bumpT > 0) this.bumpT -= dt;
    // خطوط السرعة
    const g = this.lines; g.clear();
    if (this.speed > 330 && !this.reduceMotion) {
      g.lineStyle(2, 0xffffff, .55);
      for (let i = 0; i < 7; i++) {
        const y = ROAD_Y - 70 + ((i * 41 + t * 700) % 120);
        const x = ((t * (500 + i * 70) + i * 90) % (W + 120)) - 60;
        g.lineBetween(W - x, y, W - x + 38 + this.speed * .05, y);
      }
    }
    this.exhaust.frequency = this.speed > 300 ? 30 : 70;
    this.flag.setAlpha(Phaser.Math.Clamp((this.progress - .55) * 2.2, 0, 1));
  }

  // ── واجهة من الصفحة ────────────────────────────────────
  setTotal(n) { this.total = Math.max(1, n); }
  setTime(frac) { this.timeFrac = Phaser.Math.Clamp(frac, 0, 1); }

  setProgress(p, animate = true) {
    const target = Phaser.Math.Clamp(p, 0, 1);
    const toX = START_X + (END_X - START_X) * target;
    if (!animate || this.reduceMotion) {
      this.progress = target; this.me.box.x = toX; this.drawHud(); return;
    }
    this.tweens.add({
      targets: this, progress: target, duration: 900, ease: 'Cubic.easeInOut',
      onUpdate: () => this.drawHud(),
    });
    this.tweens.add({ targets: this.me.box, x: toX, duration: 900, ease: 'Cubic.easeInOut' });
  }

  answer(ok, streak, timeout) {
    if (this.reduceMotion) { return; }
    if (ok) {
      this.targetSpeed = 700;
      this.flames.explode(14);
      this.cameras.main.shake(160, .004);
      this.add.particles(this.me.box.x, this.me.box.y - 20, 'p_star', {
        speed: { min: 60, max: 200 }, angle: { min: 200, max: 340 }, scale: { start: .8, end: 0 },
        lifespan: 700, gravityY: 300, tint: [0xffd15c, 0xffffff, 0xff8a3d], emitting: false,
      }).setDepth(12).explode(streak >= 3 ? 16 : 9);
      const lbl = arText(this, this.me.box.x + 10, this.me.box.y - 46, streak >= 3 ? 'نيترو! 🔥' : 'سريع!', 18, '#FFD15C', {
        stroke: '#1B1747', strokeThickness: 4,
      }).setDepth(14).setScale(.2);
      this.tweens.add({ targets: lbl, scale: 1, y: lbl.y - 14, duration: 260, ease: 'Back.easeOut' });
      this.tweens.add({ targets: lbl, alpha: 0, y: lbl.y - 34, duration: 480, delay: 620, onComplete: () => lbl.destroy() });
      this.time.delayedCall(1100, () => { this.targetSpeed = 160; });
    } else {
      this.targetSpeed = 30;
      this.tweens.add({ targets: this.me, wob: { from: -9, to: 0 }, duration: 600, ease: 'Elastic.easeOut' });
      this.add.particles(this.me.box.x - 20, this.me.box.y + 4, 'p_puff', {
        speed: { min: 20, max: 80 }, scale: { start: .8, end: 2.6 }, alpha: { start: .85, end: 0 },
        lifespan: 800, tint: 0x555070, emitting: false,
      }).setDepth(12).explode(7);
      if (timeout) { this.bumpT = .7; this.cameras.main.shake(220, .007); }
      this.time.delayedCall(900, () => { this.targetSpeed = 160; });
    }
  }

  finishRun(good) {
    this.finished = true;
    this.targetSpeed = good ? 520 : 60;
    if (good && !this.reduceMotion) {
      this.add.particles(W / 2, -10, 'p_conf', {
        x: { min: 20, max: W - 20 }, speedY: { min: 90, max: 240 }, rotate: { min: 0, max: 360 },
        scale: { min: .5, max: 1 }, lifespan: 1600, gravityY: 260, duration: 900, frequency: 20, quantity: 2,
        tint: [0xffd15c, 0xf472b6, 0x34d399, 0x60a5fa, 0xffffff],
      }).setDepth(40);
    }
  }
}

export async function createRaceStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, RaceScene);
  return {
    setTotal: (n) => scene.setTotal(n),
    setTime: (f) => scene.setTime(f),
    setProgress: (p, animate) => scene.setProgress(p, animate),
    answer: (ok, streak, timeout) => scene.answer(ok, streak, timeout),
    finish: (good) => scene.finishRun(good),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
