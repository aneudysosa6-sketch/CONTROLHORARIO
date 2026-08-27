begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select plan(4);
select has_function('public', 'preview_next_employee_code_internal', array['uuid']);
select has_function('public', 'allocate_next_employee_code_internal', array['uuid','uuid']);
select ok(
  pg_get_functiondef('public.preview_next_employee_code_internal(uuid)'::regprocedure)
    like '%pg_catalog.random()%',
  'preview starts from a random six-digit candidate'
);
select ok(
  pg_get_functiondef('public.allocate_next_employee_code_internal(uuid,uuid)'::regprocedure)
    not like '%v_last + 1%',
  'allocator no longer increments a monotonic sequence'
);
select * from finish();
rollback;