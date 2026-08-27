-- Normalize only EXECUTE on public.tiene_permiso(text).
-- The function definition and every non-function ACL remain unchanged.

begin;

do $tiene_permiso_execute_preflight$
declare
  v_function_oid oid :=
    pg_catalog.to_regprocedure('public.tiene_permiso(text)');
  v_authenticated_oid oid :=
    pg_catalog.to_regrole('authenticated');
  v_anon_oid oid :=
    pg_catalog.to_regrole('anon');
begin
  if v_function_oid is null then
    raise exception using
      errcode = '42883',
      message = 'TIENE_PERMISO_FUNCTION_NOT_FOUND';
  end if;

  if v_authenticated_oid is null then
    raise exception using
      errcode = '42704',
      message = 'AUTHENTICATED_ROLE_NOT_FOUND';
  end if;

  if v_anon_oid is null then
    raise exception using
      errcode = '42704',
      message = 'ANON_ROLE_NOT_FOUND';
  end if;
end;
$tiene_permiso_execute_preflight$;

-- RESTRICT is intentional. A dependent grant must stop the migration rather
-- than be removed transitively.
revoke all privileges on function public.tiene_permiso(text)
from public, anon, authenticated
restrict;

grant execute on function public.tiene_permiso(text)
to authenticated;

do $tiene_permiso_execute_validation$
declare
  v_function_oid oid :=
    pg_catalog.to_regprocedure('public.tiene_permiso(text)');
  v_authenticated_oid oid :=
    pg_catalog.to_regrole('authenticated');
  v_anon_oid oid :=
    pg_catalog.to_regrole('anon');
  v_authenticated_effective boolean;
  v_authenticated_direct boolean;
  v_authenticated_grantable boolean;
  v_anon_effective boolean;
  v_anon_direct boolean;
  v_public_execute boolean;
begin
  select
    pg_catalog.has_function_privilege(
      v_authenticated_oid,
      p.oid,
      'EXECUTE'
    ),
    exists (
      select 1
      from pg_catalog.aclexplode(p.proacl) acl
      where acl.grantee = v_authenticated_oid
        and pg_catalog.upper(acl.privilege_type) = 'EXECUTE'
    ),
    exists (
      select 1
      from pg_catalog.aclexplode(p.proacl) acl
      where acl.grantee = v_authenticated_oid
        and pg_catalog.upper(acl.privilege_type) = 'EXECUTE'
        and acl.is_grantable
    ),
    pg_catalog.has_function_privilege(
      v_anon_oid,
      p.oid,
      'EXECUTE'
    ),
    exists (
      select 1
      from pg_catalog.aclexplode(p.proacl) acl
      where acl.grantee = v_anon_oid
        and pg_catalog.upper(acl.privilege_type) = 'EXECUTE'
    ),
    exists (
      select 1
      from pg_catalog.aclexplode(p.proacl) acl
      where acl.grantee = 0
        and pg_catalog.upper(acl.privilege_type) = 'EXECUTE'
    )
  into strict
    v_authenticated_effective,
    v_authenticated_direct,
    v_authenticated_grantable,
    v_anon_effective,
    v_anon_direct,
    v_public_execute
  from pg_catalog.pg_proc p
  where p.oid = v_function_oid;

  if v_authenticated_effective is not true
     or v_authenticated_direct is not true
     or v_authenticated_grantable is true
     or v_anon_effective is true
     or v_anon_direct is true
     or v_public_execute is true then
    raise exception using
      errcode = '42501',
      message = 'TIENE_PERMISO_EXECUTE_MATRIX_MISMATCH',
      detail = pg_catalog.format(
        'authenticated_effective=%s, authenticated_direct=%s, authenticated_grantable=%s, anon_effective=%s, anon_direct=%s, public_execute=%s',
        coalesce(v_authenticated_effective::text, 'NULL'),
        coalesce(v_authenticated_direct::text, 'NULL'),
        coalesce(v_authenticated_grantable::text, 'NULL'),
        coalesce(v_anon_effective::text, 'NULL'),
        coalesce(v_anon_direct::text, 'NULL'),
        coalesce(v_public_execute::text, 'NULL')
      );
  end if;
end;
$tiene_permiso_execute_validation$;

commit;
