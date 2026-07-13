import { useEffect, useState } from "react";
import {
  AlertTriangle,
  Clock3,
  Coffee,
  TimerReset,
  UserMinus,
  Users,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { Empty, PageHeader } from "../components/UI";
import {
  journeyService,
  type Journey,
} from "../modules/journeys/journeyService";
import { dashboardErrorMessage, logDashboardFailure } from "../modules/dashboard/dashboardDiagnostics";
const localWorkDate = (date = new Date()) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};
export function Rc2DashboardPage() {
  const { session } = useAuth(),
    navigate = useNavigate();
  const [journeys, setJourneys] = useState<Journey[]>([]),
    [loading, setLoading] = useState(true),
    [error, setError] = useState("");
  useEffect(() => {
    journeyService.list()
      .then(setJourneys)
      .catch((e) => {
        logDashboardFailure("jornadas + empleados + jornada_incidencias", e, session);
        setError(dashboardErrorMessage(e));
      })
      .finally(() => setLoading(false));
  }, [session]);
  const today = localWorkDate(),
    rows = journeys.filter((x) => x.workDate === today),
    incidents = rows.flatMap((x) => x.incidents),
    stats = [
      [
        "Sin iniciar",
        rows.filter((x) => x.status === "SIN_INICIAR").length,
        Users,
        "gray",
      ],
      [
        "En curso",
        rows.filter((x) => x.status === "EN_CURSO").length,
        Clock3,
        "green",
      ],
      [
        "En pausa",
        rows.filter((x) => x.status === "EN_PAUSA").length,
        Coffee,
        "amber",
      ],
      [
        "Finalizadas",
        rows.filter((x) => x.status === "FINALIZADA").length,
        TimerReset,
        "blue",
      ],
      [
        "Pendientes",
        rows.filter((x) => x.pendingReview).length,
        UserMinus,
        "red",
      ],
      [
        "Incidencias nuevas",
        incidents.filter((x) => !x.read).length,
        AlertTriangle,
        "amber",
      ],
    ] as const;
  return (
    <>
      <PageHeader
        eyebrow="JORNADAS EN TIEMPO REAL"
        title={`Buenos días, ${session?.name.split(" ")[0] ?? ""}`}
        description="Indicadores reales según Supabase, permisos y RLS."
      />
      {error && <div className="error">{error}</div>}
      {!error && <section className="stats">
        {stats.map(([label, count, Icon, tone]) => (
          <article className="stat" key={label}>
            <div className={`stat-icon ${tone}`}>
              <Icon />
            </div>
            <span>{label}</span>
            <strong>{count}</strong>
            <small>Fecha laboral actual</small>
          </article>
        ))}
      </section>}
      {!error && <div className="dashboard-grid">
        <section className="panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">ACTIVIDAD REAL</span>
              <h2>Jornadas recientes</h2>
            </div>
            <button onClick={() => navigate("/jornadas")}>Ver jornadas</button>
          </div>
          {loading ? (
            <Empty text="Cargando jornadas…" />
          ) : rows.length ? (
            rows.slice(0, 8).map((x) => (
              <article className="employee-cell" key={x.id}>
                <span className="avatar">
                  {x.employee
                    .split(" ")
                    .map((n) => n[0])
                    .join("")
                    .slice(0, 2)}
                </span>
                <div>
                  <b>{x.employee}</b>
                  <p>
                    {x.status} · {x.workedMinutes} minutos
                  </p>
                </div>
              </article>
            ))
          ) : (
            <Empty text="No hay jornadas registradas." />
          )}
        </section>
        <section className="panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">REQUIEREN ATENCIÓN</span>
              <h2>Incidencias internas</h2>
            </div>
          </div>
          {loading ? (
            <Empty text="Cargando incidencias…" />
          ) : incidents.filter((x) => !x.read).length ? (
            incidents
              .filter((x) => !x.read)
              .slice(0, 6)
              .map((x) => (
                <article className="new-event panel" key={x.id}>
                  <AlertTriangle />
                  <b>
                    {x.type} · {x.severity}
                  </b>
                  <p>{x.message}</p>
                </article>
              ))
          ) : (
            <Empty text="No hay incidencias nuevas." />
          )}
        </section>
      </div>}
    </>
  );
}
