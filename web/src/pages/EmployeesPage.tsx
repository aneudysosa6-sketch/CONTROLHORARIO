import { useEffect, useMemo, useState } from 'react';
import { Eye, FileDown, Plus, Search, UserMinus } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Badge, Empty, PageHeader, Toast } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { exportEmployeesPdf, exportEmployeesXlsx } from '../modules/employees/employeeExports';
import { EmployeeLifecycleDialog } from '../modules/employees/EmployeeLifecycleDialog';
import { EmployeePagination } from '../modules/employees/EmployeePagination';
import { employeeService, type EmployeeRecord, type EmployeeStatus } from '../modules/employees/employeeService';

const PAGE_SIZE = 20;

export function EmployeesPage() {
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<EmployeeRecord[]>([]);
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<EmployeeStatus | 'todos'>('todos');
  const [branch, setBranch] = useState('');
  const [department, setDepartment] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [terminating, setTerminating] = useState<EmployeeRecord | null>(null);

  const load = async () => {
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

  useEffect(() => { void load(); }, []);
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

  return <>
    <PageHeader
      eyebrow="CAPITAL HUMANO"
      title="Empleados"
      description="Personal operativo. Los expedientes desvinculados se conservan en Empleados dados de baja."
      action={<div className="button-row">
        <button type="button" className="secondary" disabled={!rows.length} onClick={() => void exportEmployeesPdf(rows, 'empleados-operativos.pdf')}>Exportar PDF</button>
        <button type="button" className="secondary" disabled={!rows.length} onClick={() => void exportEmployeesXlsx(rows, 'empleados-operativos.xlsx')}><FileDown />Exportar Excel</button>
        <button type="button" className="secondary" onClick={() => window.print()}>Imprimir</button>
        <Link className="primary" to="/empleados/nuevo"><Plus />Nuevo empleado</Link>
      </div>}
    />
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
      {loading ? <Empty text="Cargando empleados…" /> : !rows.length && <Empty text="No hay empleados operativos que coincidan con los filtros." />}
    </section>
    <EmployeePagination page={safePage} totalPages={totalPages} totalRows={rows.length} onPageChange={setPage} />
    {terminating && <EmployeeLifecycleDialog
      employee={terminating}
      mode="terminate"
      onCancel={() => setTerminating(null)}
      onCompleted={async (nextMessage) => {
        setTerminating(null);
        setMessage(nextMessage);
        await load();
      }}
    />}
    <Toast message={message} />
  </>;
}
