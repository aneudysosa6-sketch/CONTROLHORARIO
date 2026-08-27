import jsPDF from 'jspdf';

export interface FaceRegistrationInstruction {
  employee_id: string;
  employee_name?: string;
}

/** Compatibility export for employee creation: the initial PDF contains no QR or token. */
export async function downloadFaceInvitationPdf(employee: FaceRegistrationInstruction) {
  const document = new jsPDF();
  document.setFontSize(20);
  document.text('CONTROL HORARIO', 20, 28);
  document.setFontSize(14);
  document.text('Registro facial pendiente', 20, 45);
  document.setFontSize(11);
  document.text('Empleado: ' + (employee.employee_name || employee.employee_id), 20, 60);
  document.text('Registre el rostro desde un Terminal Android autorizado.', 20, 76);
  document.text('Este documento no contiene QR, token ni credencial de dispositivo.', 20, 86);
  document.save('registro-facial-pendiente-' + employee.employee_id + '.pdf');
}
