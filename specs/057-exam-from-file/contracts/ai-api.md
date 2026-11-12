# عقد: التطبيق ↔ ai-worker

الأساس: `https://active-class.online/ai/*` (Caddy ← 127.0.0.1:8788). كل الطلبات `Authorization: Bearer <Supabase access token>`؛ الخدمة تتحقق من التوقيع وتاخد `owner_id`.

## POST /ai/exam/jobs
Body (JSON):
```json
{
  "job_id": "uuid",
  "mode": "convert | generate",
  "images": ["<base64 jpeg>", "..."],
  "text": "اختياري — في generate فقط",
  "count": 10,
  "difficulty": "easy | medium | hard",
  "language": "ar"
}
```
- `images` أو `text` (واحد منهم على الأقل)؛ `convert` بيحتاج `images`.
- الحدود: صور ≤ `max_images`، حجم ≤ `max_bytes`، `count` ≤ `max_questions`.
- الرد `202 {"job_id","status":"queued"}`. لو الـ id موجود: `200` بالحالة الحالية (بدون خصم جديد).
- أخطاء: `401` توكن غلط، `402 {"error":"quota"}` الحصة خلصت، `403 {"error":"paused"}` الميزة موقوفة، `413 too_large`، `422 invalid_request`، `503 busy`.

## GET /ai/exam/jobs/:id
`200`:
```json
{
  "job_id": "uuid",
  "status": "queued|running|done|failed|rejected",
  "fail_reason": null,
  "progress": {"done": 2, "total": 4},
  "result": {"questions": [], "skipped": 0, "notes": []}
}
```
`result` موجود لما `status=done`. التطبيق يستعلم كل 2–3 ثواني. `404` لو مش بتاع المدرس.

## GET /ai/exam/quota
`{ "remaining": 7, "limit": 10 }` (نفس حساب الواجهة: المجاني المتبقي + الرصيد).

## شكل السؤال في `result.questions[]`
```json
{
  "text": "…",
  "options": ["…", "…", "…", "…"],
  "correct_index": 2,
  "explanation": "…",
  "needs_review": false,
  "has_figure": false,
  "duplicate": false,
  "source_page": 1
}
```
`correct_index` ممكن يكون `null`.

## ضمانات
- الخصم يتم عند البدء ويتردّ عند أي `failed/rejected` (راجع research R6).
- الصور مبتتخزنش ولا بتتسجّل.
- `GET /ai/health` داخلي لـ Caddy.
