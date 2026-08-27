import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  BriefcaseBusiness,
  CalendarDays,
  CheckCircle2,
  Clock3,
  Coffee,
  HandCoins,
  RefreshCw,
  TimerReset,
  Users,
  WalletCards,
} from 'lucide-react';
import { Empty } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import {
  BarChart,
  DashboardFilters,
  DashboardSkeleton,
  DonutGauge,
  FinancialCard,
  KpiCard,
  LineChart,
  type ChartPoint,
  type DashboardFilterOption,
} from '../modules/dashboard/DashboardVisuals';
import { dashboardErrorMessage } from '../modules/dashboard/dashboardDiagnostics';
import { executiveDashboardService, type ExecutiveDashboardData } from '../modules/dashboard/executiveDashboardService';
import type { ReportFiltersValue } from '../modules/reports/ReportFilters';

const initialFilters: ReportFiltersValue = { company: 'current', branch: '', department: '', supervisor: '', employee: '', from: '', to: '' };
const currencyFormatter = new Intl.NumberFormat('es-DO', { style: 'currency', currency: 'DOP', maximumFractionDigits: 2 });
const money = (value: number) => currencyFormatter.format(value);
const typeCount = (items: ExecutiveDashboardData['journeys'], type: string) => items.filter((journey) => journey.incidents.some((incident) => incident.type === type)).length;
const uniqueOptions = (values: string[]): DashboardFilterOption[] => [...new Set(values.filter(Boolean))].sort((a, b) => a.localeCompare(b, 'es')).map((value) => ({ value, label: value }));

function offsetDate(value: string, offset: number) {
  const [year, month, day] = value.split('-').map(Number);
  if (!year || !month || !day) return '';
  return new Date(Date.UTC(year, month - 1, day + offset)).toISOString().slice(0, 10);
}

function displayDate(value: string) {
  const [year, month, day] = value.split('-').map(Number);
  if (!year || !month || !day) return 'Fecha no disponible';
  return new Intl.DateTimeFormat('es-DO', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(year, month - 1, day, 12));
}

function compactDate(value: string) {
  const [, month, day] = value.split('-');
  return `${day}/${month}`;
}

function seriesByDate(journeys: ExecutiveDashboardData['journeys'], endDate: string, predicate: (journey: ExecutiveDashboardData['journeys'][number]) => boolean): ChartPoint[] {
  const dates = Array.from({ length: 7 }, (_, index) => offsetDate(endDate, index - 6)).filter(Boolean);
  return dates.map((workDate) => ({ label: compactDate(workDate), value: journeys.filter((journey) => journey.workDate === workDate && predicate(journey)).length }));
}

export function ExecutiveDashboardPage() {
  const { session } = useAuth();
  const [data, setData] = useState<ExecutiveDashboardData | null>(null);
  const [filters, setFilters] = useState<ReportFiltersValue>(initialFilters);
  const [draftFilters, setDraftFilters] = useState<ReportFiltersValue>(initialFilters);
  const [date, setDate] = useState('');
  const [error, setError] = useState('');
  const [syncError, setSyncError] = useState('');
  const [syncing, setSyncing] = useState(false);
  const [payrollLoading, setPayrollLoading] = useState(false);
  const [payrollError, setPayrollError] = useState('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const dateRef = useRef('');
  const dataRef = useRef<ExecutiveDashboardData | null>(null);
  const requestInFlight = useRef(false);
  const dashboardRequestId = useRef(0);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  const loadDashboard = useCallback(async () => {
    if (!session || requestInFlight.current) return;
    const requestId = ++dashboardRequestId.current;
    requestInFlight.current = true;
    setSyncing(true);
    try {
      let value = await executiveDashboardService.load(session);
      const selectedDate = dateRef.current || value.snapshot.workDate;
      if (selectedDate !== value.payrollDashboard.as_of_date) {
        const payrollDashboard = await executiveDashboardService.loadPayrollDashboard(selectedDate);
        value = { ...value, payrollDashboard };
      }
      if (!mounted.current || requestId !== dashboardRequestId.current) return;
      if (!dateRef.current) {
        dateRef.current = value.snapshot.workDate;
        setDate(value.snapshot.workDate);
      }
      setData(value);
      dataRef.current = value;
      setError('');
      setSyncError('');
      setLastUpdated(new Date());
    } catch (reason) {
      if (!mounted.current || requestId !== dashboardRequestId.current) return;
      const message = dashboardErrorMessage(reason);
      if (dataRef.current) setSyncError(message);
      else setError(message);
    } finally {
      if (requestId === dashboardRequestId.current) {
        requestInFlight.current = false;
        if (mounted.current) setSyncing(false);
      }
    }
  }, [session]);

  useEffect(() => {
    dashboardRequestId.current += 1;
    requestInFlight.current = false;
    dateRef.current = '';
    dataRef.current = null;
    setData(null);
    setDate('');
    setError('');
    setSyncError('');
    setSyncing(false);
    setPayrollLoading(false);
    setPayrollError('');
    setLastUpdated(null);
  }, [session?.companyId, session?.id]);

  useEffect(() => { void loadDashboard(); }, [loadDashboard]);
  useEffect(() => {
    if (!session) return;
    const interval = window.setInterval(() => { void loadDashboard(); }, 12_000);
    return () => window.clearInterval(interval);
  }, [loadDashboard, session]);

  useEffect(() => {
    dateRef.current = date;
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
      .then((payrollDashboard) => {
        if (!active) return;
        setData((current) => {
          const next = current ? { ...current, payrollDashboard } : current;
          dataRef.current = next;
          return next;
        });
        setPayrollLoading(false);
        setLastUpdated(new Date());
      })
      .catch((reason) => {
        if (!active) return;
        setPayrollError(dashboardErrorMessage(reason));
        setPayrollLoading(false);
      });
    return () => { active = false; };
  }, [data, date]);

  const branchOptions = useMemo(() => uniqueOptions((data?.employees ?? []).map((employee) => employee.branchName)), [data?.employees]);
  const departmentOptions = useMemo(() => uniqueOptions((data?.employees ?? []).filter((employee) => !draftFilters.branch || employee.branchName === draftFilters.branch).map((employee) => employee.departmentName)), [data?.employees, draftFilters.branch]);
  const employeeOptions = useMemo(() => (data?.employees ?? [])
    .filter((employee) => (!draftFilters.branch || employee.branchName === draftFilters.branch) && (!draftFilters.department || employee.departmentName === draftFilters.department))
    .map((employee) => ({ value: `${employee.code} ${employee.name}`, label: `${employee.code} · ${employee.name}` })), [data?.employees, draftFilters.branch, draftFilters.department]);

  const scopedJourneys = useMemo(() => (data?.journeys ?? []).filter((journey) =>
    (!filters.branch || journey.branch === filters.branch)
    && (!filters.department || journey.department === filters.department)
    && (!filters.employee || journey.employeeId === filters.employee || `${journey.code} ${journey.employee}`.toLowerCase().includes(filters.employee.toLowerCase()))
    && (!filters.from || journey.workDate >= filters.from)
    && (!filters.to || journey.workDate <= filters.to)
  ), [data?.journeys, filters]);

  const visibleEmployees = useMemo(() => (data?.employees ?? []).filter((employee) =>
    (!filters.branch || employee.branchName === filters.branch)
    && (!filters.department || employee.departmentName === filters.department)
    && (!filters.employee || employee.id === filters.employee || `${employee.code} ${employee.name}`.toLowerCase().includes(filters.employee.toLowerCase()))
  ), [data?.employees, filters]);

  const selectedJourneys = useMemo(() => scopedJourneys.filter((journey) => journey.workDate === date), [date, scopedJourneys]);
  const previousDate = offsetDate(date, -1);
  const previousPeriodIncluded = Boolean(previousDate) && (!filters.from || previousDate >= filters.from) && (!filters.to || previousDate <= filters.to);
  const previousJourneys = useMemo(() => scopedJourneys.filter((journey) => journey.workDate === previousDate), [previousDate, scopedJourneys]);
  const payrollDashboard = data?.payrollDashboard.as_of_date === date ? data.payrollDashboard : undefined;
  const payrollSnapshot = data?.payroll.snapshot;
  const activeLoans = useMemo(() => payrollSnapshot?.prestamos.filter((loan) => loan.pendiente > 0) ?? [], [payrollSnapshot?.prestamos]);
  const dueLoans = useMemo(() => activeLoans.filter((loan) => loan.fecha_final).sort((left, right) => (left.fecha_final ?? '').localeCompare(right.fecha_final ?? '')).slice(0, 5), [activeLoans]);
  const payrollBlockers = payrollDashboard?.blockers.map((blocker) => `${blocker.employee_code} · ${blocker.employee_name}: ${blocker.message}`).join(' | ') ?? '';
  const payrollDiagnostic = payrollError || payrollBlockers || payrollDashboard?.reason || '';
  const payrollState = payrollLoading ? 'loading' : payrollError ? 'error' : payrollDashboard?.source === 'UNAVAILABLE' || payrollDashboard?.total == null ? 'blocked' : 'success';
  const overtimeState = payrollState === 'success' ? 'success' : payrollState;
  const overtimeHours = payrollDashboard?.employees.reduce((total, employee) => total + employee.overtime_hours, 0) ?? 0;
  const pendingLoans = activeLoans.reduce((total, loan) => total + loan.pendiente, 0);

  const initiatedSeries = useMemo(() => seriesByDate(scopedJourneys, date, () => true), [date, scopedJourneys]);
  const pausedSeries = useMemo(() => seriesByDate(scopedJourneys, date, (journey) => journey.status === 'EN_PAUSA'), [date, scopedJourneys]);
  const finishedSeries = useMemo(() => seriesByDate(scopedJourneys, date, (journey) => journey.status === 'FINALIZADA'), [date, scopedJourneys]);
  const tardySeries = useMemo(() => seriesByDate(scopedJourneys, date, (journey) => journey.incidents.some((incident) => incident.type === 'TARDANZA')), [date, scopedJourneys]);
  const payrollTimelinePoints = useMemo(() => payrollDashboard?.total != null ? [{ label: payrollDashboard.period_end, value: payrollDashboard.total }] : [], [payrollDashboard]);
  const overtimePoints = useMemo(() => (payrollDashboard?.employees ?? []).map((employee) => ({ label: employee.employee_code, value: employee.overtime_hours })).slice(0, 10), [payrollDashboard?.employees]);
  const loanPoints = useMemo(() => activeLoans.map((loan, index) => ({ label: `Préstamo ${index + 1}`, value: loan.pendiente })).slice(0, 8), [activeLoans]);
  const recentJourneys = useMemo(() => data?.snapshot.recent.slice(0, 6) ?? [], [data?.snapshot.recent]);
  const criticalIncidents = useMemo(() => data?.snapshot.incidents.filter((incident) => ['ALTA', 'CRITICA'].includes(incident.severity)).slice(0, 6) ?? [], [data?.snapshot.incidents]);
  const syncIssue = syncError || payrollError;
  const syncState = syncIssue ? 'Con incidencias' : syncing || payrollLoading ? 'Actualizando' : 'Sincronizado';

  const applyFilters = () => setFilters(draftFilters);
  const clearFilters = () => { setDraftFilters(initialFilters); setFilters(initialFilters); };
  const selectToday = () => {
    const today = data?.snapshot.workDate ?? '';
    dateRef.current = today;
    setDate(today);
  };

  if (!data && !error) return <div className="executive-dashboard"><DashboardSkeleton /></div>;
  if (!data && error) return <section className="executive-dashboard exec-load-error" role="alert"><AlertTriangle /><h1>No fue posible cargar el Dashboard Ejecutivo</h1><p>{error}</p><button type="button" className="primary" onClick={() => void loadDashboard()}><RefreshCw />Reintentar</button></section>;
  if (!data) return null;

  const activeEmployees = visibleEmployees.filter((employee) => employee.active).length;
  const initiated = selectedJourneys.length;
  const paused = selectedJourneys.filter((journey) => journey.status === 'EN_PAUSA').length;
  const finished = selectedJourneys.filter((journey) => journey.status === 'FINALIZADA').length;
  const tardy = typeCount(selectedJourneys, 'TARDANZA');

  return <div className="executive-dashboard">
    <header className="exec-hero">
      <div className="exec-hero-copy"><span>CONTROL OPERATIVO</span><h1>Dashboard Ejecutivo</h1><p>Indicadores consolidados disponibles para la empresa autenticada.</p></div>
      <div className="exec-hero-date"><CalendarDays /><div><span>Fecha de análisis</span><strong>{displayDate(date)}</strong></div></div>
      <div className="exec-hero-actions">
        <label className="exec-date-picker"><span className="sr-only">Seleccionar fecha</span><input type="date" aria-label="Fecha del Dashboard" value={date} onChange={(event) => setDate(event.target.value)} /></label>
        <button type="button" className="secondary" onClick={selectToday}>Hoy</button>
        <button type="button" className="primary" aria-label="Actualizar Dashboard" disabled={syncing} onClick={() => void loadDashboard()}><RefreshCw className={syncing ? 'spin' : ''} />Actualizar</button>
      </div>
      <div className="exec-sync-row" aria-live="polite"><span className={`exec-sync-dot${syncIssue ? ' warning' : ''}`} /><b>{syncState}</b><span>Última actualización: {lastUpdated ? new Intl.DateTimeFormat('es-DO', { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(lastUpdated) : 'pendiente'}</span>{syncIssue && <span className="exec-sync-error">{syncIssue}</span>}</div>
    </header>

    <DashboardFilters value={draftFilters} onChange={setDraftFilters} onApply={applyFilters} onClear={clearFilters} branches={branchOptions} departments={departmentOptions} employees={employeeOptions} />

    <section className="exec-section-heading"><div><span>RESUMEN DEL DÍA</span><h2>Indicadores principales</h2></div><small>Los valores responden a la fecha y filtros aplicados.</small></section>
    <section className="exec-kpi-grid">
      <KpiCard label="Empleados activos" value={activeEmployees} icon={Users} points={[]} tone="blue" helper={`${visibleEmployees.length} empleados visibles`} />
      <KpiCard label="Jornadas iniciadas" value={initiated} previous={previousPeriodIncluded ? previousJourneys.length : undefined} icon={Activity} points={initiatedSeries} tone="violet" helper="Todos los estados iniciados" />
      <KpiCard label="Jornadas en pausa" value={paused} previous={previousPeriodIncluded ? previousJourneys.filter((journey) => journey.status === 'EN_PAUSA').length : undefined} icon={Coffee} points={pausedSeries} tone="cyan" helper="Estado EN_PAUSA" increaseIsPositive={false} />
      <KpiCard label="Jornadas finalizadas" value={finished} previous={previousPeriodIncluded ? previousJourneys.filter((journey) => journey.status === 'FINALIZADA').length : undefined} icon={CheckCircle2} points={finishedSeries} tone="blue" helper="Estado FINALIZADA" />
      <KpiCard label="Tardanzas" value={tardy} previous={previousPeriodIncluded ? typeCount(previousJourneys, 'TARDANZA') : undefined} icon={TimerReset} points={tardySeries} tone="amber" helper="Incidencias TARDANZA" increaseIsPositive={false} />
    </section>

    <section className="exec-section-heading"><div><span>VISIÓN FINANCIERA</span><h2>Indicadores del período</h2></div><small>Sin recálculos en la interfaz: datos entregados por los servicios existentes.</small></section>
    <section className="exec-financial-grid">
      <FinancialCard label="Horas extras del período" value={overtimeState === 'success' ? overtimeHours : null} icon={Clock3} state={overtimeState} points={overtimePoints} format={(value) => `${value.toLocaleString('es-DO', { maximumFractionDigits: 2 })} h`} tone="cyan" />
      <FinancialCard label="Total nómina del período" value={payrollDashboard?.total ?? null} icon={WalletCards} state={payrollState} points={payrollTimelinePoints} format={money} message={payrollDiagnostic || (payrollDashboard ? `${payrollDashboard.period_start} — ${payrollDashboard.period_end}` : undefined)} tone="violet" />
      <FinancialCard label="Préstamos pendientes" value={payrollSnapshot ? pendingLoans : null} icon={HandCoins} state={payrollSnapshot ? 'success' : 'blocked'} points={loanPoints} format={money} tone="blue" />
    </section>

    <section className="exec-section-heading"><div><span>DISTRIBUCIÓN OPERATIVA</span><h2>Medidores del día</h2></div><small>Porcentajes derivados exclusivamente de los totales visibles.</small></section>
    <section className="exec-gauge-grid">
      <DonutGauge label="Empleados activos" value={activeEmployees} total={visibleEmployees.length} icon={Users} />
      <DonutGauge label="Jornadas iniciadas" value={initiated} total={activeEmployees} icon={Activity} />
      <DonutGauge label="En pausa" value={paused} total={initiated} icon={Coffee} />
      <DonutGauge label="Finalizadas" value={finished} total={initiated} icon={CheckCircle2} />
      <DonutGauge label="Tardanzas" value={tardy} total={initiated} icon={TimerReset} />
    </section>

    <section className="exec-charts-grid">
      <LineChart title="Nómina del período" subtitle="La línea temporal aparecerá cuando existan al menos dos cortes históricos reales." points={payrollTimelinePoints} formatValue={money} />
      <BarChart title="Horas extras" subtitle="Horas reales por empleado del período consultado." points={overtimePoints} unit=" h" />
    </section>

    <section className="exec-operations-grid">
      <section className="exec-list-card"><header><div><Activity /><span><b>Actividad reciente</b><small>Jornadas registradas</small></span></div><span>{recentJourneys.length}</span></header>{recentJourneys.length ? <div className="exec-list">{recentJourneys.map((journey) => <article key={journey.id}><span className="exec-list-icon"><BriefcaseBusiness /></span><div><b>{journey.code} · {journey.employee}</b><p>{journey.status} · {journey.workedMinutes} min trabajados</p></div><time dateTime={journey.updatedAt}>{journey.updatedAt.slice(0, 10)}</time></article>)}</div> : <Empty text="No hay jornadas registradas hoy." />}</section>
      <section className="exec-list-card"><header><div><AlertTriangle /><span><b>Alertas críticas</b><small>Incidencias que requieren atención</small></span></div><span>{criticalIncidents.length}</span></header>{criticalIncidents.length ? <div className="exec-list">{criticalIncidents.map((incident) => <article key={incident.id}><span className="exec-list-icon warning"><AlertTriangle /></span><div><b>{incident.type} · {incident.employee}</b><p>{incident.message}</p></div><span className="exec-list-meta">{incident.severity}</span></article>)}</div> : <Empty text="No hay alertas críticas en este alcance." />}</section>
      <section className="exec-list-card"><header><div><HandCoins /><span><b>Próximos préstamos</b><small>Vencimientos registrados</small></span></div><span>{dueLoans.length}</span></header>{dueLoans.length ? <div className="exec-list">{dueLoans.map((loan) => <article key={loan.id}><span className="exec-list-icon"><HandCoins /></span><div><b>{money(loan.pendiente)}</b><p>{loan.motivo}</p></div><time>{loan.fecha_final}</time></article>)}</div> : <Empty text="No hay préstamos con vencimiento registrado." />}</section>
    </section>
  </div>;
}
