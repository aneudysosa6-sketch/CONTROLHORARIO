begin;
set local search_path=extensions,public,pg_catalog;
set local role postgres;
select * from no_plan();

select ok(has_function_privilege('service_role','public.confirmar_enrolamiento_facial_terminal(jsonb)','execute'),'only Edge service can confirm terminal face enrollment');
select isnt(has_function_privilege('anon','public.confirmar_enrolamiento_facial_terminal(jsonb)','execute'),true,'anonymous phone cannot confirm a face');
select isnt(has_function_privilege('authenticated','public.confirmar_enrolamiento_facial_terminal(jsonb)','execute'),true,'normal JWT cannot confirm a face');
select isnt(has_function_privilege('authenticated','public.crear_invitacion_enrolamiento_facial(uuid,text)','execute'),true,'Web JWT cannot create QR invitations');
select isnt(has_function_privilege('service_role','public.service_exchange_face_enrollment_token(text,text)','execute'),true,'old QR exchange is no longer callable');
select ok(has_function_privilege('authenticated','public.eliminar_rostro_empleado(uuid)','execute'),'Web keeps scoped administrative face reset');
select isnt(has_table_privilege('anon','public.terminal_face_enrollment_idempotency','select'),true,'phones cannot inspect enrollment idempotency');
select isnt(has_function_privilege('authenticated','public.registrar_evento_jornada_dispositivo(jsonb)','execute'),true,'normal JWT still cannot submit attendance');
select ok(has_function_privilege('service_role','public.registrar_evento_jornada_dispositivo(jsonb)','execute'),'attendance remains service-only');

select * from finish();
rollback;
