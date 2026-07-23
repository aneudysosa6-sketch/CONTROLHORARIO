import { useEffect, useMemo, useState } from 'react';
import { Badge, Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { administrationService, type OrganizationData, type Schedule } from '../modules/administration/administrationService';
import { supervisorService, type SupervisorSchedule } from '../modules/supervisor/supervisorService';

type ScheduleScope = 'all' | 'team';

const emptyOrganization: OrganizationData = {
  branches: [], departments: [], positions: [], profiles: [], employees: [], roles: [],
  permissions: [], departmentAssignments: [], rolePermissions: [],
};

export function SchedulesPage() {
  const { hasPermission } = useAuth();
  const canViewAll = hasPermission('configuracion.administrar') || hasPermission('configuracion.horarios');
  const canViewTeam = hasPermission('horarios.ver_asignados');
  const canEditTeam = hasPermission('horarios.editar_asignados');
  const [scope, setScope] = useState<ScheduleScope>(canViewAll ? 'all' : 'team');
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [teamSchedules, setTeamSchedules] = useState<SupervisorSchedule[]>([]);
  const [organization, setOrganization] = useState<OrganizationData>(emptyOrganization);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadAll = async () => {
    setLoading(true);
    setError('');
    try {
      const [nextSchedules, nextOrganization] = await Promise.all([
        administrationService.schedules(),
        administrationService.organization(),
      ]);
      setSchedules(nextSchedules);
      setOrganization(nextOrganization);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible cargar los horarios.');
    } finally {
      setLoading(false);
    }
  };

  const loadTeam = async () => {
    setLoading(true);
    setError('');
    try {
      setTeamSchedules(await supervisorService.schedules());
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible cargar los horarios de tu equipo.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!canViewAll && canViewTeam) setScope('team');
  }, [canViewAll, canViewTeam]);

  useEffect(() => {
    void (scope === 'team' ? loadTeam() : loadAll());
  }, [scope]);

  const activeSchedules = useMemo(() => scope === 'team'
    ? teamSchedules.filter((schedule) => schedule.activo)
    : schedules.filter((schedule) => schedule.activo), [scope, schedules, teamSchedules]);
  const averageTolerance = activeSchedules.length
    ? Math.round(activeSchedules.reduce((total, schedule) => total + schedule.tolerancia_min, 0) / activeSchedules.length)
    : null;
  const averageLunch = activeSchedules.length
    ? Math.round(activeSchedules.reduce((total, schedule) => total + schedule.duracion_almuerzo_min, 0) / activeSchedules.length)
    : null;

  const editTeamSchedule = async (schedule: SupervisorSchedule) => {
    const reason = window.prompt('Motivo obligatorio del cambio')?.trim();
    if (!reason) return;
    const date = window.prompt('Vigente desde YYYY-MM-DD')?.trim() || schedule.fecha_vigencia;
    const start = window.prompt('Entrada HH:MM')?.trim() || schedule.hora_entrada;
    const end = window.prompt('Salida HH:MM')?.trim() || schedule.hora_salida;
    const lunch = window.prompt('Inicio almuerzo HH:MM (vacío si no aplica)')?.trim() || schedule.inicio_almuerzo;
    const duration = Number(window.prompt('Duración almuerzo minutos')?.trim() || schedule.duracion_almuerzo_min);
    const tolerance = Number(window.prompt('Tolerancia minutos')?.trim() || schedule.tolerancia_min);
    try {
      setError('');
      await supervisorService.saveSchedule({
        employeeId: schedule.empleado_id,
        date,
        start,
        end,
        lunch,
        duration,
        days: schedule.dias_laborales,
        tolerance,
        reason,
      });
      await loadTeam();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible actualizar el horario.');
    }
  };

  return <>
    <PageHeader
      eyebrow="CONFIGURACIÓN"
      title="Horarios"
      description={scope === 'team' ? 'Horarios de los departamentos que tienes asignados.' : 'Turnos, días laborales, almuerzo y tolerancia de la empresa.'}
    />
    {canViewTeam && <div className="toolbar"><label className="employee-cell"><input type="checkbox" checked={scope === 'team'} onChange={(event) => setScope(event.target.checked ? 'team' : 'all')} disabled={!canViewAll} />Solo mi equipo</label></div>}
    {error && <div className="error" role="alert">{error}</div>}
    <section className="stats admin-mini-stats">
      <article className="stat"><span>Turnos activos</span><strong>{activeSchedules.length}</strong></article>
      <article className="stat"><span>Tolerancia configurada</span><strong>{averageTolerance == null ? '—' : `${averageTolerance} min`}</strong></article>
      <article className="stat"><span>Almuerzo promedio</span><strong>{averageLunch == null ? '—' : `${averageLunch} min`}</strong></article>
    </section>
    {scope === 'team' ? <section className="table-wrap payroll-wide">
      <table><thead><tr><th>Empleado</th><th>Alcance</th><th>Vigencia</th><th>Horario</th><th>Almuerzo</th><th>Tolerancia</th><th>Acciones</th></tr></thead><tbody>{teamSchedules.map((schedule) => <tr key={schedule.id}>
        <td>{schedule.codigo} · {schedule.nombre}</td><td>{schedule.sucursal} · {schedule.departamento}</td><td>{schedule.fecha_vigencia}{schedule.fecha_fin ? ` → ${schedule.fecha_fin}` : ''}</td>
        <td>{schedule.hora_entrada} – {schedule.hora_salida}</td><td>{schedule.inicio_almuerzo || '—'} · {schedule.duracion_almuerzo_min} min</td><td>{schedule.tolerancia_min} min</td>
        <td>{canEditTeam && <button type="button" className="secondary" onClick={() => void editTeamSchedule(schedule)}>Editar</button>}</td>
      </tr>)}</tbody></table>
      {loading && <Empty text="Cargando horarios…" />}
      {!loading && !teamSchedules.length && <Empty text="No hay horarios en tu equipo." />}
    </section> : <section className="table-wrap payroll-wide">
      <table><thead><tr><th>Empleado</th><th>Vigencia</th><th>Turno</th><th>Días</th><th>Tolerancia / almuerzo</th></tr></thead><tbody>{schedules.map((schedule) => {
        const employee = organization.employees.find((item) => item.id === schedule.empleado_id);
        return <tr key={schedule.id}><td>{employee ? `${employee.codigo_empleado} · ${employee.nombre_completo}` : schedule.empleado_id}</td><td>{schedule.fecha_vigencia}{schedule.fecha_fin ? ` → ${schedule.fecha_fin}` : ''}</td><td>{schedule.hora_entrada} – {schedule.hora_salida}</td><td>{schedule.dias_laborales.join(', ')}</td><td><Badge tone={schedule.activo ? 'green' : 'gray'}>{schedule.tolerancia_min} min / {schedule.duracion_almuerzo_min} min</Badge></td></tr>;
      })}</tbody></table>
      {loading && <Empty text="Cargando horarios…" />}
      {!loading && !schedules.length && <Empty text="No hay horarios configurados." />}
    </section>}
  </>;
}
