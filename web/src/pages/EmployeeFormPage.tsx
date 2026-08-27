import { FormEvent, useEffect, useMemo, useState } from 'react';
import { ArrowLeft, Save } from 'lucide-react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import {
  employeeService,
  type EmployeeCatalogs,
  type EmployeeFinanceItem,
  type EmployeeInput,
  type EmployeePayConfig,
  type EmployeeStatus,
} from '../modules/employees/employeeService';
import { EMPLOYEE_CODE_ERROR, isValidEmployeeCode, normalizeEmployeeCode } from '../modules/employees/employeeCodePolicy';
import { employeePayRates } from '../modules/employees/employeePayCalculations';

const blankPay: EmployeePayConfig = {
  dias_divisor_quincenal: 30,
  horas_dia: 8,
  valor_hora_extra: 0,
  afp_valor: 0,
  sfs_valor: 0,
  otros_impuestos_valor: 0,
  incentivo_periodo: 0,
  descuento_fijo_quincenal: 0,
  descuento_fijo_motivo: '',
  descuento_fijo_activo: false,
  otros_descuentos_fijos: 0,
  nomina_activa: true,
};

const blank: EmployeeInput = {
  code: '',
  name: '',
  cedula: '',
  email: '',
  phone: '',
  startDate: new Date().toISOString().slice(0, 10),
  status: 'activo',
  active: true,
  salary: null,
  payType: 'mensual',
  branchId: '',
  departmentId: '',
  positionId: '',
  pay: blankPay,
  payReason: 'Configuración salarial inicial',
};

const money = (value: number) => 'RD$ ' + value.toLocaleString('es-DO', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

function FinanceSummary({ title, items }: { title: string; items: EmployeeFinanceItem[] }) {
  return <div className="form-section">
    <h2>{title}</h2>
    {items.length ? <div className="detail-grid">{items.map((item) => <div key={item.id}>
      <small>{item.estado} · cuota {money(item.descuento_periodo)}</small>
      <b>Pendiente {money(item.pendiente)} de {money(item.monto_total)}</b>
    </div>)}</div> : <p>No hay registros. Se administran desde la ficha del empleado sin duplicar su configuración salarial.</p>}
  </div>;
}

export function EmployeeFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [form, setForm] = useState<EmployeeInput>(blank);
  const [catalogs, setCatalogs] = useState<EmployeeCatalogs>({ branches: [], departments: [], positions: [] });
  const [loans, setLoans] = useState<EmployeeFinanceItem[]>([]);
  const [credits, setCredits] = useState<EmployeeFinanceItem[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      const nextCatalogs = await employeeService.catalogs();
      if (!active) return;
      setCatalogs(nextCatalogs);
      if (!id) return;
      const [employee, paySheet] = await Promise.all([employeeService.get(id), employeeService.getPay(id)]);
      if (!active || !employee) return;
      setForm({
        id: employee.id,
        code: employee.code,
        name: employee.name,
        cedula: employee.cedula,
        email: employee.email,
        phone: employee.phone,
        startDate: employee.startDate,
        status: employee.status,
        active: employee.active,
        salary: employee.salary,
        payType: employee.payType || 'mensual',
        branchId: employee.branchId,
        departmentId: employee.departmentId,
        positionId: employee.positionId,
        pay: paySheet?.config ?? blankPay,
        payReason: 'Actualización de ficha salarial',
      });
      setLoans(paySheet?.prestamos ?? []);
      setCredits(paySheet?.creditos ?? []);
    };
    load().catch((failure) => active && setError(failure instanceof Error ? failure.message : 'No fue posible cargar el empleado.'));
    return () => { active = false; };
  }, [id]);

  const departments = useMemo(
    () => catalogs.departments.filter((item) => !form.branchId || !item.branch_id || item.branch_id === form.branchId),
    [catalogs.departments, form.branchId],
  );
  const positions = useMemo(
    () => catalogs.positions.filter((item) => !form.departmentId || !item.department_id || item.department_id === form.departmentId),
    [catalogs.positions, form.departmentId],
  );
  const rates = employeePayRates(form.salary, form.pay.dias_divisor_quincenal, form.pay.horas_dia);
  const validCode = !id || isValidEmployeeCode(form.code);

  const field = <K extends keyof EmployeeInput>(name: K, value: EmployeeInput[K]) => {
    setForm((current) => ({ ...current, [name]: value }));
  };
  const pay = <K extends keyof EmployeePayConfig>(name: K, value: EmployeePayConfig[K]) => {
    setForm((current) => ({ ...current, pay: { ...current.pay, [name]: value } }));
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError('');
    if (id && !normalizeEmployeeCode(form.code)) {
      setError(EMPLOYEE_CODE_ERROR);
      return;
    }
    if (!form.name.trim() || !form.salary || form.salary <= 0 || form.pay.horas_dia <= 0 || !form.payReason.trim()) {
      setError('Complete los campos obligatorios de empleado y pago.');
      return;
    }
    setBusy(true);
    try {
      const saved = await employeeService.save({ ...form, id, active: form.status !== 'desvinculado' });
      navigate('/empleados/' + saved.id, { replace: true });
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'No fue posible guardar el empleado.');
    } finally {
      setBusy(false);
    }
  };

  return <div className="page stack">
    <header className="page-header">
      <div>
        <p className="eyebrow">Empleados</p>
        <h1>{id ? 'Editar empleado' : 'Nuevo empleado'}</h1>
        <p>Los datos administrativos se gestionan en Web. El rostro queda pendiente para registrarse en un Terminal autorizado.</p>
      </div>
      <Link className="button secondary" to={id ? '/empleados/' + id : '/empleados'}><ArrowLeft />Volver</Link>
    </header>

    <form className="stack" onSubmit={submit}>
      <div className="form-section"><h2>1. Datos personales</h2><div className="form-grid">
        <label>Código de empleado<input readOnly aria-readonly="true" value={id ? form.code : 'Se asignará al guardar'} /><small>Formato: 6 dígitos. {id ? 'El código identifica permanentemente al empleado.' : 'Supabase asigna el código oficial al guardar.'}</small></label>
        <label>Nombre completo *<input required value={form.name} onChange={(event) => field('name', event.target.value)} /></label>
        <label>Cédula<input value={form.cedula} onChange={(event) => field('cedula', event.target.value)} /></label>
        <label>Correo<input type="email" value={form.email} onChange={(event) => field('email', event.target.value)} /></label>
        <label>Teléfono<input value={form.phone} onChange={(event) => field('phone', event.target.value)} /></label>
      </div></div>

      <div className="form-section"><h2>2. Organización</h2><div className="form-grid">
        <label>Sucursal<select value={form.branchId} onChange={(event) => field('branchId', event.target.value)}><option value="">Sin asignar</option>{catalogs.branches.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
        <label>Departamento<select value={form.departmentId} onChange={(event) => field('departmentId', event.target.value)}><option value="">Sin asignar</option>{departments.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
        <label>Cargo<select value={form.positionId} onChange={(event) => field('positionId', event.target.value)}><option value="">Sin asignar</option>{positions.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
        <label>Fecha de ingreso<input type="date" value={form.startDate} onChange={(event) => field('startDate', event.target.value)} /></label>
        <label>Estado<select value={form.status} onChange={(event) => field('status', event.target.value as EmployeeStatus)} disabled={form.status === 'desvinculado'}><option value="activo">Activo</option><option value="pendiente">Pendiente</option><option value="licencia">Licencia</option><option value="suspendido">Suspendido</option>{form.status === 'desvinculado' && <option value="desvinculado">Desvinculado</option>}</select></label>
      </div></div>

      <div className="form-section"><h2>3. Horario</h2><div className="form-grid">
        <label>Horas normales diarias *<input type="number" min="0.01" step="0.01" value={form.pay.horas_dia} onChange={(event) => pay('horas_dia', Number(event.target.value))} /></label>
      </div><p>Las horas reales provienen exclusivamente de jornadas finalizadas.</p></div>

      <div className="form-section"><h2>4. Pago y nómina</h2><div className="form-grid">
        <label>Sueldo mensual *<input type="number" min="0.01" step="0.01" value={form.salary ?? ''} onChange={(event) => field('salary', event.target.value === '' ? null : Number(event.target.value))} /></label>
        <label>Días divisor del salario *<input type="number" min="0.01" step="0.01" value={form.pay.dias_divisor_quincenal} onChange={(event) => pay('dias_divisor_quincenal', Number(event.target.value))} /></label>
        <label>Pago diario calculado<input readOnly value={money(rates.daily)} /></label>
        <label>Valor hora normal calculado<input readOnly value={money(rates.hourly)} /></label>
        <label>Valor hora extra manual<input type="number" min="0" step="0.01" value={form.pay.valor_hora_extra} onChange={(event) => pay('valor_hora_extra', Number(event.target.value))} /></label>
        <label>Ejemplo de pago por 8 horas<input readOnly value={money(rates.eightHours)} /></label>
        <label>Incentivo fijo<input type="number" min="0" step="0.01" value={form.pay.incentivo_periodo} onChange={(event) => pay('incentivo_periodo', Number(event.target.value))} /></label>
        <label className="check"><input type="checkbox" checked={form.pay.nomina_activa} onChange={(event) => pay('nomina_activa', event.target.checked)} />Nómina activa</label>
      </div></div>

      <div className="form-section"><h2>5. AFP, SFS e impuestos</h2><div className="form-grid">
        <label>AFP manual por quincena<input type="number" min="0" step="0.01" value={form.pay.afp_valor} onChange={(event) => pay('afp_valor', Number(event.target.value))} /></label>
        <label>SFS manual por quincena<input type="number" min="0" step="0.01" value={form.pay.sfs_valor} onChange={(event) => pay('sfs_valor', Number(event.target.value))} /></label>
        <label>Otros impuestos manuales<input type="number" min="0" step="0.01" value={form.pay.otros_impuestos_valor} onChange={(event) => pay('otros_impuestos_valor', Number(event.target.value))} /></label>
      </div></div>

      <FinanceSummary title="6. Préstamos" items={loans} />
      <FinanceSummary title="7. Créditos" items={credits} />

      <div className="form-section"><h2>8. Descuentos fijos</h2><div className="form-grid">
        <label>Descuento fijo por quincena<input type="number" min="0" step="0.01" value={form.pay.descuento_fijo_quincenal} onChange={(event) => pay('descuento_fijo_quincenal', Number(event.target.value))} /></label>
        <label>Motivo<input value={form.pay.descuento_fijo_motivo} onChange={(event) => pay('descuento_fijo_motivo', event.target.value)} /></label>
        <label className="check"><input type="checkbox" checked={form.pay.descuento_fijo_activo} onChange={(event) => pay('descuento_fijo_activo', event.target.checked)} />Descuento activo</label>
      </div></div>

      <div className="form-section"><h2>9. Otros descuentos</h2><div className="form-grid">
        <label>Otros descuentos fijos por quincena<input type="number" min="0" step="0.01" value={form.pay.otros_descuentos_fijos} onChange={(event) => pay('otros_descuentos_fijos', Number(event.target.value))} /></label>
        <label>Motivo de la configuración *<input required value={form.payReason} onChange={(event) => field('payReason', event.target.value)} /></label>
      </div></div>

      {form.status === 'desvinculado' && <div className="error" role="status">Este expediente está desvinculado. Reactívelo desde Empleados dados de baja antes de editarlo.</div>}
      {error && <div className="error" role="alert">{error}</div>}
      <div className="form-actions"><button className="primary" disabled={busy || !validCode || form.status === 'desvinculado'}><Save />{busy ? 'Guardando…' : 'Guardar empleado y pago'}</button></div>
    </form>
  </div>;
}
