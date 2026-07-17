import { employeeService, type EmployeeRecord } from '../employees/employeeService';
import { journeyService, type Journey } from '../journeys/journeyService';
import { payrollService, type PayrollEmployee, type PayrollSnapshot } from '../payroll/payrollService';

export type ReportPayrollData = { snapshot: PayrollSnapshot | null; employees: PayrollEmployee[] };
export type IncidentReportRow = { id: string; journey: Journey; type: string; severity: string; message: string; minutes: number | null; resolved: boolean; createdAt: string };

export const reportDataService = {
  journeys: () => journeyService.list(),
  employees: () => employeeService.list(),
  inactiveEmployees: async () => (await employeeService.list()).filter((employee) => employee.status === 'desvinculado' || !employee.active),
  permissionsAndLicenses: async () => (await employeeService.list()).filter((employee) => employee.status === 'licencia'),
  payroll: async (): Promise<ReportPayrollData> => {
    const periods = await payrollService.listPeriods();
    if (!periods[0]) return { snapshot: null, employees: [] };
    const [snapshot, employees] = await Promise.all([payrollService.get(periods[0].id), payrollService.listEmployees()]);
    return { snapshot, employees };
  },
  incidents: async (): Promise<IncidentReportRow[]> => (await journeyService.list()).flatMap((journey) => journey.incidents.map((incident) => ({ id: incident.id, journey, type: incident.type, severity: incident.severity, message: incident.message, minutes: incident.minutes, resolved: incident.resolved, createdAt: incident.createdAt }))),
};

export type { EmployeeRecord, Journey };
