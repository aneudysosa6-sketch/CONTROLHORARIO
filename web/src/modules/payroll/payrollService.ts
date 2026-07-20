import { getSupabaseClient } from '../../infrastructure/supabase/client';

export type PayrollState='BORRADOR'|'CALCULADA'|'EN_REVISION'|'APROBADA'|'CERRADA'|'ANULADA';
export type PayrollPeriod={id:string;fecha_inicio:string;fecha_fin:string;tipo_periodo:'QUINCENAL'|'MENSUAL';estado:PayrollState;nomina_id:string;version_calculo:number;desactualizada:boolean;errores:unknown[];resumen:PayrollSummary};
export type PayrollSummary={empleados?:number;total_sueldos?:number;total_horas_extras?:number;total_incentivos?:number;total_prestamos?:number;total_creditos?:number;total_impuestos?:number;total_otros_descuentos?:number;total_general_pagado?:number};
export type PayrollDetail={id:string;empleado_id:string;codigo_empleado:string;nombre_empleado:string;tipo_pago:string;sueldo_base:number;dias_trabajados:number;horas_normales:number;horas_extras:number;horas_nocturnas:number;valor_hora:number;valor_hora_extra:number;pago_normal:number;total_horas_extras:number;total_nocturnas:number;incentivos:number;afp:number;sfs:number;otros_impuestos:number;total_impuestos:number;descuento_prestamo:number;descuento_credito:number;descuento_fijo:number;rotura_falta:number;otros_descuentos:number;total_descuentos:number;bruto:number;neto:number;version_calculo:number;formula:string};
export type PayrollEmployee={id:string;codigo:string;nombre:string;salario:number|null;tipo_pago:string|null};
export type PayrollLoan={id:string;empleado_id:string;monto_total:number;total_pagado:number;pendiente:number;descuento_periodo:number;estado:string;fecha_inicio:string;fecha_final?:string;motivo:string};
export type PayrollCredit={id:string;empleado_id:string;monto_total:number;total_descontado:number;pendiente:number;descuento_periodo:number;estado:string;fecha_inicio:string;fecha_final?:string;motivo:string};
export type PayrollAudit={id:number;accion:string;motivo?:string;fecha:string;empleado_id?:string;antes?:unknown;despues?:unknown};
export type PayrollSnapshot={periodo:PayrollPeriod;nomina:{id:string;estado:PayrollState;version_calculo:number;formula:string;desactualizada:boolean;errores:unknown[];resumen:PayrollSummary;calculada_en?:string};detalles:PayrollDetail[];ajustes:unknown[];prestamos:PayrollLoan[];creditos:PayrollCredit[];auditoria:PayrollAudit[]};
export type AdjustmentRow={codigo:string;tipo:'DESCU-PRES'|'DESCU-CRED'|'ROTUR/FALT'|'OTRO_DESCUENTO'|'INCENTIVO';monto:number};
export type PayrollDashboardBlocker={employee_id?:string;employee_code:string;employee_name:string;reason:string;message:string};
export type PayrollDashboardWarning=PayrollDashboardBlocker&{journeys?:number;amount?:number};
export type PayrollDashboardEmployee={employee_id:string;employee_code:string;employee_name:string;pay_type:string;salary:number;journeys:number|null;normal_hours:number;overtime_hours:number;gross:number;afp:number;sfs:number;loans:number;discounts:number;net:number};
export type PayrollDashboardTotal={source:'CLOSED'|'REAL_TIME'|'UNAVAILABLE';as_of_date:string;period_id:string|null;period_start:string;period_end:string;period_type:'QUINCENAL'|'MENSUAL';payroll_state:PayrollState|'PREVIEW';total:number|null;employees_included:number;journeys_used:number;total_hours:number;employees:PayrollDashboardEmployee[];blockers:PayrollDashboardBlocker[];warnings:PayrollDashboardWarning[];reason:string|null};

export class PayrollApiError extends Error{constructor(message:string,readonly code?:string,readonly details?:string,readonly hint?:string){super(message);this.name='PayrollApiError'}}
function fail(error:{message:string;code?:string;details?:string;hint?:string}|null):never{throw new PayrollApiError(error?.message??'Error desconocido de nómina',error?.code,error?.details,error?.hint)}
async function rpc<T>(name:string,args:Record<string,unknown>={}){const{data,error}=await getSupabaseClient().rpc(name,args);if(error)fail(error);return data as T}

export const payrollService={
 listPeriods:()=>rpc<PayrollPeriod[]>('listar_nomina_periodos'),
 listEmployees:()=>rpc<PayrollEmployee[]>('listar_empleados_nomina'),
 get:(periodId:string)=>rpc<PayrollSnapshot>('obtener_nomina',{p_periodo:periodId}),
 async dashboardTotal(workDate:string){
  try{
   const result=await rpc<PayrollDashboardTotal>('obtener_total_nomina_dashboard',{p_fecha:workDate});
   console.info('PAYROLL_DASHBOARD',{
    empleadosIncluidos:result.employees_included,
    empleados:result.employees.map(employee=>employee.employee_code),
    jornadasUtilizadas:result.journeys_used,
    horas:result.total_hours,
    salario:result.employees.map(employee=>({employeeCode:employee.employee_code,value:employee.salary})),
    bloqueos:result.blockers.map(blocker=>({employeeCode:blocker.employee_code,reason:blocker.reason})),
    totalCalculado:result.total,
    motivo:result.reason,
   });
   return result;
  }catch(error){
   console.error('PAYROLL_DASHBOARD',{empleadosIncluidos:0,jornadasUtilizadas:0,horas:0,salario:[],bloqueos:[],totalCalculado:null,motivo:error instanceof Error?error.message:'PAYROLL_DASHBOARD_RPC_ERROR'});
   throw error;
  }
 },
 createPeriod:(from:string,to:string,type:'QUINCENAL'|'MENSUAL')=>rpc<string>('crear_periodo_nomina',{p_inicio:from,p_fin:to,p_tipo:type}),
 async calculate(periodId:string){const result=await rpc<{periodo_id:string;nomina_id:string;version:number;resumen:PayrollSummary}>('calcular_nomina',{p_periodo:periodId});const{publishNotification}=await import('../notifications/notificationIntegration');publishNotification('payroll_generated','Nómina generada',{periodId,result},`payroll-generated:${periodId}:${result.version}`);return result},
 changeState:(periodId:string,state:PayrollState,reason:string)=>rpc<void>('cambiar_estado_nomina',{p_periodo:periodId,p_estado:state,p_motivo:reason}),
 async applyAdjustments(periodId:string,rows:AdjustmentRow[],origin:'MANUAL'|'EXCEL',reason:string){const result=await rpc<{aplicado:boolean;filas?:number;errores:{codigo:string;error:string}[]}>('aplicar_descuentos_nomina',{p_periodo:periodId,p_filas:rows,p_origen:origin,p_motivo:reason});if(!result.aplicado)throw new PayrollApiError('La carga fue rechazada completa; no se aplicó ninguna fila.','PAYROLL_IMPORT_REJECTED',JSON.stringify(result.errores));return result},
 createLoan:(employeeId:string,total:number,perPeriod:number,date:string,reason:string)=>rpc<string>('crear_prestamo_nomina',{p_empleado:employeeId,p_total:total,p_descuento:perPeriod,p_fecha:date,p_motivo:reason}),
 async changeLoanState(id:string,state:'APROBADO'|'ENTREGADO'|'CANCELADO',reason:string){await rpc<void>('cambiar_estado_prestamo_nomina',{p_prestamo:id,p_estado:state,p_motivo:reason});if(state==='APROBADO'||state==='CANCELADO'){const{publishNotification}=await import('../notifications/notificationIntegration');publishNotification(state==='APROBADO'?'loan_approved':'loan_rejected',state==='APROBADO'?'Préstamo aprobado':'Préstamo rechazado',{loanId:id,reason},`loan-state:${id}:${state}`)}},
 createCredit:(employeeId:string,total:number,perPeriod:number,date:string,reason:string)=>rpc<string>('crear_credito_nomina',{p_empleado:employeeId,p_total:total,p_descuento:perPeriod,p_fecha:date,p_motivo:reason}),
 cancelCredit:(id:string,reason:string)=>rpc<void>('cancelar_credito_nomina',{p_credito:id,p_motivo:reason}),
 registerExport:(periodId:string,type:'PLANTILLA'|'IMPORTACION'|'EXCEL_FINAL'|'PDF_FINAL',name:string,metadata:Record<string,unknown>)=>rpc<string>('registrar_exportacion_nomina',{p_periodo:periodId,p_tipo:type,p_nombre:name,p_metadata:metadata}),
};
