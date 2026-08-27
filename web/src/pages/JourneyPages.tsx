import { type ReactNode, useEffect, useMemo, useState } from 'react';
import { AlertTriangle, CalendarDays, Filter, RefreshCw, Search, UserRound } from 'lucide-react';
import { Badge, Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { journeyService, type Journey, type JourneyConflict, type JourneyIncident } from '../modules/journeys/journeyService';
import { formatDurationMinutes } from '../modules/journeys/timeFormat';
import { supervisorService, type SupervisorJourney } from '../modules/supervisor/supervisorService';

import '../styles/journeys.css';

const ask = (label: string) => window.prompt(label)?.trim() || '';
const localInput = (value: string | null) => value ? new Date(value).toISOString().slice(0, 16) : '';

type JornadaStatus = 'EN_CURSO' | 'EN_PAUSA' | 'FINALIZADA' | 'SIN_INICIAR' | 'PENDIENTE' | 'INCOMPLETA';
type JourneyStatusTone = 'blue' | 'amber' | 'green' | 'orange' | 'red' | 'gray';

const toStatus = (status: string): string => (status ?? '').toUpperCase().trim();

const statusTone = (status: string): JourneyStatusTone => {
  const normalized = toStatus(status);
  if (normalized === 'FINALIZADA') return 'green';
  if (normalized === 'EN_CURSO') return 'amber';
  if (normalized === 'EN_PAUSA') return 'blue';
  if (normalized === 'PENDIENTE') return 'orange';
  if (normalized === 'INCOMPLETA') return 'red';
  return 'gray';
};

const statusLabel = (status: string): string => {
  const normalized = toStatus(status);
  if (normalized === 'EN_CURSO') return 'EN CURSO';
  if (normalized === 'EN_PAUSA') return 'EN PAUSA';
  if (normalized === 'FINALIZADA') return 'FINALIZADA';
  if (normalized === 'SIN_INICIAR') return 'SIN INICIAR';
  if (normalized === 'PENDIENTE') return 'PENDIENTE';
  if (normalized === 'INCOMPLETA') return 'INCOMPLETA';
  return status || 'SIN ESTADO';
};

function JourneyStatusBadge({ status, tone = 'gray' }: { status: string; tone?: JourneyStatusTone }) {
  return <span className={`journey-status-badge journey-status-${tone}`}>{statusLabel(status)}</span>;
}

function JourneyEmployeeHeader({ name, code, branch, department }: { name: string; code: string; branch: string; department: string }) {
  return <div className="journey-employee">
    <span className="journey-employee-name">{name || 'Sin nombre'}</span>
    <span className="journey-employee-subtitle">{code || 'Sin código'} · {branch || 'Sin sucursal'} · {department || 'Sin departamento'}</span>
  </div>;
}

function TimesBlock({ workedMinutes, breakMinutes }: { workedMinutes: number; breakMinutes: number }) {
  return <div className="journey-time-block">
    <small>Trabajo</small>
    <strong>{formatDurationMinutes(workedMinutes)}</strong>
    <small>Pausa</small>
    <strong>{formatDurationMinutes(breakMinutes)}</strong>
  </div>;
}

function JourneyLoadingSkeleton() {
  return <div className="journey-skeleton" role="status" aria-live="polite">
    {Array.from({ length: 5 }).map((_, index) => (
      <article className="journey-skeleton-row" key={index}><span /><span /><span /><span /></article>
    ))}
  </div>;
}

function JourneyFiltersCard({
  title,
  children,
  canApply,
  onApply,
  onClear,
}: {
  title: string;
  canApply: boolean;
  onApply: () => void;
  onClear: () => void;
  children: ReactNode;
}) {
  return <section className="journey-filters-card panel">
    <div className="journey-filters-title">
      <span><Filter size={16} /> {title}</span>
      <div className="journey-filter-actions">
        <button type="button" className="secondary" onClick={onClear}>Limpiar filtros</button>
        <button type="button" className="primary" disabled={!canApply} onClick={() => void onApply()}>Aplicar</button>
      </div>
    </div>
    <div className="journey-filters">
      {children}
    </div>
  </section>;
}

function JourneyEmptyState() {
  return <div className="journey-empty">
    <span className="journey-empty-icon"><Search size={24} /></span>
    <i>No se encontraron jornadas</i>
    <p>Prueba cambiando los filtros.</p>
  </div>;
}

function AllJourneysPage({ pendingOnly }: { pendingOnly: boolean }) {
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<Journey[]>([]);
  const [incidents, setIncidents] = useState<JourneyIncident[]>([]);
  const [conflicts, setConflicts] = useState<JourneyConflict[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<Journey | null>(null);

  const defaultFilters = { date: '', query: '', status: 'TODOS', severity: 'TODAS' };
  const [filters, setFilters] = useState(defaultFilters);
  const [draftFilters, setDraftFilters] = useState(defaultFilters);

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
      if(import.meta.env.DEV)console.error('ERROR_LOAD_JOURNEYS',{errorType:reason instanceof Error?reason.name:'UnknownError'});
      setError('No fue posible cargar jornadas. Vuelve a intentarlo.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void load(); }, []);

  const filtered = useMemo(() => items.filter((journey) =>
    (!filters.date || journey.workDate === filters.date) &&
    (!pendingOnly || journey.pendingReview) &&
    (filters.status === 'TODOS' || journey.status === filters.status) &&
    (filters.severity === 'TODAS' || journey.severity === filters.severity) &&
    `${journey.employee} ${journey.code} ${journey.branch} ${journey.department}`.toLowerCase().includes(filters.query.toLowerCase()),
  ), [items, filters, pendingOnly]);

  const summary = useMemo(() => {
    const inProgress = filtered.filter((journey) => ['EN_CURSO', 'EN_PAUSA'].includes(toStatus(journey.status))).length;
    const completed = filtered.filter((journey) => toStatus(journey.status) === 'FINALIZADA').length;
    const pending = filtered.filter((journey) => journey.pendingReview || toStatus(journey.status) === 'PENDIENTE').length;
    return {
      total: filtered.length,
      inProgress,
      completed,
      pending,
    };
  }, [filtered]);

  const applyFilters = () => {
    setFilters(draftFilters);
  };

  const clearFilters = () => {
    setDraftFilters(defaultFilters);
    setFilters(defaultFilters);
  };

  const canApply = JSON.stringify(filters) !== JSON.stringify(draftFilters);

  const changeEnabled = async (journey: Journey, enabled: boolean) => {
    if (!selected) return;
    const reason = ask(`Motivo obligatorio para ${enabled ? 'habilitar' : 'deshabilitar'} la jornada`);
    if (!reason) return;
    try {
      await journeyService.setEnabled(journey.employeeId, enabled, reason);
      await load();
    } catch (reasonToApprove) {
      if(import.meta.env.DEV)console.error('ERROR_SET_ENABLED');
      setError('No fue posible actualizar el estado de la jornada.');
    }
  };

  const approve = async (journey: Journey) => {
    const reason = ask('Motivo obligatorio de aprobación');
    if (!reason) return;
    try {
      await journeyService.approve(journey.id, reason);
      await load();
    } catch (reasonToApprove) {
      if(import.meta.env.DEV)console.error('ERROR_APPROVE');
      setError('No fue posible aprobar la jornada.');
    }
  };

  const canCorrect = hasPermission('jornadas.admin_off_on');
  const canApprove = hasPermission('jornadas.aprobar_pendientes');

  return <>
    <PageHeader eyebrow="OPERACIONES" title={pendingOnly ? 'Pendientes' : 'Jornadas'} description={pendingOnly ? 'Pendientes de revisión dentro de tu alcance autorizado.' : 'Consulta y gestiona las jornadas de los departamentos asignados.'} />
    <section className="journey-stats">
      <article><strong>{summary.total}</strong><small>Total jornadas</small></article>
      <article><strong>{summary.inProgress}</strong><small>En curso</small></article>
      <article><strong>{summary.completed}</strong><small>Finalizadas</small></article>
      <article><strong>{summary.pending}</strong><small>Pendientes</small></article>
    </section>
    <JourneyFiltersCard
      title="Filtros de jornadas"
      canApply={canApply}
      onApply={applyFilters}
      onClear={clearFilters}
    >
      <label><CalendarDays size={16} />Fecha<input type="date" value={draftFilters.date} onChange={(event) => setDraftFilters((current) => ({ ...current, date: event.target.value }))} /></label>
      <label>Estado<select value={draftFilters.status} onChange={(event) => setDraftFilters((current) => ({ ...current, status: event.target.value }))}><option value="TODOS">TODOS</option>{['SIN_INICIAR', 'EN_CURSO', 'EN_PAUSA', 'FINALIZADA'].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Severidad<select value={draftFilters.severity} onChange={(event) => setDraftFilters((current) => ({ ...current, severity: event.target.value }))}><option value="TODAS">TODAS</option>{['NINGUNA', 'INFORMATIVA', 'MEDIA', 'ALTA', 'CRITICA'].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label><Search size={16} />Empleado / alcance<input value={draftFilters.query} onChange={(event) => setDraftFilters((current) => ({ ...current, query: event.target.value }))} placeholder="Nombre, código, sucursal..." /></label>
    </JourneyFiltersCard>
    {error && <div className="error journey-error" role="alert"><span>{error}</span><button type="button" className="secondary" onClick={() => void load()}><RefreshCw size={14} />Reintentar</button></div>}
    <section className="journey-table-wrap">
      {loading ? <JourneyLoadingSkeleton /> : !filtered.length ? <JourneyEmptyState /> : <>
        <div className="journey-desktop">
          <table>
            <thead><tr><th>Empleado</th><th>Fecha</th><th>Estado</th><th>Tiempos</th><th>Revisión</th><th>Acciones</th></tr></thead>
            <tbody>{filtered.map((journey) => <tr key={journey.id} className={incidents.some((incident) => incident.journeyId === journey.id && !incident.read) ? 'new-event' : ''}>
              <td><JourneyEmployeeHeader name={journey.employee} code={journey.code} branch={journey.branch} department={journey.department} /></td>
              <td>{journey.workDate}</td>
              <td><JourneyStatusBadge status={journey.status} tone={statusTone(journey.status)} /></td>
              <td><TimesBlock workedMinutes={journey.workedMinutes} breakMinutes={journey.breakMinutes} /></td>
              <td>{journey.pendingReview ? <Badge tone="red">{journey.severity}</Badge> : <Badge tone="gray">Sin pendiente</Badge>}</td>
              <td>
                <div className="journey-actions">
                  <button type="button" className="secondary" aria-label={`Ver detalle de ${journey.employee}`} onClick={() => setSelected(journey)}>Ver detalle</button>
                  {canApprove && journey.pendingReview && <button type="button" onClick={() => void approve(journey)}>Aprobar pendiente</button>}
                  {canCorrect && <button type="button" onClick={() => setSelected(journey)}>{'Corregir jornada'}</button>}
                  {!canApprove && !canCorrect && <span className="journey-no-actions">Sin acciones</span>}
                </div>
              </td>
            </tr>)}</tbody>
          </table>
        </div>
        <div className="journey-mobile">
          {filtered.map((journey) => (
            <article className="journey-card" key={journey.id}>
              <header>
                <JourneyEmployeeHeader name={journey.employee} code={journey.code} branch={journey.branch} department={journey.department} />
                <JourneyStatusBadge status={journey.status} tone={statusTone(journey.status)} />
              </header>
              <div className="journey-card-meta">
                <strong>{journey.workDate}</strong>
                <span>{journey.pendingReview ? `Pendiente: ${journey.severity}` : 'Sin pendencia'}</span>
              </div>
              <TimesBlock workedMinutes={journey.workedMinutes} breakMinutes={journey.breakMinutes} />
              <div className="journey-actions">
                <button type="button" className="secondary" onClick={() => setSelected(journey)}>Ver detalle</button>
                {canApprove && journey.pendingReview && <button type="button" onClick={() => void approve(journey)}>Aprobar pendiente</button>}
                {canCorrect && <button type="button" onClick={() => setSelected(journey)}>Corregir jornada</button>}
                {!canApprove && !canCorrect && <span className="journey-no-actions">Sin acciones</span>}
              </div>
            </article>
          ))}
        </div>
      </>}
    </section>
    {selected && <section className="panel" style={{ marginTop: 16 }}>
      <div className="panel-title"><div><span className="eyebrow">DETALLE Y AUDITORÍA</span><h2>{selected.employee} · {selected.workDate}</h2></div><button type="button" onClick={() => setSelected(null)}>Cerrar</button></div>
      {incidents.filter((incident) => incident.journeyId === selected.id).map((incident) => <article className={!incident.read ? 'new-event panel' : 'panel'} key={incident.id}><AlertTriangle /><b>{incident.type} · {incident.severity}</b><p>{incident.message}{incident.minutes != null ? ` · ${formatDurationMinutes(incident.minutes)}` : ''}</p></article>)}
      {conflicts.filter((conflict) => conflict.journeyId === selected.id).map((conflict) => <div className="error" key={conflict.id}>Conflicto {conflict.status}: {conflict.reason}</div>)}
      <div className="button-row">
        {canCorrect && <button type="button" className="secondary" onClick={() => selected && void changeEnabled(selected, false)}>ADMIN-OFF</button>}
        {canCorrect && <button type="button" className="secondary" onClick={() => selected && void changeEnabled(selected, true)}>ADMIN-ON</button>}
        {selected.pendingReview && canApprove && <button type="button" className="primary" onClick={() => void approve(selected)}>Aprobar pendiente</button>}
      </div>
    </section>}
  </>;
}

function TeamJourneysPage({ pendingOnly }: { pendingOnly: boolean }) {
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<SupervisorJourney[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const defaultFilters = { date: '', status: '', severity: '', branch: '', department: '', query: '' };
  const [filters, setFilters] = useState(defaultFilters);
  const [draftFilters, setDraftFilters] = useState(defaultFilters);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      setItems(await supervisorService.journeys(filters.date));
    } catch (reason) {
      if(import.meta.env.DEV)console.error('ERROR_LOAD_TEAM_JOURNEYS',{errorType:reason instanceof Error?reason.name:'UnknownError'});
      setError('No fue posible cargar jornadas de tu equipo.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void load(); }, [filters.date]);

  const rows = useMemo(() => items.filter((journey) =>
    (!pendingOnly || journey.revision_pendiente) &&
    (!filters.status || journey.estado === filters.status) &&
    (!filters.severity || journey.severidad === filters.severity) &&
    (!filters.branch || journey.sucursal === filters.branch) &&
    (!filters.department || journey.departamento === filters.department) &&
    (!filters.query || `${journey.codigo} ${journey.nombre}`.toLowerCase().includes(filters.query.toLowerCase())),
  ), [items, pendingOnly, filters]);

  const summary = useMemo(() => {
    const inProgress = rows.filter((journey) => ['EN_CURSO', 'EN_PAUSA'].includes(toStatus(journey.estado))).length;
    const completed = rows.filter((journey) => toStatus(journey.estado) === 'FINALIZADA').length;
    const pending = rows.filter((journey) => journey.revision_pendiente).length;
    return {
      total: rows.length,
      inProgress,
      completed,
      pending,
    };
  }, [rows]);

  const applyFilters = () => {
    setFilters(draftFilters);
  };

  const clearFilters = () => {
    setDraftFilters(defaultFilters);
    setFilters(defaultFilters);
  };

  const canApply = JSON.stringify(filters) !== JSON.stringify(draftFilters);
  const canCorrect = hasPermission('jornadas.corregir_asignadas');
  const canApprove = hasPermission('jornadas.aprobar_pendientes_asignadas');

  const decide = async (journey: SupervisorJourney, decision: string) => {
    const reason = ask(`Motivo obligatorio: ${decision}`);
    if (!reason) return;
    try {
      await supervisorService.decide(journey.id, decision, reason);
      await load();
    } catch (reasonToDecide) {
      if(import.meta.env.DEV)console.error('ERROR_DECIDE_JOURNEY');
      setError('No fue posible resolver la jornada.');
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
    } catch (reasonToCorrect) {
      if(import.meta.env.DEV)console.error('ERROR_CORRECT_JOURNEY');
      setError('No fue posible corregir la jornada.');
    }
  };

  return <>
    <PageHeader eyebrow="OPERACIONES" title={pendingOnly ? 'Pendientes' : 'Jornadas'} description={pendingOnly ? 'Jornadas pendientes de tu equipo.' : 'Detalle operativo de los departamentos asignados.'} />
    <section className="journey-stats">
      <article><strong>{summary.total}</strong><small>Total jornadas</small></article>
      <article><strong>{summary.inProgress}</strong><small>En curso</small></article>
      <article><strong>{summary.completed}</strong><small>Finalizadas</small></article>
      <article><strong>{summary.pending}</strong><small>Pendientes</small></article>
    </section>
    <JourneyFiltersCard
      title="Filtros de equipo"
      canApply={canApply}
      onApply={applyFilters}
      onClear={clearFilters}
    >
      <label><CalendarDays size={16} />Fecha<input type="date" value={draftFilters.date} onChange={(event) => setDraftFilters((current) => ({ ...current, date: event.target.value }))} /></label>
      <label><UserRound size={16} />Empleado<input value={draftFilters.query} onChange={(event) => setDraftFilters((current) => ({ ...current, query: event.target.value }))} placeholder="Código o nombre" /></label>
      <label>Sucursal<select value={draftFilters.branch} onChange={(event) => setDraftFilters((current) => ({ ...current, branch: event.target.value }))}><option value="">Todas</option>{[...new Set(items.map((item) => item.sucursal))].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Departamento<select value={draftFilters.department} onChange={(event) => setDraftFilters((current) => ({ ...current, department: event.target.value }))}><option value="">Todos</option>{[...new Set(items.map((item) => item.departamento))].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Estado<select value={draftFilters.status} onChange={(event) => setDraftFilters((current) => ({ ...current, status: event.target.value }))}><option value="">Todos</option>{['SIN_INICIAR', 'EN_CURSO', 'EN_PAUSA', 'FINALIZADA'].map((value) => <option key={value}>{value}</option>)}</select></label>
      <label>Severidad<select value={draftFilters.severity} onChange={(event) => setDraftFilters((current) => ({ ...current, severity: event.target.value }))}><option value="">Todas</option>{['NINGUNA', 'INFORMATIVA', 'MEDIA', 'ALTA', 'CRITICA'].map((value) => <option key={value}>{value}</option>)}</select></label>
    </JourneyFiltersCard>
    {error && <div className="error journey-error" role="alert"><span>{error}</span><button type="button" className="secondary" onClick={() => void load()}><RefreshCw size={14} />Reintentar</button></div>}
    <section className="journey-table-wrap">
      {loading ? <JourneyLoadingSkeleton /> : !rows.length ? <JourneyEmptyState /> : <>
        <div className="journey-desktop">
          <table>
            <thead><tr><th>Empleado</th><th>Fecha</th><th>Estado</th><th>Tiempos</th><th>Pendiente</th><th>Acciones</th></tr></thead>
            <tbody>{rows.map((journey) => <tr key={journey.id} className={journey.incidencias.length ? 'new-event' : ''}>
              <td><JourneyEmployeeHeader name={journey.nombre} code={journey.codigo} branch={journey.sucursal} department={journey.departamento} /></td>
              <td>{journey.fecha_laboral}</td>
              <td><JourneyStatusBadge status={journey.estado} tone={statusTone(journey.estado)} /></td>
              <td><TimesBlock workedMinutes={journey.minutos_trabajados} breakMinutes={journey.minutos_pausa} /></td>
                  <td>{journey.revision_pendiente ? <Badge tone="red">{journey.severidad}</Badge> : 'No'}</td>
                  <td>
                    <div className="journey-actions">
                  {canCorrect && <button type="button" onClick={() => void correct(journey)}>Corregir jornada</button>}
                  {journey.revision_pendiente && canApprove && <>
                    <button type="button" onClick={() => void decide(journey, 'APROBADA')}>Aprobar</button>
                    <button type="button" onClick={() => void decide(journey, 'RECHAZADA')}>Rechazar</button>
                    <button type="button" onClick={() => void decide(journey, 'DEVUELTA')}>Devolver</button>
                  </>}
                  {!canCorrect && !journey.revision_pendiente && <span className="journey-no-actions">Sin acciones</span>}
                </div>
              </td>
            </tr>)}</tbody>
          </table>
        </div>
        <div className="journey-mobile">
          {rows.map((journey) => (
            <article className="journey-card" key={journey.id}>
              <header>
                <JourneyEmployeeHeader name={journey.nombre} code={journey.codigo} branch={journey.sucursal} department={journey.departamento} />
                <JourneyStatusBadge status={journey.estado} tone={statusTone(journey.estado)} />
              </header>
              <div className="journey-card-meta">
                <strong>{journey.fecha_laboral}</strong>
                <span>{journey.revision_pendiente ? `Pendiente: ${journey.severidad}` : 'Sin pendencia'}</span>
              </div>
              <TimesBlock workedMinutes={journey.minutos_trabajados} breakMinutes={journey.minutos_pausa} />
              <div className="journey-actions">
                {canCorrect && <button type="button" onClick={() => void correct(journey)}>Corregir jornada</button>}
                {journey.revision_pendiente && canApprove && <button type="button" onClick={() => void decide(journey, 'APROBADA')}>Aprobar pendiente</button>}
                {!canCorrect && !journey.revision_pendiente && <span className="journey-no-actions">Sin acciones</span>}
              </div>
            </article>
          ))}
        </div>
      </>}
    </section>
  </>;
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
