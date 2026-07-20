begin;
select plan(4);

select has_function('public', 'obtener_total_nomina_dashboard', array['date']);
select function_returns('public', 'obtener_total_nomina_dashboard', array['date'], 'jsonb');
select volatility_is('public', 'obtener_total_nomina_dashboard', array['date'], 'stable');
select ok(
  has_function_privilege('authenticated', 'public.obtener_total_nomina_dashboard(date)', 'EXECUTE'),
  'authenticated puede consultar el total de nómina del Dashboard'
);

select * from finish();
rollback;
