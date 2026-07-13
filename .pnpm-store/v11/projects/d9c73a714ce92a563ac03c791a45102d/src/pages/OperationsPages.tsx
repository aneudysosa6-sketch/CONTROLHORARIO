import { useState } from "react";
import {
  FileDown,
  FileSpreadsheet,
  Fingerprint,
  MapPin,
  Pause,
  Play,
  RotateCcw,
  Search,
  Square,
  X,
} from "lucide-react";
import { employees } from "../data/mockData";
import { Badge, PageHeader, Toast } from "../components/UI";

export function ReportsPage() {
  const [message, setMessage] = useState("");
  const [range, setRange] = useState("Semanal");
  function exportFile(type: string) {
    const text = `Reporte ${range} OSINET\nHoras totales: 632\nHoras extras: 18\nTardanzas: 7\nAusencias: 3`;
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([text], { type: "text/plain" }));
    a.download = `reporte-${range.toLowerCase()}.${type === "Excel" ? "csv" : "txt"}`;
    a.click();
    URL.revokeObjectURL(a.href);
    setMessage(`Reporte preparado para ${type}`);
  }
  return (
    <>
      <PageHeader
        eyebrow="INTELIGENCIA OPERATIVA"
        title="Reportes"
        description="Analiza asistencia por período, empleado, departamento y estado."
        action={
          <div className="button-row">
            <button className="secondary" onClick={() => exportFile("PDF")}>
              <FileDown />
              Preparar PDF
            </button>
            <button className="primary" onClick={() => exportFile("Excel")}>
              <FileSpreadsheet />
              Exportar Excel
            </button>
          </div>
        }
      />
      <div className="report-filters">
        <label>
          Período
          <select value={range} onChange={(e) => setRange(e.target.value)}>
            <option>Diario</option>
            <option>Semanal</option>
            <option>Mensual</option>
          </select>
        </label>
        <label>
          Desde
          <input type="date" defaultValue="2026-07-06" />
        </label>
        <label>
          Hasta
          <input type="date" defaultValue="2026-07-10" />
        </label>
        <label>
          Departamento
          <select>
            <option>Todos</option>
            <option>Operaciones</option>
            <option>Finanzas</option>
            <option>Tecnología</option>
          </select>
        </label>
        <button className="primary">
          <Search />
          Aplicar filtros
        </button>
      </div>
      <section className="stats report-stats">
        {[
          ["Horas totales", "632h"],
          ["Horas normales", "614h"],
          ["Horas extras", "18h"],
          ["Tardanzas", "7"],
          ["Ausencias", "3"],
          ["Pausas", "42"],
        ].map(([k, v]) => (
          <article className="stat" key={k}>
            <span>{k}</span>
            <strong>{v}</strong>
            <small>Período seleccionado</small>
          </article>
        ))}
      </section>
      <section className="panel chart-panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">ASISTENCIA SEMANAL</span>
            <h2>Horas por día</h2>
          </div>
        </div>
        <div className="bars">
          {[78, 92, 86, 96, 72].map((h, i) => (
            <div key={i}>
              <span style={{ height: `${h}%` }} />
              <small>{["Lun", "Mar", "Mié", "Jue", "Vie"][i]}</small>
            </div>
          ))}
        </div>
      </section>
      <Toast message={message} />
    </>
  );
}

export function SettingsPage() {
  const [saved, setSaved] = useState("");
  function submit(e: React.FormEvent) {
    e.preventDefault();
    setSaved("Configuración guardada localmente");
    setTimeout(() => setSaved(""), 2200);
  }
  return (
    <>
      <PageHeader
        eyebrow="ADMINISTRACIÓN"
        title="Configuración"
        description="Personaliza empresa, reglas laborales, catálogos y preferencias del sistema."
      />
      <form className="settings-grid" onSubmit={submit}>
        {[
          ["Datos de la empresa", "Razón social, RNC, sucursales y contacto"],
          ["Horarios", "Turnos, días laborables y descansos"],
          ["Reglas laborales", "Tolerancia de tardanza y horas extras"],
          ["Organización", "Departamentos y cargos"],
          ["Usuarios administradores", "Roles, permisos y accesos"],
          ["Apariencia", "Tema, densidad y preferencias"],
        ].map(([title, desc], i) => (
          <section className="panel" key={title}>
            <span className="setting-index">0{i + 1}</span>
            <h2>{title}</h2>
            <p>{desc}</p>
            <label>
              {i === 0 ? "Nombre / valor principal" : "Configuración"}
              <input
                defaultValue={
                  i === 0
                    ? "ACME Dominicana"
                    : i === 1
                      ? "L-V · 8:00–17:00"
                      : i === 2
                        ? "15 minutos"
                        : "Configuración predeterminada"
                }
              />
            </label>
          </section>
        ))}
        <button className="primary save-settings">Guardar preferencias</button>
      </form>
      <Toast message={saved} />
    </>
  );
}

export function KioskPage() {
  const [mode, setMode] = useState<"home" | "pin" | "finger">("home"),
    [pin, setPin] = useState(""),
    [identified, setIdentified] = useState(false),
    [message, setMessage] = useState("");
  function key(k: string) {
    if (k === "⌫") setPin((p) => p.slice(0, -1));
    else if (/^\d$/.test(k) && pin.length < 5) setPin((p) => p + k);
  }
  function identify() {
    if (!/^\d{5}$/.test(pin)) {
      setMessage("El código debe contener exactamente 5 dígitos.");
      return;
    }
    const found = employees.find((e) => e.pin === pin);
    if (found) {
      setIdentified(true);
      setMessage(`Hola, ${found.name}`);
    } else setMessage("PIN no reconocido en los datos demo");
  }
  function punch(action: string) {
    setMessage(
      `${action} registrada a las ${new Date().toLocaleTimeString("es-DO", { hour: "2-digit", minute: "2-digit" })}`,
    );
    setTimeout(() => {
      setMode("home");
      setPin("");
      setIdentified(false);
    }, 1800);
  }
  return (
    <div className="kiosk">
      <button
        className="kiosk-close"
        onClick={() => {
          setMode("home");
          setIdentified(false);
        }}
      >
        <X />
        Reiniciar
      </button>
      <div className="kiosk-brand">
        <span className="brand-mark">O</span>
        <b>OSINET</b>
        <small>CONTROL DE ASISTENCIA</small>
      </div>
      {mode === "home" && (
        <>
          <div>
            <span className="eyebrow">BIENVENIDO</span>
            <h1>Registra tu jornada</h1>
            <p>Selecciona tu método de identificación</p>
          </div>
          <div className="kiosk-options">
            <button onClick={() => setMode("pin")}>
              <span>••••</span>
              <b>Ingresar con PIN</b>
              <small>Usa tu código personal</small>
            </button>
            <button onClick={() => setMode("finger")}>
              <Fingerprint />
              <b>Usar huella</b>
              <small>Requiere app Android / dispositivo compatible</small>
            </button>
          </div>
        </>
      )}
      {mode === "finger" && (
        <div className="finger-info">
          <Fingerprint />
          <h2>Verificación biométrica</h2>
          <p>
            La huella real es responsabilidad de la aplicación Android y el
            lector 2Connect. El navegador no simula ni registra biometría.
          </p>
          <button className="primary" onClick={() => setMode("home")}>
            Volver
          </button>
        </div>
      )}
      {mode === "pin" && !identified && (
        <div className="pin-box">
          <span className="eyebrow">IDENTIFICACIÓN POR PIN</span>
          <div className="pin-dots">
            {Array.from({ length: 5 }, (_, i) => (
              <i className={pin[i] ? "filled" : ""} key={i} />
            ))}
          </div>
          <div className="keypad">
            {["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0"].map(
              (k) => (
                <button onClick={() => key(k)} key={k}>
                  {k}
                </button>
              ),
            )}
            <button className="ok" onClick={identify}>
              OK
            </button>
          </div>
        </div>
      )}
      {mode === "pin" && identified && (
        <div className="punch-actions">
          <h2>{message}</h2>
          <div>
            <button onClick={() => punch("Inicio de jornada")}>
              <Play />
              Iniciar jornada
            </button>
            <button onClick={() => punch("Pausa")}>
              <Pause />
              Pausar
            </button>
            <button onClick={() => punch("Reanudación")}>
              <RotateCcw />
              Reanudar
            </button>
            <button onClick={() => punch("Fin de jornada")}>
              <Square />
              Finalizar
            </button>
          </div>
        </div>
      )}{" "}
      {message && !identified && <p className="kiosk-message">{message}</p>}
    </div>
  );
}
