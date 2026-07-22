import { useState } from "react";
import {
  FileDown,
  FileSpreadsheet,
  Fingerprint,
  Search,
  X,
} from "lucide-react";
import { employees } from "../data/mockData";
import { PageHeader, Toast } from "../components/UI";
import { EMPLOYEE_CODE_ERROR, normalizeEmployeeCode } from "../modules/employees/employeeCodePolicy";
import "../styles/employee-code.css";

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

export function KioskPage() {
  const [mode, setMode] = useState<"code" | "face">("face"),
    [employeeCode, setEmployeeCode] = useState(""),
    [employeeName, setEmployeeName] = useState(""),
    [message, setMessage] = useState("");
  function key(k: string) {
    setMessage("");
    if (k === "⌫") setEmployeeCode((value) => value.slice(0, -1));
    else if (/^\d$/.test(k) && employeeCode.length < 6) setEmployeeCode((value) => value + k);
  }
  function identify() {
    const normalizedCode = normalizeEmployeeCode(employeeCode);
    if (!normalizedCode) {
      setMessage(EMPLOYEE_CODE_ERROR);
      return;
    }
    const found = employees.find((employee) => normalizeEmployeeCode(employee.code) === normalizedCode);
    if (found) {
      setEmployeeCode(normalizedCode);
      setEmployeeName(found.name);
      setMessage("Código encontrado. La verificación facial es obligatoria para continuar.");
      setMode("face");
    } else {
      setMessage("Código de empleado no reconocido en los datos demo");
    }
  }
  function reset() {
    setMode("face");
    setEmployeeCode("");
    setEmployeeName("");
    setMessage("");
  }
  return (
    <div className="kiosk">
      <button className="kiosk-close" onClick={reset}>
        <X />
        Reiniciar
      </button>
      <div className="kiosk-brand">
        <span className="brand-mark">O</span>
        <b>OSINET</b>
        <small>CONTROL DE ASISTENCIA</small>
      </div>
      {mode === "face" && (
        <div className="finger-info">
          <Fingerprint />
          <h2>Verificación facial</h2>
          {employeeName && <h3>{employeeCode} · {employeeName}</h3>}
          <p>
            La validación facial es responsabilidad de la aplicación Android.
            El código solo identifica al empleado: nunca autoriza una jornada sin comprobar su rostro.
          </p>
          {message && <p className="kiosk-message">{message}</p>}
          {!employeeName && (
            <button className="secondary" onClick={() => setMode("code")}>
              Usar código de empleado
            </button>
          )}
          <button className="primary" onClick={reset}>
            Reiniciar identificación facial
          </button>
        </div>
      )}
      {mode === "code" && (
        <div className="employee-code-box">
          <span className="eyebrow">CÓDIGO DE EMPLEADO</span>
          <h2>Ingresa tu código de empleado</h2>
          <div className="employee-code-dots" aria-label={`${employeeCode.length} de 6 dígitos ingresados`}>
            {Array.from({ length: 6 }, (_, i) => (
              <i className={employeeCode[i] ? "filled" : ""} key={i} />
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
      {message && mode === "code" && <p className="kiosk-message">{message}</p>}
    </div>
  );
}
