// art.js — رسومات كرتونية بالكود (Canvas 2D) تتحوّل لـ textures جوّه Phaser.
// مفيش ملفات صور: كل حاجة بتتولّد وقت التشغيل، فصفحة اللعبة تفضل خفيفة.

export const R = 2; // دقة الـtexture (2× عشان الشاشات الحادة)

export function hex(c) {
  const n = parseInt(c.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
export function mix(a, b, t) {
  const A = hex(a), B = hex(b);
  const m = A.map((v, i) => Math.round(v + (B[i] - v) * t));
  return `rgb(${m[0]},${m[1]},${m[2]})`;
}
export const lighten = (c, t) => mix(c, '#ffffff', t);
export const darken = (c, t) => mix(c, '#1b1747', t);

/** ينشئ CanvasTexture بحجم منطقي (w×h) ويرسم عليه بدالة draw(ctx,w,h). */
export function makeTexture(scene, key, w, h, draw) {
  if (scene.textures.exists(key)) return key;
  const tex = scene.textures.createCanvas(key, Math.ceil(w * R), Math.ceil(h * R));
  const ctx = tex.getContext();
  ctx.scale(R, R);
  draw(ctx, w, h);
  tex.refresh();
  return key;
}

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
export { rr as roundRect };

// ── خلفية السما ──────────────────────────────────────────────
export function skyTexture(scene, key, w, h, top = '#2BA8FF', bottom = '#BDEBFF') {
  return makeTexture(scene, key, w, h, (c) => {
    const g = c.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, top); g.addColorStop(1, bottom);
    c.fillStyle = g; c.fillRect(0, 0, w, h);
  });
}

// ── شمس بوش مبتسم ───────────────────────────────────────────
export function sunTexture(scene, key = 'sun') {
  return makeTexture(scene, key, 120, 120, (c) => {
    c.translate(60, 60);
    c.fillStyle = 'rgba(255,224,102,.35)';
    for (let i = 0; i < 12; i++) {
      c.save(); c.rotate((i * Math.PI) / 6);
      c.beginPath(); c.moveTo(-7, -38); c.lineTo(0, -58); c.lineTo(7, -38); c.closePath(); c.fill();
      c.restore();
    }
    const g = c.createRadialGradient(-8, -10, 4, 0, 0, 36);
    g.addColorStop(0, '#FFF3B0'); g.addColorStop(1, '#FFC93C');
    c.fillStyle = g; c.beginPath(); c.arc(0, 0, 33, 0, Math.PI * 2); c.fill();
    c.strokeStyle = '#F5A81C'; c.lineWidth = 2.5; c.stroke();
    c.fillStyle = '#7A4A00';
    c.beginPath(); c.arc(-11, -5, 3.2, 0, 7); c.arc(11, -5, 3.2, 0, 7); c.fill();
    c.strokeStyle = '#7A4A00'; c.lineWidth = 2.6; c.lineCap = 'round';
    c.beginPath(); c.arc(0, 3, 12, 0.2 * Math.PI, 0.8 * Math.PI); c.stroke();
    c.fillStyle = 'rgba(255,120,120,.45)';
    c.beginPath(); c.arc(-19, 6, 5, 0, 7); c.arc(19, 6, 5, 0, 7); c.fill();
  });
}

// ── غيمة ──────────────────────────────────────────────────
export function cloudTexture(scene, key, w = 130, h = 56, seed = 1) {
  return makeTexture(scene, key, w, h, (c) => {
    const bumps = seed % 2 ? [[.22, .62, .2], [.42, .42, .27], [.66, .5, .23], [.84, .66, .17]]
                           : [[.2, .6, .18], [.38, .45, .25], [.6, .38, .26], [.82, .6, .2]];
    c.fillStyle = 'rgba(40,90,160,.12)';
    bumps.forEach(([x, y, r]) => { c.beginPath(); c.arc(x * w, y * h + 5, r * h * 1.1, 0, 7); c.fill(); });
    c.fillStyle = '#fff';
    bumps.forEach(([x, y, r]) => { c.beginPath(); c.arc(x * w, y * h, r * h * 1.1, 0, 7); c.fill(); });
    c.fillRect(w * .2, h * .6, w * .64, h * .26);
  });
}

// ── تلال بنفس اتجاه التكرار (seamless) ───────────────────────
export function hillsTexture(scene, key, w, h, color, amp, periods, phase = 0) {
  return makeTexture(scene, key, w, h, (c) => {
    c.fillStyle = color; c.beginPath(); c.moveTo(0, h);
    for (let x = 0; x <= w; x += 4) {
      const y = h * .55 - amp * Math.sin((x / w) * Math.PI * 2 * periods + phase)
                        - amp * .5 * Math.sin((x / w) * Math.PI * 2 * (periods * 2 + 1) + phase * 2);
      c.lineTo(x, y);
    }
    c.lineTo(w, h); c.closePath(); c.fill();
  });
}

// ── شجر وشجيرات (مكرّرة) ──────────────────────────────────
export function treesTexture(scene, key, w, h) {
  return makeTexture(scene, key, w, h, (c) => {
    const spots = [[.06, 1], [.2, .7], [.34, 1], [.5, .8], [.66, 1], [.8, .7], [.93, .9]];
    spots.forEach(([fx, s], i) => {
      const x = fx * w, base = h - 2;
      if (i % 3 === 1) { // شجيرة
        c.fillStyle = '#2FAE63'; c.beginPath(); c.arc(x, base - 10 * s, 14 * s, 0, 7); c.arc(x + 14 * s, base - 7 * s, 11 * s, 0, 7); c.fill();
        c.fillStyle = '#4BD07F'; c.beginPath(); c.arc(x - 4 * s, base - 14 * s, 6 * s, 0, 7); c.fill();
      } else { // شجرة
        c.fillStyle = '#8B5A2B'; c.fillRect(x - 3 * s, base - 22 * s, 6 * s, 22 * s);
        c.fillStyle = '#27A35A'; c.beginPath(); c.arc(x, base - 34 * s, 19 * s, 0, 7); c.fill();
        c.fillStyle = '#46C97B'; c.beginPath(); c.arc(x - 6 * s, base - 40 * s, 8 * s, 0, 7); c.fill();
      }
    });
  });
}

// ── بالونة كرتونية بلون معيّن (جسم + عقدة + خيط) ─────────────
export const BALLOON_W = 130;
export const BALLOON_H = 184;
export function balloonTexture(scene, key, color) {
  return makeTexture(scene, key, BALLOON_W, BALLOON_H, (c) => {
    const cx = 65, cy = 68;
    // خيط متعرّج
    c.strokeStyle = 'rgba(40,30,80,.55)'; c.lineWidth = 2; c.lineCap = 'round';
    c.beginPath(); c.moveTo(cx, cy + 66);
    c.bezierCurveTo(cx - 9, cy + 80, cx + 9, cy + 92, cx - 2, cy + 106);
    c.stroke();
    // ظل خفيف تحت
    c.fillStyle = 'rgba(0,0,0,.10)';
    c.beginPath(); c.ellipse(cx + 5, cy + 7, 52, 62, 0, 0, 7); c.fill();
    // العقدة
    c.fillStyle = darken(color, .25);
    c.beginPath(); c.moveTo(cx - 8, cy + 74); c.lineTo(cx + 8, cy + 74); c.lineTo(cx, cy + 62); c.closePath(); c.fill();
    // الجسم
    const g = c.createRadialGradient(cx - 18, cy - 24, 6, cx, cy, 86);
    g.addColorStop(0, lighten(color, .55)); g.addColorStop(.35, color); g.addColorStop(1, darken(color, .38));
    c.fillStyle = g;
    c.beginPath();
    c.moveTo(cx, cy - 62);
    c.bezierCurveTo(cx + 58, cy - 62, cx + 62, cy + 22, cx + 6, cy + 66);
    c.lineTo(cx - 6, cy + 66);
    c.bezierCurveTo(cx - 62, cy + 22, cx - 58, cy - 62, cx, cy - 62);
    c.closePath(); c.fill();
    c.strokeStyle = 'rgba(27,23,71,.22)'; c.lineWidth = 2; c.stroke();
    // لمعة
    c.fillStyle = 'rgba(255,255,255,.62)';
    c.beginPath(); c.ellipse(cx - 27, cy - 28, 9, 19, -0.5, 0, 7); c.fill();
    c.fillStyle = 'rgba(255,255,255,.4)';
    c.beginPath(); c.arc(cx - 14, cy - 46, 4, 0, 7); c.fill();
  });
}

// ── جسيمات ──────────────────────────────────────────────────
export function particleTextures(scene) {
  makeTexture(scene, 'p_conf', 10, 14, (c) => { c.fillStyle = '#fff'; rr(c, 1, 1, 8, 12, 2); c.fill(); });
  makeTexture(scene, 'p_shred', 16, 16, (c) => {
    c.fillStyle = '#fff'; c.beginPath(); c.moveTo(2, 3); c.lineTo(14, 6); c.lineTo(6, 14); c.closePath(); c.fill();
  });
  makeTexture(scene, 'p_star', 28, 28, (c) => {
    c.translate(14, 14); c.fillStyle = '#fff'; c.beginPath();
    for (let i = 0; i < 10; i++) {
      const r = i % 2 ? 5.5 : 13, a = (Math.PI / 5) * i - Math.PI / 2;
      c.lineTo(Math.cos(a) * r, Math.sin(a) * r);
    }
    c.closePath(); c.fill();
  });
  makeTexture(scene, 'p_puff', 40, 40, (c) => {
    const g = c.createRadialGradient(20, 20, 2, 20, 20, 19);
    g.addColorStop(0, 'rgba(255,255,255,.95)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = g; c.beginPath(); c.arc(20, 20, 19, 0, 7); c.fill();
  });
  makeTexture(scene, 'p_ring', 64, 64, (c) => {
    c.strokeStyle = '#fff'; c.lineWidth = 5; c.beginPath(); c.arc(32, 32, 27, 0, 7); c.stroke();
  });
  makeTexture(scene, 'p_dot', 8, 8, (c) => { c.fillStyle = '#fff'; c.beginPath(); c.arc(4, 4, 3.5, 0, 7); c.fill(); });
}

// ── شارة صح/غلط ──────────────────────────────────────────────
export function badgeTexture(scene, key, ok) {
  return makeTexture(scene, key, 64, 64, (c) => {
    const col = ok ? '#10B981' : '#F43F5E';
    c.fillStyle = 'rgba(0,0,0,.2)'; c.beginPath(); c.arc(33, 36, 28, 0, 7); c.fill();
    const g = c.createLinearGradient(0, 4, 0, 60);
    g.addColorStop(0, lighten(col, .3)); g.addColorStop(1, darken(col, .15));
    c.fillStyle = g; c.beginPath(); c.arc(32, 32, 28, 0, 7); c.fill();
    c.strokeStyle = '#fff'; c.lineWidth = 4; c.stroke();
    c.strokeStyle = '#fff'; c.lineWidth = 7; c.lineCap = 'round'; c.lineJoin = 'round';
    c.beginPath();
    if (ok) { c.moveTo(19, 33); c.lineTo(28, 42); c.lineTo(45, 23); }
    else { c.moveTo(21, 21); c.lineTo(43, 43); c.moveTo(43, 21); c.lineTo(21, 43); }
    c.stroke();
  });
}

// ── عربية سباق كرتونية ─────────────────────────────────────
export function carTexture(scene, key, color, driver = '#FFD15C') {
  return makeTexture(scene, key, 112, 60, (c) => {
    // الجسم
    const g = c.createLinearGradient(0, 14, 0, 46);
    g.addColorStop(0, lighten(color, .35)); g.addColorStop(.5, color); g.addColorStop(1, darken(color, .3));
    c.fillStyle = g; rr(c, 4, 22, 104, 26, 12); c.fill();
    c.strokeStyle = 'rgba(27,23,71,.35)'; c.lineWidth = 2; c.stroke();
    // الكابينة
    c.fillStyle = darken(color, .12); c.beginPath();
    c.moveTo(30, 24); c.quadraticCurveTo(38, 4, 58, 4); c.quadraticCurveTo(76, 4, 84, 24); c.closePath(); c.fill();
    c.stroke();
    // الزجاج
    c.fillStyle = '#BFEBFF'; c.beginPath();
    c.moveTo(38, 23); c.quadraticCurveTo(44, 9, 58, 9); c.quadraticCurveTo(71, 9, 77, 23); c.closePath(); c.fill();
    // السواق
    c.fillStyle = driver; c.beginPath(); c.arc(58, 17, 8, 0, 7); c.fill();
    c.fillStyle = '#2A2200'; c.beginPath(); c.arc(55.5, 16, 1.4, 0, 7); c.arc(61, 16, 1.4, 0, 7); c.fill();
    c.strokeStyle = '#2A2200'; c.lineWidth = 1.4; c.beginPath(); c.arc(58.5, 19, 3, 0.15 * Math.PI, 0.85 * Math.PI); c.stroke();
    // مصابيح وشريط
    c.fillStyle = '#FFF1A8'; rr(c, 98, 28, 8, 8, 3); c.fill();
    c.fillStyle = '#FF5C5C'; rr(c, 6, 28, 6, 8, 3); c.fill();
    c.fillStyle = 'rgba(255,255,255,.55)'; rr(c, 20, 31, 70, 5, 2.5); c.fill();
    // رقم
    c.fillStyle = '#fff'; c.beginPath(); c.arc(50, 38, 6.5, 0, 7); c.fill();
    c.fillStyle = darken(color, .3); c.font = '800 9px sans-serif'; c.textAlign = 'center'; c.fillText('1', 50, 41.5);
  });
}
export function wheelTexture(scene, key = 'wheel') {
  return makeTexture(scene, key, 24, 24, (c) => {
    c.translate(12, 12);
    c.fillStyle = '#2A2540'; c.beginPath(); c.arc(0, 0, 11, 0, 7); c.fill();
    c.fillStyle = '#D7DAF0'; c.beginPath(); c.arc(0, 0, 6, 0, 7); c.fill();
    c.strokeStyle = '#8A8FB8'; c.lineWidth = 2;
    for (let i = 0; i < 4; i++) { c.beginPath(); c.moveTo(0, 0); c.lineTo(Math.cos(i * Math.PI / 2) * 6, Math.sin(i * Math.PI / 2) * 6); c.stroke(); }
    c.fillStyle = '#2A2540'; c.beginPath(); c.arc(0, 0, 1.8, 0, 7); c.fill();
  });
}
// الطريق (تكرار أفقي)
export function roadTexture(scene, key, w, h) {
  return makeTexture(scene, key, w, h, (c) => {
    c.fillStyle = '#4A4766'; c.fillRect(0, 0, w, h);
    c.fillStyle = '#5B5878'; c.fillRect(0, 0, w, 4);
    c.fillStyle = '#FFE08A';
    for (let x = 0; x < w; x += 60) { rr(c, x + 8, h * .5 - 2.5, 34, 5, 2.5); c.fill(); }
    c.fillStyle = '#EDEBFA'; c.fillRect(0, h - 5, w, 3);
  });
}
export function flagTexture(scene, key = 'flag') {
  return makeTexture(scene, key, 34, 44, (c) => {
    c.fillStyle = '#2A2540'; c.fillRect(4, 2, 3, 42);
    const s = 7;
    for (let y = 0; y < 3; y++) for (let x = 0; x < 3; x++) {
      c.fillStyle = (x + y) % 2 ? '#fff' : '#14172B'; c.fillRect(7 + x * s, 3 + y * s, s, s);
    }
  });
}
