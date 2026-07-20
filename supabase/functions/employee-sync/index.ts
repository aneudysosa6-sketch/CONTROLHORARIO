import { createClient } from '@supabase/supabase-js'

const cors={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'content-type,x-device-id,x-device-credential',
}
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}})
const text=(value:unknown)=>typeof value==='string'?value.trim():''
const hash=async(value:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))).map(x=>x.toString(16).padStart(2,'0')).join('')
const validUuid=(value:string)=>/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
const afterCursor=(row:{updated_at:string,id:string},updatedAt:string,id:string)=>!updatedAt||row.updated_at>updatedAt||(row.updated_at===updatedAt&&row.id>id)
const validEmployeeCode=(value:string)=>/^[0-9]{5,12}$/.test(value)
const validEmbedding=(value:unknown):value is number[]=>Array.isArray(value)&&value.length===128&&value.every(item=>typeof item==='number'&&Number.isFinite(item))
type ErrorInfo={error:string;details:string|null;hint:string|null;code:string|null;stacktrace:string|null}
const errorInfo=(value:unknown):ErrorInfo=>{
  const record=value&&typeof value==='object'?value as Record<string,unknown>:{}
  const message=text(record.message)||text(record.error)||(value instanceof Error?value.message:'')||String(value)
  return{error:message,details:text(record.details)||null,hint:text(record.hint)||null,code:text(record.code)||null,stacktrace:value instanceof Error?value.stack??null:text(record.stack)||null}
}
const stageFailure=(requestId:string,stage:string,value:unknown,companyId:string|null,status=500)=>{
  const info=errorInfo(value)
  console.error('EmployeeSync etapa fallida',{request_id:requestId,stage,company_id:companyId,...info,postgrest_response:value})
  return json({...info,stage,company_id:companyId,diagnostic_request_id:requestId},status)
}

Deno.serve(async request=>{
  const requestId=crypto.randomUUID()
  let diagnosticCompanyId:string|null=null
  console.log('EmployeeSync request recibido',{request_id:requestId,method:request.method})
  if(request.method==='OPTIONS')return new Response('ok',{headers:cors})
  if(request.method!=='POST')return json({error:'Método no permitido'},405)
  try{
    const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const deviceId=text(request.headers.get('x-device-id')),credential=text(request.headers.get('x-device-credential'))
    console.log('EmployeeSync credenciales recibidas',{request_id:requestId,device_id:deviceId,credential_present:credential.length>0,credential_length:credential.length})
    if(!validUuid(deviceId)||credential.length!==64)return json({error:'Credencial de dispositivo requerida'},401)
    const admin=createClient(url,service,{auth:{persistSession:false}}),now=new Date().toISOString()
    let authResult
    try{
      authResult=await admin.from('credenciales_dispositivo').select('empresa_id,dispositivo_id').eq('dispositivo_id',deviceId).eq('token_hash',await hash(credential)).is('revocado_at',null).gt('expires_at',now).maybeSingle()
      console.log('EmployeeSync respuesta PostgREST autenticación',{request_id:requestId,data:authResult.data,error:authResult.error,status:authResult.status,statusText:authResult.statusText})
    }catch(error){return stageFailure(requestId,'autenticacion_dispositivo',error,null)}
    if(authResult.error)return stageFailure(requestId,'autenticacion_dispositivo',authResult.error,null,authResult.status||500)
    const auth=authResult.data
    if(!auth)return json({error:'Dispositivo no autorizado o credencial vencida'},401)
    diagnosticCompanyId=auth.empresa_id
    console.log('EmployeeSync dispositivo autenticado',{request_id:requestId,device_id:deviceId,company_id:auth.empresa_id})
    console.log('EmployeeSync company_id leído',{request_id:requestId,company_id:auth.empresa_id})
    let deviceResult
    try{
      deviceResult=await admin.from('dispositivos_android').select('id,empresa_id').eq('id',deviceId).eq('empresa_id',auth.empresa_id).eq('estado','activo').maybeSingle()
      console.log('EmployeeSync respuesta PostgREST dispositivo',{request_id:requestId,data:deviceResult.data,error:deviceResult.error,status:deviceResult.status,statusText:deviceResult.statusText})
    }catch(error){return stageFailure(requestId,'validacion_dispositivo',error,auth.empresa_id)}
    if(deviceResult.error)return stageFailure(requestId,'validacion_dispositivo',deviceResult.error,auth.empresa_id,deviceResult.status||500)
    const device=deviceResult.data
    if(!device)return json({error:'Dispositivo revocado o empresa incorrecta'},403)
    console.log('EmployeeSync dispositivo activo validado',{request_id:requestId,device_id:device.id,company_id:device.empresa_id})

    const body=await request.json().catch(()=>({})) as Record<string,unknown>
    const targeted=Object.prototype.hasOwnProperty.call(body,'employee_code'),employeeCode=text(body.employee_code)
    if(targeted&&!validEmployeeCode(employeeCode))return json({error:'employee_code inválido'},400)
    const cursor:Record<string,unknown>=targeted?{}:((body.cursor??{}) as Record<string,unknown>),cursorUpdatedAt=text(cursor.updated_at),cursorId=text(cursor.id)
    console.log('EmployeeSync cursor recibido',{request_id:requestId,company_id:auth.empresa_id,cursor_updated_at:cursorUpdatedAt||null,cursor_id:cursorId||null})
    if(targeted)console.log('FACE_CROSS_DEVICE_SYNC',{employeeCode,targetedSyncStarted:true})
    if(cursorUpdatedAt&&Number.isNaN(Date.parse(cursorUpdatedAt)))return json({error:'Cursor updated_at inválido'},400)
    if(cursorId&&!validUuid(cursorId))return json({error:'Cursor id inválido'},400)

    let query=admin.from('empleados').select('id,codigo_empleado,nombre_completo,correo,telefono,sucursal_id,departamento_id,puesto_id,supervisor_id,estado_laboral,fecha_ingreso,salario,tipo_pago,activo,jornada_habilitada,updated_at,face_embedding').eq('empresa_id',auth.empresa_id)
    if(targeted)query=query.eq('codigo_empleado',employeeCode).limit(1)
    else{query=query.order('updated_at').order('id').limit(1001);if(cursorUpdatedAt)query=query.gte('updated_at',cursorUpdatedAt)}
    let employeeResult
    try{
      employeeResult=await query
      console.log('EmployeeSync respuesta PostgREST consulta SQL',{request_id:requestId,company_id:auth.empresa_id,rows:employeeResult.data?.length??0,error_code:employeeResult.error?.code??null,status:employeeResult.status,statusText:employeeResult.statusText})
    }catch(error){return stageFailure(requestId,'consulta_empleados',error,auth.empresa_id)}
    if(employeeResult.error)return stageFailure(requestId,'consulta_empleados',employeeResult.error,auth.empresa_id,employeeResult.status||500)
    const data=employeeResult.data
    const changed=targeted?(data??[]):(data??[]).filter(row=>afterCursor(row,cursorUpdatedAt,cursorId)),page=targeted?changed.slice(0,1):changed.slice(0,500),last=page.at(-1)
    console.log('EmployeeSync empleados encontrados',{request_id:requestId,company_id:auth.empresa_id,query_rows:data?.length??0,after_cursor:changed.length,page_rows:page.length})
    const branchIds=[...new Set(page.map(row=>row.sucursal_id).filter(Boolean))] as string[]
    const departmentIds=[...new Set(page.map(row=>row.departamento_id).filter(Boolean))] as string[]
    const positionIds=[...new Set(page.map(row=>row.puesto_id).filter(Boolean))] as string[]
    const supervisorIds=[...new Set(page.map(row=>row.supervisor_id).filter(Boolean))] as string[]
    const employeeIds=page.map(row=>row.id) as string[]
    const empty={data:[] as Record<string,unknown>[],error:null,status:200,statusText:'Sin IDs'}
    let branchResult,departmentResult,positionResult,supervisorResult,scheduleResult
    try{
      ;[branchResult,departmentResult,positionResult,supervisorResult,scheduleResult]=await Promise.all([
        branchIds.length?admin.from('branches').select('id,name').eq('company_id',auth.empresa_id).in('id',branchIds):Promise.resolve(empty),
        departmentIds.length?admin.from('departments').select('id,name').eq('company_id',auth.empresa_id).in('id',departmentIds):Promise.resolve(empty),
        positionIds.length?admin.from('positions').select('id,name').eq('company_id',auth.empresa_id).in('id',positionIds):Promise.resolve(empty),
        supervisorIds.length?admin.from('empleados').select('id,nombre_completo').eq('empresa_id',auth.empresa_id).in('id',supervisorIds):Promise.resolve(empty),
        employeeIds.length?admin.from('horarios_empleados').select('empleado_id,hora_entrada,hora_salida,inicio_almuerzo,duracion_almuerzo_min,dias_laborales,tolerancia_min,fecha_vigencia').eq('empresa_id',auth.empresa_id).eq('activo',true).in('empleado_id',employeeIds).order('fecha_vigencia',{ascending:false}):Promise.resolve(empty),
      ])
      console.log('EmployeeSync respuestas PostgREST catálogos',{request_id:requestId,company_id:auth.empresa_id,branches:branchResult,departments:departmentResult,positions:positionResult,supervisors:supervisorResult})
    }catch(error){return stageFailure(requestId,'consulta_catalogos_supervisores',error,auth.empresa_id)}
    const lookupError=branchResult.error||departmentResult.error||positionResult.error||supervisorResult.error||scheduleResult.error
    if(lookupError)return stageFailure(requestId,'consulta_catalogos_supervisores',lookupError,auth.empresa_id,500)
    const branchNames=new Map((branchResult.data??[]).map(row=>[row.id,row.name]))
    const departmentNames=new Map((departmentResult.data??[]).map(row=>[row.id,row.name]))
    const positionNames=new Map((positionResult.data??[]).map(row=>[row.id,row.name]))
    const supervisorNames=new Map((supervisorResult.data??[]).map(row=>[row.id,row.nombre_completo]))
    const schedules=new Map<string,Record<string,unknown>>();for(const row of scheduleResult.data??[]){if(!schedules.has(String(row.empleado_id)))schedules.set(String(row.empleado_id),row)}
    const employees=page.filter(row=>row.activo===true).map(row=>{const schedule=schedules.get(row.id);return({
      remote_id:row.id,code:row.codigo_empleado,name:row.nombre_completo,email:row.correo??'',phone:row.telefono??'',
      branch_id:row.sucursal_id,branch_name:branchNames.get(row.sucursal_id)??'',
      department_id:row.departamento_id,department_name:departmentNames.get(row.departamento_id)??'',
      position_id:row.puesto_id,position_name:positionNames.get(row.puesto_id)??'',
      supervisor_id:row.supervisor_id,supervisor_name:supervisorNames.get(row.supervisor_id)??'',
      status:row.estado_laboral,jornada_enabled:row.jornada_habilitada!==false,
      schedule_start:schedule?.hora_entrada??null,schedule_end:schedule?.hora_salida??null,lunch_start:schedule?.inicio_almuerzo??null,
      lunch_duration_minutes:schedule?.duracion_almuerzo_min??null,work_days:schedule?.dias_laborales??null,tolerance_minutes:schedule?.tolerancia_min??null,
      start_date:row.fecha_ingreso,salary:row.salario,pay_type:row.tipo_pago,updated_at:row.updated_at,face_embedding:validEmbedding(row.face_embedding)?row.face_embedding:null,
    })})
    const inactive=page.filter(row=>row.activo!==true).map(row=>({remote_id:row.id,updated_at:row.updated_at}))
    if(targeted){const row=page[0];console.log('FACE_CROSS_DEVICE_SYNC',{employeeCode,remoteId:row?.id??null,remoteEmbeddingPresent:validEmbedding(row?.face_embedding),remoteEmbeddingDimension:Array.isArray(row?.face_embedding)?row.face_embedding.length:null,httpStatus:200,finalResult:row?'FOUND':'NOT_FOUND'})}
    console.log('EmployeeSync empleados enviados',{request_id:requestId,company_id:auth.empresa_id,active_sent:employees.length,inactive_sent:inactive.length,has_more:changed.length>page.length})
    await admin.from('dispositivos_android').update({ultima_conexion_at:now}).eq('id',deviceId).eq('empresa_id',auth.empresa_id)
    await admin.from('credenciales_dispositivo').update({ultima_uso_at:now}).eq('dispositivo_id',deviceId).eq('empresa_id',auth.empresa_id)
    return json({employees,inactive,cursor:targeted?null:(last?{updated_at:last.updated_at,id:last.id}:{updated_at:cursorUpdatedAt,id:cursorId}),has_more:targeted?false:changed.length>page.length,targeted,synced_at:now,company_id:auth.empresa_id,diagnostic_request_id:requestId})
  }catch(error){return stageFailure(requestId,'excepcion_no_controlada',error,diagnosticCompanyId)}
})
