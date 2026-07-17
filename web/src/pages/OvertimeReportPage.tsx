import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Empty, PageHeader } from '../components/UI';
import { ReportFilters, type ReportFiltersValue } from '../modules/reports/ReportFilters';
import { journeyService, type Journey } from '../modules/journeys/journeyService';

const hours = (minutes: number) => Math.round((minutes / 60) * 100) / 100;

export function OvertimeReportPage() {
  const [rows, setRows] = useState<Journey[]>([]);
  const [filters, setFilters] = useState<ReportFiltersValue>({ company: '', branch: '', department: '', supervisor: '', employee: '', from: '', to: '' });
  const [onlyWithOvertime, setOnlyWithOvertime] = useState(true);
  const [journeyState, setJourneyState] = useState('');
  const [minimumAmount, setMinimumAmount] = useState('');
  const [maximumAmount, setMaximumAmount] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    journeyService.list().then(setRows).catch((reason) => setError(reason instanceof Error ? reason.message : 'No fue posible cargar las horas extras.'));
  }, []);

  const data = useMemo(() => rows.filter((journey) => {
    const overtimeMinutes = Math.max(0, journey.workedMinutes - 480);
    const hasAmountRange = minimumAmount !== '' || maximumAmount !== '';

    // Journey does not expose a persisted overtime amount. A monetary filter must
    // therefore not infer one from hours; it produces no matching unverified rows.
    return (!onlyWithOvertime || overtimeMinutes > 0)
      && (!journeyState || journey.status === journeyState)
      && (!filters.branch || journey.branch === filters.branch)
      && (!filters.department || journey.department === filters.department)
      && (!filters.employee || `${journey.code} ${journey.employee}`.toLowerCase().includes(filters.employee.toLowerCase()))
      && (!filters.from || journey.workDate >= filters.from)
      && (!filters.to || journey.workDate <= filters.to)
      && !hasAmountRange;
  }), [rows, filters, onlyWithOvertime, journeyState, minimumAmount, maximumAmount]);

  const overtimeMinutes = data.reduce((total, journey) => total + Math.max(0, journey.workedMinutes - 480), 0);
  const employeesWithOvertime = new Set(data.filter((journey) => journey.workedMinutes > 480).map((journey) => journey.employeeId));

  return <>
    <PageHeader eyebrow="REPORTES" title="Reporte de Horas Extras" description="Información registrada de jornadas, solo lectura." action={<div className="button-row"><Link className="secondary" to="/reportes">Volver</Link><button className="secondary">Exportar PDF</button><button className="secondary">Exportar Excel</button><button className="secondary" onClick={() => window.print()}>Imprimir</button></div>} />
    <ReportFilters value={filters} onChange={setFilters} />
    <section className="panel payroll-periods">
      <label><input type="checkbox" checked={onlyWithOvertime} onChange={(event) => setOnlyWithOvertime(event.target.checked)} /> Solo empleados con horas extras</label>
      <label>Estado de jornada<select value={journeyState} onChange={(event) => setJourneyState(event.target.value)}><option value="">Todos</option>{['SIN_INICIAR', 'EN_CURSO', 'EN_PAUSA', 'FINALIZADA'].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Monto mínimo<input type="number" min="0" value={minimumAmount} onChange={(event) => setMinimumAmount(event.target.value)} /></label>
      <label>Monto máximo<input type="number" min="0" value={maximumAmount} onChange={(event) => setMaximumAmount(event.target.value)} /></label>
    </section>
    <section className="stats payroll-stats">
      {[
        ['Empleados con horas extras', employeesWithOvertime.size],
        ['Total horas extras', `${hours(overtimeMinutes)} h`],
        ['Total pagado por horas extras', 'No disponible'],
        ['Promedio por empleado', employeesWithOvertime.size ? `${hours(overtimeMinutes / employeesWithOvertime.size)} h` : '0 h'],
      ].map(([label, value]) => <article className="stat" key={label}><span>{label}</span><strong>{value}</strong></article>)}
    </section>
    {error && <div className="error">{error}</div>}
    {!data.length ? <Empty text="No hay horas extras para estos filtros." /> : <section className="table-wrap payroll-wide"><table><thead><tr><th>Fecha</th><th>Código</th><th>Empleado</th><th>Sucursal</th><th>Departamento</th><th>Horas normales</th><th>Horas extras</th><th>Monto horas extras</th><th>Estado de jornada</th><th>Observaciones</th></tr></thead><tbody>{data.map((journey) => {
      const extra = Math.max(0, journey.workedMinutes - 480);
      return <tr key={journey.id}><td>{journey.workDate}</td><td>{journey.code}</td><td>{journey.employee}</td><td>{journey.branch}</td><td>{journey.department}</td><td>{hours(Math.min(journey.workedMinutes, 480))}</td><td>{hours(extra)}</td><td>No disponible</td><td>{journey.status}</td><td>{journey.incidents.map((incident) => incident.message).join(' · ') || '—'}</td></tr>;
    })}</tbody></table></section>}
  </>;
}
