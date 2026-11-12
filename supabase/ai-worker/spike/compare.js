// spike مؤقت (spec 057 / T003): بيقارن Groq وClaude على صور حقيقية.
// الاستخدام:
//   1) ضع صور JPEG في spike/samples/ بأسماء: convert-<اسم>.jpg (امتحان مطبوع/خط يد)
//      أو generate-<اسم>.jpg (صفحة درس). ممكن أكتر من صورة بنفس الاسم + -1/-2.
//   2) اعمل supabase/ai-worker/.env فيه:
//        GROQ_API_KEY=...   ANTHROPIC_API_KEY=...   (واحد منهم يكفي)
//        اختياري: GROQ_MODEL=...  CLAUDE_MODEL=...
//   3) node spike/compare.js           (أو: node spike/compare.js convert-exam1)
// الناتج: جدول في الطرفية + ملفات JSON في spike/out/ (ممنوعة من git). مفيش مفتاح بيتطبع.
import { readFileSync, readdirSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { extract } from '../src/providers/index.js';
import { createGroq } from '../src/providers/groq.js';
import { createClaude } from '../src/providers/claude.js';

const env = { ...process.env };
const envPath = new URL('../.env', import.meta.url);
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*?)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const providers = {};
if (env.GROQ_API_KEY) {
  providers.groq = createGroq({
    apiKey: env.GROQ_API_KEY,
    model: env.GROQ_MODEL || 'qwen/qwen3.8-27b',
  });
}
if (env.ANTHROPIC_API_KEY) {
  providers.claude = createClaude({
    apiKey: env.ANTHROPIC_API_KEY,
    model: env.CLAUDE_MODEL || 'claude-sonnet-5-5',
  });
}
if (!Object.keys(providers).length) {
  console.error('ضع GROQ_API_KEY أو ANTHROPIC_API_KEY في supabase/ai-worker/.env');
  process.exit(1);
}

const dir = new URL('./samples/', import.meta.url);
if (!existsSync(dir)) { console.error('مجلد spike/samples/ مش موجود'); process.exit(1); }
const only = process.argv[2];

// نجمّع الصور حسب الاسم الأساسي: convert-exam1.jpg + convert-exam1-2.jpg → نفس الطلب
const groups = new Map();
for (const f of readdirSync(dir).filter((x) => /\.(jpe?g)$/i.test(x)).sort()) {
  const base = f.replace(/(-\d+)?\.(jpe?g)$/i, '');
  if (only && base !== only) continue;
  if (!groups.has(base)) groups.set(base, []);
  groups.get(base).push(f);
}
if (!groups.size) { console.error('مفيش صور JPEG مناسبة في spike/samples/'); process.exit(1); }

mkdirSync(new URL('./out/', import.meta.url), { recursive: true });

console.log('الملف'.padEnd(26), 'المزوّد'.padEnd(8), 'الزمن'.padEnd(8), 'أسئلة'.padEnd(6), 'مراجعة'.padEnd(7), 'بدون إجابة'.padEnd(10), 'ملاحظات');
for (const [base, files] of groups) {
  const mode = base.startsWith('generate') ? 'generate' : 'convert';
  const images = files.map((f) => readFileSync(new URL(f, dir)).toString('base64'));
  for (const name of Object.keys(providers)) {
    const t0 = Date.now();
    const r = await extract({ [name]: providers[name] }, { primary: name }, {
      mode, images, count: 8, difficulty: 'medium', language: 'ar', maxQuestions: 30,
    });
    const secs = ((Date.now() - t0) / 1000).toFixed(1) + 'ث';
    if (r.ok) {
      const review = r.questions.filter((q) => q.needs_review).length;
      const noAns = r.questions.filter((q) => q.correct_index === null).length;
      const use = r.usage ? JSON.stringify(r.usage) : '';
      console.log(base.padEnd(26), name.padEnd(8), secs.padEnd(8), String(r.questions.length).padEnd(6), String(review).padEnd(7), String(noAns).padEnd(10), use);
      writeFileSync(new URL(`./out/${base}.${name}.json`, import.meta.url), JSON.stringify(r, null, 2));
    } else {
      console.log(base.padEnd(26), name.padEnd(8), secs.padEnd(8), 'فشل'.padEnd(6), '-'.padEnd(7), '-'.padEnd(10), `${r.reason ?? ''} ${r.detail ?? ''}`);
    }
  }
}
console.log('\nالنتايج الكاملة في spike/out/*.json — راجع الأسئلة بعينك وقارن الدقة.');
