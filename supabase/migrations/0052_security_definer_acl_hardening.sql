begin;

alter function public.nomina_distribuir_descuentos_v3(numeric, jsonb) stable;

revoke all on function private.capture_prior_adjustment_0050()
  from public, anon, authenticated, service_role;
revoke all on function private.cleanup_terminal_departments_0050()
  from public, anon, authenticated, service_role;
revoke all on function private.complete_prior_adjustments_0050()
  from public, anon, authenticated, service_role;
revoke all on function private.salary_change_license_days_0050()
  from public, anon, authenticated, service_role;
revoke all on function public.calcular_ganancia_jornada(uuid)
  from public, anon, authenticated, service_role;
do $do$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated, service_role';
  end if;
end
$do$;
revoke all on function public.trg_calcular_ganancia_jornada()
  from public, anon, authenticated, service_role;
revoke all on function public.trg_completar_evento_jornada_p1()
  from public, anon, authenticated, service_role;

commit;