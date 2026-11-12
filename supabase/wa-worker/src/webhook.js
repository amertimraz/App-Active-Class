// معالجة webhook واتساب (spec 056): حالات التسليم + ردود الإيقاف.
import { parseWebhook, statusRank, verifySignature } from './meta.js';

// رقم Meta (digits بدون +) → نفس صيغة to_phone المخزنة (digits بدون +)
const digits = (s) => String(s ?? '').replace(/\D/g, '');

export async function applyWebhook(db, payload, log = console) {
  const { statuses, stops } = parseWebhook(payload);

  for (const s of statuses) {
    if (s.status === 'failed') {
      const code = s.error?.code;
      const reason = code === 131026 ? 'not_on_whatsapp' : 'provider_error';
      const { rows } = await db.query(
        `update wa_outbox set status='failed', fail_reason=$2, charged=false
          where provider_msg_id=$1 and status in ('sent','delivered') returning owner_id, charged`,
        [s.id, reason],
      );
      // رجّع الحصة (الرسايل اللي فشلت بعد القبول مش بتتحاسب عادةً)
      if (rows.length) await db.query(`select wa_release_quota($1,'free')`, [rows[0].owner_id]);
      continue;
    }
    if (!['sent', 'delivered', 'read'].includes(s.status)) continue;
    const col = s.status === 'delivered' ? 'delivered_at' : s.status === 'read' ? 'read_at' : 'sent_at';
    // مش بنرجّع الحالة للخلف: ranking بالـ SQL
    await db.query(
      `update wa_outbox set status=$2, ${col}=coalesce(${col}, $3)
        where provider_msg_id=$1
          and (case status when 'sent' then 1 when 'delivered' then 2 when 'read' then 3 else 0 end)
              < (case $2 when 'sent' then 1 when 'delivered' then 2 when 'read' then 3 else 0 end)`,
      [s.id, s.status, s.at],
    );
  }

  for (const st of stops) {
    const phone = digits(st.from);
    await db.query(
      `update wa_consents set status='stopped', stopped_at=now() where phone=$1 and status <> 'stopped'`,
      [phone],
    );
    log.info('[wa] إيقاف من ولي أمر', phone.slice(0, 4) + '***');
  }
  return { statuses: statuses.length, stops: stops.length };
}

// معالج HTTP: GET للتحقق (hub.challenge) وPOST للأحداث الموقّعة.
const val = async (v) => (typeof v === 'function' ? await v() : v);

export function createWebhookHandler({ db, appSecret, verifyToken, log = console }) {
  return async function handle(req, res, rawBody) {
    const url = new URL(req.url, 'http://x');
    if (req.method === 'GET') {
      const vt = await val(verifyToken);
      const ok = url.searchParams.get('hub.mode') === 'subscribe'
        && vt && url.searchParams.get('hub.verify_token') === vt;
      res.writeHead(ok ? 200 : 403);
      return res.end(ok ? url.searchParams.get('hub.challenge') : 'forbidden');
    }
    if (req.method === 'POST') {
      if (!verifySignature(rawBody, req.headers['x-hub-signature-256'], await val(appSecret))) {
        res.writeHead(401); return res.end('bad signature');
      }
      let payload;
      try { payload = JSON.parse(rawBody.toString('utf8')); } catch { res.writeHead(400); return res.end('bad json'); }
      // نرد 200 بسرعة؛ الأخطاء اتسجل بس (Meta بتعيد الإرسال لو رجّعنا خطأ)
      applyWebhook(db, payload, log).catch((e) => log.error('[wa] webhook', e.message));
      res.writeHead(200); return res.end('ok');
    }
    res.writeHead(405); res.end();
  };
}
