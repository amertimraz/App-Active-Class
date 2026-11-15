// مزوّد Groq (OpenAI-compatible). الصور كـ data URL. حد الصور في الطلب = 3 (Groq بيرفض أكتر: "This model supports up to 3 images").
const URL_CHAT = 'https://api.groq.com/openai/v1/chat/completions';

const val = async (v) => (typeof v === 'function' ? await v() : v);

export function classify(status) {
  if (status === 401 || status === 403) return { kind: 'auth', reason: 'provider_auth' };
  if (status === 429 || status >= 500) return { kind: 'temp', reason: 'provider_error' };
  return { kind: 'permanent', reason: 'provider_error' };
}

export function createGroq({ apiKey, model, fetchFn = fetch }) {
  return {
    name: 'groq',
    maxImages: 3,
    // يرجّع { ok:true, text } أو { ok:false, kind, reason, detail }
    async complete({ system, user, images = [], extraUser }) {
      const key = await val(apiKey);
      const mdl = await val(model);
      if (!key || !mdl) return { ok: false, kind: 'auth', reason: 'provider_auth', detail: 'not configured' };
      const content = [{ type: 'text', text: user }];
      for (const b64 of images) {
        content.push({ type: 'image_url', image_url: { url: `data:image/jpeg;base64,${b64}` } });
      }
      const messages = [{ role: 'system', content: system }, { role: 'user', content }];
      if (extraUser) messages.push({ role: 'user', content: extraUser });
      let res, body;
      try {
        res = await fetchFn(URL_CHAT, {
          method: 'POST',
          headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ model: mdl, messages, temperature: 0.2, response_format: { type: 'json_object' } }),
        });
        body = await res.json().catch(() => ({}));
      } catch (e) {
        return { ok: false, kind: 'temp', reason: 'network', detail: e.message };
      }
      if (!res.ok) return { ok: false, ...classify(res.status), detail: body?.error?.message ?? `HTTP ${res.status}` };
      const text = body?.choices?.[0]?.message?.content;
      return text ? { ok: true, text, usage: body.usage ?? null } : { ok: false, kind: 'temp', reason: 'bad_output', detail: 'empty' };
    },
  };
}
