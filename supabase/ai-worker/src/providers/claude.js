// مزوّد Claude (Anthropic Messages API). الصور كـ image blocks.
const URL_MSG = 'https://api.anthropic.com/v1/messages';

const val = async (v) => (typeof v === 'function' ? await v() : v);

export function classify(status) {
  if (status === 401 || status === 403) return { kind: 'auth', reason: 'provider_auth' };
  if (status === 429 || status === 529 || status >= 500) return { kind: 'temp', reason: 'provider_error' };
  return { kind: 'permanent', reason: 'provider_error' };
}

export function createClaude({ apiKey, model, fetchFn = fetch }) {
  return {
    name: 'claude',
    maxImages: 20,
    async complete({ system, user, images = [], extraUser }) {
      const key = await val(apiKey);
      const mdl = await val(model);
      if (!key || !mdl) return { ok: false, kind: 'auth', reason: 'provider_auth', detail: 'not configured' };
      const content = [];
      for (const b64 of images) {
        content.push({ type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: b64 } });
      }
      content.push({ type: 'text', text: user });
      const messages = [{ role: 'user', content }];
      if (extraUser) {
        messages.push({ role: 'assistant', content: '{' });
        messages.push({ role: 'user', content: extraUser });
      }
      let res, body;
      try {
        res = await fetchFn(URL_MSG, {
          method: 'POST',
          headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
          body: JSON.stringify({ model: mdl, max_tokens: 8000, temperature: 0.2, system, messages }),
        });
        body = await res.json().catch(() => ({}));
      } catch (e) {
        return { ok: false, kind: 'temp', reason: 'network', detail: e.message };
      }
      if (!res.ok) return { ok: false, ...classify(res.status), detail: body?.error?.message ?? `HTTP ${res.status}` };
      const text = (body?.content ?? []).filter((b) => b.type === 'text').map((b) => b.text).join('');
      return text ? { ok: true, text, usage: body.usage ?? null } : { ok: false, kind: 'temp', reason: 'bad_output', detail: 'empty' };
    },
  };
}
