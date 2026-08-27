$ErrorActionPreference='Stop';$root=Split-Path -Parent $PSScriptRoot
$sql=Get-Content -Raw (Join-Path $root 'supabase/migrations/0013_employee_portal_loans.sql');$app=Get-Content -Raw (Join-Path $root 'web/src/App.tsx');$web=Get-Content -Raw (Join-Path $root 'web/src/pages/EmployeePortalPage.tsx');$admin=Get-Content -Raw (Join-Path $root 'web/src/pages/LoanRequestsPage.tsx');$android=Get-Content -Raw (Join-Path $root 'app/src/main/java/com/example/controlhorario/employeeportal/EmployeeSelfServiceScreen.kt')
foreach($permission in 'empleado.perfil_ver','empleado.ganancias_ver','empleado.prestamos_ver','empleado.prestamo_solicitar','prestamos.solicitudes_ver','prestamos.solicitudes_revisar','prestamos.solicitudes_aceptar','prestamos.solicitudes_denegar','prestamos.entrega_confirmar'){if($sql-notmatch[regex]::Escape($permission)){throw "Permiso ausente: $permission"}}
if($sql-notmatch 'obtener_empleado_actual_id\(\)' -or $sql-match 'p_empleado'){throw 'El portal no debe aceptar un employee_id del cliente'}
if($sql-notmatch 'unique\(empresa_id,empleado_id,idempotency_key\)' -or $sql-notmatch 'nomina_prestamos_solicitud_uidx'){throw 'Falta idempotencia de solicitud o entrega'}
if($sql-notmatch 'cancelar_solicitud_prestamo' -or $sql-notmatch 'LOAN_PRIOR_PAYROLL_PERIOD_OPEN' -or $sql-notmatch "p.codigo='portal.acceder'"){throw 'Falta cancelación, elegibilidad de próxima nómina o acceso base del empleado'}
if($sql-notmatch "j.estado='FINALIZADA'" -or $sql-notmatch 'not j.revision_pendiente' -or $sql-notmatch "c.estado='PENDIENTE'" -or $sql-notmatch 'v_fecha-1'){throw 'Ganancias no preservan elegibilidad RC2 o exclusión de hoy'}
if($sql-notmatch "p_accion='CONFIRMAR_EFECTIVO'and v_s.estado='ACEPTADA'" -or $sql-notmatch "'ENTREGADO'"){throw 'Entrega no exige aceptación o no crea préstamo entregado'}
foreach($label in 'PERFIL','GANANCIAS HOY','PRÉSTAMO','SOLICITUD DE PRÉSTAMO'){if(($web+$android)-notmatch $label){throw "Falta sección $label"}}
if($app-notmatch '/mi-portal' -or $app-notmatch 'RequireEmployee' -or $app-notmatch 'EmployeeLayout'){throw 'Ruta web de empleado no está aislada'}
if($admin-notmatch 'CONFIRMAR_EFECTIVO' -or $admin-notmatch 'Primera confirmación'){throw 'Administración no tiene confirmación reforzada'}
if(($web+$android)-match 'service_role|pin_hash|huella|fingerprint'){throw 'El portal expone credenciales o biometría'}
Write-Output 'OK portal empleado: alcance propio, ganancias RC2/RC4, solicitudes idempotentes, transiciones y entrega única.'
