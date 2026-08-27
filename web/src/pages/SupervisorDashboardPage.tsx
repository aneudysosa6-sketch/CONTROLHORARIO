import { useEffect, useState } from 'react';
import { AlertTriangle, Clock3, Coffee, ShieldCheck, TimerReset, Users } from 'lucide-react';
import { Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { dashboardErrorMessage, logDashboardContext, logDashboardFailure } from '../modules/dashboard/dashboardDiagnostics';
import { supervisorService, type SupervisorDashboard } from '../modules/supervisor/supervisorService';

export function SupervisorDashboardPage() {
  const { session } = useAuth();
  const [data, setData] = useState<SupervisorDashboard | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    supervisorService.dashboard()
      .then((value) => {
        logDashboardContext('rpc dashboard_supervisor', session, value.fecha_laboral);
        setData(value);
      })
      .catch((reason) => {
        logDashboardFailure('rpc dashboard_supervisor', reason, session);
        setError(dashboardErrorMessage(reason));
      });
  }, [session]);

  const stats = data ? [
    ['Equipo', data.total_empleados, Users],
    ['Activos', data.activos, Users],
    ['Sin iniciar', data.sin_iniciar, Clock3],
    ['En curso', data.en_curso, ShieldCheck],
    ['En pausa', data.en_pausa, Coffee],
    ['Finalizadas', data.finalizadas, TimerReset],
    ['Pendientes', data.pendientes, AlertTriangle],
    ['Incidencias', data.incidencias_nuevas, AlertTriangle],
    ['ADMIN-OFF', data.jornadas_deshabilitadas, AlertTriangle],
  ] as const : [];

  return <>
    <PageHeader eyebrow="OPERACIÓN" title="Dashboard" description="Resumen operativo de los departamentos asignados." />
    {error && <div className="error" role="alert">{error}</div>}
    {!data && !error && <Empty text="Cargando datos protegidos…" />}
    {data && <>
      <section className="stats">{stats.map(([label, count, Icon]) => <article className="stat" key={label}><div className="stat-icon blue"><Icon /></div><span>{label}</span><strong>{count}</strong><small>{data.fecha_laboral}</small></article>)}</section>
      <div className="dashboard-grid">
        <section className="panel"><h2>Actividad reciente</h2>{data.recientes.length ? data.recientes.map((item) => <article className="employee-cell" key={item.id}><b>{item.codigo} · {item.nombre}</b><p>{item.estado} · {item.severidad}</p></article>) : <Empty text="Sin actividad del equipo." />}</section>
        <section className="panel"><h2>Incidencias y empleados sin iniciar</h2>{data.incidencias.length ? data.incidencias.map((item) => <article className="new-event panel" key={`${item.tipo}-${item.id}`}><b>{item.nombre} · {item.tipo}</b><p>{item.mensaje}</p></article>) : <Empty text="Sin incidencias ni empleados pendientes de iniciar." />}</section>
      </div>
    </>}
  </>;
}
