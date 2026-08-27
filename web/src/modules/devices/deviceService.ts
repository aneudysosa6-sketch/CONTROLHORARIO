import { getSupabaseClient } from '../../infrastructure/supabase/client';

export type TerminalUsageType = 'GENERAL' | 'DEPARTMENTS';
export type AndroidDevice = {
  id: string;
  nombre: string;
  modelo: string;
  android_version: string;
  app_version: string;
  sucursal_id: string;
  tipo_uso: TerminalUsageType;
  configuracion_revision: number;
  department_ids: string[];
  estado: string;
  registrado_at: string;
  ultima_conexion_at: string | null;
  ultima_sincronizacion_at: string | null;
  revocado_at: string | null;
};
export type DeviceBranch = { id: string; name: string };
export type DeviceDepartment = { id: string; name: string; branch_id: string };
export type TerminalConfigurationInput = {
  branchId: string;
  usageType: TerminalUsageType;
  departmentIds: string[];
};

async function invoke<T>(body: Record<string, unknown>): Promise<T> {
  const { data, error } = await getSupabaseClient().functions.invoke('device-enrollment', { body });
  if (error) throw error;
  if (data?.error_code || data?.error) throw new Error(data.error_code ?? data.error);
  return data as T;
}

export const deviceService = {
  list: async () => (await invoke<{ devices: AndroidDevice[] }>({ action: 'list' })).devices,
  async branches(): Promise<DeviceBranch[]> {
    const { data, error } = await getSupabaseClient().from('branches')
      .select('id,name').eq('status', 'active').order('name');
    if (error) throw error;
    return data ?? [];
  },
  async departments(branchId: string): Promise<DeviceDepartment[]> {
    const { data, error } = await getSupabaseClient().from('departments')
      .select('id,name,branch_id').eq('branch_id', branchId).eq('is_active', true).order('name');
    if (error) throw error;
    return data ?? [];
  },
  createCode: (configuration: TerminalConfigurationInput) => invoke<{ code: string; expires_at: string }>({
    action: 'create-code',
    branch_id: configuration.branchId,
    usage_type: configuration.usageType,
    department_ids: configuration.usageType === 'DEPARTMENTS' ? configuration.departmentIds : [],
  }),
  configure: (deviceId: string, configuration: TerminalConfigurationInput) => invoke({
    action: 'configure',
    device_id: deviceId,
    branch_id: configuration.branchId,
    usage_type: configuration.usageType,
    department_ids: configuration.usageType === 'DEPARTMENTS' ? configuration.departmentIds : [],
  }),
  revoke: (deviceId: string) => invoke({ action: 'revoke', device_id: deviceId }),
};
