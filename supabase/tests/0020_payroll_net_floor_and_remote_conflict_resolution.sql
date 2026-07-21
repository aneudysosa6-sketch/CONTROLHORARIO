begin;
select plan(15);

select has_function(
  'public',
  'nomina_prorratear_obligacion_v3',
  array['text','numeric','numeric','integer','numeric','numeric','numeric']
);
select volatility_is(
  'public',
  'nomina_prorratear_obligacion_v3',
  array['text','numeric','numeric','integer','numeric','numeric','numeric'],
  'immutable'
);
select is(
  public.nomina_prorratear_obligacion_v3('MONTO', 300, 10.42, 1, 5, 30, 8),
  0.21::numeric,
  'AFP/SFS MONTO de 300 se prorratea a 0.21 por cinco minutos'
);
select is(
  public.nomina_prorratear_obligacion_v3('MONTO', 1, 10.42, 1, 5, 30, 8),
  0.00::numeric,
  'AFP/SFS MONTO live de 1 redondea a cero'
);
select is(
  public.nomina_prorratear_obligacion_v3('PORCENTAJE', 2.87, 10.42, 1, 5, 30, 8),
  0.30::numeric,
  'PORCENTAJE se calcula sobre el bruto'
);

with result as (
  select public.nomina_distribuir_descuentos_v3(
    100,
    '[
      {"priority":10,"type":"AFP","requested":10},
      {"priority":30,"type":"OTRO_DESCUENTO","requested":60},
      {"priority":80,"type":"DESCU-PRES","requested":50},
      {"priority":90,"type":"DESCU-CRED","requested":20}
    ]'::jsonb
  ) value
)
select is((value ->> 'net')::numeric, 0::numeric, 'el neto nunca baja de cero') from result;

with result as (
  select public.nomina_distribuir_descuentos_v3(
    100,
    '[{"priority":10,"requested":10},{"priority":30,"requested":60},{"priority":80,"requested":50},{"priority":90,"requested":20}]'::jsonb
  ) value
)
select is((value #>> '{items,2,applied}')::numeric, 30::numeric, 'prestamo usa solo el saldo disponible') from result;

with result as (
  select public.nomina_distribuir_descuentos_v3(
    100,
    '[{"priority":10,"requested":10},{"priority":30,"requested":60},{"priority":80,"requested":50},{"priority":90,"requested":20}]'::jsonb
  ) value
)
select is((value #>> '{items,2,pending}')::numeric, 20::numeric, 'remanente del prestamo queda pendiente') from result;

with result as (
  select public.nomina_distribuir_descuentos_v3(
    100,
    '[{"priority":10,"requested":10},{"priority":30,"requested":60},{"priority":80,"requested":50},{"priority":90,"requested":20}]'::jsonb
  ) value
)
select is((value #>> '{items,3,applied}')::numeric, 0::numeric, 'credito no excede el disponible agotado') from result;

with result as (
  select public.nomina_distribuir_descuentos_v3(
    100,
    '[{"priority":10,"requested":10},{"priority":30,"requested":60},{"priority":80,"requested":50},{"priority":90,"requested":20}]'::jsonb
  ) value
)
select is((value ->> 'pending')::numeric, 40::numeric, 'todo remanente queda pendiente') from result;

with result as (
  select public.nomina_distribuir_descuentos_v3(0, '[{"priority":10,"requested":12.34}]'::jsonb) value
)
select is((value ->> 'net')::numeric, 0::numeric, 'bruto cero produce neto cero') from result;

with result as (
  select public.nomina_distribuir_descuentos_v3(0, '[{"priority":10,"requested":12.34}]'::jsonb) value
)
select is((value ->> 'pending')::numeric, 12.34::numeric, 'bruto cero difiere toda la deduccion') from result;

select has_column('public', 'nomina_descuentos', 'monto_solicitado');
select has_column('public', 'nomina_descuentos', 'monto_pendiente');
select has_function('public', 'resolver_conflicto_jornada_remoto_superado', array['uuid','text']);

select * from finish();
rollback;
