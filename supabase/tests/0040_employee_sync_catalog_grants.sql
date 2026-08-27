begin;

set local search_path = extensions, public, pg_catalog;
set local role postgres;

create extension if not exists pgtap;
select * from no_plan();

select is(
  (
    select count(*)::integer
    from (
      values
        ('public.branches'::text),
        ('public.departments'),
        ('public.positions')
    ) as t(table_name)
    where pg_catalog.has_table_privilege(
      'service_role',
      t.table_name,
      'SELECT'
    )
  ),
  3,
  'service_role puede leer los tres catalogos requeridos por employee-sync'
);

select is(
  (
    select count(*)::integer
    from (
      values
        ('public.branches'::text, 'INSERT'::text),
        ('public.branches', 'UPDATE'),
        ('public.branches', 'DELETE'),
        ('public.branches', 'TRUNCATE'),
        ('public.branches', 'REFERENCES'),
        ('public.branches', 'TRIGGER'),

        ('public.departments', 'INSERT'),
        ('public.departments', 'UPDATE'),
        ('public.departments', 'DELETE'),
        ('public.departments', 'TRUNCATE'),
        ('public.departments', 'REFERENCES'),
        ('public.departments', 'TRIGGER'),

        ('public.positions', 'INSERT'),
        ('public.positions', 'UPDATE'),
        ('public.positions', 'DELETE'),
        ('public.positions', 'TRUNCATE'),
        ('public.positions', 'REFERENCES'),
        ('public.positions', 'TRIGGER')
    ) as p(table_name, privilege_name)
    where pg_catalog.has_table_privilege(
      'service_role',
      p.table_name,
      p.privilege_name
    )
  ),
  0,
  'service_role no recibe DML ni privilegios administrativos sobre los catalogos'
);

select is(
  (
    select count(*)::integer
    from (
      values
        ('public.branches'::text),
        ('public.departments'),
        ('public.positions')
    ) as t(table_name)
    where pg_catalog.has_table_privilege(
      'service_role',
      t.table_name,
      'SELECT WITH GRANT OPTION'
    )
  ),
  0,
  'service_role no puede delegar SELECT sobre los catalogos'
);

select is(
  (
    select count(*)::integer
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n
      on n.oid = c.relnamespace
    cross join lateral pg_catalog.aclexplode(c.relacl) a
    where n.nspname = 'public'
      and c.relname in ('branches', 'departments', 'positions')
      and a.grantee = (
        select oid
        from pg_catalog.pg_roles
        where rolname = 'service_role'
      )
      and (
        pg_catalog.upper(a.privilege_type) <> 'SELECT'
        or a.is_grantable
      )
  ),
  0,
  'ACL directa de service_role queda limitada a SELECT no delegable'
);

select is(
  (
    select count(*)::integer
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n
      on n.oid = c.relnamespace
    join pg_catalog.pg_attribute att
      on att.attrelid = c.oid
     and att.attnum > 0
     and not att.attisdropped
    cross join lateral pg_catalog.aclexplode(att.attacl) a
    where n.nspname = 'public'
      and c.relname in ('branches', 'departments', 'positions')
      and a.grantee = (
        select oid
        from pg_catalog.pg_roles
        where rolname = 'service_role'
      )
  ),
  0,
  'service_role no tiene ACL directas a nivel de columna'
);

select * from finish();
rollback;