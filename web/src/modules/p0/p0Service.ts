import { getSupabaseClient } from '../../infrastructure/supabase/client';

export type P0Employee = { id: string; codigo: string; nombre: string; salario: number | null };
export type DirectLicense = {
  id: string;
  empleado_id: string;
  codigo_empleado?: string;
  nombre_empleado?: string;
  fecha_inicio: string;
  fecha_fin: string;
  porcentaje_pago: number;
  estado: 'ACTIVA' | 'CANCELADA';
  version_actual?: number;
  total?: number;
};
export type IncompleteJourney = {
  jornada_id: string;
  empleado_id: string;
  codigo_empleado?: string;
  nombre_empleado?: string;
  fecha_laboral: string;
  solo_inicio?: boolean;
  eventos?: unknown[];
  periodo_cerrado?: boolean;
  estado?: string;
};
export type PriorAdjustment = {
  id: string;
  empleado_id: string;
  codigo_empleado?: string;
  nombre_empleado?: string;
  periodo_origen_id: string;
  periodo_destino_id?: string | null;
  concepto: string;
  monto: number;
  estado: string;
  idempotency_key: string;
};
export type BlacklistEntry = {
  empleado_id: string;
  codigo_empleado?: string;
  nombre_empleado?: string;
  mes: string;
  ausencias: number;
  tardanzas: number;
  jornadas_incompletas: number;
  motivos: string[];
  detalle?: unknown[];
};

function fail(error: { message: string } | null): never {
  throw new Error(error?.message ?? 'No fue posible completar la operación P0.');
}

async function rpc<T>(name: string, args: Record<string, unknown> = {}) {
  const { data, error } = await getSupabaseClient().rpc(name, args);
  if (error) fail(error);
  return data as T;
}

export const p0Service = {
  async employees(): Promise<P0Employee[]> {
    const { data, error } = await getSupabaseClient()
      .from('empleados')
      .select('id,codigo_empleado,nombre_completo,salario')
      .eq('activo', true)
      .eq('estado_laboral', 'activo')
      .order('nombre_completo');
    if (error) fail(error);
    return (data ?? []).map((row) => ({
      id: row.id,
      codigo: row.codigo_empleado,
      nombre: row.nombre_completo,
      salario: row.salario,
    }));
  },
  licenses: () => rpc<DirectLicense[]>('listar_licencias_directas'),
  createLicense: (input: { employeeId: string; start: string; end: string; percentage: number; reason: string }) =>
    rpc<DirectLicense>('crear_licencia_directa', { payload: {
      empleado_id: input.employeeId,
      fecha_inicio: input.start,
      fecha_fin: input.end,
      porcentaje_pago: input.percentage,
      motivo: input.reason,
    } }),
  editLicense: (id: string, input: { start: string; end: string; percentage: number; reason: string }) =>
    rpc<DirectLicense>('editar_licencia_directa', { payload: {
      licencia_id: id,
      fecha_inicio: input.start,
      fecha_fin: input.end,
      porcentaje_pago: input.percentage,
      motivo: input.reason,
    } }),
  cancelLicense: (id: string, reason: string) =>
    rpc<DirectLicense>('cancelar_licencia_directa', { payload: { licencia_id: id, motivo: reason } }),
  incompleteJourneys: () => rpc<IncompleteJourney[]>('listar_jornadas_incompletas_pendientes'),
  resolveIncomplete: (journeyId: string, decision: 'NO_PAY' | 'PAY_DEMONSTRABLE', manualHours?: number) =>
    rpc('resolver_jornada_incompleta', { payload: {
      jornada_id: journeyId,
      decision,
      horas_manuales: manualHours ?? null,
    } }),
  priorAdjustments: (periodId?: string) => rpc<PriorAdjustment[]>('listar_ajustes_periodos_anteriores', {
    p_periodo: periodId || null,
  }),
  refreshBlacklist: (month: string) => rpc<BlacklistEntry[]>('refrescar_lista_negra_mensual', { p_mes: `${month}-01` }),
  blacklistReport: (month: string, employeeId?: string) => rpc<BlacklistEntry[]>('obtener_reporte_lista_negra_empleado', {
    p_mes: `${month}-01`,
    p_empleado: employeeId || null,
  }),
};
