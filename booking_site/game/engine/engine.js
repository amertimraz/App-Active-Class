// engine.js — نواة المحرك المشتركة: إقلاع Phaser بحجم منطقي ثابت (يتكبّر على
// الشاشات الحادة)، نص عربي واضح، وكشف الدعم عشان نرجع للنظام القديم لو فشل.
import { particleTextures } from './art.js';

export const dpr = () => Math.min(2, window.devicePixelRatio || 1);

export function supported() {
  try {
    if (!window.Phaser) return false;
    const c = document.createElement('canvas');
    return !!(c.getContext('webgl') || c.getContext('2d'));
  } catch (e) { return false; }
}

/** نستنى خط Cairo (بحد أقصى ثانية ونص) عشان النص يترسم بالخط الصح. */
export async function fontsReady() {
  try {
    await Promise.race([
      document.fonts.load('800 22px Cairo').then(() => document.fonts.load('600 16px Cairo')),
      new Promise((r) => setTimeout(r, 1500)),
    ]);
  } catch (e) { /* نكمّل بالخط الاحتياطي */ }
}

/**
 * يقلّع Phaser جوّه host بحجم منطقي W×H. بيرجّع { game, scene } بعد ما
 * المشهد يخلّص create. الكاميرا بتتكبّر بنسبة dpr عشان الرسم يبقى حاد.
 */
export function boot(host, W, H, SceneClass, data = {}) {
  const S = dpr();
  return new Promise((resolve, reject) => {
    let game;
    try {
      game = new Phaser.Game({
        type: Phaser.AUTO,
        parent: host,
        width: Math.round(W * S),
        height: Math.round(H * S),
        transparent: true,
        banner: false,
        audio: { noAudio: true },
        input: { touch: { capture: false }, mouse: { preventDefaultWheel: false } },
        render: { antialias: true, powerPreference: 'low-power' },
        fps: { target: 60 },
        scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_HORIZONTALLY },
      });
    } catch (e) { reject(e); return; }
    if (location.hostname === 'localhost') (window.__games = window.__games || []).push(game);
    const timeout = setTimeout(() => reject(new Error('stage boot timeout')), 6000);
    game.scene.add('main', SceneClass, true, {
      ...data, W, H, S,
      onReady: (scene) => { clearTimeout(timeout); resolve({ game, scene }); },
    });
  });
}

/** يجهّز الكاميرا والجسيمات — بيتنادى أول حاجة في create(). */
export function setupScene(scene, data) {
  scene.W = data.W; scene.H = data.H; scene.S = data.S;
  const cam = scene.cameras.main;
  cam.setZoom(data.S);
  cam.centerOn(data.W / 2, data.H / 2);
  particleTextures(scene);
  scene.reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/** نص عربي: Cairo + دقة عالية (الاتجاه من الصفحة). */
export function arText(scene, x, y, str, size, color = '#fff', extra = {}) {
  const t = scene.add.text(x, y, str, {
    fontFamily: 'Cairo, Tahoma, sans-serif',
    fontStyle: extra.weight || '800',
    fontSize: `${size}px`,
    color,
    align: 'center',
    // مفيش rtl:true — مع resolution>1 بيرسم نص فاضي في Phaser. الاتجاه بيتورّث من الصفحة (dir=rtl).
    resolution: Math.max(2, scene.S || 1),
    wordWrap: extra.width ? { width: extra.width, useAdvancedWrap: true } : undefined,
    stroke: extra.stroke,
    strokeThickness: extra.strokeThickness || 0,
    shadow: extra.shadow,
    lineSpacing: extra.lineSpacing ?? 2,
  });
  t.setOrigin(extra.ox ?? 0.5, extra.oy ?? 0.5);
  return t;
}

const _measure = document.createElement('canvas').getContext('2d');
/** يصغّر خط النص لحد ما يدخل في maxW×maxH، ومن غير ما أي كلمة تتقطّع نص نص. */
export function fitText(t, maxW, maxH, startSize, minSize = 11) {
  const words = String(t.text).split(/\s+/).filter(Boolean);
  const weight = t.style.fontStyle || '800';
  const longest = (size) => {
    _measure.font = `${weight} ${size}px Cairo, Tahoma, sans-serif`;
    return words.reduce((m, w) => Math.max(m, _measure.measureText(w).width), 0);
  };
  let size = startSize;
  t.setWordWrapWidth(maxW, true);
  t.setFontSize(size);
  while (size > minSize && (longest(size) > maxW || t.height > maxH)) {
    size -= 1;
    t.setFontSize(size);
  }
  return t;
}

export const BALLOON_COLORS = ['#FF5C7A', '#FFB020', '#34C759', '#3B9CFF', '#B06BFF', '#FF7AC8'];
