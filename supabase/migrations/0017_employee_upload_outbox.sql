create table if not exists public.employee_upload_idempotency(
 empresa_id uuid not null references public.companies(id) on delete cascade,
 idempotency_key uuid not null,
 empleado_id uuid not null references public.empleados(id) on delete cascade,
 operation text not null check(operation in('CREATE','UPDATE')),
 created_at timestamptz not null default now(),
 primary key(empresa_id,idempotency_key)
);
alter table public.employee_upload_idempotency enable row level security;
revoke all on public.employee_upload_idempotency from public,anon,authenticated;
grant all on public.employee_upload_idempotency to service_role;
