// قراءة المفاتيح: الأول من جدول app_secrets (اللي بيتحرر من لوحة الأدمن)، وبعدين
// متغيرات البيئة كاحتياطي. كاش قصير عشان تغيير مفتاح من اللوحة يسري خلال دقيقة.
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
      cache = cache ?? {};
    }
    at = now();
    return cache;
  }

  return {
    async get(key) {
      const fromDb = (await load())[key];
      const v = fromDb && fromDb !== PLACEHOLDER ? fromDb : env[key];
      return v && v !== PLACEHOLDER ? v : null;
    },
    invalidate() { cache = null; },
  };
}
