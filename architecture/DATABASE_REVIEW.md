# Database Review

Hallazgos críticos: drift de `profiles_company_id_id_unique`; escritura cliente histórica sobre profiles; bootstrap dependiente de seed tenant; User Provisioning original no creaba tenant; datos Android heredados con PIN/credenciales locales; módulos web aún mock; ausencia de modelo cloud implementado para asistencia/nómina/Storage/Realtime.

Corregido en diseño FINAL: unicidad declarada en `0001_FINAL`; 0002 no la recrea; 0003 revoca DML de profiles; bootstrap crea empresa, rol admin, sucursal, profile, permisos y empleado opcional; tenant ordinario se fuerza desde el actor; auditoría es inmutable.

No hay FK circulares. `profiles → auth.users`; `empleados → profiles` es opcional y no vuelve hacia empleados desde profiles. Funciones se crean después de sus dependencias. Triggers apuntan a funciones existentes. `service_role` no aparece en clientes.
