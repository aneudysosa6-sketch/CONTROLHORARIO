begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select plan(5);

select ok(
  to_regprocedure('public.validar_cronologia_evento_jornada()') is not null,
  'attendance chronology trigger function exists'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgname = 'jornada_eventos_cronologia_guard'
      and not tgisinternal
  ),
  'attendance event chronology trigger exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conname = 'jornadas_cronologia_check'
      and conrelid = 'public.jornadas'::regclass
  ),
  'journey timestamp chronology constraint exists'
);

select throws_ok(
  $sql$
    insert into public.jornada_eventos (
      jornada_id,
      empresa_id,
      empleado_id,
      accion,
      ocurrido_en,
      idempotency_key
    ) values (
      extensions.gen_random_uuid(),
      extensions.gen_random_uuid(),
      extensions.gen_random_uuid(),
      'INICIAR',
      statement_timestamp() + interval '6 minutes',
      extensions.gen_random_uuid()
    )
  $sql$,
  'P4801',
  'ATTENDANCE_EVENT_IN_FUTURE',
  'the real trigger rejects an event more than five minutes in the future'
);

select case
  when seed.jornada_id is null then
    skip(
      'non-monotonic runtime assertion requires one existing attendance event',
      1
    )
  else
    throws_ok(
      format(
        'insert into public.jornada_eventos
          (jornada_id, empresa_id, empleado_id, accion, ocurrido_en, idempotency_key)
         values (%L::uuid, %L::uuid, %L::uuid, %L, %L::timestamptz, extensions.gen_random_uuid())',
        seed.jornada_id,
        seed.empresa_id,
        seed.empleado_id,
        'INICIAR',
        least(
          seed.ultimo_evento - interval '1 second',
          statement_timestamp()
        )
      ),
      'P4802',
      'ATTENDANCE_EVENT_NON_MONOTONIC',
      'the real trigger rejects an event older than the latest journey event'
    )
end
from (values (1)) anchor(value)
left join lateral (
  select
    evento.jornada_id,
    evento.empresa_id,
    min(evento.empleado_id::text)::uuid as empleado_id,
    max(evento.ocurrido_en) as ultimo_evento
  from public.jornada_eventos evento
  group by evento.jornada_id, evento.empresa_id
  order by max(evento.ocurrido_en) desc
  limit 1
) seed on true;

select * from finish();
rollback;
