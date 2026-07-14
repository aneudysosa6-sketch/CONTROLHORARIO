import { useEffect, useState } from 'react';
import { Eye, EyeOff, LockKeyhole, Mail, ShieldCheck } from 'lucide-react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { userProvisioningService } from '../modules/userProvisioning/userProvisioningService';

export function LoginPage() {
  const { session, loading, error: authError, login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [checkingBootstrap, setCheckingBootstrap] = useState(true);

  useEffect(() => {
    let active = true;
    userProvisioningService.bootstrapStatus()
      .then(({ bootstrap_required }) => {
        if (active && bootstrap_required) navigate('/bootstrap', { replace: true });
      })
      .catch(caught => {
        if (active) setError(caught instanceof Error ? caught.message : 'No fue posible verificar el estado inicial.');
      })
      .finally(() => { if (active) setCheckingBootstrap(false); });
    return () => { active = false; };
  }, [navigate]);

  if (loading || checkingBootstrap) return <div className="premium-login-loading"><span className="premium-spinner"/><b>OSINET</b><small>Preparando acceso seguro…</small></div>;
  if (session) return <Navigate to={['employee','empleado'].includes(session.roleCode) ? '/mi-portal' : '/dashboard'} replace />;

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError('');
    if (!email.trim() || !password) {
      setError('Completa correo y contraseña.');
      return;
    }
    setBusy(true);
    try {
      await login(email.trim().toLowerCase(), password);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'No fue posible iniciar sesión.');
    } finally {
      setBusy(false);
    }
  }

  return <div className="premium-login-page">
    <div className="premium-login-ambient" aria-hidden="true" />
    <section className="premium-login-shell">
      <div className="neon-orbits" aria-hidden="true">
        <i className="neon-orbit orbit-blue"/><i className="neon-orbit orbit-green"/><i className="neon-orbit orbit-amber"/>
      </div>
      <form className="premium-login-card" onSubmit={submit}>
        <div className="premium-login-logo"><span>O</span><div><b>OSINET</b><small>CONTROLHORARIO</small></div></div>
        <div className="premium-login-heading"><span><ShieldCheck size={14}/> ACCESO EMPRESARIAL</span><h1>Bienvenido</h1><p>Administra el tiempo de tu equipo con precisión.</p></div>
        <label>Usuario / Correo<div className="premium-field"><Mail/><input type="email" value={email} onChange={event => setEmail(event.target.value)} autoComplete="username" placeholder="nombre@empresa.com" /></div></label>
        <label>Contraseña<div className="premium-field"><LockKeyhole/><input type={show ? 'text' : 'password'} value={password} onChange={event => setPassword(event.target.value)} autoComplete="current-password" placeholder="Tu contraseña"/><button type="button" onClick={() => setShow(!show)} aria-label={show ? 'Ocultar contraseña' : 'Mostrar contraseña'}>{show ? <EyeOff /> : <Eye />}</button></div></label>
        {(error || authError) && <div className="premium-login-error" role="alert">{error || authError}</div>}
        <button className="premium-login-submit" disabled={busy}>{busy ? <><span className="button-spinner"/>Validando acceso…</> : <><LockKeyhole size={18}/>Iniciar sesión</>}</button>
        <Link className="premium-login-link" to="/recuperar-password">¿Olvidaste tu contraseña?</Link>
        <footer><span/>Protegido por Supabase Auth<span/></footer>
      </form>
    </section>
  </div>;
}
