import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { ArrowLeft, KeyRound, Save } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { Empty, PageHeader } from '../components/UI';
import {
  type ManagedAccessStatus,
  type AccessesState,
  userProvisioningService,
} from '../modules/userProvisioning/userProvisioningService';

const empty: AccessesState = { accesses: [], employees: [], roles: [] };

export function UserProvisioningPage() {
  const navigate = useNavigate();
  const [catalog, setCatalog] = useState(empty);
  const [employeeId, setEmployeeId] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [roleId, setRoleId] = useState('');
  const [status, setStatus] = useState<ManagedAccessStatus>('active');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    userProvisioningService.listAccesses()
      .then((data) => { if (active) setCatalog(data); })
      .catch((failure) => {
        if (active) setError(failure instanceof Error ? failure.message : 'No fue posible cargar los datos para crear el acceso.');
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const employees = useMemo(
    () => catalog.employees.filter((employee) => !employee.perfil_id),
    [catalog.employees],
  );

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError('');
    const normalizedUsername = username.trim().toLowerCase();
    if (!employeeId || !normalizedUsername || !password || !roleId || !status) {
      setError('Empleado, usuario, contraseña, rol y estado son obligatorios.');
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedUsername)) {
      setError('El usuario debe ser un correo válido para conservar compatibilidad con Supabase Auth.');
      return;
    }
    if (password.length < 8) {
      setError('La contraseña debe contener al menos 8 caracteres.');
      return;
    }

    setBusy(true);
    try {
      await userProvisioningService.createAccess({
        employee_id: employeeId,
        username: normalizedUsername,
        password,
        role_id: roleId,
        status,
      });
      navigate('/accesos', { replace: true, state: { message: 'Acceso creado correctamente.' } });
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'No fue posible crear el acceso.');
    } finally {
      setBusy(false);
    }
  }

  if (loading) return <Empty text="Cargando empleados y roles…" />;

  return <>
    <PageHeader
      eyebrow="CONTROL DE ACCESOS"
      title="Crear acceso"
      description="La identidad personal y laboral se toma automáticamente del empleado seleccionado."
      action={<Link className="secondary" to="/accesos"><ArrowLeft />Volver</Link>}
    />
    {error && <div className="error" role="alert">{error}</div>}
    <form className="form-panel access-form" onSubmit={submit}>
      <div className="access-form-heading">
        <span className="admin-card-icon"><KeyRound size={22} /></span>
        <div><h2>Credenciales y autorización</h2><p>Un empleado solo puede tener un acceso.</p></div>
      </div>
      <div className="form-grid access-form-grid">
        <label>Empleado
          <select value={employeeId} onChange={(event) => setEmployeeId(event.target.value)} required>
            <option value="">Seleccionar empleado</option>
            {employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.codigo_empleado} · {employee.nombre_completo}</option>)}
          </select>
        </label>
        <label>Usuario
          <input type="email" autoComplete="username" value={username} onChange={(event) => setUsername(event.target.value)} placeholder="usuario@empresa.com" required />
        </label>
        <label>Contraseña
          <input type="password" autoComplete="new-password" minLength={8} value={password} onChange={(event) => setPassword(event.target.value)} required />
        </label>
        <label>Rol
          <select value={roleId} onChange={(event) => setRoleId(event.target.value)} required>
            <option value="">Seleccionar rol</option>
            {catalog.roles.map((role) => <option key={role.id} value={role.id}>{role.name}</option>)}
          </select>
        </label>
        <label>Estado
          <select value={status} onChange={(event) => setStatus(event.target.value as ManagedAccessStatus)} required>
            <option value="active">Activo</option>
            <option value="inactive">Inactivo</option>
            <option value="suspended">Suspendido</option>
          </select>
        </label>
      </div>
      {!employees.length && <div className="access-empty-note">No hay empleados activos sin acceso. Crea o libera un empleado antes de continuar.</div>}
      <div className="form-actions">
        <button className="primary" disabled={busy || !employees.length}><Save />{busy ? 'Creando…' : 'Crear acceso'}</button>
      </div>
    </form>
  </>;
}
