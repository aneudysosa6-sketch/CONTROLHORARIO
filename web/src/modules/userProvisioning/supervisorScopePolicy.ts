export const SUPERVISOR_ROLE_CODE_CANONICAL = 'SUPERVISOR';

export interface SupervisorScopeDepartment {
  id: string;
  branch_id: string | null;
  is_active: boolean;
}

export interface SupervisorScopeSelection {
  branchId: string;
  departmentIds: readonly string[];
}

export interface SupervisorScopeRequestFields {
  branch_id: string;
  department_ids: string[];
}

export type SupervisorScopeValidationError =
  | 'ROLE_CANONICAL_REQUIRED'
  | 'SUPERVISOR_BRANCH_REQUIRED'
  | 'SIN_DEPARTAMENTOS'
  | 'SUPERVISOR_DEPARTMENTS_INVALID';

export type SupervisorScopeValidation =
  | {
      valid: true;
      applies: boolean;
      branchId: string;
      departmentIds: string[];
    }
  | {
      valid: false;
      error: SupervisorScopeValidationError;
    };

export type SupervisorScopeBuildResult =
  | {
      ok: true;
      scope: SupervisorScopeRequestFields | null;
    }
  | {
      ok: false;
      error: SupervisorScopeValidationError;
    };

/**
 * El servidor es la unica autoridad que canonicaliza roles. Los aliases, el
 * nombre visible y los codigos originales nunca convierten un rol en
 * SUPERVISOR dentro del cliente.
 */
export function isSupervisorCanonicalRole(roleCodeCanonical: string | null | undefined) {
  return roleCodeCanonical === SUPERVISOR_ROLE_CODE_CANONICAL;
}

export function deduplicateDepartmentIds(departmentIds: readonly string[]) {
  return [...new Set(departmentIds)];
}

export function activeDepartmentsForBranch<T extends SupervisorScopeDepartment>(
  departments: readonly T[],
  branchId: string,
) {
  return departments.filter(
    (department) => department.is_active && department.branch_id === branchId,
  );
}

export function selectAllActiveDepartmentIds(
  departments: readonly SupervisorScopeDepartment[],
  branchId: string,
) {
  return deduplicateDepartmentIds(
    activeDepartmentsForBranch(departments, branchId).map((department) => department.id),
  );
}

export function toggleDepartmentSelection(
  departmentIds: readonly string[],
  departmentId: string,
  selected: boolean,
) {
  const current = deduplicateDepartmentIds(departmentIds);
  if (selected) return deduplicateDepartmentIds([...current, departmentId]);
  return current.filter((id) => id !== departmentId);
}

export function changeSupervisorBranch(
  selection: SupervisorScopeSelection,
  nextBranchId: string,
): SupervisorScopeSelection {
  return {
    branchId: nextBranchId,
    departmentIds: nextBranchId === selection.branchId
      ? deduplicateDepartmentIds(selection.departmentIds)
      : [],
  };
}

export function validateSupervisorScope(
  roleCodeCanonical: string | null | undefined,
  selection: SupervisorScopeSelection,
  departments: readonly SupervisorScopeDepartment[],
): SupervisorScopeValidation {
  if (!roleCodeCanonical) {
    return { valid: false, error: 'ROLE_CANONICAL_REQUIRED' };
  }
  if (!isSupervisorCanonicalRole(roleCodeCanonical)) {
    return { valid: true, applies: false, branchId: '', departmentIds: [] };
  }

  if (!selection.branchId) {
    return { valid: false, error: 'SUPERVISOR_BRANCH_REQUIRED' };
  }

  const departmentIds = deduplicateDepartmentIds(selection.departmentIds);
  if (departmentIds.length === 0) {
    return { valid: false, error: 'SIN_DEPARTAMENTOS' };
  }

  const allowedIds = new Set(
    activeDepartmentsForBranch(departments, selection.branchId).map((department) => department.id),
  );
  if (departmentIds.some((departmentId) => !allowedIds.has(departmentId))) {
    return { valid: false, error: 'SUPERVISOR_DEPARTMENTS_INVALID' };
  }

  return {
    valid: true,
    applies: true,
    branchId: selection.branchId,
    departmentIds,
  };
}

/**
 * `scope: null` significa que el consumidor debe omitir branch_id y
 * department_ids por completo al construir el request de un rol no
 * supervisor.
 */
export function buildSupervisorScopeRequest(
  roleCodeCanonical: string | null | undefined,
  selection: SupervisorScopeSelection,
  departments: readonly SupervisorScopeDepartment[],
): SupervisorScopeBuildResult {
  const validation = validateSupervisorScope(roleCodeCanonical, selection, departments);
  if (!validation.valid) return { ok: false, error: validation.error };
  if (!validation.applies) return { ok: true, scope: null };
  return {
    ok: true,
    scope: {
      branch_id: validation.branchId,
      department_ids: validation.departmentIds,
    },
  };
}
