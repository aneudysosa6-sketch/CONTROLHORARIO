import { useCallback, useEffect, useState } from 'react';
import { AlertTriangle, Clock3, Coffee, TimerReset, UserMinus, Users } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { dashboardErrorMessage, logDashboardContext, logDashboardFailure } from '../modules/dashboard/dashboardDiagnostics';
import { DashboardQueryError, dashboardService, type DashboardSnapshot } from '../modules/dashboard/dashboardService';

export function Rc2DashboardPage() {
  const { session } = useAuth();
  const navigate = useNavigate();
  const [snapshot, setSnapshot] = useState<DashboardSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadDashboard = useCallback(async (initialLoad: boolean) => {
    if (initialLoad) {
      setLoading(true);
      setError('');
      setSnapshot(null);
    }
    if (!session) {
      setError('No existe una sesión autenticada para cargar el Dashboard.');
      setLoading(false);
      return;
    }
    try {
      const value = await dashboardService.load(session);
      logDashboardContext('admin scoped queries', session, value.workDate);
      setSnapshot(value);
      setError('');
    } catch (failure) {
      logDashboardFailure(failure instanceof DashboardQueryError ? failure.query : 'dashboard.load', failure, session, failure instanceof DashboardQueryError ? failure.workDate : null);
      setError(dashboardErrorMessage(failure));
    } finally {
      if (initialLoad) setLoading(false);
    }
  }, [session]);

  useEffect(() => {
    void loadDashboard(true);
    const interval = window.setInterval(() => { void loadDashboard(false); }, 15_000);
    const onFocus = () => { void loadDashboard(false); };
    window.addEventListener('focus', onFocus);
    return () => {
      window.clearInterval(interval);
      window.removeEventListener('focus', onFocus);
    };
  }, [loadDashboard]);

  const stats = snapshot ? [
    ['Sin iniciar', snapshot.notStarted, Users, 'gray'], ['En curso', snapshot.inProgress, Clock3, 'green'], ['En pausa', snapshot.paused, Coffee, 'amber'], ['Finalizadas', snapshot.finished, TimerReset, 'blue'], ['Pendientes', snapshot.pending, UserMinus, 'red'], ['Incidencias', snapshot.incidentCount, AlertTriangle, 'amber'],
  ] as const : [];

  return <>
    <PageHeader eyebrow="JORNADAS EN TIEMPO REAL" title={`Buenos días, ${session?.name.split(' ')[0] ?? ''}`} description="Indicadores reales según Supabase, permisos y RLS." />
    {error && <div className="error" role="alert">{error}</div>}
    {loading && <Empty text="Cargando Dashboard protegido…" />}
    {snapshot && !error && <><section className="stats">{stats.map(([label, count, Icon, tone]) => <article className="stat" key={label}><div className={`stat-icon ${tone}`}><Icon /></div><span>{label}</span><strong>{count}</strong><small>{snapshot.workDate}</small></article>)}</section><div className="dashboard-grid">
      <section className="panel"><div className="panel-title"><div><span className="eyebrow">ACTIVIDAD REAL</span><h2>Jornadas recientes</h2></div><button onClick={() => navigate('/jornadas')}>Ver jornadas</button></div>{snapshot.recent.length ? snapshot.recent.map((journey) => <article className="employee-cell" key={journey.id}><span className="avatar">{journey.employee.split(' ').map((name) => name[0]).join('').slice(0, 2)}</span><div><b>{journey.code ? `${journey.code} · ` : ''}{journey.employee}</b><p>{journey.status} · {journey.workedMinutes} minutos · {journey.severity}</p></div></article>) : <Empty text="No hay jornadas para la fecha laboral de la empresa." />}</section>
      <section className="panel"><div className="panel-title"><div><span className="eyebrow">REQUIEREN ATENCIÓN</span><h2>Incidencias internas</h2></div></div>{snapshot.incidents.length ? snapshot.incidents.map((incident) => <article className="new-event panel" key={incident.id}><AlertTriangle /><b>{incident.employee} · {incident.type} · {incident.severity}</b><p>{incident.message}</p></article>) : <Empty text="No hay incidencias nuevas." />}</section>
    </div></>}
  </>;
}
