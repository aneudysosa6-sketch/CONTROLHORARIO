import{getSupabaseClient}from'../../infrastructure/supabase/client';
export interface PendingAuthUser{id:string;email:string;full_name:string;created_at:string}
export interface CatalogItem{id:string;name:string;code?:string;company_id?:string}
export interface AvailableEmployee{id:string;nombre_completo:string;codigo_empleado:string;empresa_id:string}
export interface ProvisioningState{users:PendingAuthUser[];companies:CatalogItem[];roles:CatalogItem[];employees:AvailableEmployee[]}
export interface ProvisionInput{user_id?:string;email?:string;full_name:string;company_id:string;role_id:string;employee_id?:string;status:'active'|'invited'}
export interface BootstrapInput{company_name:string;legal_name:string;company_slug:string;full_name:string;email:string;branch_name:string;employee_code?:string;timezone:'America/Santo_Domingo'}
async function invoke<T>(body:Record<string,unknown>):Promise<T>{const{data,error}=await getSupabaseClient().functions.invoke('user-provisioning',{body});if(error)throw error;if(data?.error)throw new Error(data.error);return data as T}
async function bootstrap(input:BootstrapInput,secret:string){const{data,error}=await getSupabaseClient().functions.invoke('user-provisioning',{body:{action:'bootstrap',...input},headers:{'x-bootstrap-secret':secret}});if(data?.error)throw new Error(data.error);if(error){const response=(error as {context?:Response}).context;if(response){const payload=await response.clone().json().catch(()=>null) as {error?:string}|null;if(payload?.error)throw new Error(payload.error)}throw error}return data as {profile:unknown}}
export const userProvisioningService={bootstrapStatus:()=>invoke<{bootstrap_required:boolean}>({action:'bootstrap-status'}),list:(company_id?:string)=>invoke<ProvisioningState>({action:'list',company_id}),provision:(input:ProvisionInput)=>invoke<{profile:unknown}>({action:'provision',...input}),invite:(input:ProvisionInput)=>invoke<{profile:unknown}>({action:'invite',...input}),bootstrap};
