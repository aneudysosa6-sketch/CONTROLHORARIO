import { useEffect, useMemo, useRef, useState, type FormEvent, type KeyboardEvent as ReactKeyboardEvent, type RefObject } from 'react';
import { ArrowLeft, Edit3, KeyRound, Plus, Power, Search, Trash2, X } from 'lucide-react';
import { Link, Navigate, useLocation, useNavigate, useParams } from 'react-router-dom';
import { Badge, Empty, PageHeader, Toast } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { administrationService, type AuditEvent } from '../modules/administration/administrationService';
import {
  type AccessRecord,
  type AccessMutationResult,
  type AccessStatus,
  type AccessesState,
  type ManagedAccessStatus,
  type SupervisorScopeState,
  UserProvisioningError,
  userProvisioningService,
} from '../modules/userProvisioning/userProvisioningService';
import {
  activeDepartmentsForBranch,
  buildSupervisorScopeRequest,
  changeSupervisorBranch,
  isSupervisorCanonicalRole,
  selectAllActiveDepartmentIds,
  toggleDepartmentSelection,
} from '../modules/userProvisioning/supervisorScopePolicy';

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

function provisioningFailureMessage(failure: unknown, fallback: string) {
  if (!(failure instanceof UserProvisioningError)) {
    return failure instanceof Error ? failure.message : fallback;
  }
  const recovery = failure.recoveryStatus === 'auth_cleanup_pending'
    ? ' La identidad Auth requiere limpieza; no reintentes con otro correo.'
    : failure.recoveryStatus === 'auth_compensated'
      ? ' La identidad Auth creada fue compensada; puedes corregir y reintentar.'
      : failure.recoveryStatus === 'auth_restored'
        ? ' Los datos de Auth anteriores fueron restaurados; puedes corregir y reintentar.'
      : failure.recoveryStatus === 'auth_restore_pending'
        ? ' La restauración de Auth quedó pendiente; solicita revisión antes de reintentar.'
        : '';
  const request = failure.requestId ? ` Solicitud: ${failure.requestId}.` : '';
  return `${failure.message}.${recovery}${request}`.replace('..', '.');
}

function accessMutationMessage(result: AccessMutationResult, success: string) {
  const request = result.requestId ? ` Solicitud: ${result.requestId}.` : '';
  const pending = [
    result.auth_status_sync === 'pending'
      ? 'La base de datos quedó actualizada, pero la sincronización de Auth está pendiente.'
      : '',
    result.audit_sync === 'pending'
      ? 'El registro complementario de auditoría quedó pendiente.'
      : '',
  ].filter(Boolean).join(' ');
  return pending ? `${success} ${pending}${request}` : success;
}

function scopeValidationMessage(code: string) {
  if (code === 'ROLE_CANONICAL_REQUIRED') return 'No se recibió la clasificación canónica del rol.';
  if (code === 'SUPERVISOR_BRANCH_REQUIRED') return 'Selecciona una sucursal supervisada.';
  if (code === 'SIN_DEPARTAMENTOS') return 'SIN_DEPARTAMENTOS: selecciona al menos un departamento.';
  return 'La selección contiene departamentos inactivos o de otra sucursal.';
}

function SupervisorScopeFields({
  data,
  loading,
  loadError,
  needsReconciliation,
  branchId,
  departmentIds,
  disabled,
  onBranchChange,
  onToggleDepartment,
  onSelectAll,
  onClear,
  onRetry,
}: {
  data: SupervisorScopeState | null;
  loading: boolean;
  loadError: string;
  needsReconciliation: boolean;
  branchId: string;
  departmentIds: string[];
  disabled: boolean;
  onBranchChange: (branchId: string) => void;
  onToggleDepartment: (departmentId: string, selected: boolean) => void;
  onSelectAll: () => void;
  onClear: () => void;
  onRetry: () => void;
}) {
  const departments = activeDepartmentsForBranch(data?.departments ?? [], branchId);
  const visibleSelectedCount = departmentIds.filter((id) => departments.some((item) => item.id === id)).length;
  return <fieldset className="access-scope" disabled={disabled && !loadError}>
    <legend>Alcance del supervisor</legend>
    <p className="access-scope-help">El acceso queda limitado exclusivamente a los departamentos seleccionados.</p>
    {loading && <div className="access-scope-state" role="status">Cargando sucursales y departamentos…</div>}
    {loadError && <div className="error access-scope-state" role="alert">{loadError}<button type="button" className="secondary" onClick={onRetry}>Reintentar</button></div>}
    {needsReconciliation && <div className="error access-scope-state" role="alert">Las asignaciones existentes abarcan varias sucursales o incluyen datos inactivos. Selecciona conscientemente una sucursal y su nuevo conjunto de departamentos.</div>}
    {!loading && !loadError && <>
      <label>Sucursal supervisada
        <select value={branchId} onChange={(event) => onBranchChange(event.target.value)} required>
          <option value="">Seleccionar sucursal</option>
          {(data?.branches ?? []).map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}
        </select>
      </label>
      {!data?.branches.length && <div className="access-empty-note">No hay sucursales activas disponibles.</div>}
      <fieldset className="access-departments" disabled={!branchId}>
        <legend>Departamentos supervisados</legend>
        <div className="access-scope-toolbar">
          <span aria-live="polite">{visibleSelectedCount} {visibleSelectedCount === 1 ? 'departamento seleccionado' : 'departamentos seleccionados'}</span>
          <div className="button-row">
            <button type="button" className="secondary" disabled={!departments.length} onClick={onSelectAll}>Seleccionar todos</button>
            <button type="button" className="secondary" disabled={!departmentIds.length} onClick={onClear}>Limpiar</button>
          </div>
        </div>
        {!branchId && <div className="access-scope-state">Selecciona una sucursal para ver sus departamentos.</div>}
        {branchId && !departments.length && <div className="access-empty-note">Esta sucursal no tiene departamentos activos.</div>}
        {!!departments.length && <div className="access-department-list">
          {departments.map((department) => <label className="access-department-option" key={department.id}>
            <input
              type="checkbox"
              checked={departmentIds.includes(department.id)}
              onChange={(event) => onToggleDepartment(department.id, event.target.checked)}
            />
            <span>{department.name}</span>
          </label>)}
        </div>}
      </fieldset>
    </>}
  </fieldset>;
}

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
  const [creating, setCreating] = useState(false);
  const [newEmployeeId, setNewEmployeeId] = useState('');
  const [newUsername, setNewUsername] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newRoleId, setNewRoleId] = useState('');
  const [newStatus, setNewStatus] = useState<ManagedAccessStatus>('active');
  const [createError, setCreateError] = useState('');
  const [createIdempotencyKey, setCreateIdempotencyKey] = useState('');
  const createDialogRef = useRef<HTMLFormElement>(null);
  const createReturnFocusRef = useRef<HTMLElement | null>(null);
  const [supervisorScope, setSupervisorScope] = useState<SupervisorScopeState | null>(null);
  const [scopeLoading, setScopeLoading] = useState(false);
  const [scopeLoadError, setScopeLoadError] = useState('');
  const [scopeNeedsReconciliation, setScopeNeedsReconciliation] = useState(false);
  const [supervisorBranchId, setSupervisorBranchId] = useState('');
  const [supervisorDepartmentIds, setSupervisorDepartmentIds] = useState<string[]>([]);
  const scopeRequestVersionRef = useRef(0);

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
  const roleCodeFor = (selectedRoleId: string) => catalog.roles.find((role) => role.id === selectedRoleId)?.role_code_canonical;
  const editRoleCodeCanonical = roleCodeFor(roleId);
  const createRoleCodeCanonical = roleCodeFor(newRoleId);
  const editIsSupervisor = isSupervisorCanonicalRole(editRoleCodeCanonical);
  const createIsSupervisor = isSupervisorCanonicalRole(createRoleCodeCanonical);

  async function loadSupervisorScope(profileId?: string) {
    const requestVersion = ++scopeRequestVersionRef.current;
    setScopeLoading(true);
    setScopeLoadError('');
    try {
      const data = await userProvisioningService.getSupervisorScope(profileId);
      if (requestVersion !== scopeRequestVersionRef.current) return;
      const selectedBranch = data.scope.branch_id ?? '';
      const allowed = new Set(
        activeDepartmentsForBranch(data.departments, selectedBranch).map((department) => department.id),
      );
      setSupervisorScope(data);
      setSupervisorBranchId(selectedBranch);
      setSupervisorDepartmentIds(data.scope.department_ids.filter((departmentId) => allowed.has(departmentId)));
      setScopeNeedsReconciliation(data.scope.requires_reconciliation);
    } catch (failure) {
      if (requestVersion !== scopeRequestVersionRef.current) return;
      setScopeLoadError(provisioningFailureMessage(failure, 'No fue posible cargar el alcance del supervisor.'));
    } finally {
      if (requestVersion === scopeRequestVersionRef.current) setScopeLoading(false);
    }
  }

  useEffect(() => {
    if (!access) return;
    setEmployeeId(access.employee_id ?? '');
    setUsername(access.username || access.email || '');
    setRoleId(access.role_id);
    setStatus(access.status === 'invited' ? 'active' : access.status);
  }, [access?.id]);

  useEffect(() => {
    if (mode !== 'edit' || !access || !editIsSupervisor) return;
    if (supervisorScope?.scope.profile_id === access.id) return;
    void loadSupervisorScope(access.id);
  }, [mode, access?.id, editIsSupervisor]);

  useEffect(() => {
    if (!creating || !createIsSupervisor || supervisorScope || scopeLoading) return;
    void loadSupervisorScope();
  }, [creating, createIsSupervisor]);

  useEffect(() => {
    const scopeIsRelevant = (mode === 'edit' && editIsSupervisor) || (creating && createIsSupervisor);
    if (scopeIsRelevant) return;
    scopeRequestVersionRef.current += 1;
    setScopeLoading(false);
    setSupervisorScope(null);
    setScopeLoadError('');
    setScopeNeedsReconciliation(false);
    setSupervisorBranchId('');
    setSupervisorDepartmentIds([]);
  }, [mode, creating, editIsSupervisor, createIsSupervisor]);

  function changeScopeBranch(nextBranchId: string) {
    const next = changeSupervisorBranch(
      { branchId: supervisorBranchId, departmentIds: supervisorDepartmentIds },
      nextBranchId,
    );
    setSupervisorBranchId(next.branchId);
    setSupervisorDepartmentIds([...next.departmentIds]);
    setScopeNeedsReconciliation(false);
  }

  function toggleScopeDepartment(departmentId: string, selected: boolean) {
    setSupervisorDepartmentIds((current) => toggleDepartmentSelection(current, departmentId, selected));
    setScopeNeedsReconciliation(false);
  }

  function selectAllScopeDepartments() {
    setSupervisorDepartmentIds(selectAllActiveDepartmentIds(supervisorScope?.departments ?? [], supervisorBranchId));
    setScopeNeedsReconciliation(false);
  }

  function clearScopeDepartments() {
    setSupervisorDepartmentIds([]);
    setScopeNeedsReconciliation(false);
  }

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

  async function run<T>(action: () => Promise<T>, success: string | ((result: T) => string)) {
    setBusy(true);
    setError('');
    try {
      const result = await action();
      setMessage(typeof success === 'function' ? success(result) : success);
      await load();
      return result;
    } catch (failure) {
      setError(provisioningFailureMessage(failure, 'No fue posible completar la operación.'));
      return null;
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
      (result) => accessMutationMessage(result, next === 'active' ? 'Acceso activado.' : 'Acceso desactivado.'),
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
      const result = await userProvisioningService.updateAccessPassword(passwordTarget.id, password);
      setMessage(result.audit_sync === 'pending'
        ? `Contraseña actualizada, pero su auditoría quedó pendiente.${result.requestId ? ` Solicitud: ${result.requestId}.` : ''}`
        : 'Contraseña actualizada.');
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

  function trapDialogFocus(
    event: ReactKeyboardEvent<HTMLFormElement>,
    dialogRef: RefObject<HTMLFormElement | null>,
    close: () => void,
  ) {
    if (event.key === 'Escape') {
      event.preventDefault();
      close();
      return;
    }
    if (event.key !== 'Tab') return;
    const focusable = [...(dialogRef.current?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [href], [tabindex]:not([tabindex="-1"])') ?? [])]
      .filter((element) => !element.closest('fieldset:disabled'));
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
    if (!access.role_code_canonical || !editRoleCodeCanonical) {
      setError('No se recibió la clasificación canónica del rol. Actualiza el backend antes de editar este acceso.');
      return;
    }
    if (isSupervisorCanonicalRole(access.role_code_canonical) && !editIsSupervisor) {
      const confirmed = window.confirm('Al cambiar este acceso a otro rol se eliminarán sus asignaciones de supervisor. ¿Deseas continuar?');
      if (!confirmed) return;
    }
    if (editIsSupervisor && status !== 'active') {
      setError('El alcance solo puede guardarse para un perfil supervisor activo. Usa el control de estado para desactivar el acceso.');
      return;
    }

    const scopeResult = buildSupervisorScopeRequest(
      editRoleCodeCanonical,
      { branchId: supervisorBranchId, departmentIds: supervisorDepartmentIds },
      supervisorScope?.departments ?? [],
    );
    if (editIsSupervisor && (scopeLoading || scopeLoadError || scopeNeedsReconciliation || !supervisorScope)) {
      setError(scopeLoadError || 'Completa o reconcilia el alcance del supervisor antes de guardar.');
      return;
    }
    if (!scopeResult.ok) {
      setError(scopeValidationMessage(scopeResult.error));
      return;
    }
    const saved = await run(
      () => userProvisioningService.updateAccess({
        profile_id: access.id,
        employee_id: employeeId,
        username: normalizedUsername,
        role_id: roleId,
        status,
        ...(scopeResult.scope ?? {}),
      }),
      (result) => accessMutationMessage(result, 'Acceso actualizado.'),
    );
    if (saved) {
      navigate('/accesos', { state: { message: accessMutationMessage(saved, 'Acceso actualizado.') } });
    }
  }

  function openCreateDialog(trigger: HTMLElement) {
    scopeRequestVersionRef.current += 1;
    createReturnFocusRef.current = trigger;
    setNewEmployeeId('');
    setNewUsername('');
    setNewPassword('');
    setNewRoleId('');
    setNewStatus('active');
    setCreateError('');
    setCreateIdempotencyKey(crypto.randomUUID());
    setSupervisorScope(null);
    setScopeLoadError('');
    setScopeNeedsReconciliation(false);
    setSupervisorBranchId('');
    setSupervisorDepartmentIds([]);
    setCreating(true);
  }

  function closeCreateDialog() {
    if (busy) return;
    scopeRequestVersionRef.current += 1;
    setCreating(false);
    setCreateError('');
    setCreateIdempotencyKey('');
    setSupervisorScope(null);
    setScopeLoadError('');
    setScopeNeedsReconciliation(false);
    setSupervisorBranchId('');
    setSupervisorDepartmentIds([]);
    window.requestAnimationFrame(() => createReturnFocusRef.current?.focus());
  }

  async function createAccess(event: FormEvent) {
    event.preventDefault();
    const normalizedUsername = newUsername.trim().toLowerCase();
    if (!newEmployeeId || !normalizedUsername || !newPassword || !newRoleId || !newStatus) {
      setCreateError('Empleado, usuario, contraseña, rol y estado son obligatorios.');
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedUsername)) {
      setCreateError('El usuario debe ser un correo válido para Supabase Auth.');
      return;
    }
    if (newPassword.length < 8) {
      setCreateError('La contraseña debe contener al menos 8 caracteres.');
      return;
    }
    if (!createRoleCodeCanonical) {
      setCreateError('No se recibió la clasificación canónica del rol. Actualiza el backend antes de crear accesos.');
      return;
    }
    if (createIsSupervisor && newStatus !== 'active') {
      setCreateError('Un acceso supervisor debe crearse activo para poder guardar su alcance.');
      return;
    }
    const scopeResult = buildSupervisorScopeRequest(
      createRoleCodeCanonical,
      { branchId: supervisorBranchId, departmentIds: supervisorDepartmentIds },
      supervisorScope?.departments ?? [],
    );
    if (createIsSupervisor && (scopeLoading || scopeLoadError || scopeNeedsReconciliation || !supervisorScope)) {
      setCreateError(scopeLoadError || 'Completa el alcance del supervisor antes de crear el usuario.');
      return;
    }
    if (!scopeResult.ok) {
      setCreateError(scopeValidationMessage(scopeResult.error));
      return;
    }
    const idempotencyKey = createIdempotencyKey || crypto.randomUUID();
    if (!createIdempotencyKey) setCreateIdempotencyKey(idempotencyKey);
    setBusy(true);
    setCreateError('');
    try {
      const result = await userProvisioningService.createAccess({
        employee_id: newEmployeeId,
        username: normalizedUsername,
        password: newPassword,
        role_id: newRoleId,
        status: newStatus,
        idempotency_key: idempotencyKey,
        ...(scopeResult.scope ?? {}),
      });
      setCreating(false);
      setCreateIdempotencyKey('');
      setSupervisorScope(null);
      setMessage(accessMutationMessage(result, 'Usuario creado correctamente.'));
      window.requestAnimationFrame(() => createReturnFocusRef.current?.focus());
      await load();
    } catch (failure) {
      setCreateError(provisioningFailureMessage(failure, 'No fue posible crear el usuario.'));
    } finally {
      setBusy(false);
    }
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
    const editScopeValid = buildSupervisorScopeRequest(
      editRoleCodeCanonical,
      { branchId: supervisorBranchId, departmentIds: supervisorDepartmentIds },
      supervisorScope?.departments ?? [],
    ).ok;
    const editScopeBlocked = editIsSupervisor && (
      status !== 'active' || scopeLoading || Boolean(scopeLoadError) || scopeNeedsReconciliation || !supervisorScope || !editScopeValid
    );
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
          {editIsSupervisor && status !== 'active' && <div className="error" role="alert">El alcance solo puede guardarse para un supervisor activo. Para desactivarlo sin editar el alcance, usa el control de estado del listado.</div>}
          {editIsSupervisor && <SupervisorScopeFields
            data={supervisorScope}
            loading={scopeLoading}
            loadError={scopeLoadError}
            needsReconciliation={scopeNeedsReconciliation}
            branchId={supervisorBranchId}
            departmentIds={supervisorDepartmentIds}
            disabled={busy || scopeLoading}
            onBranchChange={changeScopeBranch}
            onToggleDepartment={toggleScopeDepartment}
            onSelectAll={selectAllScopeDepartments}
            onClear={clearScopeDepartments}
            onRetry={() => void loadSupervisorScope(access.id)}
          />}
        </div>
        <div className="form-actions"><button className="primary" disabled={busy || editScopeBlocked}>{busy ? 'Guardando…' : 'Guardar cambios'}</button></div>
      </form>
    </>;
  }

  return <>
    <PageHeader
      eyebrow="IDENTIDAD Y SEGURIDAD"
      title="Accesos"
      description="Credenciales vinculadas a empleados, roles y estados de Supabase Auth."
      action={canCreate ? <button type="button" className="primary" onClick={(event) => openCreateDialog(event.currentTarget)}><Plus />Crear usuario</button> : undefined}
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
      <form ref={passwordDialogRef} className="panel access-dialog" role="dialog" aria-modal="true" aria-labelledby="access-password-title" aria-describedby="access-password-description" onKeyDown={(event) => trapDialogFocus(event, passwordDialogRef, closePasswordDialog)} onSubmit={changePassword}>
        <div className="panel-title"><div><span className="eyebrow">SEGURIDAD</span><h2 id="access-password-title">Cambiar contraseña</h2><p id="access-password-description">{passwordTarget.username} · {employeeName(passwordTarget)}</p></div><button type="button" className="icon" aria-label="Cerrar diálogo" onClick={closePasswordDialog}><X /></button></div>
        {passwordError && <div className="error" role="alert">{passwordError}</div>}
        <label>Nueva contraseña<input autoFocus type="password" autoComplete="new-password" minLength={8} value={password} onChange={(event) => setPassword(event.target.value)} required /></label>
        <div className="button-row"><button type="button" className="secondary" onClick={closePasswordDialog}>Cancelar</button><button className="primary" disabled={busy}>{busy ? 'Actualizando…' : 'Cambiar contraseña'}</button></div>
      </form>
    </div>}
    {creating && <div className="access-dialog-backdrop" role="presentation">
      <form ref={createDialogRef} className="panel access-dialog access-dialog-wide" role="dialog" aria-modal="true" aria-labelledby="create-user-title" onKeyDown={(event) => trapDialogFocus(event, createDialogRef, closeCreateDialog)} onSubmit={createAccess}>
        <div className="panel-title"><div><span className="eyebrow">USUARIOS</span><h2 id="create-user-title">Crear usuario</h2><p>Vincula un empleado, un rol y sus credenciales desde este módulo.</p></div><button type="button" className="icon" aria-label="Cerrar diálogo" disabled={busy} onClick={closeCreateDialog}><X /></button></div>
        {createError && <div className="error" role="alert">{createError}</div>}
        <div className="form-grid access-form-grid">
          <label>Empleado
            <select value={newEmployeeId} onChange={(event) => setNewEmployeeId(event.target.value)} required>
              <option value="">Seleccionar empleado</option>
              {catalog.employees.filter((employee) => !employee.perfil_id).map((employee) => <option key={employee.id} value={employee.id}>{employee.codigo_empleado} · {employee.nombre_completo}</option>)}
            </select>
          </label>
          <label>Usuario
            <input autoFocus type="email" autoComplete="username" value={newUsername} onChange={(event) => setNewUsername(event.target.value)} placeholder="usuario@empresa.com" required />
          </label>
          <label>Contraseña
            <input type="password" autoComplete="new-password" minLength={8} value={newPassword} onChange={(event) => setNewPassword(event.target.value)} required />
          </label>
          <label>Rol
            <select value={newRoleId} onChange={(event) => setNewRoleId(event.target.value)} required>
              <option value="">Seleccionar rol</option>
              {catalog.roles.map((role) => <option key={role.id} value={role.id}>{role.name}</option>)}
            </select>
          </label>
          <label>Estado
            <select value={newStatus} onChange={(event) => setNewStatus(event.target.value as ManagedAccessStatus)} required>
              <option value="active">Activo</option><option value="inactive">Inactivo</option><option value="suspended">Suspendido</option>
            </select>
          </label>
          {createIsSupervisor && newStatus !== 'active' && <div className="error" role="alert">Un acceso supervisor debe crearse activo para guardar su alcance.</div>}
          {createIsSupervisor && <SupervisorScopeFields
            data={supervisorScope}
            loading={scopeLoading}
            loadError={scopeLoadError}
            needsReconciliation={scopeNeedsReconciliation}
            branchId={supervisorBranchId}
            departmentIds={supervisorDepartmentIds}
            disabled={busy || scopeLoading}
            onBranchChange={changeScopeBranch}
            onToggleDepartment={toggleScopeDepartment}
            onSelectAll={selectAllScopeDepartments}
            onClear={clearScopeDepartments}
            onRetry={() => void loadSupervisorScope()}
          />}
        </div>
        {!catalog.employees.some((employee) => !employee.perfil_id) && <div className="access-empty-note">No hay empleados activos sin usuario. Crea o libera un empleado antes de continuar.</div>}
        <div className="button-row"><button type="button" className="secondary" disabled={busy} onClick={closeCreateDialog}>Cancelar</button><button className="primary" disabled={busy || !catalog.employees.some((employee) => !employee.perfil_id) || (createIsSupervisor && (newStatus !== 'active' || scopeLoading || Boolean(scopeLoadError) || scopeNeedsReconciliation || !supervisorScope || !buildSupervisorScopeRequest(createRoleCodeCanonical, { branchId: supervisorBranchId, departmentIds: supervisorDepartmentIds }, supervisorScope?.departments ?? []).ok))}>{busy ? 'Creando…' : 'Crear usuario'}</button></div>
      </form>
    </div>}
    <Toast message={message} />
  </>;
}
