import { useEffect, useState } from 'react';
import { Eye, EyeOff, LockKeyhole } from 'lucide-react';
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

  if (loading || checkingBootstrap) return <div className="empty">Verificando configuración inicial…</div>;
  if (session) return <Navigate to="/dashboard" replace />;

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
      navigate('/dashboard');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'No fue posible iniciar sesión.');
    } finally {
      setBusy(false);
    }
  }

  return <div className="login-page">
    <div className="login-art"><div className="orb" /><div className="login-copy"><span className="eyebrow">CONTROL HORARIO IA</span><h1>El tiempo de tu equipo,<br /><em>bajo control.</em></h1><p>Acceso seguro mediante Supabase Auth y autorización efectiva por perfil.</p><div className="trust">● Sesión cifrada <span>RLS · permisos · alcance empresarial</span></div></div></div>
    <form className="login-card" onSubmit={submit}><div className="login-logo"><span className="brand-mark">O</span><div><b>OSINET</b><small>TIME ERP ENTERPRISE</small></div></div><h2>Bienvenido</h2><p>Ingresa a tu espacio administrativo</p><label>Correo<input type="email" value={email} onChange={event => setEmail(event.target.value)} autoComplete="username" /></label><label>Contraseña<div className="password"><input type={show ? 'text' : 'password'} value={password} onChange={event => setPassword(event.target.value)} autoComplete="current-password" /><button type="button" onClick={() => setShow(!show)} aria-label="Mostrar contraseña">{show ? <EyeOff /> : <Eye />}</button></div></label>{(error || authError) && <div className="error">{error || authError}</div>}<button className="primary full" disabled={busy}><LockKeyhole size={18} />{busy ? 'Validando…' : 'Iniciar sesión'}</button><Link className="auth-link" to="/recuperar-password">¿Olvidaste tu contraseña?</Link></form>
  </div>;
}
