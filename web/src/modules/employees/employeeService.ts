import { getSupabaseClient } from '../../infrastructure/supabase/client';
import { EMPLOYEE_CODE_ERROR, normalizeEmployeeCode } from './employeeCodePolicy';
import { buildEmployeeMutationPayload } from './employeeMutationPayload';

export type EmployeeStatus = 'activo' | 'pendiente' | 'licencia' | 'suspendido' | 'desvinculado';

export interface EmployeeRecord {
  id: string;
  code: string;
  name: string;
  cedula: string;
  email: string;
  phone: string;
  startDate: string;
  status: EmployeeStatus;
  active: boolean;
  salary: number | null;
  payType: string;
  companyId: string;
  companyName: string;
  branchId: string;
  branchName: string;
  departmentId: string;
  departmentName: string;
  positionId: string;
  positionName: string;
  fingerprintReady: boolean;
  fingerprintRegisteredAt: string;
  fingerprintDevice: string;
  terminationDate: string;
  terminationReason: string;
  terminationObservation: string;
  terminatedBy: string;
  terminationActorName: string;
}

export interface EmployeePayConfig {
  dias_divisor_quincenal: number;
  horas_dia: number;
  valor_hora_extra: number;
  afp_valor: number;
  sfs_valor: number;
  otros_impuestos_valor: number;
  incentivo_periodo: number;
  descuento_fijo_quincenal: number;
  descuento_fijo_motivo: string;
  descuento_fijo_activo: boolean;
  otros_descuentos_fijos: number;
  nomina_activa: boolean;
}

export interface EmployeeFinanceItem {
  id: string;
  monto_total: number;
  pendiente: number;
  descuento_periodo: number;
  estado: string;
  total_pagado?: number;
  total_descontado?: number;
  motivo: string;
}

export interface EmployeePaySheet {
  config: EmployeePayConfig;
  prestamos: EmployeeFinanceItem[];
  creditos: EmployeeFinanceItem[];
}

export interface EmployeeCatalogs {
  branches: { id: string; name: string }[];
  departments: { id: string; name: string; branch_id: string | null }[];
  positions: { id: string; name: string; department_id: string | null }[];
}

export interface EmployeeInput {
  id?: string;
  code: string;
  name: string;
  cedula?: string;
  email?: string;
  phone?: string;
  startDate?: string;
  status: EmployeeStatus;
  active: boolean;
  salary?: number | null;
  payType?: string;
  branchId?: string;
  departmentId?: string;
  positionId?: string;
  pay: EmployeePayConfig;
  payReason: string;
}

export interface EmployeeTerminationInput {
  date: string;
  reason: string;
  observation?: string;
}

export interface EmployeeLifecycleEvent {
  id: number;
  event: 'EMPLOYEE_TERMINATED' | 'EMPLOYEE_REACTIVATED';
  effectiveDate: string;
  reason: string;
  observation: string;
  previousStatus: string;
  nextStatus: string;
  createdAt: string;
}

type EmployeeRow = {
  id: string;
  codigo_empleado: string;
  nombre_completo: string;
  cedula: string | null;
  correo: string | null;
  telefono: string | null;
  fecha_ingreso: string | null;
  estado_laboral: EmployeeStatus;
  activo: boolean;
  salario: number | null;
  tipo_pago: string | null;
  empresa_id: string;
  sucursal_id: string | null;
  departamento_id: string | null;
  puesto_id: string | null;
  fecha_desvinculacion: string | null;
  motivo_desvinculacion: string | null;
  observacion_desvinculacion: string | null;
  desvinculado_por: string | null;
  branches: { name: string } | { name: string }[] | null;
  departments: { name: string } | { name: string }[] | null;
  positions: { name: string } | { name: string }[] | null;
  termination_actor: { full_name: string } | { full_name: string }[] | null;
  companies: { name: string } | { name: string }[] | null;
};

type BiometricState = {
  empleado_id: string;
  registrada: boolean;
  registrado_at: string | null;
  dispositivo_origen: string | null;
};

const EMPLOYEE_SELECT = 'id,codigo_empleado,nombre_completo,cedula,correo,telefono,fecha_ingreso,estado_laboral,activo,salario,tipo_pago,empresa_id,sucursal_id,departamento_id,puesto_id,fecha_desvinculacion,motivo_desvinculacion,observacion_desvinculacion,desvinculado_por,companies!empleados_empresa_id_fkey(name),branches!empleados_sucursal_misma_empresa_fk(name),departments!empleados_departamento_misma_empresa_fk(name),positions!empleados_puesto_misma_empresa_fk(name),termination_actor:profiles!empleados_desvinculado_por_misma_empresa_fk(full_name)';

const related = (value: { name: string } | { name: string }[] | null) =>
  Array.isArray(value) ? value[0]?.name ?? '' : value?.name ?? '';

const actorName = (value: { full_name: string } | { full_name: string }[] | null) =>
  Array.isArray(value) ? value[0]?.full_name ?? '' : value?.full_name ?? '';

const map = (row: EmployeeRow): EmployeeRecord => ({
  id: row.id,
  code: normalizeEmployeeCode(row.codigo_empleado) ?? row.codigo_empleado,
  name: row.nombre_completo,
  cedula: row.cedula ?? '',
  email: row.correo ?? '',
  phone: row.telefono ?? '',
  startDate: row.fecha_ingreso ?? '',
  status: row.estado_laboral,
  active: row.activo,
  salary: row.salario,
  payType: row.tipo_pago ?? '',
  companyId: row.empresa_id,
  companyName: related(row.companies),
  branchId: row.sucursal_id ?? '',
  branchName: related(row.branches),
  departmentId: row.departamento_id ?? '',
  departmentName: related(row.departments),
  positionId: row.puesto_id ?? '',
  positionName: related(row.positions),
  fingerprintReady: false,
  fingerprintRegisteredAt: '',
  fingerprintDevice: '',
  terminationDate: row.fecha_desvinculacion ?? '',
  terminationReason: row.motivo_desvinculacion ?? '',
  terminationObservation: row.observacion_desvinculacion ?? '',
  terminatedBy: row.desvinculado_por ?? '',
  terminationActorName: actorName(row.termination_actor),
});

const invoke = async <T>(body: Record<string, unknown>) => {
  const { data, error } = await getSupabaseClient().functions.invoke('employee-management', { body });
  if (data?.error) throw new Error(data.error);
  if (error) {
    const response = (error as { context?: Response }).context;
    const payload = await response?.clone().json().catch(() => null) as { error?: unknown } | null;
    const message = typeof payload?.error === 'string' ? payload.error.trim() : '';
    if (message) throw new Error(message);
    throw error;
  }
  return data as T;
};

const withBiometrics = async (items: EmployeeRecord[]) => {
  const { data, error } = await getSupabaseClient().rpc('listar_estados_biometricos_empleados');
  if (error) {
    if (error.code === 'PGRST202') return items;
    throw error;
  }
  const states = new Map(((data ?? []) as BiometricState[]).map((state) => [state.empleado_id, state]));
  return items.map((item) => {
    const state = states.get(item.id);
    return {
      ...item,
      fingerprintReady: state?.registrada === true,
      fingerprintRegisteredAt: state?.registrado_at ?? '',
      fingerprintDevice: state?.dispositivo_origen ?? '',
    };
  });
};

const rows = (data: unknown[] | null) => (data ?? []).map((row) => map(row as EmployeeRow));

export const employeeService = {
  /** Full scoped list retained for read-only reports that explicitly need every state. */
  async list() {
    const { data, error } = await getSupabaseClient()
      .from('empleados')
      .select(EMPLOYEE_SELECT)
      .order('nombre_completo');
    if (error) throw error;
    return withBiometrics(rows(data));
  },

  /** Operational employee list: termination records belong exclusively to the bajas screen. */
  async listActive() {
    const { data, error } = await getSupabaseClient()
      .from('empleados')
      .select(EMPLOYEE_SELECT)
      .eq('activo', true)
      .neq('estado_laboral', 'desvinculado')
      .order('nombre_completo');
    if (error) throw error;
    return withBiometrics(rows(data));
  },

  async listTerminated() {
    const { data, error } = await getSupabaseClient()
      .from('empleados')
      .select(EMPLOYEE_SELECT)
      .eq('estado_laboral', 'desvinculado')
      .order('fecha_desvinculacion', { ascending: false, nullsFirst: false })
      .order('nombre_completo');
    if (error) throw error;
    return rows(data);
  },

  async get(id: string) {
    const { data, error } = await getSupabaseClient()
      .from('empleados')
      .select(EMPLOYEE_SELECT)
      .eq('id', id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return null;
    return (await withBiometrics([map(data as unknown as EmployeeRow)]))[0] ?? null;
  },

  async catalogs(): Promise<EmployeeCatalogs> {
    const supabase = getSupabaseClient();
    const [branches, departments, positions] = await Promise.all([
      supabase.from('branches').select('id,name').eq('status', 'active').order('name'),
      supabase.from('departments').select('id,name,branch_id').eq('is_active', true).order('name'),
      supabase.from('positions').select('id,name,department_id').eq('is_active', true).order('name'),
    ]);
    if (branches.error) throw branches.error;
    if (departments.error) throw departments.error;
    if (positions.error) throw positions.error;
    return { branches: branches.data ?? [], departments: departments.data ?? [], positions: positions.data ?? [] };
  },

  async getPay(id: string) {
    const { data, error } = await getSupabaseClient().rpc('obtener_ficha_pago_empleado', { p_empleado: id });
    if (error) throw error;
    return data as EmployeePaySheet;
  },

  async lifecycleHistory(id: string): Promise<EmployeeLifecycleEvent[]> {
    const { data, error } = await getSupabaseClient()
      .from('empleado_ciclo_laboral_auditoria')
      .select('id,evento,fecha_efectiva,motivo,observacion,estado_anterior,estado_nuevo,creado_en')
      .eq('empleado_id', id)
      .order('creado_en', { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => ({
      id: Number(row.id),
      event: row.evento as EmployeeLifecycleEvent['event'],
      effectiveDate: row.fecha_efectiva,
      reason: row.motivo,
      observation: row.observacion ?? '',
      previousStatus: row.estado_anterior ?? '',
      nextStatus: row.estado_nuevo,
      createdAt: row.creado_en,
    }));
  },

  async nextCode() {
    const result = await invoke<{ code: string }>({ action: 'next-code' });
    const code = normalizeEmployeeCode(result.code);
    if (!code) throw new Error('El servidor no devolvió un código de empleado válido.');
    return code;
  },

  async save(input: EmployeeInput) {
    if (input.status === 'desvinculado') {
      throw new Error('La desvinculación se gestiona exclusivamente desde la acción Dar de baja.');
    }
    const code = input.id ? normalizeEmployeeCode(input.code) : null;
    if (input.id && !code) throw new Error(EMPLOYEE_CODE_ERROR);
    const client = getSupabaseClient();
    const { data: allowed, error: permissionError } = await client.rpc('tiene_permiso', { codigo_permiso: 'nomina.editar' });
    if (permissionError) throw permissionError;
    if (allowed !== true) throw new Error('Se requiere el permiso nomina.editar para guardar Pago y nómina.');
    const employee = buildEmployeeMutationPayload(input, code ?? undefined);
    const result = await invoke<{ employee: { id: string; code?: string } }>({ action: 'save', employee });
    const id = result.employee.id;
    const assignedCode = normalizeEmployeeCode(result.employee.code ?? '');
    if (!assignedCode) throw new Error('El servidor no devolvió el código oficial del empleado.');
    const { error } = await client.rpc('guardar_ficha_pago_empleado', { p_empleado: id, p_config: input.pay, p_motivo: input.payReason });
    if (error) throw error;
    return { id, code: assignedCode };
  },

  async terminate(id: string, input: EmployeeTerminationInput) {
    const result = await invoke<{ id: string; active: boolean; status: EmployeeStatus }>({
      action: 'terminate',
      id,
      date: input.date,
      reason: input.reason.trim(),
      observation: input.observation?.trim() || null,
    });
    const { publishNotification } = await import('../notifications/notificationIntegration');
    publishNotification('employee_deactivated', 'Empleado desvinculado', { employeeId: id }, `employee-terminated:${id}:${Date.now()}`);
    return result;
  },

  async reactivate(id: string, reason: string) {
    return invoke<{ id: string; active: boolean; status: EmployeeStatus }>({
      action: 'reactivate',
      id,
      reason: reason.trim(),
    });
  },
};
