// characters.js — شخصيات وعناصر الألعاب الجديدة (بطل، وحش، سلّة، صندوق، كروت،
// أزرار كبيرة). كلها Canvas 2D بالكود زي art.js.
import { makeTexture, lighten, darken, roundRect as rr } from './art.js';

function eyes(c, x, y, gap, r, mood) {
  if (mood === 'happy') { // عيون مبتسمة ^ ^
    c.strokeStyle = '#1B1747'; c.lineWidth = 3; c.lineCap = 'round';
    [-gap, gap].forEach((dx) => { c.beginPath(); c.arc(x + dx, y + 2, r, Math.PI * 1.1, Math.PI * 1.9); c.stroke(); });
    return;
  }
  if (mood === 'hurt') { // عيون X
    c.strokeStyle = '#1B1747'; c.lineWidth = 3; c.lineCap = 'round';
    [-gap, gap].forEach((dx) => {
      c.beginPath(); c.moveTo(x + dx - r, y - r); c.lineTo(x + dx + r, y + r);
      c.moveTo(x + dx + r, y - r); c.lineTo(x + dx - r, y + r); c.stroke();
    });
    return;
  }
  [-gap, gap].forEach((dx) => {
    c.fillStyle = '#fff'; c.beginPath(); c.arc(x + dx, y, r + 2, 0, 7); c.fill();
    c.strokeStyle = 'rgba(27,23,71,.5)'; c.lineWidth = 1.5; c.stroke();
    c.fillStyle = '#1B1747'; c.beginPath(); c.arc(x + dx + 1.5, y + 1, r * 0.62, 0, 7); c.fill();
    c.fillStyle = '#fff'; c.beginPath(); c.arc(x + dx + 3, y - 1, 1.6, 0, 7); c.fill();
  });
}

/** البطل: كرة زرقا ظريفة بعيون كبيرة وشريط رأس. mood: n | happy | hurt */
export function heroTexture(scene, key, mood = 'n') {
  return makeTexture(scene, key, 96, 104, (c) => {
    c.fillStyle = 'rgba(0,0,0,.14)'; c.beginPath(); c.ellipse(48, 98, 30, 6, 0, 0, 7); c.fill();
    c.fillStyle = '#FF9F43'; c.beginPath(); c.ellipse(34, 92, 11, 7, 0, 0, 7); c.ellipse(62, 92, 11, 7, 0, 0, 7); c.fill();
    const g = c.createRadialGradient(36, 34, 6, 48, 52, 52);
    g.addColorStop(0, '#7DD3FC'); g.addColorStop(0.6, '#38A3F5'); g.addColorStop(1, '#1D6FD6');
    c.fillStyle = g; c.beginPath(); c.arc(48, 52, 40, 0, 7); c.fill();
    c.strokeStyle = 'rgba(27,23,71,.3)'; c.lineWidth = 2.5; c.stroke();
    c.fillStyle = '#FF5C7A'; c.fillRect(11, 26, 74, 9);
    c.beginPath(); c.moveTo(84, 28); c.lineTo(96, 20); c.lineTo(92, 34); c.closePath(); c.fill();
    eyes(c, 48, 48, 14, 7, mood);
    c.strokeStyle = '#1B1747'; c.lineWidth = 3; c.lineCap = 'round'; c.beginPath();
    if (mood === 'hurt') c.arc(48, 74, 7, Math.PI * 1.1, Math.PI * 1.9);
    else if (mood === 'happy') c.arc(48, 62, 12, 0.1 * Math.PI, 0.9 * Math.PI);
    else c.arc(48, 64, 8, 0.15 * Math.PI, 0.85 * Math.PI);
    c.stroke();
    c.fillStyle = 'rgba(255,120,150,.5)'; c.beginPath(); c.arc(24, 62, 6, 0, 7); c.arc(72, 62, 6, 0, 7); c.fill();
    c.fillStyle = 'rgba(255,255,255,.5)'; c.beginPath(); c.ellipse(30, 40, 6, 11, -0.5, 0, 7); c.fill();
  });
}

export function swordTexture(scene, key = 'sword') {
  return makeTexture(scene, key, 70, 18, (c) => {
    c.fillStyle = '#E8EEF9'; c.beginPath(); c.moveTo(18, 4); c.lineTo(62, 9); c.lineTo(18, 14); c.closePath(); c.fill();
    c.strokeStyle = '#8FA3C7'; c.lineWidth = 1.5; c.stroke();
    c.fillStyle = '#FFC93C'; rr(c, 12, 1, 7, 16, 3); c.fill();
    c.fillStyle = '#8B5A2B'; rr(c, 2, 6, 11, 6, 3); c.fill();
  });
}

/** الوحش: كتلة كبيرة بقرنين وأسنان. mood: n | angry | hurt */
export function monsterTexture(scene, key, color, mood = 'n') {
  return makeTexture(scene, key, 190, 176, (c) => {
    c.fillStyle = 'rgba(0,0,0,.16)'; c.beginPath(); c.ellipse(95, 168, 66, 9, 0, 0, 7); c.fill();
    c.fillStyle = '#FFF1C9'; c.strokeStyle = 'rgba(27,23,71,.35)'; c.lineWidth = 2.5;
    [[44, 38, 28, -6], [146, 38, 162, -6]].forEach(([x, y, tx, ty]) => {
      c.beginPath(); c.moveTo(x - 14, y + 10); c.quadraticCurveTo(x - 6, ty, tx, ty + 4);
      c.quadraticCurveTo(x + 8, y - 6, x + 14, y + 12); c.closePath(); c.fill(); c.stroke();
    });
    const g = c.createRadialGradient(70, 60, 10, 95, 95, 96);
    g.addColorStop(0, lighten(color, 0.4)); g.addColorStop(0.55, color); g.addColorStop(1, darken(color, 0.4));
    c.fillStyle = g; c.beginPath();
    c.moveTo(95, 28); c.bezierCurveTo(170, 24, 188, 100, 168, 146);
    c.quadraticCurveTo(150, 168, 95, 166); c.quadraticCurveTo(40, 168, 22, 146);
    c.bezierCurveTo(2, 100, 20, 24, 95, 28); c.closePath(); c.fill(); c.lineWidth = 3; c.stroke();
    c.fillStyle = 'rgba(255,255,255,.18)'; c.beginPath(); c.ellipse(95, 126, 42, 30, 0, 0, 7); c.fill();
    if (mood === 'hurt') eyes(c, 95, 76, 30, 8, 'hurt');
    else {
      [-30, 30].forEach((dx) => {
        c.fillStyle = '#fff'; c.beginPath(); c.arc(95 + dx, 76, 16, 0, 7); c.fill();
        c.strokeStyle = 'rgba(27,23,71,.5)'; c.lineWidth = 2; c.stroke();
        c.fillStyle = mood === 'angry' ? '#E11D48' : '#1B1747';
        c.beginPath(); c.arc(95 + dx - (dx > 0 ? 3 : -3), 80, 7.5, 0, 7); c.fill();
      });
      c.strokeStyle = '#1B1747'; c.lineWidth = 5; c.lineCap = 'round';
      const t = mood === 'angry' ? 14 : 4;
      c.beginPath(); c.moveTo(52, 52 - t * 0.2); c.lineTo(82, 56 + t);
      c.moveTo(138, 52 - t * 0.2); c.lineTo(108, 56 + t); c.stroke();
    }
    c.fillStyle = '#3A0F2E'; c.beginPath();
    if (mood === 'hurt') c.ellipse(95, 124, 18, 10, 0, 0, 7);
    else { c.moveTo(56, 112); c.quadraticCurveTo(95, mood === 'angry' ? 160 : 150, 134, 112); c.quadraticCurveTo(95, 126, 56, 112); }
    c.fill();
    if (mood !== 'hurt') {
      c.fillStyle = '#fff';
      [[68, 114], [86, 122], [104, 122], [122, 114]].forEach(([x, y], i) => {
        c.beginPath(); c.moveTo(x - 7, y - 4); c.lineTo(x + 7, y - 4); c.lineTo(x, y + (i % 3 === 1 ? 10 : 15)); c.closePath(); c.fill();
      });
    }
  });
}

export function basketTexture(scene, key = 'basket') {
  return makeTexture(scene, key, 120, 78, (c) => {
    c.fillStyle = 'rgba(0,0,0,.14)'; c.beginPath(); c.ellipse(60, 74, 44, 5, 0, 0, 7); c.fill();
    const g = c.createLinearGradient(0, 18, 0, 70);
    g.addColorStop(0, '#E9B25C'); g.addColorStop(1, '#B9772A');
    c.fillStyle = g; c.beginPath(); c.moveTo(6, 22); c.lineTo(114, 22); c.lineTo(100, 70);
    c.quadraticCurveTo(60, 78, 20, 70); c.closePath(); c.fill();
    c.strokeStyle = 'rgba(94,52,12,.55)'; c.lineWidth = 2;
    for (let x = 18; x < 110; x += 16) { c.beginPath(); c.moveTo(x, 24); c.lineTo(x - (x - 60) * 0.12, 70); c.stroke(); }
    for (let y = 34; y < 70; y += 13) { c.beginPath(); c.moveTo(10 + (y - 22) * 0.28, y); c.lineTo(110 - (y - 22) * 0.28, y); c.stroke(); }
    c.fillStyle = '#9A5E1D'; rr(c, 2, 14, 116, 14, 7); c.fill();
    c.strokeStyle = 'rgba(94,52,12,.6)'; c.lineWidth = 2; c.stroke();
  });
}

/** صندوق إجابة بلون حافة */
export function crateTexture(scene, key, color) {
  return makeTexture(scene, key, 132, 84, (c) => {
    c.fillStyle = 'rgba(0,0,0,.18)'; rr(c, 6, 8, 126, 76, 14); c.fill();
    const g = c.createLinearGradient(0, 0, 0, 80);
    g.addColorStop(0, lighten(color, 0.35)); g.addColorStop(1, darken(color, 0.22));
    c.fillStyle = g; rr(c, 2, 2, 124, 76, 14); c.fill();
    c.strokeStyle = darken(color, 0.45); c.lineWidth = 3; c.stroke();
    c.fillStyle = 'rgba(255,255,255,.28)'; rr(c, 9, 7, 110, 12, 6); c.fill();
    c.fillStyle = darken(color, 0.3);
    [[10, 10], [114, 10], [10, 68], [114, 68]].forEach(([x, y]) => { c.beginPath(); c.arc(x, y, 3.2, 0, 7); c.fill(); });
  });
}

/** كارت ذاكرة: ظهر مزخرف (back) أو وش (q للسؤال، a للإجابة) */
export function cardTexture(scene, key, kind) {
  return makeTexture(scene, key, 150, 116, (c) => {
    c.fillStyle = 'rgba(0,0,0,.2)'; rr(c, 4, 6, 144, 108, 16); c.fill();
    if (kind === 'back') {
      const g = c.createLinearGradient(0, 0, 150, 116);
      g.addColorStop(0, '#8B5CF6'); g.addColorStop(1, '#EC4899');
      c.fillStyle = g; rr(c, 2, 2, 144, 108, 16); c.fill();
      c.strokeStyle = '#fff'; c.lineWidth = 4; c.stroke();
      c.strokeStyle = 'rgba(255,255,255,.35)'; c.lineWidth = 2;
      for (let i = -2; i < 8; i++) { c.beginPath(); c.moveTo(i * 24, 0); c.lineTo(i * 24 + 90, 116); c.stroke(); }
      c.fillStyle = '#FFE08A'; c.beginPath();
      for (let i = 0; i < 10; i++) { const r = i % 2 ? 9 : 22, a = (Math.PI / 5) * i - Math.PI / 2; c.lineTo(75 + Math.cos(a) * r, 56 + Math.sin(a) * r); }
      c.closePath(); c.fill(); c.strokeStyle = '#F5A81C'; c.lineWidth = 2.5; c.stroke();
    } else {
      const col = kind === 'q' ? '#3B82F6' : '#10B981';
      c.fillStyle = '#FFFFFF'; rr(c, 2, 2, 144, 108, 16); c.fill();
      c.strokeStyle = col; c.lineWidth = 6; c.stroke();
      c.fillStyle = lighten(col, 0.85); rr(c, 10, 10, 128, 92, 10); c.fill();
      c.fillStyle = col; c.beginPath(); c.arc(20, 20, 8, 0, 7); c.fill();
    }
  });
}

/** زرار كرتوني ضخم 3D (للصح/الغلط). */
export function bigButtonTexture(scene, key, color) {
  return makeTexture(scene, key, 210, 150, (c) => {
    c.fillStyle = darken(color, 0.35); rr(c, 4, 14, 202, 130, 28); c.fill();
    const g = c.createLinearGradient(0, 0, 0, 130);
    g.addColorStop(0, lighten(color, 0.35)); g.addColorStop(1, color);
    c.fillStyle = g; rr(c, 4, 4, 202, 126, 28); c.fill();
    c.strokeStyle = 'rgba(27,23,71,.3)'; c.lineWidth = 3; c.stroke();
    c.fillStyle = 'rgba(255,255,255,.3)'; rr(c, 16, 10, 178, 26, 13); c.fill();
  });
}
