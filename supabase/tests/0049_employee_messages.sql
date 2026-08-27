begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select plan(12);

select has_table('public', 'mensajes_empleados', 'pending employee messages table exists');
select has_table('public', 'mensajes_empleados_recibidos', 'content-free receipt tombstone table exists');
select has_function('public', 'crear_mensaje_empleado', array['uuid','text','text','text','integer','uuid'], 'message creation RPC exists');
select has_function('public', 'obtener_mensajes_pendientes_dispositivo', array['uuid','uuid'], 'device sync RPC exists');
select has_function('public', 'confirmar_mensaje_recibido_dispositivo', array['jsonb'], 'receipt RPC exists');
select col_is_pk('public', 'mensajes_empleados_recibidos', array['mensaje_id'], 'first receipt wins by message id');
select ok(
  exists (select 1 from pg_indexes where indexname = 'mensajes_empleados_un_pendiente_idx' and indexdef ilike '%unique%'),
  'only one pending message per employee'
);
select ok(
  exists (select 1 from public.permisos where codigo = 'mensajes.administrar' and activo),
  'message administration permission exists'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.mensajes_empleados'::regclass),
  'message content table has RLS'
);
select ok(
  not has_table_privilege('authenticated', 'public.mensajes_empleados', 'SELECT'),
  'authenticated users cannot list pending message content'
);
select ok(
  lower(pg_get_constraintdef((
    select oid from pg_constraint where conname = 'mensajes_empleados_contenido_check'
  ))) like '%audio_duracion_segundos >= 1%'
  and lower(pg_get_constraintdef((
    select oid from pg_constraint where conname = 'mensajes_empleados_contenido_check'
  ))) like '%audio_duracion_segundos <= 30%',
  'recorded audio is limited to 30 seconds'
);
select ok(
  exists (select 1 from storage.buckets where id = 'employee-message-audio' and not public),
  'message audio bucket is private'
);

select * from finish();
rollback;