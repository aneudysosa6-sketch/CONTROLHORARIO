import { useEffect, useMemo, useState } from 'react';
import { Ban, CalendarDays, Calculator, Printer, RefreshCw, Save, ShieldAlert } from 'lucide-react';
import { Badge, Empty, PageHeader } from '../components/UI';
import {
  p0Service,
  type BlacklistEntry,
  type DirectLicense,
  type IncompleteJourney,
  type P0Employee,
  type PriorAdjustment,
} from '../modules/p0/p0Service';

const errorText = (error: unknown) => error instanceof Error ? error.message : 'No fue posible completar la operación.';
const today = () => new Date().toISOString().slice(0, 10);
const monthNow = () => new Date().toISOString().slice(0, 7);
const money = (value: number | undefined) => new Intl.NumberFormat('es-DO', { style: 'currency', currency: 'DOP' }).format(value ?? 0);

export function LicensesPage() {
  const [employees, setEmployees] = useState<P0Employee[]>([]);
  const [items, setItems] = useState<DirectLicense[]>([]);
  const [employeeId, setEmployeeId] = useState('');
  const [start, setStart] = useState(today());
  const [end, setEnd] = useState(today());
  const [percentage, setPercentage] = useState(100);
  const [reason, setReason] = useState('');
  const [editing, setEditing] = useState<DirectLicense | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const load = async () => {
    const [employeeRows, licenses] = await Promise.all([p0Service.employees(), p0Service.licenses()]);
    setEmployees(employeeRows);
    setItems(licenses);
    if (!employeeId && employeeRows[0]) setEmployeeId(employeeRows[0].id);
  };
  useEffect(() => { void load().catch((e) => setError(errorText(e))); }, []);

  const reset = () => {
    setEditing(null);
    setStart(today());
    setEnd(today());
    setPercentage(100);
    setReason('');
  };
  const save = async () => {
    setError('');
    if (!employeeId || !reason.trim() || end < start || percentage < 0 || percentage > 100) {
      setError('Completa empleado, rango, porcentaje de 1 a 100 y motivo.');
      return;
    }
    if (editing && start < editing.fecha_inicio) {
      setError('La edición solo puede aplicarse desde el inicio original hacia adelante.');
      return;
    }
    setBusy(true);
    try {
      if (editing) await p0Service.editLicense(editing.id, { start, end, percentage, reason });
      else await p0Service.createLicense({ employeeId, start, end, percentage, reason });
      reset();
      await load();
    } catch (e) { setError(errorText(e)); } finally { setBusy(false); }
  };
  const edit = (item: DirectLicense) => {
    setEditing(item);
    setEmployeeId(item.empleado_id);
    setStart(item.fecha_inicio);
    setEnd(item.fecha_fin);
    setPercentage(item.porcentaje_pago);
    setReason('Corrección de licencia');
  };
  const cancel = async (item: DirectLicense) => {
    const cancellationReason = window.prompt('Motivo de cancelación');
    if (!cancellationReason?.trim()) return;
    try { await p0Service.cancelLicense(item.id, cancellationReason); await load(); }
    catch (e) { setError(errorText(e)); }
  };
  return <>
    <PageHeader eyebrow="RECURSOS HUMANOS" title="Licencias directas" description="Registro inmediato, días calendario y pago diario calculado como salario / 30 × porcentaje." />
    {error && <div className="error">{error}</div>}
    <section className="panel form-grid">
      <label>Empleado<select value={employeeId} disabled={Boolean(editing)} onChange={(e) => setEmployeeId(e.target.value)}>{employees.map((item) => <option key={item.id} value={item.id}>{item.codigo} · {item.nombre}</option>)}</select></label>
      <label>Desde<input type="date" min={editing?.fecha_inicio} value={start} onChange={(e) => setStart(e.target.value)} /></label>
      <label>Hasta<input type="date" min={start} value={end} onChange={(e) => setEnd(e.target.value)} /></label>
      <label>Porcentaje<input type="number" min="0" max="100" step="0.01" value={percentage} onChange={(e) => setPercentage(Number(e.target.value))} /></label>
      <label className="span-2">Motivo<input value={reason} onChange={(e) => setReason(e.target.value)} /></label>
      <div className="button-row"><button className="primary" disabled={busy} onClick={() => void save()}><Save />{editing ? 'Guardar versión' : 'Registrar licencia'}</button>{editing && <button className="secondary" onClick={reset}>Cancelar edición</button>}</div>
    </section>
    <section className="table-wrap"><table><thead><tr><th>Empleado</th><th>Rango</th><th>Pago</th><th>Total</th><th>Estado</th><th /></tr></thead><tbody>{items.map((item) => <tr key={item.id}><td><b>{item.codigo_empleado}</b><small>{item.nombre_empleado}</small></td><td>{item.fecha_inicio} → {item.fecha_fin}</td><td>{item.porcentaje_pago}%</td><td>{money(item.total)}</td><td><Badge tone={item.estado === 'ACTIVA' ? 'green' : 'gray'}>{item.estado}</Badge></td><td><div className="button-row">{item.estado === 'ACTIVA' && <><button className="secondary" onClick={() => edit(item)}>Editar</button><button className="secondary" onClick={() => void cancel(item)}>Cancelar</button></>}</div></td></tr>)}</tbody></table>{!items.length && <Empty text="No hay licencias directas registradas." />}</section>
  </>;
}

export function NoPayPage() {
  const [items, setItems] = useState<IncompleteJourney[]>([]);
  const [hours, setHours] = useState<Record<string, string>>({});
  const [error, setError] = useState('');
  const load = async () => setItems(await p0Service.incompleteJourneys());
  useEffect(() => { void load().catch((e) => setError(errorText(e))); }, []);
  const resolve = async (item: IncompleteJourney, decision: 'NO_PAY' | 'PAY_DEMONSTRABLE') => {
    const manual = item.solo_inicio && decision === 'PAY_DEMONSTRABLE' ? Number(hours[item.jornada_id] ?? '') : undefined;
    if (manual !== undefined && (!Number.isFinite(manual) || manual < 0 || manual > 8)) {
      setError('Solo una jornada con INICIAR admite entre 0 y 8 horas manuales.');
      return;
    }
    try { await p0Service.resolveIncomplete(item.jornada_id, decision, manual); await load(); }
    catch (e) { setError(errorText(e)); }
  };
  return <>
    <PageHeader eyebrow="ASISTENCIA" title="Jornadas incompletas" description="NO PAGAR o reconocimiento de intervalos demostrables; horas manuales solo cuando existe únicamente INICIAR." />
    {error && <div className="error">{error}</div>}
    <section className="table-wrap"><table><thead><tr><th>Empleado</th><th>Fecha</th><th>Evidencia</th><th>Horas manuales</th><th /></tr></thead><tbody>{items.map((item) => <tr key={item.jornada_id}><td><b>{item.codigo_empleado}</b><small>{item.nombre_empleado}</small></td><td>{item.fecha_laboral}</td><td>{item.solo_inicio ? 'Solo INICIAR' : 'Intervalos demostrables'}</td><td>{item.solo_inicio ? <input aria-label="Horas manuales" type="number" min="0" max="8" step="0.25" value={hours[item.jornada_id] ?? ''} onChange={(e) => setHours((current) => ({ ...current, [item.jornada_id]: e.target.value }))} /> : 'Automático'}</td><td><div className="button-row"><button className="secondary" onClick={() => void resolve(item, 'NO_PAY')}><Ban />NO PAGAR</button><button className="primary" onClick={() => void resolve(item, 'PAY_DEMONSTRABLE')}><Calculator />Resolver</button></div></td></tr>)}</tbody></table>{!items.length && <Empty text="No hay jornadas incompletas pendientes." />}</section>
  </>;
}

export function PriorAdjustmentsPage() {
  const [period, setPeriod] = useState('');
  const [items, setItems] = useState<PriorAdjustment[]>([]);
  const [error, setError] = useState('');
  const load = async () => { try { setItems(await p0Service.priorAdjustments(period)); } catch (e) { setError(errorText(e)); } };
  useEffect(() => { void load(); }, []);
  return <>
    <PageHeader eyebrow="NÓMINA" title="Ajustes de períodos anteriores" description="Deltas idempotentes originados después del cierre y aplicables en la siguiente nómina." action={<button className="secondary" onClick={() => void load()}><RefreshCw />Actualizar</button>} />
    {error && <div className="error">{error}</div>}
    <section className="panel"><label>Período destino (opcional)<input value={period} onChange={(e) => setPeriod(e.target.value)} placeholder="UUID del período" /></label></section>
    <section className="table-wrap"><table><thead><tr><th>Empleado</th><th>Origen</th><th>Destino</th><th>Concepto</th><th>Delta</th><th>Estado</th></tr></thead><tbody>{items.map((item) => <tr key={item.id}><td><b>{item.codigo_empleado}</b><small>{item.nombre_empleado}</small></td><td>{item.periodo_origen_id}</td><td>{item.periodo_destino_id ?? 'Siguiente nómina'}</td><td>{item.concepto}</td><td>{money(item.monto)}</td><td><Badge tone={item.estado === 'APLICADO' ? 'green' : 'amber'}>{item.estado}</Badge></td></tr>)}</tbody></table>{!items.length && <Empty text="No hay ajustes anteriores pendientes." />}</section>
  </>;
}

export function BlacklistPage() {
  const [month, setMonth] = useState(monthNow());
  const [employees, setEmployees] = useState<P0Employee[]>([]);
  const [employeeId, setEmployeeId] = useState('');
  const [items, setItems] = useState<BlacklistEntry[]>([]);
  const [error, setError] = useState('');
  useEffect(() => { void p0Service.employees().then(setEmployees).catch((e) => setError(errorText(e))); }, []);
  const report = async () => { try { setItems(await p0Service.blacklistReport(month, employeeId)); } catch (e) { setError(errorText(e)); } };
  const refresh = async () => { try { await p0Service.refreshBlacklist(month); await report(); } catch (e) { setError(errorText(e)); } };
  const selected = useMemo(() => items.find((item) => !employeeId || item.empleado_id === employeeId), [employeeId, items]);
  return <>
    <PageHeader eyebrow="SEGUIMIENTO" title="Lista negra mensual" description="Vista de seguimiento por ausencias, tardanzas y jornadas incompletas. Nunca bloquea marcaciones." action={<div className="button-row"><button className="secondary" onClick={() => void refresh()}><RefreshCw />Recalcular</button><button className="secondary" onClick={() => window.print()}><Printer />Imprimir</button></div>} />
    {error && <div className="error">{error}</div>}
    <section className="panel form-grid"><label>Mes<input type="month" value={month} onChange={(e) => setMonth(e.target.value)} /></label><label>Empleado<select value={employeeId} onChange={(e) => setEmployeeId(e.target.value)}><option value="">Todos</option>{employees.map((item) => <option key={item.id} value={item.id}>{item.codigo} · {item.nombre}</option>)}</select></label><button className="primary" onClick={() => void report()}><CalendarDays />Consultar</button></section>
    <section className="table-wrap"><table><thead><tr><th>Empleado</th><th>Ausencias</th><th>Tardanzas</th><th>Incompletas</th><th>Motivos</th><th>Impacto</th></tr></thead><tbody>{items.map((item) => <tr key={`${item.empleado_id}:${item.mes}`}><td><b>{item.codigo_empleado}</b><small>{item.nombre_empleado}</small></td><td>{item.ausencias}</td><td>{item.tardanzas}</td><td>{item.jornadas_incompletas}</td><td>{item.motivos?.join(', ')}</td><td><Badge tone="amber">Seguimiento, no bloqueo</Badge></td></tr>)}</tbody></table>{!items.length && <Empty text="No hay empleados en seguimiento para el filtro." />}</section>
    {selected?.detalle && <section className="panel"><h2><ShieldAlert /> Detalle individual</h2><pre>{JSON.stringify(selected.detalle, null, 2)}</pre></section>}
  </>;
}
