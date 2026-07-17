import type { Session } from '../../types';
import { employeeService, type EmployeeRecord } from '../employees/employeeService';
import { journeyService, type Journey } from '../journeys/journeyService';
import { reportDataService } from '../reports/reportDataService';
import { dashboardService, type DashboardSnapshot } from './dashboardService';

export type ExecutiveDashboardData = { snapshot: DashboardSnapshot; employees: EmployeeRecord[]; journeys: Journey[]; payroll: Awaited<ReturnType<typeof reportDataService.payroll>> };

export const executiveDashboardService = {
  async load(session: Session): Promise<ExecutiveDashboardData> {
    const [snapshot, employees, journeys, payroll] = await Promise.all([
      dashboardService.load(session),
      employeeService.list(),
      journeyService.list(),
      reportDataService.payroll(),
    ]);
    return { snapshot, employees, journeys, payroll };
  },
};
