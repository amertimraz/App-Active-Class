// ladder.js — «سلم المليون»: سلالم طالعة ناحية كأس في الآخر، والبطل بيطلع درجة
// مع كل إجابة صح، ولو غلط بيقع. الساحة شغّالة طول الجولة (الأسئلة والأزرار تحتها).
import { skyTexture } from './art.js';
import { heroTexture } from './characters.js';
import { boot, setupScene, arText, fontsReady } from './engine.js';

const W = 480, H = 200;
const BASE_Y = 176, TOP_Y = 66, X0 = 34, X1 = W - 104;

class LadderScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    this.total = 1; this.step = 0; this.n = 1;
    skyTexture(this, 'lsky', W, H, '#1E3A8A', '#F59E0B');
    this.add.image(0, 0, 'lsky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    for (let i = 0; i < 16; i++) {
      const s = this.add.image(Phaser.Math.Between(8, W - 8), Phaser.Math.Between(6, 90), 'p_star').setScale(Phaser.Math.FloatBetween(0.1, 0.22)).setAlpha(0.85).setDepth(-9);
      if (!this.reduceMotion) this.tweens.add({ targets: s, alpha: 0.2, duration: Phaser.Math.Between(700, 1800), yoyo: true, repeat: -1 });
    }
    heroTexture(this, 'lh_n', 'n'); heroTexture(this, 'lh_h', 'happy'); heroTexture(this, 'lh_x', 'hurt');
    this.hero = this.add.image(X0, BASE_Y - 24, 'lh_n').setScale(0.5 * 0.5).setDepth(8);
    this.stepsLayer = this.add.graphics().setDepth(2);
    this.labels = [];
    this.trophy = arText(this, W - 46, TOP_Y - 34, '🏆', 40).setDepth(3);
    if (!this.reduceMotion) this.tweens.add({ targets: this.trophy, y: this.trophy.y - 5, duration: 700, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
    this.msg = arText(this, W / 2, 28, '', 22, '#FFD15C', { stroke: '#1B1747', strokeThickness: 5 }).setDepth(30).setAlpha(0);
    data.onReady(this);
  }

  /** مكان درجة i (0 = الأرض) */
  pos(i) {
    const f = this.n === 0 ? 0 : i / this.n;
    return { x: X0 + (X1 - X0) * f, y: BASE_Y - (BASE_Y - TOP_Y) * f };
  }

  setup(total) {
    this.total = Math.max(1, total);
    this.n = Math.min(this.total, 10);
    this.step = 0;
    this.labels.forEach((l) => l.destroy()); this.labels = [];
    this.drawSteps(0);
    const p = this.pos(0);
    this.hero.setTexture('lh_n').setPosition(p.x, p.y - 24).setAngle(0).setAlpha(1);
  }

  visualStep(answered) {
    return Math.round((answered / this.total) * this.n);
  }

  drawSteps(done) {
    const g = this.stepsLayer; g.clear();
    const w = (X1 - X0) / this.n;
    for (let i = 1; i <= this.n; i++) {
      const p = this.pos(i);
      const passed = i <= done;
      g.fillStyle(0x000000, 0.22); g.fillRoundedRect(p.x - w / 2 + 3, p.y + 3, w - 4, BASE_Y - p.y + 18, 7);
      g.fillStyle(passed ? 0xFFC93C : 0x7C5BE0, 1); g.fillRoundedRect(p.x - w / 2, p.y, w - 4, BASE_Y - p.y + 16, 7);
      g.fillStyle(0xffffff, passed ? 0.5 : 0.28); g.fillRoundedRect(p.x - w / 2 + 3, p.y + 3, w - 10, 6, 3);
    }
    if (!this.labels.length) {
      for (let i = 1; i <= this.n; i++) {
        const p = this.pos(i), w = (X1 - X0) / this.n;
        this.labels.push(arText(this, p.x - 2 - w / 2 + (w - 4) / 2, p.y + 16, String(Math.round((i / this.n) * this.total)), 13, '#FFFFFF', { stroke: 'rgba(0,0,0,.4)', strokeThickness: 3 }).setDepth(3));
      }
    }
  }

  say(text, color = '#FFD15C') {
    this.msg.setText(text).setColor(color).setAlpha(1).setScale(0.3);
    this.tweens.add({ targets: this.msg, scale: 1, duration: 220, ease: 'Back.easeOut' });
    this.tweens.add({ targets: this.msg, alpha: 0, duration: 380, delay: 800 });
  }

  /** إجابة صح: يطلع للدرجة المقابلة لعدد الإجابات الصح */
  climb(correctCount) {
    const target = this.visualStep(correctCount);
    this.drawSteps(target);
    const p = this.pos(target);
    this.hero.setTexture('lh_h');
    if (this.reduceMotion) { this.hero.setPosition(p.x, p.y - 24); return; }
    this.tweens.add({ targets: this.hero, x: p.x, y: p.y - 24, duration: 520, ease: 'Cubic.easeInOut' });
    this.tweens.add({ targets: this.hero, scaleY: 0.5 * 0.5 * 1.18, duration: 160, yoyo: true, delay: 40 });
    this.add.particles(p.x, p.y - 20, 'p_star', {
      speed: { min: 60, max: 180 }, angle: { min: 200, max: 340 }, scale: { start: 0.6, end: 0 },
      lifespan: 600, tint: [0xffd15c, 0xffffff], emitting: false,
    }).setDepth(20).explode(8);
    this.say('طلعت درجة!');
    this.time.delayedCall(900, () => this.hero.setTexture('lh_n'));
  }

  /** غلط: البطل يقع للأرض */
  fall() {
    this.hero.setTexture('lh_x');
    const p = this.pos(0);
    this.drawSteps(this.visualStep(0));
    if (this.reduceMotion) { this.hero.setPosition(p.x, p.y - 20); this.hero.setAngle(90); return; }
    this.cameras.main.shake(220, 0.008);
    this.tweens.add({ targets: this.hero, x: p.x + 8, y: BASE_Y - 14, angle: 720, duration: 750, ease: 'Bounce.easeOut' });
    this.say('وقعت من السلم!', '#FF8A8A');
  }

  win() {
    const p = this.pos(this.n);
    this.hero.setTexture('lh_h');
    this.tweens.add({ targets: this.hero, x: p.x, y: p.y - 24, duration: 500 });
    this.add.particles(W / 2, -10, 'p_conf', {
      x: { min: 20, max: W - 20 }, speedY: { min: 90, max: 240 }, rotate: { min: 0, max: 360 }, scale: { min: 0.5, max: 1 },
      lifespan: 1500, gravityY: 260, duration: 900, frequency: 20, quantity: 2,
      tint: [0xffd15c, 0xf472b6, 0x34d399, 0x60a5fa, 0xffffff],
    }).setDepth(40);
    this.say('وصلت للكأس! 🏆');
  }
}

export async function createLadderStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, LadderScene);
  return {
    setup: (total) => scene.setup(total),
    climb: (correctCount) => scene.climb(correctCount),
    fall: () => scene.fall(),
    win: () => scene.win(),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
