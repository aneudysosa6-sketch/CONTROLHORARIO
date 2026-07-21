import { useEffect, useMemo, useRef, useState, type FormEvent, type KeyboardEvent as ReactKeyboardEvent } from 'react';
import { ArrowLeft, Edit3, KeyRound, Plus, Power, Search, Trash2, X } from 'lucide-react';
import { Link, Navigate, useLocation, useNavigate, useParams } from 'react-router-dom';
import { Badge, Empty, PageHeader, Toast } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { administrationService, type AuditEvent } from '../modules/administration/administrationService';
import {
  type AccessRecord,
  type AccessStatus,
  type AccessesState,
  type ManagedAccessStatus,
  userProvisioningService,
} from '../modules/userProvisioning/userProvisioningService';

const empty: AccessesState = { accesses: [], employees: [], roles: [] };
const statusLabel: Record<AccessStatus, string> = {
  active: 'Activo',
  inactive: 'Inactivo',
  suspended: 'Suspendido',
  invited: 'Invitado',
};

function isAdministrator(access: AccessRecord) {
  const value = `${access.role_code ?? ''} ${access.role_name}`
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
  return value.includes('admin');
}

function lastAccess(value: string | null) {
  if (!value) return 'Nunca';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'No disponible';
  return new Intl.DateTimeFormat('es-DO', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
}

const employeeName = (access: AccessRecord) => access.employee_name?.trim() || 'Sin empleado vinculado';
const employeeCode = (access: AccessRecord) => access.employee_code?.trim() || '—';

export function UsersAdministrationPage({
  mode = 'list',
}: {
  mode?: 'list' | 'view' | 'edit' | 'audit';
}) {
  const { id } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const { session, hasPermission } = useAuth();
  const [catalog, setCatalog] = useState(empty);
  const [audit, setAudit] = useState<AuditEvent[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState((location.state as { message?: string } | null)?.message ?? '');
  const [passwordTarget, setPasswordTarget] = useState<AccessRecord | null>(null);
  const [password, setPassword] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const passwordDialogRef = useRef<HTMLFormElement>(null);
  const passwordReturnFocusRef = useRef<HTMLElement | null>(null);
  const [employeeId, setEmployeeId] = useState('');
  const [username, setUsername] = useState('');
  const [roleId, setRoleId] = useState('');
  const [status, setStatus] = useState<ManagedAccessStatus>('active');

  async function load() {
    setLoading(true);
    setError('');
    try {
      const data = await userProvisioningService.listAccesses();
      setCatalog(data);
      if (mode === 'audit' && id) {
        const events = await administrationService.audit();
        setAudit(events.filter((event) => event.entidad_id === id));
      }
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'No fue posible cargar los accesos.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { void load(); }, [id, mode]);

  const access = catalog.accesses.find((item) => item.id === id);
  useEffect(() => {
    if (!access) return;
    setEmployeeId(access.employee_id ?? '');
    setUsername(access.username || access.email || '');
    setRoleId(access.role_id);
    setStatus(access.status === 'invited' ? 'active' : access.status);
  }, [access?.id]);

  const rows = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return catalog.accesses;
    return catalog.accesses.filter((item) =>
      `${item.username} ${item.email ?? ''} ${item.employee_name ?? ''} ${item.employee_code ?? ''} ${item.role_name} ${item.status}`
        .toLowerCase()
        .includes(normalized),
    );
  }, [catalog.accesses, query]);

  const activeAdministratorCount = useMemo(
    () => catalog.accesses.filter((item) => item.status === 'active' && isAdministrator(item)).length,
    [catalog.accesses],
  );
  const canCreate = hasPermission('usuarios.create') || hasPermission('usuarios.administrar');
  const canEdit = hasPermission('usuarios.edit') || hasPermission('usuarios.administrar');
  const canManage = hasPermission('usuarios.administrar');

  async function run(action: () => Promise<unknown>, success: string) {
    setBusy(true);
    setError('');
    try {
      await action();
      setMessage(success);
      await load();
      return true;
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'No fue posible completar la operación.');
      return false;
    } finally {
      setBusy(false);
    }
  }

  async function toggleAccess(item: AccessRecord) {
    const next: ManagedAccessStatus = item.status === 'active' ? 'inactive' : 'active';
    const verb = next === 'active' ? 'activar' : 'desactivar';
    if (!window.confirm(`¿Confirmas ${verb} el acceso de ${employeeName(item)}?`)) return;
    await run(
      () => userProvisioningService.setAccessStatus(item.id, next),
      next === 'active' ? 'Acceso activado.' : 'Acceso desactivado.',
    );
  }

  async function removeAccess(item: AccessRecord) {
    if (item.id === session?.id) {
      setError('No puedes eliminar el acceso de la sesión actual.');
      return;
    }
    if (item.status === 'active' && isAdministrator(item) && activeAdministratorCount <= 1) {
      setError('No se puede eliminar el último administrador.');
      return;
    }
    if (!window.confirm(`¿Eliminar el acceso de ${employeeName(item)}? El empleado y sus datos no serán eliminados.`)) return;
    await run(
      () => userProvisioningService.deleteAccess(item.id),
      'Acceso eliminado. El empleado se conserva.',
    );
  }

  async function changePassword(event: FormEvent) {
    event.preventDefault();
    if (!passwordTarget) return;
    setPasswordError('');
    if (password.length < 8) {
      setPasswordError('La contraseña debe contener al menos 8 caracteres.');
      return;
    }
    setBusy(true);
    try {
      await userProvisioningService.updateAccessPassword(passwordTarget.id, password);
      setMessage('Contraseña actualizada.');
      setPassword('');
      closePasswordDialog();
      await load();
    } catch (failure) {
      setPasswordError(failure instanceof Error ? failure.message : 'No fue posible cambiar la contraseña.');
    } finally {
      setBusy(false);
    }
  }

  function openPasswordDialog(item: AccessRecord, trigger: HTMLElement) {
    passwordReturnFocusRef.current = trigger;
    setPasswordTarget(item);
    setPassword('');
    setPasswordError('');
    setError('');
  }

  function closePasswordDialog() {
    setPasswordTarget(null);
    setPasswordError('');
    window.requestAnimationFrame(() => passwordReturnFocusRef.current?.focus());
  }

  function trapDialogFocus(event: ReactKeyboardEvent<HTMLFormElement>) {
    if (event.key === 'Escape') {
      event.preventDefault();
      closePasswordDialog();
      return;
    }
    if (event.key !== 'Tab') return;
    const focusable = [...(passwordDialogRef.current?.querySelectorAll<HTMLElement>('button:not([disabled]), input:not([disabled]), [href], [tabindex]:not([tabindex="-1"])') ?? [])];
    const first = focusable[0];
    const last = focusable.at(-1);
    if (!first || !last) return;
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  async function saveAccess(event: FormEvent) {
    event.preventDefault();
    if (!access) return;
    const normalizedUsername = username.trim().toLowerCase();
    if (!employeeId || !normalizedUsername || !roleId || !status) {
      setError('Empleado, usuario, rol y estado son obligatorios.');
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedUsername)) {
      setError('El usuario debe ser un correo válido para Supabase Auth.');
      return;
    }
    const saved = await run(
      () => userProvisioningService.updateAccess({
        profile_id: access.id,
        employee_id: employeeId,
        username: normalizedUsername,
        role_id: roleId,
        status,
      }),
      'Acceso actualizado.',
    );
    if (saved) navigate('/accesos');
  }

  if (mode === 'view' && id) return <Navigate to={`/accesos/${id}/editar`} replace />;
  if (loading) return <Empty text="Cargando accesos…" />;

  if (mode === 'audit') {
    return <>
      <PageHeader eyebrow="CONTROL DE ACCESOS" title="Auditoría del acceso" description={access ? `${access.username} · ${employeeName(access)}` : 'Acceso no encontrado'} action={<Link className="secondary" to="/accesos"><ArrowLeft />Volver</Link>} />
      {error && <div className="error" role="alert">{error}</div>}
      <section className="panel">
        {audit.length ? <div className="table-wrap"><table><thead><tr><th>Fecha</th><th>Acción</th><th>Motivo</th></tr></thead><tbody>{audit.map((item) => <tr key={item.id}><td>{lastAccess(item.fecha)}</td><td>{item.accion}</td><td>{item.motivo ?? 'Sin observación'}</td></tr>)}</tbody></table></div> : <Empty text="No hay eventos de auditoría para este acceso." />}
      </section>
    </>;
  }

  if (mode === 'edit') {
    if (!access) return <Empty text="Acceso no encontrado o fuera del alcance autorizado." />;
    const availableEmployees = catalog.employees.filter((employee) => !employee.perfil_id || employee.id === access.employee_id);
    const currentEmployeeMissing = Boolean(access.employee_id) && !availableEmployees.some((employee) => employee.id === access.employee_id);
    return <>
      <PageHeader eyebrow="CONTROL DE ACCESOS" title="Editar acceso" description="Los datos personales continúan vinculados al expediente del empleado." action={<Link className="secondary" to="/accesos"><ArrowLeft />Volver</Link>} />
      {error && <div className="error" role="alert">{error}</div>}
      <form className="form-panel access-form" onSubmit={saveAccess}>
        <div className="form-grid access-form-grid access-edit-grid">
          <label>Empleado
            <select value={employeeId} onChange={(event) => setEmployeeId(event.target.value)} required>
              <option value="">Seleccionar empleado</option>
              {currentEmployeeMissing && <option value={access.employee_id ?? ''}>{employeeCode(access)} · {employeeName(access)}</option>}
              {availableEmployees.map((employee) => <option key={employee.id} value={employee.id}>{employee.codigo_empleado} · {employee.nombre_completo}</option>)}
            </select>
          </label>
          <label>Usuario
            <input type="email" autoComplete="username" value={username} onChange={(event) => setUsername(event.target.value)} required />
          </label>
          <label>Rol
            <select value={roleId} onChange={(event) => setRoleId(event.target.value)} required>
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
        <div className="form-actions"><button className="primary" disabled={busy}>{busy ? 'Guardando…' : 'Guardar cambios'}</button></div>
      </form>
    </>;
  }

  return <>
    <PageHeader
      eyebrow="IDENTIDAD Y SEGURIDAD"
      title="Accesos"
      description="Credenciales vinculadas a empleados, roles y estados de Supabase Auth."
      action={canCreate ? <Link className="primary" to="/accesos/nuevo"><Plus />Nuevo acceso</Link> : undefined}
    />
    {error && <div className="error" role="alert">{error}</div>}
    <div className="toolbar access-toolbar">
      <div className="search"><Search /><input aria-label="Buscar accesos" placeholder="Buscar usuario, empleado o rol" value={query} onChange={(event) => setQuery(event.target.value)} /></div>
      <Badge tone="blue">{rows.length} accesos</Badge>
    </div>
    <section className="table-wrap payroll-wide access-table">
      <table>
        <thead><tr><th>Usuario</th><th>Empleado</th><th>Rol</th><th>Estado</th><th>Último acceso</th><th>Acciones</th></tr></thead>
        <tbody>{rows.map((item) => {
          const isCurrent = item.id === session?.id;
          const isLastAdministrator = item.status === 'active' && isAdministrator(item) && activeAdministratorCount <= 1;
          return <tr key={item.id}>
            <td><b>{item.username || item.email}</b>{isCurrent && <small>Sesión actual</small>}</td>
            <td><div className="employee-cell"><span className="avatar">{item.employee_name?.split(' ').map((part) => part[0]).join('').slice(0, 2).toUpperCase() || '—'}</span><div><b>{employeeName(item)}</b><small>{employeeCode(item)}</small></div></div></td>
            <td>{item.role_name}</td>
            <td><Badge tone={item.status === 'active' ? 'green' : item.status === 'suspended' || item.status === 'invited' ? 'amber' : 'gray'}>{statusLabel[item.status]}</Badge></td>
            <td>{lastAccess(item.last_sign_in_at)}</td>
            <td><div className="access-actions">
              {canEdit ? <Link className="secondary" aria-label={`Editar acceso de ${employeeName(item)}`} to={`/accesos/${item.id}/editar`}><Edit3 />Editar</Link> : <button className="secondary" disabled><Edit3 />Editar</button>}
              <button className="secondary" disabled={!canManage || busy} onClick={(event) => openPasswordDialog(item, event.currentTarget)}><KeyRound />Cambiar contraseña</button>
              <button className="secondary" disabled={!canManage || busy || isCurrent} title={isCurrent ? 'No puedes cambiar el estado de tu sesión actual.' : undefined} onClick={() => void toggleAccess(item)}><Power />{item.status === 'active' ? 'Desactivar' : 'Activar'}</button>
              <button className="secondary danger" disabled={!canManage || busy || isCurrent || isLastAdministrator} title={isCurrent ? 'No puedes eliminar el acceso actual.' : isLastAdministrator ? 'No puedes eliminar el último administrador.' : undefined} onClick={() => void removeAccess(item)}><Trash2 />Eliminar</button>
            </div></td>
          </tr>;
        })}</tbody>
      </table>
      {!rows.length && <Empty text={query ? 'No hay accesos que coincidan con la búsqueda.' : 'No hay accesos registrados.'} />}
    </section>

    {passwordTarget && <div className="access-dialog-backdrop" role="presentation">
      <form ref={passwordDialogRef} className="panel access-dialog" role="dialog" aria-modal="true" aria-labelledby="access-password-title" aria-describedby="access-password-description" onKeyDown={trapDialogFocus} onSubmit={changePassword}>
        <div className="panel-title"><div><span className="eyebrow">SEGURIDAD</span><h2 id="access-password-title">Cambiar contraseña</h2><p id="access-password-description">{passwordTarget.username} · {employeeName(passwordTarget)}</p></div><button type="button" className="icon" aria-label="Cerrar diálogo" onClick={closePasswordDialog}><X /></button></div>
        {passwordError && <div className="error" role="alert">{passwordError}</div>}
        <label>Nueva contraseña<input autoFocus type="password" autoComplete="new-password" minLength={8} value={password} onChange={(event) => setPassword(event.target.value)} required /></label>
        <div className="button-row"><button type="button" className="secondary" onClick={closePasswordDialog}>Cancelar</button><button className="primary" disabled={busy}>{busy ? 'Actualizando…' : 'Cambiar contraseña'}</button></div>
      </form>
    </div>}
    <Toast message={message} />
  </>;
}
