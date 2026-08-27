import { useEffect, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { faceEnrollmentService, type FaceEnrollmentStatus } from './faceEnrollmentService';

type FaceEnrollmentCardProps = {
  employeeId: string;
  employeeName?: string;
  [key: string]: unknown;
};

export function FaceEnrollmentCard({ employeeId }: FaceEnrollmentCardProps) {
  const { hasPermission } = useAuth();
  const [status, setStatus] = useState<FaceEnrollmentStatus | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const load = async () => {
    setStatus(await faceEnrollmentService.status(employeeId));
  };

  useEffect(() => {
    load().catch((failure) => setError(failure instanceof Error ? failure.message : 'No fue posible consultar el rostro.'));
  }, [employeeId]);

  const reset = async () => {
    if (!window.confirm('¿Eliminar el rostro registrado? El empleado quedará pendiente para registrarlo nuevamente en un Terminal autorizado.')) return;
    setBusy(true);
    setError('');
    try {
      await faceEnrollmentService.reset(employeeId);
      await load();
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'No fue posible eliminar el rostro.');
    } finally {
      setBusy(false);
    }
  };

  const enrolled = status?.face_status === 'ENROLLED';
  return <section className="card stack">
    <div className="section-heading">
      <div>
        <p className="eyebrow">Biometría facial</p>
        <h2>Estado del rostro</h2>
      </div>
      <span className={enrolled ? 'badge badge-success' : 'badge badge-warning'}>
        {enrolled ? 'ENROLADO' : 'PENDIENTE'}
      </span>
    </div>
    <p className="muted">Los rostros pendientes se registran únicamente desde un Terminal Android autorizado.</p>
    {status?.face_enrolled_at && <p className="muted">Registrado: {new Date(status.face_enrolled_at).toLocaleString()}</p>}
    {enrolled && hasPermission('empleados.biometria_invitar') && <button className="button secondary" type="button" disabled={busy} onClick={reset}>
      {busy ? 'Eliminando…' : 'Eliminar rostro'}
    </button>}
    {error && <p className="form-error">{error}</p>}
  </section>;
}
