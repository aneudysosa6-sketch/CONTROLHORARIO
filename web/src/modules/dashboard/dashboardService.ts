import type { PostgrestError } from '@supabase/supabase-js';
import { getSupabaseClient } from '../../infrastructure/supabase/client';
import type { Session } from '../../types';

type EmployeeRow = { id: string; nombre_completo: string; codigo_empleado: string; activo: boolean; jornada_habilitada: boolean };
type JourneyRow = { id: string; empleado_id: string; fecha_laboral: string; estado: string; minutos_trabajados: number | null; revision_pendiente: boolean; severidad: string; actualizada_en: string };
type IncidentRow = { id: string; jornada_id: string; empleado_id: string; tipo: string; severidad: string; mensaje: string; leida: boolean; resuelta: boolean; creada_en: string };

export type DashboardSnapshot = {
  workDate: string;
  notStarted: number;
  inProgress: number;
  paused: number;
  finished: number;
  pending: number;
  incidentCount: number;
  recent: Array<{ id: string; employee: string; code: string; status: string; workedMinutes: number; severity: string; updatedAt: string }>;
  incidents: Array<{ id: string; employee: string; type: string; severity: string; message: string; createdAt: string }>;
};

export class DashboardQueryError extends Error {
  constructor(
    public readonly query: string,
    public readonly code: string,
    message: string,
    public readonly details: string,
    public readonly hint: string,
    public readonly workDate: string | null,
  ) {
    super(message);
    this.name = 'DashboardQueryError';
  }
}

const failure = (query: string, error: PostgrestError, workDate: string | null) =>
  new DashboardQueryError(query, error.code, error.message, error.details, error.hint, workDate);

const dashboardLog = (event: 'DASHBOARD_QUERY' | 'ACTIVE_JOURNEY_QUERY', details: Record<string, unknown>) => {
  if (import.meta.env.DEV) console.debug(event, details);
};

export function companyWorkDate(timezone: string, date = new Date()): string {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
    const value = (type: Intl.DateTimeFormatPartTypes) => parts.find((part) => part.type === type)?.value ?? '';
    const result = `${value('year')}-${value('month')}-${value('day')}`;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(result)) throw new RangeError('No fue posible formar la fecha laboral.');
    return result;
  } catch (error) {
    throw new DashboardQueryError('companies.timezone', 'INVALID_COMPANY_TIMEZONE', error instanceof Error ? error.message : 'Zona horaria empresarial inválida.', timezone, '', null);
  }
}

function requireAdminScope(session: Session) {
  if (session.roleCode !== 'admin') throw new DashboardQueryError('dashboard role', 'DASHBOARD_ROLE_UNSUPPORTED', 'El Dashboard administrativo requiere rol admin.', session.roleCode, '', null);
  const required = ['jornadas.ver_todas', 'empleados.ver_todos'];
  const missing = required.filter((permission) => !session.permissions.includes(permission));
  if (missing.length) throw new DashboardQueryError('effective permissions', 'DASHBOARD_PERMISSION_MISSING', 'Faltan permisos efectivos para cargar el Dashboard.', missing.join(','), '', null);
}

export const dashboardService = {
  async load(session: Session): Promise<DashboardSnapshot> {
    requireAdminScope(session);
    const supabase = getSupabaseClient();
    const companyResult = await supabase.from('companies').select('timezone').eq('id', session.companyId).maybeSingle();
    if (companyResult.error) throw failure('companies.select(timezone)', companyResult.error, null);
    if (!companyResult.data?.timezone) throw new DashboardQueryError('companies.select(timezone)', 'COMPANY_TIMEZONE_NOT_FOUND', 'No se encontró la zona horaria de la empresa autenticada.', session.companyId, '', null);
    const workDate = companyWorkDate(companyResult.data.timezone);
    dashboardLog('DASHBOARD_QUERY', {
      companyId: session.companyId,
      workDate,
      timezone: companyResult.data.timezone,
      branchId: null,
      departmentId: null,
      supervisorId: null,
    });

    const [employeeResult, journeyResult, incidentResult] = await Promise.all([
      supabase.from('empleados').select('id,nombre_completo,codigo_empleado,activo,jornada_habilitada').eq('empresa_id', session.companyId),
      supabase.from('jornadas').select('id,empleado_id,fecha_laboral,estado,minutos_trabajados,revision_pendiente,severidad,actualizada_en').eq('empresa_id', session.companyId).eq('fecha_laboral', workDate).order('actualizada_en', { ascending: false }),
      supabase.from('jornada_incidencias').select('id,jornada_id,empleado_id,tipo,severidad,mensaje,leida,resuelta,creada_en').eq('empresa_id', session.companyId).eq('resuelta', false).eq('leida', false).order('creada_en', { ascending: false }),
    ]);
    if (employeeResult.error) throw failure('empleados.select(dashboard scope)', employeeResult.error, workDate);
    if (journeyResult.error) throw failure('jornadas.select(fecha_laboral)', journeyResult.error, workDate);
    if (incidentResult.error) throw failure('jornada_incidencias.select(open unread)', incidentResult.error, workDate);

    const employees = (employeeResult.data ?? []) as EmployeeRow[];
    const journeys = (journeyResult.data ?? []) as JourneyRow[];
    const incidents = (incidentResult.data ?? []) as IncidentRow[];
    const employeeById = new Map(employees.map((employee) => [employee.id, employee]));
    const employeesWithJourney = new Set(journeys.map((journey) => journey.empleado_id));
    const eligible = employees.filter((employee) => employee.activo && employee.jornada_habilitada);
    dashboardLog('ACTIVE_JOURNEY_QUERY', {
      companyId: session.companyId,
      workDate,
      timezone: companyResult.data.timezone,
      statuses: ['EN_CURSO', 'EN_PAUSA', 'FINALIZADA'],
      employeeId: null,
      resultCount: journeys.length,
      inProgress: journeys.filter((journey) => journey.estado === 'EN_CURSO').length,
    });
    return {
      workDate,
      notStarted: eligible.filter((employee) => !employeesWithJourney.has(employee.id)).length,
      inProgress: journeys.filter((journey) => journey.estado === 'EN_CURSO').length,
      paused: journeys.filter((journey) => journey.estado === 'EN_PAUSA').length,
      finished: journeys.filter((journey) => journey.estado === 'FINALIZADA').length,
      pending: journeys.filter((journey) => journey.revision_pendiente).length,
      incidentCount: incidents.length,
      recent: journeys.slice(0, 8).map((journey) => ({ id: journey.id, employee: employeeById.get(journey.empleado_id)?.nombre_completo ?? 'Empleado visible por RLS', code: employeeById.get(journey.empleado_id)?.codigo_empleado ?? '', status: journey.estado, workedMinutes: journey.minutos_trabajados ?? 0, severity: journey.severidad ?? 'NINGUNA', updatedAt: journey.actualizada_en })),
      incidents: incidents.slice(0, 6).map((incident) => ({ id: incident.id, employee: employeeById.get(incident.empleado_id)?.nombre_completo ?? 'Empleado visible por RLS', type: incident.tipo, severity: incident.severidad, message: incident.mensaje, createdAt: incident.creada_en })),
    };
  },
};
