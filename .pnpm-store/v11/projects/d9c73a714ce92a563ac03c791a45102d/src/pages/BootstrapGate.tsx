import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { userProvisioningService } from '../modules/userProvisioning/userProvisioningService';

const messageOf = (error: unknown) => error instanceof Error ? error.message : 'No fue posible verificar la configuración inicial.';

export function BootstrapGate() {
  const navigate = useNavigate();
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);

  const checkBootstrap = useCallback(async () => {
    setError('');
    try {
      const { bootstrap_required } = await userProvisioningService.bootstrapStatus();
      navigate(bootstrap_required ? '/bootstrap' : '/login', { replace: true });
    } catch (caught) {
      setError(messageOf(caught));
    }
  }, [navigate]);

  useEffect(() => { void checkBootstrap(); }, [attempt, checkBootstrap]);

  return <div className="auth-page">
    <div className="auth-card bootstrap-gate" role="status" aria-live="polite">
      <span className="brand-mark">O</span>
      <h1>Preparando OSINET</h1>
      {!error ? <p>Verificando la configuración inicial…</p> : <><div className="error" role="alert">{error}</div><button className="primary full" onClick={() => setAttempt(value => value + 1)}>Reintentar</button></>}
    </div>
  </div>;
}
