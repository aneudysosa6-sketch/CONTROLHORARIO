import { useEffect, useId, useState } from 'react';
import { RotateCcw, UserMinus, X } from 'lucide-react';
import { employeeService, type EmployeeRecord } from './employeeService';
import '../../styles/employee-lifecycle.css';

export type EmployeeLifecycleMode = 'terminate' | 'reactivate';

const today = () => {
  const date = new Date();
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().slice(0, 10);
};

export function EmployeeLifecycleDialog({
  employee,
  mode,
  onCancel,
  onCompleted,
}: {
  employee: EmployeeRecord;
  mode: EmployeeLifecycleMode;
  onCancel: () => void;
  onCompleted: (message: string) => void | Promise<void>;
}) {
  const titleId = useId();
  const descriptionId = useId();
  const [date, setDate] = useState(today);
  const [reason, setReason] = useState('');
  const [observation, setObservation] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const terminating = mode === 'terminate';

  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !busy) onCancel();
    };
    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [busy, onCancel]);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError('');
    if (terminating && !date) {
      setError('La fecha de desvinculación es obligatoria.');
      return;
    }
    if (reason.trim().length < 3) {
      setError('El motivo debe tener al menos 3 caracteres para conservar la auditoría.');
      return;
    }
    setBusy(true);
    try {
      if (terminating) {
        await employeeService.terminate(employee.id, { date, reason, observation });
        await onCompleted(`${employee.name} fue desvinculado sin eliminar su historial.`);
      } else {
        await employeeService.reactivate(employee.id, reason);
        await onCompleted(`${employee.name} fue reactivado correctamente.`);
      }
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'No fue posible completar la operación.');
    } finally {
      setBusy(false);
    }
  }

  return <div className="employee-dialog-backdrop" onMouseDown={(event) => {
    if (event.target === event.currentTarget && !busy) onCancel();
  }}>
    <section className="employee-dialog" role="dialog" aria-modal="true" aria-labelledby={titleId} aria-describedby={descriptionId}>
      <header>
        <div>
          <span className="eyebrow">GESTIÓN LABORAL</span>
          <h2 id={titleId}>{terminating ? 'Confirmar desvinculación' : 'Reactivar empleado'}</h2>
        </div>
        <button type="button" className="icon" aria-label="Cerrar" disabled={busy} onClick={onCancel}><X /></button>
      </header>
      <p id={descriptionId}>
        <strong>{employee.code} · {employee.name}</strong><br />
        {terminating
          ? 'El expediente, las jornadas, la nómina y la auditoría se conservarán. El empleado dejará de aparecer en el listado operativo.'
          : 'El empleado volverá al listado operativo. La desvinculación anterior permanecerá en el historial de auditoría.'}
      </p>
      {terminating && <p><strong>¿Está seguro de que desea desvincular a este empleado?</strong></p>}
      <form onSubmit={submit}>
        {terminating && <label>Fecha de desvinculación *
          <input autoFocus type="date" required max={today()} value={date} onChange={(event) => setDate(event.target.value)} />
        </label>}
        <label>{terminating ? 'Motivo de desvinculación' : 'Motivo de reactivación'} *
          <input autoFocus={!terminating} required minLength={3} maxLength={500} value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Describe el motivo" />
        </label>
        {terminating && <label>Observación
          <textarea maxLength={2000} rows={4} value={observation} onChange={(event) => setObservation(event.target.value)} placeholder="Información adicional opcional" />
        </label>}
        {error && <div className="error" role="alert">{error}</div>}
        <div className="form-actions">
          <button type="button" className="secondary" disabled={busy} onClick={onCancel}>Cancelar</button>
          <button type="submit" className={terminating ? 'danger' : 'primary'} disabled={busy}>
            {terminating ? <UserMinus /> : <RotateCcw />}
            {busy ? 'Procesando…' : terminating ? 'Confirmar baja' : 'Confirmar reactivación'}
          </button>
        </div>
      </form>
    </section>
  </div>;
}
