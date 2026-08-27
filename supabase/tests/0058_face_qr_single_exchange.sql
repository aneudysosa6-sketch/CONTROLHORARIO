begin;
set local search_path=extensions,public,pg_catalog;
set local role postgres;
select * from no_plan();

select ok(pg_get_functiondef('public.crear_invitacion_enrolamiento_facial(uuid,text)'::regprocedure) ilike '%FACE_QR_ENROLLMENT_DEPRECATED%','QR creation fails closed');
select ok(pg_get_functiondef('public.service_exchange_face_enrollment_token(text,text)'::regprocedure) ilike '%FACE_QR_ENROLLMENT_DEPRECATED%','old QR replay fails closed');
select ok(pg_get_functiondef('public.service_complete_face_enrollment(text,jsonb,jsonb)'::regprocedure) ilike '%FACE_QR_ENROLLMENT_DEPRECATED%','old QR session cannot complete');
select isnt(has_function_privilege('anon','public.service_exchange_face_enrollment_token(text,text)','execute'),true,'anonymous QR exchange has no grant');
select isnt(has_function_privilege('service_role','public.service_complete_face_enrollment(text,jsonb,jsonb)','execute'),true,'legacy completion has no service grant');
select ok(not exists(select 1 from public.face_enrollment_invitations where estado='PENDING'),'migration revoked every pending QR invitation');

select * from finish();
rollback;
