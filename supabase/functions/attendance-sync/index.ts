import {createClient} from '@supabase/supabase-js';

const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'content-type, x-device-id, x-device-credential'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
const text=(value:unknown)=>typeof value==='string'?value.trim():'';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const sha256=async(value:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))).map(x=>x.toString(16).padStart(2,'0')).join('');

Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 const requestId=crypto.randomUUID(),started=Date.now();
 try{
  const deviceId=text(req.headers.get('x-device-id')),credential=text(req.headers.get('x-device-credential'));
  if(!uuid.test(deviceId)||!credential)return json({error:'Credencial de dispositivo requerida',error_code:'INVALID_DEVICE_CREDENTIAL',request_id:requestId},401);
  const url=Deno.env.get('SUPABASE_URL'),service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if(!url||!service)throw new Error('Configuración Supabase incompleta');
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}}),hash=await sha256(credential),now=new Date().toISOString();
  const{data:auth,error:authError}=await admin.from('credenciales_dispositivo').select('empresa_id,dispositivo_id,expires_at,revocado_at').eq('dispositivo_id',deviceId).eq('token_hash',hash).is('revocado_at',null).gt('expires_at',now).maybeSingle();
  if(authError)throw authError;
  if(!auth)return json({error:'Credencial de dispositivo inválida o vencida',error_code:'INVALID_DEVICE_CREDENTIAL',request_id:requestId},401);
  const{data:device,error:deviceError}=await admin.from('dispositivos_android').select('id,empresa_id,estado').eq('id',deviceId).eq('empresa_id',auth.empresa_id).maybeSingle();
  if(deviceError)throw deviceError;
  if(!device||device.estado!=='activo')return json({error:'Dispositivo revocado o inactivo',error_code:'DEVICE_REVOKED',request_id:requestId},403);
  const{data:company,error:companyError}=await admin.from('companies').select('timezone').eq('id',auth.empresa_id).single();if(companyError)throw companyError;
  const body=await req.json() as{operations?:unknown[]};
  if(!Array.isArray(body.operations)||body.operations.length===0||body.operations.length>100)return json({error:'operations debe contener entre 1 y 100 elementos',error_code:'INVALID_PAYLOAD',request_id:requestId},400);
  const results=[];
  for(const raw of body.operations){
   const operation=(raw??{}) as Record<string,unknown>,employeeId=text(operation.employee_remote_id),key=text(operation.idempotency_key),action=text(operation.action),workDate=text(operation.work_date),occurredAt=text(operation.occurred_at);
   if(!uuid.test(employeeId)||!uuid.test(key)||!['INICIAR','PAUSAR','REANUDAR','FINALIZAR'].includes(action)||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(workDate)||Number.isNaN(Date.parse(occurredAt))){results.push({idempotency_key:key,result:'rejected',error_code:'INVALID_PAYLOAD'});continue}
   const parts=new Intl.DateTimeFormat('en-CA',{timeZone:company.timezone,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(occurredAt));const companyDate=`${parts.find(x=>x.type==='year')?.value}-${parts.find(x=>x.type==='month')?.value}-${parts.find(x=>x.type==='day')?.value}`;if(companyDate!==workDate){results.push({idempotency_key:key,result:'conflict',error_code:'WORK_DATE_MISMATCH',company_work_date:companyDate});continue}
   const payload={empresa_id:auth.empresa_id,empleado_id:employeeId,dispositivo_id:deviceId,fecha_laboral:workDate,accion:action,ocurrido_en:occurredAt,idempotency_key:key,version_conocida:Number(operation.known_version??0),contract_version:Number(operation.contract_version??0)};
   const{data,error}=await admin.rpc('registrar_evento_jornada_dispositivo',{payload});
   if(error){console.error('AttendanceSync RPC failure',{request_id:requestId,device_id:deviceId,error_code:error.code,message:error.message,details:error.details,hint:error.hint});results.push({idempotency_key:key,result:'rejected',error_code:error.code||'DATABASE_ERROR',error:error.message,details:error.details,hint:error.hint});continue}
   results.push({idempotency_key:key,...(data as Record<string,unknown>)});
  }
  await admin.from('credenciales_dispositivo').update({ultima_uso_at:now}).eq('dispositivo_id',deviceId).eq('empresa_id',auth.empresa_id);
  await admin.from('dispositivos_android').update({ultima_conexion_at:now}).eq('id',deviceId).eq('empresa_id',auth.empresa_id);
  console.info('AttendanceSync completed',{request_id:requestId,device_id:deviceId,company_id:auth.empresa_id,operations:results.length,duration_ms:Date.now()-started});
  return json({contract_version:1,company_id:auth.empresa_id,request_id:requestId,results});
 }catch(error){const message=error instanceof Error?error.message:String(error);console.error('AttendanceSync exception',{request_id:requestId,message,stack:error instanceof Error?error.stack:undefined,duration_ms:Date.now()-started});return json({error:message,error_code:'ATTENDANCE_SYNC_ERROR',request_id:requestId},500)}
});
