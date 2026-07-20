import { useEffect, useMemo, useState } from 'react';
import { AlertTriangle, Clock3, Coffee, HandCoins, Users } from 'lucide-react';
import { Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { dashboardErrorMessage } from '../modules/dashboard/dashboardDiagnostics';
import { executiveDashboardService, type ExecutiveDashboardData } from '../modules/dashboard/executiveDashboardService';
import { ReportFilters, type ReportFiltersValue } from '../modules/reports/ReportFilters';

const initialFilters: ReportFiltersValue = { company: '', branch: '', department: '', supervisor: '', employee: '', from: '', to: '' };
const money = (value?: number) => value == null ? 'No disponible' : new Intl.NumberFormat('es-DO', { style: 'currency', currency: 'DOP' }).format(value);
const hours = (value: number) => `${Math.round(value * 100) / 100} h`;
const typeCount = (items: ExecutiveDashboardData['journeys'], type: string) => items.filter((journey) => journey.incidents.some((incident) => incident.type === type)).length;

function Bars({ title, values }: { title: string; values: Array<{ label: string; value: number }> }) {
  const maximum = Math.max(1, ...values.map((item) => item.value));
  return <section className="panel"><h2>{title}</h2>{values.length ? <div style={{ display: 'grid', gap: 10 }}>{values.map((item) => <div key={item.label} style={{ display: 'grid', gridTemplateColumns: 'minmax(90px, 1fr) 3fr 42px', alignItems: 'center', gap: 10, fontSize: 12 }}><span>{item.label}</span><div style={{ height: 9, background: '#172a44', borderRadius: 999, overflow: 'hidden' }}><i style={{ display: 'block', height: '100%', width: `${(item.value / maximum) * 100}%`, background: 'linear-gradient(90deg,#0872ff,#37b8ff)', borderRadius: 'inherit' }} /></div><b style={{ textAlign: 'right' }}>{item.value}</b></div>)}</div> : <Empty text="No hay datos registrados para este gráfico." />}</section>;
}

export function ExecutiveDashboardPage() {
  const { session } = useAuth();
  const [data, setData] = useState<ExecutiveDashboardData | null>(null);
  const [filters, setFilters] = useState<ReportFiltersValue>(initialFilters);
  const [date, setDate] = useState('');
  const [error, setError] = useState('');
  const [payrollLoading, setPayrollLoading] = useState(false);
  const [payrollError, setPayrollError] = useState('');

  useEffect(() => {
    if (!session) return;
    executiveDashboardService.load(session).then((value) => { setData(value); setDate(value.snapshot.workDate); }).catch((reason) => setError(dashboardErrorMessage(reason)));
  }, [session]);

  useEffect(() => {
    if (!data || !date) return;
    if (data.payrollDashboard.as_of_date === date) {
      setPayrollLoading(false);
      setPayrollError('');
      return;
    }
    let active = true;
    setPayrollLoading(true);
    setPayrollError('');
    executiveDashboardService.loadPayrollDashboard(date)
      .then((payrollDashboard) => { if (active) { setData((current) => current ? { ...current, payrollDashboard } : current); setPayrollLoading(false); } })
      .catch((reason) => { if (active) { setPayrollError(dashboardErrorMessage(reason)); setPayrollLoading(false); } });
    return () => { active = false; };
  }, [data, date]);

  const visibleJourneys = useMemo(() => (data?.journeys ?? []).filter((journey) => (!date || journey.workDate === date) && (!filters.branch || journey.branch === filters.branch) && (!filters.department || journey.department === filters.department) && (!filters.employee || `${journey.code} ${journey.employee}`.toLowerCase().includes(filters.employee.toLowerCase()))), [data, date, filters]);
  const visibleEmployees = useMemo(() => (data?.employees ?? []).filter((employee) => (!filters.branch || employee.branchName === filters.branch) && (!filters.department || employee.departmentName === filters.department) && (!filters.employee || `${employee.code} ${employee.name}`.toLowerCase().includes(filters.employee.toLowerCase()))), [data, filters]);
  const today = visibleJourneys.filter((journey) => journey.workDate === date);
  const payroll = data?.payroll.snapshot;
  const payrollDashboard = data?.payrollDashboard.as_of_date === date ? data.payrollDashboard : undefined;
  const payrollBlockers = payrollDashboard?.blockers.map((blocker) => `${blocker.employee_code} · ${blocker.employee_name}: ${blocker.message}`).join(' | ') ?? '';
  const payrollDiagnostic = payrollError || payrollBlockers || payrollDashboard?.reason || '';
  const payrollValue = payrollLoading ? 'Calculando…' : payrollError ? 'Error de cálculo' : payrollDashboard?.total != null ? money(payrollDashboard.total) : 'Cálculo bloqueado';
  const activeLoans = payroll?.prestamos.filter((loan) => loan.pendiente > 0) ?? [];
  const dueLoans = activeLoans.filter((loan) => loan.fecha_final).sort((a, b) => (a.fecha_final ?? '').localeCompare(b.fecha_final ?? '')).slice(0, 6);
  const overtimeHours = payroll?.detalles.reduce((total, detail) => total + detail.horas_extras, 0) ?? 0;
  const dayJourneys = Object.entries(visibleJourneys.reduce<Record<string, number>>((result, journey) => ({ ...result, [journey.workDate]: (result[journey.workDate] ?? 0) + 1 }), {})).sort(([a], [b]) => a.localeCompare(b)).slice(-7).map(([label, value]) => ({ label, value }));
  const weeklyAttendance = Object.entries(visibleJourneys.filter((journey) => journey.status === 'FINALIZADA').reduce<Record<string, number>>((result, journey) => ({ ...result, [journey.workDate]: (result[journey.workDate] ?? 0) + 1 }), {})).sort(([a], [b]) => a.localeCompare(b)).slice(-7).map(([label, value]) => ({ label, value }));
  const overtimeByDepartment = Object.entries(visibleJourneys.reduce<Record<string, number>>((result, journey) => ({ ...result, [journey.department || 'Sin departamento']: (result[journey.department || 'Sin departamento'] ?? 0) + (journey.workedMinutes > 480 ? 1 : 0) }), {})).map(([label, value]) => ({ label, value })).filter((item) => item.value > 0);
  const incidentsByType = Object.entries(visibleJourneys.flatMap((journey) => journey.incidents).reduce<Record<string, number>>((result, incident) => ({ ...result, [incident.type]: (result[incident.type] ?? 0) + 1 }), {})).map(([label, value]) => ({ label, value }));
  const employeeStates = Object.entries(visibleEmployees.reduce<Record<string, number>>((result, employee) => ({ ...result, [employee.status]: (result[employee.status] ?? 0) + 1 }), {})).map(([label, value]) => ({ label, value }));

  return <>
    <PageHeader eyebrow="DASHBOARD EJECUTIVO" title="Panel principal" description="Indicadores consolidados disponibles para la empresa autenticada." />
    <ReportFilters value={filters} onChange={setFilters} />
    <section className="panel payroll-periods"><label>Fecha<input type="date" value={date} onChange={(event) => setDate(event.target.value)} /></label></section>
    {error && <div className="error">{error}</div>}
    {!data && !error && <Empty text="Cargando Dashboard ejecutivo…" />}
    {data && <>
      <section className="stats payroll-stats">{[
        ['Empleados activos', visibleEmployees.filter((employee) => employee.active).length], ['Empleados inactivos', visibleEmployees.filter((employee) => !employee.active).length], ['Jornadas iniciadas hoy', today.length], ['Jornadas en pausa', today.filter((journey) => journey.status === 'EN_PAUSA').length], ['Jornadas finalizadas', today.filter((journey) => journey.status === 'FINALIZADA').length], ['Jornadas incompletas', typeCount(today, 'JORNADA_INCOMPLETA')], ['Tardanzas de hoy', typeCount(today, 'TARDANZA')], ['Ausencias de hoy', typeCount(today, 'AUSENCIA')], ['Permisos activos', visibleEmployees.filter((employee) => employee.status === 'licencia').length], ['Horas extras del período', hours(overtimeHours)], ['Total nómina del período', payrollValue], ['Préstamos pendientes', money(activeLoans.reduce((total, loan) => total + loan.pendiente, 0))],
      ].map(([label, value]) => <article className="stat" key={String(label)} title={label === 'Total nómina del período' ? payrollDiagnostic : undefined}><span>{label}</span><strong>{value}</strong>{label === 'Total nómina del período' && payrollDiagnostic && <small>{payrollDiagnostic}</small>}</article>)}</section>
      <section className="dashboard-grid"><Bars title="Jornadas por día" values={dayJourneys} /><Bars title="Asistencia semanal" values={weeklyAttendance} /><Bars title="Horas extras por departamento" values={overtimeByDepartment} /><Bars title="Incidencias por tipo" values={incidentsByType} /><Bars title="Estado de empleados" values={employeeStates} /></section>
      <section className="dashboard-grid"><section className="panel"><h2>Últimos eventos</h2>{data.snapshot.recent.length ? data.snapshot.recent.map((event) => <article className="employee-cell" key={event.id}><Clock3 /><div><b>{event.code} · {event.employee}</b><p>{event.status} · {event.updatedAt}</p></div></article>) : <Empty text="No hay eventos recientes." />}</section><section className="panel"><h2>Alertas críticas</h2>{data.snapshot.incidents.filter((incident) => ['ALTA', 'CRITICA'].includes(incident.severity)).length ? data.snapshot.incidents.filter((incident) => ['ALTA', 'CRITICA'].includes(incident.severity)).map((incident) => <article className="new-event panel" key={incident.id}><AlertTriangle /><div><b>{incident.type} · {incident.employee}</b><p>{incident.message}</p></div></article>) : <Empty text="No hay alertas críticas." />}</section><section className="panel"><h2>Próximos vencimientos de préstamos</h2>{dueLoans.length ? dueLoans.map((loan) => <article className="employee-cell" key={loan.id}><HandCoins /><div><b>{money(loan.pendiente)}</b><p>Vence: {loan.fecha_final}</p></div></article>) : <Empty text="No hay préstamos con fecha de vencimiento registrada." />}</section><section className="panel"><h2>Últimas jornadas registradas</h2>{data.snapshot.recent.length ? data.snapshot.recent.map((journey) => <article className="employee-cell" key={`journey-${journey.id}`}><Users /><div><b>{journey.employee}</b><p>{journey.status} · {journey.workedMinutes} min</p></div></article>) : <Empty text="No hay jornadas registradas." />}</section></section>
    </>}
  </>;
}
