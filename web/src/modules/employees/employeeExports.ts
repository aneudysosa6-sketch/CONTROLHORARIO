import type { EmployeeRecord } from './employeeService';

const commonColumns = (employee: EmployeeRecord) => ({
  Código: employee.code,
  Empleado: employee.name,
  Cédula: employee.cedula,
  Empresa: employee.companyName,
  Sucursal: employee.branchName,
  Departamento: employee.departmentName,
  Cargo: employee.positionName,
  Estado: employee.status,
});

const exportRows = (employees: EmployeeRecord[], includeTermination: boolean) => employees.map((employee) => ({
  ...commonColumns(employee),
  ...(includeTermination ? {
    'Fecha de desvinculación': employee.terminationDate,
    'Motivo de desvinculación': employee.terminationReason,
    Observación: employee.terminationObservation,
    Responsable: employee.terminationActorName,
  } : {}),
}));

export async function exportEmployeesXlsx(
  employees: EmployeeRecord[],
  fileName: string,
  includeTermination = false,
) {
  const XLSX = await import('xlsx');
  const sheet = XLSX.utils.json_to_sheet(exportRows(employees, includeTermination));
  sheet['!cols'] = includeTermination
    ? [{ wch: 12 }, { wch: 34 }, { wch: 18 }, { wch: 28 }, { wch: 24 }, { wch: 24 }, { wch: 24 }, { wch: 15 }, { wch: 20 }, { wch: 42 }, { wch: 54 }, { wch: 30 }]
    : [{ wch: 12 }, { wch: 34 }, { wch: 18 }, { wch: 28 }, { wch: 24 }, { wch: 24 }, { wch: 24 }, { wch: 15 }];
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book, sheet, includeTermination ? 'Empleados dados de baja' : 'Empleados');
  XLSX.writeFile(book, fileName);
}

export async function exportEmployeesPdf(
  employees: EmployeeRecord[],
  fileName: string,
  includeTermination = false,
) {
  const [{ jsPDF }, { default: autoTable }] = await Promise.all([import('jspdf'), import('jspdf-autotable')]);
  const doc = new jsPDF({ orientation: 'landscape' });
  const title = includeTermination ? 'Empleados dados de baja' : 'Empleados operativos';
  doc.setFillColor(6, 25, 52);
  doc.rect(0, 0, 297, 28, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(18);
  doc.text('CONTROLHORARIO / OSINET', 14, 12);
  doc.setFontSize(11);
  doc.text(title, 14, 21);
  doc.setTextColor(20, 35, 55);
  doc.setFontSize(9);
  doc.text(`Registros: ${employees.length} · Generado: ${new Date().toLocaleString('es-DO')}`, 14, 36);
  const head = includeTermination
    ? [['Código', 'Empleado', 'Cédula', 'Empresa', 'Fecha baja', 'Motivo', 'Observación', 'Responsable']]
    : [['Código', 'Empleado', 'Cédula', 'Empresa', 'Sucursal', 'Departamento', 'Cargo', 'Estado']];
  const body = includeTermination
    ? employees.map((employee) => [employee.code, employee.name, employee.cedula, employee.companyName, employee.terminationDate, employee.terminationReason, employee.terminationObservation, employee.terminationActorName])
    : employees.map((employee) => [employee.code, employee.name, employee.cedula, employee.companyName, employee.branchName, employee.departmentName, employee.positionName, employee.status]);
  autoTable(doc, {
    startY: 42,
    head,
    body,
    styles: { fontSize: includeTermination ? 6.5 : 7.5, cellPadding: 2, overflow: 'linebreak' },
    headStyles: { fillColor: [0, 105, 180] },
  });
  doc.save(fileName);
}
