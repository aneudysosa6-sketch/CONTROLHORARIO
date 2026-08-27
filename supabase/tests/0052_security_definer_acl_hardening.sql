begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select plan(3);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prosecdef
      and has_function_privilege('public', p.oid, 'EXECUTE')
  ),
  'SECURITY DEFINER functions are not executable by PUBLIC'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.proacl is null
  ),
  'public SECURITY DEFINER functions have explicit ACLs'
);

select volatility_is(
  'public',
  'nomina_distribuir_descuentos_v3',
  array['numeric', 'jsonb'],
  'stable',
  'deduction distribution does not claim stronger volatility than its expressions'
);

select * from finish();
rollback;