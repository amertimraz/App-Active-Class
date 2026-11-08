// wheel.js — «عجلة الحظ»: بعد كل إجابة صح الطالب بيلف عجلة بنقاط مكافأة.
// القطاعات بتترسم بالكود، واللفّة بتبطّأ لحد ما تقف على القطاع الفايز.
import { skyTexture, makeTexture, lighten, darken } from './art.js';
import { boot, setupScene, arText, fontsReady } from './engine.js';

const W = 480, H = 330;
const CX = W / 2, CY = 170, R = 128;

/** قطاعات العجلة: kind: x2 (يضاعف نقاط السؤال) | add (نقاط) | zero */
export const WHEEL_SEGMENTS = [
  { label: '×2', kind: 'x2', value: 2, color: '#F59E0B', weight: 1 },
  { label: '+50', kind: 'add', value: 50, color: '#3B82F6', weight: 2 },
  { label: '+300', kind: 'add', value: 300, color: '#10B981', weight: 1 },
  { label: 'صفر', kind: 'zero', value: 0, color: '#94A3B8', weight: 1 },
  { label: '+100', kind: 'add', value: 100, color: '#EC4899', weight: 2 },
  { label: '+500', kind: 'add', value: 500, color: '#8B5CF6', weight: 1 },
  { label: '+200', kind: 'add', value: 200, color: '#EF4444', weight: 2 },
  { label: '+150', kind: 'add', value: 150, color: '#06B6D4', weight: 2 },
];

export function pickWheelIndex(rand = Math.random) {
  const total = WHEEL_SEGMENTS.reduce((s, x) => s + x.weight, 0);
  let r = rand() * total;
  for (let i = 0; i < WHEEL_SEGMENTS.length; i++) {
    r -= WHEEL_SEGMENTS[i].weight;
    if (r < 0) return i;
  }
  return WHEEL_SEGMENTS.length - 1;
}

class WheelScene extends Phaser.Scene {
  create(data) {
    setupScene(this, data);
    skyTexture(this, 'wsky', W, H, '#7C2D12', '#F59E0B');
    this.add.image(0, 0, 'wsky').setOrigin(0).setDisplaySize(W, H).setDepth(-10);
    if (!this.reduceMotion) {
      // أضواء مسرح بتلمع
      for (let i = 0; i < 18; i++) {
        const a = (Math.PI * 2 * i) / 18;
        const d = this.add.image(CX + Math.cos(a) * (R + 22), CY + Math.sin(a) * (R + 22), 'p_dot').setScale(1.2).setDepth(2);
        this.tweens.add({ targets: d, alpha: 0.25, duration: 420, yoyo: true, repeat: -1, delay: i * 55 });
      }
    }
    // جسم العجلة
    const n = WHEEL_SEGMENTS.length, ang = (Math.PI * 2) / n;
    const key = makeTexture(this, 'wheel_body', R * 2 + 24, R * 2 + 24, (c, w, h) => {
      c.translate(w / 2, h / 2);
      c.fillStyle = '#5B2A0A'; c.beginPath(); c.arc(0, 0, R + 11, 0, 7); c.fill();
      c.fillStyle = '#FFD15C'; c.beginPath(); c.arc(0, 0, R + 6, 0, 7); c.fill();
      WHEEL_SEGMENTS.forEach((s, i) => {
        c.save(); c.rotate(i * ang - Math.PI / 2 - ang / 2);
        const g = c.createRadialGradient(0, 0, 10, 0, 0, R);
        g.addColorStop(0, lighten(s.color, 0.35)); g.addColorStop(1, s.color);
        c.fillStyle = g; c.beginPath(); c.moveTo(0, 0); c.arc(0, 0, R, 0, ang); c.closePath(); c.fill();
        c.strokeStyle = 'rgba(255,255,255,.85)'; c.lineWidth = 2.5; c.stroke();
        c.rotate(ang / 2);
        c.fillStyle = '#fff'; c.strokeStyle = darken(s.color, 0.5); c.lineWidth = 4;
        c.font = '800 24px Cairo, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle';
        c.strokeText(s.label, R * 0.62, 0); c.fillText(s.label, R * 0.62, 0);
        c.restore();
      });
      c.fillStyle = '#fff'; c.beginPath(); c.arc(0, 0, 18, 0, 7); c.fill();
      c.fillStyle = '#F59E0B'; c.beginPath(); c.arc(0, 0, 11, 0, 7); c.fill();
    });
    this.wheel = this.add.image(CX, CY, key).setScale(0.5).setDepth(3);
    // المؤشّر
    const g = this.add.graphics().setDepth(6);
    g.fillStyle(0x000000, 0.25); g.fillTriangle(CX - 16, 22, CX + 16, 22, CX, 62);
    g.fillStyle(0xff3355, 1); g.fillTriangle(CX - 15, 18, CX + 15, 18, CX, 58);
    g.lineStyle(3, 0xffffff, 1); g.strokeTriangle(CX - 15, 18, CX + 15, 18, CX, 58);
    this.result = arText(this, CX, H - 26, '', 24, '#FFFFFF', { stroke: '#5B2A0A', strokeThickness: 5 }).setDepth(10);
    data.onReady(this);
  }

  spin(index) {
    return new Promise((resolve) => {
      const n = WHEEL_SEGMENTS.length, seg = 360 / n;
      // القطاع i مركزه على زاوية i*seg (من فوق). نلف لحد ما مركزه يوصل المؤشّر.
      const target = 360 * (this.reduceMotion ? 1 : 5) - index * seg + Phaser.Math.Between(-Math.floor(seg * 0.3), Math.floor(seg * 0.3));
      this.wheel.setAngle(0);
      this.tweens.add({
        targets: this.wheel, angle: target, duration: this.reduceMotion ? 300 : 4200, ease: 'Cubic.easeOut',
        onComplete: () => {
          const s = WHEEL_SEGMENTS[index];
          this.result.setText(s.kind === 'zero' ? 'حظ أوفر المرة الجاية' : s.kind === 'x2' ? 'نقاطك اتضاعفت! ×2' : `مكافأة ${s.label} نقطة`);
          if (s.kind !== 'zero' && !this.reduceMotion) {
            this.add.particles(CX, CY, 'p_conf', {
              speed: { min: 120, max: 360 }, angle: { min: 0, max: 360 }, scale: { start: 1, end: 0.2 },
              lifespan: 1100, gravityY: 320, tint: [0xffd15c, 0xf472b6, 0x34d399, 0x60a5fa, 0xffffff], emitting: false,
            }).setDepth(20).explode(40);
            this.tweens.add({ targets: this.wheel, scale: 0.54, duration: 160, yoyo: true });
          }
          resolve(index);
        },
      });
    });
  }
}

export async function createWheelStage(host) {
  await fontsReady();
  const { game, scene } = await boot(host, W, H, WheelScene);
  return {
    spin: (index) => scene.spin(index),
    destroy: () => { try { game.destroy(true); } catch (e) { /* ignore */ } },
    game, aspect: W / H,
  };
}
