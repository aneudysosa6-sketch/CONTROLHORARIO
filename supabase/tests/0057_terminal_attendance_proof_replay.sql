begin;
set local search_path=extensions,public,pg_catalog;
set local role postgres;
select * from no_plan();

select ok(
  exists(
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='jornada_eventos'
      and column_name='biometric_proof_id'
      and data_type='uuid'
  ),
  'attendance events materialize the biometric proof id'
);

select ok(
  exists(
    select 1 from pg_indexes
    where schemaname='public'
      and indexname='jornada_eventos_biometric_proof_once_0056'
      and indexdef ilike 'create unique index%'
      and indexdef ilike '%biometric_proof_id%'
  ),
  'a biometric proof can be consumed once per tenant and device'
);

select ok(
  pg_get_functiondef(
    'public.registrar_evento_jornada_dispositivo(jsonb)'::regprocedure
  ) ilike '%BIOMETRIC_PROOF_REPLAY%',
  'the attendance RPC rejects proof replay'
);

select ok(
  pg_get_functiondef(
    'public.registrar_evento_jornada_dispositivo(jsonb)'::regprocedure
  ) ilike '%biometric_verified%',
  'the attendance RPC requires server-verified biometric proof'
);

select isnt(
  has_function_privilege(
    'anon',
    'public.registrar_evento_jornada_dispositivo(jsonb)',
    'execute'
  ),
  true,
  'anonymous callers cannot execute the attendance RPC'
);

select isnt(
  has_function_privilege(
    'authenticated',
    'public.registrar_evento_jornada_dispositivo(jsonb)',
    'execute'
  ),
  true,
  'normal user JWT callers cannot execute the attendance RPC'
);

select * from finish();
rollback;