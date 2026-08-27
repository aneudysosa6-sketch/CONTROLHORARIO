begin;

do $$
declare
  v_definition text;
  v_old text := 'when v_accion=''REANUDAR'' then v_ocurrido else pausa_finalizada_en end';
  v_new text := 'when v_accion=''PAUSAR'' then null when v_accion=''REANUDAR'' then v_ocurrido else pausa_finalizada_en end';
begin
  select pg_catalog.pg_get_functiondef(
    'public.registrar_evento_jornada_dispositivo(jsonb)'::regprocedure
  ) into v_definition;
  if pg_catalog.strpos(v_definition, v_new) = 0 then
    if pg_catalog.strpos(v_definition, v_old) = 0 then
      raise exception 'ATTENDANCE_SECOND_PAUSE_ANCHOR_NOT_FOUND';
    end if;
    execute pg_catalog.replace(v_definition, v_old, v_new);
  end if;
end;
$$;

do $$
declare
  v_definition text;
  v_old text := 'raise exception ''PAYROLL_EMPLOYEE_CONFIGURATION_INVALID:%'', v_employee.id;';
  v_new text := 'return jsonb_build_object(''status'',''BLOCKED_CONFIGURATION'',''inserted'',0,''reason'',''PAYROLL_EMPLOYEE_CONFIGURATION_INVALID'');';
begin
  select pg_catalog.pg_get_functiondef(
    'private.devengar_movimientos_nomina_jornada(uuid,uuid,text)'::regprocedure
  ) into v_definition;
  if pg_catalog.strpos(v_definition, v_new) = 0 then
    if pg_catalog.strpos(v_definition, v_old) = 0 then
      raise exception 'PAYROLL_CONFIGURATION_RECOVERY_ANCHOR_NOT_FOUND';
    end if;
    execute pg_catalog.replace(v_definition, v_old, v_new);
  end if;
end;
$$;

commit;