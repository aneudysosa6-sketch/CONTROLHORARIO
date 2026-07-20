import type { Session } from '../../types';
import { employeeService, type EmployeeRecord } from '../employees/employeeService';
import { journeyService, type Journey } from '../journeys/journeyService';
import { payrollService, type PayrollDashboardTotal } from '../payroll/payrollService';
import { reportDataService } from '../reports/reportDataService';
import { dashboardService, type DashboardSnapshot } from './dashboardService';

export type ExecutiveDashboardData = { snapshot: DashboardSnapshot; employees: EmployeeRecord[]; journeys: Journey[]; payroll: Awaited<ReturnType<typeof reportDataService.payroll>>; payrollDashboard: PayrollDashboardTotal };

export const executiveDashboardService = {
  async load(session: Session): Promise<ExecutiveDashboardData> {
    const snapshot = await dashboardService.load(session);
    const [employees, journeys, payroll, payrollDashboard] = await Promise.all([
      employeeService.list(),
      journeyService.list(),
      reportDataService.payroll(),
      payrollService.dashboardTotal(snapshot.workDate),
    ]);
    return { snapshot, employees, journeys, payroll, payrollDashboard };
  },
  loadPayrollDashboard: (workDate: string) => payrollService.dashboardTotal(workDate),
};
