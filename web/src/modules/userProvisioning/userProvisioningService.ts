import { getSupabaseClient } from '../../infrastructure/supabase/client';

export interface PendingAuthUser {
  id: string;
  email: string;
  full_name: string;
  created_at: string;
}

export interface CatalogItem {
  id: string;
  name: string;
  code?: string;
  role_code_canonical?: string;
  company_id?: string;
}

export interface AvailableEmployee {
  id: string;
  nombre_completo: string;
  codigo_empleado: string;
  empresa_id: string;
  perfil_id?: string | null;
}

export interface ProvisioningState {
  users: PendingAuthUser[];
  companies: CatalogItem[];
  roles: CatalogItem[];
  employees: AvailableEmployee[];
}

export type AccessStatus = 'active' | 'inactive' | 'suspended' | 'invited';
export type ManagedAccessStatus = Exclude<AccessStatus, 'invited'>;

export interface AccessRecord {
  id: string;
  username: string;
  email?: string;
  employee_id: string | null;
  employee_name: string | null;
  employee_code: string | null;
  role_id: string;
  role_name: string;
  role_code?: string;
  role_code_canonical?: string;
  status: AccessStatus;
  last_sign_in_at: string | null;
}

export interface AccessesState {
  accesses: AccessRecord[];
  employees: AvailableEmployee[];
  roles: CatalogItem[];
}

export interface CreateAccessInput {
  employee_id: string;
  username: string;
  password: string;
  role_id: string;
  status: ManagedAccessStatus;
  idempotency_key: string;
  branch_id?: string;
  department_ids?: string[];
}

export interface UpdateAccessInput {
  profile_id: string;
  employee_id: string;
  username: string;
  role_id: string;
  status: ManagedAccessStatus;
  branch_id?: string;
  department_ids?: string[];
}

export interface SupervisorBranchOption {
  id: string;
  name: string;
  code: string;
  status: 'active';
}

export interface SupervisorDepartmentOption {
  id: string;
  name: string;
  code: string;
  branch_id: string;
  is_active: boolean;
}

export interface SupervisorScopeSnapshot {
  profile_id: string | null;
  role_code_canonical: string | null;
  status: ManagedAccessStatus | null;
  branch_id: string | null;
  branch_ids: string[];
  department_ids: string[];
  invalid_department_ids: string[];
  requires_reconciliation: boolean;
}

export interface SupervisorScopeState {
  branches: SupervisorBranchOption[];
  departments: SupervisorDepartmentOption[];
  supervisor_role_ids: string[];
  scope: SupervisorScopeSnapshot;
}

export interface SaveSupervisorScopeInput {
  profile_id: string;
  branch_id: string;
  department_ids: string[];
}

export interface AccessMutationResult {
  access: unknown;
  auth_status_sync: 'completed' | 'pending';
  audit_sync?: 'completed' | 'pending';
  idempotent_replay?: boolean;
  recovered_committed_transaction?: boolean;
  auth_compensation?: 'completed';
  requestId?: string;
}

export interface AuditMutationResult {
  updated: boolean;
  audit_sync: 'completed' | 'pending';
  requestId?: string;
}

interface ProvisioningFailurePayload {
  error?: string;
  requestId?: string;
  stage?: string;
  recovery_status?: string;
}

export class UserProvisioningError extends Error {
  constructor(
    message: string,
    readonly requestId?: string,
    readonly stage?: string,
    readonly recoveryStatus?: string,
  ) {
    super(message);
    this.name = 'UserProvisioningError';
  }
}

export interface ProvisionInput {
  user_id?: string;
  email?: string;
  full_name: string;
  company_id: string;
  role_id: string;
  employee_id?: string;
  status: 'active' | 'invited';
}

export interface BootstrapInput {
  company_name: string;
  legal_name: string;
  company_slug: string;
  full_name: string;
  email: string;
  branch_name: string;
  timezone: 'America/Santo_Domingo';
}

async function invoke<T>(body: Record<string, unknown>): Promise<T> {
  const { data, error, response } = await getSupabaseClient().functions.invoke(
    'user-provisioning',
    { body },
  );
  const dataFailure = data as ProvisioningFailurePayload | null;
  if (dataFailure?.error) {
    throw new UserProvisioningError(
      dataFailure.error,
      dataFailure.requestId,
      dataFailure.stage,
      dataFailure.recovery_status,
    );
  }
  if (error) {
    if (response) {
      const payload = await response.json().catch(() => null) as ProvisioningFailurePayload | null;
      if (payload?.error) {
        throw new UserProvisioningError(
          payload.error,
          payload.requestId,
          payload.stage,
          payload.recovery_status,
        );
      }
    }
    throw error;
  }
  return data as T;
}

async function bootstrap(input: BootstrapInput, secret: string) {
  const { data, error, response } = await getSupabaseClient().functions.invoke(
    'user-provisioning',
    {
      body: { action: 'bootstrap', ...input },
      headers: { 'x-bootstrap-secret': secret },
    },
  );
  if (data?.error) throw new Error(data.error);
  if (error) {
    if (response) {
      const payload = await response.json().catch(() => null) as { error?: string } | null;
      if (payload?.error) throw new Error(payload.error);
    }
    throw error;
  }
  return data as { profile: unknown };
}

export const userProvisioningService = {
  bootstrapStatus: () => invoke<{ bootstrap_required: boolean }>({ action: 'bootstrap-status' }),
  list: (company_id?: string) => invoke<ProvisioningState>({ action: 'list', company_id }),
  provision: (input: ProvisionInput) => invoke<{ profile: unknown }>({ action: 'provision', ...input }),
  invite: (input: ProvisionInput) => invoke<{ profile: unknown }>({ action: 'invite', ...input }),
  bootstrap,

  listAccesses: () => invoke<AccessesState>({ action: 'list-accesses' }),
  getSupervisorScope: (profileId?: string) => invoke<SupervisorScopeState>({
    action: 'get-supervisor-scope',
    ...(profileId ? { profile_id: profileId } : {}),
  }),
  saveSupervisorScope: (input: SaveSupervisorScopeInput) => invoke<{
    profile_id: string;
    branch_id: string;
    department_ids: string[];
    changed: boolean;
  }>({ action: 'save-supervisor-scope', ...input }),
  createAccess: (input: CreateAccessInput) => invoke<AccessMutationResult>({ action: 'create-access', ...input }),
  updateAccess: (input: UpdateAccessInput) => invoke<AccessMutationResult>({ action: 'update-access', ...input }),
  updateAccessPassword: (profileId: string, password: string) => invoke<AuditMutationResult>({
    action: 'update-password',
    profile_id: profileId,
    password,
  }),
  setAccessStatus: (profileId: string, status: ManagedAccessStatus) => invoke<AccessMutationResult>({
    action: 'set-status',
    profile_id: profileId,
    status,
  }),
  deleteAccess: (profileId: string) => invoke<void>({
    action: 'delete-access',
    profile_id: profileId,
  }),
};
