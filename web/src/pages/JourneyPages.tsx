import { useEffect, useMemo, useState } from 'react';
import { AlertTriangle, Eye, Search } from 'lucide-react';
import { Badge, Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { journeyService, type Journey, type JourneyConflict, type JourneyIncident } from '../modules/journeys/journeyService';
import { supervisorService, type SupervisorJourney } from '../modules/supervisor/supervisorService';

const tone = (status: string) => status === 'EN_CURSO'
  ? 'green'
  : status === 'EN_PAUSA'
    ? 'amber'
    : status === 'FINALIZADA'
      ? 'blue'
      : 'gray';

const ask = (label: string) => window.prompt(label)?.trim() || '';
const localInput = (value: string | null) => value ? new Date(value).toISOString().slice(0, 16) : '';

function AllJourneysPage({ pendingOnly }: { pendingOnly: boolean }) {
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<Journey[]>([]);
  const [incidents, setIncidents] = useState<JourneyIncident[]>([]);
  const [conflicts, setConflicts] = useState<JourneyConflict[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [date, setDate] = useState('');
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState('TODOS');
  const [severity, setSeverity] = useState('TODAS');
  const [selected, setSelected] = useState<Journey | null>(null);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const [journeys, nextIncidents, nextConflicts] = await Promise.all([
        journeyService.list(),
        journeyService.incidents(),
        journeyService.conflicts(),
      ]);
      setItems(journeys);
      setIncidents(nextIncidents);
      setConflicts(nextConflicts);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible cargar jornadas.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void load(); }, []);

  const filtered = useMemo(() => items.filter((journey) =>
    (!date || journey.workDate === date) &&
    (!pendingOnly || journey.pendingReview) &&
    (status === 'TODOS' || journey.status === status) &&
    (severity === 'TODAS' || journey.severity === severity) &&
    `${journey.employee} ${journey.code} ${journey.branch} ${journey.department}`.toLowerCase().includes(query.toLowerCase()),
  ), [items, date, pendingOnly, status, severity, query]);

  const changeEnabled = async (enabled: boolean) => {
    if (!selected) return;
    const reason = ask(`Motivo obligatorio para ${enabled ? 'habilitar' : 'deshabilitar'} la jornada`);
    if (!reason) return;
    try {
      await journeyService.setEnabled(selected.employeeId, enabled, reason);
      await load();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'No fue posible cambiar el estado de jornada.');
    }
  };

  const approve = async () => {
    if (!selected) return;
    const reason = ask('Motivo obligatorio de aprobación');
    if (!reason) return;
    try {
      await journeyService.approve(selected.id, reason);
      await load();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'No fue posible aprobar la jornada.');
    }
  };

  return <>
    <PageHeader eyebrow="OPERACIONES" title={pendingOnly ? 'Pendientes' : 'Jornadas'} description={pendingOnly ? 'Jornadas que requieren revisión dentro de tu alcance autorizado.' : 'Estado consolidado, incidencias, revisión y conflictos protegidos por permisos.'} />
    <JourneyFilters date={date} setDate={setDate} query={query} setQuery={setQuery} status={status} setStatus={setStatus} severity={severity} setSeverity={setSeverity} />
    {error && <div className="error" role="alert">{error}</div>}
    <section className="table-wrap">
      <table><thead><tr><th>Empleado</th><th>Fecha</th><th>Estado</th><th>Trabajado</th><th>Pausa</th><th>Revisión</th><th /></tr></thead><tbody>{filtered.map((journey) => <tr key={journey.id} className={incidents.some((incident) => incident.journeyId === journey.id && !incident.read) ? 'new-event' : ''}>
        <td><b>{journey.employee}</b><small>{journey.code} · {journey.branch} · {journey.department}</small></td>
        <td>{journey.workDate}</td><td><Badge tone={tone(journey.status)}>{journey.status}</Badge></td><td>{journey.workedMinutes} min</td><td>{journey.breakMinutes} min</td>
        <td>{journey.pendingReview ? <Badge tone="red">{journey.severity}</Badge> : <Badge tone="gray">Sin pendiente</Badge>}</td>
        <td><button type="button" className="icon" aria-label={`Ver jornada de ${journey.employee}`} onClick={() => setSelected(journey)}><Eye /></button></td>
      </tr>)}</tbody></table>
      {loading && <Empty text="Cargando jornadas…" />}
      {!loading && !filtered.length && <Empty text="No hay jornadas para estos filtros." />}
    </section>
    {selected && <section className="panel" style={{ marginTop: 16 }}>
      <div className="panel-title"><div><span className="eyebrow">DETALLE Y AUDITORÍA</span><h2>{selected.employee} · {selected.workDate}</h2></div><button type="button" onClick={() => setSelected(null)}>Cerrar</button></div>
      {incidents.filter((incident) => incident.journeyId === selected.id).map((incident) => <article className={!incident.read ? 'new-event panel' : 'panel'} key={incident.id}><AlertTriangle /><b>{incident.type} · {incident.severity}</b><p>{incident.message}{incident.minutes != null ? ` · ${incident.minutes} minutos` : ''}</p></article>)}
      {conflicts.filter((conflict) => conflict.journeyId === selected.id).map((conflict) => <div className="error" key={conflict.id}>Conflicto {conflict.status}: {conflict.reason}</div>)}
      {hasPermission('jornadas.admin_off_on') && <div className="button-row"><button type="button" className="secondary" onClick={() => void changeEnabled(false)}>ADMIN-OFF</button><button type="button" className="secondary" onClick={() => void changeEnabled(true)}>ADMIN-ON</button></div>}
      {selected.pendingReview && hasPermission('jornadas.aprobar_pendientes') && <button type="button" className="primary" onClick={() => void approve()}>Aprobar pendiente</button>}
    </section>}
  </>;
}

function TeamJourneysPage({ pendingOnly }: { pendingOnly: boolean }) {
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<SupervisorJourney[]>([]);
  const [date, setDate] = useState('');
  const [status, setStatus] = useState('');
  const [severity, setSeverity] = useState('');
  const [branch, setBranch] = useState('');
  const [department, setDepartment] = useState('');
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      setItems(await supervisorService.journeys(date));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible cargar jornadas de tu equipo.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void load(); }, [date]);

  const rows = useMemo(() => items.filter((journey) =>
    (!pendingOnly || journey.revision_pendiente) &&
    (!status || journey.estado === status) &&
    (!severity || journey.severidad === severity) &&
    (!branch || journey.sucursal === branch) &&
    (!department || journey.departamento === department) &&
    (!query || `${journey.codigo} ${journey.nombre}`.toLowerCase().includes(query.toLowerCase())),
  ), [items, pendingOnly, status, severity, branch, department, query]);

  const decide = async (journey: SupervisorJourney, decision: string) => {
    const reason = ask(`Motivo obligatorio: ${decision}`);
    if (!reason) return;
    try {
      await supervisorService.decide(journey.id, decision, reason);
      await load();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible resolver la jornada.');
    }
  };

  const correct = async (journey: SupervisorJourney) => {
    const reason = ask('Motivo obligatorio de corrección');
    if (!reason) return;
    try {
      await supervisorService.correct(journey.id, {
        start: ask('Llegada ISO (fecha y hora)') || localInput(journey.iniciado_en),
        breakStart: ask('Inicio almuerzo ISO (vacío si no aplica)') || null,
        breakEnd: ask('Regreso almuerzo ISO (vacío si no aplica)') || null,
        end: ask('Salida ISO (fecha y hora)') || localInput(journey.finalizado_en),
      }, reason);
      await load();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible corregir la jornada.');
    }
  };

  return <>
    <PageHeader eyebrow="OPERACIONES" title={pendingOnly ? 'Pendientes' : 'Jornadas'} description={pendingOnly ? 'Jornadas pendientes de tu equipo.' : 'Detalle operativo de los departamentos asignados.'} />
    <div className="report-filters">
      <label>Fecha<input type="date" value={date} onChange={(event) => setDate(event.target.value)} /></label>
      <label>Empleado<input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Código o nombre" /></label>
      <label>Sucursal<select value={branch} onChange={(event) => setBranch(event.target.value)}><option value="">Todas</option>{[...new Set(items.map((item) => item.sucursal))].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Departamento<select value={department} onChange={(event) => setDepartment(event.target.value)}><option value="">Todos</option>{[...new Set(items.map((item) => item.departamento))].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Estado<select value={status} onChange={(event) => setStatus(event.target.value)}><option value="">Todos</option>{['SIN_INICIAR', 'EN_CURSO', 'EN_PAUSA', 'FINALIZADA'].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Severidad<select value={severity} onChange={(event) => setSeverity(event.target.value)}><option value="">Todas</option>{['NINGUNA', 'INFORMATIVA', 'MEDIA', 'ALTA', 'CRITICA'].map((value) => <option key={value}>{value}</option>)}</select></label>
    </div>
    {error && <div className="error" role="alert">{error}</div>}
    <section className="table-wrap payroll-wide"><table><thead><tr><th>Empleado</th><th>Fecha</th><th>Estado</th><th>Tiempos</th><th>Pendiente</th><th>Acciones</th></tr></thead><tbody>{rows.map((journey) => <tr key={journey.id} className={journey.incidencias.length ? 'new-event' : ''}>
      <td><b>{journey.codigo} · {journey.nombre}</b><small>{journey.sucursal} · {journey.departamento}</small></td><td>{journey.fecha_laboral}</td><td>{journey.estado}</td><td>{journey.minutos_trabajados} min · pausa {journey.minutos_pausa}</td>
      <td>{journey.revision_pendiente ? <Badge tone="red">{journey.severidad}</Badge> : 'No'}</td>
      <td><div className="button-row">{hasPermission('jornadas.corregir_asignadas') && <button type="button" onClick={() => void correct(journey)}>Corregir</button>}{journey.revision_pendiente && hasPermission('jornadas.aprobar_pendientes_asignadas') && <><button type="button" onClick={() => void decide(journey, 'APROBADA')}>Aprobar</button><button type="button" onClick={() => void decide(journey, 'RECHAZADA')}>Rechazar</button><button type="button" onClick={() => void decide(journey, 'DEVUELTA')}>Devolver</button></>}</div></td>
    </tr>)}</tbody></table>
      {loading && <Empty text="Cargando jornadas de tu equipo…" />}
      {!loading && !rows.length && <Empty text="No hay jornadas en este alcance." />}
    </section>
  </>;
}

function JourneyFilters({
  date, setDate, query, setQuery, status, setStatus, severity, setSeverity,
}: {
  date: string;
  setDate: (value: string) => void;
  query: string;
  setQuery: (value: string) => void;
  status: string;
  setStatus: (value: string) => void;
  severity: string;
  setSeverity: (value: string) => void;
}) {
  return <div className="report-filters">
    <label>Fecha<input type="date" value={date} onChange={(event) => setDate(event.target.value)} /></label>
    <label>Estado<select value={status} onChange={(event) => setStatus(event.target.value)}><option value="TODOS">TODOS</option>{['SIN_INICIAR', 'EN_CURSO', 'EN_PAUSA', 'FINALIZADA'].map((value) => <option key={value}>{value}</option>)}</select></label>
    <label>Severidad<select value={severity} onChange={(event) => setSeverity(event.target.value)}><option value="TODAS">TODAS</option>{['NINGUNA', 'INFORMATIVA', 'MEDIA', 'ALTA', 'CRITICA'].map((value) => <option key={value}>{value}</option>)}</select></label>
    <label>Empleado / alcance<div className="search"><Search /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Nombre, código, sucursal…" /></div></label>
  </div>;
}

export function JourneysPage({ pendingOnly = false }: { pendingOnly?: boolean }) {
  const { hasPermission } = useAuth();
  return hasPermission('jornadas.ver_todas')
    ? <AllJourneysPage pendingOnly={pendingOnly} />
    : <TeamJourneysPage pendingOnly={pendingOnly} />;
}

export function AttendancePage() {
  return <JourneysPage />;
}
