-- Módulo 2.2: relación opcional de supervisor para sincronización Android.
alter table public.empleados
  add column if not exists supervisor_id uuid;

alter table public.empleados
  drop constraint if exists empleados_supervisor_misma_empresa_fk;

alter table public.empleados
  add constraint empleados_supervisor_misma_empresa_fk
    foreign key (empresa_id, supervisor_id)
    references public.empleados(empresa_id, id)
    on delete set null (supervisor_id);

create index if not exists empleados_supervisor_idx
  on public.empleados(empresa_id, supervisor_id)
  where supervisor_id is not null;

comment on column public.empleados.supervisor_id is
  'Supervisor laboral opcional del mismo tenant; no concede permisos de acceso.';
