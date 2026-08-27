import { useEffect, useState } from 'react';
import { ArrowLeft, KeyRound, Power, Save, Settings2, Smartphone } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Badge, Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import {
  deviceService,
  type AndroidDevice,
  type DeviceBranch,
  type DeviceDepartment,
  type TerminalUsageType,
} from '../modules/devices/deviceService';

const errorText = (error: unknown) => error instanceof Error ? error.message : 'No fue posible completar la operación.';

export function DevicesPage() {
  const { hasPermission } = useAuth();
  const [items, setItems] = useState<AndroidDevice[]>([]);
  const [branches, setBranches] = useState<DeviceBranch[]>([]);
  const [departments, setDepartments] = useState<DeviceDepartment[]>([]);
  const [branchId, setBranchId] = useState('');
  const [usageType, setUsageType] = useState<TerminalUsageType>('GENERAL');
  const [selectedDepartments, setSelectedDepartments] = useState<string[]>([]);
  const [editingDeviceId, setEditingDeviceId] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [expires, setExpires] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const chooseBranch = async (nextBranchId: string, retainedDepartments: string[] = []) => {
    setBranchId(nextBranchId);
    setSelectedDepartments([]);
    if (!nextBranchId) {
      setDepartments([]);
      return;
    }
    const rows = await deviceService.departments(nextBranchId);
    setDepartments(rows);
    setSelectedDepartments(retainedDepartments.filter((id) => rows.some((row) => row.id === id)));
  };

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const [devices, branchRows] = await Promise.all([deviceService.list(), deviceService.branches()]);
      setItems(devices);
      setBranches(branchRows);
      const selectedBranch = branchId || branchRows[0]?.id || '';
      if (selectedBranch) await chooseBranch(selectedBranch, selectedDepartments);
    } catch (e) {
      setError(errorText(e));
    } finally {
      setLoading(false);
    }
  };
  useEffect(() => { void load(); }, []);

  const configuration = () => ({
    branchId,
    usageType,
    departmentIds: usageType === 'DEPARTMENTS' ? selectedDepartments : [],
  });

  const validate = () => {
    if (!branchId) return 'Selecciona la sucursal física del terminal.';
    if (usageType === 'DEPARTMENTS' && selectedDepartments.length === 0) {
      return 'Selecciona al menos un departamento.';
    }
    return '';
  };

  const createCode = async () => {
    const validation = validate();
    if (validation) { setError(validation); return; }
    setBusy(true);
    setError('');
    try {
      const result = await deviceService.createCode(configuration());
      setCode(result.code);
      setExpires(result.expires_at);
    } catch (e) { setError(errorText(e)); } finally { setBusy(false); }
  };

  const beginEdit = async (item: AndroidDevice) => {
    setEditingDeviceId(item.id);
    setUsageType(item.tipo_uso ?? 'GENERAL');
    await chooseBranch(item.sucursal_id, item.department_ids ?? []);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const saveConfiguration = async () => {
    if (!editingDeviceId) return;
    const validation = validate();
    if (validation) { setError(validation); return; }
    setBusy(true);
    setError('');
    try {
      await deviceService.configure(editingDeviceId, configuration());
      setEditingDeviceId(null);
      await load();
    } catch (e) { setError(errorText(e)); } finally { setBusy(false); }
  };

  const revoke = async (item: AndroidDevice) => {
    if (!confirm(`¿Revocar ${item.nombre}?`)) return;
    try { await deviceService.revoke(item.id); await load(); }
    catch (e) { setError(errorText(e)); }
  };

  const toggleDepartment = (id: string) => {
    setSelectedDepartments((current) => current.includes(id) ? current.filter((value) => value !== id) : [...current, id]);
  };
  const date = (value: string | null) => value ? new Date(value).toLocaleString('es-DO') : 'Sin actividad';
  const branchName = (id: string) => branches.find((branch) => branch.id === id)?.name ?? id;

  return <>
    <PageHeader
      eyebrow="ADMINISTRACIÓN DEL SISTEMA"
      title="Terminales faciales"
      description="La sucursal define la ubicación de marcación; GENERAL reconoce toda la empresa y DEPARTMENTS restringe por departamentos activos."
      action={<Link className="secondary" to="/administracion"><ArrowLeft />Administración</Link>}
    />
    {error && <div className="error">{error}</div>}
    {hasPermission('dispositivos.registrar') && <section className="panel" style={{ marginBottom: 16 }}>
      <h2><Settings2 /> {editingDeviceId ? 'Editar configuración del terminal' : 'Nuevo código de enrolamiento'}</h2>
      <div className="form-grid">
        <label>Sucursal física
          <select value={branchId} onChange={(event) => void chooseBranch(event.target.value)}>
            <option value="">Seleccionar</option>
            {branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}
          </select>
        </label>
        <label>Tipo de uso
          <select value={usageType} onChange={(event) => {
            const next = event.target.value as TerminalUsageType;
            setUsageType(next);
            if (next === 'GENERAL') setSelectedDepartments([]);
          }}>
            <option value="GENERAL">Uso general</option>
            <option value="DEPARTMENTS">Por departamentos</option>
          </select>
        </label>
      </div>
      {usageType === 'DEPARTMENTS' && <div className="panel" style={{ marginTop: 12 }}>
        <b>Departamentos autorizados</b>
        <div className="button-row" style={{ marginTop: 10 }}>
          {departments.map((department) => <label key={department.id} className="secondary" style={{ cursor: 'pointer' }}>
            <input type="checkbox" checked={selectedDepartments.includes(department.id)} onChange={() => toggleDepartment(department.id)} />
            {department.name}
          </label>)}
          {!departments.length && <span className="muted">La sucursal no tiene departamentos activos.</span>}
        </div>
      </div>}
      <div className="button-row" style={{ marginTop: 14 }}>
        {editingDeviceId
          ? <><button className="primary" disabled={busy} onClick={() => void saveConfiguration()}><Save />Guardar configuración</button><button className="secondary" onClick={() => setEditingDeviceId(null)}>Cancelar</button></>
          : <button className="primary" disabled={busy} onClick={() => void createCode()}><KeyRound />{busy ? 'Generando…' : 'Generar código'}</button>}
      </div>
    </section>}
    {code && <section className="panel" style={{ marginBottom: 16 }}>
      <h2>Código de enrolamiento</h2>
      <p>Úsalo únicamente en el terminal autorizado. Se muestra una sola vez y vence a las {new Date(expires).toLocaleTimeString('es-DO')}.</p>
      <strong style={{ fontSize: 28, letterSpacing: 4 }}>{code}</strong>
      <button className="secondary" onClick={() => setCode('')}>Ocultar</button>
    </section>}
    <section className="table-wrap"><table><thead><tr><th>Dispositivo</th><th>Configuración</th><th>Versiones</th><th>Última conexión</th><th>Última sincronización</th><th>Estado</th><th /></tr></thead><tbody>{items.map((item) => <tr key={item.id}>
      <td><div className="employee-cell"><span className="avatar"><Smartphone /></span><div><b>{item.nombre}</b><small>{item.modelo}</small></div></div></td>
      <td><b>{item.tipo_uso === 'DEPARTMENTS' ? 'Por departamentos' : 'Uso general'}</b><small>{branchName(item.sucursal_id)} · rev. {item.configuracion_revision ?? 0}</small><small>{item.tipo_uso === 'DEPARTMENTS' ? `${item.department_ids?.length ?? 0} departamento(s)` : 'Toda la empresa'}</small></td>
      <td>Android {item.android_version}<small>App {item.app_version}</small></td>
      <td>{date(item.ultima_conexion_at)}</td>
      <td>{date(item.ultima_sincronizacion_at)}</td>
      <td><Badge tone={item.estado === 'activo' ? 'green' : 'gray'}>{item.estado}</Badge></td>
      <td><div className="button-row">{item.estado !== 'revocado' && hasPermission('dispositivos.registrar') && <button className="icon" aria-label="Configurar" onClick={() => void beginEdit(item)}><Settings2 /></button>}{item.estado !== 'revocado' && hasPermission('dispositivos.revocar') && <button className="icon" aria-label="Revocar" onClick={() => void revoke(item)}><Power /></button>}</div></td>
    </tr>)}</tbody></table>{loading ? <Empty text="Cargando dispositivos…" /> : !items.length ? <Empty text="No hay dispositivos Android registrados." /> : null}</section>
  </>;
}
