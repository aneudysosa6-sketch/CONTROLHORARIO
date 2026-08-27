import { useEffect, useMemo, useState } from 'react';
import { Eye, FileDown, History, RotateCcw, Search } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Badge, Empty, PageHeader, Toast } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { exportEmployeesPdf, exportEmployeesXlsx } from '../modules/employees/employeeExports';
import { EmployeeLifecycleDialog } from '../modules/employees/EmployeeLifecycleDialog';
import { EmployeePagination } from '../modules/employees/EmployeePagination';
import { employeeService, type EmployeeRecord } from '../modules/employees/employeeService';

const PAGE_SIZE = 20;
const displayDate = (value: string) => value
  ? new Intl.DateTimeFormat('es-DO', { dateStyle: 'medium' }).format(new Date(`${value}T00:00:00`))
  : 'No registrada';

export function TerminatedEmployeesPage() {
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<EmployeeRecord[]>([]);
  const [query, setQuery] = useState('');
  const [branch, setBranch] = useState('');
  const [department, setDepartment] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [reactivating, setReactivating] = useState<EmployeeRecord | null>(null);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      setItems(await employeeService.listTerminated());
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'No fue posible cargar los empleados dados de baja.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void load(); }, []);
  useEffect(() => { setPage(1); }, [query, branch, department, from, to]);

  const rows = useMemo(() => items.filter((employee) =>
    employee.status === 'desvinculado' &&
    (!branch || employee.branchName === branch) &&
    (!department || employee.departmentName === department) &&
    (!from || employee.terminationDate >= from) &&
    (!to || employee.terminationDate <= to) &&
    `${employee.code} ${employee.name} ${employee.cedula} ${employee.terminationReason} ${employee.terminationObservation}`
      .toLowerCase().includes(query.trim().toLowerCase()),
  ), [items, query, branch, department, from, to]);
  const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const visibleRows = rows.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);
  const branches = [...new Set(items.map((employee) => employee.branchName).filter(Boolean))];
  const departments = [...new Set(items.map((employee) => employee.departmentName).filter(Boolean))];
  const canReactivate = hasPermission('empleados.desactivar');

  return <>
    <PageHeader
      eyebrow="CAPITAL HUMANO"
      title="Empleados dados de baja"
      description="Desvinculaciones laborales vigentes. Los expedientes y su auditoría se conservan sin eliminación."
      action={<div className="button-row">
        <button type="button" className="secondary" disabled={!rows.length} onClick={() => void exportEmployeesPdf(rows, 'empleados-dados-de-baja.pdf', true)}>Exportar PDF</button>
        <button type="button" className="secondary" disabled={!rows.length} onClick={() => void exportEmployeesXlsx(rows, 'empleados-dados-de-baja.xlsx', true)}><FileDown />Exportar Excel</button>
        <button type="button" className="secondary" onClick={() => window.print()}>Imprimir</button>
      </div>}
    />
    {error && <div className="error" role="alert">{error}</div>}
    <div className="toolbar">
      <div className="search"><Search /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar empleado, motivo u observación" /></div>
      <div className="filter-row">
        <select aria-label="Filtrar bajas por sucursal" value={branch} onChange={(event) => setBranch(event.target.value)}><option value="">Todas las sucursales</option>{branches.map((value) => <option key={value}>{value}</option>)}</select>
        <select aria-label="Filtrar bajas por departamento" value={department} onChange={(event) => setDepartment(event.target.value)}><option value="">Todos los departamentos</option>{departments.map((value) => <option key={value}>{value}</option>)}</select>
        <label>Desde<input type="date" value={from} onChange={(event) => setFrom(event.target.value)} /></label>
        <label>Hasta<input type="date" value={to} onChange={(event) => setTo(event.target.value)} /></label>
        <Badge tone="gray">{rows.length} desvinculados</Badge>
      </div>
    </div>
    <section className="table-wrap payroll-wide">
      <table>
        <thead><tr><th>Código</th><th>Empleado</th><th>Cédula</th><th>Empresa</th><th>Fecha de baja</th><th>Motivo</th><th>Observación</th><th>Responsable</th><th>Sucursal</th><th>Departamento</th><th>Estado</th><th>Acciones</th></tr></thead>
        <tbody>{visibleRows.map((employee) => <tr key={employee.id}>
          <td>{employee.code}</td>
          <td><strong>{employee.name}</strong><small>{employee.positionName || 'Sin cargo registrado'}</small></td>
          <td>{employee.cedula || 'No registrada'}</td>
          <td>{employee.companyName || 'Empresa autorizada'}</td>
          <td>{displayDate(employee.terminationDate)}</td>
          <td>{employee.terminationReason || 'No registrado'}</td>
          <td>{employee.terminationObservation || 'Sin observación'}</td>
          <td>{employee.terminationActorName || 'No registrado (histórico)'}</td>
          <td>{employee.branchName || 'Sin asignar'}</td>
          <td>{employee.departmentName || 'Sin asignar'}</td>
          <td><Badge tone="gray">Desvinculado</Badge></td>
          <td><div className="button-row">
            <Link className="icon" to={`/empleados/${employee.id}`} aria-label={`Ver expediente de ${employee.name}`}><Eye /></Link>
            <Link className="secondary" to={`/empleados/${employee.id}/historial`}><History />Historial</Link>
            {canReactivate && <button type="button" className="primary" onClick={() => setReactivating(employee)}><RotateCcw />Reactivar</button>}
          </div></td>
        </tr>)}</tbody>
      </table>
      {loading ? <Empty text="Cargando empleados dados de baja…" /> : !rows.length && <Empty text="No hay desvinculaciones que coincidan con los filtros." />}
    </section>
    <EmployeePagination page={safePage} totalPages={totalPages} totalRows={rows.length} onPageChange={setPage} />
    {reactivating && <EmployeeLifecycleDialog
      employee={reactivating}
      mode="reactivate"
      onCancel={() => setReactivating(null)}
      onCompleted={async (nextMessage) => {
        setReactivating(null);
        setMessage(nextMessage);
        await load();
      }}
    />}
    <Toast message={message} />
  </>;
}
