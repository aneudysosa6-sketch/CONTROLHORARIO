export interface EmployeeMutationInput {
  id?: string;
  name: string;
  cedula?: string;
  email?: string;
  phone?: string;
  startDate?: string;
  status: string;
  active: boolean;
  salary?: number | null;
  payType?: string;
  branchId?: string;
  departmentId?: string;
  positionId?: string;
}

export const buildEmployeeMutationPayload = (input: EmployeeMutationInput, code?: string) => ({
  id: input.id,
  ...(code ? { code } : {}),
  name: input.name,
  cedula: input.cedula,
  email: input.email,
  phone: input.phone,
  startDate: input.startDate,
  status: input.status,
  active: input.active,
  salary: input.salary,
  payType: input.payType,
  branchId: input.branchId,
  departmentId: input.departmentId,
  positionId: input.positionId,
});
