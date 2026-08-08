-- Privilegios directos minimos para las Edge Functions de administracion.
-- Las tablas de alcance se escriben exclusivamente mediante RPC SECURITY DEFINER.

begin;

-- user-provisioning y employee-management solo leen perfiles. Los cambios de
-- perfil se realizan mediante los contratos internos versionados.
revoke insert, update, delete, truncate, references, trigger
  on table public.profiles
  from service_role;
grant select
  on table public.profiles
  to service_role;

-- user-provisioning resuelve y valida el rol solicitado, pero no administra el
-- catalogo de roles mediante DML directo.
revoke insert, update, delete, truncate, references, trigger
  on table public.roles
  from service_role;
grant select
  on table public.roles
  to service_role;

-- employee-management lee, crea y actualiza empleados. Las bajas son logicas y
-- no existe ningun flujo autorizado que elimine filas directamente.
revoke delete, truncate, references, trigger
  on table public.empleados
  from service_role;
grant select, insert, update
  on table public.empleados
  to service_role;

-- El alcance de supervisores siempre pasa por las RPC de 0033. Se revoca DML
-- directo sin alterar SELECT, RLS, policies ni los grants EXECUTE existentes.
revoke insert, update, delete
  on table public.perfil_sucursales
  from service_role;
revoke insert, update, delete
  on table public.perfil_departamentos
  from service_role;

commit;
