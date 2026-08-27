begin;
set local search_path=extensions,public,pg_catalog;
set local role postgres;
select * from no_plan();

select has_table('public','terminal_face_enrollment_idempotency','terminal enrollment has a dedicated replay ledger');
select ok(pg_get_functiondef('public.terminal_face_enrollment_pending_count(uuid,uuid)'::regprocedure) ilike '%terminal_empleado_elegible%','pending count reuses canonical terminal scope');
select ok(pg_get_functiondef('public.terminal_face_schedule_ready(uuid,uuid)'::regprocedure) ilike '%cardinality(h.dias_laborales) between 1 and 6%','weekly schedule requires at least one day off');
select ok(pg_get_functiondef('public.terminal_face_enrollment_lookup(uuid,uuid,text)'::regprocedure) ilike '%SCHEDULE_DAYOFF_REQUIRED%','lookup enforces schedule and day off');
select ok(pg_get_functiondef('public.confirmar_enrolamiento_facial_terminal(jsonb)'::regprocedure) ilike '%FACE_DUPLICATE%','confirmation rejects a face already owned by another employee');
select ok(pg_get_functiondef('public.confirmar_enrolamiento_facial_terminal(jsonb)'::regprocedure) ilike '%IDEMPOTENCY_KEY_REUSED%','confirmation detects replay key reuse');
select ok(pg_get_functiondef('public.confirmar_enrolamiento_facial_terminal(jsonb)'::regprocedure) ilike '%ANDROID_TERMINAL%','server records terminal source');
select ok(pg_get_functiondef('public.confirmar_enrolamiento_facial_terminal(jsonb)'::regprocedure) ilike '%jsonb_array_length(v_embedding)<>128%','server requires Android-compatible dimension');
select isnt(has_function_privilege('anon','public.terminal_face_enrollment_lookup(uuid,uuid,text)','execute'),true,'personal phone cannot lookup for enrollment');
select isnt(has_function_privilege('authenticated','public.terminal_face_enrollment_lookup(uuid,uuid,text)','execute'),true,'normal JWT cannot lookup for terminal enrollment');
select ok(has_function_privilege('service_role','public.terminal_face_enrollment_lookup(uuid,uuid,text)','execute'),'Edge service can perform scoped lookup');
select is((public.confirmar_enrolamiento_facial_terminal('{}'::jsonb)->>'error_code'),'FACE_EMBEDDING_INVALID','invalid payload is rejected without writing');

select * from finish();
rollback;
