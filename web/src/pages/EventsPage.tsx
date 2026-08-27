import { useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Badge, Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { eventService, type EventRecord, type EventStatus } from '../modules/events/eventService';

type IncidentScope = 'all' | 'pending' | 'assigned';

const tone = (priority: string): 'blue' | 'amber' | 'red' | 'gray' =>
  priority === 'CRITICA' ? 'red' : priority === 'ALTA' ? 'amber' : priority === 'MEDIA' ? 'blue' : 'gray';

export function EventsPage({ detail = false }: { detail?: boolean }) {
  const { id } = useParams();
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<EventRecord[]>([]);
  const canViewAll = hasPermission('eventos.view');
  const canViewAssigned = hasPermission('incidencias.ver_asignadas');
  const [scope, setScope] = useState<IncidentScope>(canViewAll ? 'all' : 'assigned');
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<EventStatus | ''>('');
  const [priority, setPriority] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const data = scope === 'assigned' || (!canViewAll && scope === 'pending')
        ? await eventService.listAssignedToMe()
        : await eventService.list();
      setItems(data);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible cargar incidencias.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!canViewAll && scope === 'all') {
      setScope('assigned');
      return;
    }
    void load();
  }, [scope, canViewAll]);

  const rows = useMemo(() => items.filter((item) =>
    (scope !== 'pending' || item.status === 'Pendiente') &&
    (!status || item.status === status) &&
    (!priority || item.priority === priority) &&
    `${item.code} ${item.employee} ${item.type} ${item.description}`.toLowerCase().includes(query.toLowerCase()),
  ), [items, scope, query, status, priority]);

  const update = async (operation: () => Promise<unknown>) => {
    setBusy(true);
    setError('');
    try {
      await operation();
      await load();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'No fue posible actualizar la incidencia.');
    } finally {
      setBusy(false);
    }
  };

  const incident = items.find((item) => item.id === id);
  if (detail && loading) return <Empty text="Cargando incidencia…" />;
  if (detail && !incident) return <Empty text="Incidencia no encontrada o fuera del alcance autorizado." />;

  if (detail && incident) {
    return <>
      <PageHeader eyebrow="INCIDENCIAS" title={incident.type} description={`${incident.employee} · ${incident.date}`} action={<Link className="secondary" to="/incidencias">Volver</Link>} />
      {error && <div className="error" role="alert">{error}</div>}
      <section className="detail-grid panel">{[
        ['Empleado', incident.employee],
        ['Código', incident.code],
        ['Empresa', 'Empresa autorizada'],
        ['Sucursal', incident.branch],
        ['Departamento', incident.department],
        ['Prioridad', incident.priority],
        ['Estado', incident.status],
        ['Fecha y hora', incident.date],
        ['Descripción', incident.description],
        ['Observaciones', incident.observations || 'Sin observaciones'],
      ].map(([label, value]) => <div key={label}><small>{label}</small><b>{value}</b></div>)}</section>
      <div className="button-row">
        <button type="button" className="secondary" disabled={busy || incident.status !== 'Pendiente'} onClick={() => void update(() => eventService.review(incident.id))}>Marcar revisada</button>
        <button type="button" className="primary" disabled={busy || incident.status === 'Cerrado'} onClick={() => void update(() => eventService.close(incident.id, 'Cierre desde Incidencias'))}>Cerrar</button>
        <button type="button" className="secondary" disabled={busy || incident.status !== 'Cerrado'} onClick={() => void update(() => eventService.reopen(incident.id, 'Reapertura desde Incidencias'))}>Reabrir</button>
      </div>
    </>;
  }

  const counts = {
    critical: items.filter((item) => item.priority === 'CRITICA').length,
    open: items.filter((item) => item.status !== 'Cerrado').length,
    closed: items.filter((item) => item.status === 'Cerrado').length,
    tardy: items.filter((item) => item.type === 'TARDANZA').length,
    absent: items.filter((item) => item.type === 'AUSENCIA').length,
    incomplete: items.filter((item) => item.type === 'JORNADA_INCOMPLETA').length,
    overtime: items.filter((item) => item.type === 'HORAS_EXTRAS').length,
  };

  return <>
    <PageHeader
      eyebrow="OPERACIONES"
      title="Incidencias"
      description="Eventos operativos registrados dentro del alcance autorizado."
      action={<div className="button-row"><button type="button" className="secondary">Exportar PDF</button><button type="button" className="secondary">Exportar Excel</button><button type="button" className="secondary" onClick={() => window.print()}>Imprimir</button></div>}
    />
    {error && <div className="error" role="alert">{error}</div>}
    <section className="stats payroll-stats">{[
      ['Críticas', counts.critical], ['Abiertas', counts.open], ['Cerradas', counts.closed],
      ['Tardanzas', counts.tardy], ['Ausencias', counts.absent], ['Incompletas', counts.incomplete], ['Horas extras', counts.overtime],
    ].map(([label, value]) => <article className="stat" key={String(label)}><span>{label}</span><strong>{value}</strong></article>)}</section>
    <div className="toolbar">
      <input className="search" placeholder="Buscar incidencias" value={query} onChange={(event) => setQuery(event.target.value)} />
      <div className="filter-row" role="group" aria-label="Alcance de incidencias">
        <button type="button" className={scope === 'all' ? 'primary' : 'secondary'} disabled={!canViewAll} title={canViewAll ? undefined : 'No tienes permiso para consultar todas las incidencias.'} onClick={() => setScope('all')}>Todas</button>
        <button type="button" className={scope === 'pending' ? 'primary' : 'secondary'} onClick={() => setScope('pending')}>Pendientes</button>
        <button type="button" className={scope === 'assigned' ? 'primary' : 'secondary'} disabled={!canViewAssigned} title={canViewAssigned ? undefined : 'No tienes permiso para consultar incidencias asignadas.'} onClick={() => setScope('assigned')}>Asignadas a mí</button>
        <select aria-label="Filtrar por prioridad" value={priority} onChange={(event) => setPriority(event.target.value)}><option value="">Todas las prioridades</option>{['CRITICA', 'ALTA', 'MEDIA', 'BAJA', 'INFORMATIVA'].map((value) => <option key={value}>{value}</option>)}</select>
        <select aria-label="Filtrar por estado" value={status} onChange={(event) => setStatus(event.target.value as EventStatus | '')}><option value="">Todos los estados</option>{['Pendiente', 'Revisado', 'Cerrado'].map((value) => <option key={value}>{value}</option>)}</select>
      </div>
    </div>
    <section className="table-wrap payroll-wide">
      <table>
        <thead><tr><th>Fecha</th><th>Empleado</th><th>Código</th><th>Sucursal</th><th>Departamento</th><th>Tipo</th><th>Prioridad</th><th>Estado</th><th>Descripción</th><th /></tr></thead>
        <tbody>{rows.map((item) => <tr key={item.id}>
          <td>{item.date}</td><td>{item.employee}</td><td>{item.code}</td><td>{item.branch}</td><td>{item.department}</td><td>{item.type}</td>
          <td><Badge tone={tone(item.priority)}>{item.priority}</Badge></td><td>{item.status}</td><td>{item.description}</td>
          <td><Link className="secondary" to={`/incidencias/${item.id}`}>Ver</Link></td>
        </tr>)}</tbody>
      </table>
      {loading && <Empty text="Cargando incidencias…" />}
      {!loading && !rows.length && <Empty text="No hay incidencias para los filtros aplicados." />}
    </section>
  </>;
}
