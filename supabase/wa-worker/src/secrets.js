// قراءة المفاتيح (spec 056/057): الأول من جدول app_secrets (اللي بيتحرر من لوحة
// الأدمن)، وبعدين متغيرات البيئة كاحتياطي. فيه كاش قصير عشان تغيير مفتاح من
// اللوحة يسري خلال دقيقة بدون إعادة تشغيل. القيمة PENDING_SET_ME = مش متضبوطة.
const PLACEHOLDER = 'PENDING_SET_ME';

export function createSecrets({ db, env = process.env, ttlMs = 60_000, now = () => Date.now() }) {
  let cache = null;
  let at = 0;

  async function load() {
    if (cache && now() - at < ttlMs) return cache;
    try {
      const { rows } = await db.query('select key, value from app_secrets');
      cache = Object.fromEntries(rows.map((r) => [r.key, r.value]));
    } catch {
      cache = cache ?? {}; // الجدول لسه مش موجود → بيئة فقط
    }
    at = now();
    return cache;
  }

  return {
    // بيرجّع القيمة أو null لو مش متضبوطة
    async get(key) {
      const fromDb = (await load())[key];
      const v = fromDb && fromDb !== PLACEHOLDER ? fromDb : env[key];
      return v && v !== PLACEHOLDER ? v : null;
    },
    invalidate() { cache = null; },
  };
}
