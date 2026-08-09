-- 0037 postflight: catalog-only and SELECT-only.
-- Expected: authenticated=true/direct, anon=false, PUBLIC=false.

with identifiers as (
  select
    pg_catalog.to_regprocedure(
      'public.tiene_permiso(text)'
    ) as function_oid,
    pg_catalog.to_regrole('authenticated') as authenticated_oid,
    pg_catalog.to_regrole('anon') as anon_oid
),
function_state as (
  select
    i.function_oid,
    i.authenticated_oid,
    i.anon_oid,
    p.proacl,
    p.proowner
  from identifiers i
  left join pg_catalog.pg_proc p on p.oid = i.function_oid
),
observed as (
  select
    f.function_oid is not null as function_exists,
    f.authenticated_oid is not null as authenticated_exists,
    f.anon_oid is not null as anon_exists,
    case
      when f.function_oid is null or f.authenticated_oid is null then null
      else pg_catalog.has_function_privilege(
        f.authenticated_oid,
        f.function_oid,
        'EXECUTE'
      )
    end as authenticated_effective,
    exists (
      select 1
      from pg_catalog.aclexplode(f.proacl) acl
      where acl.grantee = f.authenticated_oid
        and pg_catalog.upper(acl.privilege_type) = 'EXECUTE'
    ) as authenticated_direct,
    exists (
      select 1
      from pg_catalog.aclexplode(f.proacl) acl
      where acl.grantee = f.authenticated_oid
        and pg_catalog.upper(acl.privilege_type) = 'EXECUTE'
        and acl.is_grantable
    ) as authenticated_direct_grantable,
    case
      when f.function_oid is null or f.anon_oid is null then null
      else pg_catalog.has_function_privilege(
        f.anon_oid,
        f.function_oid,
        'EXECUTE'
      )
    end as anon_effective,
    exists (
      select 1
      from pg_catalog.aclexplode(f.proacl) acl
      where acl.grantee = f.anon_oid
        and pg_catalog.upper(acl.privilege_type) = 'EXECUTE'
    ) as anon_direct,
    case
      when f.function_oid is null then null
      when f.proacl is null then true
      else exists (
        select 1
        from pg_catalog.aclexplode(f.proacl) acl
        where acl.grantee = 0
          and pg_catalog.upper(acl.privilege_type) = 'EXECUTE'
      )
    end as public_execute
  from function_state f
)
select
  o.*,
  o.function_exists
    and o.authenticated_exists
    and o.anon_exists
    and o.authenticated_effective is true
    and o.authenticated_direct is true
    and o.authenticated_direct_grantable is false
    and o.anon_effective is false
    and o.anon_direct is false
    and o.public_execute is false
    as acl_matches_expected
from observed o;
