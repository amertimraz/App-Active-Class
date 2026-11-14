// حلقة الإرسال (spec 056). القرار صرف (decide) والباقي I/O رفيع على Postgres.
import { inSendWindow, nextWindowStart, retryDelayMs, MAX_ATTEMPTS, createBucket } from './rules.js';

// بيقرر إيه اللي يحصل لطلب قبل ما نتصل بالمزوّد. بلا أي I/O.
// ctx: { cfg:{killSwitch,fromHour,toHour}, settings:{enabled,kinds,pausedByAdmin,adminActivated}|null,
//        consent: 'granted'|'stopped'|null (حالة الرقم عند المدرس), globalStopped:boolean, now:Date }
export function decide(row, ctx) {
  const { cfg, settings, consent, globalStopped, now } = ctx;
  if (cfg.killSwitch) return { action: 'defer', until: new Date(now.getTime() + 60_000), quiet: true };

  const isTest = row.kind === 'test';
  if (!settings || !settings.enabled || settings.pausedByAdmin) {
    return { action: 'block', reason: 'disabled' };
  }
  // قفل افتراضي: الخدمة ما بتشتغلش لمدرس غير لما الأدمن يفتحها (حتى رسايل الاختبار).
  if (!settings.adminActivated) {
    return { action: 'block', reason: 'not_activated' };
  }
  if (!isTest && settings.kinds && settings.kinds[row.kind] === false) {
    return { action: 'block', reason: 'disabled' };
  }
  if (!isTest) {
    if (globalStopped || consent === 'stopped') return { action: 'block', reason: 'stopped' };
    if (consent !== 'granted') return { action: 'block', reason: 'no_consent' };
    if (!inSendWindow(now, cfg.fromHour, cfg.toHour)) {
      return { action: 'defer', until: nextWindowStart(now, cfg.fromHour, cfg.toHour) };
    }
  }
  return { action: 'send' };
}

// نتيجة فشل من المزوّد → إجراء على الصف
export function afterFailure(row, result, now = new Date()) {
  const attempts = row.attempts + 1;
  if (result.kind === 'temp') {
    if (attempts >= MAX_ATTEMPTS) return { status: 'failed', reason: result.reason, attempts };
    return { status: 'pending', reason: result.reason, attempts, until: new Date(now.getTime() + retryDelayMs(attempts)) };
  }
  return { status: 'failed', reason: result.reason, attempts };
}

async function loadCfg(db) {
  const { rows } = await db.query('select key, value from wa_config');
  const m = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return {
    killSwitch: m.kill_switch === true || m.kill_switch === 'true',
    fromHour: Number(m.send_from_hour ?? 8),
    toHour: Number(m.send_to_hour ?? 22),
    ratePerMin: Number(m.rate_per_min ?? 30),
  };
}

export function createSender({ db, meta, log = console }) {
  let bucket = null;
  let bucketRate = 0;

  async function revert(id, until) {
    await db.query(`update wa_outbox set status='pending', not_before=$2 where id=$1`, [id, until]);
  }

  async function processRow(row, cfg) {
    const now = new Date();
    const [{ rows: [st] }, { rows: cons }] = await Promise.all([
      db.query(`select enabled, kinds, paused_by_admin as "pausedByAdmin", admin_activated as "adminActivated" from wa_teacher_settings where owner_id=$1`, [row.owner_id]),
      db.query(
        `select owner_id, student_local_id, status from wa_consents where phone=$1
         and (status='stopped' or (owner_id=$2 and student_local_id=$3))`,
        [row.to_phone, row.owner_id, row.student_local_id],
      ),
    ]);
    const globalStopped = cons.some((c) => c.status === 'stopped');
    const mine = cons.find((c) => c.owner_id === row.owner_id && c.student_local_id === row.student_local_id);
    const d = decide(row, { cfg, settings: st ?? null, consent: mine?.status ?? null, globalStopped, now });

    if (d.action === 'block') {
      await db.query(`update wa_outbox set status='blocked', fail_reason=$2 where id=$1`, [row.id, d.reason]);
      return;
    }
    if (d.action === 'defer') return revert(row.id, d.until);

    if (!bucket || bucketRate !== cfg.ratePerMin) { bucket = createBucket(cfg.ratePerMin); bucketRate = cfg.ratePerMin; }
    if (!bucket.take()) return revert(row.id, new Date(Date.now() + 10_000));

    const { rows: [{ q }] } = await db.query(`select wa_reserve_quota($1) as q`, [row.owner_id]);
    if (!q) {
      await db.query(`update wa_outbox set status='blocked', fail_reason='no_quota' where id=$1`, [row.id]);
      return;
    }

    const r = await meta.send(row.kind, row.to_phone, row.vars);
    if (r.ok) {
      await db.query(
        `update wa_outbox set status='sent', sent_at=now(), provider_msg_id=$2, charged=true, attempts=attempts+1 where id=$1`,
        [row.id, r.id],
      );
      return;
    }
    await db.query(`select wa_release_quota($1,$2)`, [row.owner_id, q]);
    if (r.kind === 'auth') {
      log.error('[wa] خطأ مصادقة من المزوّد — kill switch', r.detail);
      await db.query(`update wa_config set value='true', updated_at=now() where key='kill_switch'`);
      return revert(row.id, new Date(Date.now() + 60_000));
    }
    const a = afterFailure(row, r);
    if (a.status === 'pending') {
      await db.query(`update wa_outbox set status='pending', fail_reason=$2, attempts=$3, not_before=$4 where id=$1`,
        [row.id, a.reason, a.attempts, a.until]);
    } else {
      await db.query(`update wa_outbox set status='failed', fail_reason=$2, attempts=$3 where id=$1`,
        [row.id, a.reason, a.attempts]);
    }
  }

  return {
    // يرجّع عدد الصفوف المعالجة
    async tick(limit = 20) {
      const cfg = await loadCfg(db);
      if (cfg.killSwitch) return 0;
      const { rows } = await db.query(
        `update wa_outbox set status='sending' where id in (
           select id from wa_outbox where status='pending' and not_before <= now()
           order by not_before limit $1 for update skip locked) returning *`,
        [limit],
      );
      for (const row of rows) {
        try { await processRow(row, cfg); }
        catch (e) {
          log.error('[wa] فشل معالجة صف', row.id, e.message);
          await revert(row.id, new Date(Date.now() + 60_000)).catch(() => {});
        }
      }
      return rows.length;
    },
  };
}
