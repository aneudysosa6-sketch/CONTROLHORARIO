import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, Eye, Search } from "lucide-react";
import { Badge, Empty, PageHeader } from "../components/UI";
import { useAuth } from "../context/AuthContext";
import {
  journeyService,
  type Journey,
  type JourneyConflict,
  type JourneyIncident,
} from "../modules/journeys/journeyService";
const tone = (status: string) =>
  status === "EN_CURSO"
    ? "green"
    : status === "EN_PAUSA"
      ? "amber"
      : status === "FINALIZADA"
        ? "blue"
        : "gray";
export function JourneysPage() {
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<Journey[]>([]),
    [incidents, setIncidents] = useState<JourneyIncident[]>([]),
    [conflicts, setConflicts] = useState<JourneyConflict[]>([]),
    [loading, setLoading] = useState(true),
    [error, setError] = useState(""),
    [date, setDate] = useState(""),
    [query, setQuery] = useState(""),
    [status, setStatus] = useState("TODOS"),
    [severity, setSeverity] = useState("TODAS"),
    [selected, setSelected] = useState<Journey | null>(null);
  useEffect(() => {
    Promise.all([
      journeyService.list(),
      journeyService.incidents(),
      journeyService.conflicts(),
    ])
      .then(([j, i, c]) => {
        setItems(j);
        setIncidents(i);
        setConflicts(c);
      })
      .catch((e) =>
        setError(
          e instanceof Error ? e.message : "No fue posible cargar jornadas.",
        ),
      )
      .finally(() => setLoading(false));
  }, []);
  const filtered = useMemo(
    () =>
      items.filter(
        (x) =>
          (!date || x.workDate === date) &&
          (status === "TODOS" || x.status === status) &&
          (severity === "TODAS" || x.severity === severity) &&
          `${x.employee} ${x.code} ${x.branch} ${x.department}`
            .toLowerCase()
            .includes(query.toLowerCase()),
      ),
    [items, date, status, severity, query],
  );
  async function changeEnabled(enabled: boolean) {
    if (!selected) return;
    const reason = prompt(
      `Motivo obligatorio para ${enabled ? "habilitar" : "deshabilitar"} la jornada`,
    );
    if (!reason?.trim()) return;
    try {
      await journeyService.setEnabled(selected.employeeId, enabled, reason.trim());
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "No fue posible cambiar el estado de jornada.");
    }
  }
  return (
    <>
      <PageHeader
        eyebrow="JORNADAS RC2"
        title="Control de jornadas"
        description="Estado consolidado, incidencias, revisión y conflictos protegidos por RLS."
      />
      <div className="report-filters">
        <label>
          Fecha
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
        </label>
        <label>
          Estado
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option>TODOS</option>
            {["SIN_INICIAR", "EN_CURSO", "EN_PAUSA", "FINALIZADA"].map((x) => (
              <option key={x}>{x}</option>
            ))}
          </select>
        </label>
        <label>
          Severidad
          <select
            value={severity}
            onChange={(e) => setSeverity(e.target.value)}
          >
            <option>TODAS</option>
            {["NINGUNA", "INFORMATIVA", "MEDIA", "ALTA", "CRITICA"].map((x) => (
              <option key={x}>{x}</option>
            ))}
          </select>
        </label>
        <label>
          Empleado / alcance
          <div className="search">
            <Search />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Nombre, código, sucursal…"
            />
          </div>
        </label>
      </div>
      {error && <div className="error">{error}</div>}
      <section className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Empleado</th>
              <th>Fecha</th>
              <th>Estado</th>
              <th>Trabajado</th>
              <th>Pausa</th>
              <th>Revisión</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {filtered.map((x) => (
              <tr
                key={x.id}
                className={
                  incidents.some((i) => i.journeyId === x.id && !i.read)
                    ? "new-event"
                    : ""
                }
              >
                <td>
                  <b>{x.employee}</b>
                  <small>
                    {x.code} · {x.branch} · {x.department}
                  </small>
                </td>
                <td>{x.workDate}</td>
                <td>
                  <Badge tone={tone(x.status)}>{x.status}</Badge>
                </td>
                <td>{x.workedMinutes} min</td>
                <td>{x.breakMinutes} min</td>
                <td>
                  {x.pendingReview ? (
                    <Badge tone="red">{x.severity}</Badge>
                  ) : (
                    <Badge tone="gray">Sin pendiente</Badge>
                  )}
                </td>
                <td>
                  <button className="icon" onClick={() => setSelected(x)}>
                    <Eye />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {loading ? (
          <Empty text="Cargando jornadas…" />
        ) : (
          !filtered.length && (
            <Empty text="No hay jornadas para estos filtros." />
          )
        )}
      </section>
      {selected && (
        <section className="panel" style={{ marginTop: 16 }}>
          <div className="panel-title">
            <div>
              <span className="eyebrow">DETALLE Y AUDITORÍA</span>
              <h2>
                {selected.employee} · {selected.workDate}
              </h2>
            </div>
            <button onClick={() => setSelected(null)}>Cerrar</button>
          </div>
          {incidents
            .filter((i) => i.journeyId === selected.id)
            .map((i) => (
              <article
                className={!i.read ? "new-event panel" : "panel"}
                key={i.id}
              >
                <AlertTriangle />
                <b>
                  {i.type} · {i.severity}
                </b>
                <p>
                  {i.message}
                  {i.minutes != null ? ` · ${i.minutes} minutos` : ""}
                </p>
              </article>
            ))}
          {conflicts
            .filter((c) => c.journeyId === selected.id)
            .map((c) => (
              <div className="error" key={c.id}>
                Conflicto {c.status}: {c.reason}
              </div>
            ))}
          {hasPermission("jornadas.admin_off_on") && (
            <div className="button-row">
              <button className="secondary" onClick={() => changeEnabled(false)}>
                ADMIN-OFF
              </button>
              <button className="secondary" onClick={() => changeEnabled(true)}>
                ADMIN-ON
              </button>
            </div>
          )}
          {selected.pendingReview &&
            hasPermission("jornadas.aprobar_pendientes") && (
              <button
                className="primary"
                onClick={() => {
                  const reason = prompt("Motivo obligatorio de aprobación");
                  if (reason?.trim())
                    journeyService
                      .approve(selected.id, reason.trim())
                      .then(() => location.reload())
                      .catch((e) => setError(String(e)));
                }}
              >
                Aprobar pendiente
              </button>
            )}
        </section>
      )}
    </>
  );
}
export function AttendancePage() {
  return <JourneysPage />;
}
