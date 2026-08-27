begin;

create or replace function public.validar_cronologia_evento_jornada()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_ultimo timestamptz;
begin
  if new.ocurrido_en > statement_timestamp() + interval '5 minutes' then
    raise exception using errcode = 'P4801', message = 'ATTENDANCE_EVENT_IN_FUTURE';
  end if;

  select max(evento.ocurrido_en)
    into v_ultimo
  from public.jornada_eventos evento
  where evento.empresa_id = new.empresa_id
    and evento.jornada_id = new.jornada_id;

  if v_ultimo is not null and new.ocurrido_en < v_ultimo then
    raise exception using errcode = 'P4802', message = 'ATTENDANCE_EVENT_NON_MONOTONIC';
  end if;

  return new;
end;
$$;

drop trigger if exists jornada_eventos_cronologia_guard on public.jornada_eventos;
create trigger jornada_eventos_cronologia_guard
before insert on public.jornada_eventos
for each row execute function public.validar_cronologia_evento_jornada();

alter table public.jornadas
  drop constraint if exists jornadas_cronologia_check;
alter table public.jornadas
  add constraint jornadas_cronologia_check check (
    (iniciado_en is null or pausa_iniciada_en is null or iniciado_en <= pausa_iniciada_en)
    and (pausa_iniciada_en is null or pausa_finalizada_en is null or pausa_iniciada_en <= pausa_finalizada_en)
    and (iniciado_en is null or finalizado_en is null or iniciado_en <= finalizado_en)
    and (pausa_finalizada_en is null or finalizado_en is null or pausa_finalizada_en <= finalizado_en)
    and minutos_trabajados >= 0
    and minutos_pausa >= 0
  ) not valid;

revoke all on function public.validar_cronologia_evento_jornada() from public, anon, authenticated;

commit;