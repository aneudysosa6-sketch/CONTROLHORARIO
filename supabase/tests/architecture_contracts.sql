-- Ejecutar solo en Supabase local después de FINAL + seed. Nunca contra producción.
begin;
select plan(1);
do $$
declare v_missing text;
begin
  select string_agg(x,', ') into v_missing from unnest(array['companies','roles','branches','departments','positions','profiles','empleados','permisos','rol_permisos','perfil_permisos','perfil_sucursales','perfil_departamentos','user_provisioning_audit']) x
  where to_regclass('public.'||x) is null;
  if v_missing is not null then raise exception 'Tablas faltantes: %',v_missing; end if;
  if to_regprocedure('public.tiene_permiso(text)') is null then raise exception 'Falta tiene_permiso'; end if;
  if to_regprocedure('public.provision_user_internal(jsonb)') is null then raise exception 'Falta provisioning'; end if;
  if to_regprocedure('public.bootstrap_tenant_internal(jsonb)') is null then raise exception 'Falta bootstrap'; end if;
  if not exists(select 1 from pg_constraint where conrelid='public.profiles'::regclass and conname='profiles_company_id_id_unique') then raise exception 'Falta unique tenant/profile'; end if;
  if exists(select 1 from information_schema.role_table_grants where grantee='authenticated' and table_name='profiles' and privilege_type in('INSERT','UPDATE','DELETE')) then raise exception 'authenticated conserva DML de profiles'; end if;
  if exists(select 1 from pg_class where relnamespace='public'::regnamespace and relkind='r' and relname in('companies','roles','branches','departments','positions','profiles','empleados','permisos','rol_permisos','perfil_permisos','perfil_sucursales','perfil_departamentos','user_provisioning_audit') and not relrowsecurity) then raise exception 'Tabla sin RLS'; end if;
end $$;
select pass('Contratos de arquitectura base disponibles y protegidos');
select * from finish();
rollback;
