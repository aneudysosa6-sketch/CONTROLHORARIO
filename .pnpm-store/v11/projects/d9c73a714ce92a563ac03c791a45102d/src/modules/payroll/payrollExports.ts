import type { AdjustmentRow,PayrollEmployee,PayrollSnapshot } from './payrollService';

export const PAYROLL_TEMPLATE_HEADERS=['Código de empleado','Nombre de empleado','DESCU-PRES','DESCU-CRED','ROTUR/FALT'] as const;
export type ImportIssue={row:number;field:string;message:string};
export type ImportPreview={rows:AdjustmentRow[];issues:ImportIssue[];sourceRows:number};
const money=(value:number|undefined)=>Number(value??0).toFixed(2);
function save(blob:Blob,name:string){const href=URL.createObjectURL(blob);const link=document.createElement('a');link.href=href;link.download=name;link.click();setTimeout(()=>URL.revokeObjectURL(href),0)}

export async function downloadPayrollTemplate(employees:PayrollEmployee[],name='plantilla-descuentos-nomina.xlsx'){
 const XLSX=await import('xlsx');
 const rows=employees.slice().sort((a,b)=>a.codigo.localeCompare(b.codigo,undefined,{numeric:true})).map(e=>({
  [PAYROLL_TEMPLATE_HEADERS[0]]:e.codigo,[PAYROLL_TEMPLATE_HEADERS[1]]:e.nombre,[PAYROLL_TEMPLATE_HEADERS[2]]:0,[PAYROLL_TEMPLATE_HEADERS[3]]:0,[PAYROLL_TEMPLATE_HEADERS[4]]:0,
 }));
 const sheet=XLSX.utils.json_to_sheet(rows,{header:[...PAYROLL_TEMPLATE_HEADERS]});sheet['!cols']=[{wch:20},{wch:38},{wch:16},{wch:16},{wch:16}];
 const book=XLSX.utils.book_new();XLSX.utils.book_append_sheet(book,sheet,'Descuentos');XLSX.writeFile(book,name);
}

export async function parsePayrollTemplate(file:File,employees:PayrollEmployee[]):Promise<ImportPreview>{
 const XLSX=await import('xlsx');
 const book=XLSX.read(await file.arrayBuffer(),{type:'array'});const sheet=book.Sheets[book.SheetNames[0]];if(!sheet)return{rows:[],issues:[{row:1,field:'archivo',message:'El archivo no contiene hojas.'}],sourceRows:0};
 const matrix=XLSX.utils.sheet_to_json<unknown[]>(sheet,{header:1,defval:null,raw:true});const headers=(matrix[0]??[]).map(v=>String(v??'').trim());const issues:ImportIssue[]=[];
 PAYROLL_TEMPLATE_HEADERS.forEach((header,index)=>{if(headers[index]!==header)issues.push({row:1,field:header,message:`Se esperaba la columna ${index+1}: ${header}.`})});
 if(headers.length!==PAYROLL_TEMPLATE_HEADERS.length)issues.push({row:1,field:'columnas',message:'La plantilla debe contener exactamente cinco columnas.'});
 const byCode=new Map(employees.map(e=>[e.codigo,e]));const seen=new Set<string>();const rows:AdjustmentRow[]=[];
 matrix.slice(1).forEach((raw,index)=>{const number=index+2;const values=raw as unknown[];if(values.every(v=>v===null||String(v).trim()===''))return;const code=String(values[0]??'').trim();const employee=byCode.get(code);
  if(!employee)issues.push({row:number,field:PAYROLL_TEMPLATE_HEADERS[0],message:'Código de empleado inexistente.'});
  if(seen.has(code))issues.push({row:number,field:PAYROLL_TEMPLATE_HEADERS[0],message:'Código duplicado en la plantilla.'});seen.add(code);
  if(employee&&String(values[1]??'').trim()!==employee.nombre)issues.push({row:number,field:PAYROLL_TEMPLATE_HEADERS[1],message:'El nombre no coincide con el código.'});
  ([['DESCU-PRES',values[2]],['DESCU-CRED',values[3]],['ROTUR/FALT',values[4]]] as const).forEach(([type,value],column)=>{const amount=typeof value==='number'?value:Number(String(value??'').replace(',','.'));if(!Number.isFinite(amount)||amount<0)issues.push({row:number,field:PAYROLL_TEMPLATE_HEADERS[column+2],message:'Debe ser un número mayor o igual a cero.'});else if(amount>0)rows.push({codigo:code,tipo:type,monto:amount})});
 });
 return{rows,issues,sourceRows:Math.max(0,matrix.length-1)};
}

export async function downloadFinalExcel(snapshot:PayrollSnapshot,name:string){
 const XLSX=await import('xlsx');
 const s=snapshot.nomina.resumen??{};const summary=[
  ['Cantidad de empleados',s.empleados??0],['Total Sueldos',s.total_sueldos??0],['Total Horas Extras',s.total_horas_extras??0],['Total Incentivos',s.total_incentivos??0],['Total Préstamos',s.total_prestamos??0],['Total Créditos',s.total_creditos??0],['Total Impuestos',s.total_impuestos??0],['Total Otros Descuentos',s.total_otros_descuentos??0],['TOTAL GENERAL PAGADO',s.total_general_pagado??0],
 ];
 const details=snapshot.detalles.map(d=>({Empleado:d.nombre_empleado,Código:d.codigo_empleado,'Sueldo mensual':d.sueldo_base,'Horas normales':d.horas_normales,'Pago normal':d.pago_normal,'Horas extras':d.horas_extras,'Valor hora extra':d.valor_hora_extra,'Pago extras':d.total_horas_extras,Incentivos:d.incentivos,Descuentos:d.total_descuentos,Impuestos:d.total_impuestos,Bruto:d.bruto,Neto:d.neto}));
 const discounts=snapshot.detalles.map(d=>({Empleado:d.nombre_empleado,Código:d.codigo_empleado,'DESCU-PRES':d.descuento_prestamo,'DESCU-CRED':d.descuento_credito,'ROTUR/FALT':d.rotura_falta,'Descuento fijo':d.descuento_fijo,Otros:d.otros_descuentos,Total:d.total_descuentos}));
 const book=XLSX.utils.book_new();XLSX.utils.book_append_sheet(book,XLSX.utils.aoa_to_sheet([['Resumen de nómina','Valor'],...summary]),'Resumen');XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet(details),'Detalle');XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet(discounts),'Descuentos');XLSX.writeFile(book,name);
}

export async function downloadPayrollPdf(snapshot:PayrollSnapshot,company:string,name:string){
 const[{jsPDF},{default:autoTable}]=await Promise.all([import('jspdf'),import('jspdf-autotable')]);
 const doc=new jsPDF({orientation:'landscape'});const period=snapshot.periodo;const s=snapshot.nomina.resumen??{};
 doc.setFillColor(6,25,52);doc.rect(0,0,297,30,'F');doc.setTextColor(255,255,255);doc.setFontSize(20);doc.text('CONTROLHORARIO / OSINET',14,13);doc.setFontSize(11);doc.text(`Nómina ${period.fecha_inicio} al ${period.fecha_fin} · ${period.estado}`,14,22);
 doc.setTextColor(20,35,55);doc.setFontSize(11);doc.text(`Empresa: ${company}`,14,39);doc.text(`Empleados: ${s.empleados??0}   Bruto: RD$ ${money(snapshot.detalles.reduce((a,d)=>a+d.bruto,0))}   Descuentos: RD$ ${money(snapshot.detalles.reduce((a,d)=>a+d.total_descuentos,0))}   Neto: RD$ ${money(s.total_general_pagado)}`,14,47);
 autoTable(doc,{startY:55,head:[['Código','Empleado','Base','Horas','Extras','Nocturnas','Impuestos','Descuentos','Neto']],body:snapshot.detalles.map(d=>[d.codigo_empleado,d.nombre_empleado,money(d.sueldo_base),money(d.horas_normales),money(d.horas_extras),money(d.horas_nocturnas),money(d.total_impuestos),money(d.total_descuentos),money(d.neto)]),styles:{fontSize:8},headStyles:{fillColor:[0,105,180]}});
 const y=(doc as unknown as{lastAutoTable?:{finalY:number}}).lastAutoTable?.finalY??170;doc.setFontSize(8);doc.text(`Generado: ${new Date().toLocaleString()} · Motor: ${snapshot.nomina.formula} · Versión: ${snapshot.nomina.version_calculo}`,14,Math.min(y+10,200));save(doc.output('blob'),name);
}
