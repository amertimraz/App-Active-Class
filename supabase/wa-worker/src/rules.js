// قواعد صرفة (spec 056): ساعات الإرسال، التأجيل، token bucket. بلا I/O عشان تتختبر.

// الساعة بتوقيت القاهرة لتاريخ معيّن
export function cairoHour(date) {
  const h = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Cairo', hour: '2-digit', hour12: false,
  }).format(date);
  return Number(h) % 24;
}

export function inSendWindow(date, fromHour, toHour) {
  const h = cairoHour(date);
  return h >= fromHour && h < toHour;
}

// أقرب وقت مسموح (بداية النافذة القادمة بتوقيت القاهرة). بنزوّد ساعة ساعة — بسيط وآمن مع DST.
export function nextWindowStart(date, fromHour, toHour) {
  if (inSendWindow(date, fromHour, toHour)) return date;
  let t = new Date(date.getTime());
  t.setUTCMinutes(0, 0, 0);
  for (let i = 0; i < 48; i++) {
    t = new Date(t.getTime() + 3600_000);
    if (inSendWindow(t, fromHour, toHour)) return t;
  }
  return t;
}

// تأخير إعادة المحاولة: 30ث ← 2د ← 10د
export function retryDelayMs(attempts) {
  return [30_000, 120_000, 600_000][Math.min(Math.max(attempts - 1, 0), 2)];
}

export const MAX_ATTEMPTS = 3;

// token bucket بسيط: بيتحكم في عدد الرسايل في الدقيقة
export function createBucket(perMin, now = () => Date.now()) {
  let tokens = perMin;
  let last = now();
  return {
    take() {
      const t = now();
      tokens = Math.min(perMin, tokens + ((t - last) / 60_000) * perMin);
      last = t;
      if (tokens >= 1) { tokens -= 1; return true; }
      return false;
    },
  };
}

// أسباب الفشل بالعربي للعرض في التطبيق (نفس الأكواد المخزنة في wa_outbox.fail_reason)
export const FAIL_REASON_AR = {
  no_consent: 'مفيش موافقة من ولي الأمر',
  stopped: 'ولي الأمر أوقف الرسايل',
  no_quota: 'خلصت حصة الرسايل',
  invalid_number: 'رقم ولي الأمر غير صالح',
  not_on_whatsapp: 'الرقم مش على واتساب',
  recipient_not_allowed: 'الرقم غير مسموح له بالاستلام',
  template_error: 'مشكلة في قالب الرسالة',
  template_vars: 'بيانات الرسالة ناقصة',
  provider_error: 'تعذّر الإرسال، حاول لاحقًا',
  provider_auth: 'الخدمة متوقفة مؤقتًا',
  network: 'مشكلة اتصال، سنعيد المحاولة',
  cancelled: 'اتلغت',
  disabled: 'الخدمة متوقفة',
  not_activated: 'الخدمة لسه ما اتفعّلتش من الإدارة',
};
