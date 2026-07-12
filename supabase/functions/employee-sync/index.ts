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
const relationText=(value:unknown,key:string)=>{const row=Array.isArray(value)?value[0]:value;return row&&typeof row==='object'&&key in row?text((row as Record<string,unknown>)[key]):''}

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
    const{data:auth,error:authError}=await admin.from('credenciales_dispositivo').select('empresa_id,dispositivo_id').eq('dispositivo_id',deviceId).eq('token_hash',await hash(credential)).is('revocado_at',null).gt('expires_at',now).maybeSingle()
    if(authError)throw authError
    if(!auth)return json({error:'Dispositivo no autorizado o credencial vencida'},401)
    diagnosticCompanyId=auth.empresa_id
    console.log('EmployeeSync dispositivo autenticado',{request_id:requestId,device_id:deviceId,company_id:auth.empresa_id})
    const{data:device,error:deviceError}=await admin.from('dispositivos_android').select('id,empresa_id').eq('id',deviceId).eq('empresa_id',auth.empresa_id).eq('estado','activo').maybeSingle()
    if(deviceError)throw deviceError
    if(!device)return json({error:'Dispositivo revocado o empresa incorrecta'},403)
    console.log('EmployeeSync dispositivo activo validado',{request_id:requestId,device_id:device.id,company_id:device.empresa_id})

    const body=await request.json().catch(()=>({})),cursor=body?.cursor??{},cursorUpdatedAt=text(cursor.updated_at),cursorId=text(cursor.id)
    console.log('EmployeeSync cursor recibido',{request_id:requestId,company_id:auth.empresa_id,cursor_updated_at:cursorUpdatedAt||null,cursor_id:cursorId||null})
    if(cursorUpdatedAt&&Number.isNaN(Date.parse(cursorUpdatedAt)))return json({error:'Cursor updated_at inválido'},400)
    if(cursorId&&!validUuid(cursorId))return json({error:'Cursor id inválido'},400)

    let query=admin.from('empleados').select('id,codigo_empleado,nombre_completo,correo,telefono,sucursal_id,departamento_id,puesto_id,supervisor_id,estado_laboral,fecha_ingreso,salario,tipo_pago,activo,updated_at,branches!empleados_sucursal_misma_empresa_fk(name),departments!empleados_departamento_misma_empresa_fk(name),positions!empleados_puesto_misma_empresa_fk(name),supervisor:empleados!empleados_supervisor_misma_empresa_fk(nombre_completo)').eq('empresa_id',auth.empresa_id).order('updated_at').order('id').limit(1001)
    if(cursorUpdatedAt)query=query.gte('updated_at',cursorUpdatedAt)
    const{data,error}=await query
    if(error){console.error('EmployeeSync consulta empleados falló',{request_id:requestId,company_id:auth.empresa_id,error});throw error}
    const changed=(data??[]).filter(row=>afterCursor(row,cursorUpdatedAt,cursorId)),page=changed.slice(0,500),last=page.at(-1)
    console.log('EmployeeSync empleados encontrados',{request_id:requestId,company_id:auth.empresa_id,query_rows:data?.length??0,after_cursor:changed.length,page_rows:page.length})
    const employees=page.filter(row=>row.activo===true).map(row=>({
      remote_id:row.id,code:row.codigo_empleado,name:row.nombre_completo,email:row.correo??'',phone:row.telefono??'',
      branch_id:row.sucursal_id,branch_name:relationText(row.branches,'name'),
      department_id:row.departamento_id,department_name:relationText(row.departments,'name'),
      position_id:row.puesto_id,position_name:relationText(row.positions,'name'),
      supervisor_id:row.supervisor_id,supervisor_name:relationText(row.supervisor,'nombre_completo'),
      status:row.estado_laboral,start_date:row.fecha_ingreso,salary:row.salario,pay_type:row.tipo_pago,updated_at:row.updated_at,
    }))
    const inactive=page.filter(row=>row.activo!==true).map(row=>({remote_id:row.id,updated_at:row.updated_at}))
    console.log('EmployeeSync empleados enviados',{request_id:requestId,company_id:auth.empresa_id,active_sent:employees.length,inactive_sent:inactive.length,has_more:changed.length>page.length})
    await admin.from('dispositivos_android').update({ultima_conexion_at:now}).eq('id',deviceId).eq('empresa_id',auth.empresa_id)
    await admin.from('credenciales_dispositivo').update({ultima_uso_at:now}).eq('dispositivo_id',deviceId).eq('empresa_id',auth.empresa_id)
    return json({employees,inactive,cursor:last?{updated_at:last.updated_at,id:last.id}:{updated_at:cursorUpdatedAt,id:cursorId},has_more:changed.length>page.length,synced_at:now,company_id:auth.empresa_id,diagnostic_request_id:requestId})
  }catch(error){
    console.error('EmployeeSync excepción completa',{request_id:requestId,error,stack:error instanceof Error?error.stack:null})
    return json({error:error instanceof Error?error.message:'Error inesperado',company_id:diagnosticCompanyId,diagnostic_request_id:requestId},500)
  }
})
