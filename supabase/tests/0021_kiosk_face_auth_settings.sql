begin;
select plan(9);

select has_table('public','company_settings');
select has_column('public','company_settings','face_only_enabled');
select has_column('public','company_settings','pin_fallback_enabled');
select has_column('public','company_settings','face_match_threshold');
select has_column('public','company_settings','face_match_margin');
select has_function('public','actualizar_configuracion_kiosk',array['boolean','boolean','numeric','numeric','text']);
select ok(
 exists(select 1 from public.permisos where codigo='kiosk.pin_fallback_manage' and activo),
 'existe permiso activo para administrar el fallback PIN'
);
select ok(
 not has_table_privilege('authenticated','public.company_settings','UPDATE'),
 'authenticated no puede omitir el RPC con UPDATE directo'
);
select ok(
 has_function_privilege('authenticated','public.actualizar_configuracion_kiosk(boolean,boolean,numeric,numeric,text)','EXECUTE'),
 'authenticated puede invocar el RPC, que valida el permiso exacto internamente'
);

select * from finish();
rollback;
