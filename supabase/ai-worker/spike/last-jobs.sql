-- آخر طلبات الذكاء الاصطناعي: الحالة وسبب الفشل والمزوّد وعدد الأسئلة (بدون محتوى).
select created_at::timestamp(0) as at, mode, status, coalesce(fail_reason, '-') as reason,
       coalesce(provider, '-') as provider,
       coalesce(jsonb_array_length(result -> 'questions'), 0) as questions
from ai_jobs order by created_at desc limit 5;
