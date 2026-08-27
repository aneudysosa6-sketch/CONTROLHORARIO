export const SUPERVISOR_ROLE_CODE_CANONICAL = 'SUPERVISOR';

export interface SupervisorScopeDepartment {
  id: string;
  branch_id: string | null;
  is_active: boolean;
}

export interface SupervisorScopeSelection {
  branchIds: readonly string[];
  departmentIds: readonly string[];
}

export interface SupervisorScopeRequestFields {
  branch_ids: string[];
  department_ids: string[];
}

export type SupervisorScopeValidationError =
  | 'ROLE_CANONICAL_REQUIRED'
  | 'SUPERVISOR_BRANCH_REQUIRED'
  | 'SUPERVISOR_BRANCH_WITHOUT_DEPARTMENTS'
  | 'SIN_DEPARTAMENTOS'
  | 'SUPERVISOR_DEPARTMENTS_INVALID';

export type SupervisorScopeValidation =
  | {
      valid: true;
      applies: boolean;
      branchIds: string[];
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

export function isSupervisorCanonicalRole(roleCodeCanonical: string | null | undefined) {
  return roleCodeCanonical === SUPERVISOR_ROLE_CODE_CANONICAL;
}

export function deduplicateDepartmentIds(departmentIds: readonly string[]) {
  return [...new Set(departmentIds)];
}

export function deduplicateBranchIds(branchIds: readonly string[]) {
  return [...new Set(branchIds)];
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
  branchIds: readonly string[],
) {
  const selectedBranches = new Set(branchIds);
  return deduplicateDepartmentIds(
    departments
      .filter((department) =>
        department.is_active &&
        department.branch_id != null &&
        selectedBranches.has(department.branch_id)
      )
      .map((department) => department.id),
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

export function toggleSupervisorBranch(
  selection: SupervisorScopeSelection,
  branchId: string,
  selected: boolean,
  departments: readonly SupervisorScopeDepartment[],
): SupervisorScopeSelection {
  const branchIds = selected
    ? deduplicateBranchIds([...selection.branchIds, branchId])
    : deduplicateBranchIds(selection.branchIds).filter((id) => id !== branchId);
  const removedDepartmentIds = new Set(
    selected ? [] : activeDepartmentsForBranch(departments, branchId).map((department) => department.id),
  );
  return {
    branchIds,
    departmentIds: deduplicateDepartmentIds(selection.departmentIds)
      .filter((id) => !removedDepartmentIds.has(id)),
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
    return { valid: true, applies: false, branchIds: [], departmentIds: [] };
  }

  const branchIds = deduplicateBranchIds(selection.branchIds).filter(Boolean);
  if (branchIds.length === 0) {
    return { valid: false, error: 'SUPERVISOR_BRANCH_REQUIRED' };
  }

  const departmentIds = deduplicateDepartmentIds(selection.departmentIds);
  if (departmentIds.length === 0) {
    return { valid: false, error: 'SIN_DEPARTAMENTOS' };
  }

  const departmentById = new Map(
    departments
      .filter((department) => department.is_active && department.branch_id != null)
      .map((department) => [department.id, department] as const),
  );
  if (departmentIds.some((departmentId) => {
    const department = departmentById.get(departmentId);
    return !department?.branch_id || !branchIds.includes(department.branch_id);
  })) {
    return { valid: false, error: 'SUPERVISOR_DEPARTMENTS_INVALID' };
  }
  if (branchIds.some((branchId) =>
    !departmentIds.some((departmentId) => departmentById.get(departmentId)?.branch_id === branchId)
  )) {
    return { valid: false, error: 'SUPERVISOR_BRANCH_WITHOUT_DEPARTMENTS' };
  }

  return {
    valid: true,
    applies: true,
    branchIds,
    departmentIds,
  };
}

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
      branch_ids: validation.branchIds,
      department_ids: validation.departmentIds,
    },
  };
}