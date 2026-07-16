# Investigación de proyectos HRMS de referencia

Investigación realizada sobre documentación y repositorios oficiales. Se adoptan patrones, no código, fórmulas ni identidad visual.

| Proyecto | Módulos útiles | Patrones recomendados | Patrones que no convienen | Ideas para CONTROLHORARIO | Riesgos | Fuente oficial |
|---|---|---|---|---|---|---|
| Frappe HR / ERPNext HR | empleado maestro, turnos, asistencia, licencias, nómina, reportes | prerequisitos explícitos; documentos maestros vs transacciones; nómina por componentes y asistencia | fórmulas/localización ajenas; amplitud ERP completa | entrada de nómina por período; estados submit/approve; reportes mensuales | motor demasiado configurable sin gobierno | [Frappe HR](https://docs.frappe.io/hr/), [repositorio](https://github.com/frappe/hrms) |
| Odoo Employees | expediente, contratos, departamentos, presencia, offboarding | ficha central con pestañas y acciones relacionadas; maestro separado de acceso | replicar CRM/equipos/badges no prioritarios | ficha 360° del empleado y baja sin borrar historial | exceso de campos y acoplamiento | [Employees](https://www.odoo.com/documentation/18.0/applications/hr/employees.html) |
| Odoo Attendances | dashboard, check-in/out, kiosco, errores, GPS/método | propio/equipo; registros con modo, IP/GPS; errores previos a nómina | reducir CONTROLHORARIO a entrada/salida; reemplazar 4 eventos | panel de incidencias y métodos/orígenes auditables | edición manual sin trazabilidad | [Attendances](https://www.odoo.com/documentation/18.0/applications/hr/attendances.html) |
| Odoo Time Off | tipos, saldos, calendario, adjuntos, doble aprobación | Mi tiempo vs Gestión; solicitudes por horas/días; documentos y niveles | importar reglas de acumulación/localización | portal personal, bandeja “esperando por mí”, porcentaje configurable propio | saldos incorrectos por calendario | [Time Off](https://www.odoo.com/documentation/18.0/applications/hr/time_off.html) |
| Odoo Planning | turnos, recursos, Gantt, publicación | planificación visual separada del horario contractual; vigencias | complejidad de proyectos/ventas | rotaciones, publicación y cambios temporales | sobreplanificación móvil | [Planning](https://www.odoo.com/documentation/18.0/applications/services/planning.html) |
| Odoo Payroll | work entries, estructuras, reglas, recibos | capa intermedia asistencia/ausencia→work entries→nómina; conflictos visibles | reglas fiscales/localizaciones copiadas | pre-nómina reproducible y período bloqueable | fórmulas dinámicas inseguras | [Payroll](https://www.odoo.com/documentation/16.0/applications/hr/payroll.html), [Work entries](https://www.odoo.com/documentation/19.0/applications/hr/payroll/work_entries.html) |
| OrangeHRM | PIM, Admin, Leave, Time, Attendance, ESS | separación Admin/PIM/Leave/Time; supervisor ve subordinados; módulos activables | arquitectura web/PHP como molde; flujos antiguos | navegación por dominios, portal “Mi información”, aprobaciones masivas | permisos históricos inconsistentes | [repositorio](https://github.com/orangehrm/orangehrm), [Leave oficial](https://starterhelp.orangehrm.com/hc/en-us/sections/360005148219-Leave) |
| Kimai | timesheets, equipos, permisos, reportes, auditoría | permisos own/other; alcance por equipo; bloqueo tras exportar; auditoría | facturación/proyectos como núcleo de RRHH | propio/departamento/empresa; períodos cerrados; acciones auditadas | modelo de tiempo por proyectos no equivale a jornada | [Timesheet](https://www.kimai.org/documentation/timesheet.html), [Permissions](https://www.kimai.org/documentation/permissions.html) |
| OCA HR Attendance | historial, razones, teórico vs real, descansos, RFID | addons pequeños por capacidad; razones de corrección; análisis esperado/real | instalar/copiar módulos AGPL o depender de Odoo | módulos desacoplados, adaptador de lector, reporte horario esperado | fragmentación por addons | [OCA hr-attendance](https://github.com/OCA/hr-attendance) |
| OCA Payroll | payroll, contabilidad, ventajas, feriados | núcleo pequeño + integraciones opcionales; contratos/feriados separados | copiar implementación/licencia o contabilidad completa ahora | paquetes por dominio y dependencias explícitas | localización y contabilidad complejas | [OCA payroll](https://github.com/OCA/payroll) |

## Síntesis adoptada

1. Navegación: Inicio, Mi portal, Personal, Tiempo, Ausencias, Nómina, Reportes, Administración y Sistema.
2. Separación: empleado maestro; evento de ponche; jornada calculada; horario esperado; ausencia aprobada; entrada de nómina.
3. Vistas por alcance: propio, departamento, sucursal, empresa y global.
4. Bandejas de pendientes y errores antes de nómina.
5. Períodos aprobados/exportados bloqueados; cambios mediante corrección o nueva versión.
6. Módulos por dominio y adaptadores de infraestructura, no una clase/navegación monolítica.

## Patrones rechazados

- Copiar fórmulas fiscales, porcentajes, esquemas visuales o localizaciones extranjeras.
- Convertir asistencia en timesheets de proyecto.
- Exponer edición directa de eventos históricos o nómina cerrada.
- Introducir CRM, facturación, reclutamiento o desempeño antes de estabilizar el núcleo.
- Depender de nombres de rol sin permiso y alcance efectivos.
- Sustituir el lector Android/2Connect por kiosco web simulado.
