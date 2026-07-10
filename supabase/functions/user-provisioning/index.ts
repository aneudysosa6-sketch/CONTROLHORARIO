import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type, x-bootstrap-secret'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
const required=(value:unknown,name:string)=>{if(typeof value!=='string'||!value.trim())throw new Error(`${name} es obligatorio`);return value.trim()};

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  try{
    const url=required(Deno.env.get('SUPABASE_URL'),'SUPABASE_URL');
    const publishable=required(Deno.env.get('SUPABASE_ANON_KEY'),'SUPABASE_ANON_KEY');
    const serviceKey=required(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),'SUPABASE_SERVICE_ROLE_KEY');
    const jwt=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');
    if(!jwt)return json({error:'Sesión requerida'},401);
    const admin=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
    const callerClient=createClient(url,publishable,{global:{headers:{Authorization:`Bearer ${jwt}`}},auth:{persistSession:false}});
    const{data:{user},error:userError}=await admin.auth.getUser(jwt);
    if(userError||!user)return json({error:'Sesión inválida'},401);
    const body=await req.json();
    const action=required(body.action,'action');
    const isBootstrap=action==='bootstrap';
    let callerCompanyId:string|undefined;
    if(isBootstrap){
      const expected=Deno.env.get('USER_PROVISIONING_BOOTSTRAP_SECRET');
      if(!expected||req.headers.get('x-bootstrap-secret')!==expected)return json({error:'Bootstrap no autorizado'},403);
      const{count}=await admin.from('profiles').select('id',{count:'exact',head:true});
      if(count!==0)return json({error:'Bootstrap cerrado: ya existe al menos un profile'},409);
    }else{
      const{data:allowed,error}=await callerClient.rpc('tiene_permiso',{codigo_permiso:'usuarios.administrar'});
      if(error||allowed!==true)return json({error:'Permiso usuarios.administrar requerido'},403);
      const{data:callerProfile,error:profileError}=await admin.from('profiles').select('company_id').eq('id',user.id).eq('status','active').single();
      if(profileError||!callerProfile)return json({error:'Profile activo requerido'},403);
      callerCompanyId=callerProfile.company_id;
    }

    if(action==='list'){return await listState(admin,callerCompanyId)}
    if(action==='bootstrap'){
      return await provision(admin,{...body,user_id:user.id,actor_user_id:null,action:'bootstrap_admin'});
    }
    if(action==='create'||action==='invite'){
      const email=required(body.email,'email').toLowerCase();
      const created=action==='invite'
        ? await admin.auth.admin.inviteUserByEmail(email,{data:{full_name:body.full_name}})
        : await admin.auth.admin.createUser({email,password:required(body.password,'password'),email_confirm:true,user_metadata:{full_name:body.full_name}});
      if(created.error||!created.data.user)throw created.error??new Error('No se creó el usuario Auth');
      try{return await provision(admin,{...body,company_id:callerCompanyId,status:'active',user_id:created.data.user.id,actor_user_id:user.id,action:action==='invite'?'invite_user':'create_user'})}
      catch(error){if(action==='create')await admin.auth.admin.deleteUser(created.data.user.id);throw error}
    }
    if(action==='provision')return await provision(admin,{...body,company_id:callerCompanyId,actor_user_id:user.id,action:'provision_user'});
    return json({error:'Acción no soportada'},400);
  }catch(error){return json({error:error instanceof Error?error.message:'Error inesperado'},400)}
});

async function listState(admin:ReturnType<typeof createClient>,companyId?:string){
  const authUsers:Array<{id:string;email?:string;user_metadata?:Record<string,unknown>;created_at:string}>=[];for(let page=1;;page++){const{data,error}=await admin.auth.admin.listUsers({page,perPage:1000});if(error)throw error;authUsers.push(...data.users);if(data.users.length<1000)break}
  const ids=authUsers.map(u=>u.id);const{data:profiles,error:profileError}=ids.length?await admin.from('profiles').select('id').in('id',ids):{data:[],error:null};if(profileError)throw profileError;
  const known=new Set((profiles??[]).map(p=>p.id));
  let companies=admin.from('companies').select('id,name,slug').eq('status','active');
  const{data:companyRows,error:companyError}=await companies;if(companyError)throw companyError;
  const selected=companyId??companyRows?.[0]?.id;
  const [{data:roles,error:rolesError},{data:employees,error:employeesError}]=await Promise.all([
    admin.from('roles').select('id,name,code,company_id').eq('company_id',selected??'00000000-0000-0000-0000-000000000000').eq('is_active',true),
    admin.from('empleados').select('id,nombre_completo,codigo_empleado,empresa_id').eq('empresa_id',selected??'00000000-0000-0000-0000-000000000000').is('perfil_id',null).eq('activo',true)
  ]);if(rolesError)throw rolesError;if(employeesError)throw employeesError;
  return json({users:authUsers.filter(u=>!known.has(u.id)).map(u=>({id:u.id,email:u.email??'',full_name:typeof u.user_metadata?.full_name==='string'?u.user_metadata.full_name:u.email??'',created_at:u.created_at})),companies:companyRows??[],roles:roles??[],employees:employees??[]});
}

async function provision(admin:ReturnType<typeof createClient>,payload:Record<string,unknown>){
  required(payload.user_id,'user_id');required(payload.company_id,'company_id');required(payload.role_id,'role_id');required(payload.full_name,'full_name');
  const{data,error}=await admin.rpc('provision_user_internal',{payload});if(error)throw error;return json({profile:data});
}
