// قوالب واتساب (spec 056). الأسماء والمتغيرات لازم تطابق اللي اتقدّم/اعتُمد في Meta.
// ترتيب المتغيرات = {{1}} {{2}} ... في نص القالب المعتمد (انظر specs/056-.../templates.md).

export const TEMPLATES = {
  absence: {
    name: 'ac_absence_ar',
    language: 'ar',
    // {{1}} اسم الطالب  {{2}} المجموعة  {{3}} التاريخ  {{4}} اسم المدرس
    params: ['student', 'group', 'date', 'teacher'],
  },
  late_payment: {
    name: 'ac_late_payment_ar',
    language: 'ar',
    // {{1}} اسم الطالب  {{2}} المبلغ المتأخر  {{3}} اسم المدرس
    params: ['student', 'amount', 'teacher'],
  },
  receipt: {
    name: 'ac_receipt_ar',
    language: 'ar',
    // {{1}} المبلغ المدفوع  {{2}} اسم الطالب  {{3}} الشهر  {{4}} المتبقي  {{5}} اسم المدرس
    params: ['amount', 'student', 'month', 'remaining', 'teacher'],
  },
  // رسالة اختبار للمدرس نفسه: نفس قالب الغياب
  test: null,
};
TEMPLATES.test = TEMPLATES.absence;

// بيحوّل (kind, vars) لـ payload قالب Meta. بيرمي خطأ لو متغير ناقص.
export function buildTemplatePayload(kind, to, vars) {
  const t = TEMPLATES[kind];
  if (!t) throw new Error(`kind غير معروف: ${kind}`);
  const parameters = t.params.map((key) => {
    const v = vars?.[key];
    if (v === undefined || v === null || String(v).trim() === '') {
      throw new Error(`متغير ناقص: ${key}`);
    }
    // Meta ما بتقبلش سطر جديد/تابات/أكتر من 4 مسافات في متغير
    const text = String(v).replace(/[\r\n\t]+/g, ' ').replace(/ {2,}/g, ' ').trim();
    return { type: 'text', text };
  });
  return {
    messaging_product: 'whatsapp',
    to,
    type: 'template',
    template: {
      name: t.name,
      language: { code: t.language },
      components: [{ type: 'body', parameters }],
    },
  };
}
