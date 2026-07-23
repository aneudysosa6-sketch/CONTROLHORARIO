import { useEffect, useState } from 'react';
import { Building2, Eye, EyeOff, LockKeyhole, ShieldCheck } from 'lucide-react';
import { Navigate, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { getSupabaseClient } from '../infrastructure/supabase/client';
import { userProvisioningService } from '../modules/userProvisioning/userProvisioningService';
import { BrandMark } from '../components/BrandMark';

const timezone = 'America/Santo_Domingo' as const;
const errorMessage = (error: unknown) => error instanceof Error ? error.message : 'No fue posible completar el bootstrap.';

export function BootstrapPage() {
  const { session, loading: authLoading, refresh, logout } = useAuth();
  const navigate = useNavigate();
  const [checking, setChecking] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [companyName, setCompanyName] = useState('');
  const [legalName, setLegalName] = useState('');
  const [slug, setSlug] = useState('');
  const [fullName, setFullName] = useState('');
  const [branchName, setBranchName] = useState('Sucursal principal');
  const [secret, setSecret] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const supabase = getSupabaseClient();
        const { data: { session: authSession }, error: sessionError } = await supabase.auth.getSession();
        if (sessionError) throw sessionError;
        if (!active || !authSession) return;
        setEmail(authSession.user.email ?? '');
        const { data: profile, error: profileError } = await supabase.from('profiles').select('id').eq('id', authSession.user.id).maybeSingle();
        if (profileError) throw profileError;
        if (profile) {
          await refresh();
          if (active) navigate('/dashboard', { replace: true });
          return;
        }
        setAuthenticated(true);
      } catch (caught) {
        if (active) setError(errorMessage(caught));
      } finally {
        if (active) setChecking(false);
      }
    })();
    return () => { active = false; };
  }, [navigate, refresh]);

  if (session) return <Navigate to="/dashboard" replace />;
  if (authLoading || checking) return <div className="empty">Verificando estado del bootstrap…</div>;

  async function signIn(event: React.FormEvent) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const supabase = getSupabaseClient();
      const { data, error: loginError } = await supabase.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
      if (loginError) throw loginError;
      if (!data.session) throw new Error('Supabase no devolvió una sesión válida.');
      setEmail(data.session.user.email ?? email.trim().toLowerCase());
      const { data: profile, error: profileError } = await supabase.from('profiles').select('id').eq('id', data.session.user.id).maybeSingle();
      if (profileError) throw profileError;
      if (profile) {
        await refresh();
        navigate('/dashboard', { replace: true });
        return;
      }
      setAuthenticated(true);
    } catch (caught) {
      setError(errorMessage(caught));
    } finally {
      setBusy(false);
    }
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError('');
    const normalizedSlug = slug.trim().toLowerCase();
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(normalizedSlug)) {
      setError('El slug solo puede contener letras minúsculas, números y guiones simples.');
      return;
    }
    setBusy(true);
    let loginCompleted = false;
    try {
      const supabase = getSupabaseClient();
      const { data: loginData, error: loginError } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      });
      if (loginError) throw loginError;
      if (!loginData.session) throw new Error('Supabase no devolvió una sesión válida para ejecutar el bootstrap.');
      loginCompleted = true;
      await userProvisioningService.bootstrap({
        company_name: companyName.trim(),
        legal_name: legalName.trim(),
        company_slug: normalizedSlug,
        full_name: fullName.trim(),
        email: email.trim().toLowerCase(),
        branch_name: branchName.trim(),
        timezone,
      }, secret);
      setSecret('');
      await logout();
      navigate('/login', { replace: true });
    } catch (caught) {
      setSecret('');
      if (loginCompleted) await logout().catch(() => undefined);
      setError(errorMessage(caught));
    } finally {
      setBusy(false);
    }
  }

  return <div className="bootstrap-page">
    <header className="bootstrap-brand"><BrandMark/><div><b>OSINET</b><small>BOOTSTRAP SEGURO</small></div></header>
    <main className="bootstrap-shell">
      <section className="bootstrap-intro"><span className="eyebrow">CONTROLHORARIO-PROD</span><h1>Activa el primer<br /><em>administrador.</em></h1><p>Este proceso crea la empresa, la sucursal principal y el profile administrativo mediante la Edge Function protegida.</p><div className="bootstrap-security"><ShieldCheck /><span><b>Sin credenciales privilegiadas en el navegador</b><small>El secreto temporal vive solo en este formulario y se descarta después del intento.</small></span></div></section>
      {authenticated ? <form className="bootstrap-card" onSubmit={submit}>
        <div className="bootstrap-title"><Building2 /><div><h2>Configuración inicial</h2><p>Sesión Auth: {email}</p></div></div>
        <div className="bootstrap-grid">
          <label>Nombre de empresa<input required maxLength={120} value={companyName} onChange={e => setCompanyName(e.target.value)} /></label>
          <label>Razón social<input required maxLength={160} value={legalName} onChange={e => setLegalName(e.target.value)} /></label>
          <label>Slug<input required maxLength={63} placeholder="mi-empresa" value={slug} onChange={e => setSlug(e.target.value.toLowerCase())} /></label>
          <label>Nombre completo del administrador<input required maxLength={160} autoComplete="name" value={fullName} onChange={e => setFullName(e.target.value)} /></label>
          <label>Correo<input readOnly type="email" value={email} /></label>
          <label>Sucursal principal<input required maxLength={120} value={branchName} onChange={e => setBranchName(e.target.value)} /></label>
          <label>Código de empleado<input readOnly value="Asignado automáticamente" /><small>Formato: 6 dígitos</small></label>
          <label>Zona horaria<input readOnly value={timezone} /></label>
          <label className="bootstrap-secret">Contraseña de la cuenta Auth<input required type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} /></label>
          <label className="bootstrap-secret">Secreto temporal de bootstrap<input required type="password" autoComplete="off" value={secret} onChange={e => setSecret(e.target.value)} /></label>
        </div>
        {error && <div className="error" role="alert">{error}</div>}
        <button className="primary full" disabled={busy}>{busy ? 'Creando entorno…' : 'Completar bootstrap seguro'}</button>
      </form> : <form className="bootstrap-card bootstrap-login" onSubmit={signIn}>
        <div className="bootstrap-title"><LockKeyhole /><div><h2>Identifica al primer usuario</h2><p>Inicia sesión con la cuenta ya creada en Supabase Auth.</p></div></div>
        <label>Correo<input required type="email" autoComplete="username" value={email} onChange={e => setEmail(e.target.value)} /></label>
        <label>Contraseña<div className="password"><input required type={showPassword ? 'text' : 'password'} autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} /><button type="button" onClick={() => setShowPassword(!showPassword)} aria-label={showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'}>{showPassword ? <EyeOff /> : <Eye />}</button></div></label>
        {error && <div className="error" role="alert">{error}</div>}
        <button className="primary full" disabled={busy}><LockKeyhole />{busy ? 'Validando…' : 'Iniciar sesión para continuar'}</button>
      </form>}
    </main>
  </div>;
}
