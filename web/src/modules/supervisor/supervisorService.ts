import { getSupabaseClient } from '../../infrastructure/supabase/client';

export type SupervisorEmployee={id:string;codigo:string;nombre:string;sucursal_id:string;sucursal:string;departamento_id:string;departamento:string;cargo:string;estado_laboral:string;jornada_habilitada:boolean;telefono:string|null;estado_jornada:string;ultima_accion:string|null;incidencias_abiertas:number;horario_resumen:string};
export type SupervisorJourney={id:string;empleado_id:string;codigo:string;nombre:string;sucursal:string;departamento:string;fecha_laboral:string;estado:string;iniciado_en:string|null;pausa_iniciada_en:string|null;pausa_finalizada_en:string|null;finalizado_en:string|null;minutos_trabajados:number;minutos_pausa:number;revision_pendiente:boolean;severidad:string;version_sync:number;incidencias:Record<string,unknown>[];conflictos:Record<string,unknown>[]};
export type SupervisorIncident={id:string;jornada_id:string;empleado_id:string;codigo:string;nombre:string;sucursal:string;departamento:string;tipo:string;severidad:string;minutos:number|null;mensaje:string;leida:boolean;resuelta:boolean;creada_en:string};
export type SupervisorSchedule={id:string;empleado_id:string;codigo:string;nombre:string;sucursal:string;departamento:string;fecha_vigencia:string;fecha_fin:string|null;hora_entrada:string;hora_salida:string;inicio_almuerzo:string|null;duracion_almuerzo_min:number;dias_laborales:number[];tolerancia_min:number;activo:boolean};
export type SupervisorDashboard={fecha_laboral:string;total_empleados:number;activos:number;sin_iniciar:number;en_curso:number;en_pausa:number;finalizadas:number;pendientes:number;incidencias_nuevas:number;jornadas_deshabilitadas:number;sin_iniciar_empleados:{id:string;codigo:string;nombre:string}[];recientes:{id:string;empleado_id:string;codigo:string;nombre:string;estado:string;actualizada_en:string;severidad:string}[];incidencias:{id:string;jornada_id:string;empleado_id:string;nombre:string;tipo:string;severidad:string;mensaje:string;creada_en:string}[]};
export type SupervisorAudit={id:number;empleado_id:string|null;jornada_id:string|null;entidad:string;accion:string;antes:unknown;despues:unknown;motivo:string;actor_rol:string;fecha:string};

const rpc=async<T>(name:string,args:Record<string,unknown>={})=>{const{data,error}=await getSupabaseClient().rpc(name,args);if(error)throw error;return data as T};
export const supervisorService={
 dashboard:()=>rpc<SupervisorDashboard>('dashboard_supervisor'),
 employees:()=>rpc<SupervisorEmployee[]>('listar_empleados_supervisor'),
 journeys:(date?:string)=>rpc<SupervisorJourney[]>('listar_jornadas_supervisor',{p_fecha:date||null}),
 incidents:()=>rpc<SupervisorIncident[]>('listar_incidencias_supervisor'),
 schedules:()=>rpc<SupervisorSchedule[]>('listar_horarios_supervisor'),
 async audit(){const{data,error}=await getSupabaseClient().from('supervisor_auditoria').select('id,empleado_id,jornada_id,entidad,accion,antes,despues,motivo,actor_rol,fecha').order('fecha',{ascending:false}).limit(200);if(error)throw error;return(data??[])as SupervisorAudit[]},
 setAttendance:(employeeId:string,enabled:boolean,reason:string)=>rpc<void>('establecer_jornada_habilitada',{p_empleado:employeeId,p_habilitada:enabled,p_motivo:reason}),
 decide:(journeyId:string,decision:string,reason:string)=>rpc<void>('resolver_jornada_pendiente',{p_jornada:journeyId,p_decision:decision,p_motivo:reason}),
 correct:(journeyId:string,values:{start:string;breakStart:string|null;breakEnd:string|null;end:string},reason:string)=>rpc<void>('corregir_jornada_supervisor',{p_jornada:journeyId,p_inicio:values.start,p_pausa_inicio:values.breakStart,p_pausa_fin:values.breakEnd,p_fin:values.end,p_motivo:reason}),
 manual:(employeeId:string,date:string,values:{start:string;breakStart:string|null;breakEnd:string|null;end:string},reason:string)=>rpc<string>('registrar_jornada_manual_supervisor',{p_empleado:employeeId,p_fecha:date,p_inicio:values.start,p_pausa_inicio:values.breakStart,p_pausa_fin:values.breakEnd,p_fin:values.end,p_motivo:reason}),
  resolveIncident:(id:string,resolved:boolean,comment:string)=>rpc<void>('resolver_incidencia_supervisor',{p_incidencia:id,p_resuelta:resolved,p_comentario:comment}),
  markIncidentRead:(id:string)=>rpc<void>('marcar_incidencia_jornada_leida',{p_incidencia:id}),
 saveSchedule:(value:{employeeId:string;date:string;start:string;end:string;lunch:string|null;duration:number;days:number[];tolerance:number;reason:string})=>rpc<string>('guardar_horario_supervisor',{p_empleado:value.employeeId,p_fecha:value.date,p_entrada:value.start,p_salida:value.end,p_almuerzo:value.lunch,p_duracion:value.duration,p_dias:value.days,p_tolerancia:value.tolerance,p_motivo:value.reason}),
};
