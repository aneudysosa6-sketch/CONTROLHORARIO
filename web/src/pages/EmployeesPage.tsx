import { useEffect, useMemo, useState } from 'react';
import { Eye, FileDown, Plus, Search, UserMinus } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Badge, Empty, PageHeader, Toast } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { exportEmployeesPdf, exportEmployeesXlsx } from '../modules/employees/employeeExports';
import { EmployeeLifecycleDialog } from '../modules/employees/EmployeeLifecycleDialog';
import { EmployeePagination } from '../modules/employees/EmployeePagination';
import { employeeService, type EmployeeRecord, type EmployeeStatus } from '../modules/employees/employeeService';
import { supervisorService, type SupervisorEmployee } from '../modules/supervisor/supervisorService';

const PAGE_SIZE = 20;

type EmployeeScope = 'all' | 'team';

function TeamEmployeesTable({
  items,
  loading,
  error,
  onReload,
  onError,
}: {
  items: SupervisorEmployee[];
  loading: boolean;
  error: string;
  onReload: () => Promise<void>;
  onError: (message: string) => void;
}) {
  const { hasPermission } = useAuth();
  const [query, setQuery] = useState('');
  const [branch, setBranch] = useState('');
  const [department, setDepartment] = useState('');
  const [employment, setEmployment] = useState('');
  const [enabled, setEnabled] = useState('');

  const rows = useMemo(() => items.filter((employee) =>
    (!query || `${employee.codigo} ${employee.nombre}`.toLowerCase().includes(query.toLowerCase())) &&
    (!branch || employee.sucursal === branch) &&
    (!department || employee.departamento === department) &&
    (!employment || employee.estado_laboral === employment) &&
    (!enabled || String(employee.jornada_habilitada) === enabled),
  ), [items, query, branch, department, employment, enabled]);

  const run = async (action: () => Promise<unknown>) => {
    try {
      onError('');
      await action();
      await onReload();
    } catch (reason) {
      onError(reason instanceof Error ? reason.message : 'No fue posible actualizar al empleado del equipo.');
    }
  };

  const toggleAttendance = async (employee: SupervisorEmployee) => {
    const reason = window.prompt(`Motivo obligatorio para ADMIN-${employee.jornada_habilitada ? 'OFF' : 'ON'}`)?.trim();
    if (!reason) return;
    await run(() => supervisorService.setAttendance(employee.id, !employee.jornada_habilitada, reason));
  };

  const registerManualJourney = async (employee: SupervisorEmployee) => {
    const date = window.prompt('Fecha laboral YYYY-MM-DD')?.trim();
    const reason = window.prompt('Motivo obligatorio del registro manual')?.trim();
    if (!date || !reason) return;
    const start = window.prompt('Llegada ISO')?.trim() ?? '';
    const breakStart = window.prompt('Inicio almuerzo ISO (vacío si no aplica)')?.trim() || null;
    const breakEnd = window.prompt('Regreso almuerzo ISO (vacío si no aplica)')?.trim() || null;
    const end = window.prompt('Salida ISO')?.trim() ?? '';
    await run(() => supervisorService.manual(employee.id, date, { start, breakStart, breakEnd, end }, reason));
  };

  const updateSchedule = async (employee: SupervisorEmployee) => {
    const reason = window.prompt('Motivo obligatorio del horario')?.trim();
    const date = window.prompt('Vigente desde YYYY-MM-DD')?.trim();
    if (!reason || !date) return;
    const start = window.prompt('Entrada HH:MM')?.trim() ?? '';
    const end = window.prompt('Salida HH:MM')?.trim() ?? '';
    const lunch = window.prompt('Inicio almuerzo HH:MM (vacío si no aplica)')?.trim() || null;
    const duration = Number(window.prompt('Duración almuerzo minutos')?.trim() || 60);
    const tolerance = Number(window.prompt('Tolerancia minutos')?.trim() || 15);
    await run(() => supervisorService.saveSchedule({
      employeeId: employee.id,
      date,
      start,
      end,
      lunch,
      duration,
      days: [1, 2, 3, 4, 5],
      tolerance,
      reason,
    }));
  };

  return <>
    {error && <div className="error" role="alert">{error}</div>}
    <div className="report-filters">
      <label>Buscar<input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Código o nombre" /></label>
      <label>Sucursal<select value={branch} onChange={(event) => setBranch(event.target.value)}><option value="">Todas</option>{[...new Set(items.map((item) => item.sucursal))].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Departamento<select value={department} onChange={(event) => setDepartment(event.target.value)}><option value="">Todos</option>{[...new Set(items.map((item) => item.departamento))].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Estado<select value={employment} onChange={(event) => setEmployment(event.target.value)}><option value="">Todos</option>{[...new Set(items.map((item) => item.estado_laboral))].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Jornada<select value={enabled} onChange={(event) => setEnabled(event.target.value)}><option value="">Todas</option><option value="true">Habilitada</option><option value="false">Deshabilitada</option></select></label>
    </div>
    <section className="table-wrap payroll-wide">
      <table>
        <thead><tr><th>Empleado</th><th>Alcance</th><th>Cargo</th><th>Jornada</th><th>Estado</th><th>Horario</th><th>Acciones</th></tr></thead>
        <tbody>{rows.map((employee) => <tr key={employee.id}>
          <td><b>{employee.codigo} · {employee.nombre}</b><small>{employee.telefono || 'Teléfono restringido'}</small></td>
          <td>{employee.sucursal} · {employee.departamento}</td>
          <td>{employee.cargo}</td>
          <td><Badge tone={employee.jornada_habilitada ? 'green' : 'red'}>{employee.jornada_habilitada ? 'ON' : 'OFF'}</Badge></td>
          <td>{employee.estado_laboral} · {employee.estado_jornada}</td>
          <td>{employee.horario_resumen || 'Sin horario'}</td>
          <td><div className="button-row">
            {hasPermission('jornadas.admin_off_on') && <button type="button" onClick={() => void toggleAttendance(employee)}>ADMIN-{employee.jornada_habilitada ? 'OFF' : 'ON'}</button>}
            {hasPermission('jornadas.corregir_asignadas') && <button type="button" onClick={() => void registerManualJourney(employee)}>Tiempo manual</button>}
            {hasPermission('horarios.editar_asignados') && <button type="button" onClick={() => void updateSchedule(employee)}>Horario</button>}
          </div></td>
        </tr>)}</tbody>
      </table>
      {loading && <Empty text="Cargando empleados de tu equipo…" />}
      {!loading && !rows.length && <Empty text="No hay empleados de tu equipo que coincidan con los filtros." />}
    </section>
  </>;
}

export function EmployeesPage() {
  const { hasPermission } = useAuth();
  const canViewAll = hasPermission('empleados.view');
  const canViewTeam = hasPermission('empleados.ver_asignados');
  const [scope, setScope] = useState<EmployeeScope>(canViewAll ? 'all' : 'team');
  const [items, setItems] = useState<EmployeeRecord[]>([]);
  const [teamItems, setTeamItems] = useState<SupervisorEmployee[]>([]);
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<EmployeeStatus | 'todos'>('todos');
  const [branch, setBranch] = useState('');
  const [department, setDepartment] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [terminating, setTerminating] = useState<EmployeeRecord | null>(null);

  const loadAll = async () => {
    setLoading(true);
    setError('');
    try {
      setItems(await employeeService.listActive());
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible cargar empleados.');
    } finally {
      setLoading(false);
    }
  };

  const loadTeam = async () => {
    setLoading(true);
    setError('');
    try {
      setTeamItems(await supervisorService.employees());
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible cargar los empleados asignados.');
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

  useEffect(() => { setPage(1); }, [query, status, branch, department]);

  const rows = useMemo(() => items.filter((employee) =>
    employee.status !== 'desvinculado' &&
    (status === 'todos' || employee.status === status) &&
    (!branch || employee.branchName === branch) &&
    (!department || employee.departmentName === department) &&
    `${employee.code} ${employee.name} ${employee.cedula}`.toLowerCase().includes(query.trim().toLowerCase()),
  ), [items, query, status, branch, department]);
  const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const visibleRows = rows.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);
  const branches = [...new Set(items.map((item) => item.branchName).filter(Boolean))];
  const departments = [...new Set(items.map((item) => item.departmentName).filter(Boolean))];
  const canTerminate = hasPermission('empleados.desactivar');
  const canCreate = hasPermission('empleados.create');

  return <>
    <PageHeader
      eyebrow="CAPITAL HUMANO"
      title="Empleados"
      description={scope === 'team'
        ? 'Personal dentro de tus departamentos asignados. Las acciones conservan su alcance y auditoría.'
        : 'Personal operativo. Los expedientes desvinculados se conservan en Empleados dados de baja.'}
      action={scope === 'all' ? <div className="button-row">
        <button type="button" className="secondary" disabled={!rows.length} onClick={() => void exportEmployeesPdf(rows, 'empleados-operativos.pdf')}>Exportar PDF</button>
        <button type="button" className="secondary" disabled={!rows.length} onClick={() => void exportEmployeesXlsx(rows, 'empleados-operativos.xlsx')}><FileDown />Exportar Excel</button>
        <button type="button" className="secondary" onClick={() => window.print()}>Imprimir</button>
        {canCreate && <Link className="primary" to="/empleados/nuevo"><Plus />Nuevo empleado</Link>}
      </div> : undefined}
    />

    {canViewTeam && <div className="toolbar">
      <div className="filter-row">
        <label>Alcance<select aria-label="Filtrar empleados por alcance" value={scope} onChange={(event) => setScope(event.target.value as EmployeeScope)}>
          {canViewAll && <option value="all">Todos los empleados</option>}
          <option value="team">Solo mi equipo</option>
        </select></label>
      </div>
    </div>}

    {scope === 'team' ? <TeamEmployeesTable items={teamItems} loading={loading} error={error} onReload={loadTeam} onError={setError} /> : <>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="toolbar">
        <div className="search"><Search /><input placeholder="Buscar por código, nombre o cédula" value={query} onChange={(event) => setQuery(event.target.value)} /></div>
        <div className="filter-row">
          <select aria-label="Filtrar por sucursal" value={branch} onChange={(event) => setBranch(event.target.value)}><option value="">Todas las sucursales</option>{branches.map((value) => <option key={value}>{value}</option>)}</select>
          <select aria-label="Filtrar por departamento" value={department} onChange={(event) => setDepartment(event.target.value)}><option value="">Todos los departamentos</option>{departments.map((value) => <option key={value}>{value}</option>)}</select>
          <select aria-label="Filtrar por estado laboral" value={status} onChange={(event) => setStatus(event.target.value as EmployeeStatus | 'todos')}>
            <option value="todos">Todos los estados operativos</option>
            <option value="activo">Activos</option>
            <option value="pendiente">Pendientes</option>
            <option value="licencia">Licencia</option>
            <option value="suspendido">Suspendidos</option>
          </select>
          <Badge tone="gray">{rows.length} registros</Badge>
        </div>
      </div>
      <section className="table-wrap payroll-wide">
        <table>
          <thead><tr><th>Código</th><th>Nombre</th><th>Cédula</th><th>Empresa</th><th>Sucursal</th><th>Departamento</th><th>Cargo</th><th>Supervisor</th><th>Estado</th><th>Acciones</th></tr></thead>
          <tbody>{visibleRows.map((employee) => <tr key={employee.id}>
            <td>{employee.code}</td>
            <td>{employee.name}</td>
            <td>{employee.cedula || 'No registrada'}</td>
            <td>{employee.companyName || 'Empresa autorizada'}</td>
            <td>{employee.branchName || 'Sin asignar'}</td>
            <td>{employee.departmentName || 'Sin asignar'}</td>
            <td>{employee.positionName || 'Sin asignar'}</td>
            <td>No disponible</td>
            <td><Badge tone={employee.active ? 'green' : employee.status === 'suspendido' ? 'amber' : 'gray'}>{employee.status}</Badge></td>
            <td><div className="button-row">
              <Link className="icon" to={`/empleados/${employee.id}`} aria-label={`Ver expediente de ${employee.name}`}><Eye /></Link>
              <Link className="secondary" to={`/empleados/${employee.id}/editar`}>Editar</Link>
              {canTerminate && <button type="button" className="secondary" onClick={() => setTerminating(employee)}><UserMinus />Dar de baja</button>}
            </div></td>
          </tr>)}</tbody>
        </table>
        {loading && <Empty text="Cargando empleados…" />}
        {!loading && !rows.length && <Empty text="No hay empleados operativos que coincidan con los filtros." />}
      </section>
      <EmployeePagination page={safePage} totalPages={totalPages} totalRows={rows.length} onPageChange={setPage} />
      {terminating && <EmployeeLifecycleDialog
        employee={terminating}
        mode="terminate"
        onCancel={() => setTerminating(null)}
        onCompleted={async (nextMessage) => {
          setTerminating(null);
          setMessage(nextMessage);
          await loadAll();
        }}
      />}
      <Toast message={message} />
    </>}
  </>;
}
