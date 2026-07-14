import { getSupabaseClient } from '../../infrastructure/supabase/client';

export type LoanMovement={id:string;tipo:string;monto:number;saldo_anterior:number;saldo_posterior:number;estado:string;referencia?:string;creado_en:string;periodo_id?:string};
export type EmployeeLoan={id:string;monto_total:number;pagado:number;pendiente:number;descuento_periodo:number;estado:string;fecha_inicio:string;motivo:string;movimientos:LoanMovement[]};
export type LoanRequest={id:string;empleado_id?:string;codigo?:string;empleado?:string;monto_solicitado:number;descuento_periodo:number;motivo:string;estado:string;origen:string;observacion_revision?:string;creada_en:string;actualizada_en:string;prestamo_id?:string};
export type EmployeePortal={perfil:{id:string;codigo:string;nombre:string;correo?:string;telefono?:string;estado:string;fecha_ingreso?:string;sucursal?:string;departamento?:string;puesto?:string};ganancias:{periodo_inicio:string;periodo_fin:string;corte:string;minutos_normales:number;minutos_extra:number;pago_normal:number;pago_extra:number;incentivo:number;total:number;formula:string};prestamos:EmployeeLoan[];solicitudes:LoanRequest[]};

function message(error:{message:string}|null){return error?.message??'No fue posible completar la operación.'}
async function rpc<T>(name:string,args:Record<string,unknown>={}){const{data,error}=await getSupabaseClient().rpc(name,args);if(error)throw new Error(message(error));return data as T}

export const employeePortalService={
 get:()=>rpc<EmployeePortal>('obtener_portal_empleado'),
 requestLoan:(amount:number,discount:number,reason:string,idempotency:string,origin:'WEB'|'ANDROID'='WEB')=>rpc<LoanRequest>('crear_solicitud_prestamo',{p_monto:amount,p_descuento:discount,p_motivo:reason,p_idempotency:idempotency,p_origen:origin}),
 cancelRequest:(id:string,origin:'WEB'|'ANDROID'='WEB')=>rpc<{id:string;estado:string}>('cancelar_solicitud_prestamo',{p_solicitud:id,p_origen:origin}),
 listRequests:(state?:string,search?:string)=>rpc<LoanRequest[]>('listar_solicitudes_prestamo_admin',{p_estado:state||null,p_busqueda:search?.trim()||null}),
 manageRequest:(id:string,action:'REVISAR'|'ACEPTAR'|'DENEGAR'|'CONFIRMAR_EFECTIVO',reason:string)=>rpc<{id:string;estado:string;prestamo_id?:string}>('gestionar_solicitud_prestamo',{p_solicitud:id,p_accion:action,p_motivo:reason,p_origen:'WEB'}),
};
