import * as XLSX from 'xlsx';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';

const exactHeaders=['Código de empleado','Nombre de empleado','DESCU-PRES','DESCU-CRED','ROTUR/FALT'];
const template=XLSX.utils.aoa_to_sheet([exactHeaders,['00001','Empleado Prueba',0,125,0]]);
const templateRows=XLSX.utils.sheet_to_json(template,{header:1});
if(JSON.stringify(templateRows[0])!==JSON.stringify(exactHeaders))throw new Error('Las columnas de plantilla no conservan el orden exacto.');

const book=XLSX.utils.book_new();
XLSX.utils.book_append_sheet(book,XLSX.utils.aoa_to_sheet([['Métrica','Valor'],['TOTAL GENERAL PAGADO',1000]]),'Resumen');
XLSX.utils.book_append_sheet(book,XLSX.utils.aoa_to_sheet([['Código','Neto'],['00001',1000]]),'Detalle');
XLSX.utils.book_append_sheet(book,template,'Descuentos');
const bytes=XLSX.write(book,{type:'buffer',bookType:'xlsx'});
const reopened=XLSX.read(bytes,{type:'buffer'});
if(reopened.SheetNames.join(',')!=='Resumen,Detalle,Descuentos')throw new Error('El Excel final no contiene las tres hojas requeridas.');

const pdf=new jsPDF();pdf.text('CONTROLHORARIO / OSINET',10,10);autoTable(pdf,{head:[['Empleado','Neto']],body:[['Empleado Prueba','1000.00']]});
const pdfBytes=new Uint8Array(pdf.output('arraybuffer'));const signature=String.fromCharCode(...pdfBytes.slice(0,4));
if(signature!=='%PDF'||pdfBytes.length<500)throw new Error('El PDF generado no es válido.');

console.log(`OK RC4 exports: plantilla exacta, Excel de ${bytes.length} bytes y PDF de ${pdfBytes.length} bytes.`);
