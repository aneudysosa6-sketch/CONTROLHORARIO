import { createClient } from '@supabase/supabase-js'
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type,x-device-id,x-device-credential'}
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}})
const text=(value:unknown)=>typeof value==='string'?value.trim():''
const random=(size:number)=>{const bytes=new Uint8Array(size);crypto.getRandomValues(bytes);return Array.from(bytes,x=>x.toString(16).padStart(2,'0')).join('')}
const hash=async(value:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))).map(x=>x.toString(16).padStart(2,'0')).join('')

Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors})
 try{
  const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const body=await request.json(),action=text(body.action),admin=createClient(url,service,{auth:{persistSession:false}})
  if(action==='exchange'){
   const code=text(body.code).toUpperCase(),installation=text(body.installation_id),publicKey=text(body.public_key_spki)
   if(!/^[A-F0-9]{16}$/.test(code)||!/^[0-9a-f-]{36}$/i.test(installation)||publicKey.length<80)return json({error:'Solicitud de enrolamiento inválida'},400)
   const {data:enrollment}=await admin.from('codigos_enrolamiento_dispositivo').select('id').eq('codigo_hash',await hash(code)).is('usado_at',null).is('revocado_at',null).gt('expires_at',new Date().toISOString()).maybeSingle()
   if(!enrollment)return json({error:'Código inválido, vencido o usado'},403)
   const deviceId=crypto.randomUUID(),credential=random(32),now=new Date().toISOString()
   const {error}=await admin.rpc('enroll_android_device_internal',{payload:{enrollment_id:enrollment.id,device_id:deviceId,installation_id:installation,public_key_spki:publicKey,name:text(body.name),model:text(body.model),android_version:text(body.android_version),app_version:text(body.app_version),token_hash:await hash(credential),now}})
   if(error)throw error
   return json({device_id:deviceId,credential,expires_at:new Date(Date.now()+30*86400000).toISOString()})
  }
  if(action==='employee-sync'){
   const deviceId=text(request.headers.get('x-device-id')),credential=text(request.headers.get('x-device-credential'))
   if(!/^[0-9a-f-]{36}$/i.test(deviceId)||credential.length!==64)return json({error:'Credencial de dispositivo requerida'},401)
   const now=new Date().toISOString(),{data:auth}=await admin.from('credenciales_dispositivo').select('empresa_id,dispositivo_id').eq('dispositivo_id',deviceId).eq('token_hash',await hash(credential)).is('revocado_at',null).gt('expires_at',now).maybeSingle()
   if(!auth)return json({error:'Dispositivo no autorizado o credencial vencida'},401)
   const {data:device}=await admin.from('dispositivos_android').select('id').eq('id',deviceId).eq('empresa_id',auth.empresa_id).eq('estado','activo').maybeSingle()
   if(!device)return json({error:'Dispositivo revocado o inactivo'},403)
   const {data:employees,error}=await admin.from('empleados').select('id,codigo_empleado,nombre_completo,telefono,activo,sucursal_id,updated_at').eq('empresa_id',auth.empresa_id).order('id')
   if(error)throw error
   await admin.from('dispositivos_android').update({ultima_conexion_at:now}).eq('id',deviceId).eq('empresa_id',auth.empresa_id)
   await admin.from('credenciales_dispositivo').update({ultima_uso_at:now}).eq('dispositivo_id',deviceId).eq('empresa_id',auth.empresa_id)
   return json({employees:employees??[],synced_at:now})
  }
  const jwt=request.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');if(!jwt)return json({error:'Sesión requerida'},401)
  const caller=createClient(url,anon,{global:{headers:{Authorization:`Bearer ${jwt}`}},auth:{persistSession:false}}),{data:{user}}=await admin.auth.getUser(jwt);if(!user)return json({error:'Sesión inválida'},401)
  const {data:profile}=await admin.from('profiles').select('company_id').eq('id',user.id).eq('status','active').single();if(!profile)return json({error:'Profile activo requerido'},403)
  const permission=action==='list'?'dispositivos.ver':action==='create-code'?'dispositivos.registrar':'dispositivos.revocar',{data:allowed}=await caller.rpc('tiene_permiso',{codigo_permiso:permission});if(allowed!==true)return json({error:`Permiso ${permission} requerido`},403)
  if(action==='list'){const[{data,error},{data:credentials,error:credentialsError}]=await Promise.all([admin.from('dispositivos_android').select('id,nombre,modelo,android_version,app_version,sucursal_id,estado,registrado_at,ultima_conexion_at,revocado_at').eq('empresa_id',profile.company_id).order('registrado_at',{ascending:false}),admin.from('credenciales_dispositivo').select('dispositivo_id,ultima_uso_at,created_at').eq('empresa_id',profile.company_id).order('created_at',{ascending:false})]);if(error)throw error;if(credentialsError)throw credentialsError;const lastSync=new Map<string,string|null>();for(const row of credentials??[]){if(!lastSync.has(row.dispositivo_id))lastSync.set(row.dispositivo_id,row.ultima_uso_at)}return json({devices:(data??[]).map(device=>({...device,ultima_sincronizacion_at:lastSync.get(device.id)??null}))})}
  if(action==='create-code'){const code=random(8).toUpperCase(),expires=new Date(Date.now()+10*60000).toISOString();const{error}=await admin.from('codigos_enrolamiento_dispositivo').insert({empresa_id:profile.company_id,sucursal_id:text(body.branch_id)||null,codigo_hash:await hash(code),expires_at:expires,creado_por:user.id});if(error)throw error;return json({code,expires_at:expires})}
  if(action==='revoke'){const id=text(body.device_id),now=new Date().toISOString();await admin.from('dispositivos_android').update({estado:'revocado',revocado_at:now}).eq('id',id).eq('empresa_id',profile.company_id);await admin.from('credenciales_dispositivo').update({revocado_at:now}).eq('dispositivo_id',id).eq('empresa_id',profile.company_id);return json({id,status:'revocado'})}
  return json({error:'Acción no soportada'},400)
 }catch(error){return json({error:error instanceof Error?error.message:'Error inesperado'},400)}
})
